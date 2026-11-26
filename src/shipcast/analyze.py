"""出来事を分析して話題を作る。"""

import json
from collections.abc import Collection, Iterator, Sequence
from datetime import date
from importlib.resources import files
from typing import Protocol

from shipcast.model import Event, Neta, Story, story_id
from shipcast.state import Store

MAX_ATTEMPTS = 2
PROMPT_PATH = "prompts/analyze.md"
_MAX_ERRORS = 20
_REQUIRED_TEXT = ("title", "what", "why")


class _Completer(Protocol):
    def complete(self, prompt: str, *, system: str = "", want_json: bool = False) -> str: ...


class AnalyzeFailed(Exception):
    """応答が続けて話題の形式に合わなかった。"""

    def __init__(self, attempts: int, errors: Sequence[str]) -> None:
        self.attempts = attempts
        self.errors = tuple(errors)
        detail = "、".join(self.errors[:5])
        super().__init__(f"分析の応答が{attempts}回とも決まった形になりませんでした：{detail}")


def analyze(
    events: Sequence[Event],
    route: _Completer,
    *,
    store: Store,
    repo_id: str,
    day: date,
) -> list[Story]:
    """その日の出来事を分析し、応答順の話題を返す。"""
    # 空の入力でも repo_id と day を story_id と同じ規則で検査する。
    story_id(repo_id, day, ("",))
    for event in events:
        if not isinstance(event, Event) or event.repo_id != repo_id:
            raise ValueError("events: 指定したリポジトリのEventだけを渡してください")
    if not events:
        return []

    system = _read_prompt()
    payload = {
        "repo": repo_id,
        "date": day.isoformat(),
        "events": [
            {
                key: value
                for key, value in event.to_dict().items()
                if key not in ("schema", "repo_id")
            }
            for event in events
        ],
    }
    event_ids = {event.id for event in events}
    errors: list[str] = []
    for _ in range(MAX_ATTEMPTS):
        if errors:
            payload["previous_errors"] = errors
        prompt = json.dumps(payload, ensure_ascii=False)
        response = route.complete(prompt, system=system, want_json=True)
        values, errors = parse_stories(response, event_ids=event_ids)
        if not errors:
            return [
                Story(
                    id=story_id(repo_id, day, story["event_ids"]),
                    repo_id=repo_id,
                    date=day,
                    **story,
                )
                for story in values
            ]
    raise AnalyzeFailed(MAX_ATTEMPTS, errors)


def _read_prompt() -> str:
    return files("shipcast").joinpath(*PROMPT_PATH.split("/")).read_text(encoding="utf-8")


def _reject_json_constant(value: str) -> None:
    # json.loads は既定で JSON 規格外の NaN と Infinity も受け付ける。
    raise ValueError("JSON constant is not supported")


def parse_stories(text: str, *, event_ids: Collection[str]) -> tuple[list[dict], list[str]]:
    """応答を検査し、Story に渡せる値または日本語の修正箇所を返す。"""
    text = text.strip()
    lines = text.split("\n")
    if len(lines) >= 2 and lines[0].removesuffix("\r") in ("```", "```json") and lines[-1] == "```":
        text = "\n".join(lines[1:-1])
    try:
        response = json.loads(text, parse_constant=_reject_json_constant)
    except (ValueError, RecursionError):
        return [], ["応答: JSONとして読み取れる形にしてください"]
    if not isinstance(response, dict):
        return [], ["応答: JSONのオブジェクトにしてください"]
    raw_stories = response.get("stories")
    if not isinstance(raw_stories, list):
        return [], ["stories: 話題の配列にしてください"]
    if not raw_stories:
        return [], ["stories: 話題を1件以上入れてください"]

    known_ids = set(event_ids)
    used_ids: set[str] = set()
    errors: list[str] = []
    for index, story in enumerate(raw_stories):
        for error in _story_errors(story, f"stories[{index}]", known_ids, used_ids):
            if len(errors) == _MAX_ERRORS:
                return [], [*errors, "ほかにも誤りがあります"]
            errors.append(error)
    if errors:
        return [], errors
    return [_story_values(story) for story in raw_stories], []


def _utf8_error(value: str, path: str) -> Iterator[str]:
    try:
        value.encode("utf-8")
    except UnicodeEncodeError:
        yield f"{path}: UTF-8に変換できる文字列にしてください"


def _is_string_list(value: object) -> bool:
    return isinstance(value, list) and all(isinstance(item, str) for item in value)


def _string_list_errors(value: object, path: str) -> Iterator[str]:
    if not _is_string_list(value):
        yield f"{path}: 文字列の配列にしてください"
        return
    for item in value:
        yield from _utf8_error(item, path)


def _story_errors(
    story: object, path: str, known_ids: set[str], used_ids: set[str]
) -> Iterator[str]:
    if not isinstance(story, dict):
        yield f"{path}: 話題をJSONのオブジェクトにしてください"
        return

    for key in _REQUIRED_TEXT:
        value = story.get(key)
        if not isinstance(value, str) or not value.strip():
            yield f"{path}.{key}: 空白だけでない文字列にしてください"
        else:
            yield from _utf8_error(value, f"{path}.{key}")

    for key in ("notice", "waiting"):
        yield from _string_list_errors(story.get(key, []), f"{path}.{key}")

    neta = story.get("neta")
    if not isinstance(neta, dict):
        yield f"{path}.neta: JSONのオブジェクトにしてください"
    else:
        score = neta.get("score")
        if type(score) is not int or not 0 <= score <= 3:
            yield f"{path}.neta.score: 0〜3の整数にしてください"
        reason = neta.get("reason", "")
        if not isinstance(reason, str):
            yield f"{path}.neta.reason: 文字列にしてください"
        else:
            yield from _utf8_error(reason, f"{path}.neta.reason")
        yield from _string_list_errors(neta.get("channels", []), f"{path}.neta.channels")

    ids = story.get("event_ids")
    if not _is_string_list(ids) or not ids:
        yield f"{path}.event_ids: 出来事のIDを1件以上含む文字列の配列にしてください"
        return
    story_ids = set(ids)
    if story_ids - known_ids:
        yield f"{path}.event_ids: 入力にある出来事のIDだけを使ってください"
    if len(story_ids) != len(ids):
        yield f"{path}.event_ids: 同じ話題の中でIDを重複させないでください"
    if story_ids & used_ids:
        yield f"{path}.event_ids: ほかの話題で使ったIDを除いてください"
    used_ids.update(story_ids & known_ids)


def _story_values(story: dict) -> dict:
    neta = story["neta"]
    return {
        "title": story["title"],
        "what": story["what"],
        "why": story["why"],
        "notice": tuple(story.get("notice", [])),
        "waiting": tuple(story.get("waiting", [])),
        "neta": Neta(neta["score"], neta.get("reason", ""), tuple(neta.get("channels", []))),
        "event_ids": tuple(story["event_ids"]),
    }
