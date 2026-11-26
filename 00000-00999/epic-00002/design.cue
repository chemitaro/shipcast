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
}
