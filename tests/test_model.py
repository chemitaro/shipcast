import re
from datetime import date, datetime, timedelta, timezone

import pytest

from shipcast.model import Entry, Event, ModelError, Neta, Story, event_id, story_id

JST = timezone(timedelta(hours=9))
AT = datetime(2026, 11, 26, 10, 15, tzinfo=JST)


@pytest.mark.parametrize("optional", [{}, {"body": "架空の本文", "refs": ["abc"], "actor": "taro"}])
def test_event_round_trip(optional):
    event = Event("e1", "demo-app", "git", "commit", AT, "架空の変更", **optional)
    data = event.to_dict()
    assert list(data) == [
        "schema",
        "id",
        "repo_id",
        "source",
        "kind",
        "at",
        "title",
        "body",
        "refs",
        "actor",
    ]
    assert data["schema"] == 1
    assert data["at"] == "2026-11-26T10:15:00+09:00"
    assert data["refs"] == optional.get("refs", [])
    assert event.refs == tuple(data["refs"])
    assert Event.from_dict(data) == Event.from_json(event.to_json()) == event
    assert "架空の変更" in event.to_json()


@pytest.mark.parametrize("optional", [{}, {"notice": ["a"], "waiting": ["b"], "event_ids": ["e1"]}])
def test_story_round_trip(optional):
    neta = Neta(2, "架空の理由", ["x"]) if optional else Neta(0)
    story = Story("s1", "demo-app", AT.date(), "題名", "内容", "理由", neta, **optional)
    data = story.to_dict()
    assert list(data) == [
        "schema",
        "id",
        "repo_id",
        "date",
        "title",
        "what",
        "why",
        "neta",
        "notice",
        "waiting",
        "event_ids",
    ]
    assert data["schema"] == 1
    assert data["date"] == "2026-11-26"
    assert data["neta"] == {
        "score": 2 if optional else 0,
        "reason": "架空の理由" if optional else "",
        "channels": ["x"] if optional else [],
    }
    assert list(data["neta"]) == ["score", "reason", "channels"]
    assert story.event_ids == tuple(optional.get("event_ids", ()))
    assert Story.from_dict(data) == Story.from_json(story.to_json()) == story
    assert Story.from_dict(
        {
            "schema": 1,
            "id": "s1",
            "repo_id": "demo-app",
            "date": "2026-11-26",
            "title": "題名",
            "what": "内容",
            "why": "理由",
            "neta": {"score": 0},
        }
    ).neta == Neta(0)


@pytest.mark.parametrize("optional", [{}, {"story_ids": ["s1"]}])
def test_entry_round_trip(optional):
    entry = Entry("demo-app", AT.date(), "/tmp/demo.md", "fake/fake", "fake/fake", AT, **optional)
    data = entry.to_dict()
    assert list(data) == [
        "schema",
        "repo_id",
        "date",
        "path",
        "analyst",
        "writer",
        "generated_at",
        "story_ids",
    ]
    assert data["schema"] == 1
    assert data["date"] == "2026-11-26"
    assert data["generated_at"] == "2026-11-26T10:15:00+09:00"
    assert data["story_ids"] == optional.get("story_ids", [])
    assert Entry.from_dict(data) == Entry.from_json(entry.to_json()) == entry


def test_stable_ids():
    base = event_id("git", "demo-app", "abc")
    assert re.fullmatch("[a-f0-9]{16}", base)
    assert base == event_id("git", "demo-app", "abc")
    assert base != event_id("specdock", "demo-app", "abc")
    assert base != event_id("git", "demo-lib", "abc")
    assert base != event_id("git", "demo-app", "def")
    day = date(2026, 11, 26)
    assert story_id("demo-app", day, ["b", "a", "a"]) == story_id("demo-app", day, iter(["a", "b"]))
    assert story_id("demo-app", day, ["a"]) != story_id("demo-app", day, ["a", "b"])
    with pytest.raises(ModelError, match="event_ids"):
        story_id("demo-app", day, [])


@pytest.mark.parametrize(
    ("change", "field"),
    [
        ({"schema": 2}, "schema"),
        ({"schema": True}, "schema"),
        ({"schema": 1.0}, "schema"),
        ({"title": 1}, "title"),
        ({"kind": ""}, "kind"),
        ({"body": None}, "body"),
        ({"source": "unknown"}, "source"),
        ({"at": "2026-11-26T10:15:00"}, "at"),
        ({"at": "x"}, "at"),
        ({"refs": ["abc", 3]}, "refs"),
        ({"refs": "abc"}, "refs"),
        ({"repo_id": "Demo"}, "repo_id"),
        ({"repo_id": "a/b"}, "repo_id"),
        ({"repo_id": ""}, "repo_id"),
    ],
)
def test_event_rejects_invalid_fields(change, field):
    event = Event("e1", "demo-app", "git", "commit", AT, "題名")
    with pytest.raises(ModelError, match=rf"Event\.{field}"):
        Event.from_dict(event.to_dict() | change)


@pytest.mark.parametrize("field", ["schema", "id", "repo_id", "source", "kind", "at", "title"])
def test_event_rejects_missing_fields(field):
    data = Event("e1", "demo-app", "git", "commit", AT, "題名").to_dict()
    del data[field]
    with pytest.raises(ModelError, match=rf"Event\.{field}"):
        Event.from_dict(data)


@pytest.mark.parametrize("text", ["{", "[]", "null", '{"schema": ' + "9" * 10000 + "}"])
def test_event_rejects_unreadable_json(text):
    with pytest.raises(ModelError, match=r"Event\.json"):
        Event.from_json(text)


@pytest.mark.parametrize("score", [4, -1, True, "2"])
def test_invalid_neta_score(score):
    with pytest.raises(ModelError, match=r"Neta\.score"):
        Neta(score)
    story = Story("s1", "demo-app", AT.date(), "題名", "内容", "理由", Neta(0))
    with pytest.raises(ModelError, match=r"Story\.neta\.score"):
        Story.from_dict(story.to_dict() | {"neta": {"score": score}})


def test_invalid_date():
    with pytest.raises(ModelError, match=r"Entry\.date"):
        Entry("demo-app", AT, "/tmp/demo.md", "fake/fake", "fake/fake", AT)
    entry = Entry("demo-app", AT.date(), "/tmp/demo.md", "fake/fake", "fake/fake", AT)
    with pytest.raises(ModelError, match=r"Entry\.date"):
        Entry.from_dict(entry.to_dict() | {"date": "2026-13-01"})


def test_unknown_keys_are_ignored_and_defaults_are_used():
    event = Event("e1", "demo-app", "git", "commit", AT, "題名")
    data = event.to_dict() | {"extra": "discarded"}
    for field in ("body", "refs", "actor"):
        del data[field]
    assert Event.from_dict(data) == event
