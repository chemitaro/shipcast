package spec

goal: "Wave 2 として、iss-00009 と並行に `main` へ入れる。入った後、収集（iss-00011）・分析（iss-00015）・執筆（iss-00016）・配信（iss-00017）が、型・状態・日誌の契約を読み込んで始められる。"

steps: {
	"S-01": {
		title:    "型・ID・JSONの行き来（`shipcast.model`）"
		text:     "D-01〜D-04。T-01〜T-04 を `tests/test_model.py` に先に書いて落ちることを確かめ（Red）、`src/shipcast/model.py` に `ModelError`、`Event`・`Neta`・`Story`・`Entry`、`event_id`・`story_id`、`to_dict`・`to_json`・`from_dict`・`from_json` を書いて通す（Green）。完了の条件：T-01〜T-04 が通り、`uv run ruff check` が通る。"
		realizes: ["R-01", "R-03", "F-01"]
		session:  "impl"
		status:  "done"
	}
	"S-02": {
		title:    "日誌のパスと前付けの契約（`shipcast.model`）"
		text:     "D-05。T-11〜T-13 を `tests/test_journal.py` に先に書いて Red を確かめ、`src/shipcast/model.py` に `JournalFormatError`、`JOURNAL_REQUIRED_FIELDS`・`JOURNAL_FIELDS`、`JournalMeta`、`journal_path`、`write_frontmatter`、`parse_journal`、`read_frontmatter` を足して Green。完了の条件：T-11〜T-13 と S-01 の試験が通り、`uv run ruff check` が通る。"
		realizes: ["R-04", "F-02", "F-04"]
		after: ["S-01"]
		session: "impl"
		status:  "done"
	}
	"S-03": {
		title:    "SQLiteの状態の置き場（`shipcast.state`）"
		text:     "D-06、D-07。T-05〜T-10 を `tests/test_state.py` に先に書いて Red を確かめ、`src/shipcast/state.py` に `StateError`、`Run`、`Store` と5つの表を書いて Green。完了の条件：`test_commands` がすべて終了コード0。"
		realizes: ["R-02", "R-03", "F-03"]
		after: ["S-02"]
		session: "impl"
		status:  "done"
	}
}

tests: {
	"T-01": {title: "架空の Event・Story・Entry を `to_json`→`from_json`、`to_dict`→`from_dict` で戻すと元と等しい（任意の項目を省いた値と、全部を埋めた値の両方）", verifies: ["R-01"]}
	"T-02": {title: "`to_dict` の鍵が D-03 の順で、最上位に `schema: 1` があり、neta には `schema` がない。`date` が `YYYY-MM-DD`、時刻が元の時差のISO 8601", verifies: ["R-01"]}
	"T-03": {title: "`event_id` が同じ引数で同じ16桁の英小文字の16進数になり、`source`・`repo_id`・`native_id` のどれかを変えると変わる。`story_id` が `event_ids` の順と重複に依らず、空なら `ModelError`", verifies: ["R-01", "R-03"]}
	"T-04": {title: "F-01 の各場合（必須の項目がない、文字列でない、`schema` が1でない・ない、`source` が知らない値、`at` に時差がない、`date` に `datetime`、`neta.score` が4・-1・`True`・`\"2\"`、`repo_id` が `Demo`・`a/b`・空、JSONでない文字列）が、項目の名前を含む `ModelError` になる。知らない鍵は捨てて読める", verifies: ["F-01"]}
	"T-05": {title: "`Store(tmp_path / \"state\")` が、ないディレクトリを作り、`state.sqlite3` に5つの表と `user_version = 1` を作る。開き直しても誤りにならない", verifies: ["R-02"]}
	"T-06": {title: "`events_for(\"demo-app\", 2026-11-26, tz=+09:00)` が、その日の0:00と23:59の Event を時刻の順に返し、前日の23:59・翌日の0:00・ほかのrepositoryの Event を返さない。時差の違う Event（+09:00 と +00:00）も瞬間の順に並ぶ", verifies: ["R-02"]}
	"T-07": {title: "Story・Entry・Run を保存して `stories_for`（保存した順）・`entry_for`・`runs_for` で読むと等しい。Entry のない日は `None`。`Store` を閉じて開き直しても読める", verifies: ["R-02"]}
	"T-08": {title: "点数2と3の話題を `add_neta` すると `neta_balance` が5、`unconsumed_neta` が点数の高い順、`consume_neta` で1つ消化すると残りの点数になり、戻り値が消化した件数", verifies: ["R-02"]}
	"T-09": {title: "同じ Event の一覧を二度 `add_events` すると、二度目の戻り値が0で件数が同じ。同じIDの Story・同じ日の Entry を二度保存すると1件で後の内容。同じ話題の二度目の `add_neta` は `False` で残高が同じ", verifies: ["R-03"]}
	"T-10": {title: "`user_version = 2` の置き場で `StateError`（ファイルのバイト列が変わらない）、SQLiteでないファイルで `StateError`。どちらも誤りの文にパスがある", verifies: ["F-03"]}
	"T-11": {title: "`journal_path(tmp_path, \"shipcast\", date(2026, 11, 26)) == tmp_path / \"shipcast\" / \"2026\" / \"2026-11-26.md\"`。何も作らない。`repo` が `../x`・`A`・`a/b`・空なら `ModelError`", verifies: ["R-04", "F-04"]}
	"T-12": {title: "必須だけの `JournalMeta` と全部の項目の `JournalMeta` を `write_frontmatter` で書き、本文を足して `parse_journal` で読むと元の値と本文に戻る。ファイルに書いて `read_frontmatter` でも同じ。`:` を含む題名、知らない鍵、空の任意の項目、空白の行を読める", verifies: ["R-04"]}
	"T-13": {title: "`lead` と `date` が欠けた前付けで、2つを名指す `JournalFormatError`。先頭が `---` でない・閉じがない・`:` のない行・同じ鍵が2回・読めない `date`／`schema` で `JournalFormatError`。改行・前後の空白・空の値を持つ `JournalMeta` は作れない", verifies: ["R-04", "F-02"]}
}

