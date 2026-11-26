import json
import subprocess
from collections.abc import Mapping
from dataclasses import dataclass
from pathlib import Path

import pytest

from shipcast import models
from shipcast.config import ModelConfig
from shipcast.models import agent_markers, in_agent_context


class UnreadableKeys(Mapping):
    def __iter__(self):
        raise RuntimeError("unreadable keys")

    def __len__(self):
        return 1

    def __getitem__(self, key):
        raise AssertionError("unreadable keys have no values")


class UnreadableValues(Mapping):
    def __iter__(self):
        return iter(("AI_AGENT",))

    def __len__(self):
        return 1

    def __getitem__(self, key):
        raise RuntimeError("unreadable value")


@pytest.mark.parametrize(
    ("env", "expected"),
    [
        ({"CLAUDECODE": ""}, ("CLAUDECODE",)),
        ({"AI_AGENT": "DUMMY"}, ("AI_AGENT",)),
        ({"ORCA_AGENT_SESSION_ID": ""}, ("ORCA_AGENT_SESSION_ID",)),
        ({"CODEX_THREAD_ID": ""}, ("CODEX_THREAD_ID",)),
        (
            {"CODEX_OTHER": "DUMMY", "AI_AGENT": "", "CLAUDECODE": ""},
            ("AI_AGENT", "CLAUDECODE", "CODEX_OTHER"),
        ),
        ({"HOME": "/example", "CODEX": "", "X_CODEX_THREAD_ID": ""}, ()),
        ([], ("<環境を読めない>",)),
        ([("HOME", "/example")], ("<環境を読めない>",)),
        (UnreadableKeys(), ("<環境を読めない>",)),
        (UnreadableValues(), ("AI_AGENT",)),
    ],
)
def test_agent_markers(env, expected):
    assert agent_markers(env) == expected
    assert in_agent_context(env) is bool(expected)


@pytest.fixture(autouse=True)
def reject_real_subprocess(monkeypatch):
    def reject(*args, **kwargs):
        pytest.fail("subprocess.run must be replaced by a test double")

    monkeypatch.setattr(subprocess, "run", reject)


def test_fake_is_deterministic():
    route = models.get_route(ModelConfig("fake", "demo", None, None), env={})

    assert isinstance(route, models.GuardedRoute)
    assert (route.name, route.model) == ("fake", "demo")
    instruction = "Return only one JSON value. Do not add code fences or any other text."
    result = route.complete("本文", system="指示", want_json=True)
    assert result == route.complete("本文", system="指示", want_json=True)
    assert json.loads(result) == {
        "model": "demo",
        "prompt": "本文",
        "route": "fake",
        "system": f"指示\n\n{instruction}",
        "want_json": True,
    }


def test_fake_returns_responder_text_verbatim():
    def respond(prompt, system, want_json):
        assert (prompt, system, want_json) == ("本文", "", False)
        return "  応答\n"

    route = models.get_route(ModelConfig("fake", "demo", None, None), env={}, responder=respond)

    assert route.complete("本文") == "  応答\n"


def test_unknown_route_names_allowed_routes():
    with pytest.raises(models.UnknownRoute) as exc:
        models.get_route(ModelConfig("gemini", "demo", None, None))
    assert exc.value.route == "gemini"
    for name in ("antigravity", "claude", "codex", "fake"):
        assert name in str(exc.value)


@pytest.mark.parametrize("timeout", [0, -1, float("inf"), float("nan"), None, "600"])
def test_get_route_rejects_invalid_timeout(timeout):
    with pytest.raises(ValueError):
        models.get_route(ModelConfig("fake", "demo", None, None), timeout=timeout)


@pytest.mark.parametrize("name", ["antigravity", "claude", "codex"])
def test_get_route_rejects_responder_outside_fake(name):
    with pytest.raises(ValueError):
        models.get_route(ModelConfig(name, "demo", None, None), responder=lambda *_: "")


