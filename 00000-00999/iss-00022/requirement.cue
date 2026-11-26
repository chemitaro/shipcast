package spec

schema: "specdock/v1"

assurance: {
	level:  "light"
	reason: "手元だけの新しい道具の一部で、PRを戻せば元に戻る"
}

purpose: "`shipcast schedule install|uninstall` で、毎日3時のlaunchdの登録を作り、外せるようにする。"

requirements: {
	"R-01": {title: "`schedule install` が、epic-00007 の D-03 のplistを書き、読み込みのcommandを示す"}
	"R-02": {title: "`schedule uninstall` が、plistを外す"}
	"R-03": {title: "READMEに、`uv tool install` と、外付けvolumeのときの許可の付け方を書く"}
}
