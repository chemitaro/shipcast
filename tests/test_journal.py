from datetime import date, datetime

import pytest

from shipcast.model import (
    JournalFormatError,
    JournalMeta,
    ModelError,
    journal_path,
    parse_journal,
    read_frontmatter,
    write_frontmatter,
)

DAY = date(2026, 11, 26)


@pytest.mark.parametrize("repo", ["../x", "A", "a/b", "", "a_b", "a.b"])
def test_journal_path_rejects_invalid_repo(tmp_path, repo):
    with pytest.raises(ModelError, match=r"journal_path\.repo"):
        journal_path(tmp_path, repo, DAY)
    assert list(tmp_path.iterdir()) == []


def test_journal_path_does_not_create_files(tmp_path):
    assert journal_path(tmp_path, "demo-app", DAY) == tmp_path / "demo-app/2026/2026-11-26.md"
    assert list(tmp_path.iterdir()) == []


@pytest.mark.parametrize("full", [False, True])
def test_journal_round_trip(tmp_path, full):
    optional = (
        {
            "category": "開発日誌",
            "analyst": "fake/fake",
            "writer": "fake/fake",
            "generated_at": "2026-11-27T03:00:00+09:00",
            "schema": 0,
        }
        if full
        else {}
    )
    meta = JournalMeta("記録: 今日の変更", "要約", DAY, "demo-app", **optional)
    text = write_frontmatter(meta)
    expected = "---\ntitle: 記録: 今日の変更\nlead: 要約\ndate: 2026-11-26\nrepo: demo-app\n"
    if full:
        expected += (
            "category: 開発日誌\nanalyst: fake/fake\nwriter: fake/fake\n"
            "generated_at: 2026-11-27T03:00:00+09:00\nschema: 0\n"
        )
    assert text == expected + "---\n"

    body = "\n# 本文\r\n\n---\n最後"
    assert parse_journal(text + body) == (meta, body)
    path = tmp_path / "journal.md"
    path.write_text(text + body, encoding="utf-8")
    assert read_frontmatter(path) == meta


def test_journal_reads_bom_crlf_optional_empty_and_unknown_keys():
    text = (
        "\ufeff---  \r\ntitle : 記録: 今日の変更 \r\nlead: 要約\r\n\r\n"
        "date: 2026-11-26\r\nrepo: demo-app\r\nfuture: yes\r\n"
        "category: \r\nschema: \r\n---\r\n\r\n本文\r\n"
    )
    assert parse_journal(text) == (
        JournalMeta("記録: 今日の変更", "要約", DAY, "demo-app"),
        "\r\n本文\r\n",
    )


def test_read_missing_frontmatter(tmp_path):
    with pytest.raises(FileNotFoundError):
        read_frontmatter(tmp_path / "journal.md")


@pytest.mark.parametrize(
    ("text", "message"),
    [
        ("title: 記録\n---", "1"),
        ("---\ntitle: 記録", "---"),
        ("---\ntitle 記録\n---", "2"),
        ("---\nInvalid: value\n---", "2"),
        ("---\ntitle: 記録\ntitle: 記録\n---", "title"),
        ("---\nfuture: a\nfuture: b\n---", "future"),
        ("---\ntitle: 記録\nrepo: demo-app\nlead: \n---", "lead, date"),
        ("---\ntitle: 記録\nlead: 要約\ndate: 2026-13-01\nrepo: demo-app\n---", "date"),
        (
            "---\ntitle: 記録\nlead: 要約\ndate: 2026-11-26\nrepo: demo-app\nschema: x\n---",
            "schema",
        ),
    ],
)
def test_parse_rejects_invalid_frontmatter(text, message):
    with pytest.raises(JournalFormatError, match=message):
        parse_journal(text)


@pytest.mark.parametrize(
    ("change", "field"),
    [
        ({"title": "記録\n本文"}, "title"),
        ({"lead": "要約\r本文"}, "lead"),
        ({"lead": " 要約"}, "lead"),
        ({"title": ""}, "title"),
        ({"writer": ""}, "writer"),
        ({"category": "日誌 "}, "category"),
        ({"repo": "../demo-app"}, "repo"),
        ({"date": datetime(2026, 11, 26)}, "date"),
        ({"schema": True}, "schema"),
        ({"schema": -1}, "schema"),
    ],
)
def test_journal_meta_rejects_invalid_values(change, field):
    valid = {"title": "記録", "lead": "要約", "date": DAY, "repo": "demo-app"}
    with pytest.raises(JournalFormatError, match=rf"JournalMeta\.{field}"):
        JournalMeta(**(valid | change))
