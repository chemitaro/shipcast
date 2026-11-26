import os
import subprocess
import sys
from dataclasses import replace
from datetime import date, timedelta, timezone

import pytest

from shipcast.collect import COLLECTORS, git
from shipcast.collect.base import CollectError
from shipcast.collect.git import GitCollector
from shipcast.config import RepoConfig
from shipcast.model import event_id
from shipcast.state import Store

DAY = date(2026, 11, 26)
TZ = timezone(timedelta(hours=9))
AUTHOR = "Demo Author"


@pytest.fixture
def git_repo(tmp_path, monkeypatch):
    for key in tuple(os.environ):
        if key.startswith("GIT_"):
            monkeypatch.delenv(key)
    monkeypatch.setenv("HOME", str(tmp_path / "home"))
    monkeypatch.setenv("GIT_CONFIG_GLOBAL", os.devnull)
    monkeypatch.setenv("GIT_CONFIG_SYSTEM", os.devnull)
    monkeypatch.setenv("GIT_AUTHOR_NAME", AUTHOR)
    monkeypatch.setenv("GIT_AUTHOR_EMAIL", "author@example.com")
    monkeypatch.setenv("GIT_COMMITTER_NAME", "Demo Committer")
    monkeypatch.setenv("GIT_COMMITTER_EMAIL", "committer@example.com")
    path = tmp_path / "demo"
    path.mkdir()
    run_git(path, "init", "-b", "main")
    return RepoConfig("demo", path, "main", "Demo", False)


def run_git(path, *args, stamp=None):
    env = os.environ.copy()
    if stamp is not None:
        env.update(GIT_AUTHOR_DATE=stamp, GIT_COMMITTER_DATE=stamp)
    return subprocess.run(
        ["git", "--no-optional-locks", "-C", str(path), *args],
        capture_output=True,
        env=env,
        check=True,
    ).stdout


def commit(repo, stamp, subject, *files, body=""):
    path = repo.path
    for name in files:
        (path / name).write_text(f"架空の内容 {stamp}\n", encoding="utf-8")
    run_git(path, "add", "--all")
    run_git(
        path,
        "commit",
        "--allow-empty",
        "--allow-empty-message",
        "-m",
        subject,
        "-m",
        body,
        stamp=stamp,
    )
    return run_git(path, "rev-parse", "HEAD").decode().strip()


def merge(repo, stamp, branch="feature"):
    run_git(repo.path, "merge", "--no-ff", "-m", "架空の統合", branch, stamp=stamp)
    return run_git(repo.path, "rev-parse", "HEAD").decode().strip()


def test_collects_first_parent_day_and_merge_contents(git_repo):
    repo = git_repo
    commit(repo, "2026-11-24T08:00:00+09:00", "開始", "base.txt")
    run_git(repo.path, "switch", "-c", "feature")
    feature = commit(repo, "2026-11-24T09:00:00+09:00", "架空の機能", "feature.txt")
    run_git(repo.path, "switch", "main")
    commit(repo, "2026-11-25T23:59:59+09:00", "前日", "base.txt")
    start = commit(repo, "2026-11-26T00:00:00+09:00", "", "base.txt")
    noon = commit(
        repo,
        "2026-11-26T12:00:00+09:00",
        "正午",
        "base.txt",
        "noon.txt",
        body="架空の本文\x1f続き",
    )
    run_git(repo.path, "switch", "-c", "unmerged")
    commit(repo, "2026-11-26T13:00:00+09:00", "未統合", "unmerged.txt")
    run_git(repo.path, "switch", "main")
    merged = merge(repo, "2026-11-26T15:00:00+09:00")
    last = commit(repo, "2026-11-26T23:59:59+09:00", "当日の最後")
    commit(repo, "2026-11-27T00:00:00+09:00", "翌日", "base.txt")

    result = GitCollector().collect(repo, DAY, TZ)

    assert result.warnings == ()
    expected = [
        (start, "commit", "（題名のないcommit）", "00:00:00", "変更したファイル: 1件", (start,)),
        (
            noon,
            "commit",
            "正午",
            "12:00:00",
            "架空の本文\x1f続き\n\n変更したファイル: 2件",
            (noon,),
        ),
        (
            merged,
            "merge",
            "架空の統合",
            "15:00:00",
            "変更したファイル: 1件\n取り込んだcommit: 1件",
            (merged,),
        ),
        (
            feature,
            "commit",
            "架空の機能",
            "15:00:00",
            f"変更したファイル: 1件\nマージ {merged[:12]} で入った"
            "（commitの時刻 2026-11-24T09:00:00+09:00）",
            (feature, merged),
        ),
        (last, "commit", "当日の最後", "23:59:59", "変更したファイル: 0件", (last,)),
    ]
    for event, (sha, kind, title, clock, body, refs) in zip(result.events, expected, strict=True):
        assert event.id == event_id("git", "demo", sha)
        assert (event.source, event.repo_id, event.actor) == ("git", "demo", AUTHOR)
        assert (event.kind, event.title, event.body, event.refs) == (kind, title, body, refs)
        assert event.at.isoformat() == f"2026-11-26T{clock}+09:00"


