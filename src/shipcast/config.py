"""Read and validate shipcast's TOML configuration."""

import os
import re
import shutil
import tempfile
import tomllib
from dataclasses import dataclass
from pathlib import Path
from typing import Any
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

DEFAULT_CONFIG_PATH = "~/.config/shipcast/config.toml"
DEFAULT_CONFIG_TEXT = """\
# shipcast の設定ファイル（schema 1）
# 日誌の対象のrepositoryは `shipcast repo add <path>` で末尾に足します。

schema = 1
timezone = "Asia/Tokyo"
journal_dir = "~/.local/share/shipcast/journal"
state_dir = "~/.local/state/shipcast"

[models.analyst]
route = "codex"          # codex | claude | fake
model = "gpt-6.2-sol" # より安い: "gpt-6-luna"（codex debug models で確認。2026-11-26）
effort = "low"

[models.writer]
route = "antigravity"    # antigravity | claude | codex | fake
model = "gemini-4-neon"
thinking = "high"

[serve]
host = "127.0.0.1"
port = 8765
design_system_dir = ""   # 空なら、登録したrepositoryの spec-dock/design-system を使う

[neta]
threshold = 6
"""

_REPO_ID = re.compile(r"[a-z0-9]+(?:-[a-z0-9]+)*")


@dataclass(frozen=True)
class RepoConfig:
    id: str
    path: Path
    ref: str
    title: str
    orca: bool


@dataclass(frozen=True)
class ModelConfig:
    route: str
    model: str
    effort: str | None
    thinking: str | None


@dataclass(frozen=True)
class ModelsConfig:
    analyst: ModelConfig
    writer: ModelConfig


@dataclass(frozen=True)
class ServeConfig:
    host: str
    port: int
    design_system_dir: Path | None


@dataclass(frozen=True)
class NetaConfig:
    threshold: int


@dataclass(frozen=True)
class Config:
    """設定を足すときは型と D-04 の許可項目・検証を更新する。形を変えるときは schema を上げる。"""

    schema: int
    timezone: str
    journal_dir: Path
    state_dir: Path
    models: ModelsConfig
    serve: ServeConfig
    neta: NetaConfig
    repos: tuple[RepoConfig, ...]


class ConfigError(Exception):
    def __init__(self, problem: str, hint: str, path: Path | None = None):
        super().__init__(problem)
        self.problem = problem
        self.hint = hint
        self.path = path

    def __str__(self) -> str:
        prefix = f"{self.path}: " if self.path is not None else ""
        return f"{prefix}{self.problem}\n直し方: {self.hint}"


def config_path() -> Path:
    return Path(os.environ.get("SHIPCAST_CONFIG") or DEFAULT_CONFIG_PATH).expanduser()


def _read_text(path: Path) -> str:
    try:
        return path.read_bytes().decode("utf-8")
    except UnicodeDecodeError as error:
        raise ConfigError(
            "UTF-8で設定ファイルを読めません", "UTF-8で保存し直してください", path
        ) from error


def load_config(path: str | Path | None = None) -> Config:
    source = config_path() if path is None else Path(path).expanduser()
    try:
        text = _read_text(source)
    except FileNotFoundError as error:
        raise ConfigError(
            "設定ファイルがありません", "`shipcast repo add <path>` で作れます", source
        ) from error
    return parse_config(text, source)


