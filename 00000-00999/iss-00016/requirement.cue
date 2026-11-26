package spec

schema: "specdock/v1"

assurance: {
	level:  "standard"
	reason: "日誌のMarkdownの形（epic-00002 の日誌の契約）を実際に作る部品で、配信（epic-00005）とおまけ（iss-00019）がこの形を読む。誤ると日誌が読めなくなるが、出来事と話題は状態に残るので、PRを戻して書き直せば回復できる"
}

purpose: "話題から、書き手のモデルで日誌の本文を書き、epic-00002 の日誌の契約（パスと前付け）と epic-00004 の D-04 の形のMarkdownのファイルを作る。`shipcast write` のコマンド。"

requirements: {
	"R-01": {
		title: "`shipcast write --repo <id> --date <日付>` が、集める→まとめる→書くを通して、日誌のファイルを作る"
		acceptance: ["fake の経路で、`<journal_dir>/<repo>/<年>/<YYYY-MM-DD>.md` ができる", "前付けに `title`・`lead`・`date`・`repo`・`analyst`・`writer`・`generated_at` が入る"]
	}
	"R-02": {
		title: "前付け・要約・知っておくべきこと・物語・待っていること・数字の順のMarkdownになる"
		acceptance: ["使うタグは summary・warning・checklist・metrics だけで、順は epic-00004 の D-04 のとおり"]
	}
	"R-03": {
		title: "出来事のない日は、モデルを呼ばずに短い日誌にする"
		acceptance: ["Eventが0件の日は、経路の呼び出しが0回で、前付けと「大きな動きはありませんでした。」の1行になる"]
	}
	"R-04": {
		title: "`:::metrics` の数字は、出来事（events）から機械で数える"
		text:  "書き手のモデルには数えさせない。組み立ての関数は、話題（stories）と一緒にその日の出来事（events）を入力に受け取る。"
		acceptance: ["merge の数、commit の数、閉じたScopeの数、開いている本人待ちのtodoの数が、見本の出来事の数と一致する"]
	}
	"R-05": {
		title: "日誌の末尾に囲みを足す拡張点がある（iss-00019 の「発信の芽」が使う）"
		text:  "拡張点は、日誌の組み立ての最後に呼ばれ、Markdownの囲みの文字列を返す部品の一覧。このIssueでは一覧は空で、日誌は変わらない。"
		acceptance: ["試験用の部品を1つ登録すると、その文字列が `:::metrics` の後に足される", "登録がないときは、足す囲みがない"]
	}
}

failures: {
	"F-01": {title: "書き手が失敗したら、前のファイルを壊さず、失敗として記録する"}
	"F-02": {title: "書き手には骨組みだけを渡し、創作を禁じる"}
}
