package spec

schema: "specdock/v1"

assurance: {
	level:  "light"
	reason: "手元だけの新しい道具の一部で、PRを戻せば元に戻る"
}

purpose: "`shipcast serve` で、日誌のMarkdownをデザインシステムで描くページとして返す。"

requirements: {
	"R-01": {title: "`/<repo>/<日付>` で、日誌のMarkdownを epic-00005 の D-01 の形に包んで返す"}
	"R-02": {title: "`/_ds/` で、デザインシステムのファイル（ds.css、ds.js、vendor）を返す"}
	"R-03": {title: "既定で 127.0.0.1 に立ち、READMEにTailscaleでの公開の手順を書く"}
}

failures: {
	"F-01": {title: "デザインシステムが見つからないときは、設定の仕方を示して止まる"}
	"F-02": {title: "`..` を含むpathや置き場の外は404にする"}
}
