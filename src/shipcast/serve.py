import argparse
import ipaddress
import re
import socket
import sys
from collections.abc import Sequence
from datetime import date
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import unquote

from shipcast.config import Config, ConfigError, config_path, load_config
from shipcast.model import REPO_ID_PATTERN, JournalFormatError, journal_path, parse_journal
from shipcast.page import BROKEN_JOURNAL_PAGE, NOT_FOUND_PAGE, wrap_markdown

_ASSET_CONTENT_TYPES = {
    ".css": "text/css; charset=utf-8",
    ".js": "text/javascript; charset=utf-8",
    ".mjs": "text/javascript; charset=utf-8",
    ".json": "application/json",
    ".wasm": "application/wasm",
    ".woff2": "font/woff2",
    ".md": "text/plain; charset=utf-8",
    ".txt": "text/plain; charset=utf-8",
}
_BRACKETED_HOST = re.compile(r"\[([a-z0-9.:_%~-]+)\](?::[0-9]+)?", re.ASCII)
_NAMED_HOST = re.compile(r"([a-z0-9-]+(?:\.[a-z0-9-]+)*)(?::[0-9]+)?", re.ASCII)
_JOURNAL_DATE = re.compile(r"[0-9]{4}-[0-9]{2}-[0-9]{2}")
_HTML_CONTENT_TYPE = "text/html; charset=utf-8"
_TEXT_CONTENT_TYPE = "text/plain; charset=utf-8"


def split_path(target: str) -> tuple[str, ...] | None:
    path = target.partition("?")[0].partition("#")[0]
    if not path.startswith("/"):
        return None
    if path == "/":
        return ()
    try:
        parts = tuple(unquote(part, errors="strict") for part in path[1:].split("/"))
    except UnicodeDecodeError:
        return None
    if any(
        not part or part.startswith(".") or "/" in part or "\\" in part or "\x00" in part
        for part in parts
    ):
        return None
    return parts


def resolve_inside(root: Path, parts: Sequence[str]) -> Path | None:
    try:
        base = root.resolve()
        candidate = base.joinpath(*parts).resolve()
    except (OSError, RuntimeError):
        return None
    return candidate if candidate.is_relative_to(base) else None


def security_headers() -> tuple[tuple[str, str], ...]:
    return (
        (
            "Content-Security-Policy",
            "default-src 'self'; script-src 'self' 'wasm-unsafe-eval' "
            "https://unpkg.com/@plantuml/core@1.2026.6/ "
            "https://unpkg.com/@highlightjs/cdn-assets@11.11.1/; "
            "style-src 'self' 'unsafe-inline' https://fonts.googleapis.com; "
            "font-src 'self' https://fonts.gstatic.com; img-src 'self' data:; object-src 'none'; "
            "base-uri 'none'; frame-ancestors 'none'; form-action 'none'",
        ),
        ("X-Content-Type-Options", "nosniff"),
        ("Referrer-Policy", "no-referrer"),
    )


def host_allowed(host: str | None) -> bool:
    if not host or not host.isascii():
        return False
    host = host.lower()
    bracketed = _BRACKETED_HOST.fullmatch(host)
    if bracketed is not None:
        try:
            ipaddress.IPv6Address(bracketed[1])
        except ValueError:
            return False
        return True

    if host.count(":") > 1:
        try:
            ipaddress.IPv6Address(host)
        except ValueError:
            return False
        return True

    named = _NAMED_HOST.fullmatch(host)
    if named is None:
        return False
    name = named[1]
    if name == "localhost" or name.endswith(".ts.net"):
        return True
    try:
        ipaddress.IPv4Address(name)
    except ValueError:
        return False
    return True


class _Handler(BaseHTTPRequestHandler):
    server_version = "shipcast"
    sys_version = ""
    journal_dir: Path
    design_dir: Path

    def parse_request(self) -> bool:
        if not super().parse_request():
            return False
        hosts = self.headers.get_all("Host", [])
        if len(hosts) != 1 or not host_allowed(hosts[0]):
            self._send_body(HTTPStatus.BAD_REQUEST, _TEXT_CONTENT_TYPE, b"Invalid Host\n")
            return False
        return True

    def end_headers(self) -> None:
        for name, value in security_headers():
            self.send_header(name, value)
        super().end_headers()

    def send_response_only(self, code: int, message: str | None = None) -> None:
        # Include status and security headers even for HTTP/0.9 requests and parse errors.
        if self.request_version == "HTTP/0.9":
            self.request_version = self.protocol_version
        super().send_response_only(code, message)

    def do_GET(self) -> None:
        # BaseHTTPRequestHandler collapses leading slashes in self.path.
        parts = split_path(self.requestline.split()[1])
        if parts and parts[0] == "_ds" and self._serve_asset(parts[1:]):
            return
        if parts is not None and len(parts) == 2 and self._serve_journal(*parts):
            return
        self._send_html(HTTPStatus.NOT_FOUND, NOT_FOUND_PAGE)

    do_HEAD = do_GET

    def do_POST(self) -> None:
        self._send_body(
            HTTPStatus.METHOD_NOT_ALLOWED,
            _TEXT_CONTENT_TYPE,
            b"Method Not Allowed\n",
            extra_headers=(("Allow", "GET, HEAD"),),
        )

    do_PUT = do_DELETE = do_PATCH = do_OPTIONS = do_POST

    def _serve_asset(self, parts: tuple[str, ...]) -> bool:
        if not parts:
            return False
        path = resolve_inside(self.design_dir, parts)
        if path is None:
            return False
        content_type = _ASSET_CONTENT_TYPES.get(path.suffix)
        if content_type is None:
            return False
        try:
            if not path.is_file():
                return False
            body = path.read_bytes()
        except OSError:
            return False
        self._send_body(HTTPStatus.OK, content_type, body)
        return True

    def _serve_journal(self, repo: str, day: str) -> bool:
        if not REPO_ID_PATTERN.fullmatch(repo) or not _JOURNAL_DATE.fullmatch(day):
            return False
        try:
            journal_day = date.fromisoformat(day)
        except ValueError:
            return False
        relative = journal_path(self.journal_dir, repo, journal_day).relative_to(self.journal_dir)
        path = resolve_inside(self.journal_dir, relative.parts)
        if path is None:
            return False
        try:
            if not path.is_file():
                return False
            text = path.read_bytes().decode("utf-8")
            meta, _ = parse_journal(text)
        except (FileNotFoundError, NotADirectoryError):
            return False
        except (OSError, UnicodeDecodeError, JournalFormatError) as error:
            self.log_error("%s: %s", path, error)
            self._send_html(HTTPStatus.INTERNAL_SERVER_ERROR, BROKEN_JOURNAL_PAGE)
            return True
        self._send_html(HTTPStatus.OK, wrap_markdown(text.removeprefix("\ufeff"), meta.title))
        return True

    def _send_html(self, status: HTTPStatus, html: str) -> None:
        self._send_body(status, _HTML_CONTENT_TYPE, html.encode("utf-8"))

    def _send_body(
        self,
        status: HTTPStatus,
        content_type: str,
        body: bytes,
        *,
        extra_headers: tuple[tuple[str, str], ...] = (),
    ) -> None:
        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        for name, value in extra_headers:
            self.send_header(name, value)
        self.end_headers()
        if self.command != "HEAD":
            self.wfile.write(body)


