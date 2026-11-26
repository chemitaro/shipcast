package spec

goal: "先に下書きの中身（Xの長さ、応答の検査、書き手への依頼、プロンプト）を作り、その上に下書きのファイル・消化・CLI を積む。試験は fake の経路の `responder` と一時ディレクトリだけで行う。"

steps: {
	"S-01": {
		status:   "done"
		title:    "Xの長さ・応答の検査・書き手への依頼と `prompts/x.md`"
		text:     "D-01・D-02。T-01・T-02 を新しい `tests/test_draft.py` に先に書いて落ちることを確かめ（Red）、`src/shipcast/draft.py`（`X_LIMIT`・`XDraft`・`x_length`・`parse_x_draft`・`XDraftFailed`・`compose_x`）と `src/shipcast/prompts/x.md` を書いて通す（Green）。完了の条件：`test_commands` がすべて終了コード0。"
		realizes: ["R-01"]
		session:  "impl"
	}
	"S-02": {
		status:   "done"
		title:    "下書きのファイル・消化（`make_x_draft`）と CLI の `draft x`"
		text:     "D-03・D-04。T-03・T-04 を `tests/test_draft.py` に先に書いて Red、`draft.py` に `draft_path`・`render_x_draft`・`make_x_draft`・`configure_x`・`run_x` を足し、`cli.py` の配線と `tests/test_cli.py` の未実装の一覧の1行を直して Green。完了の条件：`test_commands` がすべて終了コード0。"
		realizes: ["R-01", "R-02"]
		after:    ["S-01"]
		session:  "impl"
	}
}

tests: {
	"T-01": {title: "`x_length`・`parse_x_draft`：`x_length(\"abc\") == 3`、`x_length(\"日本語\") == 6`、`x_length(\"—\")`（U+2014）が1、`x_length(\"か\\u3099\") == 2`。日本語140字の本文とハッシュタグなしは通り、141字は長さと上限を含む誤り。本文とハッシュタグ `#shipcast` を合わせた全体で上限を超えると誤り。```` ```json ```` の囲みを読める。JSON でない・オブジェクトでない・`text` が空・`\\r` を含む・`https://` を含む・`@demo` を含む・`hashtags` が配列でない・4件・`#` で始まらない・空白を含む・`#123`・重複、のそれぞれで誤りを返し、誤りの文に応答の値を写さない。`hashtags` がなければ空の組。`XDraft.post` は本文と空行とハッシュタグをつなぐ", verifies: ["R-01"]}
	"T-02": {title: "`compose_x`：fake の経路の `responder` が受け取る system が `prompts/x.md` の中身（と JSON の指示）で、入力の `stories` の各要素の鍵が `title`・`what`・`why` だけ（`notice`・`waiting` を渡さない）。1回目に形の誤り、2回目に正しい応答なら、2回目の入力に `previous_errors` があり `XDraft` を返す。2回とも誤りなら `XDraftFailed`（attempts 2）。経路の `RouteError` は頼み直さずに上がる。話題が空なら `ValueError` で経路を呼ばない。`prompts/x.md` が package に入り、`redact` を通しても変わらない", verifies: ["R-01"]}
	"T-03": {title: "`make_x_draft`：`demo-app` に点数3・2・1・1の話題と `demo-lib` の話題を保存した Store で、上位3件で下書きを作ると `state_dir/drafts/demo-app/2026-11-26-x.md` ができ、`render_x_draft` の形（見出し、`:::note` の注意、投稿の本文、長さ `L / 280`、ハッシュタグの案、書き手、使った話題の題名3件）になる。その3件が `unconsumed_stories` から消え、`neta_balance(\"demo-app\")` が1、`demo-lib` は変わらず、`consumed == 3`。同じ日付のファイルがあると `DraftExists` で経路を呼ばずファイルの中身も残高も変わらない。未消化の話題がないと `NoStories` で経路を呼ばずファイルがない。書き手が2回とも誤ると `XDraftFailed` でファイルがなく残高が変わらない。`write_atomic` が失敗すると、残高が変わらない", verifies: ["R-02"]}
	"T-04": {title: "CLI：`SHIPCAST_CONFIG` の一時の設定（経路は `fake`）と、`shipcast.draft.get_route` を `responder` 付きの fake の経路に差し替えた状態で、`main([\"draft\", \"x\", \"--repo\", \"demo-app\", \"--date\", \"2026-11-26\"])` が0を返し、標準出力に下書きの道筋と「shipcastは投稿しません」が出て、ファイルができ、話題が消化済みになる。もう一度同じ日付で実行すると1で、経路を呼ばない。登録されていない `--repo` は1。未消化の話題がないと1。書き手が2回とも誤ると1でファイルがない。`draft x --help` に `--repo` と `--date` が出る。`--repo` がないと argparse の誤り（終了コード2）。`tests/test_cli.py` の未実装の一覧に `draft x` がなく、ほかの未実装の試験は通る", verifies: ["R-01", "R-02"]}
}

