"""SpecDockのScopeとtodoの出来事を読み取る。"""

import json
import os
import re
import subprocess
from dataclasses import dataclass
from datetime import UTC, date, datetime, tzinfo
from pathlib import Path

from shipcast.collect.base import CollectError, CollectResult, day_bounds
from shipcast.config import RepoConfig
from shipcast.model import Event, event_id

_GITHUB_REF = re.compile(r"gh:([^/#\s]+/[^/#\s]+)#[0-9]+")


class _OutputShapeError(ValueError):
    """外部コマンドの出力で、形の違う項目を示す。"""


@dataclass(frozen=True)
class _Scope:
    id: str
    number: int
    kind: str
    title: str
    parent_id: str
    url: str
    state_reason: str


@dataclass(frozen=True)
class _Issue:
    created_at: datetime
    closed_at: datetime | None
    state: str
    url: str


def _decode(output: str) -> object:
    try:
        return json.loads(output)
    except json.JSONDecodeError:
        return None


def _object(value: object, field: str) -> dict:
    if not isinstance(value, dict):
        raise _OutputShapeError(field)
    return value


def _array(value: object, field: str) -> list:
    if not isinstance(value, list):
        raise _OutputShapeError(field)
    return value


def _text(value: object, field: str) -> str:
    if not isinstance(value, str):
        raise _OutputShapeError(field)
    return value


def _optional_text(value: object, field: str) -> str:
    return "" if value is None else _text(value, field)


def _instant(value: object, field: str) -> datetime:
    try:
        at = datetime.fromisoformat(_text(value, field))
    except ValueError as error:
        raise _OutputShapeError(field) from error
    if at.utcoffset() is None:
        raise _OutputShapeError(field)
    return at


def _lines(text: str) -> list[str]:
    return [line.strip() for line in text.splitlines() if line.strip()]


def _failure_reason(command: subprocess.CompletedProcess[str], envelope: object = None) -> str:
    error = envelope.get("error") if isinstance(envelope, dict) else None
    if isinstance(error, dict):
        code, message = error.get("code"), error.get("message")
        if isinstance(code, str) and isinstance(message, str):
            lines = _lines(message)
            if lines:
                return f"{code}: {lines[0]}"
    lines = _lines(command.stderr)
    return lines[-1] if lines else f"終了コード {command.returncode}"


def _scope_groups(items: list) -> dict[str, list[_Scope]]:
    groups: dict[str, list[_Scope]] = {}
    for item in items:
        scope = _object(item, "items[]")
        if _text(scope.get("backend"), "backend") != "github":
            continue
        ref, number = scope.get("github_ref"), scope.get("number")
        match = _GITHUB_REF.fullmatch(ref) if isinstance(ref, str) else None
        if match is None or type(number) is not int:
            continue
        groups.setdefault(match[1], []).append(
            _Scope(
                id=_text(scope.get("id"), "id"),
                number=number,
                kind=_text(scope.get("kind"), "kind"),
                title=_text(scope.get("title"), "title"),
                parent_id=_optional_text(scope.get("parent_id"), "parent_id"),
                url=_optional_text(scope.get("url"), "url"),
                state_reason=_optional_text(scope.get("state_reason"), "state_reason"),
            )
        )
    return groups


def _issue_index(items: list) -> dict[int, _Issue]:
    issues = {}
    for item in items:
        issue = _object(item, "issue")
        number = issue.get("number")
        if type(number) is not int:
            raise _OutputShapeError("number")
        state = issue.get("state")
        if state not in ("OPEN", "CLOSED"):
            raise _OutputShapeError("state")
        closed = issue.get("closedAt", "")
        issues[number] = _Issue(
            created_at=_instant(issue.get("createdAt"), "createdAt"),
            closed_at=None if closed is None else _instant(closed, "closedAt"),
            state=state,
            url=_text(issue.get("url"), "url"),
        )
    return issues


def _catalog_warnings(result: dict) -> list[str]:
    warnings = []
    for item in _array(result.get("repositories"), "data.result.repositories"):
        row = _object(item, "repositories[]")
        status = _text(row.get("status"), "repositories[].status")
        repository = row.get("repository")
        if repository is not None:
            _text(repository, "repositories[].repository")
        problem = row.get("problem")
        if problem is not None:
            _object(problem, "repositories[].problem")
        if status != "ok":
            warnings.append(f"todoのカタログを読めません: {repository}: {problem}")
    return warnings


