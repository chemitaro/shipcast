import errno
import fcntl
import json
import sqlite3
from contextlib import closing
from datetime import UTC, date, datetime, time, timedelta
from types import SimpleNamespace
from zoneinfo import ZoneInfo

import pytest

from shipcast.cli import main
from shipcast.collect.base import CollectError, CollectResult
from shipcast.config import load_config
from shipcast.model import Event, event_id, journal_path, parse_journal
from shipcast.models import RouteFailed, get_route
from shipcast.state import Store

REPOS = ("demo-app", "other-app")
TOKYO = ZoneInfo("Asia/Tokyo")
NOW = datetime(2026, 11, 26, 3, tzinfo=TOKYO)
DAY = date(2026, 11, 25)


@pytest.mark.parametrize(
    ("instant", "expected"),
    [
        ("2026-11-25T18:00:00+00:00", date(2026, 11, 25)),
        ("2026-11-26T00:30:00+09:00", date(2026, 11, 25)),
        ("2026-03-01T03:00:00+09:00", date(2026, 2, 28)),
    ],
)
def test_previous_day_uses_local_calendar(instant, expected):
    from shipcast.run import previous_day

    assert previous_day(ZoneInfo("Asia/Tokyo"), datetime.fromisoformat(instant)) == expected


def test_previous_day_reads_the_clock_in_the_requested_zone(monkeypatch):
    from shipcast import run

    tokyo = ZoneInfo("Asia/Tokyo")

    class Clock(datetime):
        @classmethod
        def now(cls, tz=None):
            assert tz == tokyo
            return datetime(2026, 11, 25, 18, tzinfo=UTC).astimezone(tz)

    monkeypatch.setattr(run, "datetime", Clock)
    assert run.previous_day(tokyo) == date(2026, 11, 25)


@pytest.fixture
def run_cli(tmp_path, monkeypatch):
    from shipcast import run

    config_path = tmp_path / "config.toml"
    state_dir = tmp_path / "state"
    journal_dir = tmp_path / "journal"
    config_header = f"""\
timezone = "Asia/Tokyo"
state_dir = "{state_dir}"
journal_dir = "{journal_dir}"

[models.analyst]
route = "fake"
model = "fake-analyst"

[models.writer]
route = "fake"
model = "fake-writer"
"""
    repo_tables = []
    for repo_id in REPOS:
        path = tmp_path / repo_id
        path.mkdir()
        repo_tables.append(f'\n[[repos]]\nid = "{repo_id}"\npath = "{path}"\n')
    config_path.write_text(config_header + "".join(repo_tables), encoding="utf-8")
    monkeypatch.setenv("SHIPCAST_CONFIG", str(config_path))

    class Collector:
        name = "git"
        calls = []
        errors = {}

        def collect(self, repo, day, tz):
            assert tz == TOKYO
            self.calls.append(repo.id)
            if repo.id in self.errors:
                raise CollectError(self.errors[repo.id])
            event = Event(
                event_id(self.name, repo.id, "fixture-commit"),
                repo.id,
                self.name,
                "commit",
                datetime.combine(day, time(12), tz),
                "架空の出来事",
            )
            return CollectResult((event,), ("試験用の警告",))

    class Clock(datetime):
        current = NOW

        @classmethod
        def now(cls, tz=None):
            assert tz == TOKYO
            return cls.current.astimezone(tz)

    def analyze(prompt, system, want_json):
        events = json.loads(prompt)["events"]
        return json.dumps(
            {
                "stories": [
                    {
                        "title": "見本の話題",
                        "what": "見本を作成",
                        "why": "動作を確認",
                        "notice": ["試験用の変更"],
                        "neta": {"score": 1},
                        "event_ids": [event["id"] for event in events],
                    }
                ]
            }
        )

    def write(prompt, system, want_json):
        return json.dumps(
            {
                "lead": "今日の要約です。",
                "summary": ["見本を作成"],
                "story": "### 見本\n\n本文です。",
            }
        )

    replies = {"fake-analyst": analyze, "fake-writer": write}

    def route(model):
        assert model.route == "fake"
        return get_route(model, env={}, responder=replies[model.model])

    collector = Collector()
    monkeypatch.setattr(run, "COLLECTORS", (collector,))
    monkeypatch.setattr(run, "get_route", route)
    monkeypatch.setattr(run, "datetime", Clock)
    return SimpleNamespace(
        module=run,
        config_path=config_path,
        config_header=config_header,
        state_dir=state_dir,
        journal_dir=journal_dir,
        collector=collector,
        clock=Clock,
        replies=replies,
    )


def test_run_help_shows_repo_and_date(capsys):
    with pytest.raises(SystemExit) as captured:
        main(["run", "--help"])

    assert captured.value.code == 0
    output = capsys.readouterr().out
    assert "--repo ID" in output and "--date YYYY-MM-DD" in output


