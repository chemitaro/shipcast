import re
import sqlite3
from contextlib import closing
from dataclasses import replace
from datetime import UTC, date, datetime, timedelta, timezone

import pytest

from shipcast.model import Entry, Event, ModelError, Neta, Story
from shipcast.state import STATE_FILENAME, STATE_SCHEMA_VERSION, Run, StateError, Store

JST = timezone(timedelta(hours=9))
DAY = date(2026, 11, 26)


def test_creates_version_one_tables_and_reopens(tmp_path):
    assert STATE_SCHEMA_VERSION == 1
    assert STATE_FILENAME == "state.sqlite3"
    directory = tmp_path / "state"
    with Store(directory) as store:
        assert store.path == directory / "state.sqlite3"
    with closing(sqlite3.connect(directory / "state.sqlite3")) as conn:
        assert conn.execute("PRAGMA user_version").fetchone() == (1,)
        tables = conn.execute(
            "SELECT name FROM sqlite_master WHERE type = 'table' AND name != 'sqlite_sequence'"
        )
        assert {name for (name,) in tables} == {
            "events",
            "stories",
            "entries",
            "runs",
            "neta_ledger",
        }
    with Store(directory) as store:
        assert store.path.is_file()


@pytest.mark.parametrize("newer", [True, False])
def test_unreadable_state_is_left_untouched(tmp_path, newer):
    directory = tmp_path / "state"
    directory.mkdir()
    path = directory / "state.sqlite3"
    if newer:
        with closing(sqlite3.connect(path)) as conn, conn:
            conn.execute("PRAGMA user_version = 2")
    else:
        path.write_text("invalid database", encoding="utf-8")
    before = path.read_bytes()

    with pytest.raises(StateError, match=re.escape(str(path))) as error:
        Store(directory)

    assert path.read_bytes() == before
    if newer:
        assert "2" in str(error.value)
        with closing(sqlite3.connect(path)) as conn:
            assert conn.execute("SELECT name FROM sqlite_master").fetchall() == []


def test_events_use_local_day_and_sort_by_instant_then_id(tmp_path):
    midnight = Event(
        "start", "demo-app", "git", "commit", datetime(2026, 11, 26, tzinfo=JST), "開始"
    )
    first = Event("a", "demo-app", "git", "commit", datetime(2026, 11, 25, 16, tzinfo=UTC), "変更A")
    tie = Event("b", "demo-app", "git", "commit", datetime(2026, 11, 26, 1, tzinfo=JST), "変更B")
    last = Event(
        "end", "demo-app", "git", "commit", datetime(2026, 11, 26, 23, 59, tzinfo=JST), "終了"
    )
    before = Event(
        "before", "demo-app", "git", "commit", datetime(2026, 11, 25, 23, 59, tzinfo=JST), "前日"
    )
    after = Event("after", "demo-app", "git", "commit", datetime(2026, 11, 27, tzinfo=JST), "翌日")
    other = Event("other", "demo-lib", "git", "commit", first.at, "別の記録")
    events = [last, before, tie, after, first, other, midnight]

    with Store(tmp_path / "state") as store:
        assert store.add_events(iter(events)) == 7
        assert store.add_events(events) == 0
        assert store.events_for("demo-app", DAY, tz=JST) == [midnight, first, tie, last]
        assert store.events_for("demo-lib", DAY, tz=JST) == [other]
    with closing(sqlite3.connect(tmp_path / "state/state.sqlite3")) as conn:
        assert conn.execute("SELECT at, at_utc FROM events WHERE id = 'start'").fetchone() == (
            "2026-11-26T00:00:00+09:00",
            "2026-11-25T15:00:00.000000Z",
        )


def test_add_events_rolls_back_when_iterable_fails(tmp_path):
    event = Event("e1", "demo-app", "git", "commit", datetime(2026, 11, 26, tzinfo=JST), "変更")

    def interrupted():
        yield event
        raise ValueError("interrupted")

    with Store(tmp_path / "state") as store:
        with pytest.raises(ValueError, match="interrupted"):
            store.add_events(interrupted())
        assert store.events_for("demo-app", DAY, tz=JST) == []
        assert store.add_events([event]) == 1


