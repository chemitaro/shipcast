package spec

goal: "外部のモデルへの送信の境界（伏せる処理、エージェントの中の守り、共通の入口）を、本物のコマンドを起動せずに試験で固め、iss-00015・iss-00016 が `get_route` と `GuardedRoute.complete` だけで分析と書き手を呼べるようにする。"

steps: {
	"S-01": {
		title:    "伏せる処理（`shipcast.redact`）"
		text:     "D-01。T-02 を `tests/test_redact.py` に先に書いて落ちることを確かめ（Red）、`src/shipcast/redact.py` に `REDACTED`・`RULES`・`redact` を書いて通す（Green）。秘密らしい試験の値は、明らかに架空のダミー値を、文字列の連結で組み立てる（repositoryの文に、トークンの形の文字列をそのまま置かない）。完了の条件：T-02 が通り、`uv run ruff check` が通る。"
		realizes: ["R-02", "F-03"]
		session:  "impl"
		status:   "done"
	}
	"S-02": {
		title:    "エージェントの中の検出（`agent_markers`・`in_agent_context`）"
		text:     "D-02。T-04 のうち印の関数の試験（印ごと、空の値、`CODEX_` の前方一致、印のない env、Mapping でない env、読む途中で例外を上げる env）を `tests/test_models.py` に先に書いて Red、`src/shipcast/models.py` に `AGENT_MARKERS`・`AGENT_MARKER_PREFIXES`・`agent_markers`・`in_agent_context` を書いて Green。完了の条件：その試験と S-01 の試験が通り、`uv run ruff check` が通る。"
		realizes: ["F-01"]
		after:    ["S-01"]
		session:  "impl"
		status:   "done"
	}
	"S-03": {
		title:    "経路の部品と共通の入口（`get_route`・`GuardedRoute`・4つの経路・runner・例外）"
		text:     "D-03〜D-06。T-01、T-03、T-04 の経路の試験、T-05、T-06、T-08、T-09、T-10 を `tests/test_models.py` に先に書いて Red、`src/shipcast/models.py` に `ROUTES`・`DEFAULT_TIMEOUT`・`JSON_INSTRUCTION`・`MAX_ARGV_PROMPT_BYTES`・例外4つ・`Completed`・`Runner`・`run_subprocess`・非公開の経路4つ・`GuardedRoute`・`get_route` を書いて Green。試験は偽の runner だけを使い、`subprocess.run` を落とす autouse の fixture を置く（D-06）。本物の `codex`・`claude`・`agy` を起動しない（`--help` も呼ばない）。完了の条件：`test_commands` がすべて終了コード0。この手順の後で区切りのレビュー（CP-1）。"
		realizes: ["R-01", "R-02", "F-01", "F-02", "F-03", "F-04", "F-05"]
		after:    ["S-02"]
		session:  "impl"
		status:   "done"
	}
	"S-04": {
		title:    "設定の見本に、より安い分析のモデルの名前を書く"
		text:     "D-07。T-07 を `tests/test_config.py` に先に書いて Red、`src/shipcast/config.py` の `DEFAULT_CONFIG_TEXT` の分析のモデルの行に注記を足して Green。ほかの行は変えない。完了の条件：`test_commands` がすべて終了コード0。"
		realizes: ["R-03"]
		after:    ["S-03"]
		session:  "impl"
		status:   "done"
	}
	"S-05": {
		title:    "最終品質ゲートの1回目の直し：引用の中のエスケープと、規則の書き出しの位置"
		text:     "最終品質ゲートの1回目（ChatGPT の2人目の P1 と P2）を受けた仕様の直し（D-01 のコード、R-02、F-06）。T-02 に足した例と T-11 を `tests/test_redact.py` に先に書いて Red を確かめ、`src/shipcast/redact.py` を D-01 の今のコードの振る舞いに合わせて Green。完了の条件：`test_commands` がすべて終了コード0。"
		realizes: ["R-02", "F-06"]
		after:    ["S-04"]
		session:  "impl"
		status:   "todo"
	}
}

