import ipaddress
import re
from collections.abc import Sequence
from pathlib import Path
from urllib.parse import unquote

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


def split_path(target: str) -> tuple[str, ...] | None:
    path = target.partition("?")[0].partition("#")[0]
    if not path.startswith("/"):
        return None
    try:
        path = unquote(path, errors="strict")
    except UnicodeDecodeError:
        return None
    if "\x00" in path or "\\" in path:
        return None
    if path == "/":
        return ()
    parts = tuple(path[1:].split("/"))
    if any(not part or part.startswith(".") for part in parts):
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
            "default-src 'self'; script-src 'self' 'wasm-unsafe-eval' https://unpkg.com; "
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
    if "." not in name or name.endswith(".ts.net"):
        return True
    try:
        ipaddress.IPv4Address(name)
    except ValueError:
        return False
    return True