@pytest.mark.parametrize("selected", [False, True])
def test_run_writes_and_records_selected_repositories(run_cli, monkeypatch, capsys, selected):
    run = run_cli.module
    from shipcast.write import write_day

    extensions_passed = []

    def capture_extensions(*args, **kwargs):
        extensions_passed.append(kwargs["extensions"])
        return write_day(*args, **kwargs)

    monkeypatch.setattr(run, "write_day", capture_extensions)
    day = date(2026, 11, 20) if selected else DAY
    args = ["run", "--repo", REPOS[0], "--date", str(day)] if selected else ["run"]
    expected = REPOS[:1] if selected else REPOS

    assert main(args) == 0
    assert run_cli.collector.calls == list(expected)
    output = capsys.readouterr()
    lines = []
    with Store(run_cli.state_dir) as store:
        for repo_id in REPOS:
            path = journal_path(run_cli.journal_dir, repo_id, day)
            runs = store.runs_for(repo_id)
            if repo_id not in expected:
                assert not path.exists() and runs == []
                continue
            assert path.is_file()
            (record,) = runs
            assert (record.result, record.error) == ("ok", "")
            assert record.started_at.utcoffset() is not None
            assert record.finished_at.utcoffset() is not None
            assert record.started_at <= record.finished_at
            lines.append(f"{repo_id} {day}: 日誌を書きました（出来事 1件、話題 1件）: {path}")
            assert f"shipcast run: 警告: {repo_id}: git: 試験用の警告" in output.err
        assert extensions_passed == [run.journal_extensions_for(store, load_config())] * len(
            expected
        )
        assert extensions_passed == [None] * len(expected)
    assert output.out.splitlines() == [
        *lines,
        f"shipcast run: {day}: 成功 {len(expected)}件、失敗 0件",
    ]


@pytest.mark.parametrize(
    ("failure", "diagnostic"),
    [
        ("collect", "git: 試験用の収集エラー"),
        ("writer", "書き手の応答が2回とも決まった形になりませんでした"),
        ("unexpected", "RuntimeError: 試験用"),
    ],
)
def test_run_records_failure_and_continues(run_cli, monkeypatch, capsys, failure, diagnostic):
    failed_repo, next_repo = REPOS
    attempts = []
    if failure == "collect":
        run_cli.collector.errors[failed_repo] = "試験用の収集エラー"
    elif failure == "writer":
        reply = run_cli.replies["fake-writer"]

        def fail_twice(prompt, system, want_json):
            attempts.append(prompt)
            if len(attempts) <= 2:
                return "{}"
            return reply(prompt, system, want_json)

        run_cli.replies["fake-writer"] = fail_twice
    else:
        write_day = run_cli.module.write_day

        def fail_first(store, repo_id, day, **kwargs):
            if repo_id == failed_repo:
                raise RuntimeError("試験用")
            return write_day(store, repo_id, day, **kwargs)

        monkeypatch.setattr(run_cli.module, "write_day", fail_first)

    assert main(["run"]) == 1
    output = capsys.readouterr()
    assert f"shipcast run: 失敗: {failed_repo}: {diagnostic}" in output.err
    assert "Traceback" not in output.err
    assert f"{failed_repo} {DAY}: 失敗しました（理由は標準エラー）" in output.out
    assert f"{next_repo} {DAY}: 日誌を書きました" in output.out
    assert f"shipcast run: {DAY}: 成功 1件、失敗 1件" in output.out
    assert not journal_path(run_cli.journal_dir, failed_repo, DAY).exists()
    assert journal_path(run_cli.journal_dir, next_repo, DAY).is_file()
    with Store(run_cli.state_dir) as store:
        (failed,) = store.runs_for(failed_repo)
        (succeeded,) = store.runs_for(next_repo)
    assert failed.result == "failed" and diagnostic in failed.error
    assert (succeeded.result, succeeded.error) == ("ok", "")
    if failure == "writer":
        assert len(attempts) == 3


def test_run_continues_after_a_recording_error(run_cli, monkeypatch, capsys):
    failed_repo, next_repo = REPOS
    record_run = Store.record_run

    def fail_first(store, record):
        if record.repo_id == failed_repo:
            raise OSError("試験用の記録エラー")
        record_run(store, record)

    monkeypatch.setattr(Store, "record_run", fail_first)
    assert main(["run"]) == 1
    output = capsys.readouterr()
    assert f"shipcast run: 記録に失敗しました: {failed_repo}: 試験用の記録エラー" in output.err
    assert "Traceback" not in output.err
    assert journal_path(run_cli.journal_dir, next_repo, DAY).is_file()
    with Store(run_cli.state_dir) as store:
        assert store.runs_for(failed_repo) == []
        (succeeded,) = store.runs_for(next_repo)
        assert succeeded.result == "ok"


