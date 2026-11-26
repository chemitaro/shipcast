from pathlib import Path

import pytest


@pytest.fixture(autouse=True)
def isolated_config(tmp_path, monkeypatch):
    monkeypatch.setenv("HOME", str(tmp_path / "home"))
    monkeypatch.setenv("SHIPCAST_CONFIG", str(tmp_path / "config" / "config.toml"))


def test_load_schema_one_example(tmp_path):
    from shipcast.config import (
        Config,
        ModelConfig,
        ModelsConfig,
        NetaConfig,
        RepoConfig,
        ServeConfig,
        load_config,
    )

    path = tmp_path / "example.toml"
    path.write_text(
        """
schema = 1
timezone = "Asia/Tokyo"
journal_dir = "~/.local/share/shipcast/journal"
state_dir = "~/.local/state/shipcast"

[models.analyst]
route = "codex"
model = "gpt-6.2-sol"
effort = "low"

[models.writer]
route = "antigravity"
model = "gemini-4-neon"
thinking = "high"

[serve]
host = "127.0.0.1"
port = 8765
design_system_dir = ""

[neta]
threshold = 6

[[repos]]
id = "sample-app"
path = "~/sample-app"
ref = "main"
title = "Sample App"
orca = true
""",
        encoding="utf-8",
    )

    home = tmp_path / "home"
    assert load_config(path) == Config(
        schema=1,
        timezone="Asia/Tokyo",
        journal_dir=home / ".local/share/shipcast/journal",
        state_dir=home / ".local/state/shipcast",
        models=ModelsConfig(
            analyst=ModelConfig("codex", "gpt-6.2-sol", "low", None),
            writer=ModelConfig("antigravity", "gemini-4-neon", None, "high"),
        ),
        serve=ServeConfig("127.0.0.1", 8765, None),
        neta=NetaConfig(6),
        repos=(RepoConfig("sample-app", home / "sample-app", "main", "Sample App", True),),
    )


def test_empty_and_partial_files_use_defaults(tmp_path):
    from dataclasses import replace

    from shipcast.config import ModelConfig, load_config

    path = tmp_path / "partial.toml"
    path.touch()
    empty = load_config(path)
    assert empty.repos == ()
    assert empty.schema == 1
    assert empty.timezone == "Asia/Tokyo"
    assert empty.serve.port == 8765
    assert empty.neta.threshold == 6
    assert empty.models.writer == ModelConfig("antigravity", "gemini-4-neon", None, "high")

    path.write_text('[models.writer]\nroute = "fake"\n', encoding="utf-8")
    assert load_config(path) == replace(
        empty,
        models=replace(empty.models, writer=ModelConfig("fake", "gemini-4-neon", None, "high")),
    )


@pytest.mark.parametrize("override", [None, "", "~/other.toml"])
def test_load_config_path(tmp_path, monkeypatch, override):
    from shipcast.config import config_path, load_config

    home = tmp_path / "home"
    if override is None:
        monkeypatch.delenv("SHIPCAST_CONFIG")
    else:
        monkeypatch.setenv("SHIPCAST_CONFIG", override)
    expected = home / ("other.toml" if override else ".config/shipcast/config.toml")
    expected.parent.mkdir(parents=True)
    expected.write_text('timezone = "UTC"\n', encoding="utf-8")
    assert config_path() == expected
    assert load_config().timezone == "UTC"


def test_repo_order_and_omitted_fields(tmp_path):
    from shipcast.config import RepoConfig, parse_config

    text = '[serve]\ndesign_system_dir = "~/templates"\n'
    names = ("third", "first", "second")
    for name in names:
        text += f'[[repos]]\nid = "{name}"\npath = "~/repos/{name}"\n'
    home = tmp_path / "home"
    config = parse_config(text, tmp_path / "config.toml")
    assert config.serve.design_system_dir == home / "templates"
    assert config.repos == tuple(
        RepoConfig(name, home / "repos" / name, "main", name, True) for name in names
    )


def test_invalid_toml_shows_path_and_line(tmp_path):
    from shipcast.config import ConfigError, load_config

    path = tmp_path / "bad.toml"
    path.write_text("# first\nschema = 1\ntimezone = @\n", encoding="utf-8")
    with pytest.raises(ConfigError) as error:
        load_config(path)
    assert str(path) in str(error.value)
    assert "line 3" in str(error.value)
    assert "直し方:" in str(error.value)


@pytest.mark.parametrize(
    ("text", "field"),
    [
        ("foo = 0", "foo"),
        ("schema = 2", "schema"),
        ('timezone = "Unknown/Zone"', "timezone"),
        ('journal_dir = "relative"', "journal_dir"),
        ('[models.writer]\nroute = "other"', "models.writer.route"),
        ("[serve]\nport = true", "serve.port"),
        ("[serve]\nport = 0", "serve.port"),
        ("[serve]\nport = 70000", "serve.port"),
        ("[neta]\nthreshold = 0", "neta.threshold"),
        ('[[repos]]\npath = "~/demo"', "repos[1].id"),
        ('[[repos]]\nid = "Bad"\npath = "~/demo"', "repos[1].id"),
        (
            '[[repos]]\nid = "demo"\npath = "~/demo"\n[[repos]]\nid = "demo"\npath = "~/other"',
            "repos[2].id",
        ),
        ('[[repos]]\nid = "demo"', "repos[1].path"),
        ('[[repos]]\nid = "demo"\npath = "relative"', "repos[1].path"),
        ('[[repos]]\nid = "demo"\npath = "~/demo"\norca = "yes"', "repos[1].orca"),
        ('[[repos]]\nid = "demo"\npath = "~/demo"\nfoo = 0', "repos[1].foo"),
    ],
)
def test_invalid_config_shows_field_and_hint(tmp_path, text, field):
    from shipcast.config import ConfigError, parse_config

    path = tmp_path / "bad.toml"
    with pytest.raises(ConfigError) as error:
        parse_config(text, path)
    assert error.value.path == path
    assert error.value.problem.startswith(f"{field}:")
    assert "直し方:" in str(error.value)


def test_missing_file_and_default_config_text(tmp_path):
    from shipcast.config import DEFAULT_CONFIG_TEXT, ConfigError, load_config, parse_config

    path = tmp_path / "home" / "missing.toml"
    with pytest.raises(ConfigError) as error:
        load_config(Path("~/missing.toml"))
    assert str(path) in str(error.value)
    assert "設定ファイルがありません" in str(error.value)
    assert "shipcast repo add" in str(error.value)
    assert not path.parent.exists()
    assert parse_config(DEFAULT_CONFIG_TEXT, path) == parse_config("", path)


def test_invalid_utf8_has_a_fix(tmp_path):
    from shipcast.config import ConfigError, load_config

    source = tmp_path / "bad-encoding.toml"
    source.write_bytes(b"\xff")
    with pytest.raises(ConfigError) as error:
        load_config(source)
    assert str(source) in str(error.value)
    assert "UTF-8" in str(error.value)
    assert "直し方:" in str(error.value)
