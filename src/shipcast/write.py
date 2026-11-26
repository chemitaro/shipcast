"""その日の素材から日誌を書き、保存する。"""

import argparse
import json
import os
import re
import sys
import tempfile
from collections import Counter
from collections.abc import Iterable, Iterator, Sequence
from contextlib import suppress
from dataclasses import dataclass
from datetime import date, datetime, tzinfo
from html import escape
from importlib.resources import files
from pathlib import Path
from typing import Protocol
from zoneinfo import ZoneInfo

from shipcast.analyze import AnalyzeFailed, analyze
from shipcast.collect import COLLECTORS
from shipcast.collect.base import collect_repo
from shipcast.config import ConfigError, load_config
from shipcast.model import (
    Entry,
    Event,
    JournalFormatError,
    JournalMeta,
    Story,
    journal_path,
    write_frontmatter,
)
from shipcast.models import RouteError, get_route
from shipcast.neta import NetaSprout
from shipcast.state import StateError, Store

MAX_ATTEMPTS = 2
PROMPT_PATH = "prompts/write.md"

_RAW_HTML = re.compile(r"<[A-Za-z/!?]")
_BLOCK_PREFIX = re.compile(r"^(?:\s|>|[-*+](?:\s|$)|\d+[.)](?:\s|$))*")
_STORY_BLOCK = re.compile(r"^(?:#{1,2}(?:\s|$)|```|~~~)")
_SETEXT = re.compile(r"=+|-+")
_NUMBERED_PREFIX = re.compile(r"^(\d+)([.)])")
_NO_EVENTS = "大きな動きはありませんでした。"


@dataclass(frozen=True)
class Draft:
    lead: str
    summary: tuple[str, ...]
    story: str


def _read_prompt() -> str:
    return files("shipcast").joinpath(*PROMPT_PATH.split("/")).read_text(encoding="utf-8")


def _reject_json_constant(value: str) -> None:
    raise ValueError("JSON constant is not supported")


def _string_errors(value: object, path: str, *, single_line: bool = False) -> Iterator[str]:
    if not isinstance(value, str) or not value.strip():
        yield f"{path}: 空でない文字列にしてください"
    if not isinstance(value, str):
        return
    if single_line and ("\n" in value or "\r" in value):
        yield f"{path}: 1行にしてください"
    try:
        value.encode("utf-8")
    except UnicodeEncodeError:
        yield f"{path}: UTF-8に変換できる文字列にしてください"


def _draft_errors(lead: object, summary: object, story: object) -> Iterator[str]:
    yield from _string_errors(lead, "lead", single_line=True)
    if isinstance(lead, str):
        if len(lead.strip()) > 200:
            yield "lead: 200文字以内にしてください"
        if "<" in lead or ">" in lead:
            yield "lead: < と > を使わないでください"

    if not isinstance(summary, list) or not 1 <= len(summary) <= 5:
        yield "summary: 1〜5件の文字列の配列にしてください"
    if isinstance(summary, list):
        for index, item in enumerate(summary):
            path = f"summary[{index}]"
            yield from _string_errors(item, path, single_line=True)
            if isinstance(item, str) and (_RAW_HTML.search(item) or item.strip().startswith(":::")):
                yield f"{path}: HTMLや囲みを使わないでください"

    yield from _string_errors(story, "story")
    if isinstance(story, str):
        if _RAW_HTML.search(story) or ":::" in story:
            yield "story: HTMLや囲みを使わないでください"
        if any(
            _SETEXT.fullmatch(line.strip()) or _STORY_BLOCK.match(_BLOCK_PREFIX.sub("", line))
            for line in story.splitlines()
        ):
            yield "story: 見出しは ### 以下にし、コードの囲みを使わないでください"


