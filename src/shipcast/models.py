"""モデルへの経路と、呼び出し前の守り。"""

import json
import math
import os
import subprocess
import tempfile
from abc import ABC, abstractmethod
from collections.abc import Callable, Mapping, Sequence
from dataclasses import dataclass
from pathlib import Path
from typing import Protocol

from shipcast.config import ModelConfig
from shipcast.redact import redact

ROUTES = ("antigravity", "claude", "codex", "fake")
DEFAULT_TIMEOUT = 600.0
JSON_INSTRUCTION = "Return only one JSON value. Do not add code fences or any other text."
MAX_ARGV_PROMPT_BYTES = 200_000

AGENT_MARKERS = ("CLAUDECODE", "AI_AGENT", "ORCA_AGENT_SESSION_ID")
AGENT_MARKER_PREFIXES = ("CODEX_",)
UNREADABLE_ENV = "<環境を読めない>"


def agent_markers(env: Mapping[str, str]) -> tuple[str, ...]:
    if not isinstance(env, Mapping):
        return (UNREADABLE_ENV,)
    try:
        return tuple(
            sorted(
                key for key in env if key in AGENT_MARKERS or key.startswith(AGENT_MARKER_PREFIXES)
            )
        )
    except Exception:
        return (UNREADABLE_ENV,)


def in_agent_context(env: Mapping[str, str]) -> bool:
    return bool(agent_markers(env))


class RouteError(Exception):
    """モデルの経路で起きた失敗。"""


class UnknownRoute(RouteError):
    def __init__(self, route: str) -> None:
        self.route = route
        super().__init__(f"未知の経路 {route!r}。使える経路は {', '.join(ROUTES)} です")


class RouteRefused(RouteError):
    def __init__(self, route: str, *, markers: tuple[str, ...]) -> None:
        self.route = route
        self.markers = markers
        super().__init__(
            f"エージェントの中では {route} の経路を呼べません（印：{', '.join(markers)}）。"
            "普通の端末か launchd から実行してください"
        )


class RouteFailed(RouteError):
    def __init__(
        self,
        route: str,
        *,
        reason: str,
        returncode: int | None = None,
        stderr_tail: str = "",
        timed_out: bool = False,
    ) -> None:
        self.route = route
        self.returncode = returncode
        self.stderr_tail = stderr_tail
        self.timed_out = timed_out
        self.reason = reason
        super().__init__(f"{route} の経路が失敗しました（{reason}）")


@dataclass(frozen=True)
class Completed:
    returncode: int
    stdout: str
    stderr: str


class Runner(Protocol):
    def __call__(
        self,
        argv: Sequence[str],
        *,
        stdin: str | None,
        cwd: Path,
        env: Mapping[str, str],
        timeout: float,
    ) -> Completed: ...


def run_subprocess(
    argv: Sequence[str],
    *,
    stdin: str | None,
    cwd: Path,
    env: Mapping[str, str],
    timeout: float,
) -> Completed:
    if argv and Path(argv[0]).name == "agy":
        markers = agent_markers(os.environ)
        if markers:
            raise RouteRefused("antigravity", markers=markers)

    input_options = {"stdin": subprocess.DEVNULL} if stdin is None else {"input": stdin}
    result = subprocess.run(
        list(argv),
        **input_options,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
        cwd=cwd,
        env=dict(env),
        timeout=timeout,
        check=False,
    )
    return Completed(result.returncode, result.stdout, result.stderr)


class _Route(Protocol):
    def complete(
        self, prompt: str, system: str, want_json: bool, env: Mapping[str, str]
    ) -> str: ...


@dataclass(frozen=True)
class _FakeRoute:
    model: str
    responder: Callable[[str, str, bool], str] | None

    def complete(self, prompt: str, system: str, want_json: bool, env: Mapping[str, str]) -> str:
        if self.responder is not None:
            return self.responder(prompt, system, want_json)
        return json.dumps(
            {
                "model": self.model,
                "prompt": prompt,
                "route": "fake",
                "system": system,
                "want_json": want_json,
            },
            ensure_ascii=False,
            sort_keys=True,
        )