@pytest.mark.parametrize("unknown_repo", [True, False])
def test_run_rejects_invalid_repository_selection_before_creating_state(
    run_cli, capsys, unknown_repo
):
    if unknown_repo:
        args = ["run", "--repo", "missing-app"]
        diagnostic = "登録されていないrepositoryです: missing-app"
        hint = "`shipcast repo list`"
    else:
        run_cli.config_path.write_text(run_cli.config_header, encoding="utf-8")
        args = ["run"]
        diagnostic = "登録されたrepositoryはありません"
        hint = "`shipcast repo add <path>`"

    assert main(args) == 1
    output = capsys.readouterr()
    assert f"shipcast run: {diagnostic}" in output.err
    assert hint in output.err
    assert not run_cli.state_dir.exists()
    assert not run_cli.journal_dir.exists()


@pytest.mark.parametrize("marked", [False, True])
def test_run_records_route_setup_failure_for_each_repository(run_cli, monkeypatch, capsys, marked):
    reason = "試験用の経路の失敗"
    if marked:
        reason += ": Operation not permitted"

    def fail_route(config):
        raise RouteFailed("fake", reason=reason)

    monkeypatch.setattr(run_cli.module, "get_route", fail_route)
    assert main(["run"]) == 1
    assert run_cli.collector.calls == []
    assert not run_cli.journal_dir.exists()
    output = capsys.readouterr()
    diagnostic = "shipcast run: モデルの経路を作れません:"
    assert diagnostic in output.err
    assert ("フルディスクアクセス" in output.err) is marked
    with Store(run_cli.state_dir) as store:
        for repo_id in REPOS:
            (record,) = store.runs_for(repo_id)
            assert record.result == "failed"
            assert record.started_at == record.finished_at
            assert diagnostic in record.error and reason in record.error
            assert ("フルディスクアクセス" in record.error) is marked


def test_run_reports_unusable_state_directory(run_cli, monkeypatch, capsys):
    run_cli.state_dir.write_text("ディレクトリではない", encoding="utf-8")

    def unexpected_route(config):
        pytest.fail("状態の置き場を開けないときに経路を作りました")

    monkeypatch.setattr(run_cli.module, "get_route", unexpected_route)
    assert main(["run"]) == 1
    error = capsys.readouterr().err
    assert "shipcast run: 状態の置き場を開けません:" in error
    assert "直し方:" in error


@pytest.mark.parametrize(
    ("invalid_config", "diagnostic"),
    [(True, "設定ファイルがありません"), (False, "設定ファイルを開けません:")],
)
def test_run_reports_config_errors_before_creating_state(
    run_cli, capsys, invalid_config, diagnostic
):
    run_cli.config_path.unlink()
    if not invalid_config:
        run_cli.config_path.mkdir()

    assert main(["run"]) == 1
    error = capsys.readouterr().err
    assert "shipcast run:" in error and diagnostic in error and "直し方:" in error
    assert not run_cli.state_dir.exists()


def test_run_skips_locked_state_before_opening_store_or_routes(run_cli, monkeypatch, capsys):
    run_cli.state_dir.mkdir()
    lock_path = run_cli.state_dir / "run.lock"

    def unexpected_route(config):
        pytest.fail("ロックが取れないときに経路を作りました")

    with lock_path.open("w") as lock, monkeypatch.context() as blocked:
        blocked.setattr(run_cli.module, "get_route", unexpected_route)
        fcntl.flock(lock, fcntl.LOCK_EX)

        assert main(["run"]) == 0
        output = capsys.readouterr()
        assert output.out == ""
        assert output.err.splitlines() == [
            f"shipcast run: 前の実行が動いているため、今回は何もせずに終えます: {lock_path}"
        ]
        assert run_cli.collector.calls == []
        assert not (run_cli.state_dir / "state.sqlite3").exists()
        assert not run_cli.journal_dir.exists()

    assert main(["run"]) == 0
    assert run_cli.collector.calls == list(REPOS)


@pytest.mark.parametrize("interrupted", [False, True])
def test_run_releases_lock_and_leaves_lock_file(run_cli, monkeypatch, interrupted):
    if interrupted:

        def interrupt(*args, **kwargs):
            raise KeyboardInterrupt

        monkeypatch.setattr(run_cli.module, "write_day", interrupt)
        with pytest.raises(KeyboardInterrupt):
            main(["run"])
    else:
        assert main(["run"]) == 0

    lock_path = run_cli.state_dir / "run.lock"
    assert lock_path.is_file()
    with lock_path.open("r+") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)


@pytest.mark.parametrize("marked", [False, True])
def test_with_tcc_hint_only_adds_instructions_to_marked_errors(run_cli, marked):
    base = "git: Operation not permitted" if marked else "git: Permission denied"
    message = run_cli.module.with_tcc_hint(base)
    if marked:
        original, hint = message.split("\n", 1)
        assert original == base
        assert "フルディスクアクセス" in hint
        assert "launchd" in hint and "ターミナル" in hint
    else:
        assert message == base


