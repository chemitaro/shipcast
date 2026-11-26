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
        ("lead", "応答の目印\n", "lead"),
        ("lead", "応答の目印" * 40 + "あ", "lead"),
        ("lead", "応答の目印 <!--", "lead"),
        ("lead", 1, "lead"),
        ("lead", "\ud800", "lead"),
        ("summary", None, "summary"),
        ("summary", [], "summary"),
        ("summary", ["応答の目印"] * 6, "summary"),
        ("summary", [" \t "], "summary[0]"),
        ("summary", ["応答の目印\r本文"], "summary[0]"),
        ("summary", ["\r応答の目印"], "summary[0]"),
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


def _fake_route(model, responder):
    from shipcast.config import ModelConfig
    from shipcast.models import get_route

    return get_route(ModelConfig("fake", model, None, None), env={}, responder=responder)


@pytest.mark.parametrize("retry", [False, True])
def test_compose_passes_only_story_outline_and_retries_invalid_draft(retry):
    from importlib.resources import files

    from shipcast.models import JSON_INSTRUCTION
    from shipcast.write import compose

    calls = []

    def respond(prompt, system, want_json):
        calls.append((json.loads(prompt), system, want_json))
        values = _draft_values()
        if retry and len(calls) == 1:
            values["story"] = "## 応答の目印"
        return json.dumps(values, ensure_ascii=False)

    story = _story("非公開の話題ID", notice=("確認",), waiting=("回答",))
    draft = compose([story], _fake_route("fake-writer", respond), repo_id=REPO, day=DAY)
    assert draft.lead == "今日の要約です。"
    outline = {
        "title": "架空の話題",
        "what": "見本を作成",
        "why": "動作を確認",
        "notice": ["確認"],
        "waiting": ["回答"],
    }
    first = {"repo": REPO, "date": DAY.isoformat(), "stories": [outline]}
    prompt_text = (files("shipcast") / "prompts" / "write.md").read_text(encoding="utf-8")
    system = f"{prompt_text}\n\n{JSON_INSTRUCTION}"
    assert calls[0] == (first, system, True)
    assert len(calls) == 1 + retry
    if retry:
        second, second_system, want_json = calls[1]
        errors = second.pop("previous_errors")
        assert any(error.startswith("story: ") for error in errors)
        assert "応答の目印" not in str(errors)
        assert (second, second_system, want_json) == (first, system, True)


def test_compose_reports_final_errors_without_response_values():
    from shipcast.write import WriteFailed, compose

    responses = iter(['{"lead": "最初の目印"}', '{"story": "## 応答の目印"}'])
    calls = []

    def respond(*args):
        calls.append(args)
        return next(responses)

    with pytest.raises(WriteFailed) as captured:
        compose([_story("sample")], _fake_route("fake-writer", respond), repo_id=REPO, day=DAY)
    error = captured.value
    assert error.attempts == len(calls) == 2
    assert {item.partition(":")[0] for item in error.errors} == {"lead", "summary", "story"}
    assert str(error).startswith("書き手の応答が2回とも決まった形になりませんでした：")
    assert "応答の目印" not in str(error) and "最初の目印" not in str(error)


def test_compose_propagates_route_failure_without_retry_or_call_for_empty_stories():
    from shipcast.models import RouteFailed
    from shipcast.write import compose

    failure = RouteFailed("fake", reason="架空の失敗")
    calls = []

    def fail(*args):
        calls.append(args)
        raise failure

    route = _fake_route("fake-writer", fail)
    with pytest.raises(ValueError):
        compose([], route, repo_id=REPO, day=DAY)
    assert calls == []
    with pytest.raises(RouteFailed) as captured:
        compose([_story("sample")], route, repo_id=REPO, day=DAY)
    assert captured.value is failure
    assert len(calls) == 1


def _analysis_reply(prompt, system, want_json):
    events = json.loads(prompt)["events"]
    return json.dumps(
        {
            "stories": [
                {
                    "title": f"今回の話題 {event['id']}",
                    "what": "見本を作成",
                    "why": "動作を確認",
                    "notice": [f"確認 {event['id']}"],
                    "neta": {"score": 1},
                    "event_ids": [event["id"]],
                }
                for event in reversed(events)
            ]
        },
        ensure_ascii=False,
    )


def _writer_reply(prompt, system, want_json):
    assert "出来事の本文の目印" not in prompt
    return json.dumps(_draft_values(), ensure_ascii=False)


def _write_day(store, journal_dir, *, analysis_reply=_analysis_reply, writer_reply=_writer_reply):
    from shipcast.write import write_day

    return write_day(
        store,
        REPO,
        DAY,
        tz=NOW.tzinfo,
        journal_dir=journal_dir,
        now=NOW,
        analyst=_fake_route("fake-analyst", analysis_reply),
        writer=_fake_route("fake-writer", writer_reply),
    )


