import json
import os
from concurrent.futures import ThreadPoolExecutor
from datetime import date, datetime
from importlib.resources import files
from threading import Event

import pytest

from shipcast.config import ModelConfig
from shipcast.model import ModelError, Neta, Story
from shipcast.models import JSON_INSTRUCTION, RouteError, get_route
from shipcast.redact import redact
from shipcast.state import Store

DAY = date(2026, 11, 26)
NOW = datetime.fromisoformat("2026-11-26T22:00:00+09:00")
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


def _reply(*_):
    return '{"text": "見本", "hashtags": ["#shipcast"]}'


def _unexpected_reply(*_):
    pytest.fail("書き手を呼んではいけません")


def test_make_x_draft_saves_top_three_and_consumes_only_those_stories(tmp_path):
    from shipcast.draft import XDraft, make_x_draft

    selected = (
        _story("first", score=3, title=" 第一の\n 話題 "),
        _story("second", score=2, title="第二の話題"),
        _story("third", title="第三の話題"),
    )
    leftover = _story("fourth")
    unrelated = _story("other", repo_id="demo-lib", score=3)
    calls = []

    def respond(prompt, *_):
        calls.append(json.loads(prompt))
        return _reply()

    with Store(tmp_path) as store:
        store.save_stories([selected[1], selected[2], selected[0], leftover, unrelated])
        result = make_x_draft(
            store, REPO, DAY, state_dir=tmp_path, writer=_fake_route(respond), now=NOW
        )
        assert result.stories == selected
        assert result.consumed == 3
        assert store.unconsumed_stories(REPO) == [leftover]
        assert store.neta_balance(REPO) == 1
        assert store.unconsumed_stories("demo-lib") == [unrelated]
        assert store.neta_balance("demo-lib") == 3

    assert len(calls) == 1
    assert [story["title"] for story in calls[0]["stories"]] == [story.title for story in selected]
    assert result.draft == XDraft("見本", ("#shipcast",))
    assert result.path == tmp_path / "drafts" / REPO / "2026-11-26-x.md"
    assert (
        result.path.read_text(encoding="utf-8")
        == """\
# Xの下書き（demo-app 2026-11-26）

:::note
shipcastは投稿しません。内容を確かめてから、本人が投稿してください。
:::

## 投稿の本文

見本

#shipcast

## 確かめること

- 長さ：Xの数え方で 15 / 280
- ハッシュタグの案：#shipcast
- 書き手：fake/fake-writer
- 作った時刻：2026-11-26T22:00:00+09:00

## 使った話題

- 第一の 話題
- 第二の話題
- 第三の話題
"""
    )


def test_make_x_draft_preserves_existing_file_and_unconsumed_stories(tmp_path):
    from shipcast.draft import DraftExists, make_x_draft

    target = tmp_path / "drafts" / REPO / "2026-11-26-x.md"
    target.parent.mkdir(parents=True)
    target.write_text("以前の下書き\n", encoding="utf-8")
    with Store(tmp_path) as store:
        story = _story()
        store.save_stories([story])
        with pytest.raises(DraftExists) as captured:
            make_x_draft(
                store, REPO, DAY, state_dir=tmp_path, writer=_fake_route(_unexpected_reply), now=NOW
            )
        assert captured.value.path == target
        assert store.neta_balance(REPO) == 1
        assert store.unconsumed_stories(REPO) == [story]
    assert target.read_text(encoding="utf-8") == "以前の下書き\n"


def test_make_x_draft_has_no_output_without_unconsumed_stories(tmp_path):
    from shipcast.draft import NoStories, make_x_draft

    with Store(tmp_path) as store:
        store.save_stories([_story(score=0), _story("other", repo_id="demo-lib")])
        with pytest.raises(NoStories) as captured:
            make_x_draft(
                store, REPO, DAY, state_dir=tmp_path, writer=_fake_route(_unexpected_reply), now=NOW
            )
        assert captured.value.repo_id == REPO
    assert not (tmp_path / "drafts" / REPO / "2026-11-26-x.md").exists()


