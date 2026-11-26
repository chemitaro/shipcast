package spec

goal: "Wave 3 の最初として `main` へ入れる。入った後、iss-00012（SpecDock）が `Collector` の約束と `COLLECTORS` に従ってcollectorを足し始められ、iss-00016・iss-00021 が `collect_repo` を呼べる。"

steps: {
	"S-01": {
		title:    "collectorの約束と収集の実行（`shipcast.collect.base`、`shipcast.collect`）"
		text:     "D-01、D-02。T-02 のうち `collect_repo` の部分と T-05 を `tests/test_collect.py` に先に書いて落ちることを確かめ（Red）、`src/shipcast/collect/base.py` に `CollectError`・`CollectResult`・`Collector`・`day_bounds`・`RepoCollection`・`collect_repo` を、`src/shipcast/collect/__init__.py` に `COLLECTORS = ()`（S-03 でGitを足す）を書いて通す（Green）。架空のcollectorを試験の中に書く。完了の条件：その試験が通り、`uv run ruff check` が通る。"
		realizes: ["R-01"]
		session:  "impl"
	}
	"S-02": {
		title:    "`shipcast collect` のコマンド（`shipcast.collect.command`、`shipcast.cli`）"
		text:     "D-03。T-06 を `tests/test_collect.py` に先に書いて Red を確かめ（架空のcollectorを `shipcast.collect.command.COLLECTORS` の置き換えで渡す）、`src/shipcast/collect/command.py` を書き、`src/shipcast/cli.py` に D-03 の2行だけを足す・書き換える。`tests/test_cli.py` の未実装の一覧から `collect` を外す（`collect --unknown` の誤りの試験は残す）。完了の条件：T-06 と既存の試験が通り、`uv run ruff check` が通る。"
		realizes: ["R-01", "F-02"]
		after:    ["S-01"]
		session:  "impl"
	}
	"S-03": {
		title:    "Gitのcollector（`shipcast.collect.git`）と登録"
		text:     "D-04、D-05。T-01、T-03、T-04、T-07 と、T-02 の実際のGitでの端から端の試験を `tests/test_collect_git.py` に先に書いて Red を確かめ、`src/shipcast/collect/git.py` に `GitCollector` を書き、`COLLECTORS = (GitCollector(),)` にして Green。試験の架空のrepositoryは `tmp_path` に `git init -b main` で作り、`GIT_AUTHOR_DATE`・`GIT_COMMITTER_DATE` で時刻を決め、`HOME` と `GIT_CONFIG_GLOBAL`・`GIT_CONFIG_SYSTEM`（`/dev/null` など）で利用者のGitの設定を読まないようにし、名前とメールアドレスは架空のもの（`example.com`）にする。完了の条件：`test_commands` がすべて終了コード0。"
		realizes: ["R-02", "R-03", "F-01"]
		after:    ["S-02"]
		session:  "impl"
	}
}

tests: {
	"T-01": {
		title:    "架空のrepository（時差 +09:00 の日 2026-11-26）で、正本の歴史の前日 23:59:59・当日 00:00:00・12:00・23:59:59・翌日 00:00:00 のcommit、2日前に作ったfeatureのcommitを当日にmergeしたmerge、当日に作った未統合のbranchのcommitから、当日の3つのcommit（kind `commit`）、merge（kind `merge`、本文に `取り込んだcommit: 1件`）、取り込んだcommit（kind `commit`、`at` がmergeの時刻、`refs` が `(sha, mergeのsha)`、本文に `マージ <12桁> で入った`）だけが返る。各Eventの `id`・`source`・`repo_id`・`title`・`actor`・本文の `変更したファイル: N件` が D-04 のとおり。題名の空のcommitは `（題名のないcommit）`"
		verifies: ["R-02"]
	}
	"T-02": {
		title:    "`collect_repo` が、架空のcollectorのEventを保存して `saved` を返し、同じ日の二度目の `saved` が0で、`Store.events_for` の件数が同じ。実際のGitのrepositoryで `shipcast collect --repo demo --date 2026-11-26` を実行すると、終了コード0、標準出力が `demo 2026-11-26: N件を集め、N件を新しく保存しました`、状態にそのEventが入る。二度目は `0件を新しく保存しました`"
		verifies: ["R-01"]
	}
	"T-03": {
		title:    "ないpath、Gitでないpath（`tmp_path` の普通のディレクトリ）、repositoryの下のディレクトリ、ないref、`-` で始まるref、`git` のコマンドがない（`GitCollector(git=<ないpath>)`）が、どれも pathかrefか理由を含む `CollectError` になる。CLIで、1つ目のrepositoryがGitでなく2つ目が正しい設定のとき、標準エラーに `shipcast collect: 失敗: <id>: git: ` で始まる行があり、2つ目のEventは保存され、終了コード1"
		verifies: ["F-01"]
	}
	"T-04": {
		title:    "変更済みのファイルと未追跡のファイルと別のbranchを持つ架空のrepositoryで収集した前後で、`.git/HEAD` と `.git/index` のバイト列と `st_mtime_ns`、`for-each-ref` と `status --porcelain=v1 --untracked-files=all` の出力、作業ツリーのファイルのバイト列が同じ。記録した全部のGitの呼び出しが `[git, \"--no-optional-locks\", \"-C\", <path>, sub, ...]` で、`sub` が `rev-parse`・`log`・`diff-tree` のどれか"
		verifies: ["R-03"]
	}
	"T-05": {
		title:    "`collect_repo` で、`CollectError` を投げるcollectorが `errors` に `<name>: <文>` で入り、ほかのcollectorのEventは保存される。警告が `<name>: <文>` で入る。`source` の違う・`repo_id` の違う・時刻がその日の外（`day_bounds` の終わりちょうどを含む）のEventを返すcollectorは、そのEventが全部保存されず `errors` に入り、そのcollectorの警告は残る。`COLLECTORS` の `name` が重ならず `SOURCES` にあり、最初が `git`（S-03 の後）。`day_bounds` が `Store.events_for` と同じ区切り"
		verifies: ["R-01"]
	}
	"T-06": {
		title:    "CLI：`--repo` を省くと登録の全部を設定の順に集める。`--date` を省くと設定の timezone の今日（`datetime.now` を固定して確かめる）。警告だけなら終了コード0で標準エラーに `shipcast collect: 警告: ` の行。登録にない `--repo`、登録が0件、設定ファイルがない、読めない `--date`（終了コード2、usage）、状態の置き場の `state.sqlite3` がSQLiteでないファイル（`StateError`）、`state_dir` が普通のファイル（`OSError`）で、D-03 の文と終了コード。どの失敗でも状態に何も書かない（ないときは置き場を作らない。設定ファイルが読めない場合と `--repo` の誤りの場合）"
		verifies: ["R-01", "F-02"]
	}
	"T-07": {
		title:    "mergeの取り込んだcommitが `max_merged` を超えると、`max_merged` 件だけが返り、警告 `マージ <12桁> が取り込んだcommitが<N>件を超えたので、<N>件だけを集めました` が入る（`GitCollector(max_merged=2)` で3件を取り込む）"
		verifies: ["R-02"]
	}
}