def test_write_day_uses_current_analysis_order_and_registered_extension(tmp_path, monkeypatch):
    from shipcast import write
    from shipcast.model import Entry, journal_path, story_id
    from shipcast.state import Store

    block = ":::tip 発信の芽\n架空の案\n:::"

    class Extension:
        def render(self, repo_id, day, stories, events):
            return block

    extension = Extension()
    monkeypatch.setattr(write, "EXTENSIONS", (extension,))
    journal_dir = tmp_path / "journal"
    events = [_event("a"), _event("b")]
    with Store(tmp_path / "state") as store:
        store.add_events(events)
        store.save_stories(
            [_story("old-story", title="古い話題の目印", notice=("古い話題の目印",))]
        )
        result = _write_day(store, journal_dir)

        assert result.path == journal_path(journal_dir, REPO, DAY)
        assert result.events == 2
        assert tuple(story.title for story in result.stories) == ("今回の話題 b", "今回の話題 a")
        text = result.path.read_text(encoding="utf-8")
        draft, errors = write.parse_draft(_writer_reply("{}", "", True))
        assert not errors
        assert text == _build_entry(result.stories, events, draft, extensions=[extension])
        assert text.endswith(f"\n\n{block}\n")
        assert "古い話題の目印" not in text
        assert store.entry_for(REPO, DAY) == Entry(
            REPO,
            DAY,
            str(result.path),
            "fake/fake-analyst",
            "fake/fake-writer",
            NOW,
            (story_id(REPO, DAY, ("b",)), story_id(REPO, DAY, ("a",))),
        )


def test_write_day_records_empty_day_without_calling_routes(tmp_path):
    from shipcast.model import Entry, journal_path, parse_journal
    from shipcast.state import Store

    def unexpected(*args):
        pytest.fail("出来事のない日に経路が呼ばれました")

    journal_dir = tmp_path / "journal"
    with Store(tmp_path / "state") as store:
        result = _write_day(store, journal_dir, analysis_reply=unexpected, writer_reply=unexpected)
        assert result.path == journal_path(journal_dir, REPO, DAY)
        assert result.events == 0 and result.stories == ()
        meta, body = parse_journal(result.path.read_text(encoding="utf-8"))
        assert meta.lead == "大きな動きはありませんでした。"
        assert meta.analyst is None and meta.writer is None
        assert body == "\n大きな動きはありませんでした。\n"
        assert store.entry_for(REPO, DAY) == Entry(
            REPO,
            DAY,
            str(result.path),
            "none",
            "none",
            NOW,
        )


@pytest.mark.parametrize("stage", ["analyst", "writer", "extension"])
def test_write_day_preserves_existing_file_and_entry_on_failure(tmp_path, monkeypatch, stage):
    from shipcast import write
    from shipcast.analyze import AnalyzeFailed
    from shipcast.model import Entry, journal_path
    from shipcast.state import Store

    failure = RuntimeError("拡張点の試験用エラー")

    class BrokenExtension:
        def render(self, repo_id, day, stories, events):
            raise failure

    def invalid(*args):
        return "{}"

    expected = {"analyst": AnalyzeFailed, "writer": write.WriteFailed, "extension": RuntimeError}
    if stage == "extension":
        monkeypatch.setattr(write, "EXTENSIONS", (BrokenExtension(),))

    journal_dir = tmp_path / "journal"
    path = journal_path(journal_dir, REPO, DAY)
    path.parent.mkdir(parents=True)
    path.write_text("前の日誌\n", encoding="utf-8")
    old_entry = Entry(REPO, DAY, str(path), "old/analyst", "old/writer", NOW, ("old-story",))
    with Store(tmp_path / "state") as store:
        store.add_events([_event("a")])
        store.save_entry(old_entry)
        with pytest.raises(expected[stage]) as captured:
            _write_day(
                store,
                journal_dir,
                analysis_reply=invalid if stage == "analyst" else _analysis_reply,
                writer_reply=invalid if stage == "writer" else _writer_reply,
            )
        if stage == "extension":
            assert captured.value is failure
        assert path.read_text(encoding="utf-8") == "前の日誌\n"
        assert list(path.parent.iterdir()) == [path]
        assert store.entry_for(REPO, DAY) == old_entry


