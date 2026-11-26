package spec

schema: "specdock/v1"

assurance: {
	level:  "light"
	reason: "iss-00011 の約束に、SpecDockの出来事を読むcollectorを1つ足すだけで、影響はこのcollectorに閉じる。読むだけで対象を変えず、誤っても日誌のSpecDockの部分が欠けるだけで、PRを戻せば元に戻る"
}

purpose: "SpecDockのScopeとtodoの、その日の変化をEventにする。"

background: """
親の epic-00003 の R-02（SpecDockの、その日のScopeとtodoの変化）と D-03（SpecDockの読み方）を、このIssueが受け持つ（epic-00003 の `plan.cue` の `slices`）。

`main` にすでにある次のものを、名前を変えずに使う（iss-00011 で入った。PR #26）。

- `shipcast.collect.base`：`Collector`（`name`、`collect(repo, day, tz) -> CollectResult`）、`CollectResult(events, warnings)`、`CollectError`、`day_bounds(day, tz)`、`collect_repo`（collectorの返したEventの `source`・`repo_id`・時刻を確かめて保存する）
- `shipcast.collect.COLLECTORS`：登録（今は `(GitCollector(),)`）。順は git、specdock、orca
- `shipcast.model`：`Event`、`event_id(source, repo_id, native_id)`、`SOURCES`（`specdock` を含む）
- `shipcast.config.RepoConfig`：`id`、`path`（絶対のパス）、`ref`、`title`、`orca`

iss-00011 からの申し送り：`Collector.collect` の引数は、epic-00003 の D-01 の `(repo, day)` ではなく `(repo, day, tz)`。`COLLECTORS` は `shipcast.collect` にある。

実際の出力の形は、2026-11-26 に `spec-dock` 0.9.10 と `gh` 2.103.3 で確かめた（D-02 に書いた）。
"""

includes: [
	"`src/shipcast/collect/specdock.py`：`SpecDockCollector`",
	"`src/shipcast/collect/__init__.py`：`COLLECTORS` に `SpecDockCollector()` を2番目に足す（1行と import の1行）",
	"`tests/test_collect_specdock.py` と、`tests/fixtures/specdock/` の3つの見本（架空の値のJSON）",
]

excludes: [
	"Orcaのcollector（iss-00013）",
	"Scopeの状態の変化のうち、作成と終了のほか（再開、題名の変更、親の付け替え）",
	"todoの変化のうち、登録と完了のほか（取消し、延期、更新、サブタスクの登録と完了）",
	"`--limit 500` を超えるIssueを持つrepositoryの、古いScopeの時刻（警告だけを出す。epic-00003 の risks）",
	"話題にまとめること、日誌を書くこと、外部のモデルの呼び出し（`agy`、`codex`、`claude` を一切呼ばない）",
	"`shipcast.collect.base`・`shipcast.collect.command`・`shipcast.collect.git`・`shipcast.model`・`shipcast.config`・`shipcast.state`・`shipcast.cli` の変更",
]

