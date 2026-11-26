import json
import re
from collections.abc import Iterator
from dataclasses import dataclass
from importlib.resources import files

PROMPT_PATH = "prompts/write.md"

_RAW_HTML = re.compile(r"<[A-Za-z/!?]")
_BLOCK_PREFIX = re.compile(r"^(?:\s|>|[-*+](?:\s|$)|\d+[.)](?:\s|$))*")
_STORY_BLOCK = re.compile(r"^(?:#{1,2}(?:\s|$)|```|~~~)")
_SETEXT = re.compile(r"=+|-+")


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
    if single_line and ("\n" in value.strip() or "\r" in value.strip()):
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
