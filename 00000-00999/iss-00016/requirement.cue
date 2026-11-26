package spec

schema: "specdock/v1"

assurance: {
	level:  "standard"
	reason: "日誌のMarkdownの形（epic-00002 の日誌の契約）を実際に作る部品で、配信（epic-00005）とおまけ（iss-00019）がこの形を読む。誤ると日誌が読めなくなるが、出来事と話題は状態に残るので、PRを戻して書き直せば回復できる"
}

purpose: "その日の出来事を集め、話題（Story）にまとめ、書き手のモデルで「要約＋読み物」の文章を書かせ、epic-00002 の日誌の契約（パスと前付け）と epic-00004 の D-04 の形のMarkdownのファイルを作る。`shipcast write --repo <id> --date <日付>` のコマンド。"

background: """
親の epic-00004 の R-03〜R-06・F-04 と、F-01 のうち「前の日誌のファイルを壊さない」を、このIssueが受け持つ（epic-00004 の `plan.cue` の `slices`）。

`main` にすでにある次のものを、名前を変えずに使う。

- `shipcast.model`：`Event`・`Story`・`Entry`、`journal_path(journal_dir, repo, day)`、`JournalMeta`・`write_frontmatter(meta)`・`parse_journal(text)`（iss-00010）
- `shipcast.state.Store`：`events_for(repo_id, day, *, tz)`、`save_entry(entry)`（iss-00010）
- `shipcast.collect`：`COLLECTORS` と `collect_repo(store, repo, day, *, tz, collectors)`（iss-00011・iss-00012・iss-00013）
- `shipcast.models`：`get_route(model_cfg)` が返す `GuardedRoute`（`name`・`model`・`complete(prompt, *, system, want_json)`）。`fake` の経路は `responder` で応答を決める（iss-00014）
- `shipcast.analyze`：`analyze(events, route, *, store, repo_id, day) -> list[Story]`、`AnalyzeFailed`（iss-00015）

出来事の種類（`Event.kind`）は収集が決めている：git は `commit`・`merge`、SpecDock は `scope_opened`・`scope_closed`・`todo_open`・`todo_done`（`refs` の先頭が todo のID）、Orca は `conversation`。

先行のIssueからの申し送り：

- iss-00015：同じ日を分析し直すと、古い話題が `stories` の表に残る。書く段は `analyze` の戻り値を使い、`Store.stories_for` を使わない。
- iss-00017：前付けは `write_frontmatter` の形（キーの前に空白がなく、値は1行の文字列）で書く。前付けの値と本文に生のHTMLを入れない（`lead` の `<!--` で ds.js の頭の組み立てが壊れることを確かめた）。
- epic-00004 の D-05：`:::metrics` は events から機械で数え、iss-00019 が日誌の末尾に「発信の芽」（`:::tip`）を足せる拡張点を用意する。
"""

includes: [
	"`src/shipcast/write.py`：書き手への依頼（`compose`）、応答の検査（`parse_draft`）、数（`count_metrics`）、組み立て（`build_entry`）、拡張点（`JournalExtension`・`EXTENSIONS`）、原子的な置き換え（`write_atomic`）、1日の流れ（`write_day`）、CLI（`configure`・`run`）",
	"`src/shipcast/prompts/write.md`：書き手のモデルへの指示（system の本文）",
	"`src/shipcast/cli.py`：`write` の葉を `shipcast.write.configure` につなぐ（ほかの葉は変えない）",
	"`tests/test_write.py`、`tests/test_cli.py` の未実装の一覧から `write` を外す",
]

excludes: [
	"`runs` の表への記録、全repositoryを順に回す夜の実行（iss-00021 の `shipcast run`）",
	"「発信の芽」の囲みの中身とネタポイントの帳簿（iss-00019）。このIssueは拡張点だけを作り、既定の一覧は空",
	"日誌の配信・一覧の表示（epic-00005）",
	"公開の方針（公開の範囲・NGワード）による絞り込み（epic-00006 以降）",
	"本物の `codex`・`claude`・`agy` を呼ぶ試験。本物の経路での確かめは、本人の手動の実行だけ",
	"`shipcast.model`・`shipcast.state`・`shipcast.models`・`shipcast.analyze`・`shipcast.collect`・`shipcast.config` の変更",
]

