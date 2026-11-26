package spec

design: {
	"D-01": {
		title: "Pythonのpackageと開発の土台"
		text: """
		- Python 3.12以上、`uv` で管理。`src/shipcast/`、`tests/`、`pyproject.toml`。依存は少なく（標準の `argparse`、`tomllib`、`sqlite3`、`http.server`）。
		- 試験は `pytest`、整形と検査は `ruff`。
		- `AGENTS.md` の「Gitと検証」に、検証のcommand（`uv run pytest -q`、`uv run ruff check`）を書く。
		"""
		satisfies: ["R-01"]
	}
	"D-02": {
		title: "設定ファイル `config.toml` の形"
		text: """
		```toml
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

		[[repos]]
		id = "shipcast"
		path = "/abs/path/to/shipcast"
		ref = "main"
		title = "shipcast"
		orca = true
		```
		読み込みは `tomllib`。`repo add` は、`[[repos]]` の塊を末尾に足す（既存の行は書き換えない）。
		"""
		satisfies: ["R-02", "F-01"]
	}
	"D-03": {
		title: "データの型（`shipcast.model`）"
		text: """
		- **Event**：`id`（出所と元のIDのハッシュ）、`repo_id`、`source`（git｜specdock｜orca）、`kind`（commit、merge、scope_opened、scope_closed、todo_open、todo_done、conversation など）、`at`（ISO 8601）、`title`、`body`、`refs`（SHA、URL、Scope ID）、`actor`
		- **Story**：`id`、`repo_id`、`date`、`title`、`what`、`why`、`notice`（人が知っておくべきこと）、`waiting`（人を待つこと）、`event_ids`、`neta`（`score` 0〜3、`reason`、`channels`）
		- **Entry**：`repo_id`、`date`、`path`、`analyst`、`writer`、`story_ids`、`generated_at`
		dataclassで書き、JSONとの行き来の関数を付ける。
		"""
		satisfies: ["R-03"]
	}
	"D-04": {
		title: "状態の置き場（`shipcast.state`）"
		text:  "SQLiteの表：`events`（主キー id）、`stories`、`entries`、`runs`（開始・終了・結果・誤り）、`neta_ledger`（話題ごとのポイントと、消化済みか）。`INSERT OR IGNORE` で重複を除く。"
		satisfies: ["R-04"]
	}
	"D-05": {
		title: "日誌のパスと前付けの契約（`shipcast.model`）"
		text: """
		全Epicの共通の契約。iss-00010 が定数と関数にし、ほかのIssueはこれだけを使う（パスや項目の名前を各所に書かない）。

		- パス：`journal_path(journal_dir, repo, day) -> Path` が `<journal_dir>/<repo>/<YYYY>/<YYYY-MM-DD>.md`。`repo` は設定の `repos.id`（英小文字・数字・`-` だけ）。
		- 前付け（`---` で囲む塊。1行に `key: value` の平らな形だけで、YAMLのライブラリに頼らない）：

		| 項目 | 必須 | 書く段 | 例 |
		|---|---|---|---|
		| `title` | 必須 | 書く | `shipcast の開発日誌 2026-11-26` |
		| `lead` | 必須 | 書く | 1〜2文の要約 |
		| `date` | 必須 | 書く | `2026-11-26` |
		| `repo` | 必須 | 書く | `shipcast` |
		| `category` | 任意 | 書く | `開発日誌` |
		| `analyst`・`writer` | 任意 | 書く | `codex/gpt-6.2-sol` |
		| `generated_at` | 任意 | 書く | ISO 8601 |
		| `schema` | 任意 | 書く | `1` |

		- `read_frontmatter(path) -> JournalMeta` と `write_frontmatter(meta) -> str`。読む側（表紙・一覧）は必須の項目だけに頼る。
		"""
		satisfies: ["R-05"]
	}
	"D-06": {
		title:     "CI（GitHub Actions）"
		text:      "`.github/workflows/ci.yml`。PRとmainへのpushで、`uv sync` の後に `uv run ruff check` と `uv run pytest -q` を流す。外部のモデルは呼ばない（試験は fake の経路）。統括がマージするときの、CIの合格の観測に使う。"
		satisfies: ["R-01"]
	}
}
