import plistlib
from pathlib import Path

import pytest

from shipcast import schedule


def test_build_plist(tmp_path):
    program = Path("/Users/example/.local/bin/shipcast")
    logs = Path("/Users/example/.local/state/shipcast/logs")
    environment = {"PATH": "/usr/bin:/bin"}
    data = schedule.build_plist(program, logs, environment)

    assert data.startswith(b"<?xml")
    assert plistlib.loads(data) == {
        "Label": "com.shipcast.nightly",
        "ProgramArguments": ["/Users/example/.local/bin/shipcast", "run"],
        "StartCalendarInterval": {"Hour": 3, "Minute": 0},
        "StandardOutPath": "/Users/example/.local/state/shipcast/logs/nightly.out.log",
        "StandardErrorPath": "/Users/example/.local/state/shipcast/logs/nightly.err.log",
        "EnvironmentVariables": environment,
        "ProcessType": "Background",
    }
    assert data == schedule.build_plist(program, logs, environment)
    assert "EnvironmentVariables" not in plistlib.loads(schedule.build_plist(program, logs, {}))
    for invalid_program, invalid_logs in [(Path("shipcast"), logs), (program, Path("~/logs"))]:
        with pytest.raises(ValueError):
            schedule.build_plist(invalid_program, invalid_logs, {})
    schedule.build_plist(tmp_path / "shipcast", tmp_path / "logs", {})
    assert list(tmp_path.iterdir()) == []


def test_nightly_environment_expands_config_and_copies_only_allowed_keys(tmp_path, monkeypatch):
    monkeypatch.setenv("HOME", str(tmp_path))
    assert schedule.nightly_environment(
        {"PATH": "/a:/b", "SHIPCAST_CONFIG": "~/c/config.toml", "SECRET_TOKEN": "x"}
    ) == {"PATH": "/a:/b", "SHIPCAST_CONFIG": str(tmp_path / "c/config.toml")}
    assert schedule.nightly_environment({"PATH": "/a:/b"}) == {"PATH": "/a:/b"}
    assert schedule.nightly_environment({"SECRET_TOKEN": "x"}) == {}
    assert schedule.nightly_environment({"SHIPCAST_CONFIG": ""}) == {
        "SHIPCAST_CONFIG": str(tmp_path / ".config/shipcast/config.toml")
    }


def test_find_program_preserves_link_but_rejects_checkout_executables(tmp_path, monkeypatch):
    program = "/Users/example/.local/bin/shipcast"
    monkeypatch.setattr(schedule.shutil, "which", lambda name: program)
    assert schedule.find_program() == Path(program)

    program = None
    with pytest.raises(schedule.ScheduleError, match=r"直し方: .*uv tool install"):
        schedule.find_program()

    program = "/tmp/x/.venv/bin/shipcast"
    with pytest.raises(schedule.ScheduleError, match=r"checkout の \.venv"):
        schedule.find_program()

    link = tmp_path / "bin/shipcast"
    checkout_executable = tmp_path / ".venv/bin/shipcast"
    checkout_executable.parent.mkdir(parents=True)
    checkout_executable.touch()
    link.parent.mkdir()
    link.symlink_to(checkout_executable)
    program = str(link)
    with pytest.raises(schedule.ScheduleError, match=r"checkout の \.venv"):
        schedule.find_program()

    tool_executable = tmp_path / "tools/shipcast/bin/shipcast"
    tool_executable.parent.mkdir(parents=True)
    tool_executable.touch()
    link.unlink()
    link.symlink_to(tool_executable)
    assert schedule.find_program() == link
