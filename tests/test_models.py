from collections.abc import Mapping

import pytest

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