requirements: {
	"R-01": {
		title: "`shipcast write --repo <id> --date <日付>` が、集める→まとめる→書くを通して、日誌のファイルを作る"
		text:  "収集（`collect_repo`）→ その日の出来事の読み出し（`Store.events_for`）→ まとめ（`analyze`）→ 書き手（`compose`）→ 組み立て（`build_entry`）→ 置き換え（`write_atomic`）→ 日誌の記録（`Store.save_entry`）の順。形は design.cue の D-06・D-07。"
		acceptance: [
			"fake の経路で、`journal_path(journal_dir, repo, day)`（`<journal_dir>/<repo>/<年>/<YYYY-MM-DD>.md`）ができ、終了コード0",
			"前付けを `parse_journal` で読むと、`title`・`lead`・`date`・`repo`・`category`・`analyst`・`writer`・`generated_at`・`schema` が入る。`analyst`・`writer` は `<経路>/<モデル>`",
			"日誌に書く話題は `analyze` の戻り値で、状態に残る同じ日の古い話題は日誌に出ない",
			"`Store.entry_for(repo, day)` で、パスと使った話題のIDが読める",
		]
	}
	"R-02": {
		title: "前付け・要約・知っておくべきこと・物語・待っていること・数字の順のMarkdownになる"
		text:  "形は design.cue の D-04。書き手のモデルが書くのは `lead`・要約の行・物語の本文だけで、囲み（`:::`）と `##` の見出しはshipcastが付ける。"
		acceptance: [
			"出来事のある日の本文は、`:::summary` → `:::warning`（話題に `notice` があるときだけ）→ `## 今日の物語` → `:::checklist`（話題に `waiting` があるときだけ）→ `:::metrics` → 拡張点の囲み、の順",
			"使う囲みは summary・warning・checklist・metrics と、拡張点が返したものだけ",
			"文体の指示（「要約＋読み物」、です・ます調）が書き手のプロンプトにある",
		]
	}
	"R-03": {
		title: "出来事のない日は、モデルを呼ばずに短い日誌にする"
		acceptance: [
			"その日のEventが0件なら、分析と書き手の経路の呼び出しが0回で、ファイルは前付けと「大きな動きはありませんでした。」の1行になる",
		]
	}
	"R-04": {
		title: "`:::metrics` の数字は、出来事（events）から機械で数える"
		text:  "書き手のモデルには数えさせない。組み立ての関数は、話題（stories）と一緒にその日の出来事（events）を入力に受け取る。数え方は design.cue の D-03。"
		acceptance: [
			"merge の数、commit の数、閉じたScopeの数、新しい本人待ちのtodoの数が、見本の出来事から数えた値と一致する",
			"どの数も0のときも、4行とも出る",
		]
	}
	"R-05": {
		title: "日誌の末尾に囲みを足す拡張点がある（iss-00019 の「発信の芽」が使う）"
		text:  "拡張点は、日誌の組み立ての最後に呼ばれ、Markdownの囲みの文字列を返す部品の一覧。このIssueでは既定の一覧は空で、日誌は変わらない。形は design.cue の D-05。"
		acceptance: [
			"試験用の部品を1つ渡すと、その文字列が `:::metrics` の後に足される。`None` や空白だけの文字列を返した部品の分は足されない",
			"既定の一覧 `EXTENSIONS` は空で、渡さないときは何も足されない",
		]
	}
}

