import json
import subprocess
from datetime import date, datetime
from pathlib import Path
from zoneinfo import ZoneInfo

import pytest

from shipcast.collect import COLLECTORS, specdock
from shipcast.collect.base import CollectError, CollectResult, collect_repo
from shipcast.collect.specdock import SpecDockCollector
from shipcast.config import RepoConfig
from shipcast.model import Event, event_id
from shipcast.state import Store

DAY = date(2026, 11, 26)
TZ = ZoneInfo("Asia/Tokyo")
FIXTURES = Path(__file__).parent / "fixtures" / "specdock"


class FakeCommands:
    def __init__(self):
        self.calls = []
        self.responses = {
            command: (FIXTURES / filename).read_text(encoding="utf-8")
            for command, filename in (
                (("spec-dock", "scope", "list"), "scope-list.json"),
                (("spec-dock", "todo", "list"), "todo-list.json"),
                (("gh", "issue", "list"), "gh-issue-list.json"),
            )
        }

    def __call__(self, argv, **kwargs):
        self.calls.append((argv, kwargs))
        response = self.responses[tuple(argv[:3])]
        if isinstance(response, Exception):
            raise response
        if isinstance(response, str):
            return subprocess.CompletedProcess(argv, 0, response, "")
        return response


@pytest.fixture
def specdock_repo(tmp_path):
    workspace = tmp_path / "spec-dock"
    workspace.mkdir()
    (workspace / "workspace.json").write_text("{}", encoding="utf-8")
    return RepoConfig(id="demo", path=tmp_path, ref="main", title="demo", orca=False)


def test_fake_commands_serve_json_fixtures(specdock_repo):
    commands = FakeCommands()
    project = str(specdock_repo.path)
    scope = commands(["spec-dock", "scope", "list", "--project", project])
    todo = commands(["spec-dock", "todo", "list", "--project", project])
    issues = commands(["gh", "issue", "list", "--repo", "example-org/demo-app"])
    assert json.loads(scope.stdout)["data"]["result"]["items"][0]["id"] == "iss-00101"
    assert json.loads(todo.stdout)["data"]["result"]["items"][0]["todo"]["id"] == "t-0101"
    assert json.loads(issues.stdout)[0]["number"] == 101


@pytest.fixture
def commands(monkeypatch):
    commands = FakeCommands()
    monkeypatch.setattr(specdock.subprocess, "run", commands)
    return commands


def expected_event(native_id, kind, timestamp, title, refs, *lines):
    return Event(
        id=event_id("specdock", "demo", native_id),
        source="specdock",
        repo_id="demo",
        kind=kind,
        at=datetime.fromisoformat(timestamp),
        title=title,
        refs=refs,
        body="\n".join(lines),
    )


def test_scope_events_use_issue_times_in_local_day(commands, specdock_repo):
    result = SpecDockCollector().collect(specdock_repo, DAY, TZ)
    scope_events = tuple(event for event in result.events if event.kind.startswith("scope_"))
    url_101 = "https://github.com/example-org/demo-app/issues/101"
    url_102 = "https://github.com/example-org/demo-app/issues/102"
    assert scope_events == (
        expected_event(
            "scope:iss-00101:opened",
            "scope_opened",
            "2026-11-25T15:00:00Z",
            "設計見本を追加",
            ("iss-00101", url_101),
            "Scope: iss-00101（issue）",
            "親: epic-00100",
            f"URL: {url_101}",
        ),
        expected_event(
            "scope:iss-00101:closed",
            "scope_closed",
            "2026-11-26T10:00:00Z",
            "設計見本を追加",
            ("iss-00101", url_101),
            "Scope: iss-00101（issue）",
            "親: epic-00100",
            f"URL: {url_101}",
            "閉じた理由: completed",
        ),
        expected_event(
            "scope:iss-00102:opened",
            "scope_opened",
            "2026-11-26T14:59:59Z",
            "図の色を調整",
            ("iss-00102", url_102),
            "Scope: iss-00102（issue）",
            "親: epic-00100",
            f"URL: {url_102}",
        ),
    )