@pytest.mark.parametrize("stage", ["writer", "write"])
def test_make_x_draft_leaves_stories_unconsumed_after_failure(stage, tmp_path, monkeypatch):
    from shipcast import write
    from shipcast.draft import XDraftFailed, make_x_draft

    target = tmp_path / "drafts" / REPO / "2026-11-26-x.md"
    error = OSError("架空の保存失敗")

    def fail_replace(*_):
        raise error

    def invalid(*_):
        return '{"text": ""}'

    with Store(tmp_path) as store:
        story = _story(score=2)
        store.save_stories([story])
        with monkeypatch.context() as patch:
            if stage == "write":
                patch.setattr(write.os, "replace", fail_replace)
            with pytest.raises(XDraftFailed if stage == "writer" else OSError) as captured:
                make_x_draft(
                    store,
                    REPO,
                    DAY,
                    state_dir=tmp_path,
                    writer=_fake_route(invalid if stage == "writer" else _reply),
                    now=NOW,
                )

        if stage == "write":
            assert captured.value is error
            assert list(target.parent.iterdir()) == []
        else:
            assert captured.value.attempts == 2
        assert not target.exists()
        assert store.neta_balance(REPO) == 2
        assert store.unconsumed_stories(REPO) == [story]


@pytest.mark.parametrize(("repo", "day"), [("../demo-app", DAY), (REPO, NOW)])
def test_draft_path_rejects_invalid_repo_and_day(tmp_path, repo, day):
    from shipcast.draft import draft_path

    assert draft_path(str(tmp_path), REPO, DAY) == tmp_path / "drafts" / REPO / "2026-11-26-x.md"
    with pytest.raises(ModelError):
        draft_path(tmp_path, repo, day)


@pytest.fixture
def draft_cli(tmp_path, monkeypatch):
    from shipcast import draft

    config = tmp_path / "config.toml"
    state = tmp_path / "state"
    config.write_text(
        f"""\
timezone = "Asia/Tokyo"
state_dir = "{state}"
journal_dir = "{tmp_path / "journal"}"

[models.analyst]
route = "fake"
model = "fake-analyst"

[models.writer]
route = "fake"
model = "fake-writer"

[[repos]]
id = "{REPO}"
path = "{tmp_path / REPO}"
""",
        encoding="utf-8",
    )
    monkeypatch.setenv("SHIPCAST_CONFIG", str(config))

    def install_responder(responder):
        def fake_writer(model_cfg):
            assert model_cfg.route == "fake" and model_cfg.model == "fake-writer"
            return get_route(model_cfg, env={}, responder=responder)

        monkeypatch.setattr(draft, "get_route", fake_writer)

    return state, install_responder


@pytest.mark.parametrize("use_default_date", [False, True])
def test_cli_draft_x_saves_consumes_and_refuses_duplicate(
    draft_cli, capsys, monkeypatch, use_default_date
):
    from shipcast import draft
    from shipcast.cli import main

    state, install_responder = draft_cli
    with Store(state) as store:
        store.save_stories([_story()])

    class FixedClock(datetime):
        @classmethod
        def now(cls, tz):
            assert tz.key == "Asia/Tokyo"
            return NOW

    monkeypatch.setattr(draft, "datetime", FixedClock)
    argv = ["draft", "x", "--repo", REPO]
    if not use_default_date:
        argv += ["--date", "2026-11-26"]
    install_responder(_reply)
    assert main(argv) == 0
    target = state / "drafts" / REPO / "2026-11-26-x.md"
    output = capsys.readouterr()
    assert output.err == ""
    assert output.out.splitlines() == [
        f"demo-app 2026-11-26: Xの下書きを作りました（話題 1件、Xの数え方で 15 / 280）: {target}",
        "shipcastは投稿しません。内容を確かめてから、本人が投稿してください。",
    ]
    original = target.read_text(encoding="utf-8")
    with Store(state) as store:
        assert store.neta_balance(REPO) == 0

    install_responder(_unexpected_reply)
    assert main(argv) == 1
    output = capsys.readouterr()
    assert output.out == ""
    assert f"shipcast draft x: 同じ日付の下書きがあります: {target}" in output.err
    assert "--date" in output.err
    assert target.read_text(encoding="utf-8") == original