verification: "`test_commands` を順に流し、すべて終了コード0。PRを作った後に、GitHub ActionsのCIの合格を `github-pr-checks` で観測する。"
rollback:     "PRを戻す（revert）だけで元に戻る。状態は利用者の手元のSQLiteだけで、このIssueの時点では書く道具がまだない。"
exit:         "PRが最終品質ゲートとCIに合格し、タスク担当が統括にPR・合格のコミット・CIの結果を報告した時点で、このIssueの作業は終わる。マージと `spec-dock work finish` は統括が行う。"

// 関門（coding-task）。保証レベル standard の既定と、本人の決定 18〜21（init-00001 の plan.cue の delivery）に従う。
gates: {
	spec_review: "Claude `spec-reviewer`（Opus 5.5 / high）。P0・P1がなくなるまで、3回まで"
	checkpoints: "なし。理由：手順は3つで、1人の実装担当が続けて書き、どれもこのIssueの中の新しいmoduleで、後の手順が依る境界（型）は S-01 の試験と最終品質ゲートの `api-contract` の観点で確かめる。後のIssueは、このPRがマージされるまで読み込まないので、途中で止めて見る利得が小さい"
	final_quality_gate: {
		scope:          "開始のコミット（統括が作ったworktreeの作業の始めの `HEAD`、`279f747`）から S-03 の後の `HEAD` まで"
		perspectives:   ["functional-correctness", "requirements-closure", "test-adequacy", "api-contract"]
		test_commands:  ["uv sync --locked", "uv run ruff check", "uv run pytest -q"]
		record_paths:   ["spec-dock/initiatives/00000-00999/iss-00010/report.md（SpecDockの自動の保存で記録する。Gitのcommitは要らない）"]
		second_opinion: "none"
	}
	merge:            "agent"
	merger:           "統括（Antigravity）。タスク担当と実装担当はマージしない（本人の決定 21）。条件は `coding-task` の `references/merge.md`（CIの合格の観測を含む）"
	merge_permission: "本人の「PR のマージは各ワーカーが行わず、統括（Antigravity）が行う」（2026-11-26、`content/decisions/20261126-journal-format-and-hackathon-plan.md` の 21。init-00001 の `plan.cue` の `delivery.gates_by_level.standard.merge`）"
	pr:               "branchは `chemitaro/iss-00010`（統括が作ったworktreeのbranch）。PRの本文に、合格のコミット、最終品質ゲートの結果、CIの結果を書く。Issueを自動で閉じる書き方（Closes #10）は使わない"
}

execution: {
	sessions: {
		spec: {task: "仕様化（起動した側が選んだ値の記録）", provider: "claude", model: "Claude Opus 5.5", effort: "medium", rationale: "統括（Antigravity）が起動したOrcaの作業者。値は起動した側が方針§2の standard のタスク担当の行から決めた（事実の記録）"}
		owner: {task: "タスク担当（仕様、説明資料、レビュー、最終品質ゲート、PR、CIの観測）", provider: "claude", model: "Claude Opus 5.5", effort: "medium", rationale: "方針§2のタスク担当の standard の行。spec と同じセッション"}
		impl: {task: "実装（S-01〜S-03）。このworktreeで起動するOrcaの作業者", provider: "codex", model: "GPT-6.2 Sol", effort: "medium", rationale: "方針§2の、テストで確かめられる実装（バックエンド）の行と本人の決定 19"}
	}
	reviews: {
		final_gate: {role: "最終品質ゲートの `quality-gate-reviewer`", after: "S-03", model: "Claude Opus 5.5", effort: "medium"}
	}
	assignment:   "S-01, S-02, S-03 → impl（連続）"
	same_session: "なし（実装担当の提供元がタスク担当と違うため、別のセッションにする）"
}
