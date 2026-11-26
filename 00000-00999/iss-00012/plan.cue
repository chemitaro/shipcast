package spec

goal: "`main` へ入れる。入った後、`shipcast collect` がSpecDockを使うrepositoryのScopeとtodoの変化を集め、iss-00013（Orca）が同じ形で3つ目のcollectorを足せる。"

steps: {
	"S-01": {
		title:    "架空の値の見本（`tests/fixtures/specdock/`）と、試験の偽物の `subprocess.run`"
		text:     "D-02、D-05。`tests/fixtures/specdock/` に `scope-list.json`・`todo-list.json`・`gh-issue-list.json` を、D-02 の項目の名前と入れ子のまま、架空の値で書く。見本には T-01・T-02 の場合（日の境の4つの時刻、前の日に登録してその日に完了したtodo、その日に登録して取り消したtodo、サブタスク、`number` のないScope、`backend` が local のScope、再び開いたIssue）を入れる。`tests/test_collect_specdock.py` に、見本を読んで argv ごとに返し、argv を記録する偽物の `subprocess.run` と、`spec-dock/workspace.json` を置いた `tmp_path` のrepositoryを作る補助を書く。完了の条件：見本がJSONとして読め、実際の出力から写した値（手元の題名、path、repository名）がないこと（`rg` で確かめる）。`uv run ruff check` が通る。"
		realizes: ["R-03"]
		session:  "impl"
		status:   "todo"
	}
	"S-02": {
		title:    "`SpecDockCollector`（`shipcast.collect.specdock`）と登録"
		text:     "D-01、D-03、D-04。T-01〜T-05 を `tests/test_collect_specdock.py` に先に書いて落ちることを確かめ（Red）、`src/shipcast/collect/specdock.py` に `SpecDockCollector` を書き、`src/shipcast/collect/__init__.py` を `COLLECTORS = (GitCollector(), SpecDockCollector())` にして通す（Green）。完了の条件：`test_commands` がすべて終了コード0。"
		realizes: ["R-01", "R-02", "R-03", "F-01", "F-02"]
		after:    ["S-01"]
		session:  "impl"
		status:   "todo"
	}
}

tests: {
	"T-01": {
		title:    "見本（tz Asia/Tokyo、日 2026-11-26）から、`createdAt` が 2026-11-25T15:00:00Z と 2026-11-26T14:59:59Z のScopeが `scope_opened`、`CLOSED` で `closedAt` がその日のScopeが `scope_closed` になり、2026-11-25T14:59:59Z・2026-11-26T15:00:00Z のもの、`number` のないScope、`backend` が local のScope、`OPEN` に戻ったIssueの `closedAt` は入らない。各Eventの `id`（`event_id(\"specdock\", \"demo\", \"scope:<id>:opened\")` など）、`source`、`repo_id`、`kind`、`at`、`title`、`refs`、`body` の行（`閉じた理由` を含む）が D-03 のとおり"
		verifies: ["R-01"]
	}
	"T-02": {
		title:    "見本から、その日に登録したtodo（今 `open`、`done`、`cancelled` のどれも）が `todo_open`、前の日に登録してその日に `resolution.at` のある `done` のtodoが `todo_done` になり、前の日に登録して開いたままのtodo、取消し、サブタスクは入らない。`body` の行（`今の状態`、`期限`、`関連するScope`、`登録した側`、`完了した側`、`選んだ選択肢`、`記録`）と `refs` が D-03 のとおりで、空・`null` の行がない。todo list の `repositories[]` の `status` が `ok` でない見本で、警告 `todoのカタログを読めません: ` が入る"
		verifies: ["R-02"]
	}
	"T-03": {
		title:    "`gh` が `FileNotFoundError`、`TimeoutExpired`、終了コード1（標準エラーに架空の認証の誤り）、壊れたJSON、`createdAt` の読めない要素のとき、`CollectError` にならず、警告が `gh issue list を読めませんでした（example-org/demo-app）: ` で始まり、Scopeの出来事が0件で、todoの出来事は T-02 と同じ。gh の見本の件数を `issue_limit` と同じにすると（`SpecDockCollector(issue_limit=<件数>)`）、Issueが上限以上の警告が入る"
		verifies: ["F-01"]
	}
	"T-04": {
		title:    "`spec-dock` が `FileNotFoundError`、`TimeoutExpired`、標準出力が壊れたJSON、失敗の封筒（`status` `failed`、`error.code` `GIT_FAILED`、終了コード5。文に `GIT_FAILED: ` を含む）、終了コード1で標準出力が空（文が標準エラーの最後の行を含む）、終了コード0で `status` が `failed` の封筒、`data.result.items` が配列でない、のとき、scope list と todo list のそれぞれで、D-04 の文の `CollectError` になる（文に `<sub>` とpathか理由を含む）。`spec-dock/workspace.json` のないrepositoryでは、偽物の `subprocess.run` が一度も呼ばれず、`CollectResult()` と同じ（Eventも警告も0件）"
		verifies: ["R-03", "F-02"]
	}
	"T-05": {
		title:    "T-01 の収集で記録した argv が、D-02 の3つの形とちょうど同じ（`spec-dock scope list`、`spec-dock todo list`、`gh issue list --repo example-org/demo-app ...` の順、ほかの呼び出しがない）で、`env` に `GH_PROMPT_DISABLED=1` がある。`collect_repo`（本物の `Store(tmp_path)`、`collectors=(SpecDockCollector(),)`）が `errors` なしで保存し、二度目の `saved` が0。見本の題名を空にしたScopeとtodoが `（題名のないScope）`・`（題名のないtodo）` になる。`COLLECTORS` の `name` の並びが `[\"git\", \"specdock\"]`"
		verifies: ["R-01", "R-03"]
	}
}

