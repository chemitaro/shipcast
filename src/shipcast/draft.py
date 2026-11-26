"""未消化の話題から発信用の下書きを作る。"""

import json
import re
import unicodedata
from collections.abc import Sequence
from dataclasses import dataclass
from datetime import date
from importlib.resources import files

from shipcast.model import Story
from shipcast.write import _Completer, _reject_json_constant, _string_errors

X_LIMIT = 280
MAX_HASHTAGS = 3
MAX_ATTEMPTS = 2
PROMPT_PATH = "prompts/x.md"

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
