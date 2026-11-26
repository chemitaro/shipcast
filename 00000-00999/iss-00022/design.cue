package spec

goals: [
	"1回の `shipcast schedule install` で、毎日3時に `shipcast run` が動く plist がそろい、本人は表示されたコマンドを1つ打てば読み込める",
	"既定では本人の launchd を変えない（`launchctl` を呼ぶのは `--load`・`--unload` のときだけ）",
	"checkout の `.venv` の `shipcast` を登録しない（夜の実行は `uv tool install` の `shipcast` で動く）",
	"plist の組み立てを、ファイルにも `launchctl` にも触れない関数として単独で試験できる",
	"夜の `shipcast run` の日誌にも、`shipcast write` と同じ「発信の芽」の印が付く",
]

current: "`shipcast schedule install|uninstall` は未実装の印を出して終了コード2で終わる。`shipcast run` の `journal_extensions_for` は `None` を返し、夜の日誌には「発信の芽」の印が付かない。README に導入と登録の手順がない。"
target:  "`schedule install` が plist と `logs/` を書き、読み込みのコマンド（`--load` なら読み込みまで）を示す。`schedule uninstall` が plist を消し、外すコマンド（`--unload` なら外すまで）を示す。`shipcast run` は `write.journal_extensions` を渡す。README に導入・登録・外し方・許可の節がある。"

