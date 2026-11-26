"""素材を読む collector の約束と、検証・保存の共通処理。"""

from collections.abc import Sequence
from dataclasses import dataclass
from datetime import UTC, date, datetime, time, timedelta, tzinfo
from typing import Protocol

from shipcast.config import RepoConfig
from shipcast.model import Event
from shipcast.state import Store


class CollectError(Exception):
    """この出所から読めない理由と、直す対象の path や ref を日本語で伝える。"""


@dataclass(frozen=True)
class CollectResult:
    events: tuple[Event, ...] = ()
    warnings: tuple[str, ...] = ()

    def __post_init__(self) -> None:
        object.__setattr__(self, "events", tuple(self.events))
        object.__setattr__(self, "warnings", tuple(self.warnings))


class Collector(Protocol):
    """対象の repository と道具の状態を変えず、その日の Event を読む。

    Event の source は name（SOURCES のいずれか）、repo_id は repo.id とする。
    at は day_bounds の半開区間に収め、id は event_id(name, repo.id, native_id)
    で作る。native_id は出所内で一意とする。読めなければ CollectError を投げ、
    続けられる問題は warnings に入れる。想定外の例外はそのまま伝える。
    """

    name: str

    def collect(self, repo: RepoConfig, day: date, tz: tzinfo) -> CollectResult: ...


def day_bounds(day: date, tz: tzinfo) -> tuple[datetime, datetime]:
    """Store.events_for と同じ、当日の始まりから翌日の始まりまで。"""
    return (
        datetime.combine(day, time(0), tzinfo=tz),
        datetime.combine(day + timedelta(days=1), time(0), tzinfo=tz),
    )


@dataclass(frozen=True)
class RepoCollection:
    repo_id: str
    day: date
    events: tuple[Event, ...]
    saved: int
    warnings: tuple[str, ...]
    errors: tuple[str, ...]

    @property
    def ok(self) -> bool:
        return not self.errors


def collect_repo(
    store: Store,
    repo: RepoConfig,
    day: date,
    *,
    tz: tzinfo,
    collectors: Sequence[Collector],
) -> RepoCollection:
    start, end = (bound.astimezone(UTC) for bound in day_bounds(day, tz))
    events: list[Event] = []
    warnings: list[str] = []
    errors: list[str] = []
    for collector in collectors:
        try:
            result = collector.collect(repo, day, tz)
        except CollectError as error:
            errors.append(f"{collector.name}: {error}")
            continue
        problem = "約束に合わないEventを返しました"
        if not isinstance(result, CollectResult):
            errors.append(f"{collector.name}: {problem}（戻り値の型: {type(result).__name__}）")
            continue
        warnings.extend(f"{collector.name}: {warning}" for warning in result.warnings)
        for event in result.events:
            if not isinstance(event, Event):
                reason = f"要素の型: {type(event).__name__}"
            elif event.source != collector.name:
                reason = f"出所が一致しません: {event.id}"
            elif event.repo_id != repo.id:
                reason = f"repositoryが一致しません: {event.id}"
            elif not start <= event.at < end:
                reason = f"対象日の外です: {event.id}"
            else:
                continue
            errors.append(f"{collector.name}: {problem}（{reason}）")
            break
        else:
            events.extend(result.events)

    saved = store.add_events(events)
    return RepoCollection(repo.id, day, tuple(events), saved, tuple(warnings), tuple(errors))
