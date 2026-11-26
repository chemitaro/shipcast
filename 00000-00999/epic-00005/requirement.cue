package spec

schema: "specdock/v1"

assurance: {
	level:  "strict"
	reason: "tailnetの端末から読まれる手元のHTTPの配信は、セキュリティの境界になる（子の iss-00017 が strict）。パスの検査やエスケープを誤ると、置き場の外のファイルが返る、またはページの中で日誌に混ざった文字列が動き、外へ出た内容は取り消せない"
}

purpose: "日誌のMarkdownのファイルを、配信のときにデザインシステムでWebページにして読めるようにする。HTMLは保存しない。"

requirements: {
	"R-01": {
		title: "各日の日誌が、デザインシステムで描かれたWebページとして読める"
		acceptance: ["`shipcast serve` の `/<repo>/<日付>` で、タグ（summary、warning など）が部品として描かれる"]
	}
	"R-02": {
		title: "表紙と、repositoryごとの日付の一覧がある"
		acceptance: ["`/` に全repositoryの最新の日誌がカードで並ぶ", "`/<repo>/` に日付の一覧が新しい順に並ぶ"]
	}
	"R-03": {
		title: "Tailscaleで、tailnetの端末から読める"
		acceptance: ["配信は既定で 127.0.0.1 に立ち、READMEに、本人がTailscaleで公開する1回の手順がある"]
	}
}

failures: {
	"F-01": {
		title:    "デザインシステムのファイルが見つからないときは、場所の設定の仕方を示して止まる"
		impact:   "部品の描かれない崩れたページになり、原因が分からない"
		recovery: "起動のときに確かめ、`serve.design_system_dir` の書き方を示して止まる。本人が設定を直して立ち上げ直す"
	}
	"F-02": {
		title:    "日誌の置き場の外のファイルを返さない（`..`、符号化した `%2e%2e`・`%2f`、置き場の外へのsymlinkを拒む）"
		impact:   "設定・鍵・ほかのファイルが、tailnetの端末に返る"
		recovery: "pathを解決してから置き場の中かを確かめ、外なら読まずに404。返ってしまったら配信を止め、見えた秘密を作り直す"
	}
	"F-03": {
		title:    "日誌のMarkdownの中の `</script` と `<!--` で、包んだ `<script>` が途中で閉じたり崩れたりしない"
		impact:   "日誌の本文の後ろがHTMLとして動き、ページの中でscriptが動きうる"
		recovery: "包む関数の1か所で `</script` を `<\\/script`（ds.js が戻す）に、`<!--` を `<\\!--` に置き換える"
	}
	"F-04": {
		title:    "日誌の本文に混ざった生のHTMLのscriptやイベントの属性は動かない"
		impact:   "`<img onerror=…>` などが動き、同じ配信のほかの日誌を読まれうる"
		recovery: "すべての応答にCSP（インラインのscriptを許さない）と `X-Content-Type-Options: nosniff` を付け、デザインシステムがその下で描けることを実際のブラウザーで確かめる"
	}
}