def test_story_and_entry_upserts_preserve_story_order_and_survive_reopen(tmp_path):
    at = datetime(2026, 11, 26, 11, tzinfo=JST)
    first = Story("s2", "demo-app", DAY, "変更A", "内容", "理由", Neta(0))
    second = Story("s1", "demo-app", DAY, "変更B", "内容", "理由", Neta(1))
    updated = replace(first, what="更新した内容")
    entry = Entry("demo-app", DAY, "/tmp/demo.md", "fake/fake", "fake/fake", at, ("s2",))
    updated_entry = replace(entry, path="/tmp/changed.md", story_ids=("s2", "s1"))
    directory = tmp_path / "state"

    with Store(directory) as store:
        assert store.entry_for("demo-app", DAY) is None
        assert store.save_stories(iter([first, second])) == 2
        assert store.save_stories([updated]) == 1
        assert store.save_entry(entry) is None
        store.save_entry(updated_entry)

    with Store(directory) as store:
        assert store.stories_for("demo-app", DAY) == [updated, second]
        assert store.stories_for("demo-app", DAY + timedelta(days=1)) == []
        assert store.stories_for("demo-lib", DAY) == []
        assert store.entry_for("demo-app", DAY) == updated_entry
        assert store.entry_for("demo-lib", DAY) is None
    with closing(sqlite3.connect(directory / "state.sqlite3")) as conn:
        assert conn.execute("SELECT path FROM entries").fetchall() == [("/tmp/changed.md",)]


def test_save_stories_rolls_back_failed_batch(tmp_path):
    story = Story("s1", "demo-app", DAY, "変更", "内容", "理由", Neta(1))

    def interrupted():
        yield story
        raise ValueError("interrupted")

    with Store(tmp_path / "state") as store:
        with pytest.raises(ValueError, match="interrupted"):
            store.save_stories(interrupted())
        assert store.stories_for("demo-app", DAY) == []


def test_save_stories_credits_initial_points_once_per_repo(tmp_path):
    first = Story("s1", "demo-app", DAY, "変更A", "内容", "理由", Neta(2))
    second = replace(first, id="s2", title="変更B", neta=Neta(1))
    other = replace(first, id="s3", repo_id="demo-lib", neta=Neta(3))
    zero = replace(first, id="s4", neta=Neta(0))
    updated = replace(second, title="変更Bの補足", neta=Neta(3))

    with Store(tmp_path) as store:
        assert store.save_stories(iter([first, second, other])) == 3
        assert store.neta_balance("demo-app") == 3
        assert store.neta_balance("demo-lib") == 3
        assert store.save_stories([updated, zero]) == 2
        assert store.stories_for("demo-app", DAY) == [first, updated, zero]
        assert store.neta_balance("demo-app") == 3
        assert store.unconsumed_neta("demo-app") == ["s1", "s2", "s4"]
        assert store.consume_neta(["s1"]) == 1
        assert store.save_stories([first]) == 1
        assert store.neta_balance("demo-app") == 1
        assert store.unconsumed_neta("demo-app") == ["s2", "s4"]


def test_save_stories_rolls_back_both_tables_when_ledger_write_fails(tmp_path):
    first = Story("s1", "demo-app", DAY, "変更A", "内容", "理由", Neta(2))
    second = replace(first, id="s2", title="変更B")

    with Store(tmp_path) as store:
        with closing(sqlite3.connect(store.path)) as conn:
            conn.execute("""
                CREATE TRIGGER reject_second_credit BEFORE INSERT ON neta_ledger
                WHEN NEW.story_id = 's2'
                BEGIN
                    SELECT RAISE(ABORT, 'interrupted ledger write');
                END
                """)
        with pytest.raises(sqlite3.IntegrityError, match="interrupted ledger write"):
            store.save_stories([first, second])
        assert store.stories_for("demo-app", DAY) == []
        assert store.unconsumed_neta("demo-app") == []


