import plistlib
import shlex
import stat
import subprocess
from pathlib import Path
from types import SimpleNamespace

import pytest

from shipcast import schedule
from shipcast.cli import main

PROGRAM = "/Users/example/.local/bin/shipcast"
SERVICE = "gui/501/com.shipcast.nightly"


@pytest.fixture(autouse=True)
def isolate_launch_agents(tmp_path, monkeypatch):
    monkeypatch.setenv("HOME", str(tmp_path / "home"))

    def forbid_subprocess(*args, **kwargs):
        pytest.fail("schedule の試験では subprocess.run を呼べません")

    monkeypatch.setattr(schedule.subprocess, "run", forbid_subprocess)


@pytest.fixture
def schedule_cli(tmp_path, monkeypatch):
    home = tmp_path / "home"
    state = tmp_path / "state"
    config = tmp_path / "config.toml"
    config.write_text(f'state_dir = "{state}"\n', encoding="utf-8")
    monkeypatch.setenv("SHIPCAST_CONFIG", str(config))
    monkeypatch.setenv("PATH", "/usr/bin:/bin")
    monkeypatch.setenv("SECRET_TOKEN", "example-secret")
    monkeypatch.setattr(schedule.shutil, "which", lambda name: PROGRAM)
    monkeypatch.setattr("os.getuid", lambda: 501)

    calls = []
    replies = {}

    def fake_launchctl(*args):
        calls.append(args)
        reply = replies[args[0]]
        if isinstance(reply, Exception):
            raise reply
        return subprocess.CompletedProcess(args, *reply)

    monkeypatch.setattr(schedule, "launchctl", fake_launchctl)
    return SimpleNamespace(
        home=home,
        state=state,
        config=config,
        plist=home / "Library/LaunchAgents/com.shipcast.nightly.plist",
        calls=calls,
        replies=replies,
    )


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


def test_install_writes_plist_without_loading(schedule_cli, tmp_path, monkeypatch, capsys):
    home = tmp_path / "home with spaces"
    plist = home / "Library/LaunchAgents/com.shipcast.nightly.plist"
    logs = schedule_cli.state / "logs"
    interpreter = tmp_path / "python"
    monkeypatch.setenv("HOME", str(home))
    monkeypatch.setattr("sys.executable", str(interpreter))

    assert main(["schedule", "install"]) == 0
    assert logs.is_dir()
    assert stat.S_IMODE(plist.stat().st_mode) == 0o644
    assert plistlib.loads(plist.read_bytes()) == {
        "Label": "com.shipcast.nightly",
        "ProgramArguments": [PROGRAM, "run"],
        "StartCalendarInterval": {"Hour": 3, "Minute": 0},
        "StandardOutPath": str(logs / "nightly.out.log"),
        "StandardErrorPath": str(logs / "nightly.err.log"),
        "EnvironmentVariables": {
            "PATH": "/usr/bin:/bin",
            "SHIPCAST_CONFIG": str(schedule_cli.config),
        },
        "ProcessType": "Background",
    }

    out = capsys.readouterr().out
    assert f"plist を書きました: {plist}" in out
    assert f"毎日 03:00 に実行します: {PROGRAM} run" in out
    assert f"ログの置き場: {logs}" in out
    assert f"launchctl bootstrap gui/501 {shlex.quote(str(plist))}" in out
    assert f"launchctl bootout {SERVICE}" in out
    assert f"フルディスクアクセスに次を足してください: {interpreter.resolve()}" in out

    plist.write_bytes(b"previous plist")
    assert main(["schedule", "install"]) == 0
    assert "plist を置き換えました:" in capsys.readouterr().out
    assert plistlib.loads(plist.read_bytes())["Label"] == "com.shipcast.nightly"
    assert list(plist.parent.iterdir()) == [plist]
    assert schedule_cli.calls == []


@pytest.mark.parametrize(
    ("bootstrap", "expected", "message"),
    [
        ((0, "", ""), 0, f"読み込みました: {SERVICE}"),
        (
            (1, "", "details\nBootstrap failed: 5: Input/output error\n\n"),
            1,
            "読み込みに失敗しました: Bootstrap failed: 5: Input/output error",
        ),
        ((2, "stdout details\nlast line\n", ""), 1, "読み込みに失敗しました: last line"),
    ],
)
def test_install_boots_out_before_bootstrap(schedule_cli, capsys, bootstrap, expected, message):
    schedule_cli.replies.update(bootout=(1, "", "not loaded"), bootstrap=bootstrap)
    assert main(["schedule", "install", "--load"]) == expected
    assert schedule_cli.calls == [
        ("bootout", SERVICE),
        ("bootstrap", "gui/501", str(schedule_cli.plist)),
    ]
    assert schedule_cli.plist.is_file()
    output = capsys.readouterr()
    if expected == 0:
        assert message in output.out
    else:
        assert message in output.err
        assert f"launchctl bootout {SERVICE}" in output.err
        assert "--load" in output.err


