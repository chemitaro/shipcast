import errno
import os
import socket
from collections.abc import Iterator
from http.client import HTTPConnection, HTTPResponse
from pathlib import Path
from threading import Thread

import html5lib
import pytest

from shipcast import serve
from shipcast.cli import main
from shipcast.config import load_config


@pytest.mark.parametrize(
    ("target", "expected"),
    [
        ("/", ()),
        ("/demo-app/", None),
        ("/demo-app/2026-11-26?query#fragment", ("demo-app", "2026-11-26")),
        ("/_ds/%E3%81%82.css", ("_ds", "あ.css")),
        ("/_ds/%252e.css", ("_ds", "%2e.css")),
        ("https://localhost/_ds/ds.css", None),
        ("/_ds/../x", None),
        ("/_ds/%2e%2e/x", None),
        ("/_ds/..%2fx", None),
        ("/_ds/%2e%2e%2fx", None),
        ("/_ds/..%5cx", None),
        ("//x", None),
        ("/_ds//ds.css", None),
        ("/_ds/.x", None),
        ("/_ds/%00", None),
        ("/_ds/%ff", None),
    ],
)
def test_split_path(target, expected):
    assert serve.split_path(target) == expected


def test_resolve_inside(tmp_path):
    root = tmp_path / "root"
    root.mkdir()
    outside = tmp_path / "outside"
    outside.mkdir()
    (root / "linked-out").symlink_to(outside, target_is_directory=True)
    (root / "linked-in").symlink_to(root / "inside", target_is_directory=True)
    alias = tmp_path / "alias"
    alias.symlink_to(root, target_is_directory=True)

    assert serve.resolve_inside(alias, ("linked-in", "future.txt")) == root / "inside/future.txt"
    assert serve.resolve_inside(root, ("linked-out", "future.txt")) is None


EXPECTED_SECURITY_HEADERS = {
    "Content-Security-Policy": (
        "default-src 'self'; script-src 'self' 'wasm-unsafe-eval' https://unpkg.com; "
        "style-src 'self' 'unsafe-inline' https://fonts.googleapis.com; "
        "font-src 'self' https://fonts.gstatic.com; img-src 'self' data:; object-src 'none'; "
        "base-uri 'none'; frame-ancestors 'none'; form-action 'none'"
    ),
    "X-Content-Type-Options": "nosniff",
    "Referrer-Policy": "no-referrer",
}


def test_security_headers():
    headers = serve.security_headers()
    assert isinstance(headers, tuple)
    assert len(headers) == 3
    assert dict(headers) == EXPECTED_SECURITY_HEADERS


@pytest.mark.parametrize(
    ("host", "expected"),
    [
        ("127.0.0.1:8765", True),
        ("[::1]:8765", True),
        ("[::1]", True),
        ("localhost", True),
        ("MAC.TAIL1234.TS.NET:443", True),
        ("mac", True),
        ("evil.example", False),
        ("127.0.0.1.evil.example", False),
        ("ts.net.evil.example", False),
        ("mac:not-a-port", False),
        ("mac..ts.net", False),
        ("[::1]invalid", False),
        ("", False),
        (None, False),
    ],
)
def test_host_allowed(host, expected):
    assert serve.host_allowed(host) is expected


JOURNAL_FIXTURE = Path(__file__).parent / "fixtures/journal/demo-app/2026/2026-11-26.md"
JOURNAL_URL = "/demo-app/2026-11-26"


@pytest.fixture
def journal_dir(tmp_path):
    root = tmp_path / "journal"
    path = root / "demo-app/2026/2026-11-26.md"
    path.parent.mkdir(parents=True)
    path.write_bytes(JOURNAL_FIXTURE.read_bytes())
    return root


@pytest.fixture
def design_dir(tmp_path):
    root = tmp_path / "design-system"
    (root / "vendor").mkdir(parents=True)
    (root / "ds.css").write_bytes(b"body {}\r\n")
    (root / "ds.js").write_bytes(b"// design system\n")
    (root / "vendor/marked.umd.js").write_bytes(b"// Markdown renderer\n")
    return root