def parse_draft(text: str) -> tuple[Draft | None, list[str]]:
    """書き手の応答から文章と要約を取り出す。"""
    text = text.strip()
    lines = text.split("\n")
    if len(lines) >= 2 and lines[0].removesuffix("\r") in ("```", "```json") and lines[-1] == "```":
        text = "\n".join(lines[1:-1])
    try:
        response = json.loads(text, parse_constant=_reject_json_constant)
    except (ValueError, RecursionError):
        return None, ["応答: JSONとして読み取れる形にしてください"]
    if not isinstance(response, dict):
        return None, ["応答: JSONのオブジェクトにしてください"]
    lead, summary, story = (response.get(key) for key in ("lead", "summary", "story"))
    errors = list(_draft_errors(lead, summary, story))
    if errors:
        return None, errors
    return Draft(lead.strip(), tuple(item.strip() for item in summary), story.strip()), []


class _Completer(Protocol):
    @property
    def name(self) -> str: ...

    @property
    def model(self) -> str: ...

    def complete(self, prompt: str, *, system: str = "", want_json: bool = False) -> str: ...


class WriteFailed(Exception):
    """応答が続けて日誌の形式に合わなかった。"""

    def __init__(self, attempts: int, errors: Sequence[str]) -> None:
        self.attempts = attempts
        self.errors = tuple(errors)
        detail = "、".join(self.errors[:5])
        super().__init__(f"書き手の応答が{attempts}回とも決まった形になりませんでした：{detail}")


def compose(stories: Sequence[Story], route: _Completer, *, repo_id: str, day: date) -> Draft:
    """話題から日誌の文章を依頼し、形式の誤りがあれば一度頼み直す。"""
    if not stories:
        raise ValueError("書き手に渡す話題が必要です")

    system = _read_prompt()
    payload = {
        "repo": repo_id,
        "date": day.isoformat(),
        "stories": [
            {
                "title": story.title,
                "what": story.what,
                "why": story.why,
                "notice": story.notice,
                "waiting": story.waiting,
            }
            for story in stories
        ],
    }
    errors: list[str] = []
    for _ in range(MAX_ATTEMPTS):
        if errors:
            payload["previous_errors"] = errors
        prompt = json.dumps(payload, ensure_ascii=False)
        response = route.complete(prompt, system=system, want_json=True)
        draft, errors = parse_draft(response)
        if draft is not None:
            return draft
    raise WriteFailed(MAX_ATTEMPTS, errors)


@dataclass(frozen=True)
class Metric:
    value: int
    label: str


def count_metrics(events: Iterable[Event]) -> tuple[Metric, ...]:
    """同じ出来事を一度だけ数え、同日に解決した todo を除く。"""
    unique: dict[str, Event] = {}
    for event in events:
        unique.setdefault(event.id, event)
    done = {event.refs[0] for event in unique.values() if event.kind == "todo_done" and event.refs}
    counts = Counter((event.source, event.kind) for event in unique.values())
    waiting = sum(
        event.source == "specdock"
        and event.kind == "todo_open"
        and (not event.refs or event.refs[0] not in done)
        for event in unique.values()
    )
    return (
        Metric(counts["git", "merge"], "merge"),
        Metric(counts["git", "commit"], "commit"),
        Metric(counts["specdock", "scope_closed"], "閉じたScope"),
        Metric(waiting, "新しい本人待ちのtodo"),
    )


def _inline(value: str) -> str:
    text = escape(" ".join(value.split()), quote=False)
    if text and text[0] in "#:-*+=`~|":
        return "\\" + text
    return _NUMBERED_PREFIX.sub(r"\1\\\2", text)


def _list_block(heading: str, lines: Sequence[str]) -> str:
    return "\n".join([heading, *(f"- {line}" for line in lines), ":::"])


class JournalExtension(Protocol):
    def render(
        self, repo_id: str, day: date, stories: Sequence[Story], events: Sequence[Event]
    ) -> str | None: ...


EXTENSIONS: tuple[JournalExtension, ...] = ()


