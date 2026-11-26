package spec

schema: "specdock/v1"

assurance: {
	level:  "light"
	reason: "iss-00016 の拡張点に囲みを1つ足し、台帳に点数を足すだけで、外へは何も送らない。誤っても印が出ない・出すぎるだけで、PRを戻せば元に戻る"
}

purpose: "ネタポイントの台帳と、日誌の「発信の芽」の印を作る。"

requirements: {
	"R-01": {title: "話題を保存するときに、そのネタポイントを台帳に加える"}
	"R-02": {title: "未消化の合計がしきい値以上なら、日誌に `:::tip 発信の芽` の囲みを足す"}
}
