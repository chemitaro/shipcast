package spec

schema: "specdock/v1"

assurance: {
	level:  "standard"
	reason: "下書きを手元に作るだけで投稿はしない（投稿は本人）。日誌への印は書く段の拡張点に足すだけなので、消せば元に戻る"
}

purpose: "おまけ。話題ごとのネタポイントをため、しきい値を超えたら日誌に「発信の芽」の印を付け、Xの投稿の下書きを作れるようにする。"

requirements: {
	"R-01": {
		title: "話題のネタポイントを、repositoryごとにためる"
		acceptance: ["分析が付けた話題の `neta.score` が、まだ使っていない分として加算される"]
	}
	"R-02": {
		title: "たまった分がしきい値（設定の `neta.threshold`、既定6）を超えたら、日誌に「発信の芽」の囲みが出る"
		acceptance: ["囲みに、ポイントの合計と、発信に向く話題の題名が並ぶ"]
	}
	"R-03": {
		title: "`shipcast draft x --repo <id>` で、Xの投稿の下書きが手元にできる"
		acceptance: ["下書きは状態の置き場の `drafts/` にMarkdownで置かれ、使った話題は消化済みになる", "外部へは送らない"]
	}
}
