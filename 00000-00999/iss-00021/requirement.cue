package spec

schema: "specdock/v1"

assurance: {
	level:  "standard"
	reason: "夜の処理の入口で、全repositoryの収集・分析・執筆を順に動かし、実行の記録を残す。誤ると毎晩の日誌が欠け、重ねて動くと状態が乱れるが、手元の処理だけで、PRを戻して同じ日を実行し直せば回復できる"
}

purpose: "`shipcast run [--date YYYY-MM-DD] [--repo <id>]` で、登録した全repository（または1つ）の、指定した日（既定は設定の時間帯での前日）の日誌を、収集 → 分析 → 執筆の順に1度で作り、repositoryごとの結果を状態の `runs` の表に残す。毎晩3時の自動の実行（iss-00022 の launchd）の入口になる。"

background: """
親の epic-00007 の R-01・R-02・F-01・F-02 を、このIssueが受け持つ（epic-00007 の `plan.cue` の `slices`）。設計の骨は epic-00007 の D-01（`shipcast run`）・D-02（lock）・D-04（TCCの失敗の見分け）。

`main` にすでにある次のものを、名前を変えずに使う。

- `shipcast.config`：`load_config()`・`ConfigError`、`Config.timezone`・`state_dir`・`journal_dir`・`models`・`repos`（iss-00009）
- `shipcast.state`：`Store`（`record_run(run)`・`runs_for(repo_id)`・`add_events` は `INSERT OR IGNORE`）、`Run(repo_id, started_at, finished_at, result, error)`（`result` は `ok` か `failed`）、`StateError`（iss-00010）。`runs` の表はすでにあり、形は変えない
- `shipcast.collect`：`COLLECTORS`。`shipcast.collect.base`：`collect_repo(store, repo, day, *, tz, collectors)`（誤りは例外でなく `RepoCollection.errors` に入る）（iss-00011〜iss-00013）。git の失敗は `git <subcommand> が失敗しました: <path>: <stderrの最後の行>` の文になるが、最初の `rev-parse --show-toplevel` の失敗は stderr を捨てて `<path>: Gitのrepositoryではありません` になる（`collect/git.py` の `_resolve_tip`）。そのため TCC の見分けは collector の文だけに頼らない（design.cue の D-04）
- `shipcast.models`：`get_route(model_cfg)`、`RouteError`（iss-00014）
- `shipcast.write`：`write_day(store, repo_id, day, *, tz, journal_dir, analyst, writer, now)`（日誌の置き換えと `entries` の記録まで。iss-00016）

`shipcast write` は、既定の日が「今日」で、`runs` に記録しない。`shipcast run` は既定の日が「前日」で、`runs` に記録し、重ねて動かさない。並行する iss-00019（ネタポイントの台帳・日誌の印）が `write.py` と `cli.py` を変えうるので、このIssueは `write.py` を変えず、`cli.py` は `run` の葉をつなぐ最小の差分にとどめる。
"""

includes: [
	"`src/shipcast/run.py`（新しいmodule）：日の決め方、repositoryの選び方、lock、TCCの見分け、repositoryごとの処理と記録、CLI（`configure`・`run`）",
	"`src/shipcast/cli.py`：`run` の葉を `shipcast.run.configure` につなぐ（ほかの葉は変えない）",
	"`tests/test_run.py`（新しい試験）、`tests/test_cli.py` の未実装の一覧から `run` を外す",
]

excludes: [
	"launchd の登録（`shipcast schedule install`・`uninstall`）とログのファイルの置き場（iss-00022）。このIssueのログは標準出力と標準エラーだけで、launchd がそれをファイルに書く",
	"`shipcast.write`・`shipcast.state`・`shipcast.config`・`shipcast.collect`・`shipcast.models`・`shipcast.analyze`・`shipcast.model` の変更",
	"`runs` の表の形の変更、古い `runs` の行の削除",
	"ネタポイントの台帳と発信の下書き（iss-00019・iss-00020）。`shipcast run` から「発信の芽」を出す配線は、両方が `main` に入った後の追随（decisions を見る）",
	"macOS のフルディスクアクセスを自動で付けること。案内の文を記録に添えるだけで、許可は本人が行う",
	"本物の `codex`・`claude`・`agy` を呼ぶ試験。本物の経路での確かめは、本人の手動の実行だけ",
]