@pytest.mark.parametrize("stdin", [None, "本文"])
def test_run_subprocess_passes_options(monkeypatch, tmp_path, stdin):
    calls = []

    def process(argv, **kwargs):
        calls.append((argv, kwargs))
        return subprocess.CompletedProcess(argv, 7, "本文", "診断")

    monkeypatch.setattr(subprocess, "run", process)
    env = {"HOME": "/example"}
    result = models.run_subprocess(
        ("example-command", "--demo"), stdin=stdin, cwd=tmp_path, env=env, timeout=12.5
    )
    input_options = {"stdin": subprocess.DEVNULL} if stdin is None else {"input": stdin}
    assert calls == [
        (
            ["example-command", "--demo"],
            {
                **input_options,
                "capture_output": True,
                "text": True,
                "encoding": "utf-8",
                "errors": "replace",
                "cwd": tmp_path,
                "env": env,
                "timeout": 12.5,
                "check": False,
            },
        )
    ]
    assert calls[0][1]["env"] is not env
    assert result == models.Completed(7, "本文", "診断")


def test_run_subprocess_propagates_timeout(monkeypatch, tmp_path):
    timeout = subprocess.TimeoutExpired("example-command", 12.5)

    def process(*args, **kwargs):
        raise timeout

    monkeypatch.setattr(subprocess, "run", process)
    with pytest.raises(subprocess.TimeoutExpired) as exc:
        models.run_subprocess(["example-command"], stdin=None, cwd=tmp_path, env={}, timeout=12.5)
    assert exc.value is timeout


@pytest.mark.parametrize("command", ["agy", "/example/bin/agy"])
def test_run_subprocess_refuses_agy_using_real_environment(monkeypatch, tmp_path, command):
    for key in models.agent_markers(models.os.environ):
        monkeypatch.delenv(key, raising=False)
    monkeypatch.setenv("AI_AGENT", "DUMMY")
    with pytest.raises(models.RouteRefused) as exc:
        models.run_subprocess([command, "-p", "本文"], stdin=None, cwd=tmp_path, env={}, timeout=1)
    assert exc.value.route == "antigravity"
    assert exc.value.markers == ("AI_AGENT",)
    assert "DUMMY" not in str(exc.value)


def unexpected_call(*args, **kwargs):
    pytest.fail("route must not call the runner or responder")


@pytest.mark.parametrize(
    "marker", ["CLAUDECODE", "AI_AGENT", "ORCA_AGENT_SESSION_ID", "CODEX_THREAD_ID"]
)
@pytest.mark.parametrize("value", ["", "DUMMY_AGENT_VALUE"])
def test_antigravity_refuses_agent_environment(marker, value):
    route = models.get_route(
        ModelConfig("antigravity", "demo", None, None),
        env={marker: value},
        runner=unexpected_call,
    )
    with pytest.raises(models.RouteRefused) as exc:
        route.complete("本文")
    assert exc.value.route == "antigravity"
    assert exc.value.markers == (marker,)
    assert marker in str(exc.value)
    assert "DUMMY_AGENT_VALUE" not in str(exc.value)


@pytest.mark.parametrize("env", [[], [("HOME", "/example")], UnreadableKeys(), UnreadableValues()])
@pytest.mark.parametrize("name", ["antigravity", "claude", "codex", "fake"])
def test_complete_fails_closed_when_environment_cannot_be_copied(name, env):
    route = models.get_route(
        ModelConfig(name, "demo", None, None),
        env=env,
        runner=unexpected_call,
        responder=unexpected_call if name == "fake" else None,
    )
    if name == "antigravity":
        with pytest.raises(models.RouteRefused) as exc:
            route.complete("本文")
        assert exc.value.markers == ("<環境を読めない>",)
    else:
        with pytest.raises(models.RouteFailed) as exc:
            route.complete("本文")
        assert exc.value.returncode is None
        assert exc.value.reason == "環境を読めない"
    assert exc.value.route == name


@pytest.mark.parametrize(("prompt", "system"), [(None, ""), ("本文", 42)])
def test_complete_checks_types_before_reading_environment(prompt, system):
    route = models.get_route(
        ModelConfig("antigravity", "demo", None, None),
        env=UnreadableKeys(),
        runner=unexpected_call,
    )
    with pytest.raises(TypeError):
        route.complete(prompt, system=system)


