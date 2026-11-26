package spec

goal: "ハッカソン（2時間）の中で、shipcast自身のrepositoryの日誌がWebページで読めるところまで、段階を見せながら作る。"

slices: {
	"epic-00002": {
		covers: ["R-01", "R-07"]
		text:   "全Epicが使う約束（CLI、設定、データの形、状態）。最初に作る"
	}
	"epic-00003": {
		covers: ["R-02", "F-03"]
		text:   "Git・SpecDock・Orcaの収集"
		after: ["epic-00002"]
	}
	"epic-00004": {
		covers: ["R-01", "R-03", "F-01", "F-02", "F-04"]
		text:   "分析と執筆。日誌のMarkdownを書く"
		after: ["epic-00002", "epic-00003"]
	}
	"epic-00005": {
		covers: ["R-04"]
		text:   "日誌の配信。E1の後、見本の日誌を使ってE2・E3と並行に作れる"
		after: ["epic-00002"]
	}
	"epic-00006": {
		covers: ["R-06"]
		text:   "おまけ。ネタポイントとXの下書き"
		after: ["epic-00004"]
	}
	"epic-00007": {
		covers: ["R-05"]
		text:   "夜の自動実行"
		after: ["epic-00004", "epic-00005"]
	}
}

verification: "shipcast自身を登録し、`shipcast run --date <今日>` で日誌ができ、`shipcast serve` で表紙・一覧・その日の日誌が読めること。"
exit:         "ハッカソンでは、E1〜E4が動けば成功。E5・E6は時間があれば。"

execution: sessions: {
	spec: {task: "仕様化（起動した側が選んだ値の記録）", model: "Claude Opus 5.5", effort: "この会話の設定", rationale: "本人との会話の中で統括役が書いた"}
	impl: {task: "Issueの実装（Orcaの作業者）", model: "GPT-6.2 Sol", effort: "medium", rationale: "テストで確かめられる実装の既定（本人の方針）"}
}
