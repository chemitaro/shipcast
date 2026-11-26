"""未消化の話題から発信用の下書きを作る。"""

import argparse
import json
import os
import re
import sys
import unicodedata
from collections.abc import Iterator, Sequence
from contextlib import contextmanager
from dataclasses import dataclass
from datetime import date, datetime
from importlib.resources import files
from pathlib import Path
from zoneinfo import ZoneInfo

from shipcast.config import ConfigError, load_config
from shipcast.model import Story, _day, _repo_id
from shipcast.models import RouteError, get_route
from shipcast.state import StateError, Store
from shipcast.write import _Completer, _reject_json_constant, _string_errors, write_atomic

X_LIMIT = 280
MAX_HASHTAGS = 3
DRAFT_STORIES = 3
MAX_ATTEMPTS = 2
PROMPT_PATH = "prompts/x.md"

_POSTING_NOTICE = "shipcastは投稿しません。内容を確かめてから、本人が投稿してください。"

_SINGLE_WEIGHT_RANGES = ((0x0000, 0x10FF), (0x2000, 0x200D), (0x2010, 0x201F), (0x2032, 0x2037))
_URL = re.compile(r"https?://", re.IGNORECASE)
_MENTION = re.compile(r"@[A-Za-z0-9_]")
_HASHTAG = re.compile(r"#\w+")


@dataclass(frozen=True)
class XDraft:
    text: str
    hashtags: tuple[str, ...]

    @property
    def post(self) -> str:
        if not self.hashtags:
            return self.text
        return self.text + "\n\n" + " ".join(self.hashtags)


def x_length(text: str) -> int:
    """NFC 正規化した投稿を X の文字の重みで数える。"""
    return sum(
        1 if any(start <= codepoint <= end for start, end in _SINGLE_WEIGHT_RANGES) else 2
        for codepoint in map(ord, unicodedata.normalize("NFC", text))
    )


def _text_errors(value: object) -> list[str]:
    errors = list(_string_errors(value, "text"))
    if isinstance(value, str):
        if any(char != "\n" and unicodedata.category(char) == "Cc" for char in value):
            errors.append("text: 改行以外の制御文字を使わないでください")
        if _URL.search(value):
            errors.append("text: URLを使わないでください")
        if _MENTION.search(value):
            errors.append("text: @の宛先を使わないでください")
    return errors


def _parse_hashtags(value: object) -> tuple[tuple[str, ...], list[str]]:
    if not isinstance(value, list) or len(value) > MAX_HASHTAGS:
        return (), [f"hashtags: 0〜{MAX_HASHTAGS}件の文字列の配列にしてください"]

    tags: list[str] = []
    errors: list[str] = []
    for index, item in enumerate(value):
        field = f"hashtags[{index}]"
        item_errors = list(_string_errors(item, field))
        if item_errors:
            errors.extend(item_errors)
            continue

        tag = item.strip()
        if not _HASHTAG.fullmatch(tag) or tag[1:].isdigit():
            errors.append(f"{field}: #で始まる1語にし、数字だけにしないでください")
        elif tag in tags:
            errors.append(f"{field}: 同じハッシュタグを2度入れないでください")
        else:
            tags.append(tag)
    return tuple(tags), errors


def parse_x_draft(text: str) -> tuple[XDraft | None, list[str]]:
    """書き手の応答を検査し、本文とハッシュタグを取り出す。"""
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

    body = response.get("text")
    tags, tag_errors = _parse_hashtags(response.get("hashtags", []))
    errors = _text_errors(body) + tag_errors
    if errors:
        return None, errors

    draft = XDraft(body.strip(), tags)
    length = x_length(draft.post)
    if length > X_LIMIT:
        return None, [f"post: Xの数え方で {length} です。{X_LIMIT} 以内にしてください"]
    return draft, []


class XDraftFailed(Exception):
    """応答が続けて X の下書きの形式に合わなかった。"""

    def __init__(self, attempts: int, errors: Sequence[str]) -> None:
        self.attempts = attempts
        self.errors = tuple(errors)
        detail = "、".join(self.errors[:5])
        super().__init__(f"書き手の応答が{attempts}回とも決まった形になりませんでした：{detail}")


def compose_x(stories: Sequence[Story], route: _Completer, *, repo_id: str, day: date) -> XDraft:
    """話題から X の下書きを依頼し、形式の誤りがあれば一度頼み直す。"""
    if not stories:
        raise ValueError("書き手に渡す話題が必要です")

    system = files("shipcast").joinpath(*PROMPT_PATH.split("/")).read_text(encoding="utf-8")
    payload = {
        "repo": repo_id,
        "date": day.isoformat(),
        "stories": [
            {"title": story.title, "what": story.what, "why": story.why} for story in stories
        ],
    }
    errors: list[str] = []
    for _ in range(MAX_ATTEMPTS):
        if errors:
            payload["previous_errors"] = errors
        prompt = json.dumps(payload, ensure_ascii=False)
        response = route.complete(prompt, system=system, want_json=True)
        draft, errors = parse_x_draft(response)
        if draft is not None:
            return draft
    raise XDraftFailed(MAX_ATTEMPTS, errors)


def draft_path(state_dir: str | os.PathLike[str], repo_id: str, day: date) -> Path:
    _repo_id(repo_id, "draft_path.repo")
    _day(day, "draft_path.day")
    return Path(state_dir) / "drafts" / repo_id / f"{day.isoformat()}-x.md"