@pytest.mark.parametrize("name", ["antigravity", "claude", "codex", "fake"])
@pytest.mark.parametrize("fail_on", ["本文", "指示"])
def test_complete_propagates_redaction_failure(monkeypatch, name, fail_on):
    failure = ValueError("redaction failed")
    calls = []

    def redact(text):
        calls.append(text)
        if text == fail_on:
            raise failure
        return text

    monkeypatch.setattr(models, "redact", redact)
    route = models.get_route(
        ModelConfig(name, "demo", None, None),
        env={},
        runner=unexpected_call,
        responder=unexpected_call if name == "fake" else None,
    )
    with pytest.raises(ValueError) as exc:
        route.complete("本文", system="指示")
    assert exc.value is failure
    assert calls == (["本文"] if fail_on == "本文" else ["本文", "指示"])


@dataclass
class Invocation:
    argv: list[str]
    stdin: str | None
    cwd: Path
    env: Mapping[str, str]
    timeout: float


class RecordingRunner:
    def __init__(self, *, completed=None, failure=None, codex_file=b"  file response\n"):
        self.calls = []
        self.completed = completed
        self.failure = failure
        self.codex_file = codex_file

    def __call__(self, argv, *, stdin, cwd, env, timeout):
        assert cwd.name == "work"
        assert list(cwd.iterdir()) == []
        self.calls.append(Invocation(list(argv), stdin, cwd, env, timeout))
        if self.failure is not None:
            raise self.failure
        if argv[0] == "codex" and self.codex_file is not None:
            output = Path(argv[argv.index("--output-last-message") + 1])
            assert output == cwd.parent / "last-message.txt"
            output.write_bytes(self.codex_file)
        if self.completed is not None:
            return self.completed
        if argv[0] == "agy":
            return models.Completed(
                0, 'progress\n{"status":"SUCCESS","response":"  JSON response\\n"}\n \n', ""
            )
        return models.Completed(0, "  stdout response\n", "")


@pytest.mark.parametrize("effort", [None, "low"])
def test_codex_invocation(effort):
    runner = RecordingRunner()
    env = {"HOME": "/example", "AI_AGENT": ""}
    route = models.get_route(ModelConfig("codex", "demo", effort, "high"), env=env, runner=runner)
    assert (route.name, route.model) == ("codex", "demo")
    assert isinstance(route, models.GuardedRoute)
    assert route.complete("本文", system="指示", want_json=True) == "  file response\n"
    (call,) = runner.calls
    assert call.argv == [
        "codex",
        "exec",
        "--model",
        "demo",
        *(["-c", "model_reasoning_effort=low"] if effort else []),
        "--disable",
        "shell_tool",
        "--disable",
        "unified_exec",
        "--disable",
        "view_image",
        "--disable",
        "plugins",
        "--sandbox",
        "read-only",
        "--skip-git-repo-check",
        "--ephemeral",
        "--ignore-user-config",
        "--ignore-rules",
        "--color",
        "never",
        "--cd",
        str(call.cwd),
        "--output-last-message",
        str(call.cwd.parent / "last-message.txt"),
        "-",
    ]
    assert call.stdin == (
        "指示\n\nReturn only one JSON value. Do not add code fences or any other text."
        "\n\n---\n\n本文"
    )
    assert call.env == env
    assert call.env is not env
    assert call.timeout == 600.0
    assert not call.cwd.parent.exists()


@pytest.mark.parametrize(("effort", "system"), [(None, ""), ("low", "指示")])
def test_claude_invocation(effort, system):
    env = {"HOME": "/example", "CLAUDECODE": ""}
    runner = RecordingRunner()
    route = models.get_route(
        ModelConfig("claude", "demo", effort, "high"), env=env, runner=runner, timeout=12.5
    )
    assert isinstance(route, models.GuardedRoute)
    assert (route.name, route.model) == ("claude", "demo")
    assert route.complete("本文", system=system) == "  stdout response\n"
    (call,) = runner.calls
    assert call.argv == [
        "claude",
        "-p",
        "--model",
        "demo",
        *(["--effort", "low"] if effort else []),
        "--output-format",
        "text",
        "--no-session-persistence",
        "--strict-mcp-config",
        "--disable-slash-commands",
        *(["--system-prompt", system] if system else []),
        "--tools",
        "",
    ]
    assert call.stdin == "本文"
    assert call.env == env
    assert call.timeout == 12.5
    assert not call.cwd.parent.exists()


