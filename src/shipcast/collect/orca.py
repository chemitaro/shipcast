"""Orca CLIから、その日に動いた会話の発言を読み取る。"""

import json
import os
import subprocess
from collections.abc import Iterator
from datetime import UTC, date, datetime, tzinfo

from shipcast.collect.base import CollectResult, day_bounds
from shipcast.config import RepoConfig
from shipcast.model import Event, event_id


class _OrcaReadError(Exception):
    """Orca CLIを読めなかった理由。呼び出し元で警告にする。"""


def _text(value: object) -> str:
    return value if isinstance(value, str) else ""


def _lines(value: object) -> list[str]:
    return [line for raw in _text(value).splitlines() if (line := raw.strip())]


def _repository_ids(repositories: list, repo_path: str) -> tuple[set[str], set[str]]:
    own_ids: set[str] = set()
    other_ids: set[str] = set()
    for row in repositories:
        if isinstance(row, dict):
            repo_id, path = row.get("id"), row.get("path")
            if isinstance(repo_id, str) and isinstance(path, str):
                ids = own_ids if os.path.normpath(path) == repo_path else other_ids
                ids.add(repo_id)
    return own_ids, other_ids


def _conversations(
    agents: list,
    repo_path: str,
    own_ids: set[str],
    other_ids: set[str],
    start: datetime,
    end: datetime,
) -> Iterator[tuple[str, datetime, dict]]:
    seen: set[str] = set()
    for agent in agents:
        if not isinstance(agent, dict):
            continue
        session_id = _text(agent.get("orcaSessionId"))
        updated_at = agent.get("updatedAt")
        repo_id, separator, path = _text(agent.get("worktreeId")).partition("::")
        if not session_id or session_id in seen or type(updated_at) is not int or not separator:
            continue
        path = os.path.normpath(path)
        if repo_id not in own_ids and (
            repo_id in other_ids or not (path == repo_path or path.startswith(repo_path + os.sep))
        ):
            continue
        try:
            at = datetime.fromtimestamp(updated_at / 1000, UTC)
        except (OverflowError, OSError, ValueError):
            continue
        if start <= at < end:
            seen.add(session_id)
            yield session_id, at, agent


def _messages(entries: list) -> list[str]:
    messages = []
    for entry in entries:
        if not isinstance(entry, dict) or entry.get("kind") != "message":
            continue
        role = entry.get("role")
        text = _text(entry.get("text")).strip()
        if role in ("user", "assistant") and text:
            messages.append(f"[{role}]\n{text}")
    return messages


class OrcaCollector:
    name = "orca"

    def __init__(self, *, orca: str = "orca", timeout: float = 30.0, limit: int = 100):
        self.orca = orca
        self.timeout = timeout
        self.limit = limit

    def collect(self, repo: RepoConfig, day: date, tz: tzinfo) -> CollectResult:
        if not repo.orca:
            return CollectResult()

        start, end = (bound.astimezone(UTC) for bound in day_bounds(day, tz))
        try:
            agents = self._read("agents", "agent", "list")
        except _OrcaReadError as error:
            return CollectResult(
                warnings=(
                    f"Orcaの会話の一覧を読めませんでした: {error}。Orcaの会話は集めていません",
                )
            )
        warnings = []
        if agents.get("truncated") is True:
            warnings.append("Orcaの会話の一覧が途中までしか返りませんでした")

        repo_path = os.path.normpath(repo.path)
        try:
            repositories = self._read("repos", "repo", "list")
        except _OrcaReadError as error:
            warnings.append(
                f"Orcaのrepositoryの一覧を読めませんでした: {error}。pathの一致だけで会話を選びます"
            )
            own_ids, other_ids = set(), set()
        else:
            own_ids, other_ids = _repository_ids(repositories["repos"], repo_path)

        events = []
        for session_id, at, agent in _conversations(
            agents["agents"], repo_path, own_ids, other_ids, start, end
        ):
            ref = f"orca_session_id:{session_id}"
            try:
                transcript = self._read("entries", "agent", "read", ref, "--limit", str(self.limit))
            except _OrcaReadError as error:
                warnings.append(f"Orcaの会話を読めませんでした（{ref}）: {error}")
                continue
            messages = _messages(transcript["entries"])
            if not messages:
                continue

            actor = _text(agent.get("agent"))
            kind = _text(agent.get("kind"))
            workspace = _text(agent.get("workspace"))
            agent_label = "、".join(value for value in (actor, kind) if value)
            heading = [f"会話: {ref}（{agent_label}）" if agent_label else f"会話: {ref}"]
            if workspace:
                heading.append(f"workspace: {workspace}")
            if transcript.get("limited") is True:
                heading.append(f"（最新の{self.limit}件の記録だけを読みました）")

            events.append(
                Event(
                    id=event_id(self.name, repo.id, f"conversation:{session_id}:{day.isoformat()}"),
                    repo_id=repo.id,
                    source=self.name,
                    kind="conversation",
                    at=at,
                    title=_text(agent.get("title")).strip() or "（題名のない会話）",
                    body="\n\n".join(["\n".join(heading), *messages]),
                    refs=(ref,),
                    actor=actor,
                )
            )
        return CollectResult(tuple(events), tuple(warnings))

    def _read(self, field: str, *command: str) -> dict:
        try:
            completed = subprocess.run(
                [self.orca, *command, "--json"],
                capture_output=True,
                text=True,
                encoding="utf-8",
                errors="replace",
                timeout=self.timeout,
                env={**os.environ, "NO_COLOR": "1"},
                check=False,
            )
        except FileNotFoundError as error:
            raise _OrcaReadError(f"orcaのコマンドが見つかりません: {self.orca}") from error
        except subprocess.TimeoutExpired as error:
            raise _OrcaReadError(f"{self.timeout}秒で終わりませんでした") from error

        try:
            envelope = json.loads(completed.stdout)
        except (ValueError, RecursionError):
            envelope = None
        ok = envelope.get("ok") if isinstance(envelope, dict) else None
        if ok is False:
            error = envelope.get("error")
            if isinstance(error, dict):
                code = _text(error.get("code"))
                lines = _lines(error.get("message"))
                if code and lines:
                    raise _OrcaReadError(f"{code}: {lines[0]}")
        if completed.returncode or ok is False:
            lines = _lines(completed.stderr)
            raise _OrcaReadError(lines[-1] if lines else f"終了コード {completed.returncode}")
        if ok is not True:
            raise _OrcaReadError("出力をJSONとして読めません")
        result = envelope.get("result")
        if not isinstance(result, dict) or not isinstance(result.get(field), list):
            raise _OrcaReadError("出力の形が想定と違います")
        return result
