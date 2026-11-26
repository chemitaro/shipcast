package spec

goal: "新しい `run.py` に、CLI・日の決め方・repositoryごとの処理と `runs` への記録を先に作り、その上に lock と TCC の見分けを足し、最後に再実行の冪等性を試験で確かめる。試験は fake の経路の `responder`、偽の collector、一時ディレクトリだけで行う。"

steps: {
	"S-01": {
		status:   "doing"
		title:    "run のコマンドと記録（`run.py` の `configure`・`run`・`previous_day`、`cli.py` の接続）"
		text:     "D-01・D-03。T-01・T-02・T-03・T-04 を `tests/test_run.py` に先に書いて落ちることを確かめ（Red）、`src/shipcast/run.py` に `previous_day`・`configure`・`run`・`journal_extensions_for`（lock なし、TCC の案内なし、読み取りの確かめなし）を書き、`cli.py` の `run` の葉に `run_command.configure` を渡し、`tests/test_cli.py` の未実装の一覧から `run` を外して通す（Green）。完了の条件：`test_commands` がすべて終了コード0。"
		realizes: ["R-01", "R-02"]
		session:  "impl"
	}
	"S-02": {
		status:   "todo"
		title:    "lock（`run_lock`）と TCC の見分け（`with_tcc_hint`）"
		text:     "D-02・D-04。T-05・T-06・T-07 を先に書いて Red、`LOCK_FILENAME`・`run_lock`・`TCC_MARKER`・`with_tcc_hint`・`probe_readable` を書き、`run` の手順4と D-03 の手順0と誤りの文につないで Green。完了の条件：`test_commands` がすべて終了コード0。"
		realizes: ["F-01", "F-02"]
		after:    ["S-01"]
		session:  "impl"
	}
	"S-03": {
		status:   "todo"
		title:    "再実行の確かめ"
		text:     "D-05。T-08 を書く。既存の部品の性質で満たすので、Red にならないことがある。そのときは、試験が満たすべき性質を本当に見ていることを、一時的に `Store.add_events` を `INSERT` だけにする等の手元の変更で落ちることを確かめて戻し、報告に書く（その変更はcommitしない）。完了の条件：`test_commands` がすべて終了コード0。"
		realizes: ["R-03"]
		after:    ["S-02"]
		session:  "impl"
	}
}