failures: {
	"F-01": {
		title:    "分析・書き手・組み立て・書き込みのどこで失敗しても、前の日誌のファイルを壊さず、失敗として報告する"
		text:     "同じフォルダーの一時ファイルに書いてから `os.replace` で置き換える（D-06）。失敗したら一時ファイルを消す。CLIは repositoryごとに失敗の理由を日本語で標準エラーに出し、終了コード1にする。書き手の応答が2回とも形に合わないときは `WriteFailed`（D-02）。"
		impact:   "途中まで書いたファイルで前の日誌が消える"
		recovery: "出来事と話題は状態に残っている。同じ日を実行し直すと書き直せる"
	}
	"F-02": {
		title:    "書き手には話題の骨組みだけを渡し、創作を禁じ、生のHTMLと囲みを本文に入れさせない"
		text:     "書き手に渡すのは、各話題の `title`・`what`・`why`・`notice`・`waiting` だけ（出来事の本文、ネタポイント、出来事のIDは渡さない）。応答に生のHTML・囲み（`:::`）・`#`/`##` の見出しがあれば形の誤りとして1回だけ頼み直す。shipcastが本文に入れる話題の文字列は、`&`・`<`・`>` を文字の参照に置き換えてから入れる（D-04）。"
		impact:   "本人が誤った事実を日誌から信じる。配信のページが壊れる"
		recovery: "誤りに気づいたら、同じ日を実行し直す"
	}
}

constraints: [
	"標準のライブラリだけで書く（依存を足さない）",
	"試験とエージェントの作業では、外部のモデルを呼ばない。モデルの経路は `fake`（`responder` で応答を決める）だけを使い、`agy` を呼ばない（AGENTS.md）",
	"このrepositoryはpublic。見本の出来事・話題・応答は架空の値にする",
	"モデルへは `GuardedRoute.complete` だけを通して渡す（伏せる処理を飛ばさない。epic-00004 の F-02）。prompt の全体を1つのJSONの物にし、指示は system に書く（iss-00014 の申し送り）",
	"開発は通常の `coding-task`。マージは統括が行い、タスク担当と実装担当はマージしない（`content/decisions/20261126-journal-format-and-hackathon-plan.md` の 18〜21）",
]

decisions: [
	"書き手の応答はJSON（`lead`・`summary`・`story`）で受け、`:::warning` と `:::checklist` の項目は、書き手ではなく話題の `notice`・`waiting` からshipcastが機械で作る。囲みの順と種類（R-02）と創作の禁止（F-02）を、書き手の出来に頼らず保つため。epic-00004 の D-03「本文のMarkdownを受け取る」を、物語の本文と要約の行を受け取る形に細かくしたもの（タスク担当の判断、2026-11-26。本人の決定 6「細部の設計はエージェントが詰める」の範囲）",
	"書き手の応答の形が合わなければ、分析と同じく1回だけ頼み直す（`MAX_ATTEMPTS = 2`）。経路の失敗（`RouteError`）は頼み直さない（iss-00015 と同じ理由。タスク担当の判断、同じ範囲）",
	"「本人待ちのtodo」の数は、その日の出来事だけから数えられる「その日に開き、その日のうちに閉じなかったtodo」とし、表示の名前を「新しい本人待ちのtodo」にする。今開いている全件は、その日の出来事からは数えられないため（タスク担当の判断、同じ範囲）",
	"日誌の `title` は `<repo の id> の開発日誌 <YYYY-MM-DD>`、`category` は `開発日誌`、`schema` は `1`。repositoryの題名（設定の `title`）は任意の文字を含みうるので、前付けには英小文字・数字・`-` だけの id を使う（タスク担当の判断、同じ範囲）",
	"出来事のない日の前付けには `analyst`・`writer` を書かない（モデルを呼んでいないため）。`lead` は「大きな動きはありませんでした。」。状態の `entries` には `analyst`・`writer` を `none` で記録する（`Entry` は空でない文字列を求めるため）。拡張点はこの日には呼ばない（R-03 の「前付けと1行」を保つため）（タスク担当の判断、同じ範囲）",
	"`shipcast write` は書く前に収集を走らせる（R-01 の「集める→まとめる→書く」）。収集で誤り（`RepoCollection.errors`）が出た repositoryは、欠けた材料で日誌を作らないよう、書かずに失敗とする。警告だけなら書く。`--repo` を省くと登録したすべての repository、`--date` を省くと設定の時間帯の今日（`shipcast collect` と同じ）（タスク担当の判断、同じ範囲）",
	"拡張点の部品が例外を投げたら、その日の日誌は書かず失敗とする（壊れた部品で一部の欠けた日誌を黙って作らないため）（タスク担当の判断、同じ範囲）",
	"作業のbranchは統括が作ったworktreeの `chemitaro/iss-00016` を使う",
]
