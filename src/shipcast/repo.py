"""CLI commands for the configured repository list."""

import argparse
import sys

from shipcast.config import ConfigError, add_repo, load_config


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


def configure_list(parser: argparse.ArgumentParser) -> None:
    parser.set_defaults(func=run_list)


_LIST_ESCAPES = str.maketrans({"\\": r"\\", "\t": r"\t", "\n": r"\n", "\r": r"\r"})


def run_list(_args: argparse.Namespace) -> int:
    try:
        repos = load_config().repos
    except ConfigError as error:
        print(f"shipcast repo list: {error}", file=sys.stderr)
        return 1

    if not repos:
        print(
            "登録されたrepositoryはありません。`shipcast repo add <path>` で登録できます",
            file=sys.stderr,
        )
    for repo in repos:
        fields = (repo.id, repo.title, str(repo.path), repo.ref)
        print("\t".join(field.translate(_LIST_ESCAPES) for field in fields))
    return 0