tests: {
	"T-01": {title: "`get_route` が4つの経路の `GuardedRoute`（`name`・`model` が設定の値）を返す。`gemini` で4つの名前を示す `UnknownRoute`、runner は呼ばれない。`timeout` が0・負・`inf`・`nan` で `ValueError`、`responder` を `fake` 以外に渡すと `ValueError`。`fake` は同じ入力で同じJSONの文字列を返し、その中の値が受け取った model・prompt・system・want_json で、`responder` を渡せばその戻り値を返す。`codex`・`claude`・`antigravity` は D-03 の表の argv・標準入力・cwd（一時ディレクトリの中の空の `work/`）で runner を1回呼び、表の取り出し方の本文を返す（codex は偽の runner が `--output-last-message` のファイルに書いた中身、antigravity はJSONの `response`、thinking が `high` なら `--model gemini-4-neon-high`、effort がなければ `-c model_reasoning_effort` と `--effort` を付けない）。`want_json` で system の末尾に `JSON_INSTRUCTION` が付く。既定の timeout 600 が runner に渡り、runner の env が `complete` の環境の写しと等しい", verifies: ["R-01"]}
	"T-02": {title: "RD-01〜RD-11 の各規則で、ダミーの値が `[伏せた]` になり、前後の文は残る。RD-01：同じ種類の END まで、種類の違う END（BEGIN PRIVATE KEY の後の END RSA PRIVATE KEY）では止まらず末尾まで、END のない塊も末尾まで。RD-02：`https://user:pass@host` の利用者:パスワードだけ。RD-04（文の層）：`export DB_PASSWORD=\"x\"`（引用符が残る）・`api_token: x`・`password: correct horse battery`・小文字の鍵・`DB_PASSWORD=DUMMY]EXAMPLE`・`DB_PASSWORD=Ab}9xQ2`（値の全体）・閉じのない `\"password\": \"abc`・文の中のJSON `payload: {\"api_token\": \"…\", \"title\": \"keep\"}`（`title` が残る）・JSONとして読めない文の `{\\\"password\\\": \\\"…\\\"`、`PASSWORD='it\\'sEXAMPLE' tail`（単一引用の中のエスケープ）と、`'payload: ' + json.dumps(json.dumps({\"password\": 引用符を含むダミー}))[1:-1]` のようなJSONとして読めない断片（エスケープの残った引用の中の `\\\\\\\"`）で値の全体が伏せられる、`echo \"PASSWORD=DUMMY\"` と文字の `\\n` の直後の `PASSWORD=` も伏せられる、`PASSWORD=[伏せた]DUMMY_EXAMPLE` と文字の `\\n` を含む `PASSWORD=DUMMY\\nEXAMPLE` で値の全体が伏せられる、値の空の `TOKEN=` と空白だけの値は変わらない。JSONの層：鍵に入った `ghp_` のトークン（文字列の中のJSONの鍵も）が伏せられる、不正なエスケープで読めない `{\"password\":\"a\\qb\",\"x\":1}` が1回目から `{\"password\": \"[伏せた]\", \"x\": 1}` になる、`json.dumps({\"password\": …, \"title\": \"keep\"})` が `\"password\": \"[伏せた]\"` と `title` を持つJSONになる、`max_tokens` と `credentials`（物）の値が `\"[伏せた]\"`、`json.dumps` の既定で書いた「トークン」の直後の `ghp_`・`AKIA`・`sk-` の値が伏せられる、会話の本文に入れた `json.dumps({\"password\": 引用符を含むダミー, \"user\": \"demo\"})` を外側のJSONに入れたものでパスワードの断片が残らず `user` とほかの出来事が残る、JSONの文字列の中の `PASSWORD=…\\nnormal line` で `normal line` が残る、どの結果も `json.loads` で読める。RD-05〜RD-11：日本語の文字のすぐ前と後ろにあるトークンも伏せる、ペイロードが `e30` の短いJWTも伏せる、`risk-assessment-framework` は変わらない。秘密を含まない日本語の文とコードは変わらない。全部の例で `redact(redact(x)) == redact(x)`。`str` でない入力は `TypeError`", verifies: ["R-02", "F-03"]}
	"T-03": {title: "4つの経路（`fake` は `responder` で受け取ったもの）で、prompt と system に入れたダミーの秘密が、経路の実装に届く文字列（runner の argv と標準入力、`responder` の引数）に含まれず、`[伏せた]` が含まれる", verifies: ["R-02"]}
	"T-04": {title: "`CLAUDECODE`・`AI_AGENT`・`ORCA_AGENT_SESSION_ID`・`CODEX_THREAD_ID` のどれか1つ（値が空でも）があると、`agent_markers` がその名前を返し、antigravity の `complete` が `RouteRefused`（`markers` に名前、文に値を含まない）で止まり、runner は呼ばれない。印のない env では止まらない。Mapping でない env（`[]` や組のリストを含む）と、鍵を読むと例外を上げる env で、`agent_markers` が `(UNREADABLE_ENV,)` を返す。これらと、鍵は列挙できるが値を読むと例外を上げる Mapping で、antigravity の `complete` が `RouteRefused`、ほかの経路の `complete` が `RouteFailed` で、どちらも runner は呼ばれない。同じ `GuardedRoute` で、1回目は印がなく runner が呼ばれ、env に印を足した2回目は `RouteRefused` で runner が呼ばれない。ほかの3つの経路は印があっても止まらない。`get_route` は印があっても止まらない。`run_subprocess([\"agy\", ...])` は本物の `os.environ` に印があれば（monkeypatch で置く）`subprocess.run` を呼ばずに `RouteRefused`", verifies: ["F-01"]}
	"T-05": {title: "偽の runner で、終了コード1、`subprocess.TimeoutExpired`、`FileNotFoundError`、`ValueError`（NULを含む引数を想定）、空白だけの標準出力、codex の出力のファイルがない・UTF-8でない、antigravity の標準出力がJSONでない・JSONの配列や文字列（dict でない）・`status` が `ERROR`・`status` がない・`response` が空・`response` が数、`responder` が `None` を返す、のどれも `RouteFailed` になり、`route`・`returncode`・`timed_out`・`reason` が場合に合う。標準エラーの先頭に `PASSWORD=` と長い値（2000文字を超える）、途中にダミーのトークンがあるとき、`stderr_tail` が2000文字以内で、ダミーの秘密の値の断片を含まない", verifies: ["F-02"]}
	"T-06": {title: "`shipcast.models.redact` を例外を上げる関数に差し替えると、`complete` がその例外をそのまま上げ（`RouteFailed` に包まない）、runner と `responder` が呼ばれない。prompt の伏せは通り system の伏せで例外を上げる場合も同じ。prompt か system が `str` でなければ `TypeError` で、runner が呼ばれない", verifies: ["F-03"]}
	"T-07": {title: "`DEFAULT_CONFIG_TEXT` の `[models.analyst]` の `model` の行（かその直前の注記の行）に `gpt-6-luna` と `codex debug models` があり、`parse_config(DEFAULT_CONFIG_TEXT, ...)` の `models.analyst` が `ModelConfig(\"codex\", \"gpt-6.2-sol\", \"low\", None)` のまま", verifies: ["R-03"]}
	"T-08": {title: "antigravity で、最終の `text`（system と `JSON_INSTRUCTION` と区切りと prompt、日本語の多バイト文字を含む）の UTF-8 のバイト数が 200,000 を1バイト超えると runner を呼ばずに `RouteFailed`（理由に長さ）、ちょうど 200,000 バイトなら runner が呼ばれる（system あり・want_json ありの組で確かめる）。ほかの経路には上限がない", verifies: ["F-04"]}
	"T-09": {title: "`run_subprocess` を、`shipcast.models.subprocess.run` を記録する偽物に差し替えて呼ぶと、`stdin=None` では `stdin=subprocess.DEVNULL` で `input` を渡さず、`stdin` が文字列では `input` にその文字列を渡し、どちらも `capture_output=True`・`text=True`・`encoding=\"utf-8\"`・`errors=\"replace\"`・渡した `cwd`・`env` と等しい dict・渡した `timeout`・`check=False` で呼ぶ。戻り値の `CompletedProcess` が `Completed` になる。偽物が `TimeoutExpired` を上げればそのまま上がる", verifies: ["R-01", "F-02"]}
	"T-11": {title: "英字（`a`）・`-`・`.`・`_`・`\\`・`\"`・`a-` を、それぞれ 256,000 文字まで繰り返した連続文字列を `redact()` に通すと、どれも2秒未満で終わる（`time.perf_counter` で測る。CI の遅さを見込んだ余裕のある上限）。長さを倍にしても時間が4倍に近づかないことは、手元の確かめに留める", verifies: ["F-06"]}
	"T-10": {title: "道具を止める・狭める引数（F-05）：codex の argv に `--disable shell_tool`・`--disable unified_exec`・`--disable view_image`・`--disable plugins`・`--sandbox read-only`・`--ignore-user-config` があり、claude の argv の最後が `--tools` と空の文字列、antigravity の argv に `--mode plan`・`--sandbox` があって `--dangerously-skip-permissions` がない。3つとも cwd が空のディレクトリ", verifies: ["F-05"]}
}

