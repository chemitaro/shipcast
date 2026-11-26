package spec

schema: "specdock/v1"

assurance: {
	level:  "standard"
	reason: "collectorの共通の約束（`shipcast.collect.base`）は、SpecDockとOrcaの収集（iss-00012、iss-00013）と執筆（iss-00016）・夜の実行（iss-00021）が使う境界になる。対象のrepositoryを読むだけで書き換えず、誤っても日誌が欠けるだけで、PRを戻して集め直せば回復できる"
}

purpose: "collectorの共通の約束と `shipcast collect` を作り、Gitの出来事を集める。SpecDockとOrcaのcollectorは、この約束に従って後から足す。"

background: """
親の epic-00003 の R-01（Git）、R-04（書き換えない）、F-02（読めないrepositoryは失敗として記録し、ほかは続ける）と、D-01（共通の約束）・D-02（Gitの読み方）をこのIssueが受け持つ（epic-00003 の `plan.cue` の `slices`）。このIssueは、それを実装と試験に迷いがない粒度まで決める。

`main` にすでにある次のものを、名前を変えずに使う。

- `shipcast.config`（iss-00009）：`load_config()`、`Config.timezone`（IANAの名前、検証済み）・`Config.state_dir`・`Config.repos`、`RepoConfig`（`id`、`path`（絶対のパス）、`ref`（既定 `main`）、`title`、`orca`）、`ConfigError`
- `shipcast.model`（iss-00010）：`Event`、`event_id(source, repo_id, native_id)`、`SOURCES = ("git", "specdock", "orca")`
- `shipcast.state`（iss-00010）：`Store(state_dir)`、`Store.add_events(events) -> int`（新しく入った件数。同じIDは無視）、`Store.events_for(repo_id, day, tz=...)`（その日の0時から翌日の0時の前まで）、`StateError`
- `shipcast.cli`（iss-00008）：`COMMANDS` の `collect` の項目（今は未実装の印）

後で使う側：iss-00012（SpecDock）と iss-00013（Orca）は `Collector` の約束に従うcollectorを1つずつ `COLLECTORS` に足す。iss-00016（`write`）と iss-00021（`run`）は `collect_repo` を呼び、iss-00021 が `runs` の表に結果を記録する。
"""

includes: [
	"`src/shipcast/collect/__init__.py`：登録の `COLLECTORS`",
	"`src/shipcast/collect/base.py`：`Collector`、`CollectResult`、`CollectError`、`day_bounds`、`RepoCollection`、`collect_repo`",
	"`src/shipcast/collect/git.py`：`GitCollector`",
	"`src/shipcast/collect/command.py`：`shipcast collect` の引数と実行",
	"`src/shipcast/cli.py`：`collect` の項目に `command.configure` をつなぐ（import の1行と項目の1行だけ）",
	"`tests/test_collect.py`、`tests/test_collect_git.py`、`tests/test_cli.py` の未実装の一覧から `collect` を外す",
]

excludes: [
	"SpecDockとOrcaのcollector（iss-00012、iss-00013）",
	"`runs` の表への記録（iss-00021 の `shipcast run` が `collect_repo` の結果から記録する）",
	"話題にまとめること、日誌を書くこと、外部のモデルの呼び出し（`agy`、`codex`、`claude` を一切呼ばない）",
	"fast-forward で正本のbranchに入ったcommitの、入った時刻の推定（Gitに記録がないため。commitの時刻で数える）",
	"`shipcast.config`・`shipcast.model`・`shipcast.state` の変更",
]

