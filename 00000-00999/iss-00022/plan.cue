package spec

goal: "新しい `schedule.py` に、ファイルにも `launchctl` にも触れない plist の組み立てと実行ファイルの見つけ方を先に作り、その上に `install`・`uninstall` のCLIをつなぎ、`shipcast run` の拡張点を台帳につなぎ、最後に README の節を書く。試験は一時のディレクトリ（`HOME` の差し替え）、`shutil.which` と `launchctl` の偽物、fake の経路の `responder` だけで行い、本物の `~/Library/LaunchAgents/` と `launchctl` に触れない。"

steps: {
	"S-01": {
		status:   "todo"
		title:    "plist の組み立てと実行ファイルの見つけ方（`build_plist`・`nightly_environment`・`find_program`）"
		text:     "D-01・D-02。T-01・T-02・T-03 を `tests/test_schedule.py` に先に書いて落ちることを確かめ（Red）、`src/shipcast/schedule.py` に定数・`ScheduleError`・`build_plist`・`nightly_environment`・`find_program` を書いて通す（Green）。完了の条件：`test_commands` がすべて終了コード0。"
		realizes: ["R-01", "F-01"]
		session:  "impl"
	}
	"S-02": {
		status:   "todo"
		title:    "`schedule install`・`uninstall` のCLIと `launchctl` の呼び出し、`cli.py` の接続"
		text:     "D-03・D-04・D-05・D-06。T-04〜T-07 を先に書いて Red、`configure_install`・`install`・`configure_uninstall`・`uninstall`・`launchctl`・`load`・`unload`・`plist_path`・`gui_domain`・`interpreter_path` を書き、`cli.py` の2つの葉をつなぎ、`tests/test_cli.py` の未実装の一覧から2行を外して Green。完了の条件：`test_commands` がすべて終了コード0。"
		realizes: ["R-01", "R-02", "F-01", "F-02"]
		after:    ["S-01"]
		session:  "impl"
	}
	"S-03": {
		status:   "todo"
		title:    "`shipcast run` の拡張点を台帳につなぐ（`journal_extensions_for`）"
		text:     "D-07。T-08 を先に書いて Red（今の `None` では落ちる）、`journal_extensions_for` を `journal_extensions(store, config.neta.threshold)` にし、既存の `tests/test_run.py` の `[None]` の確かめを直して Green。完了の条件：`test_commands` がすべて終了コード0。"
		realizes: ["R-04"]
		after:    ["S-02"]
		session:  "impl"
	}
	"S-04": {
		status:   "todo"
		title:    "README の導入と毎晩の実行の節"
		text:     "D-08。T-09 を `tests/test_readme.py` に先に書いて Red、README に節を書いて Green。完了の条件：`test_commands` がすべて終了コード0。"
		realizes: ["R-03"]
		after:    ["S-03"]
		session:  "impl"
	}
}