@pytest.mark.parametrize(
    ("thinking", "slug"), [(None, "gemini-4-neon"), ("high", "gemini-4-neon-high")]
)
def test_antigravity_invocation(thinking, slug):
    env = {"HOME": "/example"}
    runner = RecordingRunner()
    route = models.get_route(
        ModelConfig("antigravity", "gemini-4-neon", "low", thinking), env=env, runner=runner
    )
    assert isinstance(route, models.GuardedRoute)
    assert (route.name, route.model) == ("antigravity", "gemini-4-neon")
    assert route.complete("本文", system="指示") == "  JSON response\n"
    (call,) = runner.calls
    assert call.argv == [
        "agy",
        "-p",
        "指示\n\n---\n\n本文",
        "--output-format",
        "json",
        "--model",
        slug,
        "--mode",
        "plan",
        "--sandbox",
        "--disable-slash-commands",
    ]
    assert call.stdin is None
    assert call.env == env
    assert not call.cwd.parent.exists()


def test_antigravity_checks_environment_on_every_call(monkeypatch):
    live_env = {"HOME": "/example"}
    runner = RecordingRunner()
    monkeypatch.setattr(models.os, "environ", {"AI_AGENT": ""})
    route = models.get_route(ModelConfig("antigravity", "demo", None, None), runner=runner)
    monkeypatch.setattr(models.os, "environ", live_env)
    route.complete("本文")

    live_env["CODEX_THREAD_ID"] = ""
    with pytest.raises(models.RouteRefused) as exc:
        route.complete("本文")
    assert exc.value.markers == ("CODEX_THREAD_ID",)
    (call,) = runner.calls
    assert call.env == {"HOME": "/example"}


@pytest.mark.parametrize("name", ["antigravity", "claude", "codex", "fake"])
def test_each_route_receives_only_redacted_input(name):
    prompt_secret = "ghp_" + "DUMMYEXAMPLE" * 2
    system_secret = "sk-" + "DUMMY_EXAMPLE_0000"
    response_calls = []

    def respond(*args):
        response_calls.append(args)
        return "応答"

    runner = RecordingRunner()
    route = models.get_route(
        ModelConfig(name, "demo", None, None),
        runner=runner,
        env={"AI_AGENT": ""} if name == "fake" else {},
        responder=respond if name == "fake" else None,
    )
    route.complete(f"本文 {prompt_secret}", system=f"指示 {system_secret}")
    if name == "fake":
        assert response_calls == [("本文 [伏せた]", "指示 [伏せた]", False)]
        assert not runner.calls
    else:
        (call,) = runner.calls
        sent = "\n".join([*call.argv, call.stdin or ""])
        assert "本文 [伏せた]" in sent
        assert "指示 [伏せた]" in sent
        assert prompt_secret not in sent
        assert system_secret not in sent


@pytest.mark.parametrize("normal_lines", [125, 180])
def test_nonzero_exit_redacts_stderr_before_keeping_the_tail(normal_lines):
    secret = "ghp_" + "DUMMYEXAMPLE" * 2
    stderr = "PASSWORD=" + "DUMMY" * 450 + f"\n{secret}\n" + "normal line\n" * normal_lines + "end"
    runner = RecordingRunner(completed=models.Completed(1, "partial response", stderr))
    route = models.get_route(ModelConfig("claude", "demo", None, None), env={}, runner=runner)

    with pytest.raises(models.RouteFailed) as exc:
        route.complete("本文")
    error = exc.value
    assert (error.route, error.returncode, error.timed_out) == ("claude", 1, False)
    assert "終了コード" in error.reason
    expected = ("PASSWORD=[伏せた]\n[伏せた]\n" + "normal line\n" * normal_lines + "end")[-2000:]
    assert error.stderr_tail == expected
    assert len(error.stderr_tail) <= 2000
    assert "DUMMY" not in error.stderr_tail


