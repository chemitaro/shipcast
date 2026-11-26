"""Data contracts shared by the collectors, journal, and state store."""

import hashlib
import json
import re
from collections.abc import Iterable, Mapping
from dataclasses import dataclass
from datetime import date, datetime
from os import PathLike
from pathlib import Path
from typing import Self

SCHEMA_VERSION = 1
SOURCES = ("git", "specdock", "orca")
REPO_ID_PATTERN = re.compile(r"[a-z0-9-]+")


class ModelError(ValueError):
    """A value does not match the data contract."""


def _text(value, field: str, *, empty: bool = False) -> str:
    if not isinstance(value, str) or (not empty and not value):
        raise ModelError(f"{field}: expected {'a' if empty else 'a nonempty'} string")
    return value


def _repo_id(value, field: str) -> None:
    if not isinstance(value, str) or not REPO_ID_PATTERN.fullmatch(value):
        raise ModelError(f"{field}: expected lowercase letters, digits, or hyphens")


def _source(value, field: str) -> None:
    if not isinstance(value, str) or value not in SOURCES:
        raise ModelError(f"{field}: expected one of {', '.join(SOURCES)}")


def _aware(value, field: str) -> None:
    if not isinstance(value, datetime) or value.utcoffset() is None:
        raise ModelError(f"{field}: expected a datetime with a time zone")


def _strings(values, field: str) -> tuple[str, ...]:
    if not isinstance(values, (list, tuple)) or any(not isinstance(v, str) for v in values):
        raise ModelError(f"{field}: expected a list or tuple of strings")
    return tuple(values)


def _mapping(data, field: str) -> Mapping:
    if not isinstance(data, Mapping):
        raise ModelError(f"{field}: expected an object")
    return data


def _fields(cls, data, required, defaults, *, schema=True) -> dict:
    name = cls.__name__
    data = _mapping(data, f"{name}.{'schema' if schema else 'score'}")
    if schema and (type(data.get("schema")) is not int or data["schema"] != SCHEMA_VERSION):
        raise ModelError(f"{name}.schema: expected integer {SCHEMA_VERSION}")
    for field in required:
        if field not in data:
            raise ModelError(f"{name}.{field}: missing required field")
    return {
        **{field: data[field] for field in required},
        **{field: data.get(field, default) for field, default in defaults.items()},
    }


def _parse_iso(value, field: str, parse):
    text = _text(value, field)
    try:
        return parse(text)
    except ValueError as exc:
        raise ModelError(f"{field}: invalid ISO 8601 value") from exc


class _JsonModel:
    def to_json(self) -> str:
        return json.dumps(self.to_dict(), ensure_ascii=False)

    @classmethod
    def from_json(cls, text: str) -> Self:
        field = f"{cls.__name__}.json"
        text = _text(text, field)
        try:
            data = json.loads(text)
        except (ValueError, RecursionError) as exc:
            raise ModelError(f"{field}: invalid JSON") from exc
        return cls.from_dict(_mapping(data, field))


@dataclass(frozen=True)
class Event(_JsonModel):
    id: str
    repo_id: str
    source: str
    kind: str
    at: datetime
    title: str
    body: str = ""
    refs: tuple[str, ...] = ()
    actor: str = ""

    def __post_init__(self) -> None:
        _text(self.id, "Event.id")
        _repo_id(self.repo_id, "Event.repo_id")
        _source(self.source, "Event.source")
        _text(self.kind, "Event.kind")
        _aware(self.at, "Event.at")
        _text(self.title, "Event.title")
        _text(self.body, "Event.body", empty=True)
        object.__setattr__(self, "refs", _strings(self.refs, "Event.refs"))
        _text(self.actor, "Event.actor", empty=True)

    def to_dict(self) -> dict:
        return {
            "schema": SCHEMA_VERSION,
            "id": self.id,
            "repo_id": self.repo_id,
            "source": self.source,
            "kind": self.kind,
            "at": self.at.isoformat(),
            "title": self.title,
            "body": self.body,
            "refs": list(self.refs),
            "actor": self.actor,
        }

    @classmethod
    def from_dict(cls, data: Mapping) -> Self:
        values = _fields(
            cls,
            data,
            ("id", "repo_id", "source", "kind", "at", "title"),
            {"body": "", "refs": (), "actor": ""},
        )
        values["at"] = _parse_iso(values["at"], "Event.at", datetime.fromisoformat)
        return cls(**values)


def _day(value, field: str) -> None:
    if not isinstance(value, date) or isinstance(value, datetime):
        raise ModelError(f"{field}: expected a date")


