import re
from pathlib import Path

import html5lib
import pytest

from shipcast.model import parse_journal
from shipcast.page import (
    BROKEN_JOURNAL_PAGE,
    NOT_FOUND_PAGE,
    notice_page,
    wrap_markdown,
)

FIXTURE = Path(__file__).parent / "fixtures/journal/demo-app/2026/2026-11-26.md"
FENCE = "\n<!-- -->\n"


def parse(page: str):
    """Read the page the way a browser does (HTML Living Standard tokenizer)."""
    return html5lib.parse(page, namespaceHTMLElements=False)


def ds_restore(text: str) -> str:
    r"""The same restoration as ds.js: `.replace(/<\\\/script/gi, "</script")`."""
    return re.sub(r"<\\/script", "</script", text, flags=re.IGNORECASE | re.ASCII)


def source_of(page: str) -> str:
    document = parse(page)
    sources = [s for s in document.iter("script") if s.get("id") == "ds-source"]
    assert len(sources) == 1
    assert sources[0].get("type") == "text/markdown"
    return sources[0].text or ""


def assert_frame(page: str) -> None:
    document = parse(page)
    head = document.find("head")
    scripts = list(head.iter("script"))
    assert [s.get("src") for s in scripts] == [None, "/_ds/ds.js"]
    assert scripts[0].get("id") == "ds-source"
    links = head.iter("link")
    stylesheets = [link.get("href") for link in links if link.get("rel") == "stylesheet"]
    assert stylesheets == ["/_ds/ds.css"]
    body = document.find("body")
    assert list(body) == []
    assert (body.text or "").strip() == ""


def test_wrap_markdown_returns_the_thin_frame():
    assert wrap_markdown("# 本文\n", "今日の日誌") == (
        "<!doctype html>\n"
        '<html lang="ja">\n'
        "<head>\n"
        '<meta charset="utf-8">\n'
        '<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">\n'
        '<meta name="color-scheme" content="light dark">\n'
        "<title>今日の日誌</title>\n"
        '<link rel="icon" href="data:,">\n'
        '<link rel="stylesheet" href="/_ds/ds.css">\n'
        '<script type="text/markdown" id="ds-source">\n'
        "# 本文\n"
        "\n<!-- -->\n"
        "</script>\n"
        '<script src="/_ds/ds.js"></script>\n'
        "</head>\n"
        "<body></body>\n"
        "</html>\n"
    )


@pytest.mark.parametrize(
    "markdown",
    [
        "前</script><script>document.title='x'</script>後",
        "前</SCRIPT >後",
        "前</script/後",
        "前</Script\t後",
        "閉じない <!--<script> の後ろ",
        "閉じない <!-- <script>\n\n</script>\n本文",
        "閉じた <!-- <script> --> の後ろ",
        "<!-- 閉じた --> と <!-- 閉じない",
        "末尾の <!--",
        "末尾の <script",
        "末尾の <!-- <script",
        "末尾の <!-",
        "末尾の <",
        "末尾の -",
        "<!-->すぐ閉じる<script>",
        "```html\n<!-- <script> -->\n</script>\n```\n",
        "",
    ],
)
def test_wrapped_source_closes_where_the_frame_closes(markdown):
    page = wrap_markdown(markdown, "題")

    assert_frame(page)
    expected = re.sub(r"</script", "</script", markdown, flags=re.IGNORECASE | re.ASCII)
    assert ds_restore(source_of(page)) == "\n" + expected + FENCE


def test_only_ascii_script_is_escaped():
    markdown = "前</ſcript>と</scrİpt>後"
    page = wrap_markdown(markdown, "題")

    assert "</ſcript>" in page
    assert "</scrİpt>" in page
    assert ds_restore(source_of(page)) == "\n" + markdown + FENCE


def test_original_case_is_kept_until_ds_js_restores_it():
    page = wrap_markdown("</SCRIPT>", "題")

    assert "<\\/SCRIPT>" in page
    assert ds_restore(source_of(page)) == "\n</script>" + FENCE


@pytest.mark.parametrize(
    "title",
    [
        "架空の開発日誌 <b>見本</b>",
        "</title><script>document.title='x'</script>",
        "A & B \"quoted\" 'single'",
    ],
)
def test_title_is_text(title):
    page = wrap_markdown("本文", title)

    document = parse(page)
    assert document.find("head").find("title").text == title
    assert_frame(page)


def test_fixture_journal_is_wrapped_whole():
    text = FIXTURE.read_text(encoding="utf-8")
    meta, _ = parse_journal(text)
    page = wrap_markdown(text, meta.title)

    assert_frame(page)
    assert parse(page).find("head").find("title").text == "架空の開発日誌 <b>見本</b>"
    assert ds_restore(source_of(page)) == "\n" + text + FENCE
    assert "</script><script>" not in page


@pytest.mark.parametrize(
    ("page", "title"),
    [
        (NOT_FOUND_PAGE, "ページが見つかりません"),
        (BROKEN_JOURNAL_PAGE, "日誌を読めません"),
    ],
)
def test_notice_pages_use_the_design_system(page, title):
    assert_frame(page)
    meta, body = parse_journal_like(ds_restore(source_of(page)))
    assert meta["title"] == title
    assert meta["lead"]
    assert meta["category"] == "shipcast"
    assert parse(page).find("head").find("title").text == title
    assert ":::" in body


def test_not_found_page_explains_the_url_shape():
    source = source_of(NOT_FOUND_PAGE)
    assert "/<repo>/<YYYY-MM-DD>" in source


def test_broken_journal_page_points_to_the_front_matter_and_stderr():
    source = source_of(BROKEN_JOURNAL_PAGE)
    for word in ("title", "lead", "date", "repo", "標準エラー"):
        assert word in source


def test_notice_page_builds_front_matter_and_body():
    page = notice_page("案内の題", "案内の要約", "本文の段落")

    meta, body = parse_journal_like(ds_restore(source_of(page)))
    assert meta == {"title": "案内の題", "lead": "案内の要約", "category": "shipcast"}
    assert body.strip().startswith("本文の段落")
    assert parse(page).find("head").find("title").text == "案内の題"


def parse_journal_like(source: str) -> tuple[dict[str, str], str]:
    lines = source.removeprefix("\n").split("\n")
    assert lines[0] == "---"
    closing = lines.index("---", 1)
    meta = dict(line.split(": ", 1) for line in lines[1:closing])
    return meta, "\n".join(lines[closing + 1 :])
