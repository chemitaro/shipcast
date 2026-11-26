"""Read and validate shipcast's TOML configuration."""

import os
import re
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
model = "gpt-6.2-sol"
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
