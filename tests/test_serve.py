import pytest


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
    from shipcast.serve import split_path

    assert split_path(target) == expected


def test_resolve_inside(tmp_path):
    from shipcast.serve import resolve_inside

    root = tmp_path / "root"
    root.mkdir()
    outside = tmp_path / "outside"
    outside.mkdir()
    (root / "linked-out").symlink_to(outside, target_is_directory=True)
    (root / "linked-in").symlink_to(root / "inside", target_is_directory=True)
    alias = tmp_path / "alias"
    alias.symlink_to(root, target_is_directory=True)

    assert resolve_inside(alias, ("linked-in", "future.txt")) == root / "inside/future.txt"
    assert resolve_inside(root, ("linked-out", "future.txt")) is None


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
    from shipcast.serve import security_headers

    headers = security_headers()
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
    from shipcast.serve import host_allowed

    assert host_allowed(host) is expected
