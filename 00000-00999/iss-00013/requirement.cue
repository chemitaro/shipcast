package spec

schema: "specdock/v1"

assurance: {
	level:  "light"
	reason: "任意の連携のcollectorを1つ足すだけで、失敗してもOrcaなしで日誌ができる（F-01）。読むだけで、PRを戻せば元に戻る"
}

purpose: "Orcaの会話の記録を、任意の連携として集める。本人はOrcaを使うので、基本は動く前提で作る。"

background: """
親の epic-00003 の R-03（Orcaの、そのrepositoryでのその日の会話の記録）と F-01（Orcaが使えないときは警告で続ける）、D-04（Orcaの読み方）を、このIssueが受け持つ（epic-00003 の `plan.cue` の `slices`）。

`main` にすでにある次のものを、名前を変えずに使う（iss-00011・iss-00012 で入った。PR #26、#27）。

- `shipcast.collect.base`：`Collector`（`name`、`collect(repo, day, tz) -> CollectResult`）、`CollectResult(events, warnings)`、`CollectError`、`day_bounds(day, tz)`、`collect_repo`（Eventの `source`・`repo_id`・時刻を確かめて保存する。保存は `INSERT OR IGNORE` で、同じIDは二度目から保存されない）
- `shipcast.collect.COLLECTORS`：今は `(GitCollector(), SpecDockCollector())`。順は git、specdock、orca
- `shipcast.model`：`Event`、`event_id(source, repo_id, native_id)`、`SOURCES`（`orca` を含む）
- `shipcast.config.RepoConfig`：`id`、`path`（絶対のパス）、`ref`、`title`、`orca`（真偽値。設定で省くと true）

iss-00011 からの申し送り：`Collector.collect` の引数は、epic-00003 の D-01 の `(repo, day)` ではなく `(repo, day, tz)`。`COLLECTORS` は `shipcast.collect` にある。

実際の出力の形は、2026-11-26 に `orca` 1.4.277 で確かめた（design.cue の D-02 に書いた）。Orcaのworktreeは登録したrepositoryのpathの外（例 `<worktrees>/<repo>/<branch>`）に作られるので、pathだけでは同じrepositoryの会話と分からない。Orcaのrepositoryの登録（`orca repo list --json` の `repos[].id`・`path`）と、`worktreeId` の前半（`<repo-id>`）で結びつける。
"""

includes: [
	"`src/shipcast/collect/orca.py`：`OrcaCollector`",
	"`src/shipcast/collect/__init__.py`：`COLLECTORS` に `OrcaCollector()` を3番目に足す（1行と import の1行）",
	"`tests/test_collect_orca.py` と、`tests/fixtures/orca/` の見本（架空の値のJSON）",
]

excludes: [
	"`orca search` による全文の検索（epic-00003 の D-04）",
	"ほかのhost（`--environment`、paired server）の会話。この機械のOrcaだけを読む",
	"1つの会話の、最新の100件より前の記録（`orca agent read --limit` の上限）",
	"日をまたぐ会話の、発言ごとの日の振り分け（発言に時刻がないため）。会話は最後に動いた日（`updatedAt`）にだけ入る",
	"話題にまとめること、日誌を書くこと、公開の方針での絞り込み、外部のモデルの呼び出し（`agy`、`codex`、`claude` を一切呼ばない）",
	"`shipcast.collect.base`・`shipcast.collect.command`・`shipcast.collect.git`・`shipcast.collect.specdock`・`shipcast.model`・`shipcast.config`・`shipcast.state`・`shipcast.cli` の変更",
]

requirements: {
	"R-01": {
		title: "そのrepositoryのworktreeでの、その日に動いた会話（本人とエージェントの発言）を、Event（conversation）にする"
		text:  "「そのrepositoryのworktree」は、Orcaの `worktreeId` のpathが `repo.path` かその配下のもの、または `worktreeId` の `<repo-id>` が、Orcaに `repo.path` のpathで登録されたrepositoryのIDのもの。「その日に動いた」は、会話の `updatedAt` が `day_bounds(day, tz)` の範囲にあること（発言に時刻がないため。epic-00003 の D-04）。"
		acceptance: [
			"そのrepositoryの（main checkoutと、ほかの場所のOrcaのworktreeの）会話で、`updatedAt` がその日のものが、1つの会話につき1件の、kind `conversation`、時刻 `updatedAt` のEventになる",
			"前日・翌日の `updatedAt`（日の境のちょうどを含む）の会話、ほかのrepositoryの会話、folderのworkspaceの会話は入らない",
			"Eventの本文に、`role` が `user` と `assistant` の発言が古い順に入り、道具の呼び出し（`kind` が `tool`）と `system` の発言は入らない",
			"Eventに、会話の題名、OrcaのセッションID、エージェントの種類、workspaceの名前が入る",
			"同じ会話が別の日にも動いたとき、日ごとに別のEventになる（同じIDで二度目が捨てられない）",
		]
	}
	"R-02": {
		title: "設定の `orca = false` のrepositoryでは集めない"
		text:  "`repo.orca` が false なら、`orca` のコマンドを一度も呼ばず、Eventも警告もない（`CollectResult()`）。"
		acceptance: ["`orca = false` のrepositoryで、偽物の `subprocess.run` が一度も呼ばれず、Eventも警告も0件"]
	}
}

failures: {
	"F-01": {
		title:    "Orcaが動いていない・CLIがない・読めないときは、警告を残して空を返す"
		impact:   "その日の会話の記録が日誌に入らない（1つの会話だけが読めないときは、その会話だけが入らない）。Git・SpecDockの出来事とほかのrepositoryは保存する"
		recovery: "Orcaを起動する・`orca` を入れて、同じ `--date` で集め直す（保存は冪等）。ただし、その後に会話が動くと、前の日には入らない（D-03）"
	}
}

constraints: [
	"標準のライブラリだけで書く（依存を足さない）。試験は、`subprocess.run` を置き換えて、`tests/fixtures/orca/` の見本を返す。試験で本物の `orca` を呼ばない",
	"このrepositoryはpublic。見本は完全に架空の会話にし、手元の実際のOrcaの記録（題名、発言、path、セッションID、repositoryの名前）を写さない",
	"`CollectError` を投げない。Orcaは任意の連携で、どの失敗も警告にする（F-01）",
	"開発は通常の `coding-task`。マージは統括が行い、タスク担当と実装担当はマージしない（`content/decisions/20261126-journal-format-and-hackathon-plan.md` の 18〜21）",
]

decisions: [
	"`Collector.collect(repo, day, tz)` と `shipcast.collect.COLLECTORS` は、iss-00011 の実装のとおりに使う（申し送り。統括の依頼、2026-11-26）",
	"epic-00003 の D-04 の2つのコマンドに、`orca repo list --json` を足す。Orcaのworktreeは登録したpathの外にあり、`worktreeId` のpathだけでは同じrepositoryと分からないため。読むだけのコマンドで、読めなければ警告にしてpathだけで選ぶ（タスク担当の判断、2026-11-26。本人の決定 6「細部の設計はエージェントが詰める」の範囲）",
	"Eventの native_id に日を入れる（`conversation:{orcaSessionId}:{day}`）。保存は同じIDを捨てるので、日を入れないと、前の日に集めた会話がその後に動いても、次の日に入らないため（タスク担当の判断、同じ範囲）",
	"`system` の発言（Orcaやエージェントの道具の知らせ）は入れない。R-01 の「本人とエージェントの発言」に当たらないため（タスク担当の判断、同じ範囲）",
	"作業のbranchは統括が作ったworktreeの `chemitaro/iss-00013` を使う",
]
