import json
from datetime import date
from importlib.resources import files

import pytest

from shipcast.config import ModelConfig
from shipcast.model import Neta, Story
from shipcast.models import JSON_INSTRUCTION, RouteError, get_route
from shipcast.redact import redact

DAY = date(2026, 11, 26)
REPO = "demo-app"


def _story(story_id="sample", *, repo_id=REPO, score=1, title="架空の話題"):
    return Story(
        story_id,
        repo_id,
        DAY,
        title,
        "見本を作成",
        "動作を確認",
        Neta(score),
        notice=("確認",),
        waiting=("回答",),
        event_ids=("sample-event",),
    )


def _fake_route(responder):
    return get_route(ModelConfig("fake", "fake-writer", None, None), env={}, responder=responder)


@pytest.mark.parametrize(
    ("text", "length"),
    [("abc", 3), ("日本語", 6), ("—", 1), ("か\u3099", 2)],
)
def test_x_length_counts_nfc_codepoints(text, length):
    from shipcast.draft import x_length

    assert x_length(text) == length


@pytest.mark.parametrize("fence", [None, "```", "```json"])
def test_parse_x_draft_trims_text_and_tags_and_builds_post(fence):
    from shipcast.draft import XDraft, parse_x_draft

    response = json.dumps({"text": "  一行目\n二行目  ", "hashtags": [" #個人開発 ", "#shipcast"]})
    if fence:
        response = f" \n{fence}\r\n{response}\r\n```\n "
    draft, errors = parse_x_draft(response)
    assert errors == []
    assert draft == XDraft("一行目\n二行目", ("#個人開発", "#shipcast"))
    assert draft.post == "一行目\n二行目\n\n#個人開発 #shipcast"


@pytest.mark.parametrize("extra", [{}, {"hashtags": []}])
def test_parse_x_draft_accepts_limit_without_tags(extra):
    from shipcast.draft import XDraft, parse_x_draft

    text = "日" * 140
    draft, errors = parse_x_draft(json.dumps({"text": text, **extra}))
    assert errors == []
    assert draft == XDraft(text, ())
    assert draft.post == text


@pytest.mark.parametrize(
    ("text", "tags", "length"), [("日" * 141, [], 282), ("日" * 140, ["#shipcast"], 291)]
)
def test_parse_x_draft_checks_length_of_whole_post(text, tags, length):
    from shipcast.draft import parse_x_draft

    draft, errors = parse_x_draft(json.dumps({"text": text, "hashtags": tags}))
    assert draft is None
    assert len(errors) == 1
    assert errors[0].startswith("post: ")
    assert str(length) in errors[0] and "280" in errors[0]


@pytest.mark.parametrize(
    "response", ["応答の目印", '["応答の目印"]', '{"text": "応答の目印", "unexpected": NaN}']
)
def test_parse_x_draft_rejects_invalid_json_and_non_objects(response):
    from shipcast.draft import parse_x_draft

    draft, errors = parse_x_draft(response)
    assert draft is None
    assert len(errors) == 1
    assert errors[0].startswith("応答: ")
    assert "応答の目印" not in errors[0]


@pytest.mark.parametrize(
    ("changes", "field"),
    [
        ({"text": None}, "text"),
        ({"text": " "}, "text"),
        ({"text": "\r応答の目印"}, "text"),
        ({"text": "応答の目印\x00"}, "text"),
        ({"text": "応答の目印 HTTPS://demo.example"}, "text"),
        ({"text": "応答の目印 http://demo.example"}, "text"),
        ({"text": "応答の目印 @demo"}, "text"),
        ({"text": "\ud800"}, "text"),
        ({"hashtags": "応答の目印"}, "hashtags"),
        ({"hashtags": ["#いち", "#に", "#さん", "#よん"]}, "hashtags"),
        ({"hashtags": [1]}, "hashtags[0]"),
        ({"hashtags": ["応答の目印"]}, "hashtags[0]"),
        ({"hashtags": ["#応答の目印 空白"]}, "hashtags[0]"),
        ({"hashtags": ["#123"]}, "hashtags[0]"),
        ({"hashtags": ["#応答の目印", " #応答の目印 "]}, "hashtags[1]"),
        ({"hashtags": ["#\ud800"]}, "hashtags[0]"),
    ],
)
def test_parse_x_draft_rejects_invalid_fields_without_echo(changes, field):
    from shipcast.draft import parse_x_draft

    draft, errors = parse_x_draft(json.dumps({"text": "本文", **changes}))
    assert draft is None
    assert errors and all(error.startswith(f"{field}: ") for error in errors)
    assert all("応答の目印" not in error for error in errors)
    if "\\ud800" in json.dumps(changes):
        assert any("UTF-8" in error for error in errors)


@pytest.mark.parametrize("retry", [False, True])
def test_compose_x_sends_only_story_outline_and_retries_invalid_response(retry):
    from shipcast.draft import XDraft, compose_x

    calls = []

    def respond(prompt, system, want_json):
        calls.append((json.loads(prompt), system, want_json))
        if retry and len(calls) == 1:
            return '{"text": "\\ud800"}'
        return '{"text": "見本を作りました。", "hashtags": ["#shipcast"]}'

    draft = compose_x([_story()], _fake_route(respond), repo_id=REPO, day=DAY)
    assert draft == XDraft("見本を作りました。", ("#shipcast",))
    prompt = {
        "repo": REPO,
        "date": "2026-11-26",
        "stories": [{"title": "架空の話題", "what": "見本を作成", "why": "動作を確認"}],
    }
    resource = files("shipcast").joinpath("prompts", "x.md").read_text(encoding="utf-8")
    assert redact(resource) == resource
    system = f"{resource}\n\n{JSON_INSTRUCTION}"
    assert calls[0] == (prompt, system, True)
    assert len(calls) == 1 + retry
    if retry:
        errors = calls[1][0]["previous_errors"]
        assert errors == ["text: UTF-8に変換できる文字列にしてください"]
        assert calls[1] == ({**prompt, "previous_errors": errors}, system, True)


def test_compose_x_reports_only_last_errors_after_two_attempts():
    from shipcast.draft import XDraftFailed, compose_x

    responses = iter(['{"text": ""}', '{"text": "応答の目印", "hashtags": ["数字"]}'])
    calls = []

    def respond(prompt, *_):
        calls.append(json.loads(prompt))
        return next(responses)

    with pytest.raises(XDraftFailed) as captured:
        compose_x([_story()], _fake_route(respond), repo_id=REPO, day=DAY)
    assert captured.value.attempts == len(calls) == 2
    assert len(captured.value.errors) == 1
    assert captured.value.errors[0].startswith("hashtags[0]: ")
    assert "応答の目印" not in str(captured.value)
    assert str(captured.value).startswith("書き手の応答が2回とも決まった形になりませんでした：")


def test_compose_x_does_not_call_writer_for_empty_stories_or_retry_route_errors():
    from shipcast.draft import compose_x

    failure = RouteError("架空の失敗")
    calls = []

    def respond(*args):
        calls.append(args)
        raise failure

    route = _fake_route(respond)
    with pytest.raises(ValueError):
        compose_x([], route, repo_id=REPO, day=DAY)
    assert calls == []
    with pytest.raises(RouteError) as captured:
        compose_x([_story()], route, repo_id=REPO, day=DAY)
    assert captured.value is failure
    assert len(calls) == 1