requirements: {
	"R-01": {
		title: "collectorの約束（epic-00003 の D-01）と `shipcast collect --repo --date` がある"
		text:  "約束の型は `shipcast.collect.base` に、登録の `COLLECTORS` は epic-00003 の D-01 のとおり `shipcast.collect` に置く（`base` に置くとGitのcollectorとの読み込みが循環するため）。"
		acceptance: [
			"`shipcast.collect.base` に `Collector`、`CollectResult`、`CollectError`、`collect_repo` があり、`shipcast.collect.COLLECTORS` にGitのcollector（`name` が `git`）が登録されている",
			"`shipcast collect` が、登録されたrepository（`--repo` を付ければその1つ）ごとに全collectorを呼び、Eventを `Store.add_events` で保存し、集めた件数・新しく保存した件数・警告を示す",
			"同じ日を二度集めても、状態のEventは増えない（二度目の新しく保存した件数が0）",
			"collectorの約束に合わないEvent（`source` がcollectorの `name` と違う、`repo_id` が違う、時刻がその日の外）は保存せず、そのcollectorの失敗にする",
		]
	}
	"R-02": {
		title: "その日に正本のbranch（設定の ref）に入ったcommitとmergeを、Eventにする"
		text: """
		「その日に入った」は、refのfirst-parentの列（正本のbranchの歴史）で、commitの時刻（committer date）がその日（設定の timezone の0時から翌日の0時の前まで）のものと、その日のmergeが取り込んだcommitを指す。
		"""
		acceptance: [
			"その日のfirst-parentの列のcommitが kind `commit`、親が2つ以上のものが kind `merge` になり、前日と翌日のものは入らない",
			"その日のmergeが取り込んだcommitは、commitの時刻が前の日でも、そのmergeの時刻のEventとして入る",
			"作業用のbranchの、refに入っていないcommitは入らない",
			"Eventに、題名・本文・作者・SHA・変更したファイルの数が入る",
		]
	}
	"R-03": {
		title: "読むだけの操作で集める（fetch、checkout、indexの書換えをしない）"
		acceptance: [
			"収集の前後で、対象のrepositoryの `HEAD`、index、ref、作業ツリーの状態が変わらない",
			"Gitは、すべて `git --no-optional-locks -C <path>` の形で、`rev-parse`・`log`・`diff-tree` だけを呼ぶ",
		]
	}
}

failures: {
	"F-01": {
		title: "pathがない・Gitでない・Gitの最上位でない・refがない・gitを呼べないときは、そのrepositoryを失敗として示し、ほかのrepositoryは続ける"
		impact: "そのrepositoryのGitの出来事がその日の状態に入らない。ほかのcollectorとrepositoryの結果は保存する"
		recovery: "設定のpathかrefを直し、同じ `--date` で集め直す（保存は冪等）"
	}
	"F-02": {
		title: "設定が読めない・`--repo` が登録にない・登録が1つもない・状態の置き場を開けないときは、何も集めず、直し方を示して終了コード1で止まる"
	}
}

constraints: [
	"標準のライブラリだけで書く（依存を足さない）。試験は `tmp_path` に作る架空のGitのrepositoryで行い、ネットワークと外部のモデルを使わない",
	"このrepositoryはpublic。見本の名前・メールアドレス・本文は架空のもの（`example.com` など）にする",
	"`src/shipcast/cli.py` の変更は、`collect` の接続（import の1行と `COMMANDS` の項目の1行）だけにする。並行の iss-00014・iss-00017 との衝突を小さくするため（統括の指示、2026-11-26）",
	"開発は通常の `coding-task`。マージは統括が行い、タスク担当と実装担当はマージしない（`content/decisions/20261126-journal-format-and-hackathon-plan.md` の 18〜21）",
]

decisions: [
	"`COLLECTORS` は epic-00003 の D-01 のとおり `shipcast.collect`（パッケージの `__init__.py`）に置き、約束の型は `shipcast.collect.base` に置く。Issue の当初の受け入れの文（`base` に `COLLECTORS`）は、Gitのcollectorが `base` を読み込むため循環するので、親の設計に合わせて直した。タスク担当の判断（2026-11-26。本人の決定 6「細部の設計はエージェントが詰める」の範囲）",
	"`Collector.collect` は epic-00003 の D-01 の `(repo, day)` に、日の区切りの `tz` を足して `(repo, day, tz)` にする。SpecDockとOrcaのcollectorも、その日の判定に設定の timezone が要るため。`Store.events_for` と同じく、collectorに設定を読ませず、呼ぶ側が渡す（タスク担当の判断、同じ範囲）",
	"「その日に正本のbranchに入った」をfirst-parentの列で決め、mergeが取り込んだcommitはmergeの時刻に置く。refから届く全commitをcommitの時刻で絞ると、前の日に作ってその日にmergeしたcommitが、どの日にも入らないか、集める時刻で結果が変わるため。epic-00003 の D-02 の `git log <ref> --since --until` を、R-01 の「入った」に合わせて具体化した（タスク担当の判断、同じ範囲）",
	"`shipcast collect` は `runs` の表に書かない。`runs` は iss-00021 の `shipcast run` が、repositoryごとの開始・終了・結果・誤りを記録する表で、collect が書くと二重になるため。collect の「失敗として記録」は、結果（`RepoCollection.errors`）と標準エラーの表示と終了コードで示す（タスク担当の判断、同じ範囲）",
	"`--repo` を省くと登録の全部、`--date` を省くと設定の timezone の今日を集める（タスク担当の判断、同じ範囲）",
	"作業のbranchは統括が作ったworktreeの `chemitaro/iss-00011` を使う（iss-00010 と同じ形）",
]
