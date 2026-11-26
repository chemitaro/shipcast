"""CLI commands for the configured repository list."""

import argparse
import sys

from shipcast.config import ConfigError, add_repo


def configure_add(parser: argparse.ArgumentParser) -> None:
    parser.add_argument("path")
    parser.add_argument("--id", dest="repo_id")
    parser.add_argument("--title")
    parser.add_argument("--ref", default="main")
    parser.set_defaults(func=run_add)


def run_add(args: argparse.Namespace) -> int:
    try:
        result = add_repo(args.path, repo_id=args.repo_id, title=args.title, ref=args.ref)
    except ConfigError as error:
        print(f"shipcast repo add: {error}", file=sys.stderr)
        return 1

    if result.created:
        print(f"設定ファイルを作りました: {result.config_path}")
    print(f"登録しました: {result.repo.id} {result.repo.path}")
    return 0