class _ConfigReader:
    """TOML の値を検証し、誤りにファイルと項目を付ける。"""

    def __init__(self, source: Path):
        self.source = source

    def error(self, field: str, problem: str, hint: str) -> ConfigError:
        return ConfigError(f"{field}: {problem}", hint, self.source)

    def table(self, value: object, field: str, allowed: set[str]) -> dict[str, Any]:
        if not isinstance(value, dict):
            raise self.error(field, "表ではありません", "TOMLの表で書いてください")
        for key in value:
            if key not in allowed:
                name = f"{field}.{key}" if field else key
                options = "、".join(sorted(allowed))
                raise self.error(name, "知らない項目です", f"{options} のいずれかを使ってください")
        return value

    def string(self, value: object, field: str) -> str:
        if not isinstance(value, str) or not value:
            raise self.error(
                field, "空でない文字列が必要です", '例: "sample" のように書いてください'
            )
        return value

    def absolute_path(self, value: object, field: str) -> Path:
        text = self.string(value, field)
        hint = "絶対の道筋か、展開できる ~ で始まる道筋を指定してください"
        try:
            path = Path(text).expanduser()
        except RuntimeError as error:
            raise self.error(field, "~ を展開できません", hint) from error
        if not path.is_absolute() or "\0" in text:
            raise self.error(field, "有効な絶対の道筋ではありません", hint)
        return path

    def integer(self, value: object, field: str, minimum: int, maximum: int | None = None) -> int:
        if type(value) is not int or value < minimum or (maximum is not None and value > maximum):
            numbers = f"{minimum}以上" if maximum is None else f"{minimum}〜{maximum}"
            hint = f"{numbers}の整数を書いてください"
            if minimum == maximum:
                hint = f"{minimum} と書いてください"
            raise self.error(field, "許される整数ではありません", hint)
        return value

    def model(
        self,
        value: object,
        field: str,
        default: ModelConfig,
        routes: tuple[str, ...],
    ) -> ModelConfig:
        table = self.table(value, field, {"route", "model", "effort", "thinking"})
        route = table.get("route", default.route)
        if route not in routes:
            options = "・".join(f'"{option}"' for option in routes)
            raise self.error(
                f"{field}.route", "許される経路ではありません", f"{options} から選んでください"
            )
        return ModelConfig(
            route=route,
            model=self.string(table.get("model", default.model), f"{field}.model"),
            effort=(
                self.string(table["effort"], f"{field}.effort")
                if "effort" in table
                else default.effort
            ),
            thinking=(
                self.string(table["thinking"], f"{field}.thinking")
                if "thinking" in table
                else default.thinking
            ),
        )

    def repos(self, value: object) -> tuple[RepoConfig, ...]:
        if not isinstance(value, list):
            raise self.error("repos", "表の配列ではありません", "[[repos]] の形で書いてください")
        repos = []
        seen = set()
        for index, entry in enumerate(value, start=1):
            field = f"repos[{index}]"
            table = self.table(entry, field, {"id", "path", "ref", "title", "orca"})
            repo_id = table.get("id")
            if not isinstance(repo_id, str) or not _REPO_ID.fullmatch(repo_id):
                raise self.error(
                    f"{field}.id", "有効な id が必要です", '例: id = "sample-app" と書いてください'
                )
            if repo_id in seen:
                raise self.error(f"{field}.id", "id が重複しています", "別の id を指定してください")
            seen.add(repo_id)
            path = self.absolute_path(table.get("path"), f"{field}.path")
            ref = self.string(table.get("ref", "main"), f"{field}.ref")
            title = self.string(table.get("title", repo_id), f"{field}.title")
            orca = table.get("orca", True)
            if not isinstance(orca, bool):
                raise self.error(
                    f"{field}.orca", "真偽値ではありません", "true または false を指定してください"
                )
            repos.append(RepoConfig(repo_id, path, ref, title, orca))
        return tuple(repos)


def parse_config(text: str, source: Path) -> Config:
    try:
        values = tomllib.loads(text)
    except tomllib.TOMLDecodeError as error:
        detail = str(error)
        if detail.endswith("(at end of document)"):
            line = text.count("\n") + 1
            detail += f" (line {line})"
        raise ConfigError(
            f"TOMLの文法の誤り: {detail}", "その行の書き方をTOMLの形に直してください", source
        ) from error

    reader = _ConfigReader(source)
    reader.table(
        values,
        "",
        {"schema", "timezone", "journal_dir", "state_dir", "models", "serve", "neta", "repos"},
    )
    schema = reader.integer(values.get("schema", 1), "schema", 1, 1)
    timezone = reader.string(values.get("timezone", "Asia/Tokyo"), "timezone")
    try:
        ZoneInfo(timezone)
    except (ZoneInfoNotFoundError, ValueError) as error:
        raise reader.error(
            "timezone", "時間帯を開けません", '例: "Asia/Tokyo" を指定してください'
        ) from error
    journal_dir = reader.absolute_path(
        values.get("journal_dir", "~/.local/share/shipcast/journal"), "journal_dir"
    )
    state_dir = reader.absolute_path(
        values.get("state_dir", "~/.local/state/shipcast"), "state_dir"
    )

    models = reader.table(values.get("models", {}), "models", {"analyst", "writer"})
    analyst = reader.model(
        models.get("analyst", {}),
        "models.analyst",
        ModelConfig("codex", "gpt-6.2-sol", "low", None),
        ("codex", "claude", "fake"),
    )
    writer = reader.model(
        models.get("writer", {}),
        "models.writer",
        ModelConfig("antigravity", "gemini-4-neon", None, "high"),
        ("antigravity", "claude", "codex", "fake"),
    )
    serve = reader.table(values.get("serve", {}), "serve", {"host", "port", "design_system_dir"})
    host = reader.string(serve.get("host", "127.0.0.1"), "serve.host")
    port = reader.integer(serve.get("port", 8765), "serve.port", 1, 65535)
    design_dir = serve.get("design_system_dir", "")
    design_system_dir = (
        None if design_dir == "" else reader.absolute_path(design_dir, "serve.design_system_dir")
    )
    neta = reader.table(values.get("neta", {}), "neta", {"threshold"})
    threshold = reader.integer(neta.get("threshold", 6), "neta.threshold", 1)
    return Config(
        schema,
        timezone,
        journal_dir,
        state_dir,
        ModelsConfig(analyst, writer),
        ServeConfig(host, port, design_system_dir),
        NetaConfig(threshold),
        reader.repos(values.get("repos", [])),
    )


