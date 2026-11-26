package spec

schema: "specdock/v1"

assurance: {
	level:  "light"
	reason: "iss-00016 の拡張点に囲みを1つ足し、台帳に点数を足すだけで、外へは何も送らない。誤っても印が出ない・出すぎるだけで、PRを戻せば元に戻る"
}

purpose: "ネタポイントの台帳と、日誌の「発信の芽」の印を作る。話題を保存するときに、その話題のネタポイントを repository ごとの台帳へ一度だけ足し、未消化の合計がしきい値以上の日の日誌の末尾に `:::tip 発信の芽（ネタポイント N）` の囲みを足す。"

background: """
親の epic-00006 の R-01・R-02 を、このIssueが受け持つ（epic-00006 の `plan.cue` の `slices`）。`main` にすでにある次のものを、名前を変えずに使う。

- `shipcast.state.Store`：表 `neta_ledger`（`story_id` が主キー、`repo_id`、`points` は0〜3、`consumed` は0か1）と、`add_neta(story) -> bool`（未記録なら足して `True`、記録済みなら何もせず `False`）・`neta_balance(repo_id) -> int`（未消化の合計）・`unconsumed_neta(repo_id)`・`consume_neta(ids)`（iss-00010）。`save_stories(stories)`（iss-00010）
- `shipcast.analyze.analyze`：話題を作り、`store.save_stories` で保存して返す（iss-00015）。話題の id は `story_id(repo_id, day, event_ids)` で、同じ出来事の組からは同じ id になる
- `shipcast.write`：拡張点 `JournalExtension`（`render(repo_id, day, stories, events) -> str | None`）、既定の一覧 `EXTENSIONS`、`build_entry(..., extensions=None)`・`write_day(..., extensions=None)`・CLI の `run`（iss-00016）
- `shipcast.config`：`Config.neta.threshold`（1以上の整数、既定6）

先行のIssueからの申し送り：

- iss-00016：拡張点の部品は生のHTMLを返さない。デザインシステムの `:::tip` の囲みのMarkdownだけを返す。出来事のない日には拡張点を呼ばない。部品の例外は受け止めず、その日の日誌を書かない。
- iss-00010：未消化の話題の `Story` を読む `Store` の関数が要るなら足してよい（iss-00020 の X の下書きも使う）。
- 並行の iss-00021（`shipcast run`）が別のworktreeで進む。共有のファイル（特に `cli.py`）の変更を最小にする。
"""

requirements: {
	"R-01": {
		title: "話題を保存するときに、そのネタポイントを台帳に一度だけ加える"
		text:  "`Store.save_stories` が、話題の表への保存と同じ取引（transaction）で、まだ台帳にない話題の `neta.score` を `neta_ledger` に足す。同じ id の話題を保存し直しても、点数は足さず、記録済みの点数・消化済みかは変えない。"
		acceptance: [
			"点数2と1の話題を保存すると、その repository の `neta_balance` が3になる",
			"同じ話題をもう一度保存しても（点数を変えても）、`neta_balance` は変わらない",
			"`analyze` が話題を返した後、その話題が台帳に入っている",
		]
	}
	"R-02": {
		title: "未消化の合計がしきい値以上の日だけ、日誌の末尾に `:::tip 発信の芽` の囲みが出る"
		text:  "`shipcast write` が書く出来事のある日の日誌で、その repository の `neta_balance` が設定の `neta.threshold` 以上なら、`:::metrics` の後（ほかの拡張点の後）に、ポイントの合計と、発信に向く話題の題名を並べた囲みを1つ足す。しきい値未満なら何も足さない。"
		acceptance: [
			"しきい値6で残高が6以上の日の日誌の最後の塊が `:::tip 発信の芽（ネタポイント N）` の囲みで、Nは残高、中に題名が `- ` の行で並ぶ",
			"残高がしきい値未満の日、出来事のない日には囲みが出ない",
			"囲みに生のHTMLが入らない（題名の `<` などは文字参照になる）",
		]
	}
}

includes: [
	"`src/shipcast/state.py`：`save_stories` での台帳への加算、未消化の話題を読む `unconsumed_stories`",
	"新しい `src/shipcast/neta.py`：「発信の芽」の部品 `NetaSprout`",
	"`src/shipcast/write.py`：CLI の `run` が `NetaSprout` を拡張点として渡す配線と、それを作る `journal_extensions`",
	"試験：`tests/test_state.py`・`tests/test_analyze.py`・新しい `tests/test_neta.py`・`tests/test_write.py`",
]

excludes: [
	"Xの下書きと話題の消化（`consume_neta` を呼ぶこと）。iss-00020 が受け持つ",
	"`shipcast run`（iss-00021）への配線。iss-00021 が `journal_extensions` を使えば同じ印が出る（申し送り）",
	"`cli.py`、`JournalExtension` の形、`EXTENSIONS` の既定（空のまま）、表の形（`neta_ledger` の列）の変更",
	"同じ日を分析し直して話題の分け方が変わったときの、古い話題の点数の取り消し（id が変わると別の話題として足される。残る危険として記録する）",
]

constraints: [
	"外部のモデルと `agy` を呼ばない。試験は fake の経路と一時ディレクトリだけで行う",
	"publicのrepositoryなので、試験の見本は架空のもの（`demo-app` など）にする",
]

decisions: [
	"加算の場所は `Store.save_stories` にする。話題の保存と台帳の記録が1つの取引になり、保存の後に落ちても点数だけ抜けることがない（タスク担当の判断、同じ範囲）",
	"点数0の話題も台帳に記録する（`add_neta` の既存の振る舞いのまま。残高は変わらない）。囲みの題名と `unconsumed_stories` には、点数1以上の話題だけを出す（タスク担当の判断、同じ範囲）",
	"しきい値は「以上」で比べる（epic-00006 の D-02）（タスク担当の判断、同じ範囲）",
	"部品は台帳を読むために `Store` としきい値を要るので、`EXTENSIONS`（文脈を持たない既定の一覧、空のまま）には入れず、`shipcast write` の `run` が実行のたびに `journal_extensions(store, threshold)` で `(*EXTENSIONS, NetaSprout(store, threshold))` を作って `write_day` に渡す。epic-00006 の D-02 の「拡張点に部品を1つ登録する」を、この形で満たす。`JournalExtension` の形と `build_entry`・`write_day` は変えない（タスク担当の判断、同じ範囲）",
	"囲みに並べる題名は、点数の大きい順・台帳に入った順で最大3件（タスク担当の判断、同じ範囲）",
]