@pytest.fixture
def address(journal_dir, design_dir) -> Iterator[tuple[str, int]]:
    with serve.create_server("127.0.0.1", 0, journal_dir, design_dir) as server:
        thread = Thread(target=server.serve_forever, kwargs={"poll_interval": 0.01})
        thread.start()
        try:
            yield server.server_address
        finally:
            server.shutdown()
            thread.join()


def request(address, method, target, *, host="localhost"):
    connection = HTTPConnection(*address, timeout=3)
    try:
        connection.putrequest(method, target, skip_host=True, skip_accept_encoding=True)
        if host is not None:
            connection.putheader("Host", host)
        connection.endheaders()
        with connection.getresponse() as response:
            # HTTPResponse.read() discards any bytes sent after HEAD headers.
            body = response.fp.read() if method == "HEAD" else response.read()
            return response.status, dict(response.getheaders()), body
    finally:
        connection.close()


def test_journal_page(address, journal_dir):
    journal = journal_dir / "demo-app/2026/2026-11-26.md"
    before = request(address, "GET", JOURNAL_URL)
    assert before[0] == 200
    assert "架空の開発日誌 &lt;b&gt;見本&lt;/b&gt;".encode() in before[2]
    original = journal.read_text(encoding="utf-8")
    updated = original.replace(original.splitlines()[1], "title: Demo <b>journal</b>", 1)
    journal.write_text(updated, encoding="utf-8")

    status, headers, body = request(address, "GET", JOURNAL_URL + "?view=full")

    assert status == 200
    assert headers["Content-Type"] == "text/html; charset=utf-8"
    assert int(headers["Content-Length"]) == len(body)
    assert b"<title>Demo &lt;b&gt;journal&lt;/b&gt;</title>" in body
    document = html5lib.parse(body.decode(), namespaceHTMLElements=False)
    assert document.findtext(".//title") == "Demo <b>journal</b>"
    assert document.find(".//link[@href='/_ds/ds.css']") is not None
    assert document.find(".//script[@src='/_ds/ds.js']") is not None
    sources = document.findall(".//script[@id='ds-source']")
    assert len(sources) == 1
    assert sources[0].get("type") == "text/markdown"
    assert sources[0].text.replace(r"<\/script", "</script") == f"\n{updated}\n<!-- -->\n"


@pytest.mark.parametrize(
    ("relative", "content_type"),
    [
        ("ds.css", "text/css; charset=utf-8"),
        ("ds.js", "text/javascript; charset=utf-8"),
        ("vendor/marked.umd.js", "text/javascript; charset=utf-8"),
        ("vendor/module.mjs", "text/javascript; charset=utf-8"),
        ("vendor/config.json", "application/json"),
        ("vendor/engine.wasm", "application/wasm"),
        ("vendor/font.woff2", "font/woff2"),
        ("vendor/readme.md", "text/plain; charset=utf-8"),
        ("vendor/license.txt", "text/plain; charset=utf-8"),
    ],
)
def test_design_system_asset(address, design_dir, relative, content_type):
    path = design_dir / relative
    if not path.exists():
        path.write_bytes(b"example data\x00\xff")

    status, headers, body = request(address, "GET", f"/_ds/{relative}")

    assert status == 200
    assert headers["Content-Type"] == content_type
    assert int(headers["Content-Length"]) == len(body)
    assert body == path.read_bytes()


@pytest.mark.parametrize("target", [JOURNAL_URL, "/_ds/ds.css", "/missing"])
def test_head_matches_get(address, target):
    status, headers, body = request(address, "GET", target)
    head_status, head_headers, head_body = request(address, "HEAD", target)

    assert head_status == status
    assert {key: value for key, value in head_headers.items() if key != "Date"} == {
        key: value for key, value in headers.items() if key != "Date"
    }
    assert "Date" in head_headers
    assert int(head_headers["Content-Length"]) == len(body)
    assert head_body == b""


