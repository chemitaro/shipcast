package spec

goal: "Wave 2 として、iss-00010 と並行に作り、mainへ入れる。入った後、収集（epic-00003）と夜の実行が `load_config()` と `RepoConfig` を使える。"

steps: {
	"S-01": {
		title: "設定の型と読み込み（`shipcast.config` の読む側）"
		text: """
		D-02〜D-05、D-08 の `DEFAULT_CONFIG_TEXT`。T-01〜T-07 を先に書いて落ちることを確かめ（Red）、`src/shipcast/config.py` の型、`config_path`、`load_config`、`parse_config`、`ConfigError`、`DEFAULT_CONFIG_TEXT` で通す（Green）。
		完了の条件：`uv run pytest -q tests/test_config.py` で T-01〜T-07 が通り、`uv run ruff check` が通る。
		"""
		realizes: ["R-01", "F-01", "F-02"]
		session:  "impl"
		status:   "todo"
	}
	"S-02": {
		title: "`add_repo` と `shipcast repo add`"
		text: """
		D-06、D-07、D-09 の `repo add`、D-01 の `cli.py` の `repo add` の行。T-08〜T-14 を先に書いて落ちることを確かめ（Red）、`shipcast.config.add_repo`・`derive_repo_id`・`toml_string` と `src/shipcast/repo.py` の `configure_add`・`run_add` で通す（Green）。`tests/test_cli.py` の未実装の一覧から `repo add` の1行を外す。
		完了の条件：`uv run pytest -q` の全部と `uv run ruff check` が通る。
		"""
		realizes: ["R-02", "R-04", "F-01"]
		after: ["S-01"]
		session: "impl"
		status:  "todo"
	}
	"S-03": {
		title: "`shipcast repo list`"
		text: """
		D-09 の `repo list`、D-01 の `cli.py` の `repo list` の行。T-15〜T-17 を先に書いて落ちることを確かめ（Red）、`configure_list`・`run_list` で通す（Green）。`tests/test_cli.py` の未実装の一覧から `repo list` の1行を外す。
		完了の条件：`test_commands` がすべて終了コード0。
		"""
		realizes: ["R-03", "F-02"]
		after: ["S-02"]
		session: "impl"
		status:  "todo"
	}
}

tests: {
	"T-01": {title: "epic-00002 の D-02 の見本（`[[repos]]` 1件、`path` は `tmp_path` の下）を `load_config(path)` で読むと、全項目が D-02 の型と値になる（`journal_dir` などの `~` は `HOME` の下に展開される）", verifies: ["R-01"]}
	"T-02": {title: "空のファイル・一部の項目だけのファイル（例 `[models.writer] route = \"fake\"` だけ）を読むと、書かれていない項目が D-02 の既定値になり、`repos == ()`", verifies: ["R-01"]}
	"T-03": {title: "`load_config()` が、`SHIPCAST_CONFIG` があればそこ（`~` を含む値も展開）を、なければ `HOME/.config/shipcast/config.toml` を読む", verifies: ["R-01"]}
	"T-04": {title: "`[[repos]]` 3件を書いた順に `RepoConfig` の `tuple` で返し、省いた `ref`・`title`・`orca` は `main`・`id`・`True`", verifies: ["R-01"]}
	"T-05": {title: "TOMLの文法の誤り（3行目）で `ConfigError`。`str()` に設定の道筋、`line 3`、`直し方:` が入る", verifies: ["F-01"]}
	"T-06": {title: "値の誤り（引数で回す：知らない一番上の項目、`schema = 2`、知らない `timezone`、相対の `journal_dir`、`models.writer.route` が許されない値、`serve.port = true`・`0`・`70000`、`neta.threshold = 0`、`repos` の `id` の欠け・大文字・重複、`path` の欠け・相対、`orca = \"yes\"`、`repos` の知らない項目）で `ConfigError`。`str()` に D-04 の項目の名前（`repos[n]` は1から）と `直し方:` が入る", verifies: ["F-01"]}
	"T-07": {title: "設定ファイルがないと `load_config` が `ConfigError`（`設定ファイルがありません`、`shipcast repo add`）を投げ、何も作らない。`parse_config(DEFAULT_CONFIG_TEXT)` は `parse_config(\"\")` と等しい", verifies: ["F-02", "R-04"]}
	"T-08": {title: "`repo add <偽のrepository>` が終了コード0で、標準出力に `id` と絶対の道筋を示し、`load_config` で読むと末尾に1件増え、`ref`・`title`・`orca` が既定値。`--id`・`--title`・`--ref` を渡すとその値になる", verifies: ["R-02"]}
	"T-09": {title: "コメントと空行を含む既存の設定（末尾に改行がない場合も含む）に `repo add` すると、新しいファイルの先頭が元のバイト列と同じで、2件目を足しても1件目の塊が残る", verifies: ["R-02"]}
	"T-10": {title: "`spec-dock/workspace.json` がない・道筋がない・ファイルを指す、のどれでも終了コード1で、標準エラーに `直し方:`、設定ファイルは作られず（あれば前後でバイト列が同じ）", verifies: ["R-02"]}
	"T-11": {title: "同じ `id`（`--id` で同じ名前）・同じ道筋（別の `--id`、末尾の `/` や `..` を含む書き方でも）を足すと終了コード1で、設定ファイルのバイト列が変わらない", verifies: ["R-02"]}
	"T-12": {title: "設定ファイルがない状態で `repo add` すると、親のディレクトリごと作り、標準出力に作ったことを示し、`load_config` で読むと1件で、ほかの値は空のファイルの既定値と等しい", verifies: ["R-04"]}
	"T-13": {title: "壊れた設定（文法の誤り・値の誤り）への `repo add` と、`repos = [...]` の形の設定への `repo add` は、終了コード1で、ファイルのバイト列が変わらない", verifies: ["F-01", "R-02"]}
	"T-14": {title: "`toml_string` と `derive_repo_id`：`\"`・`\\`・タブ・改行・日本語を含む題名と道筋が、書いて読んで元に戻る。`Demo Repo` → `demo-repo`、`--x__y--` → `x-y`、`日誌` → `\"\"`（`repo add` は `--id` を求めて1）。`repo add` の前後で対象のrepositoryの中身が変わらず、記号のリンクの設定はリンクのまま先が書き換わる", verifies: ["R-02", "R-04"]}
	"T-15": {title: "3件を登録した後の `repo list` が、登録の順に `id\\ttitle\\tpath\\tref` の3行を出し、終了コード0、標準エラーは空", verifies: ["R-03"]}
	"T-16": {title: "`[[repos]]` のない設定での `repo list` は、標準出力が空、標準エラーに `shipcast repo add`、終了コード0", verifies: ["R-03"]}
	"T-17": {title: "設定ファイルがない・壊れているときの `repo list` は、終了コード1で、標準エラーに `直し方:`、標準出力は空、何も作らない。`test_cli.py` の未実装の一覧に `repo add`・`repo list` がなく、ほかの葉は未実装のまま", verifies: ["R-03", "F-01", "F-02"]}
}