tests: {
	"T-01": {title: "`build_plist(Path(\"/Users/example/.local/bin/shipcast\"), Path(\"/Users/example/.local/state/shipcast/logs\"), {\"PATH\": \"/usr/bin:/bin\"})` を `plistlib.loads` で読むと、`Label == \"com.shipcast.nightly\"`、`ProgramArguments == [\"/Users/example/.local/bin/shipcast\", \"run\"]`、`StartCalendarInterval == {\"Hour\": 3, \"Minute\": 0}`、`StandardOutPath`・`StandardErrorPath` が logs の下の `nightly.out.log`・`nightly.err.log`、`EnvironmentVariables == {\"PATH\": \"/usr/bin:/bin\"}`、`ProcessType == \"Background\"`、`RunAtLoad` がない。環境が空なら `EnvironmentVariables` がない。相対の道筋の `program`・`log_dir` は `ValueError`。同じ入力で同じ bytes になる。ファイルを作らない（`tmp_path` が空のまま）", verifies: ["R-01"]}
	"T-02": {title: "`nightly_environment`：`{\"PATH\": \"/a:/b\", \"SHIPCAST_CONFIG\": \"~/c/config.toml\", \"SECRET_TOKEN\": \"x\"}`（`HOME` は一時のディレクトリ）で、`PATH` と、`SHIPCAST_CONFIG` を展開した絶対の道筋の2つだけを返す。`SHIPCAST_CONFIG` がなければ `PATH` だけ、どちらもなければ空", verifies: ["R-01"]}
	"T-03": {title: "`find_program`：`schedule.shutil.which` を差し替え、`/Users/example/.local/bin/shipcast` を返すとその道筋。`None` なら `ScheduleError` で `uv tool install` を含む直し方。`/tmp/x/.venv/bin/shipcast` なら `ScheduleError`（`.venv`）。`tmp_path` に `.venv/bin/shipcast` の実体と、それを指す `tmp_path/bin/shipcast` の symlink を作って symlink を返させても `ScheduleError`。正しいときは symlink を解かない（symlink の道筋のまま返す）", verifies: ["R-01", "F-01"]}
	"T-04": {title: "`install` の既定（`--load` なし）：autouse の fixture で `HOME` を `tmp_path/home` にし、`schedule.subprocess.run` を呼ばれたら落ちる偽物に、`schedule.launchctl` を呼び出しを記録する偽物にし、`SHIPCAST_CONFIG` の一時の設定（`state_dir` は一時のディレクトリ）、`which` の偽物、`os.getuid` を 501 に固定して `main([\"schedule\", \"install\"])` が0。`tmp_path/home/Library/LaunchAgents/com.shipcast.nightly.plist` ができ、中身が T-01 の形（`program` は偽物の道筋、logs は `<state_dir>/logs`、`EnvironmentVariables` に試験の `PATH` と `SHIPCAST_CONFIG`）、`<state_dir>/logs` のディレクトリがある。`launchctl` の偽物は呼ばれない。標準出力に `plist を書きました:`、`毎日 03:00 に実行します:`、`launchctl bootstrap gui/501 <plist>`、`launchctl bootout gui/501/com.shipcast.nightly`、`フルディスクアクセス` が出る。もう一度実行すると0で `plist を置き換えました:`、ファイルは1つで一時ファイルが残らない。`shipcast schedule install --help` に `--load` がある", verifies: ["R-01"]}
	"T-05": {title: "`install --load`：`launchctl` の偽物が `bootout` に1、`bootstrap` に0を返すと、呼び出しが `[(\"bootout\", \"gui/501/com.shipcast.nightly\"), (\"bootstrap\", \"gui/501\", <plist>)]` の順で、終了コード0、`読み込みました:` が出る。`bootstrap` が1と標準エラー `Bootstrap failed: 5: Input/output error` を返すと、終了コード1、標準エラーに `読み込みに失敗しました: Bootstrap failed: 5: Input/output error` と直し方、plist は残る。`launchctl` の偽物が `FileNotFoundError` を投げると、終了コード1で `launchctl が見つかりません`", verifies: ["R-01"]}
	"T-06": {title: "`install` の入口の誤り：`which` が `None`、`.venv` の道筋、設定が読めない（`SHIPCAST_CONFIG` が無いファイル）のどれでも、終了コード1、標準エラーに `shipcast schedule install:` と直し方、`tmp_path/home/Library` も `<state_dir>/logs` もできない。`HOME/Library/LaunchAgents` がファイルのときは、終了コード1で `書き出せません`、traceback がない", verifies: ["F-01", "F-02"]}
	"T-07": {title: "`uninstall`：plist があると、終了コード0、ファイルが消え、標準出力に `plist を消しました:` と `launchctl bootout gui/501/com.shipcast.nightly`、`launchctl` の偽物は呼ばれない。もう一度実行すると0で `登録はありません:`。`--unload` では、`launchctl` の偽物が `(\"bootout\", \"gui/501/com.shipcast.nightly\")` で1回呼ばれ、0なら `外しました:`、1（`Boot-out failed: 3: No such process`）なら標準エラーに `警告: 外せませんでした` が出て、どちらも plist が消えて終了コード0。plist の道筋がディレクトリのときは終了コード1で `plist を消せません`。`shipcast schedule uninstall --help` に `--unload` がある。`tests/test_cli.py` の未実装の一覧に `schedule` の葉がない", verifies: ["R-02", "F-02"]}
	"T-08": {title: "`shipcast run` の拡張点：既存の `run_cli` の fixture で、`write_day` を包む偽物が受け取る `extensions` が、どのrepositoryでも、最後が `NetaSprout`、その前が `write.EXTENSIONS` と同じ（`monkeypatch.setattr(write, \"EXTENSIONS\", (偽の拡張点,))` で確かめる）。fake の分析の返事で話題のネタの点を上げ（`tests/test_write.py` の `test_write_cli_appends_sprout_only_on_active_day_at_threshold` と同じ作り）、設定の `[neta] threshold` をそのrepositoryのネタポイントの合計以下にして `main([\"run\", \"--repo\", <id>, \"--date\", <日>])` が0のとき、その日誌の本文に `:::tip 発信の芽（ネタポイント <合計>）` の囲みがある。しきい値を合計より1大きくして同じ日を実行し直すと、囲みがない", verifies: ["R-04"]}
	"T-09": {title: "README：「## 導入と毎晩の実行（`shipcast schedule`）」の節が「## 日誌を読む（`shipcast serve`）」の前にあり、`uv tool install`、`shipcast schedule install`、`--load`、`shipcast schedule uninstall`、`logs/`、`フルディスクアクセス` を含む", verifies: ["R-03"]}
}