constraints: [
	"試験とエージェントの作業では外部のモデルを呼ばない。経路は `fake`（`responder`）を使い、`agy` を呼ばない",
	"情報源のrepositoryは読むだけ（収集は既存の collector に任せ、このIssueは触らない）",
	"`fcntl` を使う（対象は macOS と Linux。CI は Linux）",
]

requirements: {
	"R-01": {
		title: "全repository（または `--repo`）の、`--date`（既定は前日）の日誌を、collect → analyze → write で作る"
		text:  "repositoryごとに `collect_repo` → `write_day` の順。設定の順に、1つずつ処理する。形は design.cue の D-01〜D-03。"
		acceptance: [
			"`--date` を省くと、設定の `timezone` での今日の前日になる（例：`Asia/Tokyo` の 2026-11-26 03:00 に動くと 2026-11-25）",
			"fake の経路で、登録した2つのrepositoryの日誌（`journal_path(journal_dir, repo, day)`）ができ、終了コード0",
			"`--repo <id>` を付けると、そのrepositoryだけを処理する。登録されていない id は、何も書かずに終了コード1で、直し方を示す",
			"`shipcast run --help` に `--repo ID` と `--date YYYY-MM-DD` がある",
		]
	}
	"R-02": {
		title: "repositoryごとの成功と失敗を実行の記録に残し、1つの失敗でほかを止めない"
		acceptance: [
			"`runs` の表に、処理したrepositoryごとに1行（開始・終了・結果 `ok` か `failed`・誤りの文）が入る。成功の行の誤りは空",
			"1つのrepositoryの収集の失敗、分析・執筆の失敗、想定外の例外のどれでも、そのrepositoryを `failed` として記録し、次のrepositoryを処理する",
			"全部が成功なら終了コード0、1つでも失敗なら1。標準出力に、処理したrepositoryごとに成功か失敗かの1行と、最後に件数の1行が出る。失敗の理由は標準エラーに出る",
		]
	}
	"R-03": {
		title: "同じ日の再実行で重複しない"
		acceptance: [
			"同じ日を2回実行しても、`events` の件数が増えず、日誌のファイルが置き換わり（2回目の `generated_at` になる）、`entries` は repository と日で1行のまま",
			"`runs` は実行の履歴なので、実行ごとに行が足される",
		]
	}
}

failures: {
	"F-01": {
		title:  "前の実行が動いているときは、重ねずに終わる"
		text:   "状態の置き場の `run.lock` を排他で取れなければ、収集も記録もせずに、その旨を標準エラーに書き、終了コード0で終わる。"
		impact: "重ねて動くと、同じ日誌の置き換えと状態の書き込みが競い、毎晩の実行が同時に2つ動く"
	}
	"F-02": {
		title:  "TCCで読めないときは、直し方を記録に添える"
		text:   "外付けvolumeのrepositoryを macOS の許可（TCC）で読めず、repositoryのディレクトリの読み取りが `PermissionError`（`Operation not permitted`）になるとき、または誤りの文に `Operation not permitted` があるときは、`runs` の誤りと標準エラーに、フルディスクアクセスの付け方を添える。"
		impact: "夜の実行は本人が見ていないので、理由が分からないと毎晩同じ失敗が続く"
	}
}

decisions: [
	"lock を取れないときは、`runs` に書かず、標準エラーの1行だけを記録とする（epic-00007 の D-02「記録して終了コード0」の「記録」をこう解釈する。`runs` は repositoryごとの結果の表で、動いている側が状態を書いている最中に触らないため）。タスク担当の判断（2026-11-26）",
	"モデルの経路が作れないときは、選んだrepositoryのすべてを、その理由で `failed` として記録し、終了コード1（夜の実行の失敗が `runs` から分かるように）。タスク担当の判断（2026-11-26）",
	"`write.py` を変えず、repositoryごとの処理は `run.py` に書く（並行する iss-00019 との衝突を避ける。統括の依頼）",
	"iss-00019 の申し送り（`shipcast run` も `write_day` に `extensions=journal_extensions(store, config.neta.threshold)` を渡す）は、`journal_extensions` がまだ `main` にないので、このIssueでは配線しない。`run.py` は拡張点の一覧を1つの関数 `journal_extensions_for(store, config)`（今は `None` を返す）から得る形にし、iss-00019 と iss-00021 の両方が `main` に入った後に、その関数の中身を `write.journal_extensions(store, config.neta.threshold)` に変える小さな追随を、統括が後にマージする側か追随のIssueに割り当てる。タスク担当の判断（2026-11-26）。統括に申し送る",
]