def _body(*fields: tuple[str, str]) -> str:
    return "\n".join(f"{label}: {value}" for label, value in fields if value)


def _scope_events(
    repo_id: str,
    scope: _Scope,
    issue: _Issue,
    start: datetime,
    end: datetime,
) -> list[Event]:
    url = scope.url or issue.url
    title = scope.title or "（題名のないScope）"
    refs = (scope.id, url)
    fields = (("Scope", f"{scope.id}（{scope.kind}）"), ("親", scope.parent_id), ("URL", url))
    events = []
    if start <= issue.created_at < end:
        events.append(
            Event(
                event_id("specdock", repo_id, f"scope:{scope.id}:opened"),
                repo_id,
                "specdock",
                "scope_opened",
                issue.created_at,
                title,
                _body(*fields),
                refs,
            )
        )
    if issue.state == "CLOSED" and issue.closed_at is not None and start <= issue.closed_at < end:
        events.append(
            Event(
                event_id("specdock", repo_id, f"scope:{scope.id}:closed"),
                repo_id,
                "specdock",
                "scope_closed",
                issue.closed_at,
                title,
                _body(*fields, ("閉じた理由", scope.state_reason)),
                refs,
            )
        )
    return events


def _todo_events(repo_id: str, items: list, start: datetime, end: datetime) -> list[Event]:
    events = []
    for item in items:
        todo = _object(_object(item, "items[]").get("todo"), "todo")
        todo_id = _text(todo.get("id"), "todo.id")
        title = _text(todo.get("title"), "todo.title") or "（題名のないtodo）"
        kind = _text(todo.get("kind"), "todo.kind")
        status = _text(todo.get("status"), "todo.status")
        created = _instant(todo.get("created_at"), "todo.created_at")
        due = _optional_text(todo.get("due"), "todo.due")
        origin = _object(todo.get("origin"), "todo.origin")
        registered_by = _optional_text(origin.get("by"), "todo.origin.by")
        scopes = _object(todo.get("scopes"), "todo.scopes")
        related = tuple(
            _text(scope, "todo.scopes.related[]")
            for scope in _array(scopes.get("related"), "todo.scopes.related")
        )
        refs = (todo_id, *related)
        identity = ("todo", f"{todo_id}（{kind}）")
        related_line = ("関連するScope", "、".join(related))
        if start <= created < end:
            events.append(
                Event(
                    event_id("specdock", repo_id, f"todo:{todo_id}:open"),
                    repo_id,
                    "specdock",
                    "todo_open",
                    created,
                    title,
                    _body(
                        identity,
                        ("今の状態", status),
                        ("期限", due),
                        related_line,
                        ("登録した側", registered_by),
                    ),
                    refs,
                )
            )
        resolution = todo.get("resolution")
        if resolution is None:
            continue
        resolution = _object(resolution, "todo.resolution")
        resolved = _instant(resolution.get("at"), "todo.resolution.at")
        resolved_by = _optional_text(resolution.get("by"), "todo.resolution.by")
        choice = _optional_text(resolution.get("choice"), "todo.resolution.choice")
        record = _optional_text(resolution.get("record"), "todo.resolution.record")
        if status == "done" and start <= resolved < end:
            events.append(
                Event(
                    event_id("specdock", repo_id, f"todo:{todo_id}:done"),
                    repo_id,
                    "specdock",
                    "todo_done",
                    resolved,
                    title,
                    _body(
                        identity,
                        ("完了した側", resolved_by),
                        ("選んだ選択肢", choice),
                        ("記録", record),
                        related_line,
                    ),
                    refs,
                )
            )
    return events


