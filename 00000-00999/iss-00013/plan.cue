package spec

goal: "`main` へ入れる。入った後、`shipcast collect` が `orca = true` のrepositoryで、その日に動いたそのrepositoryのOrcaの会話を集め、Orcaが使えなくても警告だけで続く。"

steps: {
	"S-01": {
		title:    "架空の値の見本（`tests/fixtures/orca/`）と、試験の偽物の `subprocess.run`"
		text:     "D-02、D-05。`tests/fixtures/orca/` に `agent-list.json`・`repo-list.json`・会話ごとの `agent-read-<名前>.json` を、D-02 の項目の名前と入れ子のまま、完全に架空の値で書く。見本には T-01・T-04 の場合（main checkoutの会話、登録したpathの外のOrcaのworktreeの会話（`<repo-id>` で結びつく）、配下のpathの会話、ほかのrepositoryの会話、folderのworkspaceの会話、日の境の4つの `updatedAt`、`tool` と `system` の記録、空白だけの発言、発言が0件の会話、`limited` が true の会話、題名が空の会話、同じ `orcaSessionId` の重複）を入れる。`tests/test_collect_orca.py` に、見本を読んで argv ごとに返し、argv を記録する偽物の `subprocess.run` を書く。完了の条件：見本がJSONとして読め、手元の実際のOrcaの記録から写した値（題名、発言、path、セッションID、repositoryの名前）がないこと（`rg` で確かめる）。`uv run ruff check` が通る。"
		realizes: ["R-01"]
		session:  "impl"
		status:   "todo"
	}
	"S-02": {
		title:    "`OrcaCollector`（`shipcast.collect.orca`）と登録"
		text:     "D-01、D-03、D-04。T-01〜T-04 を `tests/test_collect_orca.py` に先に書いて落ちることを確かめ（Red）、`src/shipcast/collect/orca.py` に `OrcaCollector` を書き、`src/shipcast/collect/__init__.py` を `COLLECTORS = (GitCollector(), SpecDockCollector(), OrcaCollector())` にして通す（Green）。完了の条件：`test_commands` がすべて終了コード0。"
		realizes: ["R-01", "R-02", "F-01"]
		after:    ["S-01"]
		session:  "impl"
		status:   "todo"
	}
}

tests: {
	"T-01": {
		title:    "見本（tz Asia/Tokyo、日 2026-11-26）から、`repo.path` と同じpath・その配下のpath・`<repo-id>` が `repo list` の `repo.path` のIDに当たるpathの外のworktreeの会話のうち、`updatedAt` が `1795618800000`（境のちょうど）と `1795705199999` のものが、1つの会話につき1件の `conversation` のEventになり、`1795618799999`・`1795705200000` のもの、ほかのrepository、folderのworkspace、`/home/dev/demo-app-old` のような前方だけが同じpath、発言が0件の会話は入らない。各Eventの `id`（`event_id(\"orca\", \"demo\", \"conversation:<id>:2026-11-26\")`）、`source`、`repo_id`、`kind`、`at`、`title`（空の題名は `（題名のない会話）`）、`actor`、`refs`、`body`（見出しの行、`limited` の行、`[user]`・`[assistant]` のかたまりが古い順、`tool`・`system`・空白だけの発言がない）が D-03 のとおり。重複した `orcaSessionId` は1件だけ"
		verifies: ["R-01"]
	}
	"T-02": {
		title:    "T-01 の収集で記録した argv が、D-02 の3つの形とちょうど同じ（`agent list`、`repo list`、選んだ会話ごとの `agent read orca_session_id:<id> --limit 100 --json` の順、ほかの呼び出しがない。選ばれない会話の `agent read` がない）で、`env` に `NO_COLOR=1` がある。`collect_repo`（本物の `Store(tmp_path)`、`collectors=(OrcaCollector(),)`）が `errors` なしで保存し、二度目の `saved` が0。日を 2026-11-27 にし、見本の `updatedAt` をその日に動かすと、同じ会話が別のIDで保存される。`COLLECTORS` の `name` の並びが `[\"git\", \"specdock\", \"orca\"]`"
		verifies: ["R-01"]
	}
	"T-03": {
		title:    "`orca = false` のrepositoryでは、偽物の `subprocess.run` が一度も呼ばれず、`CollectResult()` と同じ（Eventも警告も0件）"
		verifies: ["R-02"]
	}
	"T-04": {
		title:    "agent list が `FileNotFoundError`、`TimeoutExpired`、`ok` が false の物（架空の `error.code`）と終了コード1、終了コード1で標準出力が空（標準エラーの最後の行が理由）、壊れたJSON、`result.agents` が配列でない、のとき、`CollectError` にならず、Eventが0件で、警告が D-04 の文（`Orcaの会話の一覧を読めませんでした: ` で始まり、理由を含む）1件だけ。`truncated` が true の見本で、その警告が足される。repo list が失敗すると、警告 `Orcaのrepositoryの一覧を読めませんでした: ` が入り、pathの一致の会話だけがEventになる。1つの会話の agent read が失敗すると、警告 `Orcaの会話を読めませんでした（orca_session_id:<id>）: ` が入り、ほかの会話はEventになる。`collect_repo` に通すと、どの場合も `errors` が空"
		verifies: ["F-01"]
	}
}

verification: "`test_commands` を順に流し、すべて終了コード0。PRを作った後に、GitHub ActionsのCIの合格を `github-pr-checks` で観測する。"
rollback:     "PRを戻す（revert）だけで元に戻る。状態に保存したEventは、利用者の手元のSQLiteにだけある。"
exit:         "PRが最終品質ゲートとCIに合格し、タスク担当が統括にPR・合格のコミット・CIの結果を報告した時点で、このIssueの作業は終わる。マージと `spec-dock work finish` は統括が行う。"

// 関門（coding-task）。保証レベル light の既定と、本人の決定 18〜21（init-00001 の plan.cue の delivery）に従う。
gates: {
	spec_review: "Claude `spec-reviewer`（Opus 5.5 / medium）。P0・P1がなくなるまで、3回まで"
	checkpoints: "なし。理由：手順は2つで、1人の実装担当が続けて書き、どれもこのIssueの中の新しいmoduleと試験で、既存のコードの変更は `__init__.py` の2行だけ。途中で止めて見る利得が小さい"
	final_quality_gate: {
		scope:          "開始のコミット（統括が作ったworktreeの作業の始めの `HEAD`、`6055bb9`）から S-02 の後の `HEAD` まで"
		perspectives:   ["functional-correctness", "requirements-closure", "test-adequacy", "security-baseline"]
		test_commands:  ["uv sync --locked", "uv run ruff check", "uv run pytest -q"]
		record_paths:   ["spec-dock/initiatives/00000-00999/iss-00013/report.md（SpecDockの自動の保存で記録する。Gitのcommitは要らない）"]
		second_opinion: "none"
	}
	merge:            "agent"
	merger:           "統括。タスク担当と実装担当はマージしない（本人の決定 21）。条件は `coding-task` の `references/merge.md`（CIの合格の観測を含む）"
	merge_permission: "本人の「PR のマージは各ワーカーが行わず、統括（Antigravity）が行う」（2026-11-26、`content/decisions/20261126-journal-format-and-hackathon-plan.md` の 21。init-00001 の `plan.cue` の `delivery`）"
	pr:               "branchは `chemitaro/iss-00013`（統括が作ったworktreeのbranch）。PRの本文に、合格のコミット、最終品質ゲートの結果、CIの結果を書く。Issueを自動で閉じる書き方（Closes #13）は使わない"
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