@pytest.mark.parametrize("contents", [b"broken frontmatter", b"\xff"])
def test_broken_journal_returns_generic_notice(address, journal_dir, capsys, contents):
    path = journal_dir / "demo-app/2026/2026-11-26.md"
    path.write_bytes(contents)

    status, headers, body = request(address, "GET", JOURNAL_URL)

    assert status == 500
    assert headers["Content-Type"] == "text/html; charset=utf-8"
    assert int(headers["Content-Length"]) == len(body)
    assert b'id="ds-source"' in body
    assert "日誌を読めません".encode() in body
    assert JOURNAL_URL.encode() not in body
    assert str(journal_dir).encode() not in body
    assert str(path) in capsys.readouterr().err


def test_journal_page_strips_bom(address, journal_dir):
    path = journal_dir / "demo-app/2026/2026-11-26.md"
    path.write_bytes(b"\xef\xbb\xbf" + path.read_bytes())

    status, _, body = request(address, "GET", JOURNAL_URL)

    assert status == 200
    document = html5lib.parse(body.decode(), namespaceHTMLElements=False)
    assert document.findtext(".//script[@id='ds-source']").startswith("\n---\n")


@pytest.mark.parametrize(
    ("version", "host_headers"),
    [
        ("HTTP/1.0", "Host: evil.example\r\n"),
        ("HTTP/1.0", ""),
        ("HTTP/1.1", "Host: localhost\r\nHost: evil.example\r\n"),
        ("HTTP/0.9", ""),
    ],
)
def test_request_rejects_invalid_host(address, version, host_headers):
    message = f"GET {JOURNAL_URL} {version}\r\n{host_headers}\r\n"
    with socket.create_connection(address, timeout=3) as connection:
        connection.sendall(message.encode("ascii"))
        with HTTPResponse(connection) as response:
            response.begin()
            body = response.read()
            assert response.status == 400
            assert int(response.getheader("Content-Length")) == len(body)
            assert response.getheader("Content-Type") == "text/plain; charset=utf-8"
            assert b'id="ds-source"' not in body


@pytest.mark.parametrize("method", ["POST", "PUT", "DELETE", "PATCH", "OPTIONS"])
def test_method_not_allowed(address, method):
    status, headers, body = request(address, method, JOURNAL_URL)

    assert status == 405
    assert headers["Allow"] == "GET, HEAD"
    assert int(headers["Content-Length"]) == len(body)


@pytest.mark.parametrize(
    ("method", "target", "host", "expected_status"),
    [
        ("GET", JOURNAL_URL, "localhost", 200),
        ("GET", "/_ds/ds.css", "localhost", 200),
        ("GET", "/missing", "localhost", 404),
        ("POST", JOURNAL_URL, "localhost", 405),
        ("GET", JOURNAL_URL, "evil.example", 400),
        ("GET", "/demo-app/2026-11-25", "localhost", 500),
        ("UNKNOWN", JOURNAL_URL, "localhost", 501),
    ],
)
def test_all_responses_have_security_headers(
    address, journal_dir, method, target, host, expected_status
):
    (journal_dir / "demo-app/2026/2026-11-25.md").write_bytes(b"broken frontmatter")

    status, headers, body = request(address, method, target, host=host)

    assert status == expected_status
    assert {name: headers.get(name) for name in EXPECTED_SECURITY_HEADERS} == (
        EXPECTED_SECURITY_HEADERS
    )
    assert headers["Server"].strip() == "shipcast"
    assert int(headers["Content-Length"]) == len(body)
    assert not {"Cache-Control", "Last-Modified", "ETag"} & headers.keys()


def test_ipv6_server(journal_dir, design_dir):
    try:
        with socket.socket(socket.AF_INET6, socket.SOCK_STREAM) as probe:
            probe.bind(("::1", 0))
    except OSError as error:
        pytest.skip(f"IPv6 loopback unavailable: {error}")
    with serve.create_server("::1", 0, journal_dir, design_dir) as server:
        assert server.server_address[0] == "::1"
        assert server.address_family == socket.AF_INET6
        assert server.daemon_threads


