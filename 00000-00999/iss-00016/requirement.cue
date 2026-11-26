package spec

schema: "specdock/v1"

assurance: {
	level:  "light"
	reason: "手元だけの新しい道具の一部で、PRを戻せば元に戻る"
}

purpose: "話題から、書き手のモデルで日誌の本文を書き、epic-00004 の D-04 の形のMarkdownのファイルを作る。`shipcast write` のコマンド。"

requirements: {
	"R-01": {title: "`shipcast write --repo <id> --date <日付>` が、集める→まとめる→書くを通して、日誌のファイルを作る"}
	"R-02": {title: "前付け・要約・知っておくべきこと・物語・待っていること・数字の順のMarkdownになる"}
	"R-03": {title: "出来事のない日は、モデルを呼ばずに短い日誌にする"}
}

failures: {
	"F-01": {title: "書き手が失敗したら、前のファイルを壊さず、失敗として記録する"}
	"F-02": {title: "書き手には骨組みだけを渡し、創作を禁じる"}
}
