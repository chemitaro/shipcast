import json
import subprocess
from dataclasses import replace
from datetime import UTC, date, datetime
from pathlib import Path
from zoneinfo import ZoneInfo

import pytest

from shipcast.collect import COLLECTORS, orca
from shipcast.collect.base import CollectResult, collect_repo
from shipcast.config import RepoConfig
from shipcast.model import Event, event_id
from shipcast.state import Store

FIXTURES = Path(__file__).parent / "fixtures" / "orca"
DAY = date(2026, 11, 26)
TZ = ZoneInfo("Asia/Tokyo")
REPO = RepoConfig(id="demo", path=Path("/home/dev/demo-app"), ref="main", title="demo", orca=True)


def session_id(number):
    return f"00000000-0000-4000-8000-{number:012d}"


def fixture_text(name):
    return (FIXTURES / f"{name}.json").read_text(encoding="utf-8")


class FakeOrca:
    def __init__(self):
        self.calls = []
        self.responses = {
            ("agent", "list"): fixture_text("agent-list"),
            ("repo", "list"): fixture_text("repo-list"),
        }
        for number, name in enumerate(("main", "worktree", "child", "empty"), start=1):
            self.responses["agent", "read", f"orca_session_id:{session_id(number)}"] = fixture_text(
                f"agent-read-{name}"
            )

    def __call__(self, argv, **kwargs):
        self.calls.append((argv, kwargs))
        command = tuple(argv[1:4] if argv[1:3] == ["agent", "read"] else argv[1:3])
        response = self.responses[command]
        if isinstance(response, Exception):
            raise response
        if isinstance(response, str):
            return subprocess.CompletedProcess(argv, 0, response, "")
        return subprocess.CompletedProcess(argv, *response)


@pytest.fixture
def fake_orca(monkeypatch):
    fake = FakeOrca()
    monkeypatch.setattr(orca.subprocess, "run", fake)
    return fake


def orca_collector():
    collector = next((item for item in COLLECTORS if item.name == "orca"), None)
    assert collector is not None, "Orca collector is not registered"
    return collector


def expected_event(number, at, title, actor, body):
    return Event(
        id=event_id("orca", "demo", f"conversation:{session_id(number)}:2026-11-26"),
        repo_id="demo",
        source="orca",
        kind="conversation",
        at=at,
        title=title,
        actor=actor,
        refs=(f"orca_session_id:{session_id(number)}",),
        body=body,
    )


def test_collects_only_selected_conversations_with_readable_messages(fake_orca):
    result = orca_collector().collect(REPO, DAY, TZ)

    end_minus_one = datetime(2026, 11, 26, 14, 59, 59, 999000, tzinfo=UTC)
    expected = (
        expected_event(
            1,
            datetime(2026, 11, 25, 15, tzinfo=UTC),
            "Lamp color experiment",
            "codex",
            f"会話: orca_session_id:{session_id(1)}（codex、chat）\n"
            "workspace: demo workspace\n"
            "（最新の100件の記録だけを読みました）\n\n"
            "[user]\nTry a blue lamp.\n\n"
            "[assistant]\nThe blue lamp is ready.\nThe switch works.\n\n"
            "[user]\nRecord the result.",
        ),
        expected_event(
            2,
            end_minus_one,
            "（題名のない会話）",
            "claude",
            f"会話: orca_session_id:{session_id(2)}（claude、terminal）\n"
            "workspace: feature-x\n\n"
            "[assistant]\nThe dial turns smoothly.",
        ),
        expected_event(
            3,
            end_minus_one,
            "Paper preview",
            "codex",
            f"会話: orca_session_id:{session_id(3)}（codex）\n\n[user]\nOpen the paper preview.",
        ),
    )
    assert result == CollectResult(expected)


def test_calls_only_selected_sessions_and_saves_once_per_day(fake_orca, monkeypatch, tmp_path):
    monkeypatch.setenv("ORCA_FIXTURE", "demo")
    collectors = (orca_collector(),)
    with Store(tmp_path) as store:
        first = collect_repo(store, REPO, DAY, tz=TZ, collectors=collectors)
        assert first.errors == first.warnings == ()
        assert first.saved == len(first.events) == 3
        assert set(store.events_for(REPO.id, DAY, tz=TZ)) == set(first.events)
        assert [argv for argv, _ in fake_orca.calls] == [
            ["orca", "agent", "list", "--json"],
            ["orca", "repo", "list", "--json"],
            *[
                [
                    "orca",
                    "agent",
                    "read",
                    f"orca_session_id:{session_id(number)}",
                    "--limit",
                    "100",
                    "--json",
                ]
                for number in (1, 2, 3, 4)
            ],
        ]
        for _, kwargs in fake_orca.calls:
            env = kwargs["env"]
            assert env["NO_COLOR"] == "1"
            assert env["ORCA_FIXTURE"] == "demo"
            assert {key: value for key, value in kwargs.items() if key != "env"} == {
                "capture_output": True,
                "text": True,
                "encoding": "utf-8",
                "errors": "replace",
                "timeout": 30.0,
                "check": False,
            }

        second = collect_repo(store, REPO, DAY, tz=TZ, collectors=collectors)
        assert second.errors == second.warnings == ()
        assert second.saved == 0
        assert second.events == first.events

        envelope = json.loads(fixture_text("agent-list"))
        conversation = envelope["result"]["agents"][0]
        conversation["updatedAt"] = 1795705200000
        envelope["result"]["agents"] = [conversation]
        fake_orca.responses["agent", "list"] = json.dumps(envelope)
        next_day = date(2026, 11, 27)

        third = collect_repo(store, REPO, next_day, tz=TZ, collectors=collectors)
        assert third.errors == third.warnings == ()
        assert third.saved == 1
        assert store.events_for(REPO.id, next_day, tz=TZ) == list(third.events)
        assert third.events[0].refs == first.events[0].refs
        assert third.events[0].id == event_id(
            "orca", "demo", f"conversation:{session_id(1)}:2026-11-27"
        )
        assert third.events[0].id != first.events[0].id


