import subprocess
from pathlib import Path

FIXTURES = Path(__file__).parent / "fixtures" / "orca"


def session_id(number):
    return f"00000000-0000-4000-8000-{number:012d}"


def fixture_text(name):
    return (FIXTURES / f"{name}.json").read_text(encoding="utf-8")


class FakeOrca:
    def __init__(self):
        self.calls = []
        self.responses = {
            ("agent", "list"): fixture_text("agent-list"),
            ("repo", "list"): fixture_text("repo-list"),
        }
        for number, name in enumerate(("main", "worktree", "child", "empty"), start=1):
            self.responses["agent", "read", f"orca_session_id:{session_id(number)}"] = (
                fixture_text(f"agent-read-{name}")
            )

    def __call__(self, argv, **kwargs):
        self.calls.append((argv, kwargs))
        command = tuple(argv[1:4] if argv[1:3] == ["agent", "read"] else argv[1:3])
        response = self.responses[command]
        if isinstance(response, Exception):
            raise response
        if isinstance(response, str):
            return subprocess.CompletedProcess(argv, 0, response, "")
        return subprocess.CompletedProcess(argv, *response)
