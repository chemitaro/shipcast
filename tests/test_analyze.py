import json
from dataclasses import replace
from datetime import UTC, date, datetime
from importlib.resources import files

import pytest

from shipcast.analyze import AnalyzeFailed, analyze, parse_stories
from shipcast.config import ModelConfig
from shipcast.model import Event, ModelError, Neta, Story, story_id
from shipcast.models import JSON_INSTRUCTION, RouteFailed, get_route
from shipcast.state import Store


def story_response(**changes):
    return {
        "title": "表示の改善",
        "what": "一覧を追加した",
        "why": "進捗を見つけやすくするため",
        "neta": {"score": 0},
        "event_ids": ["sample-a"],
        **changes,
    }


def response_text(*stories):
    return json.dumps({"stories": stories})


def test_parse_stories_preserves_order_and_defaults():
    raw = response_text(
        story_response(
            notice=["表示順が変わる"],
            waiting=["見た目の確認"],
            neta={"score": 2, "reason": "変化が見える", "channels": ["x"], "extra": 1},
            event_ids=["sample-c", "sample-a"],
            extra="無視する値",
        ),
        story_response(title="補足", event_ids=["sample-b"]),
    )
    stories, errors = parse_stories(
        f"  \n```json\n{raw}\n``` \n", event_ids=["sample-a", "sample-b", "sample-c"]
    )
    assert errors == []
    assert stories == [
        {
            "title": "表示の改善",
            "what": "一覧を追加した",
            "why": "進捗を見つけやすくするため",
            "notice": ("表示順が変わる",),
            "waiting": ("見た目の確認",),
            "neta": Neta(2, "変化が見える", ("x",)),
            "event_ids": ("sample-c", "sample-a"),
        },
        {
            "title": "補足",
            "what": "一覧を追加した",
            "why": "進捗を見つけやすくするため",
            "notice": (),
            "waiting": (),
            "neta": Neta(0),
            "event_ids": ("sample-b",),
        },
    ]


MARKER = "fictional-response-marker"


@pytest.mark.parametrize(
    ("raw", "location"),
    [
        (MARKER, "応答"),
        ("", "応答"),
        ("[" * 10000 + "0" + "]" * 10000, "応答"),
        ("[]", "応答"),
        ("{}", "stories"),
        ('{"stories": {}}', "stories"),
        (response_text(), "stories"),
        (response_text(MARKER), "stories[0]"),
        (response_text({}), "stories[0].what"),
        (response_text(story_response(what=" \t")), "stories[0].what"),
        (response_text(story_response(what=1)), "stories[0].what"),
        (response_text(story_response(notice=MARKER)), "stories[0].notice"),
        (response_text(story_response(waiting=[1])), "stories[0].waiting"),
        (response_text({}), "stories[0].neta"),
        *[
            (response_text(story_response(neta={"score": score})), "stories[0].neta.score")
            for score in (-1, 4, 1.5, "2", True)
        ],
        (
            response_text(story_response(neta={"score": 0, "channels": [1]})),
            "stories[0].neta.channels",
        ),
        (response_text(story_response(event_ids=[])), "stories[0].event_ids"),
        (response_text(story_response(event_ids=[MARKER])), "stories[0].event_ids"),
        (
            response_text(story_response(event_ids=["sample-a", "sample-a"])),
            "stories[0].event_ids",
        ),
        (response_text(story_response(), story_response()), "stories[1].event_ids"),
        (response_text(story_response(title="\ud800")), "stories[0].title"),
        (response_text(story_response(notice=["\ud800"])), "stories[0].notice"),
        (
            response_text(story_response(neta={"score": 0, "reason": "\ud800"})),
            "stories[0].neta.reason",
        ),
    ],
)
def test_parse_stories_rejects_invalid_response(raw, location):
    stories, errors = parse_stories(raw, event_ids={"sample-a"})

    assert stories == []
    assert any(error.startswith(f"{location}:") for error in errors)
    assert all(MARKER not in error for error in errors)


def test_parse_stories_caps_errors():
    stories, errors = parse_stories(response_text(*([MARKER] * 30)), event_ids={"sample-a"})

    assert stories == []
    assert len(errors) == 21
    assert errors[-1] == "ほかにも誤りがあります"
    assert all(MARKER not in error for error in errors)


