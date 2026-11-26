import os
import stat
import threading
from concurrent.futures import ThreadPoolExecutor
from dataclasses import replace
from pathlib import Path
from threading import Barrier

import pytest

from shipcast.cli import main
from shipcast.config import RepoConfig, load_config, parse_config


@pytest.fixture(autouse=True)
def config_file(tmp_path, monkeypatch):
    path = tmp_path / "config" / "config.toml"
    monkeypatch.setenv("HOME", str(tmp_path / "home"))
    monkeypatch.setenv("SHIPCAST_CONFIG", str(path))
    return path


@pytest.fixture
def make_repo(tmp_path):
    def create(name):
        path = tmp_path / "repos" / name
        marker = path / "spec-dock" / "workspace.json"
        marker.parent.mkdir(parents=True)
        marker.write_text('{"schema_version":4}', encoding="utf-8")
        return path.resolve()

    return create


def test_add_appends_with_default_and_explicit_fields(config_file, make_repo, capsys):
    config_file.parent.mkdir()
    config_file.touch()
    demo = make_repo("Demo Repo")
    sample = make_repo("sample-app")

    assert main(["repo", "add", str(demo)]) == 0
    assert capsys.readouterr() == (f"登録しました: demo-repo {demo}\n", "")
    assert load_config().repos == (RepoConfig("demo-repo", demo, "main", "Demo Repo", True),)

    assert (
        main(
            [
                "repo",
                "add",
                str(sample),
                "--id",
                "sample",
                "--title",
                "Sample App",
                "--ref",
                "next",
            ]
        )
        == 0
    )
    assert capsys.readouterr() == (f"登録しました: sample {sample}\n", "")
    assert load_config().repos == (
        RepoConfig("demo-repo", demo, "main", "Demo Repo", True),
        RepoConfig("sample", sample, "next", "Sample App", True),
    )


@pytest.mark.parametrize(
    "original",
    [b"# comment\n\nschema = 1\n", b"# comment\n\nschema = 1", b"# comment\r\n\r\nschema = 1\r\n"],
)
def test_add_keeps_original_bytes_and_previous_entry(config_file, make_repo, original):
    config_file.parent.mkdir()
    config_file.write_bytes(original)
    first = make_repo("first")
    second = make_repo("second")

    assert main(["repo", "add", str(first)]) == 0
    with_first = config_file.read_bytes()
    separator = b"\n" if original.endswith(b"\n") else b"\n\n"
    assert with_first.startswith(original + separator + b"[[repos]]\n")
    assert main(["repo", "add", str(second)]) == 0
    assert config_file.read_bytes().startswith(with_first + b"\n[[repos]]\n")
    assert [repo.id for repo in load_config().repos] == ["first", "second"]


@pytest.mark.parametrize("target_kind", ["missing", "directory", "file"])
@pytest.mark.parametrize("config_exists", [False, True])
def test_add_invalid_target_leaves_config_alone(
    tmp_path, config_file, capsys, target_kind, config_exists
):
    path = tmp_path / "invalid-target"
    if target_kind == "directory":
        path.mkdir()
    if target_kind == "file":
        path.touch()

    original = b"# original\n"
    if config_exists:
        config_file.parent.mkdir()
        config_file.write_bytes(original)

    assert main(["repo", "add", str(path)]) == 1
    output = capsys.readouterr()
    assert output.out == ""
    assert output.err.startswith("shipcast repo add:")
    assert "直し方:" in output.err
    if target_kind == "directory":
        assert "SpecDockを使っていません" in output.err
    if config_exists:
        assert config_file.read_bytes() == original
    else:
        assert not config_file.parent.exists()


@pytest.mark.parametrize("duplicate", ["id", "path", "path-with-slash", "path-with-parent"])
def test_add_duplicate_keeps_config_unchanged(config_file, make_repo, capsys, duplicate):
    first = make_repo("first")
    other = make_repo("other")
    assert main(["repo", "add", str(first)]) == 0
    capsys.readouterr()
    original = config_file.read_bytes()

    path, repo_id = {
        "id": (str(other), "first"),
        "path": (str(first), "different"),
        "path-with-slash": (f"{first}/", "different"),
        "path-with-parent": (f"{other}/../first", "different"),
    }[duplicate]
    assert main(["repo", "add", path, "--id", repo_id]) == 1
    output = capsys.readouterr()
    assert output.out == ""
    assert "すでに first として登録されています" in output.err
    assert "直し方:" in output.err
    assert config_file.read_bytes() == original


def test_add_creates_missing_config_with_defaults(config_file, make_repo, capsys):
    path = make_repo("sample-app")
    assert not config_file.parent.exists()

    assert main(["repo", "add", str(path)]) == 0
    assert capsys.readouterr() == (
        f"設定ファイルを作りました: {config_file}\n登録しました: sample-app {path}\n",
        "",
    )
    created = load_config()
    assert created.repos == (RepoConfig("sample-app", path, "main", "sample-app", True),)
    assert replace(created, repos=()) == parse_config("", config_file)
    assert config_file.read_bytes().startswith("# shipcast の設定ファイル".encode())