requirements: {
	"R-01": {
		title: "その日に作られた・閉じたScopeを、Event（scope_opened、scope_closed）にする"
		text:  "時刻は、ScopeのGitHubのIssueの `createdAt`・`closedAt` で決める（`spec-dock scope list` の出力には時刻がないため。本人の決定 23）。「その日」は `day_bounds(day, tz)` の範囲（設定の timezone の0時から翌日の0時の前まで）。"
		acceptance: [
			"Issueの `createdAt` がその日のScopeが、kind `scope_opened`、時刻 `createdAt` のEventになる",
			"Issueの `state` が `CLOSED` で `closedAt` がその日のScopeが、kind `scope_closed`、時刻 `closedAt` のEventになる",
			"前日・翌日の時刻（日の境のちょうどを含む）のScopeと、GitHubのIssueのない（`number` のない）Scopeは入らない",
			"Eventに、ScopeのID・種類・題名・親・URLが入る",
		]
	}
	"R-02": {
		title: "その日に登録された本人待ちのtodoを、Event（todo_open）にする。その日に閉じた（完了した）todoは todo_done にする"
		text:  "todoはすべて人のタスク（本人待ち）。登録の時刻は `created_at`、完了の時刻は `resolution.at`。いま開いているかどうかではなく、その日の変化（登録と完了）を数える（D-03）。"
		acceptance: [
			"`created_at` がその日のtodoが、今の状態によらず、kind `todo_open`、時刻 `created_at` のEventになる",
			"`status` が `done` で `resolution.at` がその日のtodoが、kind `todo_done`、時刻 `resolution.at` のEventになる",
			"取り消した（`cancelled`）todoの取消しと、サブタスクは入らない",
			"Eventに、todoのID・種類・題名・期限・関連するScopeが入る",
		]
	}
	"R-03": {
		title: "読むだけの機械向けの出力だけを使う"
		text:  "`spec-dock scope list --offline --json`、`spec-dock todo list --status all --offline --json`、`gh issue list --state all --json number,title,state,createdAt,closedAt,url`。カタログの内部のファイルは解釈しない。`spec-dock` には `--offline` を付け、SpecDockの手元の観測（キャッシュ）を新しくしない（道具の状態も変えない約束。`shipcast.collect.base` の `Collector`）。"
		acceptance: [
			"呼ぶ外部のコマンドは、D-02 の3つの形だけ（ほかの `spec-dock`・`gh` のsubcommandを呼ばない）",
			"SpecDockを使っていないrepository（`<path>/spec-dock/workspace.json` がない）では、何も呼ばず、Eventも警告もない",
		]
	}
}

failures: {
	"F-01": {
		title:    "`gh` が使えない・認証がない・失敗するときは、Scopeの出来事を警告にして空にし、todoの出来事だけを集める"
		impact:   "その日のScopeの作成と終了が日誌に入らない。todoとほかのcollectorの結果は保存する"
		recovery: "`gh auth status` を直して、同じ `--date` で集め直す（保存は冪等）"
	}
	"F-02": {
		title:    "SpecDockを使うrepositoryで、`spec-dock` がない・失敗する・JSONが読めないときは、`CollectError` にする（そのrepositoryのSpecDockの失敗。epic-00003 の F-02）"
		impact:   "そのrepositoryのSpecDockの出来事が入らない。Gitの出来事とほかのrepositoryは続ける"
		recovery: "`spec-dock` を入れる・直して、集め直す"
	}
}

constraints: [
	"標準のライブラリだけで書く（依存を足さない）。試験は、`subprocess.run` を置き換えて、`tests/fixtures/specdock/` の見本を返す。試験で本物の `spec-dock`・`gh` を呼ばず、ネットワークを使わない",
	"このrepositoryはpublic。見本は架空の値（repository `example-org/demo-app`、架空の題名・ID・URL）にし、手元の実際の出力の値を写さない",
	"開発は通常の `coding-task`。マージは統括が行い、タスク担当と実装担当はマージしない（`content/decisions/20261126-journal-format-and-hackathon-plan.md` の 18〜21）",
]

decisions: [
	"`Collector.collect(repo, day, tz)` と `shipcast.collect.COLLECTORS` は、iss-00011 の実装のとおりに使う（申し送り。統括の依頼、2026-11-26）",
	"R-02 の「開いている本人待ちのtodo」を、「その日に登録されたtodo」と読む。日誌はその日の変化を書くもので、Eventの時刻はその日の中に収める約束（`collect_repo` が確かめる）があり、前から開いたままのtodoを毎日出すと同じ出来事が日ごとに重なるため。今も開いているかは本文に書く（タスク担当の判断、2026-11-26。本人の決定 6「細部の設計はエージェントが詰める」の範囲）",
	"SpecDockを使っていないrepositoryは、失敗でも警告でもなく、空を返す。登録するrepositoryの多くはSpecDockを使わないので、毎晩の失敗にしないため。見分けは `spec-dock/workspace.json` があるかだけで、中身は読まない（タスク担当の判断、同じ範囲）",
	"`spec-dock` 自体が失敗したときは `CollectError`、`gh` が失敗したときは警告にする。`gh` は時刻の補いで、todoはそれなしで集められるため（epic-00003 の D-03 と F-02）",
	"作業のbranchは統括が作ったworktreeの `chemitaro/iss-00012` を使う",
]
