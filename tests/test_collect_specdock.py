import json
import subprocess
from datetime import date
from pathlib import Path
from zoneinfo import ZoneInfo

import pytest

from shipcast.config import RepoConfig

DAY = date(2026, 11, 26)
TZ = ZoneInfo("Asia/Tokyo")
FIXTURES = Path(__file__).parent / "fixtures" / "specdock"


class FakeCommands:
    def __init__(self):
        self.calls = []
        self.responses = {
            command: (FIXTURES / filename).read_text(encoding="utf-8")
            for command, filename in (
                (("spec-dock", "scope", "list"), "scope-list.json"),
                (("spec-dock", "todo", "list"), "todo-list.json"),
                (("gh", "issue", "list"), "gh-issue-list.json"),
            )
        }

    def __call__(self, argv, **kwargs):
        self.calls.append((argv, kwargs))
        response = self.responses[tuple(argv[:3])]
        if isinstance(response, Exception):
            raise response
        if isinstance(response, str):
            return subprocess.CompletedProcess(argv, 0, response, "")
        return response


@pytest.fixture
def specdock_repo(tmp_path):
    workspace = tmp_path / "spec-dock"
    workspace.mkdir()
    (workspace / "workspace.json").write_text("{}", encoding="utf-8")
    return RepoConfig(id="demo", path=tmp_path, ref="main", title="demo", orca=False)


def test_fake_commands_serve_json_fixtures(specdock_repo):
    commands = FakeCommands()
    project = str(specdock_repo.path)
    scope = commands(["spec-dock", "scope", "list", "--project", project])
    todo = commands(["spec-dock", "todo", "list", "--project", project])
    issues = commands(["gh", "issue", "list", "--repo", "example-org/demo-app"])
    assert json.loads(scope.stdout)["data"]["result"]["items"][0]["id"] == "iss-00101"
    assert json.loads(todo.stdout)["data"]["result"]["items"][0]["todo"]["id"] == "todo-00101"
    assert json.loads(issues.stdout)[0]["number"] == 101
