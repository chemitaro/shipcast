package spec

goal: "先に台帳への加算と未消化の話題の読み出しを `Store` に足し、その上に「発信の芽」の部品と CLI への配線を積む。試験は fake の経路の `responder` と一時ディレクトリだけで行う。"

steps: {
	"S-01": {
		status:   "done"
		title:    "台帳への加算（`save_stories`）と `unconsumed_stories`"
		text:     "D-01。T-01・T-02 を `tests/test_state.py`・`tests/test_analyze.py` に先に書いて落ちることを確かめ（Red）、`src/shipcast/state.py` を直して通す（Green）。`tests/test_analyze.py` の `assert store.unconsumed_neta(REPO) == []`（分析の後に台帳が空という今の期待）は、R-01 に合わせて話題の id の一覧に改める。完了の条件：`test_commands` がすべて終了コード0。"
		realizes: ["R-01"]
		session:  "impl"
	}
	"S-02": {
		status:   "done"
		title:    "「発信の芽」の部品（`NetaSprout`）と CLI への配線"
		text:     "D-02・D-03。T-03・T-04 を `tests/test_neta.py`・`tests/test_write.py` に先に書いて Red、`src/shipcast/neta.py` と `src/shipcast/write.py` の `journal_extensions`・`run` を書いて Green。`cli.py` は変えない。完了の条件：`test_commands` がすべて終了コード0。"
		realizes: ["R-02"]
		after:    ["S-01"]
		session:  "impl"
	}
}

tests: {
	"T-01": {title: "`Store.save_stories`：`demo-app` の点数2と1の話題と `demo-lib` の点数3の話題を保存すると `neta_balance(\"demo-app\") == 3`・`neta_balance(\"demo-lib\") == 3`。同じ id の話題を点数3に変えて保存し直しても残高は3のままで、`stories_for` は新しい内容を返す。`consume_neta` で消化した話題を保存し直しても、残高に戻らない。点数0の話題を保存しても残高は変わらない。`unconsumed_stories(\"demo-app\")` は点数1以上の未消化の話題を、点数の大きい順・台帳に入った順の `Story` で返し、`limit=1` で1件、消化済みと点数0の話題と別の repository の話題を含まない。台帳にあって `stories` の表にない id（`add_neta` だけで足したもの）は飛ばす", verifies: ["R-01"]}
	"T-02": {title: "`analyze`：fake の経路で点数0と2の話題が返ると、その2つの id が `unconsumed_neta(REPO)` に入り、`neta_balance(REPO) == 2`。同じ出来事で `analyze` をもう一度呼んでも残高は2のまま", verifies: ["R-01"]}
	"T-03": {title: "`NetaSprout`：しきい値6で、残高5なら `render` が `None`。残高6なら `:::tip 発信の芽（ネタポイント 6）` で始まり `:::` で終わり、題名が点数の大きい順に `- ` の行で並ぶ。点数1以上の話題が4件あると題名は3件。題名 `<b>x</b> & y` は `&lt;b&gt;x&lt;/b&gt; &amp; y` に、`# 見出し` は `\\# 見出し` に、`1. 一番` は `1\\. 一番` になる。点数1以上の話題の本体がない（台帳だけで足した）ときは、題名のない2行の囲み", verifies: ["R-02"]}
	"T-04": {title: "`write_day`・CLI：`journal_extensions(store, 6)` が `(*EXTENSIONS, NetaSprout)` を返し、`monkeypatch` で差し替えた `EXTENSIONS` の部品が先に並ぶ。`SHIPCAST_CONFIG` の一時の設定（経路は `fake`、`[neta] threshold = 3`）と偽の collector・`responder` で、点数2と1の話題が返る日の `main([\"write\", \"--repo\", \"demo-app\", \"--date\", \"2026-11-26\"])` が0を返し、日誌の最後の塊が `:::tip 発信の芽（ネタポイント 3）` の囲みで、`:::metrics` の塊の後にある。しきい値を4にした同じ日の日誌には `:::tip` がない。出来事のない日の日誌にも `:::tip` がない", verifies: ["R-02"]}
}

verification: "`test_commands` を順に流し、すべて終了コード0。試験は fake の経路の `responder` だけで、外部のモデルと `agy` を呼ばない。PRを作った後に、GitHub ActionsのCIの合格を `github-pr-checks` で観測する。"
rollback:     "PRを戻す（revert）だけで元に戻る。表の形は変えない（`neta_ledger` に行が足されるだけ）。足された行は、戻した後の版でも読めて害はない。"
exit:         "PRが最終品質ゲートとCIに合格し、タスク担当が統括にPR・合格のコミット・CIの結果・closure.md を報告した時点で、このIssueの作業は終わる。マージと `spec-dock work finish` は統括が行う。"

// 関門（coding-task）。保証レベル light の既定と、本人の決定 18〜21（init-00001 の plan.cue の delivery）に従う。
gates: {
	spec_review: "Claude `spec-reviewer`（Opus 5.5 / medium）。P0・P1がなくなるまで、3回まで"
	checkpoints: "なし。理由：手順は2つで、1人の実装担当が続けて書く。S-02 が依る境界（`unconsumed_stories` と台帳の加算）は S-01 の試験と最終品質ゲートで確かめる"
	final_quality_gate: {
		scope:          "開始のコミット（このworktreeの作業の始めの `HEAD`、`ef3075f`）から S-02 の後の `HEAD` まで"
		perspectives:   ["functional-correctness", "requirements-closure", "test-adequacy", "security-baseline"]
		reviewer:       "Claude `quality-gate-reviewer`（Opus 5.5 / medium）"
		test_commands:  ["uv sync --locked", "uv run ruff check", "uv run pytest -q"]
		record_paths:   ["spec-dock/initiatives/00000-00999/iss-00019/report.md（SpecDockの自動の保存で記録する。Gitのcommitは要らない）"]
		second_opinion: "none"
	}
	merge:            "agent"
	merger:           "統括。タスク担当と実装担当はマージしない（本人の決定 21）。条件は `coding-task` の `references/merge.md`（CIの合格の観測を含む）"
	merge_permission: "本人の「PR のマージは各ワーカーが行わず、統括が行う」（2026-11-26、`content/decisions/20261126-journal-format-and-hackathon-plan.md` の 21。init-00001 の `plan.cue` の `delivery.gates_by_level`）"
	pr:               "branchは `chemitaro/iss-00019`（統括が作ったworktreeのbranch）。PRの本文に、合格のコミット、最終品質ゲートの結果、CIの結果を書く。Issueを自動で閉じる書き方（Closes #19）は使わず、`Refs #19` にする"
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