def test_failure_discards_stderr_if_its_redaction_fails(monkeypatch):
    failure = "PASSWORD=DUMMY_EXAMPLE"

    def redact(text):
        if text == failure:
            raise ValueError("redaction failed")
        return text

    monkeypatch.setattr(models, "redact", redact)
    runner = RecordingRunner(completed=models.Completed(1, "", failure))
    route = models.get_route(ModelConfig("claude", "demo", None, None), env={}, runner=runner)
    with pytest.raises(models.RouteFailed) as exc:
        route.complete("本文")
    assert exc.value.stderr_tail == ""


@pytest.mark.parametrize(
    ("failure", "timed_out", "reason"),
    [
        (
            subprocess.TimeoutExpired("example-command", 1, stderr=b"PASSWORD=DUMMY"),
            True,
            "時間切れ",
        ),
        (FileNotFoundError("example-command"), False, "起動"),
        (ValueError("embedded null byte"), False, "起動"),
        (subprocess.SubprocessError("DUMMY"), False, "起動"),
    ],
)
def test_runner_errors_have_safe_reason_and_original_cause(failure, timed_out, reason):
    runner = RecordingRunner(failure=failure)
    route = models.get_route(ModelConfig("claude", "demo", None, None), env={}, runner=runner)
    with pytest.raises(models.RouteFailed) as exc:
        route.complete("本文")
    error = exc.value
    assert (error.route, error.returncode, error.timed_out) == ("claude", None, timed_out)
    assert reason in error.reason
    assert error.__cause__ is failure
    assert "DUMMY" not in error.stderr_tail
    if timed_out:
        assert error.stderr_tail == "PASSWORD=[伏せた]"
    assert not runner.calls[0].cwd.parent.exists()


def test_route_refusal_from_runner_is_preserved():
    failure = models.RouteRefused("antigravity", markers=("AI_AGENT",))
    runner = RecordingRunner(failure=failure)
    route = models.get_route(ModelConfig("antigravity", "demo", None, None), env={}, runner=runner)
    with pytest.raises(models.RouteRefused) as exc:
        route.complete("本文")
    assert exc.value is failure


def test_claude_rejects_blank_stdout():
    runner = RecordingRunner(completed=models.Completed(0, " \n\t", "diagnostic"))
    route = models.get_route(ModelConfig("claude", "demo", None, None), env={}, runner=runner)
    with pytest.raises(models.RouteFailed) as exc:
        route.complete("本文")
    assert (exc.value.route, exc.value.returncode, exc.value.timed_out) == ("claude", 0, False)
    assert "空" in exc.value.reason
    assert exc.value.stderr_tail == "diagnostic"


@pytest.mark.parametrize(
    ("content", "cause"),
    [(None, FileNotFoundError), (b"\xff", UnicodeDecodeError)],
)
def test_codex_rejects_missing_or_invalid_utf8_file(content, cause):
    runner = RecordingRunner(codex_file=content)
    route = models.get_route(ModelConfig("codex", "demo", None, None), env={}, runner=runner)
    with pytest.raises(models.RouteFailed) as exc:
        route.complete("本文")
    assert (exc.value.route, exc.value.returncode, exc.value.timed_out) == ("codex", 0, False)
    assert "応答" in exc.value.reason
    assert isinstance(exc.value.__cause__, cause)
    assert not runner.calls[0].cwd.parent.exists()


def test_codex_preserves_carriage_return_in_response_file():
    runner = RecordingRunner(codex_file=b"  response\r\n")
    route = models.get_route(ModelConfig("codex", "demo", None, None), env={}, runner=runner)
    assert route.complete("本文") == "  response\r\n"


@pytest.mark.parametrize(
    "stdout",
    [
        " \n\t",
        "progress only",
        "[]",
        '"text"',
        '{"response":"text"}',
        '{"status":"SUCCESS","response":""}',
        '{"status":"SUCCESS","response":"  "}',
        '{"status":"SUCCESS","response":123}',
        '{"status":"ERROR","response":"partial response"}',
    ],
)
def test_antigravity_rejects_invalid_final_response(stdout):
    runner = RecordingRunner(completed=models.Completed(0, stdout, ""))
    route = models.get_route(ModelConfig("antigravity", "demo", None, None), env={}, runner=runner)
    with pytest.raises(models.RouteFailed) as exc:
        route.complete("本文")
    assert (exc.value.route, exc.value.returncode, exc.value.timed_out) == ("antigravity", 0, False)
    assert "応答" in exc.value.reason


