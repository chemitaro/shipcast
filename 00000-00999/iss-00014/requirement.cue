package spec

schema: "specdock/v1"

assurance: {
	level:  "light"
	reason: "手元だけの新しい道具の一部で、PRを戻せば元に戻る"
}

purpose: "分析と書き手のモデルを、設定の経路の名前で呼び分ける部品と、伏せる処理を作る。"

requirements: {
	"R-01": {title: "経路 codex・antigravity・claude・fake を、設定の `models.analyst` と `models.writer` から選んで呼べる"}
	"R-02": {title: "呼ぶ前に必ず `redact()` を通す"}
	"R-03": {title: "Codexのより安いモデル（Luna など）の名前を確かめ、設定の見本に書く"}
}

failures: {
	"F-01": {title: "エージェントの中では antigravity の経路を呼ばずに止まる（epic-00004 の F-03）"}
	"F-02": {title: "外部のコマンドが失敗・時間切れのときは、理由を持った例外にする"}
}
