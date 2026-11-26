"""Wrap Markdown into the thin page that the design system renders in the browser."""

import html
import re
import string
from collections.abc import Sequence
from dataclasses import dataclass
from datetime import date

from shipcast.model import JournalMeta

_SCRIPT_CLOSE = re.compile(r"</(script)", re.IGNORECASE | re.ASCII)

# Whatever state the HTML tokenizer is in at the end of the Markdown (script data,
# escaped after "<!--", or double escaped after "<!--<script"), the leading newline
# settles it and "<!-- -->" returns it to the script data state, so the next
# "</script>" always closes ds-source. In Markdown it is an invisible comment.
_SOURCE_END = "\n<!-- -->\n"

_FRAME = """\
<!doctype html>
<html lang="ja">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<meta name="color-scheme" content="light dark">
<title>{title}</title>
<link rel="icon" href="data:,">
<link rel="stylesheet" href="/_ds/ds.css">
<script type="text/markdown" id="ds-source">
{source}</script>
<script src="/_ds/ds.js"></script>
</head>
<body></body>
</html>
"""


def wrap_markdown(markdown: str, title: str) -> str:
    """Return the page for `markdown`; the only place Markdown is put into HTML.

    `</script` becomes `<\\/script` (ds.js restores it when reading ds-source).
    """
    source = _SCRIPT_CLOSE.sub(r"<\\/\1", markdown) + _SOURCE_END
    return _FRAME.format(title=html.escape(title, quote=True), source=source)


def notice_page(title: str, lead: str, body: str) -> str:
    """Return a page in the journal's look; callers pass only fixed text, never request data."""
    front_matter = f"---\ntitle: {title}\nlead: {lead}\ncategory: shipcast\n---\n\n"
    return wrap_markdown(front_matter + body, title)


NOT_FOUND_PAGE = notice_page(
    "ページが見つかりません",
    "このURLに当たる日誌はありません。",
    """\
:::note 日誌のURLの形
表紙は `/`、repositoryごとの一覧は `/<repo>/` です（例 `/demo-app/`）。
日誌の1日のページは `/<repo>/<YYYY-MM-DD>` です（例 `/demo-app/2026-11-26`）。
`<repo>` は登録したrepositoryの id、日付は日誌を書いた日です。
:::

その日の日誌が、まだ書かれていないのかもしれません。日誌は夜の実行で1日に1つずつ作られます。
""",
)

BROKEN_JOURNAL_PAGE = notice_page(
    "日誌を読めません",
    "この日の日誌のファイルはありますが、形が正しくないため表示できません。",
    """\
:::warning 前付けを確かめてください
日誌のファイルは、UTF-8で書きます。
先頭の `---` で囲んだ前付けに、`title`・`lead`・`date`・`repo` の4つを書きます。
:::

配信を動かしている端末の標準エラーに、読めなかったファイルと理由を1行で出しています。
""",
)


_PUNCTUATION = {ord(c): f"&#{ord(c)};" for c in string.punctuation}
_PUNCTUATION |= {ord("\n"): " ", ord("\r"): " "}


def markdown_text(value: str) -> str:
    """Return `value` as literal Markdown text: every ASCII punctuation becomes `&#NN;`.

    Neither marked nor ds.js (heading attributes, `:::` lines, inline components,
    `**…**`) reads a character reference as syntax, and the browser shows the character.
    """
    return value.translate(_PUNCTUATION)


@dataclass(frozen=True)
class JournalDay:
    """One journal file found under the journal directory; `meta` is None if unreadable."""

    repo: str
    day: date
    meta: JournalMeta | None


INDEX_TITLE = "shipcast の日誌"
INDEX_LEAD = "repositoryごとに、いちばん新しい日の日誌を並べています。"
UNREADABLE_SUMMARY = "前付けを読めないため要約を表示できません。"


def _page_markdown(title: str, lead: str, body: str) -> str:
    return f"---\ntitle: {title}\nlead: {lead}\ncategory: shipcast\n---\n\n{body}"


def _day_url(entry: JournalDay) -> str:
    return f"/{entry.repo}/{entry.day.isoformat()}"


def index_markdown(latest: Sequence[JournalDay], repos: Sequence[str]) -> str:
    """The cover: one card per repository's newest readable journal, in the given order."""
    if latest:
        cards = "".join(
            f"## {markdown_text(entry.meta.title)} "
            f"{{href={_day_url(entry)} badge={entry.repo},{entry.day.isoformat()}"
            " more=この日を読む}\n"
            f"{markdown_text(entry.meta.lead)}\n"
            for entry in latest
            if entry.meta is not None
        )
        newest = f":::cards\n{cards}:::\n"
    else:
        newest = (
            ":::note まだ日誌がありません\n"
            "日誌は `shipcast run` で、登録した repository ごとに1日に1つ作られます。\n"
            ":::\n"
        )
    body = f"## 最新の日誌\n\n{newest}"
    if repos:
        links = "".join(f"- [{repo}](/{repo}/)\n" for repo in repos)
        body += f"\n## repositoryごとの一覧\n\n{links}"
    return _page_markdown(INDEX_TITLE, INDEX_LEAD, body)


def repo_markdown(repo: str, days: Sequence[JournalDay]) -> str:
    """The list for one repository: every day, newest first, one timeline per month."""
    body = "[表紙へ戻る](/)\n"
    month = None
    for entry in days:
        if (entry.day.year, entry.day.month) != month:
            if month is not None:
                body += ":::\n"
            month = (entry.day.year, entry.day.month)
            body += f"\n## {entry.day.year}年{entry.day.month}月\n\n:::timeline\n"
        if entry.meta is None:
            summary = UNREADABLE_SUMMARY
        else:
            summary = f"**{markdown_text(entry.meta.title)}** {markdown_text(entry.meta.lead)}"
        body += f"- **[{entry.day.isoformat()}]({_day_url(entry)})** — {summary}\n"
    if month is not None:
        body += ":::\n"
    lead = f"{repo} の日誌を、新しい日から順に並べています（{len(days)}日分）。"
    return _page_markdown(repo_title(repo), lead, body)


def repo_title(repo: str) -> str:
    return f"{repo} の日誌"


def index_page(latest: Sequence[JournalDay], repos: Sequence[str]) -> str:
    return wrap_markdown(index_markdown(latest, repos), INDEX_TITLE)


def repo_page(repo: str, days: Sequence[JournalDay]) -> str:
    return wrap_markdown(repo_markdown(repo, days), repo_title(repo))
