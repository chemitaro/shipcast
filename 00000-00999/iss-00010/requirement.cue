package spec

schema: "specdock/v1"

assurance: {
	level:  "standard"
	reason: "Event・Story・Entryの型とSQLiteの表は、収集・執筆・配信・夜の実行の全部が読む共通のデータの約束になる。誤ると後続の全Issueに波及するが、状態は手元のSQLiteだけで、消して集め直せば回復できる"
}

purpose: "出来事（Event）・話題（Story）・日誌（Entry）の型と、日誌のパスと前付けの契約を `shipcast.model` に、SQLiteの状態の置き場を `shipcast.state` に作る。後のIssue（収集・分析・執筆・配信・おまけ・夜の実行）は、名前や形を自分で決めずに、ここを読み込むだけにする。"

background: """
親の epic-00002 の R-03（型）、R-04（状態）、R-05（日誌の契約）をこのIssueが受け持つ（epic-00002 の `plan.cue` の `slices`）。形の正本は epic-00002 の D-03（型）、D-04（表）、D-05（日誌のパスと前付け）で、このIssueは、それを実装と試験に迷いがない粒度まで決める。

使う側として、すでに次の呼び方が後のIssueの仕様に書かれている。名前を変えずに受ける。

- iss-00011（収集）：`Store.add_events`
- iss-00015（分析）：`Store.save_stories`、`Store.stories_for(repo, date)`、neta.score は0〜3の整数で範囲の外は形の誤り
- iss-00016（執筆）：`journal_path`、前付けの `title`・`lead`・`date`・`repo`・`analyst`・`writer`・`generated_at`
- iss-00017・iss-00018（配信・一覧）：前付けの `title`・`lead`・`date` を読む
- iss-00019（ネタポイント）：`neta_ledger`、`neta_balance(repo)`、同じ話題を二度足さない
- iss-00021（夜の実行）：`runs` の表に、repositoryごとの開始・終了・結果・誤り

iss-00008 が `main` に入れたCLIの骨組み（`shipcast.cli`）と、並行の iss-00009（`shipcast.config`、`repo add|list`）には触れない。
"""

includes: [
	"`src/shipcast/model.py`：Event・Story・Entry・Neta・JournalMeta の型、`event_id`・`story_id`、JSONとの行き来、日誌のパスと前付けの関数",
	"`src/shipcast/state.py`：`Store` と `Run`、SQLiteの5つの表、保存と読み出しの関数",
	"`tests/test_model.py`、`tests/test_journal.py`、`tests/test_state.py`",
]

excludes: [
	"設定ファイルの読み込み、`state_dir`・`journal_dir`・`timezone` の既定値と `~` の展開（iss-00009 の `shipcast.config`）",
	"CLIの下位のコマンドの中身（`shipcast.cli` は変えない）",
	"出来事を実際に集めること、話題にまとめること、日誌の本文を書くこと（iss-00011 以降）",
	"表の版の移行の仕組み（版1だけを作る。新しい版の置き場を見たら止まるだけ）",
	"外部のモデルの呼び出し（`agy`、`codex`、`claude` を一切呼ばない）",
]

requirements: {
	"R-01": {
		title: "Event・Story・Entry（と話題の中の Neta）の型が `shipcast.model` にあり、JSONと行き来できる"
		text:  "項目は epic-00002 の D-03 のとおり。型は変えられない（`frozen`）dataclassで、JSONの文字列（`to_json`・`from_json`）と辞書（`to_dict`・`from_dict`）の両方と行き来する。"
		acceptance: [
			"架空の値の Event・Story・Entry を `to_json` にして `from_json` で戻すと、元と等しい（`==`）。`to_dict`・`from_dict` も同じ",
			"JSONの最上位に `\"schema\": 1` が入る（Story の中の neta には入れない）",
			"`event_id(source, repo_id, native_id)` は、同じ引数で同じ16桁の英小文字の16進数を返し、3つのどれかが違えば違う値を返す",
		]
	}
	"R-02": {
		title: "状態の置き場 `shipcast.state.Store` が、出来事・話題・日誌・実行・ネタポイントを保存し、読み出せる"
		acceptance: [
			"`Store(state_dir)` が、なければ `state_dir` を作り、その中の `state.sqlite3` に `events`・`stories`・`entries`・`runs`・`neta_ledger` の5つの表を作る",
			"保存した Event を `events_for(repo_id, day, tz=...)` で、その日（`tz` での0時から翌日の0時の前まで）の分だけ、時刻の順に読み出せる。ほかのrepositoryと前後の日の Event は入らない",
			"Story・Entry・実行の記録（Run）を保存して、`stories_for`・`entry_for`・`runs_for` で読み出すと、保存したものと等しい",
			"`add_neta` で足した話題の点数の、未消化の分の合計が `neta_balance(repo_id)` になり、`consume_neta` で消化した分は合計から外れる",
			"`Store` を閉じて同じ `state_dir` で開き直しても、保存したものが読める",
		]
	}
	"R-03": {
		title: "同じものを二度保存しても1件のまま（冪等）"
		text:  "夜の実行や手動の実行で、同じ日を何度集め直しても、件数と点数が増えないようにする。"
		acceptance: [
			"Event の `id` は、出所（`source`）・repository（`repo_id`）・元のID（SHA、Scope ID など）だけから決まる（`event_id`）",
			"同じ Event の一覧を二度 `add_events` しても `events` の件数は変わらず、二度目の戻り値（新しく入った件数）は0",
			"同じ `id` の Story を二度 `save_stories` しても1件で、後の内容になる。同じ話題を二度 `add_neta` しても、`neta_balance` は1回分のまま",
			"同じ repository と日付の Entry を二度 `save_entry` しても1件で、後の内容になる",
		]
	}
	"R-04": {
		title: "日誌のパスと前付けの契約（epic-00002 の D-05）が `shipcast.model` にある"
		acceptance: [
			"`journal_path(journal_dir, \"shipcast\", date(2026, 11, 26))` が `<journal_dir>/shipcast/2026/2026-11-26.md` を返す",
			"`write_frontmatter(meta)` で書いた文字列を `parse_journal`（ファイルなら `read_frontmatter`）で読むと、元の `JournalMeta` に戻る",
			"必須の項目（`title`・`lead`・`date`・`repo`）が欠けた、または空の前付けを読むと、欠けた項目をすべて名指して失敗する",
		]
	}
}