def test_unconsumed_stories_uses_ledger_points_and_insertion_order(tmp_path):
    first = Story("s-z", "demo-app", DAY, "変更A", "内容", "理由", Neta(2))
    tie = replace(first, id="s-a", title="変更B")
    lower = replace(first, id="s-low", neta=Neta(1))
    updated = replace(lower, neta=Neta(3))
    consumed = replace(first, id="s-consumed", neta=Neta(3))
    zero = replace(first, id="s-zero", neta=Neta(0))
    other = replace(first, id="s-other", repo_id="demo-lib", neta=Neta(3))
    orphan = replace(first, id="s-orphan", neta=Neta(3))

    with Store(tmp_path) as store:
        store.add_neta(orphan)
        store.save_stories([lower, first, tie, consumed, zero, other])
        store.save_stories([updated])
        store.consume_neta([consumed.id])

        assert store.unconsumed_stories("demo-app") == [first, tie, updated]
        assert store.unconsumed_stories("demo-app", limit=1) == [first]
        assert store.unconsumed_stories("demo-app", limit=0) == [first, tie, updated]
        assert store.unconsumed_stories("demo-app", limit=10**20) == [first, tie, updated]
        assert store.unconsumed_stories("demo-lib") == [other]


def test_runs_round_trip_and_sort_by_start_instant_then_id(tmp_path):
    start = datetime(2026, 11, 26, 11, tzinfo=JST)
    later = Run("demo-app", start, start + timedelta(minutes=10), "ok")
    earlier = Run(
        "demo-app", datetime(2026, 11, 26, 1, tzinfo=UTC), start, "failed", "架空のエラー"
    )
    same_start = Run("demo-app", start.astimezone(UTC), start, "ok")
    other = Run("demo-lib", start, start, "ok")
    directory = tmp_path / "state"

    with Store(directory) as store:
        ids = [store.record_run(run) for run in (later, earlier, same_start, other)]
        assert all(isinstance(value, int) for value in ids)
        assert ids == sorted(set(ids))
    with Store(directory) as store:
        assert store.runs_for("demo-app") == [earlier, later, same_start]
        assert store.runs_for("demo-lib") == [other]


@pytest.mark.parametrize("field", ["repo_id", "started_at", "finished_at", "result"])
def test_rejects_invalid_run(field):
    start = datetime(2026, 11, 26, 11, tzinfo=JST)
    values = {"repo_id": "demo-app", "started_at": start, "finished_at": start, "result": "ok"}
    invalid = {
        "repo_id": "A",
        "started_at": start.replace(tzinfo=None),
        "finished_at": start - timedelta(seconds=1),
        "result": "unknown",
    }
    with pytest.raises(ModelError, match=rf"Run\.{field}"):
        Run(**(values | {field: invalid[field]}))


def test_neta_counts_each_story_once_and_consumes_only_unconsumed_ids(tmp_path):
    low = Story("s1", "demo-app", DAY, "変更A", "内容", "理由", Neta(2))
    high = Story("s3", "demo-app", DAY, "変更B", "内容", "理由", Neta(3))
    tie = Story("s2", "demo-app", DAY, "変更C", "内容", "理由", Neta(3))
    other = Story("s4", "demo-lib", DAY, "別の記録", "内容", "理由", Neta(1))
    directory = tmp_path / "state"

    with Store(directory) as store:
        assert store.neta_balance("demo-app") == 0
        assert store.unconsumed_neta("demo-app") == []
        assert store.add_neta(low) is True
        assert store.add_neta(high) is True
        assert store.add_neta(replace(low, neta=Neta(0))) is False
        assert store.neta_balance("demo-app") == 5
        assert store.add_neta(other) is True
        assert store.add_neta(tie) is True
        assert store.unconsumed_neta("demo-app") == ["s3", "s2", "s1"]
        assert store.consume_neta(iter(["s3", "s3", "unknown"])) == 1
        assert store.consume_neta(["s3"]) == 0
        assert store.add_neta(high) is False

    with Store(directory) as store:
        assert store.neta_balance("demo-app") == 5
        assert store.neta_balance("demo-lib") == 1
        assert store.unconsumed_neta("demo-app") == ["s2", "s1"]
        assert store.consume_neta(["s2", "s1"]) == 2
        assert store.neta_balance("demo-app") == 0