def test_analyze_prompt_is_packaged_with_required_instructions():
    prompt = (files("shipcast") / "prompts" / "analyze.md").read_text(encoding="utf-8")
    for word in (
        "ネタポイント",
        "変化の大きさ",
        "読者への価値",
        "見せやすさ",
        "previous_errors",
        "event_ids",
        "stories",
    ):
        assert word in prompt


REPO = "demo-app"
DAY = date(2026, 11, 26)


@pytest.fixture
def events():
    return [
        Event(
            id=identifier,
            repo_id=REPO,
            source="git",
            kind=kind,
            at=datetime(2026, 11, 26, 9 + index, tzinfo=UTC),
            title=title,
            body="架空の作業の概要",
            refs=("#3",),
            actor="demo-writer",
        )
        for index, (identifier, kind, title) in enumerate(
            [
                ("sample-a", "commit", "表示を追加"),
                ("sample-b", "merge", "説明を更新"),
                ("sample-c", "commit", "一覧の表示を調整"),
            ]
        )
    ]


@pytest.fixture
def store(tmp_path):
    with Store(tmp_path) as opened:
        yield opened


def fake_route(responder):
    return get_route(ModelConfig("fake", "fake-analyst", None, None), env={}, responder=responder)


def test_analyze_builds_stories_in_response_order(events, store):
    def respond(prompt, system, want_json):
        return (
            " \n```json\n"
            + response_text(
                story_response(
                    notice=["表示順が変わる"],
                    waiting=["見た目の確認"],
                    neta={"score": 2, "reason": "変化が見える", "channels": ["x"], "extra": 1},
                    event_ids=["sample-c", "sample-a"],
                    extra="無視する値",
                ),
                story_response(title="補足", event_ids=["sample-b"]),
            )
            + "\n``` \n"
        )

    assert analyze(events, fake_route(respond), store=store, repo_id=REPO, day=DAY) == [
        Story(
            id=story_id(REPO, DAY, ("sample-c", "sample-a")),
            repo_id=REPO,
            date=DAY,
            title="表示の改善",
            what="一覧を追加した",
            why="進捗を見つけやすくするため",
            neta=Neta(2, "変化が見える", ("x",)),
            notice=("表示順が変わる",),
            waiting=("見た目の確認",),
            event_ids=("sample-c", "sample-a"),
        ),
        Story(
            id=story_id(REPO, DAY, ("sample-b",)),
            repo_id=REPO,
            date=DAY,
            title="補足",
            what="一覧を追加した",
            why="進捗を見つけやすくするため",
            neta=Neta(0),
            event_ids=("sample-b",),
        ),
    ]


@pytest.mark.parametrize(
    ("first_error", "location"),
    [
        (None, None),
        (MARKER, "応答"),
        (response_text(story_response(neta={"score": True})), "stories[0].neta.score"),
    ],
)
def test_analyze_retries_only_invalid_response(events, store, first_error, location):
    calls = []
    good = response_text(story_response())
    responses = iter([good] if first_error is None else [first_error, good])

    def respond(prompt, system, want_json):
        calls.append((prompt, system, want_json))
        return next(responses)

    assert len(analyze(events, fake_route(respond), store=store, repo_id=REPO, day=DAY)) == 1
    assert len(calls) == (1 if first_error is None else 2)
    expected_system = (files("shipcast") / "prompts" / "analyze.md").read_text(encoding="utf-8")
    for prompt, system, want_json in calls:
        assert system == f"{expected_system}\n\n{JSON_INSTRUCTION}"
        assert want_json is True
        assert MARKER not in prompt

    initial = json.loads(calls[0][0])
    assert initial == {
        "repo": REPO,
        "date": "2026-11-26",
        "events": [
            {
                "id": event.id,
                "source": "git",
                "kind": event.kind,
                "at": f"2026-11-26T{9 + index:02d}:00:00+00:00",
                "title": event.title,
                "body": "架空の作業の概要",
                "refs": ["#3"],
                "actor": "demo-writer",
            }
            for index, event in enumerate(events)
        ],
    }
    if first_error is not None:
        retry = json.loads(calls[1][0])
        errors = retry.pop("previous_errors")
        assert len(errors) == 1
        assert errors[0].startswith(f"{location}:")
        assert retry == initial


