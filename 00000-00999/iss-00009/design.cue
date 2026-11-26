package spec

goals: [
	"後のIssueが `from shipcast.config import load_config` の1行で、検証済みの型のついた設定を受け取れる",
	"`repo add` が本人の手で書いた設定ファイル（コメント、空行、並び）を壊さない",
	"壊れた設定・SpecDockのないrepository・重複の登録で、何も書かずに、直し方を示して止まる",
]

current: "`shipcast repo add` と `shipcast repo list` は、iss-00008 の「未実装」の葉（終了コード2）。設定を読むコードはない。"
target:  "`shipcast repo add <path>` が設定ファイルの末尾に `[[repos]]` の塊を足し（ないときは既定の内容で作り）、`shipcast repo list` が登録した順に示す。`shipcast.config.load_config()` が `Config` を返す。"

design: {
	"D-01": {
		title: "置かれる場所と、変えるファイル"
		text: """
		```text
		src/shipcast/config.py   # 新規。型、置き場、読み込みと検証、書き足し（CLIに依存しない）
		src/shipcast/repo.py     # 新規。repo add / repo list の葉（argparseの引数、出力、終了コード）
		src/shipcast/cli.py      # 変更。COMMANDS の repo の行の2つの Entry に configure を渡すだけ
		tests/test_config.py     # 新規。shipcast.config の試験
		tests/test_repo.py       # 新規。main(["repo", ...]) を通した試験
		tests/test_cli.py        # 変更。未実装の葉の一覧から repo add と repo list の2行を外すだけ
		```

		- 依存の向き：`cli` → `repo` → `config`。`config` は `cli` と `repo` を読み込まない（後のIssueが `config` だけを使えるように）。
		- `cli.py` の変更は、`from shipcast import repo` の1行と、`Entry("add", "リポジトリを登録する", repo.configure_add)`、`Entry("list", "登録済みのリポジトリを表示する", repo.configure_list)` だけ。説明の文と、ほかの行は変えない。
		- iss-00010 は `shipcast/model.py`・`shipcast/state.py` を足す。このIssueはそれらに触れない。
		"""
		satisfies: ["R-01", "R-02", "R-03"]
	}
	"D-02": {
		title: "設定の型（`shipcast.config`）"
		text: """
		すべて `@dataclass(frozen=True)`。

		```python
		class RepoConfig:   id: str; path: Path; ref: str; title: str; orca: bool
		class ModelConfig:  route: str; model: str; effort: str | None; thinking: str | None
		class ModelsConfig: analyst: ModelConfig; writer: ModelConfig
		class ServeConfig:  host: str; port: int; design_system_dir: Path | None
		class NetaConfig:   threshold: int
		class Config:
		    schema: int; timezone: str; journal_dir: Path; state_dir: Path
		    models: ModelsConfig; serve: ServeConfig; neta: NetaConfig
		    repos: tuple[RepoConfig, ...]
		```

		既定値（epic-00002 の D-02。道筋は読むときに `~` を展開する）：

		:::datatable 既定値
		| 項目 | 既定値 |
		|---|---|
		| `schema` | `1` |
		| `timezone` | `"Asia/Tokyo"` |
		| `journal_dir` | `~/.local/share/shipcast/journal` |
		| `state_dir` | `~/.local/state/shipcast` |
		| `models.analyst` | `route="codex"`、`model="gpt-6.2-sol"`、`effort="low"`、`thinking=None` |
		| `models.writer` | `route="antigravity"`、`model="gemini-4-neon"`、`effort=None`、`thinking="high"` |
		| `serve` | `host="127.0.0.1"`、`port=8765`、`design_system_dir=None`（ファイルの `""` も `None`） |
		| `neta.threshold` | `6` |
		| `repos` | `()` |
		| `repos[].ref` / `title` / `orca` | `"main"` / その `id` / `true` |
		:::

		- 既定値は項目ごとに補う。`[models.writer]` に `route = "fake"` だけを書けば、`model` と `thinking` は既定値のまま。
		"""
		satisfies: ["R-01"]
	}
	"D-03": {
		title: "置き場の決め方と読み込み"
		text: """
		```python
		DEFAULT_CONFIG_PATH = "~/.config/shipcast/config.toml"
		def config_path() -> Path               # SHIPCAST_CONFIG（空でなければ）か DEFAULT_CONFIG_PATH を expanduser した Path
		def load_config(path: str | Path | None = None) -> Config
		def parse_config(text: str, source: Path) -> Config   # 文字列から。誤りの文に source を使う
		```

		- `load_config(path)` は `path` を `expanduser` する（省けば `config_path()`）。ファイルがなければ F-02 の `ConfigError`。UTF-8で読めなければ F-01 の `ConfigError`。
		- `parse_config` は `tomllib.loads` の後、D-04 の規則で確かめ、`Config` を作る。`tomllib.TOMLDecodeError` は F-01 の `ConfigError` に包む（元の文に `line N` が入る）。
		- 相対の道筋は誤り（作業ディレクトリで意味が変わるため）。`~` を展開した後に `is_absolute()` でないものは D-04 の値の誤り。
		- `load_config` は、登録したrepositoryの `path` があるかを確かめない（消したrepositoryで設定の読み込みを止めないため。確かめは使う側と `repo add` が行う）。
		"""
		satisfies: ["R-01", "F-02"]
	}
	"D-04": {
		title: "値の検証の規則"
		text: """
		:::datatable 項目と規則
		| 項目 | 型と規則 | 誤りの項目の名前の例 |
		|---|---|---|
		| 一番上 | 許す項目は `schema`、`timezone`、`journal_dir`、`state_dir`、`models`、`serve`、`neta`、`repos` だけ | `foo` |
		| `schema` | 整数で `1` だけ | `schema` |
		| `timezone` | 空でない文字列で、`zoneinfo.ZoneInfo` で開ける名前 | `timezone` |
		| `journal_dir`・`state_dir` | 空でない文字列。`~` を展開して絶対 | `journal_dir` |
		| `models` | 表。許す項目は `analyst`、`writer` だけ | `models.foo` |
		| `models.analyst` | 表。許す項目 `route`（`codex`・`claude`・`fake`）、`model`（空でない文字列）、`effort`・`thinking`（空でない文字列） | `models.analyst.route` |
		| `models.writer` | 同じ。`route` は `antigravity`・`claude`・`codex`・`fake` | `models.writer.route` |
		| `serve` | 表。`host`（空でない文字列）、`port`（1〜65535の整数）、`design_system_dir`（文字列。`""` は `None`、それ以外は `~` を展開して絶対） | `serve.port` |
		| `neta` | 表。`threshold`（1以上の整数） | `neta.threshold` |
		| `repos` | 表の配列（`[[repos]]`） | `repos` |
		| `repos[n]` | 表。許す項目 `id`（必須）、`path`（必須）、`ref`、`title`、`orca` | `repos[2].foo` |
		| `repos[n].id` | 文字列で、正規表現 `^[a-z0-9]+(-[a-z0-9]+)*$`。全体で重複しない | `repos[2].id` |
		| `repos[n].path` | 空でない文字列。`~` を展開して絶対 | `repos[1].path` |
		| `repos[n].ref`・`title` | 空でない文字列 | `repos[1].ref` |
		| `repos[n].orca` | 真偽 | `repos[1].orca` |
		:::

		- 「整数」は `bool` を含めない（TOMLの `true` を `port` に書けば誤り）。
		- `repos[n]` の `n` は1から数える（人が読む番号。ファイルの上から n 番目の `[[repos]]`）。
		- 最初に見つけた誤りを1つだけ示して止まる。
		"""
		satisfies: ["R-01", "F-01"]
	}
	"D-05": {
		title: "誤りの形 `ConfigError`"
		text: """
		```python
		class ConfigError(Exception):
		    def __init__(self, problem: str, hint: str, path: Path | None = None): ...
		    problem: str; hint: str; path: Path | None
		    def __str__(self) -> str:  # 例 "/x/config.toml: repos[2].path: 絶対の道筋ではありません\\n直し方: ..."
		        # (f"{path}: " if path else "") + problem + "\\n直し方: " + hint
		```

		- 設定の誤りでは `path` は設定ファイル、`repo add` の対象の誤り（ない、SpecDockがない、`id` が作れない、重複）では `path` は対象のrepositoryか設定ファイル。
		- 文法の誤りの `problem` は `TOMLの文法の誤り: <tomllib の文>`（`line N` を含む）、`hint` は「その行の書き方をTOMLの形に直してください」。
		- 値の誤りの `problem` は `<項目の名前>: <何が違うか>`、`hint` は許す値か書き方（例 `route は "codex"・"claude"・"fake" のどれかにしてください`）。
		- ファイルがないとき（F-02）の `problem` は `設定ファイルがありません`、`hint` は「`shipcast repo add <path>` で作れます」。
		- CLIは `print(f"shipcast repo <add|list>: {error}", file=sys.stderr)` で示し、1を返す。標準出力には何も出さない。
		"""
		satisfies: ["F-01", "F-02"]
	}
	"D-06": {
		title: "`add_repo`：登録の確かめと書き足し"
		text: """
		```python
		@dataclass(frozen=True)
		class AddResult: repo: RepoConfig; config_path: Path; created: bool

		def add_repo(repo_path: str | Path, *, repo_id: str | None = None, title: str | None = None,
		             ref: str = "main", config_file: str | Path | None = None) -> AddResult
		def derive_repo_id(name: str) -> str      # 作れなければ ""
		def toml_string(value: str) -> str        # TOMLの基本の文字列（"..."）にする
		DEFAULT_CONFIG_TEXT: str                  # 新しく作るときの既定の内容
		```

		順に確かめ、どこかで誤りなら `ConfigError` を投げ、何も書かない。

		1. **対象**：`Path(repo_path).expanduser().resolve()`。ディレクトリでなければ誤り。`<対象>/spec-dock/workspace.json` が `is_file()` でなければ誤り（「SpecDockを使っていません」。直し方「SpecDockを入れたrepositoryを指定してください」）。中身は読まない。
		2. **名前**：`repo_id` があればD-04の正規表現で確かめ、なければ `derive_repo_id(対象.name)`（英小文字にし、`[^a-z0-9]+` を `-` にし、両端の `-` を除く）。空なら誤り（直し方「`--id` で英小文字・数字・`-` の名前を指定してください」）。`title` は省けば `対象.name`、`ref` とともに空なら誤り。
		3. **設定**：`config_file`（省けば `config_path()`）を `expanduser`。あればUTF-8で読み、`parse_config` で確かめる（壊れていれば F-01 の誤りのまま止まる）。なければ `DEFAULT_CONFIG_TEXT` を元の中身とし、`created=True`。
		4. **重複**：既存の `id` と同じ、または既存の `path.resolve()` が対象と同じなら誤り（「すでに <id> として登録されています」）。
		5. **合成**：元の中身 + 区切り + 塊。区切りは、元の中身が空でなく `\\n` で終わらなければ `\\n`、その後、元の中身が空でなければ空行の `\\n`。塊は次の形で、値は `toml_string` で書く。

		   ```toml
		   [[repos]]
		   id = "<id>"
		   path = "<対象の絶対の道筋>"
		   ref = "<ref>"
		   title = "<title>"
		   orca = true
		   ```
		6. **書く前の確かめ**：合成した文字列を `parse_config` で読み、`repos` が、元の `repos` の後に新しい1件を足したものと等しいことを確かめる。違えば（例 元のファイルが `repos = [...]` の形で書かれている）誤りにして書かない（直し方「`repos` を `[[repos]]` の形で書いてください」）。
		7. **書く**：D-07。
		"""
		satisfies: ["R-02", "R-04", "F-01"]
	}
	"D-07": {
		title: "ファイルを壊さない書き方"
		text: """
		- 書く先は `config_file.resolve()`（設定ファイルが記号のリンクなら、リンクを保ち、リンクの先を書き換える）。親のディレクトリは `mkdir(parents=True, exist_ok=True)`。
		- 同じディレクトリに `tempfile.NamedTemporaryFile(delete=False)`（`dir=` 書く先の親）でUTF-8で書き、`flush` と `os.fsync` の後、`os.replace` で置き換える。既存のファイルなら、置き換える前に `shutil.copymode` で許可の値を写す。途中で失敗したら一時ファイルを消し、元のファイルは元のまま。
		- 読んだ元の中身は文字列として扱い、書き換えない（先頭はバイト単位で同じ。改行は `\\n` で足す）。
		- 対象のrepositoryの中には何も書かず、`git` もほかのコマンドも実行しない。
		"""
		satisfies: ["R-02", "R-04"]
	}
	"D-08": {
		title: "既定の内容 `DEFAULT_CONFIG_TEXT`"
		text: """
		epic-00002 の D-02 の見本から `[[repos]]` を除き、先頭に説明のコメントを足したもの。`parse_config(DEFAULT_CONFIG_TEXT, ...)` は、空の文字列を読んだときと等しい `Config` になる（試験で確かめる）。

		```toml
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
		```
		"""
		satisfies: ["R-04"]
	}
	"D-09": {
		title: "CLIの葉（`shipcast.repo`）"
		text: """
		```python
		def configure_add(parser: argparse.ArgumentParser) -> None   # path（位置）、--id（dest=repo_id）、--title、--ref（既定 "main"）。set_defaults(func=run_add)
		def configure_list(parser: argparse.ArgumentParser) -> None  # 引数なし。set_defaults(func=run_list)
		def run_add(args) -> int
		def run_list(args) -> int
		```

		:::datatable 出力と終了コード
		| 場合 | 標準出力 | 標準エラー | 終了コード |
		|---|---|---|---|
		| `repo add` で足した（ファイルがあった） | `登録しました: <id> <path>` | なし | 0 |
		| `repo add` で作って足した | `設定ファイルを作りました: <設定の道筋>` の後に `登録しました: <id> <path>` | なし | 0 |
		| `repo add` の誤り（D-06 の 1〜6、F-01） | なし | `shipcast repo add: <ConfigError>` | 1 |
		| `repo list` で1件以上 | 1件1行 `<id>\\t<title>\\t<path>\\t<ref>`（登録の順。見出しなし） | なし | 0 |
		| `repo list` で0件 | なし | 「登録されたrepositoryはありません。`shipcast repo add <path>` で登録できます」 | 0 |
		| `repo list` の誤り（F-01、F-02） | なし | `shipcast repo list: <ConfigError>` | 1 |
		| 引数の誤り（`repo add` に path なし等） | なし | argparseの使い方 | 2 |
		:::

		- どちらも設定の道筋は `config_path()`（`SHIPCAST_CONFIG`）で決める。`--config` の引数は足さない。
		- `ConfigError` 以外の例外（`OSError` など）は包まずに上げる（隠さない）。
		"""
		satisfies: ["R-02", "R-03", "R-04", "F-01", "F-02"]
	}
	"D-10": {
		title: "試験の継ぎ目"
		text: """
		- `shipcast.config` の関数は直接呼ぶ（`tests/test_config.py`）。CLIは `main(["repo", ...])` を `capsys` で呼ぶ（`tests/test_repo.py`）。
		- どの試験も、`monkeypatch` で `HOME` を `tmp_path/"home"`、`SHIPCAST_CONFIG` を `tmp_path/"config"/"config.toml"`（置き場の試験では消す）に向ける。
		- 偽のrepositoryは `tmp_path/"repos"/<名前>/spec-dock/workspace.json`（中身 `{"schema_version":4}`）を作るだけ。`git init` しない。名前は架空のもの（例 `Demo Repo`、`sample-app`）。
		- 「ファイルを変えない」は、前後の `read_bytes()` の一致で、「作らない」は `exists()` で確かめる。「対象に書かない」は、前後の対象のディレクトリの全ファイルの道筋と `stat().st_mtime_ns` の組の一致で確かめる。
		- 外部のコマンドもモデルも呼ばない。
		"""
		satisfies: ["R-01", "R-02", "R-03", "R-04"]
	}
}

compatibility: """
- 新しいmoduleを足すだけ。`shipcast repo add|list` は「未実装（終了コード2）」から実際の動きに変わる。ほかの葉の未実装の応答は変えない。
- 設定ファイルの形は epic-00002 の D-02（`schema = 1`）。後で項目を足すときは `shipcast.config` の型と D-04 の許す項目に足し、形を変えるときは `schema` を上げる。
"""

risks: [
	"知らない項目を誤りにするため、後のIssueが設定に項目を足すときは `shipcast.config` を変える必要がある。D-04 の表に足す手順を、型の docstring に書く",
	"`zoneinfo` の名前の確かめは、OSの時間帯のdataに頼る。CI（ubuntu-latest）と macOS は持つ。持たない環境では `timezone` の誤りになる",
	"`os.replace` は同じファイルシステムの中でだけ不可分。一時ファイルを書く先と同じディレクトリに作ることで満たす",
]