def journal_extensions(store: Store, threshold: int) -> tuple[JournalExtension, ...]:
    return (*EXTENSIONS, NetaSprout(store, threshold))


def build_entry(
    repo_id: str,
    day: date,
    stories: Sequence[Story],
    events: Sequence[Event],
    draft: Draft | None,
    *,
    analyst: str | None,
    writer: str | None,
    generated_at: datetime,
    extensions: Sequence[JournalExtension] | None = None,
) -> str:
    """日誌の前付けと本文を決まった順に組み立てる。"""
    if events and draft is None:
        raise ValueError("出来事がある日は日誌の本文が必要です")
    lead = draft.lead if events and draft is not None else _NO_EVENTS
    meta = JournalMeta(
        title=f"{repo_id} の開発日誌 {day.isoformat()}",
        lead=lead,
        date=day,
        repo=repo_id,
        category="開発日誌",
        analyst=analyst if events else None,
        writer=writer if events else None,
        generated_at=generated_at.isoformat(timespec="seconds"),
        schema=1,
    )
    frontmatter = write_frontmatter(meta)
    if not events:
        return f"{frontmatter}\n{_NO_EVENTS}\n"
    assert draft is not None

    summary = [line for value in draft.summary if (line := _inline(value))]
    notices = [line for story in stories for value in story.notice if (line := _inline(value))]
    waiting = [line for story in stories for value in story.waiting if (line := _inline(value))]
    metrics = [f"{metric.value} | {metric.label}" for metric in count_metrics(events)]

    blocks = [_list_block(":::summary 今日の要約", summary)]
    if notices:
        blocks.append(_list_block(":::warning あなたが知っておくべきこと", notices))
    blocks.append(f"## 今日の物語\n\n{draft.story}")
    if waiting:
        blocks.append(_list_block(":::checklist あなたを待っていること", waiting))
    blocks.append(_list_block(":::metrics", metrics))
    for extension in EXTENSIONS if extensions is None else extensions:
        block = extension.render(repo_id, day, stories, events)
        if block is not None and (block := block.strip()):
            blocks.append(block)
    return frontmatter + "\n" + "\n\n".join(blocks) + "\n"


def write_atomic(path: Path, text: str) -> None:
    """同じフォルダーに書き終えてから日誌を置き換える。"""
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, temporary = tempfile.mkstemp(dir=path.parent, prefix=f".{path.name}.", suffix=".tmp")
    try:
        try:
            stream = os.fdopen(fd, "w", encoding="utf-8", newline="\n")
        except BaseException:
            with suppress(OSError):
                os.close(fd)
            raise
        with stream:
            stream.write(text)
            stream.flush()
            os.fsync(stream.fileno())
        os.chmod(temporary, 0o644)
        os.replace(temporary, path)
    except BaseException:
        with suppress(OSError):
            os.unlink(temporary)
        raise


@dataclass(frozen=True)
class WriteResult:
    path: Path
    events: int
    stories: tuple[Story, ...]


def write_day(
    store: Store,
    repo_id: str,
    day: date,
    *,
    tz: tzinfo,
    journal_dir: Path,
    analyst: _Completer,
    writer: _Completer,
    now: datetime,
    extensions: Sequence[JournalExtension] | None = None,
) -> WriteResult:
    """その日の出来事から日誌を書き、置き換えに成功してから記録する。"""
    events = store.events_for(repo_id, day, tz=tz)
    stories: tuple[Story, ...] = ()
    draft = analyst_name = writer_name = None
    if events:
        stories = tuple(analyze(events, analyst, store=store, repo_id=repo_id, day=day))
        draft = compose(stories, writer, repo_id=repo_id, day=day)
        analyst_name = f"{analyst.name}/{analyst.model}"
        writer_name = f"{writer.name}/{writer.model}"

    text = build_entry(
        repo_id,
        day,
        stories,
        events,
        draft,
        analyst=analyst_name,
        writer=writer_name,
        generated_at=now,
        extensions=extensions,
    )
    path = journal_path(journal_dir, repo_id, day)
    write_atomic(path, text)
    store.save_entry(
        Entry(
            repo_id,
            day,
            str(path),
            analyst=analyst_name or "none",
            writer=writer_name or "none",
            generated_at=now,
            story_ids=tuple(story.id for story in stories),
        )
    )
    return WriteResult(path, len(events), stories)