def create_server(host: str, port: int, journal_dir: Path, design_dir: Path) -> ThreadingHTTPServer:
    class Handler(_Handler):
        pass

    Handler.journal_dir = journal_dir
    Handler.design_dir = design_dir
    server_type = _IPv6HTTPServer if ":" in host else ThreadingHTTPServer
    return server_type((host, port), Handler)


class _IPv6HTTPServer(ThreadingHTTPServer):
    address_family = socket.AF_INET6


class DesignSystemNotFound(Exception):
    def __init__(self, searched: tuple[Path, ...]):
        super().__init__("デザインシステムが見つかりません")
        self.searched = searched


def find_design_system(config: Config) -> Path:
    explicit_dir = config.serve.design_system_dir
    locations = (
        (explicit_dir,)
        if explicit_dir is not None
        else tuple(repo.path / "spec-dock/design-system" for repo in config.repos)
    )
    for directory in locations:
        if (directory / "ds.css").is_file() and (directory / "ds.js").is_file():
            return directory.resolve()
    raise DesignSystemNotFound(locations)


def configure(parser: argparse.ArgumentParser) -> None:
    parser.add_argument("--host", metavar="HOST", help="待ち受けるホスト")
    parser.add_argument("--port", metavar="PORT", type=_parse_port, help="待ち受けるポート")
    parser.set_defaults(func=run)


def _parse_port(value: str) -> int:
    error_message = "1〜65535の整数を指定してください"
    try:
        port = int(value)
    except ValueError as error:
        raise argparse.ArgumentTypeError(error_message) from error
    if not 1 <= port <= 65535:
        raise argparse.ArgumentTypeError(error_message)
    return port


def _is_loopback(host: str) -> bool:
    if host.lower() == "localhost":
        return True
    try:
        return ipaddress.ip_address(host).is_loopback
    except ValueError:
        return False


def run(args: argparse.Namespace) -> int:
    try:
        config = load_config()
    except ConfigError as error:
        print(f"shipcast serve: {error}", file=sys.stderr)
        return 1
    try:
        design_dir = find_design_system(config)
    except DesignSystemNotFound as error:
        locations = "\n".join(map(str, error.searched)) or "登録したrepositoryがありません"
        print(
            f"shipcast serve: {error}\n"
            f"{locations}\n"
            f"設定ファイル {config_path()} に次のように指定できます。\n"
            '[serve]\ndesign_system_dir = "/…/spec-dock/design-system"\n'
            "デザインシステムは `spec-dock installation update` で入れられます。",
            file=sys.stderr,
        )
        return 2

    host = config.serve.host if args.host is None else args.host
    port = config.serve.port if args.port is None else args.port
    authority = f"[{host}]:{port}" if ":" in host else f"{host}:{port}"
    try:
        server = create_server(host, port, config.journal_dir, design_dir)
    except OSError as error:
        print(f"shipcast serve: {authority} で待ち受けられません: {error}", file=sys.stderr)
        return 1
    try:
        print(
            f"http://{authority}/<repo>/<YYYY-MM-DD> で日誌を読めます\n"
            f"日誌の置き場: {config.journal_dir}\n"
            f"デザインシステムの置き場: {design_dir}\n"
            "Ctrl+C で止まります",
            flush=True,
        )
        if not config.journal_dir.is_dir():
            print(
                "日誌の置き場がまだありません（`shipcast run` で作られます）",
                file=sys.stderr,
            )
        if not _is_loopback(host):
            print(
                "tailnetやLANの端末から直接読めます。"
                "`tailscale serve` で 127.0.0.1 の配信を公開する方法を勧めます（README）",
                file=sys.stderr,
            )
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()
    return 0