verification: "`test_commands` を順に流し、すべて終了コード0。PRを作った後に、GitHub ActionsのCIの合格を `github-pr-checks` で観測する。"
rollback:     "PRを戻す（revert）だけで元に戻る。状態に保存したEventは、利用者の手元のSQLiteにだけあり、同じIDで集め直せば増えない。"
exit:         "PRが最終品質ゲートとCIに合格し、タスク担当が統括にPR・合格のコミット・CIの結果を報告した時点で、このIssueの作業は終わる。マージと `spec-dock work finish` は統括が行う。"

// 関門（coding-task）。保証レベル standard の既定と、本人の決定 18〜21（init-00001 の plan.cue の delivery）に従う。
gates: {
	spec_review: "Claude `spec-reviewer`（Opus 5.5 / high）。P0・P1がなくなるまで、3回まで"
	checkpoints: "なし。理由：手順は3つで、1人の実装担当が続けて書き、どれもこのIssueの中の新しいmoduleで、cli.py の変更は2行だけ。後の手順が依る境界（`Collector`・`collect_repo`）は S-01 の試験と最終品質ゲートの `api-contract` の観点で確かめる。後のIssueはこのPRがマージされるまで読み込まないので、途中で止めて見る利得が小さい"
	final_quality_gate: {
		scope:          "開始のコミット（統括が作ったworktreeの作業の始めの `HEAD`、`f68349a`）から S-03 の後の `HEAD` まで"
		perspectives:   ["functional-correctness", "requirements-closure", "test-adequacy", "api-contract", "security"]
		test_commands:  ["uv sync --locked", "uv run ruff check", "uv run pytest -q"]
		record_paths:   ["spec-dock/initiatives/00000-00999/iss-00011/report.md（SpecDockの自動の保存で記録する。Gitのcommitは要らない）"]
		second_opinion: "none"
	}
	merge:            "agent"
	merger:           "統括。タスク担当と実装担当はマージしない（本人の決定 21）。条件は `coding-task` の `references/merge.md`（CIの合格の観測を含む）"
	merge_permission: "本人の「PR のマージは各ワーカーが行わず、統括（Antigravity）が行う」（2026-11-26、`content/decisions/20261126-journal-format-and-hackathon-plan.md` の 21。init-00001 の `plan.cue` の `delivery.gates_by_level.standard.merge`）"
	pr:               "branchは `chemitaro/iss-00011`（統括が作ったworktreeのbranch）。PRの本文に、合格のコミット、最終品質ゲートの結果、CIの結果を書く。Issueを自動で閉じる書き方（Closes #11）は使わない"
}

execution: {
	sessions: {
		spec: {task: "仕様化（起動した側が選んだ値の記録）", provider: "claude", model: "Claude Opus 5.5", effort: "medium", rationale: "統括が起動したOrcaの作業者。値は起動した側が方針§2の standard のタスク担当の行から決めた（事実の記録）"}
		owner: {task: "タスク担当（仕様、説明資料、レビュー、最終品質ゲート、PR、CIの観測）", provider: "claude", model: "Claude Opus 5.5", effort: "medium", rationale: "方針§2のタスク担当の standard の行。spec と同じセッション"}
		impl: {task: "実装（S-01〜S-03）。このworktreeで起動するOrcaの作業者", provider: "codex", model: "GPT-6.2 Sol", effort: "medium", rationale: "方針§2の、テストで確かめられる実装（バックエンド）の行、本人の決定 19、統括の依頼"}
	}
	reviews: {
		final_gate: {role: "最終品質ゲートの `quality-gate-reviewer`", after: "S-03", model: "Claude Opus 5.5", effort: "medium"}
	}
	assignment:   "S-01, S-02, S-03 → impl（連続）"
	same_session: "なし（実装担当の提供元がタスク担当と違うため、別のセッションにする）"
}
