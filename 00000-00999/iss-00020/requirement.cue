package spec

schema: "specdock/v1"

assurance: {
	level:  "light"
	reason: "手元だけの新しい道具の一部で、PRを戻せば元に戻る"
}

purpose: "`shipcast draft x` で、Xの投稿の下書きを手元に作る。投稿はしない。"

requirements: {
	"R-01": {title: "未消化の話題から、Xの本文（日本語で140字程度）とハッシュタグの案を、書き手のモデルで作る"}
	"R-02": {title: "下書きを `drafts/<repo>/<日付>-x.md` に置き、使った話題を消化済みにする"}
}
