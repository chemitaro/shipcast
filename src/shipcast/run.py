"""日誌を作り、repository ごとの実行結果を記録する。"""

import argparse
import fcntl
import os
import sys
from collections.abc import Iterator, Sequence
from contextlib import ExitStack, contextmanager
from datetime import date, datetime, timedelta
from pathlib import Path
from zoneinfo import ZoneInfo

from shipcast.analyze import AnalyzeFailed
from shipcast.collect import COLLECTORS
from shipcast.collect.base import CollectError, collect_repo
from shipcast.config import Config, ConfigError, RepoConfig, load_config
from shipcast.model import JournalFormatError
from shipcast.models import GuardedRoute, RouteError, get_route
from shipcast.state import Run, StateError, Store
from shipcast.write import JournalExtension, WriteFailed, write_day

LOCK_FILENAME = "run.lock"
TCC_MARKER = "Operation not permitted"
_TCC_HINT = (
    "直し方: macOS の「システム設定」→「プライバシーとセキュリティ」"
    "→「フルディスクアクセス」で、shipcast を動かすプログラム"
    "（launchd から動かすときは `shipcast` の実行ファイル、"
    "手で動かすときはターミナル）を許可してください"
)


def with_tcc_hint(error_text: str) -> str:
    if TCC_MARKER in error_text:
        return f"{error_text}\n{_TCC_HINT}"
    return error_text


def probe_readable(path: Path) -> None:
    """ディレクトリを開いて、権限による失敗だけを収集前に検出する。"""
    try:
        with os.scandir(path):
            pass
    except PermissionError:
        raise
    except OSError:
        # 無いパスなどの診断は collector に任せる。
        pass


@contextmanager
def run_lock(state_dir: Path) -> Iterator[bool]:
    """状態の置き場を排他で確保し、使用中なら False を返す。"""
    state_dir.mkdir(parents=True, exist_ok=True)
    fd = os.open(state_dir / LOCK_FILENAME, os.O_RDWR | os.O_CREAT, 0o644)
    try:
        try:
            fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            yield False
            return

        try:
            yield True
        finally:
            fcntl.flock(fd, fcntl.LOCK_UN)
    finally:
        os.close(fd)


def previous_day(tz: ZoneInfo, now: datetime | None = None) -> date:
    return (now or datetime.now(tz)).astimezone(tz).date() - timedelta(days=1)


def journal_extensions_for(store: Store, config: Config) -> Sequence[JournalExtension] | None:
    """日誌の拡張点を渡す場所。台帳との接続は後続の変更で行う。"""
    return None


def configure(parser: argparse.ArgumentParser) -> None:
    parser.add_argument("--repo", metavar="ID", help="日誌を書く repository の id（既定: 全件）")
    parser.add_argument(
        "--date", type=date.fromisoformat, metavar="YYYY-MM-DD", help="日誌の日付（既定: 前日）"
    )
    parser.set_defaults(func=run)


def run(args: argparse.Namespace) -> int:
    try:
        config = load_config()
    except ConfigError as error:
        print(f"shipcast run: {error}", file=sys.stderr)
        return 1
    except OSError as error:
        print(f"shipcast run: 設定ファイルを開けません: {error}", file=sys.stderr)
        print("直し方: 設定ファイルのパスと読み取り権限を確かめてください", file=sys.stderr)
        return 1

    tz = ZoneInfo(config.timezone)
    day = args.date or previous_day(tz)
    repos = config.repos
    if args.repo is not None:
        repos = tuple(repo for repo in repos if repo.id == args.repo)
        if not repos:
            print(f"shipcast run: 登録されていないrepositoryです: {args.repo}", file=sys.stderr)
            print(
                "直し方: `shipcast repo list` で登録済みのidを確かめてください",
                file=sys.stderr,
            )
            return 1
    if not repos:
        print(
            "shipcast run: 登録されたrepositoryはありません。"
            "`shipcast repo add <path>` で登録できます",
            file=sys.stderr,
        )
        return 1

    with ExitStack() as resources:
        try:
            if not resources.enter_context(run_lock(config.state_dir)):
                print(
                    "shipcast run: 前の実行が動いているため、今回は何もせずに終えます: "
                    f"{config.state_dir / LOCK_FILENAME}",
                    file=sys.stderr,
                )
                return 0
            store = resources.enter_context(Store(config.state_dir))
        except (StateError, OSError) as error:
            print(f"shipcast run: 状態の置き場を開けません: {error}", file=sys.stderr)
            print(
                "直し方: 設定の `state_dir` が、"
                "書き込めるディレクトリを指しているか確かめてください",
                file=sys.stderr,
            )
            return 1

        return _run_repositories(store, config, repos, day, tz)


def _run_repositories(
    store: Store, config: Config, repos: Sequence[RepoConfig], day: date, tz: ZoneInfo
) -> int:
    try:
        analyst = get_route(config.models.analyst)
        writer = get_route(config.models.writer)
    except (RouteError, ValueError) as error:
        message = with_tcc_hint(f"shipcast run: モデルの経路を作れません: {error}")
        print(message, file=sys.stderr)
        for repo in repos:
            now = datetime.now(tz)
            _record_run(store, repo.id, now, now, "failed", message)
        return 1

    failures = 0
    record_failed = False
    for repo in repos:
        started = datetime.now(tz)
        error = _write_repo(store, config, repo, day, tz, analyst=analyst, writer=writer)
        if error is None:
            result = "ok"
        else:
            result = "failed"
            failures += 1
            error = with_tcc_hint(error)
            print(f"shipcast run: 失敗: {repo.id}: {error}", file=sys.stderr)
            print(f"{repo.id} {day}: 失敗しました（理由は標準エラー）")
        if not _record_run(store, repo.id, started, datetime.now(tz), result, error or ""):
            record_failed = True

    print(f"shipcast run: {day}: 成功 {len(repos) - failures}件、失敗 {failures}件")
    return int(failures > 0 or record_failed)


def _write_repo(
    store: Store,
    config: Config,
    repo: RepoConfig,
    day: date,
    tz: ZoneInfo,
    *,
    analyst: GuardedRoute,
    writer: GuardedRoute,
) -> str | None:
    try:
        probe_readable(repo.path)
        collection = collect_repo(store, repo, day, tz=tz, collectors=COLLECTORS)
        for warning in collection.warnings:
            print(f"shipcast run: 警告: {repo.id}: {warning}", file=sys.stderr)
        if collection.errors:
            return "; ".join(collection.errors)
        result = write_day(
            store,
            repo.id,
            day,
            tz=tz,
            journal_dir=config.journal_dir,
            analyst=analyst,
            writer=writer,
            now=datetime.now(tz),
            extensions=journal_extensions_for(store, config),
        )
    except (
        AnalyzeFailed,
        WriteFailed,
        RouteError,
        JournalFormatError,
        OSError,
        StateError,
        CollectError,
    ) as error:
        return str(error)
    except Exception as error:
        return f"{type(error).__name__}: {error}"

    print(
        f"{repo.id} {day}: 日誌を書きました"
        f"（出来事 {result.events}件、話題 {len(result.stories)}件）: {result.path}"
    )
    return None


def _record_run(
    store: Store, repo_id: str, started: datetime, finished: datetime, result: str, error: str
) -> bool:
    try:
        store.record_run(Run(repo_id, started, finished, result, error))
    except Exception as record_error:
        print(f"shipcast run: 記録に失敗しました: {repo_id}: {record_error}", file=sys.stderr)
        return False
    return True
