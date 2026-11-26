import re
import string
from datetime import date
from pathlib import Path

import html5lib
import pytest

from shipcast.model import JournalMeta, parse_journal
from shipcast.page import (
    BROKEN_JOURNAL_PAGE,
    NOT_FOUND_PAGE,
    JournalDay,
    index_markdown,
    index_page,
    markdown_text,
    notice_page,
    repo_markdown,
    repo_page,
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
    assert "`/`" in source
    assert "/<repo>/`" in source


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


LITERAL_MARKDOWN = re.compile(r"(?:[^!-/:-@\[-`{-~]|&#[0-9]+;|&amp;)*")
HOSTILE_TITLE = "直した {href=https://evil.example} **太字** [x](https://evil.example) :::"
HOSTILE_LEAD = "## x\n:::cards\n<img src=x onerror=alert(1)> &amp; :name[y] {now}"


def test_markdown_text_turns_every_ascii_punctuation_into_a_reference():
    assert markdown_text(string.punctuation) == "".join(
        "&amp;" if c == "&" else f"&#{ord(c)};" for c in string.punctuation
    )
    assert markdown_text("&amp;") == "&amp;amp&#59;"
    assert markdown_text("Abc 123 日本語　全角") == "Abc 123 日本語　全角"
    assert markdown_text("a\nb\rc") == "a b c"
    assert LITERAL_MARKDOWN.fullmatch(markdown_text(HOSTILE_TITLE + HOSTILE_LEAD))


def meta(repo: str, day: date, title: str = "", lead: str = "") -> JournalMeta:
    return JournalMeta(
        title=title or f"見本の題名 {day.month}月{day.day}日",
        lead=lead or f"見本の要約 {day.month}月{day.day}日です。",
        date=day,
        repo=repo,
    )


def journal_day(repo: str, day: date, **kwargs) -> JournalDay:
    return JournalDay(repo, day, meta(repo, day, **kwargs))


def directive_lines(markdown: str, name: str) -> list[list[str]]:
    """Return the body lines of each `:::name` block (the blocks do not nest here)."""
    blocks, current = [], None
    for line in markdown.split("\n"):
        if current is None and line.split(" ")[0] == f":::{name}":
            current = []
        elif current is not None and line == ":::":
            blocks.append(current)
            current = None
        elif current is not None:
            current.append(line)
    assert current is None
    return blocks


def test_index_markdown_lists_one_card_per_latest_journal():
    latest = [
        journal_day("sample-lib", date(2026, 11, 27)),
        journal_day("demo-app", date(2026, 11, 26)),
    ]

    markdown = index_markdown(latest, ["demo-app", "sample-lib"])

    meta_lines, body = parse_journal_like(markdown)
    assert meta_lines["title"] == "shipcast の日誌"
    assert meta_lines["category"] == "shipcast"
    [cards] = directive_lines(body, "cards")
    headings = [line for line in cards if line.startswith("## ")]
    assert headings == [
        "## 見本の題名 11月27日 "
        "{href=/sample-lib/2026-11-27 badge=2026-11-27 more=この日を読む}",
        "## 見本の題名 11月26日 "
        "{href=/demo-app/2026-11-26 badge=2026-11-26 more=この日を読む}",
    ]
    first = cards.index(headings[0])
    assert cards[first + 1 : first + 4] == ["見本の要約 11月27日です。", "", "sample-lib の日誌"]
    assert "- [demo-app](/demo-app/)\n- [sample-lib](/sample-lib/)" in body


def test_index_markdown_without_journals_explains_how_they_are_made():
    markdown = index_markdown([], [])

    assert ":::note まだ日誌がありません" in markdown
    assert "shipcast run" in markdown
    assert ":::cards" not in markdown
    assert "repositoryごとの一覧" not in markdown


def test_repo_markdown_groups_days_by_month_newest_first():
    days = [
        journal_day("demo-app", date(2026, 11, 27)),
        JournalDay("demo-app", date(2026, 11, 26), None),
        journal_day("demo-app", date(2026, 10, 31)),
    ]

    markdown = repo_markdown("demo-app", days)

    meta_lines, body = parse_journal_like(markdown)
    assert meta_lines["title"] == "demo-app の日誌"
    assert "3日分" in meta_lines["lead"]
    assert "[表紙へ戻る](/)" in body
    months = [line for line in body.split("\n") if line.startswith("## ")]
    assert months == ["## 2026年11月", "## 2026年10月"]
    november, october = directive_lines(body, "timeline")
    assert november == [
        "- **[2026-11-27](/demo-app/2026-11-27)** — "
        "**見本の題名 11月27日** 見本の要約 11月27日です。",
        "- **[2026-11-26](/demo-app/2026-11-26)** — 前付けを読めないため要約を表示できません。",
    ]
    assert october == [
        "- **[2026-10-31](/demo-app/2026-10-31)** — "
        "**見本の題名 10月31日** 見本の要約 10月31日です。",
    ]


def test_hostile_front_matter_does_not_change_the_shape():
    hostile = {"title": HOSTILE_TITLE, "lead": HOSTILE_LEAD.replace("\n", " ")}
    latest = [
        journal_day("demo-app", date(2026, 11, 27), **hostile),
        journal_day("sample-lib", date(2026, 11, 20), **hostile),
    ]

    cover = index_markdown(latest, ["demo-app", "sample-lib"])
    listing = repo_markdown("demo-app", [latest[0], journal_day("demo-app", date(2026, 11, 26))])

    [cards] = directive_lines(cover, "cards")
    headings = [line for line in cards if line.startswith("#")]
    assert len(headings) == 2
    for heading in headings:
        assert heading.count("{") == heading.count("}") == 1
        assert heading.endswith("more=この日を読む}")
    [timeline] = directive_lines(listing, "timeline")
    assert len(timeline) == 2
    assert all(line.startswith("- **[2026-11-2") for line in timeline)
    for markdown in (cover, listing):
        assert "](https://" not in markdown
        assert "href=https" not in markdown
        assert "<img" not in markdown
        assert markdown.count(":::") == 2


def test_index_and_repo_pages_wrap_the_markdown():
    latest = [journal_day("demo-app", date(2026, 11, 26), title="<b>題</b>")]
    cover = index_page(latest, ["demo-app"])
    listing = repo_page("demo-app", latest)

    assert_frame(cover)
    assert_frame(listing)
    assert parse(cover).find("head").find("title").text == "shipcast の日誌"
    assert parse(listing).find("head").find("title").text == "demo-app の日誌"
    assert ds_restore(source_of(cover)) == "\n" + index_markdown(latest, ["demo-app"]) + FENCE
    assert ds_restore(source_of(listing)) == "\n" + repo_markdown("demo-app", latest) + FENCE