verification: "`test_commands` を順に流し、すべて終了コード0。PRを作った後に、GitHub ActionsのCIの合格を `github-pr-checks` で観測する。"
rollback:     "PRを戻す（revert）だけで元に戻る。状態に保存したEventは、利用者の手元のSQLiteにだけあり、同じIDで集め直せば増えない。"
exit:         "PRが最終品質ゲートとCIに合格し、タスク担当が統括にPR・合格のコミット・CIの結果を報告した時点で、このIssueの作業は終わる。マージと `spec-dock work finish` は統括が行う。"

// 関門（coding-task）。保証レベル light の既定と、本人の決定 18〜21（init-00001 の plan.cue の delivery）に従う。
gates: {
	spec_review: "Claude `spec-reviewer`（Opus 5.5 / medium）。P0・P1がなくなるまで、3回まで"
	checkpoints: "なし。理由：手順は2つで、1人の実装担当が続けて書き、どれもこのIssueの中の新しいmoduleと試験で、既存のコードの変更は `__init__.py` の2行だけ。途中で止めて見る利得が小さい"
	final_quality_gate: {
		scope:          "開始のコミット（統括が作ったworktreeの作業の始めの `HEAD`、`119ec95`）から S-02 の後の `HEAD` まで"
		perspectives:   ["functional-correctness", "requirements-closure", "test-adequacy", "security-baseline"]
		test_commands:  ["uv sync --locked", "uv run ruff check", "uv run pytest -q"]
		record_paths:   ["spec-dock/initiatives/00000-00999/iss-00012/report.md（SpecDockの自動の保存で記録する。Gitのcommitは要らない）"]
		second_opinion: "none"
	}
	merge:            "agent"
	merger:           "統括。タスク担当と実装担当はマージしない（本人の決定 21）。条件は `coding-task` の `references/merge.md`（CIの合格の観測を含む）"
	merge_permission: "本人の「PR のマージは各ワーカーが行わず、統括（Antigravity）が行う」（2026-11-26、`content/decisions/20261126-journal-format-and-hackathon-plan.md` の 21。init-00001 の `plan.cue` の `delivery`）"
	pr:               "branchは `chemitaro/iss-00012`（統括が作ったworktreeのbranch）。PRの本文に、合格のコミット、最終品質ゲートの結果、CIの結果を書く。Issueを自動で閉じる書き方（Closes #12）は使わない"
}

execution: {
	sessions: {
		spec: {task: "仕様化（起動した側が選んだ値の記録）", provider: "claude", model: "Claude Opus 5.5", effort: "medium", rationale: "統括が起動したOrcaの作業者。値は起動した側が方針§2の light のタスク担当の行から決めた（事実の記録）"}
		owner: {task: "タスク担当（仕様、説明資料、レビュー、最終品質ゲート、PR、CIの観測）", provider: "claude", model: "Claude Opus 5.5", effort: "medium", rationale: "方針§2のタスク担当の light の行。spec と同じセッション"}
		impl: {task: "実装（S-01、S-02）。このworktreeで起動するOrcaの作業者", provider: "codex", model: "GPT-6.2 Sol", effort: "medium", rationale: "方針§2の、テストで確かめられる実装（バックエンド）の行、本人の決定 19、統括の依頼"}
	}
	reviews: {
		spec_review: {role: "仕様のレビューの `spec-reviewer`", model: "Claude Opus 5.5", effort: "medium"}
		final_gate: {role: "最終品質ゲートの `quality-gate-reviewer`", after: "S-02", model: "Claude Opus 5.5", effort: "medium"}
	}
	assignment:   "S-01, S-02 → impl（連続）"
	same_session: "なし（手順は2つだが、実装担当の提供元がタスク担当と違い、統括の依頼が Codex の実装担当を名指すため、別のセッションにする）"
}