@dataclass(frozen=True)
class AddResult:
    repo: RepoConfig
    config_path: Path
    created: bool


def derive_repo_id(name: str) -> str:
    return re.sub(r"[^a-z0-9]+", "-", name.lower()).strip("-")


_TOML_ESCAPES = {codepoint: f"\\u{codepoint:04X}" for codepoint in (*range(0x20), 0x7F)}
_TOML_ESCAPES.update(
    str.maketrans(
        {
            '"': r"\"",
            "\\": r"\\",
            "\b": r"\b",
            "\t": r"\t",
            "\n": r"\n",
            "\f": r"\f",
            "\r": r"\r",
        }
    )
)


def toml_string(value: str) -> str:
    return '"' + value.translate(_TOML_ESCAPES) + '"'


def _replace_config(destination: Path, text: str, original: str | None) -> None:
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(
            mode="w", encoding="utf-8", newline="", dir=destination.parent, delete=False
        ) as file:
            temporary = Path(file.name)
            file.write(text)
            file.flush()
            os.fsync(file.fileno())
        if original is not None:
            shutil.copymode(destination, temporary)
        os.replace(temporary, destination)
        temporary = None
    finally:
        if temporary is not None:
            temporary.unlink(missing_ok=True)


def _write_config(destination: Path, text: str, original: str | None) -> bool:
    destination.parent.mkdir(parents=True, exist_ok=True)
    if os.name != "posix":
        _replace_config(destination, text, original)
        return True

    import fcntl

    # The directory survives an atomic replacement, so concurrent writers lock the same inode.
    directory_fd = os.open(destination.parent, os.O_RDONLY | os.O_DIRECTORY)
    try:
        fcntl.flock(directory_fd, fcntl.LOCK_EX)
        try:
            current = _read_text(destination)
        except FileNotFoundError:
            current = None
        if current != original:
            return False
        _replace_config(destination, text, original)
        return True
    finally:
        os.close(directory_fd)


def add_repo(
    repo_path: str | Path,
    *,
    repo_id: str | None = None,
    title: str | None = None,
    ref: str = "main",
    config_file: str | Path | None = None,
) -> AddResult:
    target = Path(repo_path).expanduser().resolve()
    if not target.is_dir():
        raise ConfigError(
            "repositoryのディレクトリがありません", "存在するディレクトリを指定してください", target
        )
    if not (target / "spec-dock" / "workspace.json").is_file():
        raise ConfigError(
            "SpecDockを使っていません", "SpecDockを入れたrepositoryを指定してください", target
        )

    repo_id = derive_repo_id(target.name) if repo_id is None else repo_id
    if not _REPO_ID.fullmatch(repo_id):
        raise ConfigError(
            "有効な id が必要です", "`--id` で英小文字・数字・`-` の名前を指定してください", target
        )
    title = target.name if title is None else title
    reader = _ConfigReader(target)
    reader.string(title, "--title")
    reader.string(ref, "--ref")
    repo = RepoConfig(repo_id, target, ref, title, True)

    source = config_path() if config_file is None else Path(config_file).expanduser()
    while True:
        destination = source.resolve()
        if destination.is_relative_to(target):
            raise ConfigError(
                "設定ファイルが対象のrepositoryの中にあります",
                "`SHIPCAST_CONFIG` でrepositoryの外の道筋を指定してください",
                source,
            )
        try:
            original = _read_text(source)
        except FileNotFoundError:
            original = None
        base = DEFAULT_CONFIG_TEXT if original is None else original
        combined = _append_repo(base, source, repo)
        if _write_config(destination, combined, original):
            return AddResult(repo, source, created=original is None)


def _append_repo(base: str, source: Path, repo: RepoConfig) -> str:
    config = parse_config(base, source)
    for existing in config.repos:
        if existing.id == repo.id or existing.path.resolve() == repo.path:
            raise ConfigError(
                f"すでに {existing.id} として登録されています",
                "未登録のrepositoryと id を指定してください",
                source,
            )

    separator = ""
    if base:
        separator = "\n" if base.endswith("\n") else "\n\n"
    combined = (
        f"{base}{separator}[[repos]]\n"
        f"id = {toml_string(repo.id)}\n"
        f"path = {toml_string(str(repo.path))}\n"
        f"ref = {toml_string(repo.ref)}\n"
        f"title = {toml_string(repo.title)}\n"
        "orca = true\n"
    )

    problem = "設定ファイルの末尾にrepositoryを足せません"
    hint = "`repos` を `[[repos]]` の形で書いてください"
    try:
        updated = parse_config(combined, source)
    except ConfigError as error:
        raise ConfigError(problem, hint, source) from error
    if updated.repos != (*config.repos, repo):
        raise ConfigError(problem, hint, source)

    return combined
