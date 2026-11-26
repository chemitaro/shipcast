"""設定された ref から Git の出来事を読み取る。"""

import os
import subprocess
from dataclasses import dataclass
from datetime import UTC, date, datetime, tzinfo
from pathlib import Path

from shipcast.collect.base import CollectError, CollectResult, day_bounds
from shipcast.config import RepoConfig
from shipcast.model import Event, event_id

_REPOSITORY_ENV = (
    "GIT_DIR",
    "GIT_WORK_TREE",
    "GIT_INDEX_FILE",
    "GIT_OBJECT_DIRECTORY",
    "GIT_ALTERNATE_OBJECT_DIRECTORIES",
    "GIT_COMMON_DIR",
    "GIT_NAMESPACE",
)
_LOG_FORMAT = "%H%x1f%P%x1f%cI%x1f%an%x1f%s%x1f%b"
_LOG_OPTIONS = ("-z", "--no-show-signature", "--no-color", f"--format={_LOG_FORMAT}")
_GIT_DATE_FORMAT = "%Y-%m-%d %H:%M:%S +0000"


@dataclass(frozen=True)
class _Commit:
    sha: str
    parents: tuple[str, ...]
    committed_at: datetime
    actor: str
    subject: str
    body: str

    @property
    def is_merge(self) -> bool:
        return len(self.parents) > 1


def _parse_log(output: str) -> list[_Commit]:
    commits = []
    for record in filter(None, output.split("\0")):
        sha, parents, committed_at, actor, subject, body = record.split("\x1f", 5)
        commits.append(
            _Commit(
                sha,
                tuple(parents.split()),
                datetime.fromisoformat(committed_at),
                actor,
                subject,
                body.rstrip(),
            )
        )
    return commits


class GitCollector:
    name = "git"

    def __init__(self, *, git: str = "git", timeout: float = 60.0, max_merged: int = 200):
        self.git = git
        self.timeout = timeout
        self.max_merged = max_merged

    def collect(self, repo: RepoConfig, day: date, tz: tzinfo) -> CollectResult:
        tip = self._resolve_tip(repo)
        start, end = (bound.astimezone(UTC) for bound in day_bounds(day, tz))
        output = self._run(
            repo.path,
            "log",
            "--first-parent",
            *_LOG_OPTIONS,
            f"--since={start:{_GIT_DATE_FORMAT}}",
            f"--until={end:{_GIT_DATE_FORMAT}}",
            "--end-of-options",
            tip,
        ).stdout

        events = []
        warnings = []
        for commit in reversed(_parse_log(output)):
            if not start <= commit.committed_at < end:
                continue
            if not commit.is_merge:
                events.append(self._event(repo, commit))
                continue

            merged = self._merged_commits(repo.path, commit)
            if len(merged) > self.max_merged:
                warnings.append(
                    f"マージ {commit.sha[:12]} が取り込んだcommitが{self.max_merged}件を"
                    f"超えたので、{self.max_merged}件だけを集めました"
                )
                merged = merged[: self.max_merged]
            events.append(self._event(repo, commit, merged_count=len(merged)))
            events.extend(self._event(repo, entry, merge=commit) for entry in reversed(merged))
        return CollectResult(tuple(events), tuple(warnings))

    def _run(
        self, path: Path, subcommand: str, *args: str, require_success: bool = True
    ) -> subprocess.CompletedProcess[str]:
        env = os.environ.copy()
        for name in _REPOSITORY_ENV:
            env.pop(name, None)
        # 部分クローンで不足したオブジェクトがあっても、自動取得は行わない。
        env.update(
            GIT_OPTIONAL_LOCKS="0",
            GIT_TERMINAL_PROMPT="0",
            GIT_NO_LAZY_FETCH="1",
            GIT_ALLOW_PROTOCOL="",
        )
        try:
            result = subprocess.run(
                [self.git, "--no-optional-locks", "-C", str(path), subcommand, *args],
                capture_output=True,
                text=True,
                encoding="utf-8",
                errors="replace",
                timeout=self.timeout,
                env=env,
                check=False,
            )
        except FileNotFoundError as error:
            raise CollectError(f"gitのコマンドが見つかりません: {self.git}") from error
        except subprocess.TimeoutExpired as error:
            raise CollectError(
                f"git {subcommand} が{self.timeout}秒で終わりませんでした: {path}"
            ) from error
        if require_success and result.returncode != 0:
            detail = result.stderr.strip().rsplit("\n", 1)[-1].strip()
            raise CollectError(f"git {subcommand} が失敗しました: {path}: {detail}")
        return result

    def _resolve_tip(self, repo: RepoConfig) -> str:
        path = repo.path
        if not path.is_dir():
            raise CollectError(f"{path}: ディレクトリがありません")
        result = self._run(path, "rev-parse", "--show-toplevel", require_success=False)
        if result.returncode != 0:
            raise CollectError(f"{path}: Gitのrepositoryではありません")
        top = Path(result.stdout.removesuffix("\n")).resolve()
        if top != path.resolve():
            raise CollectError(f"{path}: Gitのrepositoryの最上位ではありません（最上位: {top}）")
        if repo.ref.startswith("-"):
            raise CollectError(f"{path}: ref {repo.ref} がありません")
        result = self._run(
            path,
            "rev-parse",
            "--verify",
            "--quiet",
            "--end-of-options",
            f"{repo.ref}^{{commit}}",
            require_success=False,
        )
        if result.returncode != 0:
            raise CollectError(f"{path}: ref {repo.ref} がありません")
        return result.stdout.strip()

    def _merged_commits(self, path: Path, merge: _Commit) -> list[_Commit]:
        # merge 自身と、打ち切りを判断するための1件を上限に足す。
        output = self._run(
            path,
            "log",
            *_LOG_OPTIONS,
            f"--max-count={self.max_merged + 2}",
            "--end-of-options",
            merge.sha,
            f"^{merge.parents[0]}",
        ).stdout
        return [commit for commit in _parse_log(output) if commit.sha != merge.sha]

    def _event(
        self,
        repo: RepoConfig,
        commit: _Commit,
        *,
        merged_count: int | None = None,
        merge: _Commit | None = None,
    ) -> Event:
        parents = (commit.parents[0],) if commit.parents else ("--root",)
        paths = self._run(
            repo.path,
            "diff-tree",
            "-r",
            "-z",
            "--no-commit-id",
            "--name-only",
            *parents,
            commit.sha,
        ).stdout
        count = sum(bool(path) for path in paths.split("\0"))
        notes = [f"変更したファイル: {count}件"]
        if merged_count is not None:
            notes.append(f"取り込んだcommit: {merged_count}件")
        if merge is not None:
            notes.append(
                f"マージ {merge.sha[:12]} で入った"
                f"（commitの時刻 {commit.committed_at.isoformat()}）"
            )
        return Event(
            id=event_id(self.name, repo.id, commit.sha),
            repo_id=repo.id,
            source=self.name,
            kind="merge" if commit.is_merge else "commit",
            at=merge.committed_at if merge is not None else commit.committed_at,
            title=commit.subject or "（題名のないcommit）",
            body="\n\n".join(filter(None, (commit.body, "\n".join(notes)))),
            refs=(commit.sha, merge.sha) if merge is not None else (commit.sha,),
            actor=commit.actor,
        )