@pytest.mark.parametrize(
    "target",
    [
        "/",
        "/demo-app/",
        "/demo-app/2026-11-25",
        "/Demo/2026-11-26",
        "/demo-app/2026-02-30",
        "/demo-app/20261126",
        "/_ds/../x",
        "/_ds/%2e%2e/x",
        "/_ds/..%2fx",
        "/_ds/%2e%2e%2fx",
        "/_ds/..%5cx",
        "//x",
        "//_ds/ds.css",
        "/_ds//ds.css",
        "/_ds/.x",
        "/_ds/%00",
        "/_ds/%ff",
        "/_ds/explanation-skeleton.html",
        "/_ds/vendor",
    ],
)
def test_missing_or_invalid_path_returns_generic_notice(address, journal_dir, design_dir, target):
    (design_dir / "explanation-skeleton.html").write_bytes(b"outside marker")
    (design_dir / ".x").write_bytes(b"outside marker")
    (design_dir.parent / "x").write_bytes(b"outside marker")

    status, headers, body = request(address, "GET", target)

    assert status == 404
    assert headers["Content-Type"] == "text/html; charset=utf-8"
    assert b'id="ds-source"' in body
    assert "ページが見つかりません".encode() in body
    assert str(journal_dir).encode() not in body
    # Both strings also occur in the notice's fixed example URL.
    if target not in {"/", "/demo-app/"}:
        assert target.encode() not in body
    assert b"outside marker" not in body


def test_symlinks_outside_either_root_are_not_served(address, tmp_path, journal_dir, design_dir):
    external = tmp_path / "external"
    (external / "2026").mkdir(parents=True)
    outside_journal = external / "2026/2026-11-26.md"
    outside_journal.write_bytes(JOURNAL_FIXTURE.read_bytes() + b"\noutside marker")
    outside_asset = external / "file.css"
    outside_asset.write_bytes(b"outside marker")
    (design_dir / "linked.css").symlink_to(outside_asset)
    (journal_dir / "demo-app/2026/2026-11-25.md").symlink_to(outside_journal)
    (journal_dir / "linked").symlink_to(external, target_is_directory=True)

    for target in ["/_ds/linked.css", "/demo-app/2026-11-25", "/linked/2026-11-26"]:
        status, _, body = request(address, "GET", target)
        assert status == 404
        assert b"outside marker" not in body


@pytest.fixture
def config_file(tmp_path, monkeypatch):
    path = tmp_path / "shipcast.toml"
    monkeypatch.setenv("SHIPCAST_CONFIG", str(path))
    return path


def test_finds_first_available_design_system(config_file, tmp_path, design_dir):
    first_repo = tmp_path / "first"
    second_repo = tmp_path / "second"
    first_design_dir = first_repo / "spec-dock/design-system"
    first_design_dir.mkdir(parents=True)
    (first_design_dir / "ds.css").touch()
    (first_design_dir / "ds.js").mkdir()
    (second_repo / "spec-dock").mkdir(parents=True)
    (second_repo / "spec-dock/design-system").symlink_to(design_dir, target_is_directory=True)
    config_file.write_text(
        f'[[repos]]\nid = "first"\npath = "{first_repo}"\n'
        f'[[repos]]\nid = "second"\npath = "{second_repo}"\n',
        encoding="utf-8",
    )

    assert serve.find_design_system(load_config()) == design_dir.resolve()