verification: "test_commands を順に流し、すべて終了コード0。PRを作った後に、`github-pr-checks` でCIの合格を観測する。"
rollback:     "PRを戻す（revert）だけで、`repo add|list` は未実装の応答に戻る。本人の手元の設定ファイルは、`repo add` が足した末尾の `[[repos]]` の塊を消せば元に戻る。"
exit:         "PRが最終品質ゲートとCIに合格し、タスク担当が統括にPR・合格のコミット・CIの結果を報告した時点で、このIssueの作業は終わる。マージと `spec-dock work finish` は統括が行う。"

// 関門（coding-task）。保証レベル standard の既定と、本人の決定 18〜21（init-00001 の plan.cue の delivery）に従う。
gates: {
	spec_review: "Claude `spec-reviewer`（Opus 5.5 / high。standard の既定）。P0・P1がなくなるまで、3回まで。ChatGPTの2人目はなし"
	checkpoints: "なし（standard の既定。手順は3つで、後に多くの手順が頼る境界はこのIssueの中にない。すべての手順の後、最終品質ゲートへそのまま進む）"
	final_quality_gate: {
		scope:          "開始のコミット（このworktreeの作業の始めの `HEAD`）から S-03 まで"
		perspectives:   ["functional-correctness", "requirements-closure", "test-adequacy", "api-contract", "reliability-recovery"]
		perspectives_reason: "`api-contract`：`shipcast.config` の型と関数は後の全Issueが読む約束。`reliability-recovery`：本人の手元の設定ファイルを書き換えるため、失敗の時に元のまま残るかを見る"
		test_commands:  ["uv sync --locked", "uv run ruff check", "uv run pytest -q", "uv run shipcast --help", "uv run shipcast repo --help"]
		record_paths:   ["spec-dock/initiatives/00000-00999/iss-00009/report.md（SpecDockの自動の保存で記録する。Gitのcommitは要らない）"]
		second_opinion: "none"
	}
	merge:            "agent"
	merger:           "統括（Antigravity）。タスク担当と実装担当はマージしない（本人の決定 21）。条件は `coding-task` の `references/merge.md`（CIの合格の観測を含む）"
	merge_permission: "本人の「PRのマージは統括が行う。各作業者（タスク担当・実装担当）はマージしない。PRと証拠を統括に報告し、統括（Antigravity）がマージする」（2026-11-26、`content/decisions/20261126-journal-format-and-hackathon-plan.md` の 21）"
	pr:               "branchは `iss-00009`（このworktreeの `chemitaro/iss-00009` を SpecDock の作業の開始で揃える）。PRの本文に、合格のコミット、最終品質ゲートの結果、CIの結果を書く。Issueを自動で閉じる書き方（Closes #9）は使わない"
}

execution: {
	sessions: {
		spec: {task: "仕様化（起動した側が選んだ値の記録）", provider: "claude", model: "Claude Opus 5.5", effort: "medium", rationale: "統括が起動したOrcaの作業者（タスク担当）。値は起動した側が方針§2の standard のタスク担当の行で決めた（事実の記録）"}
		owner: {task: "タスク担当（仕様、レビュー、最終品質ゲート、PR、CIの観測）", provider: "claude", model: "Claude Opus 5.5", effort: "medium", rationale: "方針§2のタスク担当の standard の行"}
		impl: {task: "実装（S-01〜S-03）。このworktreeのOrcaの作業者", provider: "codex", model: "GPT-6.2 Sol", effort: "medium", rationale: "方針§2の、テストで確かめられる実装の standard の行と本人の決定 19"}
	}
	reviews: {
		final_gate: {role: "最終品質ゲートの `quality-gate-reviewer`", after: "S-03", model: "Claude Opus 5.5", effort: "medium"}
	}
	assignment:   "S-01, S-02, S-03 → impl（連続）"
	same_session: "なし"
}
