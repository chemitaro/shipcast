import argparse
import sys
from collections.abc import Callable
from dataclasses import dataclass
from functools import partial

from shipcast import __version__

from shipcast import draft  # isort: skip
from shipcast import repo  # isort: skip
from shipcast import serve  # isort: skip
from shipcast import write  # isort: skip
from shipcast.collect import command as collect_command  # isort: skip


@dataclass(frozen=True)
class Entry:
    name: str
    help: str
    configure: Callable[[argparse.ArgumentParser], None] | None = None


@dataclass(frozen=True)
class Command:
    entry: Entry
    issue_id: str
    subcommands: tuple[Entry, ...] = ()


COMMANDS = (
    Command(
        Entry("repo", "日誌の対象リポジトリを管理する"),
        "iss-00009",
        (
            Entry("add", "リポジトリを登録する", repo.configure_add),
            Entry("list", "登録済みのリポジトリを表示する", repo.configure_list),
        ),
    ),
    Command(Entry("collect", "日誌の素材を集める", collect_command.configure), "iss-00011"),
    Command(Entry("write", "集めた素材から日誌を書く", write.configure), "iss-00016"),
    Command(Entry("run", "素材の収集から日誌の作成までを実行する"), "iss-00021"),
    Command(
        Entry("serve", "日誌を閲覧するためのサーバーを起動する", serve.configure), "iss-00017"
    ),
    Command(
        Entry("draft", "発信の下書きを作る"),
        "iss-00020",
        (Entry("x", "X向けの下書きを作る", draft.configure_x),),
    ),
    Command(
        Entry("schedule", "日誌作成のスケジュールを管理する"),
        "iss-00022",
        (Entry("install", "スケジュールを登録する"), Entry("uninstall", "スケジュールを解除する")),
    ),
)


def not_implemented(command: str, issue_id: str) -> int:
    print(f"shipcast {command}: 未実装です（{issue_id} で作ります）", file=sys.stderr)
    return 2


def _run_placeholder(command: str, issue_id: str, _args: argparse.Namespace) -> int:
    return not_implemented(command, issue_id)


def _configure_leaf(
    parser: argparse.ArgumentParser, entry: Entry, command: str, issue_id: str
) -> None:
    if entry.configure is None:
        parser.set_defaults(func=partial(_run_placeholder, command, issue_id))
    else:
        entry.configure(parser)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="shipcast", description="エージェントが書く開発日誌の道具"
    )
    parser.add_argument("--version", action="version", version=f"%(prog)s {__version__}")
    subparsers = parser.add_subparsers(required=True, dest="command")

    for command in COMMANDS:
        entry = command.entry
        command_parser = subparsers.add_parser(entry.name, help=entry.help, description=entry.help)
        if command.subcommands:
            leaf_parsers = command_parser.add_subparsers(required=True, dest="subcommand")
            for leaf in command.subcommands:
                leaf_parser = leaf_parsers.add_parser(
                    leaf.name, help=leaf.help, description=leaf.help
                )
                _configure_leaf(leaf_parser, leaf, f"{entry.name} {leaf.name}", command.issue_id)
        else:
            _configure_leaf(command_parser, entry, entry.name, command.issue_id)

    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    return args.func(args)