@pytest.mark.parametrize(
    ("original", "message"),
    [
        (b"timezone = @\n", "TOMLの文法の誤り"),
        (b"schema = 2\n", "schema:"),
        (b"\xff", "UTF-8"),
        (
            b'repos = [{id = "other", path = "/example/other"}]\n',
            "`repos` を `[[repos]]` の形で書いてください",
        ),
    ],
)
def test_add_rejects_invalid_or_inline_config(config_file, make_repo, capsys, original, message):
    path = make_repo("sample-app")
    config_file.parent.mkdir()
    config_file.write_bytes(original)

    assert main(["repo", "add", str(path)]) == 1
    output = capsys.readouterr()
    assert output.out == ""
    assert output.err.startswith("shipcast repo add:")
    assert message in output.err
    assert "直し方:" in output.err
    assert config_file.read_bytes() == original


def test_add_round_trips_strings_and_preserves_link_mode_and_source(
    config_file,
    make_repo,
    tmp_path,
):
    from shipcast.config import toml_string

    path = make_repo('デモ "\\\t\n')
    title = '題名 "\\\t\n\r\x7f'
    assert parse_config(
        f'[[repos]]\nid = "sample"\npath = {toml_string(str(path))}\n'
        f"title = {toml_string(title)}\n",
        config_file,
    ).repos == (RepoConfig("sample", path, "main", title, True),)

    backing = tmp_path / "backing.toml"
    backing.write_bytes(b"# original\n")
    backing.chmod(0o640)
    config_file.parent.mkdir()
    config_file.symlink_to(backing)
    before = {
        file.relative_to(path): file.stat().st_mtime_ns
        for file in path.rglob("*")
        if file.is_file()
    }

    assert main(["repo", "add", str(path), "--id", "sample", "--title", title]) == 0
    assert load_config().repos == (RepoConfig("sample", path, "main", title, True),)
    assert config_file.is_symlink()
    assert config_file.readlink() == backing
    assert backing.read_bytes().startswith(b"# original\n\n[[repos]]\n")
    assert stat.S_IMODE(backing.stat().st_mode) == 0o640
    assert {
        file.relative_to(path): file.stat().st_mtime_ns
        for file in path.rglob("*")
        if file.is_file()
    } == before


@pytest.mark.parametrize(
    ("name", "expected"),
    [
        ("Demo Repo", "demo-repo"),
        ("--x__y--", "x-y"),
        ("日誌", ""),
    ],
)
def test_derive_repo_id(name, expected):
    from shipcast.config import derive_repo_id

    assert derive_repo_id(name) == expected


@pytest.mark.parametrize(
    ("name", "options", "message"),
    [
        ("日誌", [], "--id"),
        ("demo", ["--id", "Bad"], "--id"),
        ("demo", ["--title", ""], "--title"),
        ("demo", ["--ref", ""], "--ref"),
    ],
)
def test_add_rejects_invalid_names_and_empty_options(
    config_file, make_repo, capsys, name, options, message
):
    path = make_repo(name)
    assert main(["repo", "add", str(path), *options]) == 1
    output = capsys.readouterr()
    assert output.out == ""
    assert message in output.err
    assert "直し方:" in output.err
    assert not config_file.parent.exists()


def test_add_preserves_original_and_removes_temp_when_replacement_fails(
    config_file,
    make_repo,
    monkeypatch,
):
    path = make_repo("sample-app")
    config_file.parent.mkdir()
    original = b"# original\n"
    config_file.write_bytes(original)

    def fail_replace(*args):
        raise OSError("example replacement failure")

    monkeypatch.setattr("os.replace", fail_replace)
    with pytest.raises(OSError, match="example replacement failure"):
        main(["repo", "add", str(path)])
    assert list(config_file.parent.iterdir()) == [config_file]
    assert config_file.read_bytes() == original


def test_add_requires_path(config_file, capsys):
    with pytest.raises(SystemExit) as error:
        main(["repo", "add"])

    assert error.value.code == 2
    assert capsys.readouterr().err.startswith("usage: shipcast repo add ")
    assert not config_file.parent.exists()


def test_add_rejects_config_link_into_target(config_file, make_repo, capsys):
    target = make_repo("sample-app")
    backing = target / "original.toml"
    original = b"# original\n"
    backing.write_bytes(original)
    config_file.parent.mkdir()
    config_file.symlink_to(backing)

    assert main(["repo", "add", str(target)]) == 1
    output = capsys.readouterr()
    assert output.out == ""
    assert "repositoryの外" in output.err
    assert backing.read_bytes() == original
    assert config_file.is_symlink()


@pytest.mark.skipif(os.name != "posix", reason="Directory locking is available on POSIX")
def test_concurrent_adds_keep_both_entries(config_file, make_repo, monkeypatch):
    from shipcast.config import add_repo

    first, second = make_repo("first"), make_repo("second")
    config_file.parent.mkdir()
    config_file.touch()
    source = config_file.resolve()
    original_read = Path.read_bytes
    initial_reads = Barrier(2)
    local = threading.local()

    def read_bytes(path):
        data = original_read(path)
        if path.resolve() == source and not getattr(local, "read_config", False):
            local.read_config = True
            initial_reads.wait(timeout=5)
        return data

    with monkeypatch.context() as patch:
        patch.setattr(Path, "read_bytes", read_bytes)
        with ThreadPoolExecutor(max_workers=2) as pool:
            first_result = pool.submit(add_repo, first)
            second_result = pool.submit(add_repo, second)
            assert first_result.result().repo.id == "first"
            assert second_result.result().repo.id == "second"

    assert {repo.id for repo in load_config().repos} == {"first", "second"}
