import json
from datetime import date, datetime

import pytest

from shipcast.model import Event

DAY = date(2026, 11, 26)
NOW = datetime.fromisoformat("2026-11-27T03:02:11+09:00")
REPO = "demo-app"


def _draft_values() -> dict:
    return {
        "lead": "  今日の要約です。  ",
        "summary": ["  一つ目  ", "二つ目", "三つ目"],
        "story": "\n### 一つ目\n\n本文です。\n\n### 二つ目\n\n続きです。\n",
    }


@pytest.mark.parametrize("fence", [None, "```", "```json"])
def test_parse_draft_reads_plain_and_fenced_json(fence):
    from shipcast.write import Draft, parse_draft

    text = json.dumps({**_draft_values(), "unknown": ["無視"]}, ensure_ascii=False)
    if fence:
        text = f"  \n{fence}\r\n{text}\r\n```\n  "
    assert parse_draft(text) == (
        Draft(
            "今日の要約です。",
            ("一つ目", "二つ目", "三つ目"),
            "### 一つ目\n\n本文です。\n\n### 二つ目\n\n続きです。",
        ),
        [],
    )


@pytest.mark.parametrize(
    ("text", "location"),
    [
        ("応答の目印", "応答"),
        ("", "応答"),
        ("NaN", "応答"),
        ("Infinity", "応答"),
        ("[" * 2000 + "]" * 2000, "応答"),
        ('["応答の目印"]', "応答"),
    ],
)
def test_parse_draft_rejects_invalid_json_or_non_object(text, location):
    from shipcast.write import parse_draft

    draft, errors = parse_draft(text)
    assert draft is None
    assert errors and all(error.startswith(f"{location}: ") for error in errors)
    assert all("応答の目印" not in error for error in errors)


@pytest.mark.parametrize(
    ("field", "value", "location"),
    [
        ("lead", None, "lead"),
        ("lead", " \t ", "lead"),
        ("lead", "応答の目印\n本文", "lead"),
        ("lead", "応答の目印" * 40 + "あ", "lead"),
        ("lead", "応答の目印 <!--", "lead"),
        ("lead", 1, "lead"),
        ("lead", "\ud800", "lead"),
        ("summary", None, "summary"),
        ("summary", [], "summary"),
        ("summary", ["応答の目印"] * 6, "summary"),
        ("summary", [" \t "], "summary[0]"),
        ("summary", ["応答の目印\r本文"], "summary[0]"),
        ("summary", ["<b>応答の目印"], "summary[0]"),
        ("summary", ["  :::tip 応答の目印"], "summary[0]"),
        ("summary", [1], "summary[0]"),
        ("summary", ["\ud800"], "summary[0]"),
        ("story", None, "story"),
        ("story", " \t ", "story"),
        ("story", ":::warning 応答の目印", "story"),
        ("story", "応答の目印\n  :::", "story"),
        ("story", "応答の目印 ::: 本文", "story"),
        ("story", "- :::tip 応答の目印", "story"),
        ("story", "> :::metrics 応答の目印", "story"),
        ("story", "## 応答の目印", "story"),
        ("story", "# 応答の目印", "story"),
        ("story", "応答の目印\n#", "story"),
        ("story", "1. ## 応答の目印", "story"),
        ("story", "> # 応答の目印", "story"),
        ("story", "応答の目印\n===", "story"),
        ("story", "応答の目印\n---", "story"),
        ("story", "応答の目印\n```", "story"),
        ("story", "応答の目印\n~~~", "story"),
        ("story", "応答の目印\n- ```", "story"),
        ("story", "<script>応答の目印", "story"),
        ("story", "<!-- 応答の目印 -->", "story"),
        ("story", "\ud800", "story"),
    ],
)
def test_parse_draft_reports_field_errors_without_echoing_values(field, value, location):
    from shipcast.write import parse_draft

    values = _draft_values()
    if value is None:
        del values[field]
    else:
        values[field] = value
    draft, errors = parse_draft(json.dumps(values))
    assert draft is None
    assert any(error.startswith(f"{location}: ") for error in errors)
    assert all("応答の目印" not in error for error in errors)


def test_parse_draft_reports_errors_in_all_fields():
    from shipcast.write import parse_draft

    draft, errors = parse_draft('{"lead": 1, "summary": [1, 2], "story": "#"}')
    assert draft is None
    assert {error.partition(":")[0] for error in errors} == {
        "lead",
        "summary[0]",
        "summary[1]",
        "story",
    }


def test_parse_draft_allows_story_markdown_and_quoted_setext():
    from shipcast.write import parse_draft

    story = "### 小見出し\n- ### 項目\na < b\n- 箇条書き\n1. 番号つき\n> 引用\n> ==="
    draft, errors = parse_draft(json.dumps({**_draft_values(), "story": story}))
    assert errors == []
    assert draft is not None and draft.story == story