def expected_todo_events():
    return (
        expected_event(
            "todo:t-0101:open",
            "todo_open",
            "2026-11-25T15:00:00Z",
            "配色を確認する",
            ("t-0101", "iss-00101", "iss-00102"),
            "todo: t-0101（check）",
            "今の状態: open",
            "期限: 2026-11-30T00:00:00Z",
            "関連するScope: iss-00101、iss-00102",
            "登録した側: human",
        ),
        expected_event(
            "todo:t-0102:open",
            "todo_open",
            "2026-11-26T00:00:00Z",
            "書体を決める",
            ("t-0102",),
            "todo: t-0102（check）",
            "今の状態: done",
            "登録した側: human",
        ),
        expected_event(
            "todo:t-0102:done",
            "todo_done",
            "2026-11-26T14:59:59Z",
            "書体を決める",
            ("t-0102",),
            "todo: t-0102（check）",
            "完了した側: human",
        ),
        expected_event(
            "todo:t-0103:open",
            "todo_open",
            "2026-11-26T01:00:00Z",
            "印刷する",
            ("t-0103",),
            "todo: t-0103（check）",
            "今の状態: cancelled",
            "登録した側: human",
        ),
        expected_event(
            "todo:t-0104:done",
            "todo_done",
            "2026-11-26T03:00:00Z",
            "表紙を選ぶ",
            ("t-0104", "iss-00101"),
            "todo: t-0104（check）",
            "完了した側: human",
            "選んだ選択肢: 青い表紙",
            "記録: 見本Aを採用",
            "関連するScope: iss-00101",
        ),
    )


def test_todo_events_use_creation_and_resolution_times(commands, specdock_repo):
    result = SpecDockCollector().collect(specdock_repo, DAY, TZ)
    assert tuple(event for event in result.events if event.kind.startswith("todo_")) == (
        expected_todo_events()
    )
    assert len(result.warnings) == 1
    assert result.warnings[0].startswith(
        "todoのカタログを読めません: github.com/example-org/demo-archive: "
    )
    assert "見本のカタログを利用できません" in result.warnings[0]


@pytest.mark.parametrize(
    ("response", "reason"),
    [
        (FileNotFoundError(), "ghのコマンドが見つかりません: gh"),
        (subprocess.TimeoutExpired("gh", 60.0), "60.0秒で終わりませんでした"),
        (
            subprocess.CompletedProcess([], 1, "", "前の行\n 架空の認証エラー\n\n"),
            "架空の認証エラー",
        ),
        ("{", "出力の形が想定と違います"),
        (
            '[{"number": 101, "createdAt": "unknown", "closedAt": null, '
            '"state": "OPEN", "url": ""}]',
            "出力の形が想定と違います",
        ),
    ],
)
def test_gh_failure_preserves_todos(commands, specdock_repo, response, reason):
    commands.responses[("gh", "issue", "list")] = response
    result = SpecDockCollector().collect(specdock_repo, DAY, TZ)
    assert result.events == expected_todo_events()
    assert (
        f"gh issue list を読めませんでした（example-org/demo-app）: {reason}。"
        "Scopeの作成と終了は集めていません"
    ) in result.warnings


def test_gh_warns_at_issue_limit(commands, specdock_repo):
    count = len(json.loads(commands.responses[("gh", "issue", "list")]))
    result = SpecDockCollector(issue_limit=count).collect(specdock_repo, DAY, TZ)
    assert (
        f"example-org/demo-app のIssueが{count}件以上あるので、"
        "古いScopeの時刻を読めないことがあります"
    ) in result.warnings
    assert commands.calls[-1][0][7:9] == ["--limit", str(count)]


FAILED_ENVELOPE = (
    '{"schema_version": "specdock.cli/v2", "status": "failed", '
    '"error": {"code": "GIT_FAILED", "message": "\\n 架空の失敗 \\n 補足"}}'
)