@pytest.fixture
def write_cli(tmp_path, monkeypatch):
    from shipcast import write
    from shipcast.collect.base import CollectError, CollectResult

    config = tmp_path / "config.toml"
    journal_dir = tmp_path / "journal"
    config.write_text(
        f"""\
timezone = "Asia/Tokyo"
state_dir = "{tmp_path / "state"}"
journal_dir = "{journal_dir}"

[models.analyst]
route = "fake"
model = "fake-analyst"

[models.writer]
route = "fake"
model = "fake-writer"

[[repos]]
id = "{REPO}"
path = "{tmp_path / REPO}"

[[repos]]
id = "other-app"
path = "{tmp_path / "other-app"}"
""",
        encoding="utf-8",
    )
    monkeypatch.setenv("SHIPCAST_CONFIG", str(config))

    class Collector:
        name = "git"
        failure = None
        extra_events = ()

        def collect(self, repo, day, tz):
            assert tz.key == "Asia/Tokyo"
            if repo.id == self.failure:
                raise CollectError("試験用の収集エラー")
            if day != DAY:
                return CollectResult()
            event = _event(f"{repo.id}-commit", repo_id=repo.id)
            return CollectResult((event, *self.extra_events), ("試験用の収集警告",))

    class FixedDatetime(datetime):
        @classmethod
        def now(cls, tz=None):
            assert tz.key == "Asia/Tokyo"
            return NOW.replace(day=26).astimezone(tz)

    collector = Collector()
    monkeypatch.setattr(write, "COLLECTORS", (collector,))
    monkeypatch.setattr(write, "datetime", FixedDatetime)
    replies = {"fake-analyst": _analysis_reply, "fake-writer": _writer_reply}

    def route(model_cfg):
        assert model_cfg.route == "fake"
        return _fake_route(model_cfg.model, replies[model_cfg.model])

    monkeypatch.setattr(write, "get_route", route)
    return journal_dir, collector, replies


def test_write_cli_exposes_repo_and_date_options(capsys):
    from shipcast.cli import main

    with pytest.raises(SystemExit) as captured:
        main(["write", "--help"])
    assert captured.value.code == 0
    stdout = capsys.readouterr().out
    assert "--repo ID" in stdout and "--date YYYY-MM-DD" in stdout


def test_journal_extensions_appends_sprout_to_current_defaults(tmp_path, monkeypatch):
    from shipcast import write
    from shipcast.neta import NetaSprout
    from shipcast.state import Store

    class Extension:
        def render(self, repo_id, day, stories, events):
            return None

    earlier = Extension()
    monkeypatch.setattr(write, "EXTENSIONS", (earlier,))
    with Store(tmp_path) as store:
        extensions = write.journal_extensions(store, 6)
        assert extensions[:-1] == (earlier,)
        assert isinstance(extensions[-1], NetaSprout)


def test_write_cli_appends_sprout_only_on_active_day_at_threshold(
    tmp_path, monkeypatch, write_cli
):
    from shipcast import write
    from shipcast.cli import main
    from shipcast.model import journal_path, parse_journal

    existing_block = ":::tip 既存の拡張点\n見本\n:::"

    class Extension:
        def render(self, repo_id, day, stories, events):
            return existing_block

    monkeypatch.setattr(write, "EXTENSIONS", (Extension(),))
    journal_dir, collector, replies = write_cli
    collector.extra_events = (_event("demo-app-review"),)

    def scored_reply(prompt, system, want_json):
        response = json.loads(_analysis_reply(prompt, system, want_json))
        response["stories"][0]["neta"]["score"] = 2
        return json.dumps(response, ensure_ascii=False)

    replies["fake-analyst"] = scored_reply
    config = tmp_path / "config.toml"
    base_config = config.read_text(encoding="utf-8")

    def configure_threshold(threshold):
        config.write_text(f"{base_config}\n[neta]\nthreshold = {threshold}\n", encoding="utf-8")

    def write_journal(day):
        assert main(["write", "--repo", REPO, "--date", day.isoformat()]) == 0
        return parse_journal(journal_path(journal_dir, REPO, day).read_text(encoding="utf-8"))[1]

    configure_threshold(3)
    blocks = write_journal(DAY).rstrip().split("\n\n")
    assert blocks[-1] == (
        ":::tip 発信の芽（ネタポイント 3）\n"
        "- 今回の話題 demo-app-review\n"
        "- 今回の話題 demo-app-commit\n"
        ":::"
    )
    assert blocks[-2] == existing_block
    assert blocks[-3].startswith(":::metrics\n")

    monkeypatch.setattr(write, "EXTENSIONS", ())
    configure_threshold(4)
    assert ":::tip" not in write_journal(DAY)

    configure_threshold(3)
    assert ":::tip" not in write_journal(DAY.replace(day=27))


