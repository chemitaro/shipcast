"""Wrap Markdown into the thin page that the design system renders in the browser."""

import html
import re

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
