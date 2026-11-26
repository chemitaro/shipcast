package spec

goal: "Wave 1 として、1人で最初にmainへ入れる。入った後、iss-00009 と iss-00010 が並行に始められる。"

steps: {
	"S-01": {
		title:    "packageと開発の土台を作る"
		text:     "D-01。`uv init --package --build-backend uv` 相当の形、`uv add --dev pytest ruff`、ruffとpytestの設定、`uv.lock`。完了の条件：新しいcloneで `uv sync --locked` と `uv run ruff check` と `uv run pytest -q` が通る（この時点の試験は、packageが読み込めることの1件でよい）。"
		realizes: ["R-02"]
		session:  "impl"
		status:   "done"
	}
	"S-02": {
		title:    "CLIの入口と下位のコマンドの表"
		text:     "D-02、D-03。T-01〜T-05 を先に書いて落ちることを確かめ（Red）、`shipcast.cli` で通す（Green）。完了の条件：T-01〜T-05 が通り、`uv run shipcast --help` が7つの名前を示す。"
		realizes: ["R-01", "F-01", "F-02"]
		after: ["S-01"]
		session: "impl"
		status:  "done"
	}
	"S-03": {
		title:    "CIのworkflow"
		text:     "D-05。`.github/workflows/ci.yml` と、その中身の試験 T-07。完了の条件：T-07 が通る（CIの実際の合格は、PRを作った後に T-08 で観測する）。"
		realizes: ["R-04"]
		after: ["S-02"]
		session: "impl"
		status:  "done"
	}
	"S-04": {
		title:    "`AGENTS.md` の「Gitと検証」に検証のcommandを書く"
		text:     "D-04。エージェントが読む指示の文書なので、方針（指示・skillなどの文書を書く手順は、タスク担当が自分で書く）により、実装担当に頼まずタスク担当が書く。完了の条件：T-06 が通る。"
		realizes: ["R-03"]
		after: ["S-03"]
		session: "owner"
		status:  "done"
	}
}

tests: {
	"T-01": {title: "`main([\"--help\"])` が7つの下位のコマンドの名前を出し、終了コード0", verifies: ["R-01"]}
	"T-02": {title: "`repo --help`・`draft --help`・`schedule --help` が、その下のコマンドの名前を出す", verifies: ["R-01"]}
	"T-03": {title: "`python -m shipcast --help` が同じ出力になる（`subprocess` で `sys.executable -m shipcast`）", verifies: ["R-01"]}
	"T-04": {title: "未実装の葉（全部の葉を引数で回す）が、標準エラーに作るIssueのIDを示し、終了コード2で、`tmp_path` の下に何も作らない", verifies: ["F-01"]}
	"T-05": {title: "知らない下位のコマンド・知らない引数・下位のコマンドなしで、使い方を示して終了コード2", verifies: ["F-02"]}
	"T-06": {title: "`AGENTS.md` に、3つの検証のcommandがこの順にあり、`agy` を呼ばない旨がある", verifies: ["R-03"]}
	"T-07": {title: "`ci.yml` に、`pull_request`、`main` への `push`、`contents: read`、3つの検証のcommandがある", verifies: ["R-04"]}
	"T-08": {title: "PRで、CIの検査が1つ以上観測され、合格している（`github-pr-checks` で観測する）", verifies: ["R-04"]}
	"T-09": {title: "新しいcloneで `uv sync --locked`、`uv run ruff check`、`uv run pytest -q` が終了コード0", verifies: ["R-02"]}
}

verification: "test_commands を順に流し、すべて終了コード0。PRを作った後に T-08 でCIの合格を観測する。"
rollback:     "PRを戻す（revert）だけで元に戻る。データの移行や、外部の状態の変更はない。"
exit:         "PRが最終品質ゲートとCIに合格し、タスク担当が統括にPR・合格のコミット・CIの結果を報告した時点で、このIssueの作業は終わる。マージは統括が行う。"

// 関門（coding-task）。保証レベル light の既定と、本人の決定 18〜21（init-00001 の plan.cue の delivery）に従う。
gates: {
	spec_review:  "Claude `spec-reviewer`（Opus 5.5 / medium）。P0・P1がなくなるまで、3回まで"
	checkpoints:  "なし（light の既定。すべての手順の後、最終品質ゲートへそのまま進む）"
	final_quality_gate: {
		scope:            "開始のコミット（統括が作るworktreeの、作業の始めの `HEAD`）から S-04 まで"
		perspectives:     ["functional-correctness", "requirements-closure", "test-adequacy"]
		test_commands:    ["uv sync --locked", "uv run ruff check", "uv run pytest -q", "uv run shipcast --help"]
		record_paths:     ["spec-dock/initiatives/00000-00999/iss-00008/report.md（SpecDockの自動の保存で記録する。Gitのcommitは要らない）"]
		second_opinion:   "none"
	}
	merge:        "agent"
	merger:       "統括（Antigravity）。タスク担当と実装担当はマージしない（本人の決定 21）。条件は `coding-task` の `references/merge.md`（CIの合格の観測を含む）"
	merge_permission: "本人の「PR のマージは各ワーカーが行わず、統括（Antigravity）が行う」（2026-11-26、`content/decisions/20261126-journal-format-and-hackathon-plan.md` の 21）。light なので、マージの規則の上では許可の記録は要らないが、統括がマージする根拠として写す"
	pr:           "branchは `iss-00008`。PRの本文に、合格のコミット、最終品質ゲートの結果、CIの結果を書く。Issueを自動で閉じる書き方（Closes #8）は使わない"
}

execution: {
	sessions: {
		spec: {task: "仕様化（起動した側が選んだ値の記録）", provider: "claude", model: "Claude Opus 5.5", effort: "high", rationale: "統括（Antigravity）が起動したOrcaの作業者。値は起動した側が決めた（事実の記録）"}
		owner: {task: "タスク担当（仕様、レビュー、最終品質ゲート、PR、S-04 の文書）", provider: "claude", model: "Claude Opus 5.5", effort: "medium", rationale: "方針§2のタスク担当の light の行。S-04 は指示の文書なので、同じセッションで書く例外"}
		impl: {task: "実装（S-01〜S-03）。Orcaの作業者", provider: "codex", model: "GPT-6.2 Sol", effort: "medium", rationale: "方針§2の、テストで確かめられる実装の行と本人の決定 19"}
	}
	reviews: {
		final_gate: {role: "最終品質ゲートの `quality-gate-reviewer`", after: "S-04", model: "Claude Opus 5.5", effort: "medium"}
	}
	assignment:   "S-01, S-02, S-03 → impl（連続）、S-04 → owner（同じセッションの例外：エージェントが読む指示の文書を書く手順）"
	same_session: "S-04 だけ。理由：`AGENTS.md` はエージェントが読む指示の文書で、方針§2は、この種の文書をタスク担当が自分で書くと定める"
}