@pytest.mark.parametrize("selected", [True, False])
def test_write_cli_writes_selected_or_all_repositories(capsys, write_cli, selected):
    from shipcast.cli import main
    from shipcast.model import journal_path, parse_journal

    journal_dir, _, _ = write_cli
    args = ["write", "--repo", REPO, "--date", DAY.isoformat()] if selected else ["write"]
    assert main(args) == 0
    output = capsys.readouterr()
    path = journal_path(journal_dir, REPO, DAY)
    assert f"{REPO} {DAY}: 日誌を書きました（出来事 1件、話題 1件）: {path}" in output.out
    assert f"shipcast write: 警告: {REPO}: git: 試験用の収集警告" in output.err
    meta, _ = parse_journal(path.read_text(encoding="utf-8"))
    assert (meta.repo, meta.date, meta.generated_at) == (REPO, DAY, "2026-11-26T03:02:11+09:00")
    assert journal_path(journal_dir, "other-app", DAY).exists() is (not selected)


def test_write_cli_rejects_unknown_repo(capsys, write_cli):
    from shipcast.cli import main

    journal_dir, _, _ = write_cli
    assert main(["write", "--repo", "missing-app"]) == 1
    assert "shipcast write: 登録されていないrepositoryです: missing-app" in capsys.readouterr().err
    assert not journal_dir.exists()


def test_write_cli_skips_failed_collection_and_continues(capsys, write_cli):
    from shipcast.cli import main
    from shipcast.model import journal_path

    journal_dir, collector, _ = write_cli
    collector.failure = REPO
    assert main(["write"]) == 1
    output = capsys.readouterr()
    assert f"shipcast write: 失敗: {REPO}: git: 試験用の収集エラー" in output.err
    assert f"shipcast write: 失敗: {REPO}: 収集に失敗したため、日誌を書きませんでした" in output.err
    assert not journal_path(journal_dir, REPO, DAY).exists()
    assert journal_path(journal_dir, "other-app", DAY).exists()
    assert f"other-app {DAY}: 日誌を書きました" in output.out


def test_write_cli_reports_invalid_writer_response(capsys, write_cli):
    from shipcast.cli import main

    journal_dir, _, replies = write_cli
    replies["fake-writer"] = lambda *args: "{}"
    assert main(["write", "--repo", REPO]) == 1
    assert (
        f"shipcast write: 失敗: {REPO}: 書き手の応答が2回とも決まった形になりませんでした"
        in capsys.readouterr().err
    )
    assert not journal_dir.exists()


def test_write_cli_reports_extension_errors_for_each_repository(capsys, monkeypatch, write_cli):
    from shipcast import write
    from shipcast.cli import main

    class BrokenExtension:
        def render(self, repo_id, day, stories, events):
            raise RuntimeError("拡張点の試験用エラー")

    journal_dir, _, _ = write_cli
    monkeypatch.setattr(write, "EXTENSIONS", (BrokenExtension(),))
    assert main(["write"]) == 1
    output = capsys.readouterr()
    for repo_id in (REPO, "other-app"):
        assert f"shipcast write: 失敗: {repo_id}: RuntimeError: 拡張点の試験用エラー" in output.err
    assert "Traceback" not in output.err and not output.out
    assert not journal_dir.exists()


@pytest.mark.parametrize("error_type", ["route", "value"])
def test_write_cli_reports_model_route_setup_error(capsys, monkeypatch, write_cli, error_type):
    from shipcast import write
    from shipcast.cli import main
    from shipcast.models import RouteFailed

    journal_dir, _, _ = write_cli
    failure = RouteFailed("fake", reason="試験用の準備失敗")
    if error_type == "value":
        failure = ValueError("試験用の準備失敗")

    def fail(model_cfg):
        raise failure

    monkeypatch.setattr(write, "get_route", fail)
    assert main(["write"]) == 1
    assert f"shipcast write: モデルの経路を作れません: {failure}" in capsys.readouterr().err
    assert not journal_dir.exists()


def test_write_cli_preflights_state_before_creating_routes(
    tmp_path, capsys, monkeypatch, write_cli
):
    from shipcast import write
    from shipcast.cli import main

    journal_dir, _, _ = write_cli
    (tmp_path / "state").write_text("ディレクトリではない状態の置き場", encoding="utf-8")

    def unexpected(model_cfg):
        pytest.fail("状態の置き場が開けないときにモデルの経路を作りました")

    monkeypatch.setattr(write, "get_route", unexpected)
    assert main(["write"]) == 1
    error = capsys.readouterr().err
    assert "shipcast write: 状態の置き場を開けません:" in error
    assert "直し方: 設定の `state_dir` が" in error
    assert not journal_dir.exists()


def test_write_cli_propagates_keyboard_interrupt(write_cli):
    from shipcast.cli import main

    journal_dir, _, replies = write_cli

    def interrupt(*args):
        raise KeyboardInterrupt

    replies["fake-writer"] = interrupt
    with pytest.raises(KeyboardInterrupt):
        main(["write", "--repo", REPO])
    assert not journal_dir.exists()