def _redacted_diagnostic(value: str | bytes) -> str:
    try:
        text = value.decode("utf-8", errors="replace") if isinstance(value, bytes) else value
        return redact(text)
    except Exception:
        return ""


def _joined_prompt(prompt: str, system: str) -> str:
    return f"{system}\n\n---\n\n{prompt}" if system else prompt


@dataclass(frozen=True)
class _CommandRoute(ABC):
    config: ModelConfig
    runner: Runner
    timeout: float

    @abstractmethod
    def _command(self, prompt: str, system: str, cwd: Path) -> tuple[list[str], str | None]: ...

    def _response(self, completed: Completed, cwd: Path) -> str:
        return completed.stdout

    def _failed(self, reason: str, completed: Completed) -> RouteFailed:
        return RouteFailed(
            self.config.route,
            returncode=completed.returncode,
            stderr_tail=_redacted_diagnostic(completed.stderr)[-2000:],
            reason=reason,
        )

    def complete(self, prompt: str, system: str, want_json: bool, env: Mapping[str, str]) -> str:
        completed = None
        try:
            with tempfile.TemporaryDirectory() as directory:
                cwd = Path(directory) / "work"
                cwd.mkdir()
                argv, stdin = self._command(prompt, system, cwd)
                completed = self.runner(argv, stdin=stdin, cwd=cwd, env=env, timeout=self.timeout)
                if completed.returncode != 0:
                    raise self._failed(f"終了コード {completed.returncode}", completed)
                response = self._response(completed, cwd)
                if not response.strip():
                    raise self._failed("応答が空です", completed)
                return response
        except subprocess.TimeoutExpired as error:
            raise RouteFailed(
                self.config.route,
                stderr_tail=_redacted_diagnostic(error.stderr or "")[-2000:],
                timed_out=True,
                reason=f"時間切れ（{self.timeout:g}秒）",
            ) from error
        except subprocess.CalledProcessError as error:
            raise RouteFailed(
                self.config.route,
                returncode=error.returncode,
                stderr_tail=_redacted_diagnostic(error.stderr or "")[-2000:],
                reason=f"終了コード {error.returncode}",
            ) from error
        except (OSError, ValueError, subprocess.SubprocessError) as error:
            if completed is not None:
                raise self._failed("応答を読み取れません", completed) from error
            raise RouteFailed(self.config.route, reason="コマンドを起動できません") from error


class _CodexRoute(_CommandRoute):
    _LAST_MESSAGE = "last-message.txt"

    def _command(self, prompt: str, system: str, cwd: Path) -> tuple[list[str], str]:
        argv = ["codex", "exec", "--model", self.config.model]
        if self.config.effort is not None:
            argv += ["-c", f"model_reasoning_effort={self.config.effort}"]
        argv += [
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
            str(cwd),
            "--output-last-message",
            str(cwd.parent / self._LAST_MESSAGE),
            "-",
        ]
        return argv, _joined_prompt(prompt, system)

    def _response(self, completed: Completed, cwd: Path) -> str:
        return (cwd.parent / self._LAST_MESSAGE).read_bytes().decode("utf-8")


class _ClaudeRoute(_CommandRoute):
    def _command(self, prompt: str, system: str, cwd: Path) -> tuple[list[str], str]:
        argv = ["claude", "-p", "--model", self.config.model]
        if self.config.effort is not None:
            argv += ["--effort", self.config.effort]
        argv += [
            "--output-format",
            "text",
            "--no-session-persistence",
            "--strict-mcp-config",
            "--disable-slash-commands",
        ]
        if system:
            argv += ["--system-prompt", system]
        argv += ["--tools", ""]
        return argv, prompt


