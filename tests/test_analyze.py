import json
from importlib.resources import files

import pytest

from shipcast.model import Neta


def story_response(**changes):
    return {
        "title": "表示の改善",
        "what": "一覧を追加した",
        "why": "進捗を見つけやすくするため",
        "neta": {"score": 0},
        "event_ids": ["sample-a"],
        **changes,
    }


def response_text(*stories):
    return json.dumps({"stories": stories})


def test_parse_stories_preserves_order_and_defaults():
    from shipcast.analyze import parse_stories

    raw = response_text(
        story_response(
            notice=["表示順が変わる"],
            waiting=["見た目の確認"],
            neta={"score": 2, "reason": "変化が見える", "channels": ["x"], "extra": 1},
            event_ids=["sample-c", "sample-a"],
            extra="無視する値",
        ),
        story_response(title="補足", event_ids=["sample-b"]),
    )
    stories, errors = parse_stories(
        f"  \n```json\n{raw}\n``` \n", event_ids=["sample-a", "sample-b", "sample-c"]
    )
    assert errors == []
    assert stories == [
        {
            "title": "表示の改善",
            "what": "一覧を追加した",
            "why": "進捗を見つけやすくするため",
            "notice": ("表示順が変わる",),
            "waiting": ("見た目の確認",),
            "neta": Neta(2, "変化が見える", ("x",)),
            "event_ids": ("sample-c", "sample-a"),
        },
        {
            "title": "補足",
            "what": "一覧を追加した",
            "why": "進捗を見つけやすくするため",
            "notice": (),
            "waiting": (),
            "neta": Neta(0),
            "event_ids": ("sample-b",),
        },
    ]


MARKER = "fictional-response-marker"


@pytest.mark.parametrize(
    ("raw", "location"),
    [
        (MARKER, "応答"),
        ("", "応答"),
        ("[" * 10000 + "0" + "]" * 10000, "応答"),
        ("[]", "応答"),
        ("{}", "stories"),
        ('{"stories": {}}', "stories"),
        (response_text(), "stories"),
        (response_text(MARKER), "stories[0]"),
        (response_text({}), "stories[0].what"),
        (response_text(story_response(what=" \t")), "stories[0].what"),
        (response_text(story_response(what=1)), "stories[0].what"),
        (response_text(story_response(notice=MARKER)), "stories[0].notice"),
        (response_text(story_response(waiting=[1])), "stories[0].waiting"),
        (response_text({}), "stories[0].neta"),
        *[
            (response_text(story_response(neta={"score": score})), "stories[0].neta.score")
            for score in (-1, 4, 1.5, "2", True)
        ],
        (
            response_text(story_response(neta={"score": 0, "channels": [1]})),
            "stories[0].neta.channels",
        ),
        (response_text(story_response(event_ids=[])), "stories[0].event_ids"),
        (response_text(story_response(event_ids=[MARKER])), "stories[0].event_ids"),
        (
            response_text(story_response(event_ids=["sample-a", "sample-a"])),
            "stories[0].event_ids",
        ),
        (response_text(story_response(), story_response()), "stories[1].event_ids"),
        (response_text(story_response(title="\ud800")), "stories[0].title"),
        (response_text(story_response(notice=["\ud800"])), "stories[0].notice"),
        (
            response_text(story_response(neta={"score": 0, "reason": "\ud800"})),
            "stories[0].neta.reason",
        ),
    ],
)
def test_parse_stories_rejects_invalid_response(raw, location):
    from shipcast.analyze import parse_stories

    stories, errors = parse_stories(raw, event_ids={"sample-a"})

    assert stories == []
    assert any(error.startswith(f"{location}:") for error in errors)
    assert all(MARKER not in error for error in errors)


def test_parse_stories_caps_errors():
    from shipcast.analyze import parse_stories

    stories, errors = parse_stories(response_text(*([MARKER] * 30)), event_ids={"sample-a"})

    assert stories == []
    assert len(errors) == 21
    assert errors[-1] == "ほかにも誤りがあります"
    assert all(MARKER not in error for error in errors)


def test_analyze_prompt_is_packaged_with_required_instructions():
    prompt = (files("shipcast") / "prompts" / "analyze.md").read_text(encoding="utf-8")
    for word in (
        "ネタポイント",
        "変化の大きさ",
        "読者への価値",
        "見せやすさ",
        "previous_errors",
        "event_ids",
        "stories",
    ):
        assert word in prompt