@dataclass(frozen=True)
class Neta:
    score: int
    reason: str = ""
    channels: tuple[str, ...] = ()

    def __post_init__(self) -> None:
        if type(self.score) is not int or not 0 <= self.score <= 3:
            raise ModelError("Neta.score: expected an integer from 0 to 3")
        _text(self.reason, "Neta.reason", empty=True)
        object.__setattr__(self, "channels", _strings(self.channels, "Neta.channels"))

    def to_dict(self) -> dict:
        return {"score": self.score, "reason": self.reason, "channels": list(self.channels)}

    @classmethod
    def from_dict(cls, data: Mapping) -> Self:
        return cls(**_fields(cls, data, ("score",), {"reason": "", "channels": ()}, schema=False))


@dataclass(frozen=True)
class Story(_JsonModel):
    id: str
    repo_id: str
    date: date
    title: str
    what: str
    why: str
    neta: Neta
    notice: tuple[str, ...] = ()
    waiting: tuple[str, ...] = ()
    event_ids: tuple[str, ...] = ()

    def __post_init__(self) -> None:
        _text(self.id, "Story.id")
        _repo_id(self.repo_id, "Story.repo_id")
        _day(self.date, "Story.date")
        for field in ("title", "what", "why"):
            _text(getattr(self, field), f"Story.{field}")
        if not isinstance(self.neta, Neta):
            raise ModelError("Story.neta: expected Neta")
        for field in ("notice", "waiting", "event_ids"):
            object.__setattr__(self, field, _strings(getattr(self, field), f"Story.{field}"))

    def to_dict(self) -> dict:
        return {
            "schema": SCHEMA_VERSION,
            "id": self.id,
            "repo_id": self.repo_id,
            "date": self.date.isoformat(),
            "title": self.title,
            "what": self.what,
            "why": self.why,
            "neta": self.neta.to_dict(),
            "notice": list(self.notice),
            "waiting": list(self.waiting),
            "event_ids": list(self.event_ids),
        }

    @classmethod
    def from_dict(cls, data: Mapping) -> Self:
        values = _fields(
            cls,
            data,
            ("id", "repo_id", "date", "title", "what", "why", "neta"),
            {"notice": (), "waiting": (), "event_ids": ()},
        )
        values["date"] = _parse_iso(values["date"], "Story.date", date.fromisoformat)
        neta = _mapping(values["neta"], "Story.neta")
        try:
            values["neta"] = Neta.from_dict(neta)
        except ModelError as exc:
            raise ModelError(f"Story.neta.{str(exc).removeprefix('Neta.')}") from exc
        return cls(**values)


@dataclass(frozen=True)
class Entry(_JsonModel):
    repo_id: str
    date: date
    path: str
    analyst: str
    writer: str
    generated_at: datetime
    story_ids: tuple[str, ...] = ()

    def __post_init__(self) -> None:
        _repo_id(self.repo_id, "Entry.repo_id")
        _day(self.date, "Entry.date")
        for field in ("path", "analyst", "writer"):
            _text(getattr(self, field), f"Entry.{field}")
        _aware(self.generated_at, "Entry.generated_at")
        object.__setattr__(self, "story_ids", _strings(self.story_ids, "Entry.story_ids"))

    def to_dict(self) -> dict:
        return {
            "schema": SCHEMA_VERSION,
            "repo_id": self.repo_id,
            "date": self.date.isoformat(),
            "path": self.path,
            "analyst": self.analyst,
            "writer": self.writer,
            "generated_at": self.generated_at.isoformat(),
            "story_ids": list(self.story_ids),
        }

    @classmethod
    def from_dict(cls, data: Mapping) -> Self:
        values = _fields(
            cls,
            data,
            ("repo_id", "date", "path", "analyst", "writer", "generated_at"),
            {"story_ids": ()},
        )
        values["date"] = _parse_iso(values["date"], "Entry.date", date.fromisoformat)
        values["generated_at"] = _parse_iso(
            values["generated_at"], "Entry.generated_at", datetime.fromisoformat
        )
        return cls(**values)


def event_id(source: str, repo_id: str, native_id: str) -> str:
    _source(source, "event_id.source")
    _repo_id(repo_id, "event_id.repo_id")
    _text(native_id, "event_id.native_id")
    return _stable_id("event", source, repo_id, native_id)


def story_id(repo_id: str, day: date, event_ids: Iterable[str]) -> str:
    _repo_id(repo_id, "story_id.repo_id")
    _day(day, "story_id.day")
    if isinstance(event_ids, (str, bytes)) or not isinstance(event_ids, Iterable):
        raise ModelError("story_id.event_ids: expected an iterable of event IDs")
    ids = sorted({_text(value, "story_id.event_ids", empty=True) for value in event_ids})
    if not ids:
        raise ModelError("story_id.event_ids: expected at least one event ID")
    return _stable_id("story", repo_id, day.isoformat(), *ids)