@pytest.mark.parametrize("scenario", ["no-repos", "repo-missing", "explicit-missing"])
def test_serve_diagnoses_missing_design_system(
    config_file, tmp_path, design_dir, monkeypatch, capsys, scenario
):
    def unexpected_server(*args):
        pytest.fail("No server should start without a design system")

    monkeypatch.setattr(serve, "create_server", unexpected_server)
    repo = tmp_path / "demo-app"
    (repo / "spec-dock").mkdir(parents=True)
    repos = f'[[repos]]\nid = "demo-app"\npath = "{repo}"\n'
    if scenario == "no-repos":
        text = ""
        expected = "登録したrepositoryがありません"
    elif scenario == "repo-missing":
        text = repos
        expected = str(repo / "spec-dock/design-system")
    else:
        (repo / "spec-dock/design-system").symlink_to(design_dir, target_is_directory=True)
        incomplete = tmp_path / "incomplete"
        incomplete.mkdir()
        (incomplete / "ds.css").touch()
        text = f'[serve]\ndesign_system_dir = "{incomplete}"\n' + repos
        expected = str(incomplete)
    config_file.write_text(text, encoding="utf-8")

    assert main(["serve"]) == 2
    captured = capsys.readouterr()
    assert captured.out == ""
    assert expected in captured.err
    assert str(config_file) in captured.err
    assert "[serve]" in captured.err
    assert 'design_system_dir = "/…/spec-dock/design-system"' in captured.err
    assert "spec-dock installation update" in captured.err


@pytest.mark.parametrize("contents", [None, "[broken"])
def test_serve_diagnoses_invalid_config(config_file, capsys, contents):
    if contents is not None:
        config_file.write_text(contents, encoding="utf-8")

    assert main(["serve"]) == 1
    captured = capsys.readouterr()
    assert captured.out == ""
    assert "shipcast serve:" in captured.err
    assert "直し方:" in captured.err


@pytest.mark.parametrize(
    ("options", "configured", "host", "port", "url_authority", "warns"),
    [
        ([], "", "127.0.0.1", 8765, "127.0.0.1:8765", False),
        (
            ["--host", "0.0.0.0", "--port", "9000"],
            "",
            "0.0.0.0",
            9000,
            "0.0.0.0:9000",
            True,
        ),
        (["--host", "::1"], "", "::1", 8765, "[::1]:8765", False),
        ([], 'host = "localhost"\nport = 9876\n', "localhost", 9876, "localhost:9876", False),
    ],
)
def test_serve_starts_and_closes_on_interrupt(
    config_file,
    design_dir,
    tmp_path,
    monkeypatch,
    capsys,
    options,
    configured,
    host,
    port,
    url_authority,
    warns,
):
    journal = tmp_path / "missing-journal"
    config_file.write_text(
        f'journal_dir = "{journal}"\n[serve]\ndesign_system_dir = "{design_dir}"\n' + configured,
        encoding="utf-8",
    )
    calls = []

    class InterruptedServer:
        def serve_forever(self):
            calls.append("serve")
            raise KeyboardInterrupt

        def server_close(self):
            calls.append("closed")

    def create_server(*args):
        calls.append(args)
        return InterruptedServer()

    monkeypatch.setattr(serve, "create_server", create_server)

    assert main(["serve", *options]) == 0
    assert calls == [(host, port, journal, design_dir.resolve()), "serve", "closed"]
    captured = capsys.readouterr()
    assert f"http://{url_authority}/<repo>/<YYYY-MM-DD>" in captured.out
    assert str(journal) in captured.out
    assert str(design_dir.resolve()) in captured.out
    assert "Ctrl+C" in captured.out
    assert "日誌の置き場がまだありません" in captured.err
    assert ("tailnetやLAN" in captured.err) is warns
    assert ("tailscale serve" in captured.err) is warns


@pytest.mark.parametrize("port", ["0", "65536", "invalid"])
def test_serve_rejects_invalid_cli_port(config_file, capsys, port):
    with pytest.raises(SystemExit) as error:
        main(["serve", "--port", port])

    assert error.value.code == 2
    assert "argument --port:" in capsys.readouterr().err


def test_serve_diagnoses_occupied_port(config_file, design_dir, capsys):
    config_file.write_text(f'[serve]\ndesign_system_dir = "{design_dir}"\n', encoding="utf-8")
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as listener:
        listener.bind(("127.0.0.1", 0))
        listener.listen()
        port = listener.getsockname()[1]

        assert main(["serve", "--port", str(port)]) == 1

    captured = capsys.readouterr()
    assert captured.out == ""
    assert f"127.0.0.1:{port} で待ち受けられません" in captured.err
    assert os.strerror(errno.EADDRINUSE) in captured.err
