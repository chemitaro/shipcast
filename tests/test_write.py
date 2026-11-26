import json

import pytest


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
