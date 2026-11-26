package spec

schema: "specdock/v1"

assurance: {
	level:  "light"
	reason: "まだコードのないrepositoryに、packageの骨組みと検証の土台を足すだけで、既存の利用者も外部への影響もない。PRを戻せば元に戻る"
}

purpose: "Pythonのpackageと `shipcast` のCLIの骨組みを作り、手元とCIで試験と検査が回る状態にする。ほかのIssueは、ここで登録した下位のコマンドの中身だけを書けばよい状態にする。"

background: """
shipcastのrepositoryには、まだコードがない（`content/` と `spec-dock/` の文書だけ）。E1（epic-00002）の最初のIssueとして、全Issueが使う入口（`shipcast` のコマンド）と、検証の約束（`uv run pytest -q`、`uv run ruff check`）と、統括がマージの前に観測するCI（GitHub Actions）を入れる。

親の epic-00002 の R-01（CLIと検証）をこのIssueが受け持つ。設定の読み込み（iss-00009）、型と状態（iss-00010）は、このIssueの後に並行に作る。
"""

includes: [
	"`pyproject.toml`、`uv.lock`、`src/shipcast/`、`tests/` の骨組み（`uv init --package` 相当）",
	"`shipcast` の入口と、7つの下位のコマンド（とその下の `repo add|list`、`draft x`、`schedule install|uninstall`）の登録",
	"中身のない下位のコマンドの「未実装」の応答",
	"`AGENTS.md` の「Gitと検証」への検証のcommand",
	"GitHub Actionsの CI（`.github/workflows/ci.yml`）",
]

excludes: [
	"各下位のコマンドの中身（iss-00009 以降が作る）",
	"設定ファイルの読み込み、状態の置き場、型（iss-00009、iss-00010）",
	"外部のモデルの呼び出し（`agy`、`codex`、`claude` を一切呼ばない）",
	"PyPIなどへの公開、リリースの自動化",
]

requirements: {
	"R-01": {
		title: "`uv run shipcast --help` が、7つの下位のコマンドを示す"
		text:  "下位のコマンドは `repo`、`collect`、`write`、`run`、`serve`、`draft`、`schedule`。`repo` の下に `add` と `list`、`draft` の下に `x`、`schedule` の下に `install` と `uninstall` を登録する。説明の文は日本語。"
		acceptance: [
			"`uv run shipcast --help` の出力に、7つの名前がすべて出て、終了コードが0",
			"`uv run shipcast repo --help`、`draft --help`、`schedule --help` に、その下のコマンドの名前が出る",
			"`uv run python -m shipcast --help` も同じ出力になる",
		]
	}
	"R-02": {
		title: "`uv run pytest -q` と `uv run ruff check` が通る"
		acceptance: [
			"新しいcloneで `uv sync --locked` の後、2つのcommandが終了コード0で終わる",
			"実行時の依存（`[project] dependencies`）は空で、標準のライブラリだけを使う。開発の依存は `pytest` と `ruff` だけ",
		]
	}
	"R-03": {
		title: "`AGENTS.md` の「Gitと検証」に、検証のcommandが書かれている"
		text:  "今の「検証のcommandは、実装を始めるときにここへ書きます（まだコードはありません）。」の行を置き換える。"
		acceptance: [
			"`uv sync --locked`、`uv run ruff check`、`uv run pytest -q` が、この順で書かれている",
			"試験とエージェントの作業では外部のモデルを呼ばない（`fake` の経路を使い、`agy` を呼ばない）ことが書かれている",
		]
	}
	"R-04": {
		title: "PRとmainへのpushで、GitHub ActionsがR-02と同じ検証を流す"
		text:  "統括がPRをマージするときの条件（`coding-task` のマージの規則の、CIの合格の観測）に使う。"
		acceptance: [
			"`.github/workflows/ci.yml` が、`pull_request` と `main` への `push` で動き、`uv sync --locked`、`uv run ruff check`、`uv run pytest -q` を流す",
			"このIssueのPRで、CIの検査が1つ以上観測され、合格している",
			"workflowの権限は `contents: read` だけで、秘密情報（secrets）を使わない",
		]
	}
}

failures: {
	"F-01": {
		title: "中身のない下位のコマンドは、何も書かずに「未実装」と示して終了コード2で止まる"
		text:  "標準エラーに `shipcast <コマンド>: 未実装です（<作るIssueのID> で作ります）` を出す。ファイルやディレクトリ（設定、状態、日誌の置き場）を作らない。"
	}
	"F-02": {
		title: "知らない下位のコマンドや引数は、使い方を示して終了コード2で止まる"
	}
}

constraints: [
	"repositoryはpublic。秘密情報、個人の設定、実在の非公開の情報をコード・試験・CIに書かない（AGENTS.md）",
	"Python 3.12以上。`uv` で管理する",
	"エージェント（Claude Code・Codex・Orcaの作業者）は `agy` を呼ばない。このIssueには外部のモデルの呼び出しがない",
	"開発は通常の `coding-task`。マージは統括（Antigravity）が行い、タスク担当と実装担当はマージしない（`content/decisions/20261126-journal-format-and-hackathon-plan.md` の 18〜21）",
]

decisions: [
	"中身のない下位のコマンドの終了コードは2（epic-00002 の設計のとおり。argparseの使い方の誤りと同じ「使えない」の値）",
	"CIを入れるのは、統括のマージの条件にCIの合格の観測が要るため（同じ決定文書の「エージェントが決めた細部」）",
]
