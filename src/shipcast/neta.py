"""ネタポイントの残高から日誌の「発信の芽」を組み立てる。"""

import re
from collections.abc import Sequence
from datetime import date
from html import escape

from shipcast.model import Event, Story
from shipcast.state import Store

SPROUT_TITLES = 3

_NUMBERED_PREFIX = re.compile(r"^(\d+)([.)])")


def _inline_title(title: str) -> str:
    text = escape(" ".join(title.split()), quote=False)
    if text and text[0] in "#:-*+=`~|":
        return "\\" + text
    return _NUMBERED_PREFIX.sub(r"\1\\\2", text)


class NetaSprout:
    def __init__(self, store: Store, threshold: int) -> None:
        self._store = store
        self._threshold = threshold

    def render(
        self, repo_id: str, day: date, stories: Sequence[Story], events: Sequence[Event]
    ) -> str | None:
        balance = self._store.neta_balance(repo_id)
        if balance < self._threshold:
            return None

        candidates = self._store.unconsumed_stories(repo_id, limit=SPROUT_TITLES)
        lines = [f":::tip 発信の芽（ネタポイント {balance}）"]
        lines.extend(f"- {title}" for story in candidates if (title := _inline_title(story.title)))
        lines.append(":::")
        return "\n".join(lines)
