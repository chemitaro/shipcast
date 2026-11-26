"""Local SQLite storage for shipcast data."""

import sqlite3
from collections.abc import Iterable
from dataclasses import dataclass
from datetime import UTC, date, datetime, time, timedelta, tzinfo
from os import PathLike
from pathlib import Path
from typing import Self

from shipcast.model import Entry, Event, ModelError, Story, _aware, _repo_id, _text

STATE_SCHEMA_VERSION = 1
STATE_FILENAME = "state.sqlite3"

_INSERT_NETA = """
INSERT OR IGNORE INTO neta_ledger (story_id, repo_id, points, consumed)
VALUES (?, ?, ?, 0)
"""

_SCHEMA = """
CREATE TABLE IF NOT EXISTS events (
    id TEXT PRIMARY KEY,
    repo_id TEXT NOT NULL,
    source TEXT NOT NULL,
    kind TEXT NOT NULL,
    at TEXT NOT NULL,
    at_utc TEXT NOT NULL,
    json TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS events_repo_at ON events (repo_id, at_utc);

CREATE TABLE IF NOT EXISTS stories (
    id TEXT PRIMARY KEY,
    repo_id TEXT NOT NULL,
    date TEXT NOT NULL,
    json TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS stories_repo_date ON stories (repo_id, date);

CREATE TABLE IF NOT EXISTS entries (
    repo_id TEXT NOT NULL,
    date TEXT NOT NULL,
    path TEXT NOT NULL,
    json TEXT NOT NULL,
    PRIMARY KEY (repo_id, date)
);

CREATE TABLE IF NOT EXISTS runs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    repo_id TEXT NOT NULL,
    started_at TEXT NOT NULL,
    started_at_utc TEXT NOT NULL,
    finished_at TEXT NOT NULL,
    result TEXT NOT NULL CHECK (result IN ('ok', 'failed')),
    error TEXT NOT NULL DEFAULT ''
);

CREATE TABLE IF NOT EXISTS neta_ledger (
    story_id TEXT PRIMARY KEY,
    repo_id TEXT NOT NULL,
    points INTEGER NOT NULL CHECK (points BETWEEN 0 AND 3),
    consumed INTEGER NOT NULL DEFAULT 0 CHECK (consumed IN (0, 1))
);
"""


class StateError(RuntimeError):
    """The state database could not be opened."""


@dataclass(frozen=True)
class Run:
    repo_id: str
    started_at: datetime
    finished_at: datetime
    result: str
    error: str = ""

    def __post_init__(self) -> None:
        _repo_id(self.repo_id, "Run.repo_id")
        _aware(self.started_at, "Run.started_at")
        _aware(self.finished_at, "Run.finished_at")
        if self.result not in ("ok", "failed"):
            raise ModelError("Run.result: expected ok or failed")
        _text(self.error, "Run.error", empty=True)
        if self.finished_at.astimezone(UTC) < self.started_at.astimezone(UTC):
            raise ModelError("Run.finished_at: must not be earlier than started_at")


