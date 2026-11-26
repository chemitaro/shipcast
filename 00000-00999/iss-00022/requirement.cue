package spec

schema: "specdock/v1"

assurance: {
	level:  "standard"
	reason: "本人のmacOSのlaunchdに定期の実行を登録するplistを作る。誤ると毎晩の処理が動かない・ログが残らないが、plistを外せば元に戻り、読み込み（`launchctl`）は既定では本人が行う"
}

purpose: "`shipcast schedule install|uninstall` で、毎日3時に `shipcast run` を動かす launchd の登録（`com.shipcast.nightly.plist`）を作り、外せるようにする。あわせて、夜の `shipcast run` の日誌にも「発信の芽」の印が付くよう、iss-00021 の差し込み口をネタポイントの台帳（iss-00019）につなぐ。"

background: """
親の epic-00007 の R-03 を、このIssueが受け持つ（epic-00007 の `plan.cue` の `slices`）。設計の骨は epic-00007 の D-03（launchd の登録）。iss-00021（`shipcast run`）と iss-00019（ネタポイントの台帳・日誌の印）は `main` に入っている。

`main` にすでにある次のものを、名前を変えずに使う。

- `shipcast.config`：`load_config()`・`ConfigError`・`config_path()`、`Config.state_dir`・`neta.threshold`（iss-00009・iss-00019）。設定の置き場は環境変数 `SHIPCAST_CONFIG`（既定 `~/.config/shipcast/config.toml`）
- `shipcast.run`：`run(args)` と、日誌の拡張点を渡す差し込み口 `journal_extensions_for(store, config)`（今は `None` を返す。iss-00021 の決定で、iss-00019 と iss-00021 の両方が `main` に入った後に、中身を `write.journal_extensions(store, config.neta.threshold)` に変える追随がこのIssueに割り当てられた）
- `shipcast.write`：`journal_extensions(store, threshold)`（`EXTENSIONS` の後に `NetaSprout` を足した組）
- `shipcast.cli`：`schedule` の `install`・`uninstall` の葉は、未実装の印（終了コード2）を出す

launchd は、ユーザーのエージェント（`~/Library/LaunchAgents/` の plist）を `launchctl bootstrap gui/<uid> <plist>` で読み込み、`launchctl bootout gui/<uid>/<Label>` で外す。plist の中の道筋は `~` を展開しないので、すべて絶対の道筋にする。launchd が動かすプロセスの `PATH` は最小（`/usr/bin:/bin:/usr/sbin:/sbin`）で、`shipcast run` が呼ぶ `git`・モデルのCLIが見つからない。

並行する iss-00020（`shipcast draft x`）が `cli.py` と `tests/test_cli.py` を変えるので、`cli.py` は `schedule` の2つの葉をつなぐ最小の差分にとどめる。
"""

includes: [
	"`src/shipcast/schedule.py`（新しいmodule）：plist の組み立て、`shipcast` の実行ファイルの見つけ方、`install`・`uninstall` のCLI（`configure_install`・`configure_uninstall`）、`launchctl` の呼び出し（`--load`・`--unload` のときだけ）",
	"`src/shipcast/cli.py`：`schedule` の `install`・`uninstall` の葉を `shipcast.schedule` につなぐ（ほかの葉は変えない）",
	"`src/shipcast/run.py`：`journal_extensions_for` の中身を `write.journal_extensions(store, config.neta.threshold)` にする（iss-00019・iss-00021 からの追随）",
	"`README.md`：導入（`uv tool install`）、登録、外し方、外付けvolumeのときのフルディスクアクセスの付け方の節",
	"`tests/test_schedule.py`（新しい試験）、`tests/test_run.py` の拡張点の確かめの更新と「発信の芽」の試験、`tests/test_cli.py` の未実装の一覧から `schedule` の2件を外す、`tests/test_readme.py` に節の確かめ",
]

excludes: [
	"試験・エージェントの作業で、本物の `~/Library/LaunchAgents/` に書くこと、本物の `launchctl` を動かすこと。試験は一時のディレクトリ（`HOME` を差し替える）と、`launchctl` を呼ぶ関数の偽物だけで行う",
	"本人の環境での登録（`shipcast schedule install --load` の実行）。本人が行う",
	"macOS のフルディスクアクセスを自動で付けること。手順を README と出力に示すだけ",
	"ログのファイルの回転・削除",
	"Linux の systemd・cron への登録（対象は macOS の launchd だけ）",
	"`shipcast run` の処理（収集・執筆・lock・TCC の見分け）、`shipcast.write`・`shipcast.neta`・`shipcast.config`・`shipcast.state` の変更",
	"README の「状態」の節など、このIssueの節の外の書き換え",
]

constraints: [
	"試験とエージェントの作業では外部のモデルを呼ばない。経路は `fake`（`responder`）を使い、`agy` を呼ばない",
	"plist の生成は標準ライブラリの `plistlib` で行う（依存を足さない）",
	"CI は Linux なので、試験は `launchctl` がなくても通る形にする（plist の生成と書き出しは macOS に依らない）",
	"公開のrepositoryなので、試験の見本の道筋・uid は架空のもの（例 `/Users/example`、uid `501`）にする",
]

