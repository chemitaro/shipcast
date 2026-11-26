package spec

goals: [
	"iss-00011 の `Collector` の約束に従うクラスを1つ書き、`COLLECTORS` に1行足すだけで、Orcaの会話が `shipcast collect` に加わる",
	"Orcaの機械向けの出力（`--json`）を読むだけにし、Orcaの内部のファイルを開かない",
	"Orcaがなくても、ほかのcollectorと日誌は止まらない（どの失敗も警告）",
	"試験は架空の見本のJSONだけで行い、本物の `orca` を使わない",
]

current: "`shipcast.collect.COLLECTORS` は `(GitCollector(), SpecDockCollector())`。Orcaの会話は集めない。"
target:  "`shipcast collect` が、`orca = true` のrepositoryで、その日に動いたそのrepositoryの会話を、`source` が `orca`・kind が `conversation` のEventとして保存する。"

design: {
	"D-01": {
		title: "`shipcast.collect.orca.OrcaCollector`"
		text: """
		```python
		class OrcaCollector:
		    name = "orca"
		    def __init__(self, *, orca: str = "orca", timeout: float = 30.0, limit: int = 100): ...
		    def collect(self, repo: RepoConfig, day: date, tz: tzinfo) -> CollectResult: ...
		```

		iss-00011 の `Collector` の約束（`shipcast.collect.base` の docstring）に従う：読むだけにする、返すEventは `source == "orca"`・`repo_id == repo.id`・`day_bounds(day, tz)` の `[start, end)` の中、`id` は `event_id("orca", repo.id, <native_id>)`、続けられることは `warnings`。このcollectorは `CollectError` を投げない（requirement の constraints）。想定外の例外（プログラムの誤り）は約束どおりそのまま伝える。

		`shipcast/collect/__init__.py` は `COLLECTORS: tuple[Collector, ...] = (GitCollector(), SpecDockCollector(), OrcaCollector())` にする。

		外部のコマンドは、すべて1つの内部の関数を通す：`subprocess.run(argv, capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=self.timeout, env=<下記>, check=False)`。試験が置き換えられるように、モジュールの `subprocess` の `run` を呼ぶ（`from subprocess import run` にしない）。環境は `os.environ` の写しに `NO_COLOR=1` を足したもの（Orcaの端末の `ORCA_*` の変数はそのまま渡す。Orcaにつなぐのに要るため）。`cwd` は指定しない。
		"""
		satisfies: ["R-01", "R-02", "F-01"]
	}
	"D-02": {
		title: "読むもの（3つのコマンドと、使う項目）"
		text: """
		呼ぶのは次の3つの形だけ。2026-11-26 に `orca` 1.4.277 の実際の出力で項目を確かめた。

		| # | argv | 使う項目 |
		|---|---|---|
		| 1 | `[orca, "agent", "list", "--json"]` | 外側 `ok`、`error.code`・`error.message`。`result.agents[]` の `orcaSessionId`（接頭辞 `orca_session_id:` のない文字列）、`kind`（`chat`・`terminal`）、`agent`（`claude`・`codex` など）、`worktreeId`、`workspace`、`title`、`updatedAt`（エポックからのミリ秒の整数）。`result.truncated` |
		| 2 | `[orca, "repo", "list", "--json"]` | 外側は1と同じ。`result.repos[]` の `id`、`path` |
		| 3 | `[orca, "agent", "read", "orca_session_id:" + <orcaSessionId>, "--limit", str(limit), "--json"]` | 外側は1と同じ。`result.limited`（真偽値）、`result.entries[]` の `kind`（`message`・`tool`）、`role`（`user`・`assistant`・`system`）、`text` |

		Orcaの出力は、成功でも失敗でも標準出力に1つのJSONの物（`{"id", "ok", "result" | "error", "_meta"}`）を出し、失敗では `ok` が false、`error` が `{"code", "message"}`、終了コードが1。

		`worktreeId` は `<repo-id>::<絶対のpath>` の形。folderのworkspace（`folder:<id>` の形で `::` がない）もある。`entries` は古い順。`agent list` の `title` と `lastAssistantMessage` のうち、使うのは `title` だけ。`repo` と `hostId` は使わない。
		"""
		satisfies: ["R-01"]
	}
	"D-03": {
		title: "手順とEventの作り方"
		text: """
		`start, end = day_bounds(day, tz)`。

		1. `repo.orca` が false なら、何も呼ばずに `CollectResult()` を返す（R-02）。
		2. 1のコマンド（agent list）を読む。D-04 の誤りなら、その警告だけで空を返す。`result.truncated` が true なら、警告 `Orcaの会話の一覧が途中までしか返りませんでした` を足す。
		3. 2のコマンド（repo list）を読む。`repos[]` のうち、`id` と `path` が文字列の要素を、`path` が `repo.path` と同じもの（`own_ids`）と違うもの（`other_ids`）の `id` の集合に分ける（pathの比較は、どちらも `os.path.normpath` した文字列で行う。ファイルを開かず、symlinkは解かない）。D-04 の誤りなら、警告を足し、2つの集合を空にして続ける（pathだけで選ぶ）。
		4. 会話を選ぶ：`agents[]` の要素のうち、`orcaSessionId` が空でない文字列、`updatedAt` が整数（真偽値は除く）、`worktreeId` が `::` を含む文字列で、次のどちらかを満たすもの。
		   - `worktreeId` の最初の `::` より前（`<repo-id>`）が `own_ids` にある
		   - `<repo-id>` が `other_ids` になく、`::` より後のpath（`normpath`）が、`repo.path`（`normpath`）と同じか、その配下（`path.startswith(repo_path + os.sep)`）。`other_ids` にあるのは、`repo.path` の配下に入れ子に置かれた別のrepositoryなので除く
		   さらに、`at = datetime.fromtimestamp(updatedAt / 1000, UTC)` が `start <= at < end` のもの。同じ `orcaSessionId` が二度出たら、最初のものだけを使う。形の合わない要素は黙って飛ばす（ほかのrepositoryの、知らない形の項目のため）。
		5. 選んだ会話ごとに（`agents[]` の順に）、3のコマンド（agent read）を読む。D-04 の誤りなら、その会話を飛ばし警告を足す。`entries[]` のうち、`kind == "message"`、`role` が `user` か `assistant`、`text` が空白だけでない文字列のものを、順に残す。残りが0件の会話は、Eventにしない。

		Eventの形（1つの会話につき1件）：

		- `id`：`event_id("orca", repo.id, f"conversation:{orcaSessionId}:{day.isoformat()}")`
		- `kind`：`conversation`。`at`：4の `at`（UTC）
		- `title`：`agents[]` の `title` の前後の空白を除いたもの。空か文字列でなければ `（題名のない会話）`
		- `actor`：`agent`（文字列でなければ空）
		- `refs`：`(f"orca_session_id:{orcaSessionId}",)`
		- `body`：見出しの行と発言のかたまりを、空行（`\\n\\n`）でつなぐ。見出しの行は、`会話: orca_session_id:{orcaSessionId}（{agent}、{kind}）`、`workspace: {workspace}`、`limited` が true なら `（最新の{limit}件の記録だけを読みました）`、を `\\n` でつなぐ（値が空・文字列でない行は書かない。`agent` と `kind` の片方が欠けたら、ある方だけを括弧に書き、両方ないなら括弧を書かない）。発言のかたまりは `[{role}]\\n{text}`（`text` は前後の空白を除く）

		返すEventの順は、選んだ会話の `agents[]` の順。保存の順は `Store` が決めるので、試験はIDの集合と各項目で確かめる。
		"""
		satisfies: ["R-01", "R-02"]
	}
	"D-04": {
		title: "誤りと警告（F-01）"
		text: """
		どの誤りも `CollectError` にせず、警告の文にする。`<sub>` は `agent list`・`repo list`・`agent read` のどれか。`{理由}` は次の検査を、この順に行って決める。

		- `FileNotFoundError` → `orcaのコマンドが見つかりません: {self.orca}`
		- `subprocess.TimeoutExpired` → `{timeout}秒で終わりませんでした`
		- 標準出力がJSONの物で `ok` が false（終了コードによらない） → `{error.code}: {error.message の最初の空でない行}`（`error` が物でなければ、下の「終了コードが0でない」と同じ）
		- 終了コードが0でない → 標準エラーの最後の空でない行（空なら `終了コード {n}`）
		- 標準出力がJSONの物として読めない、`ok` が true でない → `出力をJSONとして読めません`
		- `result` が物でない、`agents`・`repos`・`entries` が配列でない → `出力の形が想定と違います`

		文：

		- agent list → `Orcaの会話の一覧を読めませんでした: {理由}。Orcaの会話は集めていません`（空を返す）
		- repo list → `Orcaのrepositoryの一覧を読めませんでした: {理由}。pathの一致だけで会話を選びます`（続ける）
		- agent read → `Orcaの会話を読めませんでした（orca_session_id:{orcaSessionId}）: {理由}`（その会話だけを飛ばす）

		Orcaが動いていないときと、Orcaの外の端末で `ORCA_*` の変数がないときは、`orca` が失敗の物か終了コード0以外を返すので、上の検査で警告になる（本物の文は版で変わるので、試験は架空の文で確かめる）。
		"""
		satisfies: ["F-01"]
	}
	"D-05": {
		title: "試験の継ぎ目と見本"
		text: """
		- 見本：`tests/fixtures/orca/agent-list.json`、`repo-list.json`、`agent-read-<名前>.json`（会話ごと）。D-02 の実際の出力の形（項目の名前・入れ子・外側の `id`・`ok`・`_meta`）を保ち、値はすべて架空にする（path は `/home/dev/demo-app` と `/home/dev/worktrees/demo-app/feature-x`、ほかのrepositoryは `/home/dev/other-app`、入れ子の別のrepositoryは `/home/dev/demo-app/vendor/lib`（`repo-list.json` に別のIDで登録）、repo-id とセッションIDは `00000000-…` のような作った UUID、架空の題名と発言）。手元の実際の出力の値を写さない。
		- 継ぎ目：`shipcast.collect.orca.subprocess.run` を、argv を記録し、argv に応じて見本の文字列（と終了コード・標準エラー）を返す偽物に置き換える（`monkeypatch.setattr`）。失敗は、偽物が `FileNotFoundError`・`subprocess.TimeoutExpired` を投げる、`ok` が false の物と終了コード1を返す、終了コード1で標準出力を空にする、壊れたJSONを返す、で作る。
		- repositoryは `RepoConfig(id="demo", path=Path("/home/dev/demo-app"), ref="main", title="demo", orca=True)`（pathを開かないので、存在しなくてよい）。日は 2026-11-26、tz は `ZoneInfo("Asia/Tokyo")`（その日は UTC の 2026-11-25T15:00:00Z（`1795618800000` ミリ秒）から 2026-11-26T15:00:00Z（`1795705200000`）の前まで）。
		"""
		satisfies: ["R-01", "R-02", "F-01"]
	}
}

risks: [
	"Orca CLIの出力の形は版で変わりうる。使う項目を見本に固定し、変われば `出力の形が想定と違います` の警告で気づく",
	"会話は最後に動いた日（`updatedAt`）にだけ入る。前の日を後から集め直すと、その後に動いた会話はその日に入らない（Orcaの発言に時刻がないため）",
	"1つの会話は最新の100件の記録（道具の呼び出しを含む）だけを読む。長い会話の前半は入らない（本文に書く）",
	"`orca repo list` が読めないとき、登録したpathの外のOrcaのworktreeの会話は入らない（警告を出す）",
	"会話の本文には、本人の発言とエージェントの出力がそのまま入る。公開の方針での絞り込みは後の段（日誌、発信）が受け持つ。状態は利用者の手元のSQLiteだけにある",
]
