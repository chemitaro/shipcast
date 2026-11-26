import re
import subprocess
import sys
from importlib.metadata import version
from pathlib import Path

import pytest

from shipcast.cli import main


def test_package_exposes_installed_version():
    from shipcast import __version__

    assert __version__ == version("shipcast")


def test_top_level_help_lists_commands(capsys):
    with pytest.raises(SystemExit) as exit_info:
        main(["--help"])

    assert exit_info.value.code == 0
    output = capsys.readouterr()
    for command in ("repo", "collect", "write", "run", "serve", "draft", "schedule"):
        assert re.search(rf"\b{command}\b", output.out)
    assert output.err == ""


@pytest.mark.parametrize(
    ("command", "subcommands"),
    [
        ("repo", ("add", "list")),
        ("draft", ("x",)),
        ("schedule", ("install", "uninstall")),
    ],
)
def test_group_help_lists_subcommands(command, subcommands, capsys):
    with pytest.raises(SystemExit) as exit_info:
        main([command, "--help"])

    assert exit_info.value.code == 0
    output = capsys.readouterr()
    for subcommand in subcommands:
        assert re.search(rf"\b{subcommand}\b", output.out)
    assert output.err == ""


def test_module_help_matches_cli_help(capsys):
    with pytest.raises(SystemExit) as exit_info:
        main(["--help"])
    assert exit_info.value.code == 0
    expected = capsys.readouterr()

    result = subprocess.run(
        [sys.executable, "-m", "shipcast", "--help"],
        capture_output=True,
        text=True,
        check=False,
    )

    assert result.returncode == 0
    assert result.stdout == expected.out
    assert result.stderr == expected.err == ""


@pytest.mark.parametrize(
    ("command", "issue_id"),
    [
        ("repo add", "iss-00009"),
        ("repo list", "iss-00009"),
        ("collect", "iss-00011"),
        ("write", "iss-00016"),
        ("run", "iss-00021"),
        ("serve", "iss-00017"),
        ("draft x", "iss-00020"),
        ("schedule install", "iss-00022"),
        ("schedule uninstall", "iss-00022"),
    ],
)
def test_unimplemented_leaf_reports_issue_without_writing(
    command, issue_id, tmp_path, monkeypatch, capsys
):
    monkeypatch.chdir(tmp_path)
    monkeypatch.setenv("HOME", str(tmp_path / "home"))
    for directory in ("CACHE", "CONFIG", "DATA", "STATE"):
        monkeypatch.setenv(f"XDG_{directory}_HOME", str(tmp_path / directory.lower()))
    monkeypatch.setenv("XDG_RUNTIME_DIR", str(tmp_path / "runtime"))

    assert main(command.split()) == 2

    output = capsys.readouterr()
    assert output.out == ""
    assert output.err == f"shipcast {command}: 未実装です（{issue_id} で作ります）\n"
    assert list(tmp_path.iterdir()) == []


@pytest.mark.parametrize(
    ("argv", "program"),
    [
        ([], "shipcast"),
        (["unknown"], "shipcast"),
        (["repo", "unknown"], "shipcast repo"),
        (["collect", "--unknown"], "shipcast"),
        (["repo"], "shipcast repo"),
        (["draft"], "shipcast draft"),
        (["schedule"], "shipcast schedule"),
    ],
)
def test_invalid_invocations_show_usage(argv, program, capsys):
    with pytest.raises(SystemExit) as exit_info:
        main(argv)

    assert exit_info.value.code == 2
    output = capsys.readouterr()
    assert output.err.startswith(f"usage: {program} ")
    assert output.out == ""


def test_version_shows_installed_version(capsys):
    with pytest.raises(SystemExit) as exit_info:
        main(["--version"])

    assert exit_info.value.code == 0
    output = capsys.readouterr()
    assert output.out == f"shipcast {version('shipcast')}\n"
    assert output.err == ""


def test_ci_runs_local_checks_for_pull_requests_and_main_pushes():
    root = Path(__file__).resolve().parents[1]
    workflow = (root / ".github/workflows/ci.yml").read_text(encoding="utf-8")

    assert "\non:\n  pull_request:\n  push:\n    branches: [main]\n" in workflow
    assert "\npermissions:\n  contents: read\n" in workflow
    checks = ("uv sync --locked", "uv run ruff check", "uv run pytest -q")
    assert "".join(f"      - run: {check}\n" for check in checks) in workflow


def test_agents_md_lists_checks_in_order_and_forbids_agy():
    root = Path(__file__).resolve().parents[1]
    agents = (root / "AGENTS.md").read_text(encoding="utf-8")

    checks = ("uv sync --locked", "uv run ruff check", "uv run pytest -q")
    positions = [agents.find(f"`{check}`") for check in checks]
    assert all(position >= 0 for position in positions)
    assert positions == sorted(positions)
    assert "`fake`" in agents
    assert "`agy`を呼ばない" in agents