def test_analyze_reports_only_last_shape_errors(events, store):
    calls = []
    responses = iter([MARKER, response_text(story_response(what={MARKER: 1}))])

    def respond(prompt, system, want_json):
        calls.append(prompt)
        return next(responses)

    with pytest.raises(AnalyzeFailed) as caught:
        analyze(events, fake_route(respond), store=store, repo_id=REPO, day=DAY)

    assert len(calls) == caught.value.attempts == 2
    assert len(caught.value.errors) == 1
    assert caught.value.errors[0].startswith("stories[0].what:")
    assert str(caught.value).startswith("分析の応答が2回とも決まった形になりませんでした")
    assert MARKER not in str(caught.value)
    assert store.stories_for(REPO, DAY) == []
    assert store.events_for(REPO, DAY, tz=UTC) == events


def test_analyze_propagates_route_failure_without_retry(events, store):
    calls = []
    failure = RouteFailed("fake", reason="架空の経路が失敗")

    def respond(prompt, system, want_json):
        calls.append(prompt)
        raise failure

    with pytest.raises(RouteFailed) as caught:
        analyze(events, fake_route(respond), store=store, repo_id=REPO, day=DAY)

    assert caught.value is failure
    assert len(calls) == 1
    assert store.stories_for(REPO, DAY) == []
    assert store.events_for(REPO, DAY, tz=UTC) == events


@pytest.mark.parametrize("already_collected", [False, True])
def test_analyze_persists_events_before_request_and_stories_before_return(
    events, store, already_collected
):
    if already_collected:
        assert store.add_events(events) == len(events)
    assert store.stories_for(REPO, DAY) == []

    def respond(prompt, system, want_json):
        assert store.events_for(REPO, DAY, tz=UTC) == events
        return response_text(
            story_response(title="補足", event_ids=["sample-b"]),
            story_response(neta={"score": 2}, event_ids=["sample-a", "sample-c"]),
        )

    stories = analyze(events, fake_route(respond), store=store, repo_id=REPO, day=DAY)
    assert len(stories) == 2
    assert store.stories_for(REPO, DAY) == stories
    assert store.events_for(REPO, DAY, tz=UTC) == events
    assert store.runs_for(REPO) == []
    assert store.unconsumed_neta(REPO) == [stories[1].id, stories[0].id]
    assert store.neta_balance(REPO) == 2
    assert analyze(events, fake_route(respond), store=store, repo_id=REPO, day=DAY) == stories
    assert store.neta_balance(REPO) == 2


def reject_call(*args):
    pytest.fail("モデルを呼び出してはいけない")


def test_analyze_returns_empty_without_calling_route(store):
    assert analyze([], fake_route(reject_call), store=store, repo_id=REPO, day=DAY) == []
    assert store.stories_for(REPO, DAY) == []
    assert store.events_for(REPO, DAY, tz=UTC) == []


@pytest.mark.parametrize("invalid_event", ["repo", "type"])
def test_analyze_rejects_invalid_event_without_side_effects(events, store, invalid_event):
    foreign = replace(events[-1], repo_id="other-app")
    mixed = [*events, foreign if invalid_event == "repo" else {}]
    with pytest.raises(ValueError):
        analyze(mixed, fake_route(reject_call), store=store, repo_id=REPO, day=DAY)

    assert store.stories_for(REPO, DAY) == []
    assert store.events_for(REPO, DAY, tz=UTC) == []
    assert store.events_for("other-app", DAY, tz=UTC) == []


@pytest.mark.parametrize(
    ("repo_id", "day"), [("INVALID", DAY), (REPO, datetime(2026, 11, 26, tzinfo=UTC))]
)
def test_analyze_validates_repo_and_day_even_without_events(store, repo_id, day):
    with pytest.raises(ModelError):
        analyze([], fake_route(reject_call), store=store, repo_id=repo_id, day=day)


def test_parse_stories_strips_unicode_whitespace_before_json():
    stories, errors = parse_stories(
        "\u3000" + response_text(story_response()) + "\u3000", event_ids={"sample-a"}
    )
    assert errors == []
    assert len(stories) == 1