failures: {
	"F-01": {
		title: "型の値が約束に合わないときは、項目を名指して `ModelError` で止まる"
		text:  "必須の項目がない、型が違う、`schema` が1でない、`source` が git・specdock・orca のどれでもない、`at` に時差がない、`neta.score` が0〜3の整数でない、`repo_id` が英小文字・数字・`-` だけでない、のどれか。後のIssue（特に iss-00015 の形の誤り）は、この誤りをそのまま使う。"
	}
	"F-02": {
		title: "前付けが壊れているときは、行か項目を名指して `JournalFormatError` で止まる"
		text:  "先頭が `---` でない、閉じの `---` がない、`key: value` の形でない行がある、同じ項目が2回ある、`date`・`schema` が読めない、のどれか。書く側では、改行を含む値、前後に空白のある値、空の値を、`JournalMeta` を作る時点で受け付けない（書いて読み戻すと変わってしまうため）。"
	}
	"F-03": {
		title: "状態の置き場が、このshipcastより新しい版か、SQLiteとして読めないときは、何も書かずに `StateError` で止まる"
		text:  "SQLiteの `user_version` が、このコードの版（1）より大きいとき（古いshipcastで新しい置き場を壊さないため）と、`state.sqlite3` がSQLiteのファイルでないとき。誤りの文に `state.sqlite3` のパスを入れる。"
	}
	"F-04": {
		title: "repositoryのIDが約束に合わないときは、パスを作らずに止まる"
		text:  "`journal_path` の `repo` に `/` や `..` などが入ると、日誌の置き場の外を指しうる。英小文字・数字・`-` だけでなければ `ModelError` で止まる。"
	}
}

constraints: [
	"repositoryはpublic。試験の見本は架空の値だけにし、実在の非公開の情報を書かない（AGENTS.md）",
	"実行時の依存を足さない。標準のライブラリ（`dataclasses`、`json`、`hashlib`、`sqlite3`、`datetime`、`pathlib`、`re`）だけを使う。前付けにYAMLのライブラリを使わない",
	"試験は `tmp_path` の下だけに書き、利用者の `~/.local/state` などに触れない。外部のモデルや外部のコマンドを呼ばない",
	"並行の iss-00009 とぶつからないよう、変えるファイルは `src/shipcast/model.py`、`src/shipcast/state.py`、`tests/test_model.py`、`tests/test_journal.py`、`tests/test_state.py` だけにする（`pyproject.toml`、`uv.lock`、`cli.py` を変えない）",
	"開発は通常の `coding-task`。マージは統括（Antigravity）が行い、タスク担当と実装担当はマージしない（`content/decisions/20261126-journal-format-and-hackathon-plan.md` の 18〜21）",
]

decisions: [
	"時刻 `at` は時差付きの `datetime` で持ち、表にはUTCに直した文字列も入れて並べ替えと日の範囲に使う。日の区切りは `Store` に設定を読ませず、呼ぶ側が `tz` で渡す（設定の `timezone` は iss-00009 が読む）。タスク担当の判断（2026-11-26。本人の決定 6「細部の設計はエージェントが詰める」の範囲）",
	"Event の `id` には `repo_id` も混ぜる。同じSHAが別のrepository（forkなど）にあっても別の出来事として残すため。epic-00002 の D-03「出所と元のIDのハッシュ」を、repositoryの区別を足して具体化した（タスク担当の判断、同じ範囲）",
	"Story の `notice`・`waiting` は文字列の並び（0件以上）にする。日誌の「知っておくべきこと」「待っていること」は箇条書きになるため（タスク担当の判断、同じ範囲）",
	"前付けの知らない項目は、読むときに捨てる（誤りにしない）。後のIssueが任意の項目を足しても、古い読む側が壊れないようにするため（タスク担当の判断、同じ範囲）",
]