requirements: {
	"R-01": {
		title: "`schedule install` が、毎日3時に `shipcast run` を動かす plist を書き、読み込みのコマンドを示す"
		text:  "形は design.cue の D-01〜D-03。"
		acceptance: [
			"`~/Library/LaunchAgents/com.shipcast.nightly.plist` ができ、`Label` が `com.shipcast.nightly`、`StartCalendarInterval` が Hour 3・Minute 0、`ProgramArguments` が `shipcast` の実行ファイルの絶対の道筋と `run` の2つ、`StandardOutPath`・`StandardErrorPath` が設定の `state_dir` の下の `logs/` の絶対の道筋",
			"`logs/` のディレクトリができる。plist の `EnvironmentVariables` に、登録した時の `PATH` が入り、`SHIPCAST_CONFIG` があればその絶対の道筋も入る",
			"`--load` を付けなければ `launchctl` を呼ばず、標準出力に本人が打つ `launchctl bootstrap gui/<uid> <plist>`（と、読み込み済みのときに先に打つ `launchctl bootout gui/<uid>/com.shipcast.nightly`）を示して、終了コード0",
			"`--load` を付けたときだけ、`launchctl bootstrap gui/<uid> <plist>` を呼ぶ。失敗したら理由を標準エラーに出し、終了コード1",
			"もう一度 `install` すると、plist を置き換える",
		]
	}
	"R-02": {
		title: "`schedule uninstall` が、plist を外す"
		acceptance: [
			"plist のファイルが消え、外すコマンド（`launchctl bootout gui/<uid>/com.shipcast.nightly`）を示して、終了コード0",
			"plist がないときも、誤りにせず、その旨を示して終了コード0",
			"`--unload` を付けたときだけ、plist を消す前に `launchctl bootout` を呼ぶ。外せなくても（読み込んでいなかったときを含む）、警告を出して plist を消し、終了コード0",
		]
	}
	"R-03": {
		title: "README に、導入・登録・外し方・フルディスクアクセスの付け方を書く"
		acceptance: [
			"README に、`uv tool install` での導入、`shipcast schedule install`（と `--load`）での登録、`shipcast schedule uninstall` での外し方、ログの置き場、外付けvolumeのrepositoryを読むときのフルディスクアクセスの付け方の節がある",
		]
	}
	"R-04": {
		title: "夜の `shipcast run` の日誌にも「発信の芽」の印が付く（iss-00019・iss-00021 からの追随）"
		acceptance: [
			"`shipcast run` が `write_day` に渡す拡張点が `write.journal_extensions(store, config.neta.threshold)` と同じ形（`EXTENSIONS` の後に、設定のしきい値の `NetaSprout`）になる",
			"fake の経路で、ネタポイントがしきい値に届いた日の `shipcast run` の日誌に `:::tip 発信の芽（ネタポイント <n>）` の囲みが入り、届かない日には入らない",
		]
	}
}

failures: {
	"F-01": {
		title:  "`shipcast` の実行ファイルが `uv tool install` のものでないときは、登録しない"
		text:   "`PATH` から `shipcast` が見つからないとき、または見つかった道筋（とその実体）が `.venv` の下（worktree や checkout の `uv run`）のときは、plist を書かず、`uv tool install` の直し方を標準エラーに出して終了コード1。"
		impact: "checkout の `.venv` の `shipcast` を登録すると、branch の切り替えや worktree の削除で、夜の実行が知らないうちに別のコードで動くか、動かなくなる（epic-00007 の D-03）"
	}
	"F-02": {
		title:  "設定が読めないとき、書けないときは、何も残さずに終わる"
		text:   "`install` で設定が読めない（`ConfigError`・`OSError`）ときは、plist を書かずに直し方を出して終了コード1。plist・`logs/` を書けない（`OSError`）ときは、理由を出して終了コード1。`uninstall` で plist を消せないときも終了コード1。"
		impact: "書きかけの plist を launchd が読むと、夜の実行が誤った道筋で動く"
	}
}

decisions: [
	"`--load` の前に、同じ Label の `launchctl bootout` を呼び、その失敗は無視する（読み込み済みのまま `bootstrap` すると失敗し、`install --load` を繰り返せないため）。タスク担当の判断（2026-11-27）",
	"`uninstall` にも `--unload` を足す（`install --load` と対にする。既定では `launchctl` を呼ばない約束は同じ）。タスク担当の判断（2026-11-27）",
	"plist の `EnvironmentVariables` に、登録した時の `PATH`（と `SHIPCAST_CONFIG`）を入れる。launchd の `PATH` は最小で、`shipcast run` が呼ぶ `git`・モデルのCLIが見つからないため。`PATH` が変わったら `install` をやり直す（README に書く）。タスク担当の判断（2026-11-27）",
	"`RunAtLoad` は入れない（読み込んだ時に動かさず、3時だけに動かす）。タスク担当の判断（2026-11-27）",
	"`ProgramArguments` の実行ファイルは、`PATH` で見つけた道筋（`uv tool` の bin の道筋。例 `~/.local/bin/shipcast`）を絶対の道筋にしたものを使い、symlink の実体には解かない（`uv tool upgrade` で実体が変わっても登録が切れないため）。`.venv` の見分けには、見つけた道筋と実体の両方を見る。タスク担当の判断（2026-11-27）",
	"フルディスクアクセスに足す対象は、`shipcast` を動かす Python の実体（`sys.executable` の実体）として、`install` の出力と README に示す。launchd から動く `shipcast` は Python のスクリプトで、許可は実際に動く実行ファイルに付くため（本人の手動の確かめで確定する仮定）。タスク担当の判断（2026-11-27）",
	"`journal_extensions_for` の追随を、統括の依頼どおりこのIssueで行う（統括の依頼、2026-11-27）",
]

questions: [
	"フルディスクアクセスに足す実行ファイルが Python の実体で足りるか（`shipcast` のスクリプトや `/bin/sh` が要るか）は、本人が外付けvolumeで手動で確かめる。違えば README と出力の案内を直す追随にする",
]
