package spec

schema: "specdock/v1"

assurance: {
	level:  "light"
	reason: "iss-00017 の包み方と道筋の上に、表紙と一覧のMarkdownを組むだけで、影響は2つのページに閉じる。読むだけで日誌を変えず、PRを戻せば元に戻る"
}

purpose: "表紙（全repositoryの最新）と、repositoryごとの日付の一覧を、Markdownで作って同じ包み方で描く。"

requirements: {
	"R-01": {title: "`/` に、repositoryごとの最新の日誌が `:::cards` で並ぶ"}
	"R-02": {title: "`/<repo>/` に、日付と lead が `:::timeline` で新しい順に並ぶ"}
}