tests: {
	"T-01": {title: "`previous_day`：`Asia/Tokyo` の 2026-11-26T03:00+09:00（UTC では 11-25T18:00）で 2026-11-25、2026-11-26T00:30+09:00 で 2026-11-25、2026-03-01T03:00+09:00 で 2026-02-28。`now` を省くと `datetime.now(tz)` を使う（module の `datetime` を差し替えて確かめる）", verifies: ["R-01"]}
	"T-02": {title: "CLI の成功：`SHIPCAST_CONFIG` の一時の設定（経路は `fake`、repository 2件、`state_dir`・`journal_dir` は一時ディレクトリ）と偽の collector（Event を1件返す）と `responder` で、`main([\"run\"])` が0を返し、前日（module の `datetime` を固定して確かめる）の日誌が2件ともでき、`runs_for` がそれぞれ1行（`result == \"ok\"`、`error == \"\"`、`started_at <= finished_at`、時間帯つき）。標準出力に `<id> <日>: 日誌を書きました` が2行と `shipcast run: <日>: 成功 2件、失敗 0件`。`write_day` を包む偽物で、`extensions` に `journal_extensions_for` の戻り値（今は `None`）が渡ることを確かめる。`--repo demo-app --date 2026-11-20` では `demo-app` の 2026-11-20 の日誌だけができ、`runs` も `demo-app` だけ。`shipcast run --help` に `--repo ID` と `--date YYYY-MM-DD` がある", verifies: ["R-01", "R-02"]}
	"T-03": {title: "1つの失敗でほかを止めない（パラメーター化）：1つ目のrepositoryで (a) collector が `CollectError` を投げる、(b) 書き手の `responder` が2回とも誤る（`WriteFailed`）、(c) `write_day` を差し替えて `RuntimeError(\"試験用\")` を投げる、のどれでも、終了コード1、2つ目のrepositoryの日誌ができて `runs` が `ok`、1つ目の `runs` が1行で `failed`、誤りが空でなく (a) は collector の文、(c) は `RuntimeError: 試験用` を含む。標準エラーに `shipcast run: 失敗: <id>:` が出て、traceback がない。標準出力に `<1つ目のid> <日>: 失敗しました（理由は標準エラー）` と `成功 1件、失敗 1件` が出る。(a) では1つ目の日誌のファイルがない", verifies: ["R-02"]}
	"T-04": {title: "入口の誤り：登録されていない `--repo` と、登録が0件の設定は、終了コード1で、標準エラーに直し方が出て、`state_dir` に何も作らない（lock のファイルもない）。`get_route` を差し替えて `RouteFailed` を投げさせると、終了コード1、標準エラーに `shipcast run: モデルの経路を作れません:`、選んだ2件の `runs` がどちらも `failed` でその文を含み、collector は呼ばれない。`state_dir` がファイルのときは終了コード1で `状態の置き場を開けません` が出る", verifies: ["R-01", "R-02"]}
	"T-05": {title: "lock が取れないとき：試験の中で `<state_dir>/run.lock` を別に開いて `fcntl.flock(LOCK_EX)` で持ったまま `main([\"run\"])` を呼ぶと、終了コード0、標準エラーに `前の実行が動いているため、今回は何もせずに終えます` と lock の path、collector も `get_route` も呼ばれず、日誌も `runs` の行もない（`state.sqlite3` がない）。持っている lock を外すと、次の `main([\"run\"])` は処理して0", verifies: ["F-01"]}
	"T-06": {title: "lock の後始末：`run` が正常に終わった後と、`write_day` が `KeyboardInterrupt` を投げて上がった後のどちらでも、試験から `run.lock` を `LOCK_EX | LOCK_NB` で取れる。`run.lock` のファイルは残る", verifies: ["F-01"]}
	"T-07": {title: "TCC：`with_tcc_hint` は `Operation not permitted` を含む文に「フルディスクアクセス」を含む案内を足し、含まない文はそのまま返す。CLI で、collector が `CollectError(\"git rev-parse が失敗しました: /Volumes/x/demo-app: fatal: ... Operation not permitted\")` を投げる場合と、`write_day` を差し替えて `PermissionError(errno.EPERM, \"Operation not permitted\", \"/Volumes/x\")` を投げる場合のどちらでも、そのrepositoryの `runs` の誤りと標準エラーに「フルディスクアクセス」が入る。`Operation not permitted` を含まない失敗の誤りには入らない。`shipcast.run.probe_readable` を差し替えて `PermissionError(errno.EPERM, \"Operation not permitted\", <path>)` を投げさせると、collector が呼ばれず、そのrepositoryが `failed` で誤りに「フルディスクアクセス」が入り、もう一方は `ok`。`PermissionError(errno.EACCES, \"Permission denied\")` なら `failed` だが案内はない。実際の `probe_readable` は、ないpathでは例外を出さない（collector の「ディレクトリがありません」がそのまま `runs` に入る）", verifies: ["F-02"]}
	"T-08": {title: "再実行：同じ設定と `--date` で `main([\"run\"])` を2回呼ぶ（module の `datetime` で2回目の時刻を進める）と、どちらも0。2回目の後、各repositoryの `events` の件数が1回目の後と同じ、日誌のファイルが2回目の `generated_at` の前付けに置き換わり、`entries` の行が repository と日で1行、`runs_for` が repositoryごとに2行（どちらも `ok`）", verifies: ["R-03"]}
}