@pytest.mark.parametrize(
    ("failure", "diagnostic", "hint_expected"),
    [
        ("collect", "Operation not permitted", True),
        ("write", "Operation not permitted", True),
        ("probe-eperm", "Operation not permitted", True),
        ("probe-eacces", "Permission denied", False),
        ("missing-path", "ディレクトリがありません", False),
    ],
)
def test_run_preserves_diagnostics_and_adds_tcc_hint_when_applicable(
    run_cli, monkeypatch, capsys, failure, diagnostic, hint_expected
):
    failed_repo, next_repo = REPOS
    run = run_cli.module
    missing_path = run_cli.config_path.parent / failed_repo

    if failure == "collect":
        run_cli.collector.errors[failed_repo] = (
            f"git rev-parse が失敗しました: /Volumes/x/demo-app: fatal: {diagnostic}"
        )
    elif failure == "write":
        write_day = run.write_day

        def fail_write(store, repo_id, day, **kwargs):
            if repo_id == failed_repo:
                raise PermissionError(errno.EPERM, diagnostic, "/Volumes/x")
            return write_day(store, repo_id, day, **kwargs)

        monkeypatch.setattr(run, "write_day", fail_write)
    elif failure.startswith("probe-"):
        error_number = errno.EPERM if failure == "probe-eperm" else errno.EACCES

        def fail_probe(path):
            if path == missing_path:
                raise PermissionError(error_number, diagnostic, str(path))

        monkeypatch.setattr(run, "probe_readable", fail_probe)
    else:
        missing_path.rmdir()
        run_cli.collector.errors[failed_repo] = f"{missing_path}: {diagnostic}"

    assert main(["run"]) == 1
    stderr = capsys.readouterr().err
    assert diagnostic in stderr and "Traceback" not in stderr
    assert ("フルディスクアクセス" in stderr) is hint_expected
    expected_calls = [next_repo] if failure.startswith("probe-") else list(REPOS)
    assert run_cli.collector.calls == expected_calls
    assert not journal_path(run_cli.journal_dir, failed_repo, DAY).exists()
    assert journal_path(run_cli.journal_dir, next_repo, DAY).is_file()
    with Store(run_cli.state_dir) as store:
        (failed,) = store.runs_for(failed_repo)
        (succeeded,) = store.runs_for(next_repo)
    assert failed.result == "failed" and diagnostic in failed.error
    assert ("フルディスクアクセス" in failed.error) is hint_expected
    assert (succeeded.result, succeeded.error) == ("ok", "")
    if failure == "missing-path":
        assert failed.error == f"git: {missing_path}: {diagnostic}"


def test_rerunning_same_day_replaces_entries_without_duplicate_events(run_cli):
    args = ["run", "--date", str(DAY)]
    assert main(args) == 0

    paths = {repo_id: journal_path(run_cli.journal_dir, repo_id, DAY) for repo_id in REPOS}
    with Store(run_cli.state_dir) as store:
        event_counts = {repo_id: len(store.events_for(repo_id, DAY, tz=TOKYO)) for repo_id in REPOS}
        database_path = store.path
    assert event_counts == {"demo-app": 1, "other-app": 1}
    for path in paths.values():
        meta, _ = parse_journal(path.read_text(encoding="utf-8"))
        assert meta.generated_at == "2026-11-26T03:00:00+09:00"

    run_cli.clock.current += timedelta(hours=1)
    assert main(args) == 0

    with Store(run_cli.state_dir) as store:
        for repo_id, path in paths.items():
            assert len(store.events_for(repo_id, DAY, tz=TOKYO)) == event_counts[repo_id]
            meta, _ = parse_journal(path.read_text(encoding="utf-8"))
            assert (meta.repo, meta.date) == (repo_id, DAY)
            assert meta.generated_at == "2026-11-26T04:00:00+09:00"
            entry = store.entry_for(repo_id, DAY)
            assert entry is not None
            assert entry.path == str(path)
            assert entry.generated_at == run_cli.clock.current
            records = store.runs_for(repo_id)
            assert [(record.result, record.error) for record in records] == [("ok", ""), ("ok", "")]
            assert [record.started_at for record in records] == [NOW, run_cli.clock.current]

    assert set(run_cli.journal_dir.rglob("*.md")) == set(paths.values())
    with closing(sqlite3.connect(database_path)) as database:
        rows = database.execute(
            "SELECT repo_id, date, COUNT(*) FROM entries GROUP BY repo_id, date ORDER BY repo_id"
        ).fetchall()
    assert rows == [(repo_id, str(DAY), 1) for repo_id in REPOS]
