from dataclasses import dataclass
from datetime import date, datetime, timedelta, timezone

import pytest

from shipcast.collect import COLLECTORS
from shipcast.collect.base import CollectError, CollectResult, collect_repo, day_bounds
from shipcast.config import RepoConfig
from shipcast.model import SOURCES, Event, event_id
from shipcast.state import Store

DAY = date(2026, 11, 26)
TZ = timezone(timedelta(hours=9))


@dataclass
class FakeCollector:
    name: str
    result: object

    def collect(self, repo, day, tz):
        if isinstance(self.result, Exception):
            raise self.result
        return self.result


def make_event(native_id="demo", *, repo_id="demo", source="git", at=None):
    return Event(
        event_id(source, repo_id, native_id),
        repo_id,
        source,
        "commit",
        at or datetime(2026, 11, 26, 12, tzinfo=TZ),
        "架空の変更",
    )


def test_collect_repo_saves_events_idempotently(tmp_path):
    repo = RepoConfig("demo", tmp_path, "main", "Demo", False)
    event = make_event()
    result = CollectResult(events=[event], warnings=["架空の警告"])
    assert result.events == (event,)
    assert result.warnings == ("架空の警告",)

    with Store(tmp_path / "state") as store:
        collectors = (FakeCollector("git", result),)
        first = collect_repo(store, repo, DAY, tz=TZ, collectors=collectors)
        second = collect_repo(store, repo, DAY, tz=TZ, collectors=collectors)
        assert first.ok and second.ok
        assert (first.repo_id, first.day, first.events, first.saved) == ("demo", DAY, (event,), 1)
        assert first.warnings == ("git: 架空の警告",)
        assert second.saved == 0
        assert store.events_for("demo", DAY, tz=TZ) == [event]
        assert store.runs_for("demo") == []


@pytest.mark.parametrize(
    "invalid, detail",
    [
        ("invalid result", "str"),
        (CollectResult(events=["invalid event"]), "str"),
        (CollectResult(events=[make_event(source="orca")]), make_event(source="orca").id),
        (CollectResult(events=[make_event(repo_id="other")]), make_event(repo_id="other").id),
        (
            CollectResult(events=[make_event(at=datetime(2026, 11, 27, tzinfo=TZ))]),
            make_event().id,
        ),
    ],
)
def test_collect_repo_discards_entire_invalid_result(tmp_path, invalid, detail):
    repo = RepoConfig("demo", tmp_path, "main", "Demo", False)
    valid = make_event("discarded")
    kept = make_event("kept", source="orca")
    if isinstance(invalid, CollectResult):
        invalid = CollectResult((valid, *invalid.events), ("架空の注意",))
    collectors = (
        FakeCollector("git", invalid),
        FakeCollector("specdock", CollectError("架空の失敗")),
        FakeCollector("orca", CollectResult((kept,))),
    )
    with Store(tmp_path / "state") as store:
        result = collect_repo(store, repo, DAY, tz=TZ, collectors=collectors)
        assert not result.ok
        assert result.events == (kept,)
        assert result.saved == 1
        assert result.errors[0].startswith("git: 約束に合わないEventを返しました（")
        assert detail in result.errors[0]
        assert result.errors[1:] == ("specdock: 架空の失敗",)
        assert result.warnings == (
            ("git: 架空の注意",) if isinstance(invalid, CollectResult) else ()
        )
        assert store.events_for("demo", DAY, tz=TZ) == [kept]


def test_day_bounds_match_store(tmp_path):
    start, end = day_bounds(DAY, TZ)
    assert start.isoformat() == "2026-11-26T00:00:00+09:00"
    assert end.isoformat() == "2026-11-27T00:00:00+09:00"
    events = [
        make_event(str(index), at=at)
        for index, at in enumerate(
            (start - timedelta(seconds=1), start, end - timedelta(seconds=1), end)
        )
    ]
    with Store(tmp_path / "state") as store:
        store.add_events(events)
        assert store.events_for("demo", DAY, tz=TZ) == events[1:3]


def test_collector_names_are_unique_and_known():
    names = [collector.name for collector in COLLECTORS]
    assert len(set(names)) == len(names)
    assert set(names) <= set(SOURCES)