class SpecDockCollector:
    name = "specdock"

    def __init__(
        self,
        *,
        spec_dock: str = "spec-dock",
        gh: str = "gh",
        timeout: float = 60.0,
        issue_limit: int = 500,
    ):
        self.spec_dock = spec_dock
        self.gh = gh
        self.timeout = timeout
        self.issue_limit = issue_limit

    def collect(self, repo: RepoConfig, day: date, tz: tzinfo) -> CollectResult:
        if not (repo.path / "spec-dock" / "workspace.json").is_file():
            return CollectResult()

        start, end = (bound.astimezone(UTC) for bound in day_bounds(day, tz))
        try:
            scopes = self._specdock_result(repo.path, "scope")
            groups = _scope_groups(_array(scopes.get("items"), "data.result.items"))
        except _OutputShapeError as error:
            raise self._shape_error(repo.path, "scope", error) from error
        try:
            todos = self._specdock_result(repo.path, "todo", "--status", "all")
            items = _array(todos.get("items"), "data.result.items")
            warnings = _catalog_warnings(todos)
            todo_events = _todo_events(repo.id, items, start, end)
        except _OutputShapeError as error:
            raise self._shape_error(repo.path, "todo", error) from error

        events = []
        for owner in sorted(groups):
            try:
                issues, count = self._read_issues(owner)
            except CollectError as error:
                warnings.append(
                    f"gh issue list を読めませんでした（{owner}）: {error}。"
                    "Scopeの作成と終了は集めていません"
                )
                continue
            if count >= self.issue_limit:
                warnings.append(
                    f"{owner} のIssueが{self.issue_limit}件以上あるので、"
                    "古いScopeの時刻を読めないことがあります"
                )
            for scope in groups[owner]:
                if (issue := issues.get(scope.number)) is not None:
                    events.extend(_scope_events(repo.id, scope, issue, start, end))
        return CollectResult(tuple(events + todo_events), tuple(warnings))

    def _run(self, argv: list[str]) -> subprocess.CompletedProcess[str]:
        env = os.environ.copy()
        env.update(GH_PROMPT_DISABLED="1", GH_NO_UPDATE_NOTIFIER="1", NO_COLOR="1")
        return subprocess.run(
            argv,
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
            timeout=self.timeout,
            env=env,
            check=False,
        )

    def _specdock_result(self, path: Path, command: str, *options: str) -> dict:
        sub = f"{command} list"
        try:
            completed = self._run(
                [
                    self.spec_dock,
                    command,
                    "list",
                    *options,
                    "--offline",
                    "--json",
                    "--project",
                    str(path),
                ]
            )
        except FileNotFoundError as error:
            raise CollectError(f"spec-dockのコマンドが見つかりません: {self.spec_dock}") from error
        except subprocess.TimeoutExpired as error:
            raise CollectError(
                f"spec-dock {sub} が{self.timeout}秒で終わりませんでした: {path}"
            ) from error
        envelope = _decode(completed.stdout)
        if completed.returncode != 0:
            raise CollectError(
                f"spec-dock {sub} が失敗しました: {path}: {_failure_reason(completed, envelope)}"
            )
        if not isinstance(envelope, dict):
            raise CollectError(f"spec-dock {sub} の出力をJSONとして読めません: {path}")
        if envelope.get("status") != "succeeded":
            raise CollectError(
                f"spec-dock {sub} が失敗しました: {path}: {_failure_reason(completed, envelope)}"
            )
        data = _object(envelope.get("data"), "data")
        return _object(data.get("result"), "data.result")

    @staticmethod
    def _shape_error(path: Path, command: str, error: _OutputShapeError) -> CollectError:
        return CollectError(f"spec-dock {command} list の出力の形が想定と違います: {path}: {error}")

    def _read_issues(self, owner: str) -> tuple[dict[int, _Issue], int]:
        try:
            completed = self._run(
                [
                    self.gh,
                    "issue",
                    "list",
                    "--repo",
                    owner,
                    "--state",
                    "all",
                    "--limit",
                    str(self.issue_limit),
                    "--json",
                    "number,title,state,createdAt,closedAt,url",
                ]
            )
        except FileNotFoundError as error:
            raise CollectError(f"ghのコマンドが見つかりません: {self.gh}") from error
        except subprocess.TimeoutExpired as error:
            raise CollectError(f"{self.timeout}秒で終わりませんでした") from error
        if completed.returncode != 0:
            raise CollectError(_failure_reason(completed))
        try:
            items = _array(_decode(completed.stdout), "issues")
            return _issue_index(items), len(items)
        except _OutputShapeError as error:
            raise CollectError("出力の形が想定と違います") from error
