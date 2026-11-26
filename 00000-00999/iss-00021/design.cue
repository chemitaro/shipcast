package spec

goals: [
	"1回の `shipcast run` で、選んだrepositoryの前日の日誌がそろい、repositoryごとの結果が `runs` に残る",
	"1つのrepositoryの失敗が、ほかのrepositoryの日誌を止めない",
	"重ねて動かさず、同じ日を何度動かしても状態が重複しない",
	"夜に本人が見ていなくても、失敗の理由と直し方が記録から分かる",
	"既存の部品（`collect_repo`・`write_day`・`Store.record_run`）を変えずに組み合わせる",
]

current: "`shipcast run` は未実装の印を出して終了コード2で終わる。`shipcast write` は、既定の日が今日で、全repositoryを collect → write するが、`runs` に記録せず、重ねての実行を防がない。"
target:  "`shipcast run` が、lock を取ってから、選んだrepositoryを1つずつ collect → write し、repositoryごとに `runs` へ1行を書き、全部が成功なら0、1つでも失敗なら1で終わる。"

design: {
	"D-01": {
		title: "CLI と日・repositoryの決め方（`shipcast.run.configure`・`run`）"
		text: """
		`src/shipcast/run.py` に置く。`configure(parser)` は `--repo`（`metavar="ID"`、既定は全件）と `--date`（`type=date.fromisoformat`、`metavar="YYYY-MM-DD"`、既定は前日）を足し、`parser.set_defaults(func=run)`。`cli.py` は、import に `from shipcast import run as run_command  # isort: skip`（ほかの葉と同じ並び）を足し、`Entry("run", "素材の収集から日誌の作成までを実行する", run_command.configure)` にするだけ（`run` の名前は使わない）。

		`run(args) -> int` の順：

		1. `load_config()`。`ConfigError` は `shipcast run: <誤り>`、`OSError` は `shipcast run: 設定ファイルを開けません: <誤り>` と直し方を標準エラーに出し、1。
		2. `tz = ZoneInfo(config.timezone)`、`day = args.date or previous_day(tz)`。`previous_day(tz, now=None)` は `(now or datetime.now(tz)).astimezone(tz).date() - timedelta(days=1)`（試験は `now` を渡すか、module の `datetime` を差し替える）。
		3. repositoryを選ぶ。`--repo` が登録にないとき、登録が0件のときは、`shipcast write` と同じ文（接頭辞は `shipcast run:`）と直し方を出して1。ここまでは何も書かない（lock のファイルも作らない）。
		4. lock を取る（D-02）。取れなければ0。
		5. `Store(config.state_dir)`。`StateError`・`OSError` は `shipcast run: 状態の置き場を開けません:` と直し方で1。
		6. `get_route(config.models.analyst)`・`get_route(config.models.writer)`。`RouteError`・`ValueError` なら、標準エラーに `shipcast run: モデルの経路を作れません: <誤り>` を出し、選んだrepositoryのすべてを、その文を誤りとする `failed` の `Run` として記録し（開始と終了は記録の時刻）、1。
		7. repositoryごとに D-03。全部が `ok` なら0、1つでも `failed`（または記録の失敗）なら1。最後に標準出力へ `shipcast run: <日>: 成功 <n>件、失敗 <m>件` を出す。

		`KeyboardInterrupt` などの `BaseException` は受け止めずに上げる。そのときも `run_lock` の `finally` で lock を外す（D-02）。
		"""
		satisfies: ["R-01", "R-02"]
	}
	"D-02": {
		title: "lock（`run.lock` と `fcntl.flock`）"
		text: """
		`LOCK_FILENAME = "run.lock"`。`config.state_dir` を `mkdir(parents=True, exist_ok=True)` で作り、`<state_dir>/run.lock` を `os.open(path, os.O_RDWR | os.O_CREAT, 0o644)` で開き、`fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)` で取る。文脈管理（`contextlib.contextmanager` の `run_lock(state_dir)`）で、正常の終わりにも例外（`BaseException` を含む）の経路にも、`finally` で `LOCK_UN` と `os.close` を行う。ファイルは消さない（消すと、次の実行と別のinodeで取り合う）。

		- 取れない（`BlockingIOError`）：収集・Store・経路に触れず、標準エラーに `shipcast run: 前の実行が動いているため、今回は何もせずに終えます: <lockのpath>` を出し、終了コード0。`runs` には書かない（requirement の決定）。
		- 開けない（`OSError`）：`shipcast run: 状態の置き場を開けません: <誤り>` と直し方で1。

		lock は、Store を開く前に取り、全repositoryの処理と記録の後に外す。
		"""
		satisfies: ["F-01"]
	}
	"D-03": {
		title: "repositoryごとの処理と記録"
		text: """
		repositoryごとに、`started = datetime.now(tz)` を取り、次を `try` / `except Exception` で囲む。

		0. 読み取りの確かめ：`probe_readable(repo.path)`（`os.scandir(path)` を開いて閉じるだけ）。`PermissionError` なら、`str(error)` を誤りとして `failed`（収集を呼ばない）。ほかの `OSError`（ない、ディレクトリでない）は無視して収集に任せる（collector が今の文で報告する）。
		1. `collect_repo(store, repo, day, tz=tz, collectors=COLLECTORS)`。警告は標準エラーに `shipcast run: 警告: <id>: <警告>`。`errors` があれば、誤りの文を `; ` でつないだものを誤りとし、`write_day` を呼ばずに `failed`。
		2. 誤りがなければ `write_day(store, repo.id, day, tz=tz, journal_dir=config.journal_dir, analyst=analyst, writer=writer, now=datetime.now(tz))`。`extensions` には `journal_extensions_for(store, config)` の戻り値を渡す（今は `None`。iss-00019 との追随でここだけを変える。requirement の決定）。成功なら `ok`、標準出力に `<id> <日>: 日誌を書きました（出来事 <n>件、話題 <m>件）: <path>`。
		3. 例外は `failed`。誤りの文は、`AnalyzeFailed`・`WriteFailed`・`RouteError`・`JournalFormatError`・`OSError`・`StateError`・`CollectError` なら `str(error)`、それ以外は `<型の名前>: <str(error)>`。

		`failed` のときは、誤りの文に D-04 の案内を添え、標準エラーに `shipcast run: 失敗: <id>: <誤りの文>`、標準出力に `<id> <日>: 失敗しました（理由は標準エラー）` を出す。最後に `store.record_run(Run(repo.id, started, datetime.now(tz), result, error))`。成功の誤りは空の文字列。記録が例外（`Exception`）で失敗したら、標準エラーに `shipcast run: 記録に失敗しました: <id>: <誤り>` を出し、終了コードを1にして、次のrepositoryへ進む。

		`COLLECTORS`・`get_route`・`datetime`・`write_day`・`probe_readable` は `shipcast.run` の module の名前として読む（試験で `monkeypatch.setattr(run, ...)` で差し替える）。
		"""
		satisfies: ["R-01", "R-02", "R-03"]
	}
	"D-04": {
		title: "TCCの失敗の見分け（`tcc_hint`）"
		text: """
		`TCC_MARKER = "Operation not permitted"`。`with_tcc_hint(error_text) -> str` は、文に `TCC_MARKER` を含むときだけ、文の後に改行と次の案内を足して返す（含まなければそのまま）。

		> 直し方: macOS の「システム設定」→「プライバシーとセキュリティ」→「フルディスクアクセス」で、shipcast を動かすプログラム（launchd から動かすときは `shipcast` の実行ファイル、手で動かすときはターミナル）を許可してください

		案内は、`runs` の誤りと標準エラーの両方に入る。`PermissionError(errno.EPERM, ...)` の `str` は `Operation not permitted` を含むので、D-03 の手順0の読み取りの確かめ（TCC は外付けvolumeのディレクトリの読み取りを EPERM で拒む）と、例外の経路でも同じに見分ける。collector の文（`rev-parse` の失敗は stderr を捨てる）に印がなくても、手順0が先に見分ける。EACCES（`Permission denied`）は TCC ではないので案内を足さない。
		"""
		satisfies: ["F-02"]
	}
	"D-05": {
		title: "再実行の冪等性"
		text: """
		新しい仕組みは足さず、既存の部品の性質で満たす。`Store.add_events` は `INSERT OR IGNORE`（同じ `id` の Event は増えない）、`write_day` は日誌を `write_atomic` で置き換え、`save_entry` は `(repo_id, date)` で上書き。`runs` は実行の履歴で、実行ごとに行が足される。lock は実行の終わりに外れるので、続けての2回目は取れる。
		"""
		satisfies: ["R-03"]
	}
}

risks: [
	"`write_day` の中で日誌の置き換えの後に `save_entry` が失敗すると、ファイルと `entries` がずれる（iss-00016 の申し送り）。`run` はその repository を `failed` として記録し、同じ日の再実行で両方を書き直す",
	"`fcntl.flock` は NFS などでは効かないことがある。状態の置き場は手元の `~/.local/state/shipcast` を想定する",
	"TCC が `os.scandir` を通し、git の段だけを拒む場合は、手順0で見分けられず、collector の文に印があるときだけ案内が付く。macOS の挙動は本人の手動の確かめで見る",
	"`write.py` の CLI と、repositoryの選び方と誤りの文が重複する。並行作業との衝突を避けるため、共通化は後のIssueに回す",
]