def render_x_draft(
    draft: XDraft,
    stories: Sequence[Story],
    *,
    repo_id: str,
    day: date,
    writer: str,
    generated_at: datetime,
) -> str:
    tags = " ".join(draft.hashtags) or "なし"
    titles = [" ".join(story.title.split()) for story in stories]
    lines = [
        f"# Xの下書き（{repo_id} {day.isoformat()}）",
        "",
        ":::note",
        _POSTING_NOTICE,
        ":::",
        "",
        "## 投稿の本文",
        "",
        draft.post,
        "",
        "## 確かめること",
        "",
        f"- 長さ：Xの数え方で {x_length(draft.post)} / {X_LIMIT}",
        f"- ハッシュタグの案：{tags}",
        f"- 書き手：{writer}",
        f"- 作った時刻：{generated_at.isoformat()}",
        "",
        "## 使った話題",
        "",
        *(f"- {title}" for title in titles),
    ]
    return "\n".join(lines) + "\n"


@dataclass(frozen=True)
class XDraftResult:
    path: Path
    draft: XDraft
    stories: tuple[Story, ...]
    consumed: int


class DraftExists(Exception):
    def __init__(self, path: Path) -> None:
        self.path = path
        super().__init__(f"同じ日付の下書きがあります: {path}")


class NoStories(Exception):
    def __init__(self, repo_id: str) -> None:
        self.repo_id = repo_id
        super().__init__(f"未消化の話題がありません: {repo_id}")


@contextmanager
def _lock_draft_state(directory: Path) -> Iterator[None]:
    if os.name != "posix":
        yield
        return

    import fcntl

    # 下書きの有無を確認してから話題を消化するまで、同じ台帳を使う実行を直列化する。
    fd = os.open(directory, os.O_RDONLY | os.O_DIRECTORY)
    try:
        fcntl.flock(fd, fcntl.LOCK_EX)
        yield
    finally:
        os.close(fd)


def make_x_draft(
    store: Store,
    repo_id: str,
    day: date,
    *,
    state_dir: Path,
    writer: _Completer,
    now: datetime,
) -> XDraftResult:
    path = draft_path(state_dir, repo_id, day)
    with _lock_draft_state(store.path.parent):
        if path.exists():
            raise DraftExists(path)

        stories = store.unconsumed_stories(repo_id, limit=DRAFT_STORIES)
        if not stories:
            raise NoStories(repo_id)

        draft = compose_x(stories, writer, repo_id=repo_id, day=day)
        markdown = render_x_draft(
            draft,
            stories,
            repo_id=repo_id,
            day=day,
            writer=f"{writer.name}/{writer.model}",
            generated_at=now,
        )
        write_atomic(path, markdown)
        consumed = store.consume_neta(story.id for story in stories)
        return XDraftResult(path, draft, tuple(stories), consumed)


def configure_x(parser: argparse.ArgumentParser) -> None:
    parser.add_argument("--repo", required=True, metavar="ID", help="下書きに使う repository の id")
    parser.add_argument(
        "--date", type=date.fromisoformat, metavar="YYYY-MM-DD", help="下書きの日付（既定: 今日）"
    )
    parser.set_defaults(func=run_x)


def _x_error(message: str, hint: str | None = None) -> int:
    print(f"shipcast draft x: {message}", file=sys.stderr)
    if hint is not None:
        print(f"直し方: {hint}", file=sys.stderr)
    return 1


def run_x(args: argparse.Namespace) -> int:
    try:
        config = load_config()
    except ConfigError as error:
        return _x_error(str(error))
    except OSError as error:
        return _x_error(
            f"設定ファイルを開けません: {error}",
            "設定ファイルのパスと読み取り権限を確かめてください",
        )

    repo_id = args.repo
    if not any(repo.id == repo_id for repo in config.repos):
        return _x_error(
            f"登録されていないrepositoryです: {repo_id}",
            "`shipcast repo list` で登録済みのidを確かめてください",
        )
    try:
        store = Store(config.state_dir)
    except (StateError, OSError) as error:
        return _x_error(
            f"状態の置き場を開けません: {error}",
            "設定の `state_dir` が、書き込めるディレクトリを指しているか確かめてください",
        )

    with store:
        try:
            writer = get_route(config.models.writer)
        except (RouteError, ValueError) as error:
            return _x_error(f"モデルの経路を作れません: {error}")

        now = datetime.now(ZoneInfo(config.timezone))
        day = args.date or now.date()
        try:
            result = make_x_draft(
                store, repo_id, day, state_dir=config.state_dir, writer=writer, now=now
            )
        except DraftExists as error:
            return _x_error(str(error), "下書きを消すか、別の日付を `--date` で指定してください")
        except NoStories as error:
            return _x_error(str(error), "`shipcast write` で日誌を書くと話題がたまります")
        except (XDraftFailed, RouteError, OSError, StateError) as error:
            return _x_error(f"失敗: {repo_id}: {error}")

    print(
        f"{repo_id} {day.isoformat()}: Xの下書きを作りました"
        f"（話題 {len(result.stories)}件、Xの数え方で {x_length(result.draft.post)} / {X_LIMIT}）: "
        f"{result.path}"
    )
    print(_POSTING_NOTICE)
    return 0