def test_disabled_orca_does_not_call_subprocess(fake_orca):
    result = orca_collector().collect(replace(REPO, orca=False), DAY, TZ)

    assert result == CollectResult()
    assert fake_orca.calls == []


ERROR_ENVELOPE = json.dumps(
    {
        "id": "fixture-error",
        "ok": False,
        "error": {"code": "demo_offline", "message": "\n  Sample offline message\nExtra detail"},
        "_meta": {},
    }
)


@pytest.mark.parametrize(
    ("response", "reason"),
    [
        (FileNotFoundError(), "orcaのコマンドが見つかりません: orca"),
        (subprocess.TimeoutExpired("orca", 30.0), "30.0秒で終わりませんでした"),
        ((1, ERROR_ENVELOPE, "Sample stderr"), "demo_offline: Sample offline message"),
        ((0, ERROR_ENVELOPE, ""), "demo_offline: Sample offline message"),
        ((1, "", "Earlier line\n Sample last error\n\n"), "Sample last error"),
        ((1, '{"ok": false, "error": []}', ""), "終了コード 1"),
        ("{broken", "出力をJSONとして読めません"),
        ('{"ok": true, "result": {"agents": {}}}', "出力の形が想定と違います"),
    ],
)
def test_agent_list_failure_only_warns(fake_orca, tmp_path, response, reason):
    fake_orca.responses["agent", "list"] = response
    warning = f"Orcaの会話の一覧を読めませんでした: {reason}。Orcaの会話は集めていません"

    collector = orca_collector()
    assert collector.collect(REPO, DAY, TZ) == CollectResult(warnings=(warning,))
    assert [argv for argv, _ in fake_orca.calls] == [["orca", "agent", "list", "--json"]]
    with Store(tmp_path) as store:
        result = collect_repo(store, REPO, DAY, tz=TZ, collectors=(collector,))
    assert result.errors == result.events == ()
    assert result.warnings == (f"orca: {warning}",)


@pytest.mark.parametrize(
    ("failure", "numbers", "warning"),
    [
        ("truncated", (1, 2, 3), "Orcaの会話の一覧が途中までしか返りませんでした"),
        (
            "repo list",
            (1, 3, 10),
            "Orcaのrepositoryの一覧を読めませんでした: 終了コード 1。"
            "pathの一致だけで会話を選びます",
        ),
        (
            "agent read",
            (2, 3),
            f"Orcaの会話を読めませんでした（orca_session_id:{session_id(1)}）: "
            "出力の形が想定と違います",
        ),
    ],
)
def test_recoverable_failure_keeps_other_conversations(
    fake_orca, tmp_path, failure, numbers, warning
):
    if failure == "truncated":
        envelope = json.loads(fixture_text("agent-list"))
        envelope["result"]["truncated"] = True
        fake_orca.responses["agent", "list"] = json.dumps(envelope)
    elif failure == "repo list":
        fake_orca.responses["repo", "list"] = (1, "", "")
        fake_orca.responses["agent", "read", f"orca_session_id:{session_id(10)}"] = fixture_text(
            "agent-read-child"
        )
    else:
        fake_orca.responses["agent", "read", f"orca_session_id:{session_id(1)}"] = (
            '{"ok": true, "result": {"entries": null}}'
        )

    with Store(tmp_path) as store:
        result = collect_repo(store, REPO, DAY, tz=TZ, collectors=(orca_collector(),))
    assert result.errors == ()
    assert result.warnings == (f"orca: {warning}",)
    assert {event.refs for event in result.events} == {
        (f"orca_session_id:{session_id(number)}",) for number in numbers
    }
    assert result.saved == len(numbers)


def test_malformed_rows_are_skipped_and_optional_text_is_omitted(fake_orca):
    envelope = json.loads(fixture_text("agent-list"))
    conversation = envelope["result"]["agents"][0]
    envelope["result"]["agents"] = [
        None,
        {**conversation, "orcaSessionId": ""},
        {**conversation, "updatedAt": True},
        {**conversation, "updatedAt": 10**50},
        {**conversation, "worktreeId": 123},
        {**conversation, "agent": None, "kind": "", "workspace": False, "title": 123},
    ]
    fake_orca.responses["agent", "list"] = json.dumps(envelope)
    fake_orca.responses["agent", "read", f"orca_session_id:{session_id(1)}"] = json.dumps(
        {
            "ok": True,
            "result": {
                "entries": [
                    None,
                    {"kind": "message", "role": "user", "text": 123},
                    {"kind": "message", "role": "user", "text": "Sample message"},
                ],
            },
        }
    )

    result = orca_collector().collect(REPO, DAY, TZ)

    assert result == CollectResult(
        (
            expected_event(
                1,
                datetime(2026, 11, 25, 15, tzinfo=UTC),
                "（題名のない会話）",
                "",
                f"会話: orca_session_id:{session_id(1)}\n\n[user]\nSample message",
            ),
        )
    )
