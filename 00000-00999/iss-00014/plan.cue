package spec

goal: "外部のモデルへの送信の境界（伏せる処理、エージェントの中の守り、共通の入口）を、本物のコマンドを起動せずに試験で固め、iss-00015・iss-00016 が `get_route` と `GuardedRoute.complete` だけで分析と書き手を呼べるようにする。"

steps: {
	"S-01": {
		title:    "伏せる処理（`shipcast.redact`）"
		text:     "D-01。T-02 を `tests/test_redact.py` に先に書いて落ちることを確かめ（Red）、`src/shipcast/redact.py` に `REDACTED`・`RULES`・`redact` を書いて通す（Green）。秘密らしい試験の値は、明らかに架空のダミー値を、文字列の連結で組み立てる（repositoryの文に、トークンの形の文字列をそのまま置かない）。完了の条件：T-02 が通り、`uv run ruff check` が通る。"
		realizes: ["R-02", "F-03"]
		session:  "impl"
	}
	"S-02": {
		title:    "エージェントの中の検出（`agent_markers`・`in_agent_context`）"
		text:     "D-02。T-04 のうち印の関数の試験（印ごと、空の値、`CODEX_` の前方一致、印のない env、Mapping でない env、読む途中で例外を上げる env）を `tests/test_models.py` に先に書いて Red、`src/shipcast/models.py` に `AGENT_MARKERS`・`AGENT_MARKER_PREFIXES`・`agent_markers`・`in_agent_context` を書いて Green。完了の条件：その試験と S-01 の試験が通り、`uv run ruff check` が通る。"
		realizes: ["F-01"]
		after:    ["S-01"]
		session:  "impl"
	}
	"S-03": {
		title:    "経路の部品と共通の入口（`get_route`・`GuardedRoute`・4つの経路・runner・例外）"
		text:     "D-03〜D-06。T-01、T-03、T-04 の経路の試験、T-05、T-06、T-08 を `tests/test_models.py` に先に書いて Red、`src/shipcast/models.py` に `ROUTES`・`DEFAULT_TIMEOUT`・`JSON_INSTRUCTION`・`MAX_ARGV_PROMPT_BYTES`・例外4つ・`Completed`・`Runner`・`run_subprocess`・非公開の経路4つ・`GuardedRoute`・`get_route` を書いて Green。試験は偽の runner だけを使い、`subprocess.run` を落とす autouse の fixture を置く（D-06）。本物の `codex`・`claude`・`agy` を起動しない（`--help` も呼ばない）。完了の条件：`test_commands` がすべて終了コード0。この手順の後で区切りのレビュー（CP-1）。"
		realizes: ["R-01", "R-02", "F-01", "F-02", "F-03", "F-04"]
		after:    ["S-02"]
		session:  "impl"
	}
	"S-04": {
		title:    "設定の見本に、より安い分析のモデルの名前を書く"
		text:     "D-07。T-07 を `tests/test_config.py` に先に書いて Red、`src/shipcast/config.py` の `DEFAULT_CONFIG_TEXT` の分析のモデルの行に注記を足して Green。ほかの行は変えない。完了の条件：`test_commands` がすべて終了コード0。"
		realizes: ["R-03"]
		after:    ["S-03"]
		session:  "impl"
	}
}