design: {
	"D-01": {
		title: "plist の組み立て（`shipcast.schedule.build_plist`）"
		text: """
		`src/shipcast/schedule.py` に置く。定数は `LABEL = "com.shipcast.nightly"`、`PLIST_NAME = f"{LABEL}.plist"`、`HOUR = 3`、`MINUTE = 0`、`LOG_DIRNAME = "logs"`、`STDOUT_LOG = "nightly.out.log"`、`STDERR_LOG = "nightly.err.log"`。

		`build_plist(program: Path, log_dir: Path, environment: Mapping[str, str]) -> bytes` は、ファイルにも環境にも触れず、次の辞書を `plistlib.dumps(..., fmt=plistlib.FMT_XML, sort_keys=True)` にした bytes を返す。

		- `Label`：`LABEL`
		- `ProgramArguments`：`[str(program), "run"]`
		- `StartCalendarInterval`：`{"Hour": 3, "Minute": 0}`（launchd は Mac の時計の時刻で動く）
		- `StandardOutPath`：`str(log_dir / STDOUT_LOG)`、`StandardErrorPath`：`str(log_dir / STDERR_LOG)`
		- `EnvironmentVariables`：`dict(environment)`（空なら入れない）
		- `ProcessType`：`"Background"`

		`RunAtLoad` は入れない（requirement の決定）。`program` と `log_dir` が絶対の道筋でなければ `ValueError`（launchd は `~` も相対の道筋も解かない）。

		`nightly_environment(environ: Mapping[str, str]) -> dict[str, str]` は、`environ` の `PATH`（あれば）と、`SHIPCAST_CONFIG`（あれば、`config_path()` と同じく `expanduser` して `absolute()` にした文字列）だけを返す。ほかの変数は入れない（秘密の値を plist に写さないため）。
		"""
		satisfies: ["R-01"]
	}
	"D-02": {
		title: "`shipcast` の実行ファイルの見つけ方（`find_program`）"
		text: """
		`find_program() -> Path` は、`shutil.which("shipcast")` で見つけた道筋を `Path(...).absolute()` にして返す（symlink は解かない。requirement の決定）。

		- 見つからない：`ScheduleError("PATH に shipcast が見つかりません", "`uv tool install` で shipcast を入れ、`uv tool update-shell` で PATH に足してから、もう一度実行してください")`
		- 見つけた道筋か、その実体（`Path.resolve()`）の道筋の部品に `.venv` がある：`ScheduleError("checkout の .venv の shipcast は登録しません: <道筋>", "`uv tool install` で入れた shipcast を使ってください（`uv run` ではなく、`shipcast schedule install` を直接実行します）")`

		`ScheduleError(problem, hint)` は `ConfigError` と同じく `__str__` が `<problem>\n直し方: <hint>` の例外で、`schedule.py` の中に置く。`shutil.which` は `shipcast.schedule` の module の名前 `shutil` から呼ぶ（試験は `monkeypatch.setattr(schedule.shutil, "which", ...)` で差し替える）。
		"""
		satisfies: ["R-01", "F-01"]
	}
	"D-03": {
		title: "`schedule install`（`configure_install`・`install`）"
		text: """
		`configure_install(parser)` は `--load`（`action="store_true"`、help「plist を書いた後、launchctl で読み込む」）を足し、`parser.set_defaults(func=install)`。

		`install(args) -> int` の順（標準エラーの接頭辞は `shipcast schedule install:`）：

		1. `load_config()`。`ConfigError` は `<接頭辞> <誤り>`、`OSError` は `<接頭辞> 設定ファイルを開けません: <誤り>` と直し方を出して1。
		2. `program = find_program()`。`ScheduleError` は `<接頭辞> <誤り>` で1。ここまでは何も書かない。
		3. `log_dir = config.state_dir / LOG_DIRNAME`（`config.state_dir` は設定が展開済みの絶対の道筋）。`log_dir.mkdir(parents=True, exist_ok=True)`。
		4. `plist = plist_path()`（`Path.home() / "Library" / "LaunchAgents" / PLIST_NAME`）。親を `mkdir(parents=True, exist_ok=True)` し、`build_plist(program, log_dir, nightly_environment(os.environ))` を、同じディレクトリの一時ファイルに書いて `os.replace` で置き換える（権限 0o644）。3〜4の `OSError` は `<接頭辞> 書き出せません: <誤り>` で1（一時ファイルは消す）。
		5. 標準出力に次を出す（コマンドの道筋は `shlex.quote` で囲む）。
		   - `plist を書きました: <plist>`（置き換えたときは `plist を置き換えました: <plist>`）
		   - `毎日 03:00 に実行します: <program> run`
		   - `ログの置き場: <log_dir>`
		   - `--load` がないとき：`読み込むには、次を実行してください:`、`  launchctl bootstrap gui/<uid> <plist>`、`すでに読み込んでいるときは、先に次を実行してください:`、`  launchctl bootout gui/<uid>/com.shipcast.nightly`
		   - `外付けvolumeのrepositoryを読むときは、フルディスクアクセスに次を足してください: <Path(sys.executable).resolve()>`（README の節を指す1行を添える）
		6. `--load` のときだけ D-05 の `load(plist)`。成功なら `読み込みました: gui/<uid>/com.shipcast.nightly` を出して0。失敗なら1（plist は残す）。

		`uid` は `os.getuid()`。`Path.home`・`os.getuid`・`sys.executable` は試験で差し替えられるよう、`plist_path()`・`gui_domain()`・`interpreter_path()` の小さな関数を通して読む。
		"""
		satisfies: ["R-01", "F-01", "F-02"]
	}
	"D-04": {
		title: "`schedule uninstall`（`configure_uninstall`・`uninstall`）"
		text: """
		`configure_uninstall(parser)` は `--unload`（`action="store_true"`、help「plist を消す前に、launchctl で外す」）を足し、`parser.set_defaults(func=uninstall)`。設定は読まない。

		`uninstall(args) -> int` の順（接頭辞は `shipcast schedule uninstall:`）：

		1. `--unload` のときだけ D-05 の `unload()`。失敗しても標準エラーに `<接頭辞> 警告: 外せませんでした（読み込んでいなかった可能性があります）: <理由>` を出して続ける。
		2. `plist_path()` があれば `unlink()` して `plist を消しました: <plist>`。なければ（`FileNotFoundError` を含む）`登録はありません: <plist>`。消せない `OSError` は `<接頭辞> plist を消せません: <誤り>` で1。
		3. `--unload` がないとき：`読み込んだ登録を外すには、次を実行してください:`、`  launchctl bootout gui/<uid>/com.shipcast.nightly`。`--unload` で外せたとき：`外しました: gui/<uid>/com.shipcast.nightly`。終了コード0。
		"""
		satisfies: ["R-02", "F-02"]
	}
	"D-05": {
		title: "`launchctl` の呼び出し（`launchctl`・`load`・`unload`）"
		text: """
		`launchctl(*args: str) -> subprocess.CompletedProcess[str]` だけが `subprocess.run(["launchctl", *args], capture_output=True, text=True, check=False)` を呼ぶ。`install`・`uninstall` は、`--load`・`--unload` がないとき、この関数を呼ばない。試験は `monkeypatch.setattr(schedule, "launchctl", 偽物)` で差し替え、さらに試験の module の autouse の fixture で `schedule.subprocess.run` を「呼ばれたら試験を落とす」偽物にし、本物の `launchctl` が動かないことを保証する。

		- `load(plist) -> str | None`：まず `launchctl("bootout", f"{gui_domain()}/{LABEL}")` を呼び、結果は見ない（requirement の決定）。次に `launchctl("bootstrap", gui_domain(), str(plist))`。終了コードが0なら `None`、0でなければ標準エラー（なければ標準出力）の最後の空でない行を理由の文として返す。`FileNotFoundError`（macOS でない）は `launchctl が見つかりません（macOS の launchd だけに対応します）` を返す。`install` は理由を `<接頭辞> 読み込みに失敗しました: <理由>` と、`launchctl bootout gui/<uid>/com.shipcast.nightly` を打ってから `--load` をやり直す直し方で出す。
		- `unload() -> str | None`：`launchctl("bootout", f"{gui_domain()}/{LABEL}")`。理由の文の作り方は `load` と同じ。

		`gui_domain()` は `f"gui/{os.getuid()}"`。
		"""
		satisfies: ["R-01", "R-02"]
	}
	"D-06": {
		title: "CLI の接続（`cli.py`）"
		text: """
		`cli.py` の import に `from shipcast import schedule  # isort: skip`（ほかの葉と同じ並び）を足し、`schedule` の2つの葉を `Entry("install", "スケジュールを登録する", schedule.configure_install)`・`Entry("uninstall", "スケジュールを解除する", schedule.configure_uninstall)` にするだけ。`Command` の題名と issue の番号、ほかの葉は変えない（並行する iss-00020 との衝突を避ける）。`tests/test_cli.py` の未実装の葉の一覧から `schedule install`・`schedule uninstall` の2行を外す。
		"""
		satisfies: ["R-01", "R-02"]
	}
	"D-07": {
		title: "`shipcast run` の拡張点の追随（`run.journal_extensions_for`）"
		text: """
		`run.py` の `journal_extensions_for(store, config)` の中身を `return journal_extensions(store, config.neta.threshold)` にし、戻り値の型を `Sequence[JournalExtension]` にする（import は `from shipcast.write import ... journal_extensions`）。docstring の「後続の変更で行う」を、台帳の印を渡すことの説明に直す。ほかの `run.py` の処理は変えない。

		`tests/test_run.py` の既存の試験で `extensions_passed == [None] * ...` を確かめている行は、渡された組の最後が `NetaSprout` で、その前が `write.EXTENSIONS` と同じことの確かめに直す（`NetaSprout` は等しさを持たないので、`==` で組を比べない）。
		"""
		satisfies: ["R-04"]
	}
	"D-08": {
		title: "README の節"
		text: """
		`README.md` の「## 置き場の原則」の後、「## 日誌を読む（`shipcast serve`）」の前に、「## 導入と毎晩の実行（`shipcast schedule`）」を置く（並行の Issue が「## License」の前に節を足しても衝突しにくい位置）。内容：

		1. 導入：`uv tool install git+https://github.com/chemitaro/shipcast`（手元の checkout からなら、main の checkout で `uv tool install .`）、`uv tool update-shell`、更新は `uv tool upgrade shipcast`。worktree や `uv run` の `shipcast` は登録しないこと
		2. 登録：`shipcast schedule install`、表示された `launchctl bootstrap gui/<uid> ...` を打つか、`shipcast schedule install --load`。毎日 03:00（Mac の時計）に `shipcast run` が前日の日誌を作る。`PATH` を変えたら登録をやり直す
		3. ログ：`<state_dir>/logs/nightly.out.log`・`nightly.err.log`（既定 `~/.local/state/shipcast/logs/`）と、実行の記録（`runs`）
		4. 外し方：`shipcast schedule uninstall`（と `--unload`、または表示された `launchctl bootout ...`）
		5. フルディスクアクセス：外付けvolumeのrepositoryを読むとき、「システム設定」→「プライバシーとセキュリティ」→「フルディスクアクセス」で、`install` が示す Python の実行ファイルを足す（追加の画面で `Cmd+Shift+G` で道筋を入れる）。Python を入れ替えたら足し直す。手で `shipcast run` を動かすときはターミナルを許可する

		`tests/test_readme.py` に、この節が「## 日誌を読む」の前にあり、`uv tool install`・`shipcast schedule install`・`--load`・`shipcast schedule uninstall`・`logs/`・`フルディスクアクセス` を含むことの試験を足す。
		"""
		satisfies: ["R-03"]
	}
}

risks: [
	"フルディスクアクセスに足す実行ファイルが Python の実体で足りるかは、macOS の判定次第で、試験では確かめられない（requirement の questions）。本人の手動の確かめで直す",
	"launchd の 03:00 は Mac の時計の時刻で、設定の `timezone` が違うと「前日」が本人の期待とずれる。README に書く",
	"Mac が3時に眠っていると、launchd は起きた後に1回動かす。日の決め方は動いた時刻の前日なので、朝に起きれば前日の日誌になる",
	"`PATH` を plist に写すので、登録の後に入れたCLIの場所は夜の実行から見えない。README に、`PATH` を変えたら `install` をやり直すと書く",
	"ログのファイルは回転しない。1晩の出力は数行で、増え方は小さい",
	"並行する iss-00020 と、`cli.py` の葉の並び・`tests/test_cli.py` の未実装の一覧・README の節の付近で、行の衝突が起こりうる。差分は最小にし、マージの順は統括が決める",
]
