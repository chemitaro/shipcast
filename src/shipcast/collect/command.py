"""日誌の素材を収集する CLI。"""

import argparse
import sys
from datetime import date, datetime
from zoneinfo import ZoneInfo

from shipcast.collect import COLLECTORS
from shipcast.collect.base import collect_repo
from shipcast.config import ConfigError, load_config
from shipcast.state import StateError, Store


def configure(parser: argparse.ArgumentParser) -> None:
    parser.add_argument("--repo", metavar="ID", help="収集する repository の id（既定: 全件）")
    parser.add_argument("--date", type=date.fromisoformat, metavar="YYYY-MM-DD", help="収集する日")
    parser.set_defaults(func=run)


def run(args: argparse.Namespace) -> int:
    try:
        config = load_config()
    except ConfigError as error:
        print(f"shipcast collect: {error}", file=sys.stderr)
        return 1
    except OSError as error:
        print(f"shipcast collect: 設定ファイルを開けません: {error}", file=sys.stderr)
        print("直し方: 設定ファイルのパスと読み取り権限を確かめてください", file=sys.stderr)
        return 1

    tz = ZoneInfo(config.timezone)
    day = args.date or datetime.now(tz).date()
    repos = config.repos
    if args.repo is not None:
        repos = tuple(repo for repo in repos if repo.id == args.repo)
        if not repos:
            print(f"shipcast collect: 登録されていないrepositoryです: {args.repo}", file=sys.stderr)
            print(
                "直し方: `shipcast repo list` で登録済みのidを確かめてください",
                file=sys.stderr,
            )
            return 1
    if not repos:
        print(
            "shipcast collect: 登録されたrepositoryはありません。"
            "`shipcast repo add <path>` で登録できます",
            file=sys.stderr,
        )
        return 1

    try:
        store = Store(config.state_dir)
    except (StateError, OSError) as error:
        print(f"shipcast collect: 状態の置き場を開けません: {error}", file=sys.stderr)
        print(
            "直し方: 設定の `state_dir` が、書き込めるディレクトリを指しているか確かめてください",
            file=sys.stderr,
        )
        return 1

    exit_code = 0
    with store:
        for repo in repos:
            result = collect_repo(store, repo, day, tz=tz, collectors=COLLECTORS)
            for warning in result.warnings:
                print(f"shipcast collect: 警告: {repo.id}: {warning}", file=sys.stderr)
            for error in result.errors:
                print(f"shipcast collect: 失敗: {repo.id}: {error}", file=sys.stderr)
            print(
                f"{repo.id} {day}: {len(result.events)}件を集め、"
                f"{result.saved}件を新しく保存しました"
            )
            if not result.ok:
                exit_code = 1
    return exit_code