def _stable_id(*parts: str) -> str:
    return hashlib.sha256("\x1f".join(parts).encode("utf-8")).hexdigest()[:16]


def journal_path(journal_dir: str | PathLike[str], repo: str, day: date) -> Path:
    _repo_id(repo, "journal_path.repo")
    _day(day, "journal_path.day")
    return Path(journal_dir) / repo / f"{day:%Y}" / f"{day.isoformat()}.md"


JOURNAL_REQUIRED_FIELDS = ("title", "lead", "date", "repo")
JOURNAL_FIELDS = (
    *JOURNAL_REQUIRED_FIELDS,
    "category",
    "analyst",
    "writer",
    "generated_at",
    "schema",
)
_JOURNAL_KEY = re.compile(r"[a-z_]+")


class JournalFormatError(ValueError):
    """The journal front matter is invalid."""


@dataclass(frozen=True)
class JournalMeta:
    title: str
    lead: str
    date: date
    repo: str
    category: str | None = None
    analyst: str | None = None
    writer: str | None = None
    generated_at: str | None = None
    schema: int | None = None

    def __post_init__(self) -> None:
        for field in JOURNAL_FIELDS:
            if field in ("date", "schema"):
                continue
            value = getattr(self, field)
            if value is None and field not in JOURNAL_REQUIRED_FIELDS:
                continue
            if (
                not isinstance(value, str)
                or not value
                or value != value.strip()
                or "\n" in value
                or "\r" in value
            ):
                raise JournalFormatError(
                    f"JournalMeta.{field}: expected a nonempty single line without outer whitespace"
                )
        if not REPO_ID_PATTERN.fullmatch(self.repo):
            raise JournalFormatError(
                "JournalMeta.repo: expected lowercase letters, digits, or hyphens"
            )
        if not isinstance(self.date, date) or isinstance(self.date, datetime):
            raise JournalFormatError("JournalMeta.date: expected a date")
        if self.schema is not None and (type(self.schema) is not int or self.schema < 0):
            raise JournalFormatError("JournalMeta.schema: expected a nonnegative integer")


def write_frontmatter(meta: JournalMeta) -> str:
    lines = ["---"]
    for field in JOURNAL_FIELDS:
        value = getattr(meta, field)
        if value is not None:
            lines.append(f"{field}: {meta.date.isoformat() if field == 'date' else value}")
    return "\n".join([*lines, "---", ""])


def parse_journal(text: str) -> tuple[JournalMeta, str]:
    lines = text.removeprefix("\ufeff").split("\n")
    if lines[0].rstrip() != "---":
        raise JournalFormatError("JournalMeta.line 1: expected an opening ---")
    closing = next(
        (i for i, line in enumerate(lines[1:], 1) if line.removesuffix("\r") == "---"), None
    )
    if closing is None:
        raise JournalFormatError("JournalMeta.frontmatter: missing closing ---")

    values = {}
    for number, line in enumerate(lines[1:closing], 2):
        if not line.strip():
            continue
        key, separator, value = line.partition(":")
        key = key.strip()
        if not separator or not _JOURNAL_KEY.fullmatch(key):
            raise JournalFormatError(f"JournalMeta.line {number}: expected key: value")
        if key in values:
            raise JournalFormatError(f"JournalMeta.{key}: duplicate key")
        values[key] = value.strip()

    missing = [field for field in JOURNAL_REQUIRED_FIELDS if not values.get(field)]
    if missing:
        raise JournalFormatError(f"前付けに必須の項目がありません: {', '.join(missing)}")
    try:
        day = date.fromisoformat(values["date"])
    except ValueError as exc:
        raise JournalFormatError("JournalMeta.date: invalid ISO 8601 date") from exc
    schema = values.get("schema")
    if schema and not schema.isdecimal():
        raise JournalFormatError("JournalMeta.schema: expected decimal digits")
    try:
        version = int(schema) if schema else None
    except ValueError as exc:
        raise JournalFormatError("JournalMeta.schema: expected decimal digits") from exc

    meta = JournalMeta(
        title=values["title"],
        lead=values["lead"],
        date=day,
        repo=values["repo"],
        category=values.get("category") or None,
        analyst=values.get("analyst") or None,
        writer=values.get("writer") or None,
        generated_at=values.get("generated_at") or None,
        schema=version,
    )
    return meta, "\n".join(lines[closing + 1 :])


def read_frontmatter(path: str | PathLike[str]) -> JournalMeta:
    with Path(path).open(encoding="utf-8", newline="") as file:
        return parse_journal(file.read())[0]
