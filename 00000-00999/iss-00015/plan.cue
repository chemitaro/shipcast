package spec

goal: "応答の形の検査とプロンプトを先に固め、その上に頼み直しと失敗、保存を積み、`analyze` が話題を保存してから返すようにする。試験は fake の経路の `responder` と一時ディレクトリの `Store` だけで行う。"

steps: {
	"S-01": {
		status:   "doing"
		title:    "分析のプロンプトとJSONの形（`parse_stories`）"
		text:     "D-02・D-04。T-01 の `parse_stories` の部分、T-05、T-07 を `tests/test_analyze.py` に先に書いて落ちることを確かめ（Red）、`src/shipcast/prompts/analyze.md` と、`src/shipcast/analyze.py` の `PROMPT_PATH`・プロンプトを読む関数・`parse_stories` を書いて通す（Green）。完了の条件：その試験が通り、`uv run ruff check` が通る。"
		realizes: ["R-01", "R-02"]
		session:  "impl"
	}
	"S-02": {
		title:    "`analyze` の関数と頼み直し、失敗（`AnalyzeFailed`）"
		text:     "D-01（手順1・2・4・5・7と、手順6のうち `Story` の組み立て）・D-03。T-01（`analyze` の部分）、T-02、T-03、T-06、T-08 を先に書いて Red、`analyze`・`MAX_ATTEMPTS`・`AnalyzeFailed` を書いて Green。この手順では、話題の保存と出来事の保存の試験（T-04）はまだ書かない。完了の条件：`test_commands` がすべて終了コード0。"
		realizes: ["R-01", "R-02", "F-01"]
		after:    ["S-01"]
		session:  "impl"
	}
	"S-03": {
		title:    "保存（出来事はモデルを呼ぶ前、話題は返す前）"
		text:     "D-01（手順3と、手順6のうち `save_stories` の呼び出し）。T-04 と、T-03・T-06 の「出来事は残り、話題は保存されない」の確かめを先に書いて Red、`store.add_events` と `store.save_stories` の呼び出しを足して Green。完了の条件：`test_commands` がすべて終了コード0。"
		realizes: ["R-03", "F-01"]
		after:    ["S-02"]
		session:  "impl"
	}
}

tests: {
	"T-01": {title: "fake の応答（2つの話題、架空の出来事3件）から、`analyze` が2つの `Story` を応答の順で返し、`title`・`what`・`why`・`notice`・`waiting`・`neta`（`score`・`reason`・`channels`）・`event_ids` が応答のとおり、`id` が `story_id(repo_id, day, event_ids)`、`repo_id`・`date` が引数の値。`notice`・`waiting`・`neta.reason`・`neta.channels` を省いた応答では空になる。知らない鍵は捨てられる。応答が ```` ```json ```` の囲みと前後の空白に包まれていても読める。`parse_stories` も同じ応答から同じ値を返し、誤りが空", verifies: ["R-01"]}
	"T-02": {title: "1回目が壊れたJSON（または V-06 の誤り）、2回目が正しい応答の `responder` で、呼び出しが2回、2回目の prompt が `json.loads` で読め、`events` が1回目と同じ、`previous_errors` に1回目の誤り（場所 `応答` か `stories[0].neta.score` を含む文）が入る。1回目が正しければ呼び出しは1回で、prompt に `previous_errors` がない。どの呼び出しも `want_json=True` で、`responder` が受け取る system が、`prompts/analyze.md` の本文の後に `\\n\\n` と `shipcast.models.JSON_INSTRUCTION` を足したものと等しい（本文は `redact()` を通しても変わらない文にする）", verifies: ["R-02"]}
	"T-03": {title: "2回とも形が合わない `responder` で、呼び出しがちょうど2回、`AnalyzeFailed` が上がり、`attempts == 2`、`errors` が2回目の誤り、文が「分析の応答が2回とも決まった形になりませんでした」で始まり、応答の本文（試験で入れた目印の文字列）を含まない。`stories_for(repo_id, day)` が空で、`events_for` で渡した出来事が読める（S-03 で足す）", verifies: ["F-01"]}
	"T-04": {title: "話題のない新しい `Store` で、`analyze` が返った後、`Store.stories_for(repo_id, day)` が返した一覧と等しい。`responder` の中で `store.events_for(repo_id, day, tz=...)` を読むと、渡した出来事がすべてある（モデルを呼ぶ前に保存されている）。収集で保存済みの出来事を渡しても誤りにならず、件数が増えない", verifies: ["R-03"]}
	"T-05": {title: "`parse_stories` の誤りの表（パラメーター化）：V-01（JSONでない、空、深すぎる入れ子で `RecursionError`）、V-02（配列が全体、`stories` がない・物）、V-03（空の `stories`）、V-04（`what` がない・空白だけ・数）、V-05（`notice` が文字列）、V-06（`score` が `-1`・`4`・`1.5`・`\"2\"`・`true`、`neta` がない、`channels` に数）、V-07（`event_ids` が空・入力にないID・同じ話題で重なる）、V-08（2つの話題が同じ出来事を含む）、V-09（`title` と `notice` の要素と `neta.reason` に、JSONのエスケープ `\\ud800` で入れた対のないサロゲート）。それぞれ誤りが1件以上で、期待する場所の文字列を含み、話題の一覧が空。誤りの文に、応答に入れた目印の値を含まない。30件の話題がすべて誤りのとき、誤りは21件（20件と「ほかにも誤りがあります」）", verifies: ["R-01", "R-02"]}
	"T-06": {title: "`responder` が `RouteFailed` を投げると、`analyze` がそのまま `RouteFailed` を投げ（`AnalyzeFailed` に包まない）、呼び出しは1回、話題は保存されず、出来事は残る（S-03 で足す）", verifies: ["F-01"]}
	"T-07": {title: "`prompts/analyze.md` が `importlib.resources` で読め、`ネタポイント`・`変化の大きさ`・`読者への価値`・`見せやすさ`・`previous_errors`・`event_ids`・`stories` を含む", verifies: ["R-01", "R-02"]}
	"T-08": {title: "出来事が0件なら、`responder` が呼ばれず、`[]` が返り、`stories_for` が空。`repo_id` の違う出来事を混ぜると `ValueError` で、`responder` が呼ばれず、何も保存されない", verifies: ["R-01"]}
}