class _AntigravityRoute(_CommandRoute):
    def _command(self, prompt: str, system: str, cwd: Path) -> tuple[list[str], None]:
        slug = self.config.model
        if self.config.thinking is not None:
            slug = f"{slug}-{self.config.thinking}"
        return [
            "agy",
            "-p",
            _joined_prompt(prompt, system),
            "--output-format",
            "json",
            "--model",
            slug,
            "--mode",
            "plan",
            "--sandbox",
            "--disable-slash-commands",
        ], None

    def _response(self, completed: Completed, cwd: Path) -> str:
        last_line = next(
            (line for line in reversed(completed.stdout.split("\n")) if line.strip()), ""
        )
        payload = json.loads(last_line)
        if not isinstance(payload, dict):
            raise self._failed("応答は JSON のオブジェクトである必要があります", completed)

        status = payload.get("status")
        response = payload.get("response")
        if status == "SUCCESS" and isinstance(response, str) and response.strip():
            return response

        safe_status = _redacted_diagnostic(str(status))[:500]
        details = payload.get("error", "")
        if not isinstance(details, str):
            details = json.dumps(details, ensure_ascii=False)
        safe_error = _redacted_diagnostic(details)[:500]
        raise self._failed(f"応答が無効です（status={safe_status}, error={safe_error}）", completed)


_COMMAND_ROUTES = {
    "antigravity": _AntigravityRoute,
    "claude": _ClaudeRoute,
    "codex": _CodexRoute,
}


@dataclass(frozen=True)
class GuardedRoute:
    name: str
    model: str
    _route: _Route
    _env: Mapping[str, str] | None

    def complete(self, prompt: str, *, system: str = "", want_json: bool = False) -> str:
        if not isinstance(prompt, str) or not isinstance(system, str):
            raise TypeError("prompt と system は str にしてください")

        source = os.environ if self._env is None else self._env
        try:
            if not isinstance(source, Mapping):
                raise TypeError
            snapshot = {key: source[key] for key in source}
        except Exception:
            if self.name == "antigravity":
                raise RouteRefused(self.name, markers=(UNREADABLE_ENV,)) from None
            raise RouteFailed(self.name, reason="環境を読めない") from None

        if self.name == "antigravity":
            markers = agent_markers(snapshot)
            if markers:
                raise RouteRefused(self.name, markers=markers)

        prompt = redact(prompt)
        system = redact(system)
        if want_json:
            system = f"{system}\n\n{JSON_INSTRUCTION}" if system else JSON_INSTRUCTION

        if self.name == "antigravity":
            try:
                size = len(_joined_prompt(prompt, system).encode("utf-8"))
            except UnicodeEncodeError as error:
                raise RouteFailed(self.name, reason="入力を UTF-8 に変換できません") from error
            if size > MAX_ARGV_PROMPT_BYTES:
                raise RouteFailed(
                    self.name,
                    reason=(
                        f"入力の長さ {size} バイトは上限 {MAX_ARGV_PROMPT_BYTES} バイトを超えます"
                    ),
                )

        response = self._route.complete(prompt, system, want_json, snapshot)
        if not isinstance(response, str):
            raise RouteFailed(self.name, reason="応答は文字列である必要があります")
        if not response.strip():
            raise RouteFailed(self.name, reason="応答が空です")
        return response


def get_route(
    model_cfg: ModelConfig,
    *,
    runner: Runner | None = None,
    env: Mapping[str, str] | None = None,
    timeout: float = DEFAULT_TIMEOUT,
    responder: Callable[[str, str, bool], str] | None = None,
) -> GuardedRoute:
    name = model_cfg.route
    if name not in ROUTES:
        raise UnknownRoute(name)
    try:
        valid_timeout = math.isfinite(timeout) and timeout > 0
    except (TypeError, OverflowError):
        valid_timeout = False
    if not valid_timeout:
        raise ValueError("timeout は正の有限の数にしてください")
    if name != "fake" and responder is not None:
        raise ValueError("responder は fake の経路だけで使えます")

    route: _Route
    if name == "fake":
        route = _FakeRoute(model_cfg.model, responder)
    else:
        route_type = _COMMAND_ROUTES[name]
        route = route_type(model_cfg, run_subprocess if runner is None else runner, timeout)
    return GuardedRoute(name, model_cfg.model, route, env)