def configure(parser: argparse.ArgumentParser) -> None:
    parser.add_argument("--repo", metavar="ID", help="日誌を書く repository の id（既定: 全件）")
    parser.add_argument("--date", type=date.fromisoformat, metavar="YYYY-MM-DD", help="日誌の日付")
    parser.set_defaults(func=run)


def run(args: argparse.Namespace) -> int:
    try:
        config = load_config()
    except ConfigError as error:
        print(f"shipcast write: {error}", file=sys.stderr)
        return 1
    except OSError as error:
        print(f"shipcast write: 設定ファイルを開けません: {error}", file=sys.stderr)
        print("直し方: 設定ファイルのパスと読み取り権限を確かめてください", file=sys.stderr)
        return 1

    tz = ZoneInfo(config.timezone)
    day = args.date or datetime.now(tz).date()
    repos = config.repos
    if args.repo is not None:
        repos = tuple(repo for repo in repos if repo.id == args.repo)
        if not repos:
            print(f"shipcast write: 登録されていないrepositoryです: {args.repo}", file=sys.stderr)
            print(
                "直し方: `shipcast repo list` で登録済みのidを確かめてください",
                file=sys.stderr,
            )
            return 1
    if not repos:
        print(
            "shipcast write: 登録されたrepositoryはありません。"
            "`shipcast repo add <path>` で登録できます",
            file=sys.stderr,
        )
        return 1

    try:
        store = Store(config.state_dir)
    except (StateError, OSError) as error:
        print(f"shipcast write: 状態の置き場を開けません: {error}", file=sys.stderr)
        print(
            "直し方: 設定の `state_dir` が、書き込めるディレクトリを指しているか確かめてください",
            file=sys.stderr,
        )
        return 1

    exit_code = 0
    with store:
        try:
            analyst = get_route(config.models.analyst)
            writer = get_route(config.models.writer)
        except (RouteError, ValueError) as error:
            print(f"shipcast write: モデルの経路を作れません: {error}", file=sys.stderr)
            return 1

        for repo in repos:
            collection = collect_repo(store, repo, day, tz=tz, collectors=COLLECTORS)
            for warning in collection.warnings:
                print(f"shipcast write: 警告: {repo.id}: {warning}", file=sys.stderr)
            if collection.errors:
                for error in collection.errors:
                    print(f"shipcast write: 失敗: {repo.id}: {error}", file=sys.stderr)
                print(
                    f"shipcast write: 失敗: {repo.id}: 収集に失敗したため、日誌を書きませんでした",
                    file=sys.stderr,
                )
                exit_code = 1
                continue

            try:
                result = write_day(
                    store,
                    repo.id,
                    day,
                    tz=tz,
                    journal_dir=config.journal_dir,
                    analyst=analyst,
                    writer=writer,
                    now=datetime.now(tz),
                    extensions=journal_extensions(store, config.neta.threshold),
                )
            except (
                AnalyzeFailed,
                WriteFailed,
                RouteError,
                JournalFormatError,
                OSError,
                StateError,
            ) as error:
                print(f"shipcast write: 失敗: {repo.id}: {error}", file=sys.stderr)
                exit_code = 1
            except Exception as error:
                print(
                    f"shipcast write: 失敗: {repo.id}: {type(error).__name__}: {error}",
                    file=sys.stderr,
                )
                exit_code = 1
            else:
                print(
                    f"{repo.id} {day}: 日誌を書きました"
                    f"（出来事 {result.events}件、話題 {len(result.stories)}件）: {result.path}"
                )
    return exit_code