@pytest.mark.parametrize("subcommand", ["scope", "todo"])
@pytest.mark.parametrize(
    ("response", "message"),
    [
        (FileNotFoundError(), "spec-dockのコマンドが見つかりません: spec-dock"),
        (
            subprocess.TimeoutExpired("spec-dock", 60.0),
            "spec-dock {sub} が60.0秒で終わりませんでした: {path}",
        ),
        ("{", "spec-dock {sub} の出力をJSONとして読めません: {path}"),
        (
            subprocess.CompletedProcess([], 5, FAILED_ENVELOPE, "別の誤り"),
            "spec-dock {sub} が失敗しました: {path}: GIT_FAILED: 架空の失敗",
        ),
        (
            subprocess.CompletedProcess([], 1, "", "前の行\n 最後の行\n\n"),
            "spec-dock {sub} が失敗しました: {path}: 最後の行",
        ),
        (FAILED_ENVELOPE, "spec-dock {sub} が失敗しました: {path}: GIT_FAILED: 架空の失敗"),
        (
            '{"status": "succeeded", "data": {"result": {"items": {}}}}',
            "spec-dock {sub} の出力の形が想定と違います: {path}: data.result.items",
        ),
    ],
)
def test_specdock_command_failure_is_collect_error(
    commands,
    specdock_repo,
    subcommand,
    response,
    message,
):
    commands.responses[("spec-dock", subcommand, "list")] = response
    with pytest.raises(CollectError) as error:
        SpecDockCollector().collect(specdock_repo, DAY, TZ)
    assert str(error.value) == message.format(sub=f"{subcommand} list", path=specdock_repo.path)
    assert [argv[1] for argv, _ in commands.calls] == (
        ["scope"] if subcommand == "scope" else ["scope", "todo"]
    )


@pytest.mark.parametrize("workspace_is_directory", [False, True])
def test_without_workspace_file_runs_no_commands(
    commands,
    specdock_repo,
    workspace_is_directory,
):
    workspace = specdock_repo.path / "spec-dock" / "workspace.json"
    workspace.unlink()
    if workspace_is_directory:
        workspace.mkdir()
    assert SpecDockCollector().collect(specdock_repo, DAY, TZ) == CollectResult()
    assert commands.calls == []


def test_command_argv_and_environment(commands, specdock_repo, monkeypatch):
    monkeypatch.setenv("GH_PROMPT_DISABLED", "0")
    monkeypatch.setenv("SHIPCAST_TEST_SUBPROCESS_ENV", "preserved")
    SpecDockCollector().collect(specdock_repo, DAY, TZ)
    project = str(specdock_repo.path)
    assert [argv for argv, _ in commands.calls] == [
        ["spec-dock", "scope", "list", "--offline", "--json", "--project", project],
        [
            "spec-dock",
            "todo",
            "list",
            "--status",
            "all",
            "--offline",
            "--json",
            "--project",
            project,
        ],
        [
            "gh",
            "issue",
            "list",
            "--repo",
            "example-org/demo-app",
            "--state",
            "all",
            "--limit",
            "500",
            "--json",
            "number,title,state,createdAt,closedAt,url",
        ],
    ]
    for _, kwargs in commands.calls:
        env = kwargs["env"]
        assert env["GH_PROMPT_DISABLED"] == env["GH_NO_UPDATE_NOTIFIER"] == env["NO_COLOR"] == "1"
        assert env["SHIPCAST_TEST_SUBPROCESS_ENV"] == "preserved"
        assert kwargs == dict(
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
            timeout=60.0,
            env=env,
            check=False,
        )


def test_collect_repo_saves_once_and_supplies_missing_titles(commands, specdock_repo):
    scope_key = ("spec-dock", "scope", "list")
    scopes = json.loads(commands.responses[scope_key])
    scopes["data"]["result"]["items"][0]["title"] = ""
    commands.responses[scope_key] = json.dumps(scopes)
    todo_key = ("spec-dock", "todo", "list")
    todos = json.loads(commands.responses[todo_key])
    todos["data"]["result"]["items"][0]["todo"]["title"] = ""
    commands.responses[todo_key] = json.dumps(todos)
    collectors = (SpecDockCollector(),)
    with Store(specdock_repo.path) as store:
        first = collect_repo(store, specdock_repo, DAY, tz=TZ, collectors=collectors)
        second = collect_repo(store, specdock_repo, DAY, tz=TZ, collectors=collectors)
        saved = store.events_for("demo", DAY, tz=TZ)
    assert first.errors == second.errors == ()
    assert first.saved == len(first.events) == len(saved) == 8
    assert second.saved == 0
    titles = {event.id: event.title for event in saved}
    assert titles[event_id("specdock", "demo", "scope:iss-00101:opened")] == "（題名のないScope）"
    assert titles[event_id("specdock", "demo", "scope:iss-00101:closed")] == "（題名のないScope）"
    assert titles[event_id("specdock", "demo", "todo:t-0101:open")] == "（題名のないtodo）"


def test_specdock_is_registered_after_git():
    assert [collector.name for collector in COLLECTORS] == ["git", "specdock", "orca"]