def test_antigravity_failure_includes_status_and_redacted_bounded_error():
    token = "ghp_" + "DUMMYEXAMPLE" * 2
    output = json.dumps({"status": "ERROR", "error": f"{token} " + "E" * 600})
    runner = RecordingRunner(completed=models.Completed(0, output, ""))
    route = models.get_route(ModelConfig("antigravity", "demo", None, None), env={}, runner=runner)
    with pytest.raises(models.RouteFailed) as exc:
        route.complete("本文")
    reason = exc.value.reason
    assert "ERROR" in reason
    assert ("[伏せた] " + "E" * 494) in reason
    assert "E" * 495 not in reason
    assert token not in reason


@pytest.mark.parametrize(("response", "reason"), [(None, "文字列"), (" \t", "空")])
def test_fake_rejects_invalid_response(response, reason):
    route = models.get_route(
        ModelConfig("fake", "demo", None, None), env={}, responder=lambda *_: response
    )
    with pytest.raises(models.RouteFailed) as exc:
        route.complete("本文")
    assert (exc.value.route, exc.value.returncode, exc.value.timed_out) == ("fake", None, False)
    assert reason in exc.value.reason


def test_fake_preserves_responder_exception():
    failure = ValueError("responder failed")

    def respond(*args):
        raise failure

    route = models.get_route(ModelConfig("fake", "demo", None, None), env={}, responder=respond)
    with pytest.raises(ValueError) as exc:
        route.complete("本文")
    assert exc.value is failure


def test_antigravity_measures_final_redacted_prompt_in_utf8():
    runner = RecordingRunner()
    route = models.get_route(ModelConfig("antigravity", "demo", None, None), env={}, runner=runner)
    expected_prefix = (
        "指示\n\nReturn only one JSON value. Do not add code fences or any other text.\n\n---\n\n"
    )
    text_budget = 200_000 - len(expected_prefix.encode("utf-8"))
    count, remainder = divmod(text_budget, len("日".encode()))
    at_limit = "日" * count + "a" * remainder

    with pytest.raises(models.RouteFailed) as exc:
        route.complete(at_limit + "a", system="指示", want_json=True)
    assert exc.value.route == "antigravity"
    assert exc.value.returncode is None
    assert "200001" in exc.value.reason
    assert "200000" in exc.value.reason
    assert not runner.calls

    route.complete(at_limit, system="指示", want_json=True)
    (call,) = runner.calls
    assert call.argv[2] == expected_prefix + at_limit
    assert len(call.argv[2].encode("utf-8")) == 200_000


@pytest.mark.parametrize("name", ["claude", "codex", "fake"])
def test_other_routes_do_not_limit_prompt_size(name):
    runner = RecordingRunner()
    prompt = "日" * 70_000
    route = models.get_route(ModelConfig(name, "demo", None, None), env={}, runner=runner)
    response = route.complete(prompt)
    if name == "fake":
        assert json.loads(response)["prompt"] == prompt
        assert not runner.calls
    else:
        (call,) = runner.calls
        assert call.stdin == prompt


def test_antigravity_rejects_prompt_that_cannot_be_encoded_in_utf8():
    runner = RecordingRunner()
    route = models.get_route(ModelConfig("antigravity", "demo", None, None), env={}, runner=runner)
    with pytest.raises(models.RouteFailed) as exc:
        route.complete("\ud800")
    assert exc.value.returncode is None
    assert "UTF-8" in exc.value.reason
    assert isinstance(exc.value.__cause__, UnicodeEncodeError)
    assert not runner.calls


def test_antigravity_keeps_unicode_line_separator_inside_json_response():
    response = "本文\u2028続き"
    final_line = json.dumps({"status": "SUCCESS", "response": response}, ensure_ascii=False)
    runner = RecordingRunner(completed=models.Completed(0, f"progress\n{final_line}\n", ""))
    route = models.get_route(ModelConfig("antigravity", "demo", None, None), env={}, runner=runner)
    assert route.complete("本文") == response