def write_config(tmp_path, *repos):
    config = tmp_path / "config.toml"
    state = tmp_path / "state"
    text = f'timezone = "Asia/Tokyo"\nstate_dir = "{state}"\n'
    for repo in repos:
        text += f'\n[[repos]]\nid = "{repo.id}"\npath = "{repo.path}"\norca = false\n'
    config.write_text(text, encoding="utf-8")
    return config, state


def collect_cli(config, *args):
    return subprocess.run(
        [sys.executable, "-m", "shipcast", "collect", "--date", DAY.isoformat(), *args],
        env={**os.environ, "SHIPCAST_CONFIG": str(config)},
        capture_output=True,
        text=True,
        encoding="utf-8",
        check=False,
    )


def test_collect_cli_saves_git_root_event_once(tmp_path, git_repo):
    assert COLLECTORS[0].name == "git"
    sha = commit(git_repo, "2026-11-26T11:00:00+09:00", "架空の初回変更", "demo.txt")
    config, state = write_config(tmp_path, git_repo)
    for saved in (1, 0):
        result = collect_cli(config, "--repo", "demo")
        assert result.returncode == 0
        assert result.stderr == ""
        assert result.stdout == f"demo 2026-11-26: 1件を集め、{saved}件を新しく保存しました\n"
    with Store(state) as store:
        (event,) = store.events_for("demo", DAY, tz=TZ)
        assert event.id == event_id("git", "demo", sha)
        assert event.refs == (sha,)
        assert event.body == "変更したファイル: 1件"


@pytest.mark.parametrize("case", ["missing", "plain", "child", "missing-ref", "flag-ref", "no-git"])
def test_git_collect_error_identifies_path_ref_or_executable(case, tmp_path, git_repo):
    repo = git_repo
    commit(repo, "2026-11-26T11:00:00+09:00", "架空の変更")
    collector = GitCollector()
    if case == "no-git":
        missing = tmp_path / "nonexistent-git"
        collector = GitCollector(git=str(missing))
        expected = f"gitのコマンドが見つかりません: {missing}"
    elif case.endswith("-ref"):
        repo = replace(repo, ref="-main" if case == "flag-ref" else "not-a-ref")
        expected = f"{repo.path}: ref {repo.ref} がありません"
    else:
        path = repo.path / "child" if case == "child" else tmp_path / case
        if case != "missing":
            path.mkdir()
        repo = replace(repo, path=path)
        reason = {
            "missing": "ディレクトリがありません",
            "plain": "Gitのrepositoryではありません",
            "child": f"Gitのrepositoryの最上位ではありません（最上位: {git_repo.path.resolve()}）",
        }[case]
        expected = f"{path}: {reason}"
    with pytest.raises(CollectError) as error:
        collector.collect(repo, DAY, TZ)
    assert str(error.value) == expected