verification: "`test_commands` を順に流し、すべて終了コード0。試験は fake の経路の `responder` だけで、外部のモデルと `agy` を呼ばない。PRを作った後に、GitHub ActionsのCIの合格を `github-pr-checks` で観測する。"
rollback:     "PRを戻す（revert）だけで元に戻る。表の形は変えない。作った下書きのファイルは本人が消せばよい。消化済みにした話題を戻すコマンドはない（台帳の `consumed` を0にすれば戻る。残る危険として記録する）。"
exit:         "PRが最終品質ゲートとCIに合格し、タスク担当が統括にPR・合格のコミット・CIの結果・closure.md を報告した時点で、このIssueの作業は終わる。マージと `spec-dock work finish` は統括が行う。"

// 関門（coding-task）。保証レベル light の既定と、本人の決定 18〜21（init-00001 の plan.cue の delivery）に従う。
gates: {
	spec_review: "Claude `spec-reviewer`（Opus 5.5 / medium）。P0・P1がなくなるまで、3回まで"
	checkpoints: "なし。理由：手順は2つで、1人の実装担当が続けて書く。S-02 が依る境界（`compose_x` と `parse_x_draft`）は S-01 の試験と最終品質ゲートで確かめる"
	final_quality_gate: {
		scope:          "開始のコミット（このworktreeの作業の始めの `HEAD`、`52ce03d`）から S-02 の後の `HEAD` まで"
		perspectives:   ["functional-correctness", "requirements-closure", "test-adequacy", "security-baseline"]
		reviewer:       "Claude `quality-gate-reviewer`（Opus 5.5 / medium）"
		test_commands:  ["uv sync --locked", "uv run ruff check", "uv run pytest -q"]
		record_paths:   ["spec-dock/initiatives/00000-00999/iss-00020/report.md（SpecDockの自動の保存で記録する。Gitのcommitは要らない）"]
		second_opinion: "none"
	}
	merge:            "agent"
	merger:           "統括。タスク担当と実装担当はマージしない（本人の決定 21）。条件は `coding-task` の `references/merge.md`（CIの合格の観測を含む）"
	merge_permission: "本人の「PR のマージは各ワーカーが行わず、統括が行う」（2026-11-26、`content/decisions/20261126-journal-format-and-hackathon-plan.md` の 21。init-00001 の `plan.cue` の `delivery.gates_by_level`）"
	pr:               "branchは `chemitaro/iss-00020`（統括が作ったworktreeのbranch）。PRの本文に、合格のコミット、最終品質ゲートの結果、CIの結果を書く。Issueを自動で閉じる書き方（Closes #20）は使わず、`Refs #20` にする"
}

execution: {
	sessions: {
		spec: {task: "仕様化（起動した側が選んだ値の記録）", provider: "claude", model: "Claude Opus 5.5", effort: "medium", rationale: "統括が起動したOrcaの作業者。値は起動した側が方針§2の light のタスク担当の行から決めた（事実の記録）"}
		owner: {task: "タスク担当（仕様、説明資料、レビュー、最終品質ゲート、PR、CIの観測）", provider: "claude", model: "Claude Opus 5.5", effort: "medium", rationale: "方針§2のタスク担当の light の行。spec と同じセッション"}
		impl: {task: "実装（S-01・S-02）。このworktreeで起動するOrcaの作業者", provider: "codex", model: "GPT-6.2 Sol", effort: "medium", rationale: "方針§2の、テストで確かめられる実装（バックエンド）の行、本人の決定 19、統括の依頼が Codex の実装担当を名指す"}
	}
	reviews: {
		spec_review: {role: "仕様のレビューの `spec-reviewer`", model: "Claude Opus 5.5", effort: "medium"}
		final_gate: {role: "最終品質ゲートの `quality-gate-reviewer`", after: "S-02", model: "Claude Opus 5.5", effort: "medium"}
	}
	assignment:   "S-01, S-02 → impl（連続）"
	same_session: "なし（手順は2つだが、統括の依頼が Codex の実装担当を名指し、提供元がタスク担当と違うため、別のセッションにする）"
}
