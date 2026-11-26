"""モデルへの経路と、呼び出し前の守り。"""

from collections.abc import Mapping

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