verification: "`test_commands` を順に流し、すべて終了コード0。試験は fake の経路の `responder` だけで、外部のモデルと `agy` を呼ばない。PRを作った後に、GitHub ActionsのCIの合格を `github-pr-checks` で観測する。本物の分析の経路（codex）での確かめは、本人の手動の実行だけ。"
rollback:     "PRを戻す（revert）だけで元に戻る。新しいモジュールを呼ぶ側はまだない（iss-00016 が後で使う）。状態の表の形は変えない。"
exit:         "PRが最終品質ゲートとCIに合格し、タスク担当が統括にPR・合格のコミット・CIの結果・closure.md を報告した時点で、このIssueの作業は終わる。マージと `spec-dock work finish` は統括が行う。"

// 関門（coding-task）。保証レベル standard の既定と、本人の決定 18〜21（init-00001 の plan.cue の delivery）に従う。
gates: {
	spec_review: "Claude `spec-reviewer`（Opus 5.5 / high）。P0・P1がなくなるまで、3回まで"
	checkpoints: "なし。理由：手順は3つで、1人の実装担当が続けて書き、どれもこのIssueの中の新しいmodule（`analyze.py`・`prompts/analyze.md`）と試験で、既存のコードは変えない。後の手順が依る境界（`parse_stories` の形）は S-01 の試験と最終品質ゲートの `api-contract` の観点で確かめる"
	final_quality_gate: {
		scope:          "開始のコミット（統括が作ったworktreeの作業の始めの `HEAD`、`b7832b8`）から S-03 の後の `HEAD` まで"
		perspectives:   ["functional-correctness", "requirements-closure", "test-adequacy", "api-contract", "security-baseline"]
		test_commands:  ["uv sync --locked", "uv run ruff check", "uv run pytest -q"]
		record_paths:   ["spec-dock/initiatives/00000-00999/iss-00015/report.md（SpecDockの自動の保存で記録する。Gitのcommitは要らない）"]
		second_opinion: "none"
	}
	merge:            "agent"
	merger:           "統括。タスク担当と実装担当はマージしない（本人の決定 21）。条件は `coding-task` の `references/merge.md`（CIの合格の観測を含む）"
	merge_permission: "本人の「PR のマージは各ワーカーが行わず、統括（Antigravity）が行う」（2026-11-26、`content/decisions/20261126-journal-format-and-hackathon-plan.md` の 21。init-00001 の `plan.cue` の `delivery.gates_by_level.standard.merge`）"
	pr:               "branchは `chemitaro/iss-00015`（統括が作ったworktreeのbranch）。PRの本文に、合格のコミット、最終品質ゲートの結果、CIの結果を書く。Issueを自動で閉じる書き方（Closes #15）は使わず、`Refs #15` にする"
}

execution: {
	sessions: {
		spec: {task: "仕様化（起動した側が選んだ値の記録）", provider: "claude", model: "Claude Opus 5.5", effort: "medium", rationale: "統括が起動したOrcaの作業者。値は起動した側が方針§2の standard のタスク担当の行から決めた（事実の記録）"}
		owner: {task: "タスク担当（仕様、説明資料、レビュー、最終品質ゲート、PR、CIの観測）", provider: "claude", model: "Claude Opus 5.5", effort: "medium", rationale: "方針§2のタスク担当の standard の行。spec と同じセッション"}
		impl: {task: "実装（S-01〜S-03）。このworktreeで起動するOrcaの作業者", provider: "codex", model: "GPT-6.2 Sol", effort: "medium", rationale: "方針§2の、テストで確かめられる実装（バックエンド）の行、本人の決定 19、統括の依頼"}
	}
	reviews: {
		spec_review: {role: "仕様のレビューの `spec-reviewer`", model: "Claude Opus 5.5", effort: "high"}
		final_gate: {role: "最終品質ゲートの `quality-gate-reviewer`", after: "S-03", model: "Claude Opus 5.5", effort: "medium"}
	}
	assignment:   "S-01, S-02, S-03 → impl（連続）"
	same_session: "なし（実装担当の提供元がタスク担当と違い、統括の依頼が Codex の実装担当を名指すため、別のセッションにする）"
}