@pytest.mark.parametrize(
    ("repo", "error", "hint"),
    [
        ("unregistered", "登録されていないrepositoryです: unregistered", "shipcast repo list"),
        (REPO, "未消化の話題がありません: demo-app", "shipcast write"),
    ],
)
def test_cli_draft_x_rejects_invalid_repo_or_no_stories(draft_cli, capsys, repo, error, hint):
    from shipcast.cli import main

    state, install_responder = draft_cli
    install_responder(_unexpected_reply)
    assert main(["draft", "x", "--repo", repo, "--date", "2026-11-26"]) == 1
    output = capsys.readouterr()
    assert output.out == ""
    assert f"shipcast draft x: {error}" in output.err
    assert hint in output.err
    assert not (state / "drafts" / repo / "2026-11-26-x.md").exists()


def test_cli_draft_x_reports_invalid_response_and_preserves_stories(draft_cli, capsys):
    from shipcast.cli import main

    state, install_responder = draft_cli
    with Store(state) as store:
        store.save_stories([_story()])
    calls = []

    def invalid(prompt, *_):
        calls.append(json.loads(prompt))
        return '{"text": "応答の目印 @demo"}'

    install_responder(invalid)
    assert main(["draft", "x", "--repo", REPO, "--date", "2026-11-26"]) == 1
    output = capsys.readouterr()
    assert output.out == ""
    assert "shipcast draft x: 失敗: demo-app:" in output.err
    assert "text:" in output.err
    assert "応答の目印" not in output.err
    assert len(calls) == 2 and calls[1]["previous_errors"]
    assert not (state / "drafts" / REPO / "2026-11-26-x.md").exists()
    with Store(state) as store:
        assert store.neta_balance(REPO) == 1


@pytest.mark.parametrize(("args", "code"), [(["--help"], 0), ([], 2)])
def test_cli_draft_x_help_and_required_repo(capsys, args, code):
    from shipcast.cli import main

    with pytest.raises(SystemExit) as captured:
        main(["draft", "x", *args])
    assert captured.value.code == code
    output = capsys.readouterr()
    if code == 0:
        assert "--repo" in output.out and "--date" in output.out
    else:
        assert "--repo" in output.err


@pytest.mark.skipif(os.name != "posix", reason="POSIX のディレクトリロックを使う")
def test_make_x_draft_serializes_concurrent_calls_for_same_day(tmp_path):
    from shipcast.draft import DraftExists, make_x_draft

    first_writing = Event()
    release_first = Event()
    second_started = Event()
    second_writing = Event()

    def first_reply(*_):
        first_writing.set()
        assert release_first.wait(timeout=5)
        return '{"text": "最初の下書き"}'

    def second_reply(*_):
        second_writing.set()
        return '{"text": "次の下書き"}'

    def run(responder, started=None):
        with Store(tmp_path) as store:
            if started is not None:
                started.set()
            return make_x_draft(
                store, REPO, DAY, state_dir=tmp_path, writer=_fake_route(responder), now=NOW
            )

    with Store(tmp_path) as store:
        store.save_stories([_story()])
    with ThreadPoolExecutor(max_workers=2) as pool:
        first = pool.submit(run, first_reply)
        try:
            assert first_writing.wait(timeout=5)
            second = pool.submit(run, second_reply, second_started)
            assert second_started.wait(timeout=5)
            assert not second_writing.wait(timeout=0.2)
        finally:
            release_first.set()
        result = first.result(timeout=5)
        with pytest.raises(DraftExists):
            second.result(timeout=5)

    assert result.consumed == 1
    assert "最初の下書き" in result.path.read_text(encoding="utf-8")
    assert not second_writing.is_set()