verification: "`test_commands` を順に流し、すべて終了コード0。試験は fake の経路の `responder` と偽の collector だけで、外部のモデルと `agy` を呼ばない。PRを作った後に、GitHub ActionsのCIの合格を `github-pr-checks` で観測する。本物の経路と外付けvolumeでの確かめ（TCC）は、本人の手動の実行だけ。"
rollback:     "PRを戻す（revert）だけで元に戻る。状態の表の形は変えない（`runs` に行が足されるだけ）。`<state_dir>/run.lock` の空のファイルが残るが、ほかの処理は読まない。"
exit:         "PRが最終品質ゲートとCIに合格し、タスク担当が統括にPR・合格のコミット・CIの結果・closure.md を報告した時点で、このIssueの作業は終わる。マージと `spec-dock work finish` は統括が行う。"

// 関門（coding-task）。保証レベル standard の既定と、本人の決定 18〜21（init-00001 の plan.cue の delivery）に従う。
gates: {
	spec_review: "Claude `spec-reviewer`（Opus 5.5 / high）。P0・P1がなくなるまで、3回まで"
	checkpoints: "なし。理由：手順は3つで、1人の実装担当が続けて書き、どれもこのIssueの新しいmodule（`run.py`）と試験が中心で、既存のコードは `cli.py` の数行と `tests/test_cli.py` の一覧だけを変える。lock と記録の境界は最終品質ゲートの `functional-correctness`・`api-contract` の観点で確かめる"
	final_quality_gate: {
		scope:          "開始のコミット（統括が作ったworktreeの作業の始めの `HEAD`、`ef3075f`）から S-03 の後の `HEAD` まで"
		perspectives:   ["functional-correctness", "requirements-closure", "test-adequacy", "api-contract", "security-baseline"]
		test_commands:  ["uv sync --locked", "uv run ruff check", "uv run pytest -q"]
		record_paths:   ["spec-dock/initiatives/00000-00999/iss-00021/report.md（SpecDockの自動の保存で記録する。Gitのcommitは要らない）"]
		second_opinion: "none"
	}
	merge:            "agent"
	merger:           "統括。タスク担当と実装担当はマージしない（本人の決定 21）。条件は `coding-task` の `references/merge.md`（CIの合格の観測を含む）"
	merge_permission: "本人の「PR のマージは各ワーカーが行わず、統括（Antigravity）が行う」（2026-11-26、`content/decisions/20261126-journal-format-and-hackathon-plan.md` の 21。init-00001 の `plan.cue` の `delivery.gates_by_level.standard.merge`）"
	pr:               "branchは `chemitaro/iss-00021`（統括が作ったworktreeのbranch）。PRの本文に、合格のコミット、最終品質ゲートの結果、CIの結果を書く。Issueを自動で閉じる書き方（Closes #21）は使わず、`Refs #21` にする"
}

execution: {
	sessions: {
		spec: {task: "仕様化（起動した側が選んだ値の記録）", provider: "claude", model: "Claude Opus 5.5", effort: "medium", rationale: "統括が起動したOrcaの作業者。値は起動した側が方針§2の standard のタスク担当の行から決めた（事実の記録）"}
		owner: {task: "タスク担当（仕様、説明資料、レビュー、最終品質ゲート、PR、CIの観測）", provider: "claude", model: "Claude Opus 5.5", effort: "medium", rationale: "方針§2のタスク担当の standard の行。spec と同じセッション"}
		impl: {task: "実装（S-01〜S-03）。このworktreeで起動するOrcaの作業者", provider: "codex", model: "GPT-6.2 Sol", effort: "medium", rationale: "方針§2の、テストで確かめられる実装（バックエンド）の行と、統括の依頼"}
	}
	reviews: {
		spec_review: {role: "仕様のレビューの `spec-reviewer`", model: "Claude Opus 5.5", effort: "high"}
		final_gate: {role: "最終品質ゲートの `quality-gate-reviewer`", after: "S-03", model: "Claude Opus 5.5", effort: "medium"}
	}
	assignment:   "S-01, S-02, S-03 → impl（連続）"
	same_session: "なし（実装担当の提供元がタスク担当と違い、統括の依頼が Codex の実装担当を名指すため、別のセッションにする）"
}