def test_install_load_when_launchctl_is_missing(schedule_cli, capsys):
    schedule_cli.replies["bootout"] = FileNotFoundError()
    assert main(["schedule", "install", "--load"]) == 1
    assert "launchctl が見つかりません" in capsys.readouterr().err
    assert schedule_cli.plist.is_file()
    assert schedule_cli.calls == [("bootout", SERVICE)]


@pytest.mark.parametrize(
    "problem", ["missing-program", "checkout", "missing-config", "config-directory"]
)
def test_install_checks_inputs_before_writing(schedule_cli, monkeypatch, capsys, problem):
    match problem:
        case "missing-program":
            monkeypatch.setattr(schedule.shutil, "which", lambda name: None)
        case "checkout":
            monkeypatch.setattr(schedule.shutil, "which", lambda name: "/tmp/x/.venv/bin/shipcast")
        case "missing-config":
            schedule_cli.config.unlink()
        case "config-directory":
            schedule_cli.config.unlink()
            schedule_cli.config.mkdir()

    assert main(["schedule", "install"]) == 1
    err = capsys.readouterr().err
    assert "shipcast schedule install:" in err
    assert "直し方:" in err
    assert not (schedule_cli.home / "Library").exists()
    assert not (schedule_cli.state / "logs").exists()
    assert schedule_cli.calls == []


def test_install_reports_a_blocked_launch_agents_directory(schedule_cli, capsys):
    agents = schedule_cli.plist.parent
    agents.parent.mkdir(parents=True)
    agents.write_text("not a directory", encoding="utf-8")
    assert main(["schedule", "install"]) == 1
    err = capsys.readouterr().err
    assert "shipcast schedule install: 書き出せません:" in err
    assert "Traceback" not in err
    assert agents.read_text(encoding="utf-8") == "not a directory"


def test_install_cleans_up_if_replacing_plist_fails(schedule_cli, monkeypatch, capsys):
    plist = schedule_cli.plist
    plist.parent.mkdir(parents=True)
    plist.write_bytes(b"previous plist")

    def refuse_replace(source, target):
        assert source.parent == target.parent
        raise PermissionError("replacement denied")

    monkeypatch.setattr("os.replace", refuse_replace)
    assert main(["schedule", "install"]) == 1
    assert "書き出せません: replacement denied" in capsys.readouterr().err
    assert plist.read_bytes() == b"previous plist"
    assert list(plist.parent.iterdir()) == [plist]


def test_uninstall_removes_plist_without_loading_config_or_calling_launchctl(schedule_cli, capsys):
    schedule_cli.config.unlink()
    plist = schedule_cli.plist
    plist.parent.mkdir(parents=True)
    plist.touch()

    assert main(["schedule", "uninstall"]) == 0
    assert not plist.exists()
    out = capsys.readouterr().out
    assert f"plist を消しました: {plist}" in out
    assert f"launchctl bootout {SERVICE}" in out

    assert main(["schedule", "uninstall"]) == 0
    assert f"登録はありません: {plist}" in capsys.readouterr().out
    assert schedule_cli.calls == []


@pytest.mark.parametrize("success", [True, False])
def test_uninstall_unloads_before_deleting_even_when_bootout_fails(
    schedule_cli, monkeypatch, capsys, success
):
    plist = schedule_cli.plist
    plist.parent.mkdir(parents=True)
    plist.touch()
    schedule_cli.replies["bootout"] = (
        (0, "", "") if success else (1, "", "Boot-out failed: 3: No such process")
    )
    fake_launchctl = schedule.launchctl

    def check_plist_before_unload(*args):
        assert plist.is_file()
        return fake_launchctl(*args)

    monkeypatch.setattr(schedule, "launchctl", check_plist_before_unload)
    assert main(["schedule", "uninstall", "--unload"]) == 0
    assert schedule_cli.calls == [("bootout", SERVICE)]
    assert not plist.exists()
    output = capsys.readouterr()
    if success:
        assert f"外しました: {SERVICE}" in output.out
    else:
        assert "警告: 外せませんでした" in output.err
        assert "Boot-out failed: 3: No such process" in output.err


def test_uninstall_reports_a_plist_it_cannot_delete(schedule_cli, capsys):
    schedule_cli.plist.mkdir(parents=True)
    assert main(["schedule", "uninstall"]) == 1
    assert "shipcast schedule uninstall: plist を消せません:" in capsys.readouterr().err
    assert schedule_cli.plist.is_dir()
    assert schedule_cli.calls == []


@pytest.mark.parametrize(("command", "flag"), [("install", "--load"), ("uninstall", "--unload")])
def test_schedule_help_shows_opt_in_flag(command, flag, capsys):
    with pytest.raises(SystemExit) as exc:
        main(["schedule", command, "--help"])
    assert exc.value.code == 0
    assert flag in capsys.readouterr().out
