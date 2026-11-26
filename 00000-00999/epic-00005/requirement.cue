package spec

schema: "specdock/v1"

assurance: {
	level:  "standard"
	reason: "手元の配信だけで、外へは公開しない。配信を止めれば元に戻る"
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
	"F-01": {title: "デザインシステムのファイルが見つからないときは、場所の設定の仕方を示して止まる"}
	"F-02": {title: "日誌の置き場の外のファイルを返さない（pathの `..` を拒む）"}
}