tests: {
	"T-01": {title: "`get_route` が4つの経路の `GuardedRoute`（`name`・`model` が設定の値）を返す。`gemini` で4つの名前を示す `UnknownRoute`、runner は呼ばれない。`timeout` が0・負・`inf`・`nan` で `ValueError`、`responder` を `fake` 以外に渡すと `ValueError`。`fake` は同じ入力で同じJSONの文字列を返し、その中の値が受け取った model・prompt・system・want_json で、`responder` を渡せばその戻り値を返す。`codex`・`claude`・`antigravity` は D-03 の表の argv・標準入力・cwd（空のディレクトリ）で runner を1回呼び、表の取り出し方の本文を返す（codex は偽の runner が `--output-last-message` のファイルに書いた中身、antigravity はJSONの `response`、thinking が `high` なら `--model gemini-4-neon-high`）。`want_json` で system の末尾に `JSON_INSTRUCTION` が付く。既定の timeout 600 が runner に渡る", verifies: ["R-01"]}
	"T-02": {title: "RD-01〜RD-11 の各規則で、ダミーの値が `[伏せた]` になり、前後の文は残る（RD-01 は閉じのない塊も末尾まで、RD-02 は `https://user:pass@host` の利用者:パスワードだけ、RD-04 は `export DB_PASSWORD=\"x\"`・`api_token: x`・JSONの `\"secret\": \"x\"`・小文字の鍵、値の空の `TOKEN=` は変わらない）。秘密を含まない日本語の文とコードは変わらない。`redact(redact(x)) == redact(x)`。`str` でない入力は `TypeError`", verifies: ["R-02", "F-03"]}
	"T-03": {title: "4つの経路（`fake` は `responder` で受け取ったもの）で、prompt と system に入れたダミーの秘密が、経路の実装に届く文字列（runner の argv と標準入力、`responder` の引数）に含まれず、`[伏せた]` が含まれる", verifies: ["R-02"]}
	"T-04": {title: "`CLAUDECODE`・`AI_AGENT`・`ORCA_AGENT_SESSION_ID`・`CODEX_THREAD_ID` のどれか1つ（値が空でも）があると、`agent_markers` がその名前を返し、antigravity の `complete` が `RouteRefused`（`markers` に名前、文に値を含まない）で止まり、runner は呼ばれない。印のない env では止まらない。Mapping でない env と、鍵を読むと例外を上げる env で `in_agent_context` が真。ほかの3つの経路は印があっても止まらない。`get_route` は印があっても止まらない。`run_subprocess([\"agy\", ...])` は本物の `os.environ` に印があれば（monkeypatch で置く）`subprocess.run` を呼ばずに `RouteRefused`", verifies: ["F-01"]}
	"T-05": {title: "偽の runner で、終了コード1、`subprocess.TimeoutExpired`、`FileNotFoundError`、空白だけの標準出力、codex の出力のファイルがない、antigravity の標準出力がJSONでない・`status` が `ERROR`・`response` が空、`responder` が `None` を返す、のどれも `RouteFailed` になり、`route`・`returncode`・`timed_out`・`reason` が場合に合い、`stderr_tail` が末尾の2000文字以内でダミーの秘密を含まない", verifies: ["F-02"]}
	"T-06": {title: "`shipcast.models.redact` を例外を上げる関数に差し替えると、`complete` がその例外をそのまま上げ（`RouteFailed` に包まない）、runner と `responder` が呼ばれない。prompt か system が `str` でなければ `TypeError` で、runner が呼ばれない", verifies: ["F-03"]}
	"T-07": {title: "`DEFAULT_CONFIG_TEXT` の `[models.analyst]` の `model` の行（かその直前の注記の行）に `gpt-6-luna` と `codex debug models` があり、`parse_config(DEFAULT_CONFIG_TEXT, ...)` の `models.analyst` が `ModelConfig(\"codex\", \"gpt-6.2-sol\", \"low\", None)` のまま", verifies: ["R-03"]}
	"T-08": {title: "antigravity で、伏せた後の `text` が 200,000 バイトを超えると runner を呼ばずに `RouteFailed`（理由に長さ）、ちょうど 200,000 バイトなら runner が呼ばれる。ほかの経路には上限がない", verifies: ["F-04"]}
}

verification: "`test_commands` を順に流し、すべて終了コード0。試験は偽の runner と `fake` の経路だけで、外部のモデルと本物の `agy` を呼ばない。PRを作った後に、GitHub ActionsのCIの合格を `github-pr-checks` で観測する。本物の経路（codex と antigravity）での確かめは、本人の手動の実行だけ。"
rollback:     "PRを戻す（revert）だけで元に戻る。新しいモジュールを呼ぶ側はまだない（iss-00015・iss-00016 が後で使う）。設定の見本の変更は注記の1行だけ。"
exit:         "PRが最終品質ゲートとCIに合格し、タスク担当が統括にPR・合格のコミット・CIの結果・closure.md を報告した時点で、このIssueの作業は終わる。マージは本人（統括が本人に確かめて采配する）、`spec-dock work finish` は統括が行う。"