verification: "`test_commands` を順に流し、すべて終了コード0。試験は偽の runner と `fake` の経路だけで、外部のモデルと本物の `agy` を呼ばない。PRを作った後に、GitHub ActionsのCIの合格を `github-pr-checks` で観測する。本物の経路（codex と antigravity）での確かめは、本人の手動の実行だけ。"
rollback:     "PRを戻す（revert）だけで元に戻る。新しいモジュールを呼ぶ側はまだない（iss-00015・iss-00016 が後で使う）。設定の見本の変更は注記の1行だけ。"
exit:         "PRが最終品質ゲートとCIに合格し、タスク担当が統括にPR・合格のコミット・CIの結果・closure.md・F-05 の受け入れの記録を報告した時点で、このIssueの作業は終わる。マージは統括が本人に確かめてから行い（gates の merger）、`spec-dock work finish` も統括が行う。"

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
		scope:          "開始のコミット（このworktreeの作業の始めの `HEAD`、`f68349a`）から S-05 の後の `HEAD` まで（S-05 は最終品質ゲートの1回目の直し）"
		perspectives:   ["functional-correctness", "requirements-closure", "test-adequacy", "api-contract", "security"]
		test_commands:  ["uv sync --locked", "uv run ruff check", "uv run pytest -q"]
		record_paths:   ["spec-dock/initiatives/00000-00999/iss-00014/report.md（SpecDockの自動の保存で記録する。Gitのcommitは要らない）"]
		second_opinion: "chatgpt（ChatGPT GPT-6 / Extra High。取れないときは GPT-6.2 Astra / high）"
	}
	merge:  "owner"
	merger: "統括（Antigravity）が、本人に確かめてからマージする。AGENTS.md と本人の決定 21 は「統括がマージする」と定め、strict では `coding-task` のマージの規則が本人の確認なしのマージを許さないので、統括は本人の了承を得てからマージする（`merge: owner` は、この本人の確認を指す）。タスク担当と実装担当はマージしない"
	pr:     "branchは `chemitaro/iss-00014`（統括が作ったworktreeのbranch）。PRの本文に、合格のコミット、最終品質ゲートの結果、CIの結果と、F-05 の残る危険（`agy -p` の道具）を本人が受け入れたこと（requirement.cue の decisions の Q-01）を書く。Issueを自動で閉じる書き方（Closes #14）は使わず、`Refs #14` にする"
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
	assignment:   "S-01, S-02, S-03, S-04, S-05 → impl（連続）"
	same_session: "なし（実装担当の提供元がタスク担当と違うため、別のセッションにする）"
}