class Store:
    def __init__(self, state_dir: str | PathLike[str]) -> None:
        directory = Path(state_dir)
        directory.mkdir(parents=True, exist_ok=True)
        self.path = directory / STATE_FILENAME
        try:
            self._conn = sqlite3.connect(self.path, autocommit=sqlite3.LEGACY_TRANSACTION_CONTROL)
        except sqlite3.DatabaseError as exc:
            raise StateError(f"{self.path}: {exc}") from exc
        try:
            version = self._conn.execute("PRAGMA user_version").fetchone()[0]
            if version > STATE_SCHEMA_VERSION:
                raise StateError(f"{self.path}: unsupported state schema version {version}")
            with self._conn:
                # SQLite's legacy transaction mode begins implicitly for DML, not DDL.
                self._conn.executescript("BEGIN;\n" + _SCHEMA)
                if version == 0:
                    self._conn.execute(f"PRAGMA user_version = {STATE_SCHEMA_VERSION}")
        except sqlite3.DatabaseError as exc:
            self.close()
            raise StateError(f"{self.path}: {exc}") from exc
        except StateError:
            self.close()
            raise

    def close(self) -> None:
        self._conn.close()

    def __enter__(self) -> Self:
        return self

    def __exit__(self, exc_type, exc, traceback) -> None:
        self.close()

    def add_events(self, events: Iterable[Event]) -> int:
        with self._conn:
            return self._conn.executemany(
                """
                INSERT OR IGNORE INTO events (id, repo_id, source, kind, at, at_utc, json)
                VALUES (?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    (
                        event.id,
                        event.repo_id,
                        event.source,
                        event.kind,
                        event.at.isoformat(),
                        _utc_text(event.at),
                        event.to_json(),
                    )
                    for event in events
                ),
            ).rowcount

    def events_for(self, repo_id: str, day: date, *, tz: tzinfo) -> list[Event]:
        start = datetime.combine(day, time(0), tzinfo=tz)
        end = datetime.combine(day + timedelta(days=1), time(0), tzinfo=tz)
        rows = self._conn.execute(
            """
            SELECT json FROM events
            WHERE repo_id = ? AND at_utc >= ? AND at_utc < ?
            ORDER BY at_utc, id
            """,
            (repo_id, _utc_text(start), _utc_text(end)),
        )
        return [Event.from_json(text) for (text,) in rows]

    def save_stories(self, stories: Iterable[Story]) -> int:
        batch = list(stories)
        with self._conn:
            count = self._conn.executemany(
                """
                INSERT INTO stories (id, repo_id, date, json) VALUES (?, ?, ?, ?)
                ON CONFLICT (id) DO UPDATE SET repo_id = excluded.repo_id,
                    date = excluded.date, json = excluded.json
                """,
                (
                    (story.id, story.repo_id, story.date.isoformat(), story.to_json())
                    for story in batch
                ),
            ).rowcount
            self._conn.executemany(
                _INSERT_NETA, ((story.id, story.repo_id, story.neta.score) for story in batch)
            )
        return count

    def stories_for(self, repo_id: str, day: date) -> list[Story]:
        rows = self._conn.execute(
            "SELECT json FROM stories WHERE repo_id = ? AND date = ? ORDER BY rowid",
            (repo_id, day.isoformat()),
        )
        return [Story.from_json(text) for (text,) in rows]

    def save_entry(self, entry: Entry) -> None:
        with self._conn:
            self._conn.execute(
                """
                INSERT INTO entries (repo_id, date, path, json) VALUES (?, ?, ?, ?)
                ON CONFLICT (repo_id, date) DO UPDATE SET path = excluded.path, json = excluded.json
                """,
                (entry.repo_id, entry.date.isoformat(), entry.path, entry.to_json()),
            )

    def entry_for(self, repo_id: str, day: date) -> Entry | None:
        row = self._conn.execute(
            "SELECT json FROM entries WHERE repo_id = ? AND date = ?", (repo_id, day.isoformat())
        ).fetchone()
        return Entry.from_json(row[0]) if row is not None else None

    def record_run(self, run: Run) -> int:
        with self._conn:
            return self._conn.execute(
                """
                INSERT INTO runs (repo_id, started_at, started_at_utc, finished_at, result, error)
                VALUES (?, ?, ?, ?, ?, ?)
                """,
                (
                    run.repo_id,
                    run.started_at.isoformat(),
                    _utc_text(run.started_at),
                    run.finished_at.isoformat(),
                    run.result,
                    run.error,
                ),
            ).lastrowid

    def runs_for(self, repo_id: str) -> list[Run]:
        rows = self._conn.execute(
            """
            SELECT started_at, finished_at, result, error FROM runs
            WHERE repo_id = ? ORDER BY started_at_utc, id
            """,
            (repo_id,),
        )
        return [
            Run(repo_id, datetime.fromisoformat(start), datetime.fromisoformat(end), result, error)
            for start, end, result, error in rows
        ]

    def add_neta(self, story: Story) -> bool:
        with self._conn:
            return (
                self._conn.execute(
                    _INSERT_NETA,
                    (story.id, story.repo_id, story.neta.score),
                ).rowcount
                == 1
            )

    def neta_balance(self, repo_id: str) -> int:
        return self._conn.execute(
            "SELECT COALESCE(SUM(points), 0) FROM neta_ledger WHERE repo_id = ? AND consumed = 0",
            (repo_id,),
        ).fetchone()[0]

    def unconsumed_neta(self, repo_id: str) -> list[str]:
        rows = self._conn.execute(
            """
            SELECT story_id FROM neta_ledger WHERE repo_id = ? AND consumed = 0
            ORDER BY points DESC, rowid
            """,
            (repo_id,),
        )
        return [story_id for (story_id,) in rows]

    def unconsumed_stories(self, repo_id: str, *, limit: int | None = None) -> list[Story]:
        # SQLite binds signed 64-bit integers and treats a negative LIMIT as unlimited.
        row_limit = min(limit, 2**63 - 1) if type(limit) is int and limit >= 1 else -1
        rows = self._conn.execute(
            """
            SELECT stories.json FROM neta_ledger
            JOIN stories ON stories.id = neta_ledger.story_id
            WHERE neta_ledger.repo_id = ? AND consumed = 0 AND points > 0
            ORDER BY points DESC, neta_ledger.rowid
            LIMIT ?
            """,
            (repo_id, row_limit),
        )
        return [Story.from_json(text) for (text,) in rows]

    def consume_neta(self, story_ids: Iterable[str]) -> int:
        with self._conn:
            return self._conn.executemany(
                "UPDATE neta_ledger SET consumed = 1 WHERE story_id = ? AND consumed = 0",
                ((story_id,) for story_id in story_ids),
            ).rowcount


def _utc_text(value: datetime) -> str:
    return value.astimezone(UTC).isoformat(timespec="microseconds").removesuffix("+00:00") + "Z"