// 関門（coding-task）。保証レベル strict の既定（specify の references/assurance-levels.md）に従う。
gates: {
	spec_review: "Claude `spec-reviewer`（Opus 5.5 / high）と、ChatGPT（GPT-6 / Extra High、`chatgpt-spec-review-strict`）の2人目。P0・P1がなくなるまで、3回まで"
	checkpoints: {
		"CP-1": {
			last_step: "S-03"
			range:     "開始のコミットから S-03 の後の `HEAD` まで"
			reviewers: "Claude `code-reviewer`（Opus 5.5 / medium）。P0・P1 で止める"
			reason:    "S-03 で、外部への送信の境界（`GuardedRoute.complete` の順）と、iss-00015・iss-00016 が依る公開の入口（`get_route`・例外・runner）が固まる。strict の「公開のAPIや権限の境界を固める手順の後」に当たる"
		}
	}
	final_quality_gate: {
		scope:          "開始のコミット（このworktreeの作業の始めの `HEAD`、`f68349a`）から S-04 の後の `HEAD` まで"
		perspectives:   ["functional-correctness", "requirements-closure", "test-adequacy", "api-contract", "security"]
		test_commands:  ["uv sync --locked", "uv run ruff check", "uv run pytest -q"]
		record_paths:   ["spec-dock/initiatives/00000-00999/iss-00014/report.md（SpecDockの自動の保存で記録する。Gitのcommitは要らない）"]
		second_opinion: "chatgpt（ChatGPT GPT-6 / Extra High。取れないときは GPT-6.2 Astra / high）"
	}
	merge:  "owner"
	merger: "本人。統括（Antigravity）が本人に確かめてマージを采配する。タスク担当と実装担当はマージしない（本人の決定 21、strict は agent のマージを許さない）"
	pr:     "branchは `chemitaro/iss-00014`（統括が作ったworktreeのbranch）。PRの本文に、合格のコミット、最終品質ゲートの結果、CIの結果を書く。Issueを自動で閉じる書き方（Closes #14）は使わず、`Refs #14` にする"
}

execution: {
	sessions: {
		spec: {task: "仕様化（起動した側が選んだ値の記録）", provider: "claude", model: "Claude Opus 5.5", effort: "high", rationale: "統括（Antigravity）が起動したOrcaの作業者。値は起動した側が方針§2の strict のタスク担当の行から決めた（事実の記録）"}
		owner: {task: "タスク担当（仕様、説明資料、レビュー、最終品質ゲート、PR、CIの観測）", provider: "claude", model: "Claude Opus 5.5", effort: "high", rationale: "方針§2のタスク担当の strict の行。spec と同じセッション"}
		impl: {task: "実装（S-01〜S-04）。このworktreeで起動するOrcaの作業者", provider: "codex", model: "GPT-6.2 Sol", effort: "medium", rationale: "方針§2の、テストで確かめられる実装（バックエンド）の strict の行と本人の決定 19"}
	}
	reviews: {
		checkpoint: {role: "区切りのレビュー CP-1 の `code-reviewer`", after: "S-03", model: "Claude Opus 5.5", effort: "medium"}
		final_gate: {role: "最終品質ゲートの `quality-gate-reviewer`（2人目は ChatGPT GPT-6 / Extra High、取れないとき GPT-6.2 Astra / high）", after: "S-04", model: "Claude Opus 5.5", effort: "high"}
	}
	assignment:   "S-01, S-02, S-03, S-04 → impl（連続）"
	same_session: "なし（実装担当の提供元がタスク担当と違うため、別のセッションにする）"
}
