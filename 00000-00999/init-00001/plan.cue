package spec

goal: "ハッカソン（2時間）の中で、shipcast自身のrepositoryの日誌がWebページで読めるところまで、ソフトウェアファクトリーの開発の手法（仕様 → 実装 → レビュー → 品質ゲート → 統括のマージ）を画面で見せながら作る。"

slices: {
	"epic-00002": {
		covers: ["R-01", "R-07"]
		text:   "E1 基盤。全Epicが使う約束（CLI、設定、データの形、状態、日誌のパスと前付けの契約）。最初に作る"
	}
	"epic-00003": {
		covers: ["R-02", "F-03"]
		text:   "E2 収集。Git・SpecDock・Orcaの収集。collectorの共通の約束（iss-00011）を先に入れ、SpecDockとOrcaを足す"
		after: ["epic-00002"]
	}
	"epic-00004": {
		covers: ["R-01", "R-03", "F-01", "F-02", "F-04"]
		text:   "E3 執筆（strict）。モデルの経路（iss-00014）はE1の後すぐに始められる。実データの要る話題のまとめ（iss-00015）だけが、E2の iss-00011・iss-00012 を待つ"
		after: ["epic-00002"]
	}
	"epic-00005": {
		covers: ["R-04"]
		text:   "E4 閲覧（strict）。E1の後、見本の日誌を使ってE2・E3と並行に作れる。画面のデザインは Opus 5.5 が直接実装する"
		after: ["epic-00002"]
	}
	"epic-00006": {
		covers: ["R-06"]
		text:   "E5 おまけ。ネタポイントとXの下書き。日誌の拡張点（iss-00016）を使う"
		after: ["epic-00004"]
	}
	"epic-00007": {
		covers: ["R-05"]
		text:   "E6 夜の自動実行"
		after: ["epic-00004", "epic-00005"]
	}
}

verification: "shipcast自身を登録し、`shipcast run --date <今日>` で日誌ができ、`shipcast serve` で表紙・一覧・その日の日誌が読めること。試験は `fake` の経路で、外部のモデルを呼ばずに通ること。"
exit:         "ハッカソンでは、E1〜E4が動き、各IssueのPRが仕様のレビュー・最終品質ゲート・CIに合格して統括にマージされれば成功。E5・E6は時間があれば。"

// 開発の進め方（本人の決定 18〜24）。各Issueの plan.cue の gates は、この既定に従う。
delivery: {
	workflow: "通常の `coding-task`。Issueを単位に、統括がOrcaのworktree（branchはIssueのID）で依頼し、タスク担当が仕様 → 仕様のレビュー → 実装担当の起動 → 区切りのレビュー → 最終品質ゲート → PR → CI → 統括への報告まで導く"
	merger:   "統括（Antigravity）。タスク担当と実装担当はマージしない（本人の決定 21）"
	ci:       "GitHub Actions（iss-00008 で入れる）で `uv run pytest -q` と `uv run ruff check` を流す。統括のマージは、`coding-task` のマージの規則どおり、CIの合格の観測を条件にする"
	gates_by_level: {
		light: {
			spec_review:     "Claude `spec-reviewer`（Opus 5.5 / medium）"
			checkpoints:     "なし"
			final_gate:      "`quality-gate-reviewer`（Opus 5.5 / medium）と全テスト"
			second_opinion:  "none"
			merge:           "agent（マージするのは統括）"
		}
		standard: {
			spec_review:     "Claude `spec-reviewer`（Opus 5.5 / high）"
			checkpoints:     "原則なし。後の多くの手順が依る境界にだけ1つ（`code-reviewer` Opus 5.5 / medium）"
			final_gate:      "`quality-gate-reviewer`（Opus 5.5 / medium）と全テスト"
			second_opinion:  "none"
			merge:           "agent（マージするのは統括）。merge_permission：本人の「PR のマージは各ワーカーが行わず、統括（Antigravity）が行う」（2026-11-26、`content/decisions/20261126-journal-format-and-hackathon-plan.md` の 21）。各Issueの plan.cue の gates に写す"
		}
		strict: {
			spec_review:     "Claude `spec-reviewer`（Opus 5.5 / high）と ChatGPT の2人目（GPT-6 / Extra High。材料であって関門ではない）"
			checkpoints:     "契約や防御の境界を決める手順の後（`code-reviewer` Opus 5.5 / medium）"
			final_gate:      "`quality-gate-reviewer`（Opus 5.5 / high）と全テスト"
			second_opinion:  "chatgpt（取れないときは GPT-6.2 Astra / high）"
			merge:           "統括がマージする（本人の決定 21）。ただし `coding-task` のマージの規則は strict のエージェントによるマージを禁じているので、統括はマージの前にPR・合格のコミット・CIの結果を本人に示し、本人の確認を得てからマージする"
		}
	}
}

execution: sessions: {
	spec: {task: "仕様化（起動した側が選んだ値の記録）", model: "Claude Opus 5.5", effort: "この会話の設定", rationale: "統括（Antigravity）が起動した作業者。値は起動した側が決めた"}
	coordinator: {task: "統括（Issueの依頼、見守り、マージ）", model: "Antigravity（本人が直接使う統括）", effort: "本人の設定", rationale: "本人の決定 19"}
	owner: {task: "各Issueのタスク担当（仕様、レビュー、品質ゲート、PR）", model: "Claude Opus 5.5", effort: "light・standard は medium、strict は high", rationale: "方針§2のタスク担当の行と本人の決定 19"}
	impl: {task: "Issueのロジックの実装（Orcaの作業者）", model: "GPT-6.2 Sol", effort: "medium", rationale: "テストで確かめられる実装の既定（方針§2、本人の決定 19）"}
	"impl-ui": {task: "画面のデザイン・レイアウト・表示の実装", model: "Claude Opus 5.5", effort: "light・standard は medium、strict は high", rationale: "本人の決定 20。方針§2のフロントエンドの行"}
}