def test_collect_cli_continues_after_git_error(tmp_path, git_repo):
    sha = commit(git_repo, "2026-11-26T11:00:00+09:00", "架空の変更")
    plain = tmp_path / "plain"
    plain.mkdir()
    config, state = write_config(tmp_path, replace(git_repo, id="plain", path=plain), git_repo)

    result = collect_cli(config)

    assert result.returncode == 1
    assert result.stderr == (
        f"shipcast collect: 失敗: plain: git: {plain}: Gitのrepositoryではありません\n"
    )
    assert result.stdout.splitlines() == [
        "plain 2026-11-26: 0件を集め、0件を新しく保存しました",
        "demo 2026-11-26: 1件を集め、1件を新しく保存しました",
    ]
    with Store(state) as store:
        assert store.events_for("plain", DAY, tz=TZ) == []
        (event,) = store.events_for("demo", DAY, tz=TZ)
        assert event.refs == (sha,)


def repo_state(path):
    head = path / ".git" / "HEAD"
    index = path / ".git" / "index"
    return (
        head.read_bytes(),
        head.stat().st_mtime_ns,
        index.read_bytes(),
        index.stat().st_mtime_ns,
        run_git(path, "for-each-ref"),
        run_git(path, "status", "--porcelain=v1", "--untracked-files=all"),
        (path / "tracked.txt").read_bytes(),
        (path / "untracked.txt").read_bytes(),
    )


def test_git_collection_preserves_repository_state(git_repo, monkeypatch):
    path = git_repo.path
    sha = commit(git_repo, "2026-11-26T11:00:00+09:00", "架空の変更", "tracked.txt")
    run_git(path, "switch", "-c", "working")
    (path / "tracked.txt").write_bytes(b"local changes")
    (path / "untracked.txt").write_bytes(b"untracked")
    before = repo_state(path)
    commands = []
    original_run = subprocess.run
    inherited = (
        "GIT_DIR",
        "GIT_WORK_TREE",
        "GIT_INDEX_FILE",
        "GIT_OBJECT_DIRECTORY",
        "GIT_ALTERNATE_OBJECT_DIRECTORIES",
        "GIT_COMMON_DIR",
        "GIT_NAMESPACE",
    )

    def record_run(args, **kwargs):
        commands.append(args)
        env = kwargs["env"]
        assert not (env.keys() & set(inherited))
        assert env["GIT_OPTIONAL_LOCKS"] == env["GIT_TERMINAL_PROMPT"] == "0"
        assert env["GIT_NO_LAZY_FETCH"] == "1"
        assert env["GIT_ALLOW_PROTOCOL"] == ""
        return original_run(args, **kwargs)

    with monkeypatch.context() as isolated:
        for key in inherited:
            isolated.setenv(key, str(path / "unrelated"))
        isolated.setattr(git.subprocess, "run", record_run)
        result = git.GitCollector().collect(git_repo, DAY, TZ)

    assert [event.refs for event in result.events] == [(sha,)]
    assert {args[4] for args in commands} == {"rev-parse", "log", "diff-tree"}
    assert all(args[:4] == ["git", "--no-optional-locks", "-C", str(path)] for args in commands)
    assert repo_state(path) == before


def test_git_collect_limits_merged_commits(git_repo):
    repo = git_repo
    commit(repo, "2026-11-23T11:00:00+09:00", "開始")
    run_git(repo.path, "switch", "-c", "feature")
    commits = [
        commit(repo, f"2026-11-24T11:0{number}:00+09:00", f"架空の変更 {number}")
        for number in range(3)
    ]
    run_git(repo.path, "switch", "main")
    sha = merge(repo, "2026-11-26T15:00:00+09:00")

    result = GitCollector(max_merged=2).collect(repo, DAY, TZ)

    assert [event.refs for event in result.events] == [(sha,), (commits[1], sha), (commits[2], sha)]
    assert result.events[0].body.endswith("取り込んだcommit: 2件")
    assert result.warnings == (
        f"マージ {sha[:12]} が取り込んだcommitが2件を超えたので、2件だけを集めました",
    )