def test_writer_prompt_is_packaged_and_survives_redaction():
    from importlib.resources import files

    from shipcast.redact import redact

    prompt = (files("shipcast") / "prompts" / "write.md").read_text(encoding="utf-8")
    for word in (
        "要約＋読み物",
        "です・ます調",
        "lead",
        "summary",
        "story",
        ":::",
        "previous_errors",
        "話題にない事実",
    ):
        assert word in prompt
    assert redact(prompt) == prompt


def _event(event_id, source="git", kind="commit", refs=(), *, repo_id=REPO):
    return Event(
        event_id,
        repo_id,
        source,
        kind,
        NOW.replace(day=26),
        "架空の出来事",
        body="出来事の本文の目印",
        refs=refs,
    )


def test_count_metrics_deduplicates_events_and_excludes_resolved_todos():
    from shipcast.write import Metric, count_metrics

    events = [
        _event("m1", "git", "merge"),
        _event("m2", "git", "merge"),
        _event("c1"),
        _event("c2"),
        _event("c3"),
        _event("c3"),
        _event("s1", "specdock", "scope_closed"),
        _event("s2", "specdock", "scope_opened"),
        _event("t1", "specdock", "todo_open", ("todo-1",)),
        _event("t2", "specdock", "todo_open", ("todo-2",)),
        _event("t3", "specdock", "todo_open"),
        _event("t4", "specdock", "todo_done", ("todo-2", "todo-1")),
        _event("o1", "orca", "conversation"),
    ]
    assert count_metrics(iter(events)) == (
        Metric(2, "merge"),
        Metric(3, "commit"),
        Metric(1, "閉じたScope"),
        Metric(2, "新しい本人待ちのtodo"),
    )
    assert count_metrics(iter(())) == (
        Metric(0, "merge"),
        Metric(0, "commit"),
        Metric(0, "閉じたScope"),
        Metric(0, "新しい本人待ちのtodo"),
    )


def _story(story_id, *, notice=(), waiting=(), title="架空の話題"):
    from shipcast.model import Neta, Story

    return Story(story_id, REPO, DAY, title, "見本を作成", "動作を確認", Neta(1), notice, waiting)


def _build_entry(stories, events, draft, **kwargs):
    from shipcast.write import build_entry

    return build_entry(
        REPO,
        DAY,
        stories,
        events,
        draft,
        analyst="fake/fake-analyst",
        writer="fake/fake-writer",
        generated_at=NOW,
        **kwargs,
    )


def test_build_entry_matches_full_journal():
    from shipcast.model import JournalMeta, parse_journal, write_frontmatter
    from shipcast.write import Draft

    draft = Draft("今日の要約です。", ("要点一", "要点二"), "### 小見出し\n\n本文です。")
    stories = [
        _story("a", notice=("<script>alert(1)</script>\n続き", "確認一"), waiting=("回答一",)),
        _story("b", notice=("確認二",), waiting=("回答二",)),
    ]
    events = [_event("commit"), _event("merge", "git", "merge")]
    text = _build_entry(stories, events, draft)

    assert (
        text
        == """\
---
title: demo-app の開発日誌 2026-11-26
lead: 今日の要約です。
date: 2026-11-26
repo: demo-app
category: 開発日誌
analyst: fake/fake-analyst
writer: fake/fake-writer
generated_at: 2026-11-27T03:02:11+09:00
schema: 1
---

:::summary 今日の要約
- 要点一
- 要点二
:::

:::warning あなたが知っておくべきこと
- &lt;script&gt;alert(1)&lt;/script&gt; 続き
- 確認一
- 確認二
:::

## 今日の物語

### 小見出し

本文です。

:::checklist あなたを待っていること
- 回答一
- 回答二
:::

:::metrics
- 1 | merge
- 1 | commit
- 0 | 閉じたScope
- 0 | 新しい本人待ちのtodo
:::
"""
    )
    assert "<script" not in text
    meta, body = parse_journal(text)
    assert meta == JournalMeta(
        "demo-app の開発日誌 2026-11-26",
        "今日の要約です。",
        DAY,
        REPO,
        "開発日誌",
        "fake/fake-analyst",
        "fake/fake-writer",
        "2026-11-27T03:02:11+09:00",
        1,
    )
    assert text == write_frontmatter(meta) + body