verification: "`test_commands` を順に流し、すべて終了コード0。試験は一時のディレクトリ（`HOME` の差し替え）、`shutil.which`・`launchctl`・`subprocess.run` の偽物、fake の経路の `responder` だけで、本物の `~/Library/LaunchAgents/`・`launchctl`・外部のモデル・`agy` に触れない。PRを作った後に、GitHub ActionsのCIの合格を `github-pr-checks` で観測する。本物の launchd での読み込み、3時の起動、外付けvolumeでのフルディスクアクセスは、本人の手動の確かめだけ。"
rollback:     "PRを戻す（revert）だけで、コードは元に戻る。本人が登録していたときは、先に `shipcast schedule uninstall --unload`（または `launchctl bootout gui/<uid>/com.shipcast.nightly` と plist の削除）で外す。状態の表の形は変えない。"
exit:         "PRが最終品質ゲートとCIに合格し、タスク担当が統括にPR・合格のコミット・CIの結果・closure.md を報告した時点で、このIssueの作業は終わる。マージと `spec-dock work finish` は統括が行う。"

// 関門（coding-task）。保証レベル standard の既定と、本人の決定 18〜21（init-00001 の plan.cue の delivery）に従う。
gates: {
	spec_review: "Claude `spec-reviewer`（Opus 5.5 / high）。P0・P1がなくなるまで、3回まで"
	checkpoints: "なし。理由：手順は4つで、1人の実装担当が続けて書き、中心はこのIssueの新しいmodule（`schedule.py`）と試験で、既存のコードは `cli.py` の数行、`run.py` の1つの関数、README の1つの節だけを変える。本物の環境に触れないことと CLI の約束は、最終品質ゲートの `functional-correctness`・`api-contract`・`security-baseline` の観点で確かめる"
	final_quality_gate: {
		scope:          "開始のコミット（統括が作ったworktreeの作業の始めの `HEAD`、`e101f40`）から S-04 の後の `HEAD` まで"
		perspectives:   ["functional-correctness", "requirements-closure", "test-adequacy", "api-contract", "security-baseline"]
		test_commands:  ["uv sync --locked", "uv run ruff check", "uv run pytest -q"]
		record_paths:   ["spec-dock/initiatives/00000-00999/iss-00022/report.md（SpecDockの自動の保存で記録する。Gitのcommitは要らない）"]
		second_opinion: "none"
	}
	merge:            "agent"
	merger:           "統括。タスク担当と実装担当はマージしない（本人の決定 21）。条件は `coding-task` の `references/merge.md`（CIの合格の観測を含む）"
	merge_permission: "本人の「PR のマージは各ワーカーが行わず、統括（Antigravity）が行う」（2026-11-26、`content/decisions/20261126-journal-format-and-hackathon-plan.md` の 21。init-00001 の `plan.cue` の `delivery.gates_by_level.standard.merge`）"
	pr:               "branchは `chemitaro/iss-00022`（統括が作ったworktreeのbranch）。PRの本文に、合格のコミット、最終品質ゲートの結果、CIの結果を書く。Issueを自動で閉じる書き方（Closes #22）は使わず、`Refs #22` にする"
}

execution: {
	sessions: {
		spec: {task: "仕様化（起動した側が選んだ値の記録）", provider: "claude", model: "Claude Opus 5.5", effort: "medium", rationale: "統括が起動したOrcaの作業者。値は起動した側が方針§2の standard のタスク担当の行から決めた（事実の記録）"}
		owner: {task: "タスク担当（仕様、説明資料、レビュー、最終品質ゲート、PR、CIの観測）", provider: "claude", model: "Claude Opus 5.5", effort: "medium", rationale: "方針§2のタスク担当の standard の行。spec と同じセッション"}
		impl: {task: "実装（S-01〜S-04）。このworktreeで起動するOrcaの作業者", provider: "codex", model: "GPT-6.2 Sol", effort: "medium", rationale: "方針§2の、テストで確かめられる実装（バックエンド）の行と、統括の依頼"}
	}
	reviews: {
		spec_review: {role: "仕様のレビューの `spec-reviewer`", model: "Claude Opus 5.5", effort: "high"}
		final_gate: {role: "最終品質ゲートの `quality-gate-reviewer`", after: "S-04", model: "Claude Opus 5.5", effort: "medium"}
	}
	assignment:   "S-01, S-02, S-03, S-04 → impl（連続）"
	same_session: "なし（実装担当の提供元がタスク担当と違い、統括の依頼が Codex の実装担当を名指すため、別のセッションにする）"
}