@pytest.mark.parametrize(
    ("value", "expected"),
    [
        (":::tip 偽", r"\:::tip 偽"),
        ("## 見出し", r"\## 見出し"),
        ("- 入れ子", r"\- 入れ子"),
        ("1. 番号", r"1\. 番号"),
        ("12) 番号", r"12\) 番号"),
        ("```", r"\```"),
        ("**太字**", r"\**太字**"),
        ("a & b", "a &amp; b"),
        (" 前後 ", "前後"),
    ],
)
def test_build_entry_escapes_list_items(value, expected):
    from shipcast.write import Draft

    text = _build_entry(
        [_story("sample", notice=(value,))],
        [_event("commit")],
        Draft("要約", ("要点",), "本文"),
    )
    assert f":::warning あなたが知っておくべきこと\n- {expected}\n:::" in text


@pytest.mark.parametrize("items", [(), (" \n\t ",)])
def test_build_entry_omits_empty_warning_and_checklist(items):
    from shipcast.write import Draft

    text = _build_entry(
        [_story("sample", notice=items, waiting=items)],
        [_event("commit")],
        Draft("要約", ("要点",), "本文"),
    )
    assert ":::warning" not in text
    assert ":::checklist" not in text


def test_build_entry_requires_draft_when_events_exist():
    with pytest.raises(ValueError, match="本文"):
        _build_entry([], [_event("commit")], None)


def test_build_entry_writes_only_frontmatter_and_one_line_without_events():
    from shipcast.write import Draft

    text = _build_entry(
        [_story("old", notice=("以前の確認",))],
        [],
        Draft("以前の要約", ("以前の要点",), "以前の本文"),
    )
    assert (
        text
        == """\
---
title: demo-app の開発日誌 2026-11-26
lead: 大きな動きはありませんでした。
date: 2026-11-26
repo: demo-app
category: 開発日誌
generated_at: 2026-11-27T03:02:11+09:00
schema: 1
---

大きな動きはありませんでした。
"""
    )


def test_build_entry_appends_nonempty_extensions_in_order(monkeypatch):
    from shipcast import write

    calls = []

    class Extension:
        def __init__(self, block):
            self.block = block

        def render(self, repo_id, day, stories, events):
            calls.append((repo_id, day, stories, events))
            return self.block

    stories = [_story("sample")]
    events = [_event("commit")]
    draft = write.Draft("要約", ("要点",), "本文")
    assert write.EXTENSIONS == ()
    base = _build_entry(stories, events, draft, extensions=[])
    assert _build_entry(stories, events, draft) == base

    tip = ":::tip 発信の芽\n本文\n:::"
    second = ":::note 次の囲み\n本文\n:::"
    extensions = (Extension(None), Extension(f" \n{tip}\n"), Extension(" \n"))
    assert _build_entry(stories, events, draft, extensions=extensions) == f"{base}\n{tip}\n"
    assert calls == [(REPO, DAY, stories, events)] * 3

    monkeypatch.setattr(write, "EXTENSIONS", (*extensions, Extension(second)))
    assert _build_entry(stories, events, draft) == f"{base}\n{tip}\n\n{second}\n"
    assert _build_entry(stories, events, draft, extensions=[]) == base

    calls.clear()
    _build_entry(stories, [], None, extensions=extensions)
    assert calls == []


def test_build_entry_propagates_extension_error():
    from shipcast.write import Draft

    failure = RuntimeError("囲みを作れません")

    class BrokenExtension:
        def render(self, repo_id, day, stories, events):
            raise failure

    with pytest.raises(RuntimeError) as captured:
        _build_entry(
            [],
            [_event("commit")],
            Draft("要約", ("要点",), "本文"),
            extensions=[BrokenExtension()],
        )
    assert captured.value is failure


def test_write_atomic_creates_parent_and_replaces_existing_file(tmp_path):
    from shipcast.write import write_atomic

    path = tmp_path / "journal" / "entry.md"
    write_atomic(path, "最初の本文\n")
    assert path.read_bytes() == "最初の本文\n".encode()
    write_atomic(path, "新しい本文\n")
    assert path.read_bytes() == "新しい本文\n".encode()
    assert path.stat().st_mode & 0o777 == 0o644
    assert list(path.parent.iterdir()) == [path]


@pytest.mark.parametrize("operation", ["fsync", "replace"])
def test_write_atomic_preserves_old_file_and_removes_temp_on_failure(
    tmp_path, monkeypatch, operation
):
    from shipcast import write

    path = tmp_path / "entry.md"
    path.write_text("前の日誌\n", encoding="utf-8")
    failure = OSError("試験用の書き込みエラー")

    def fail(*args):
        raise failure

    monkeypatch.setattr(write.os, operation, fail)
    with pytest.raises(OSError) as captured:
        write.write_atomic(path, "新しい日誌\n")
    assert captured.value is failure
    assert path.read_text(encoding="utf-8") == "前の日誌\n"
    assert list(tmp_path.iterdir()) == [path]
