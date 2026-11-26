package spec

schema: "specdock/v1"

assurance: {
	level:  "light"
	reason: "手元だけの新しい道具の一部で、PRを戻せば元に戻る"
}

purpose: "Event・Story・Entryの型と、SQLiteの状態の置き場を作る。ほかのIssueはここを読み込む。"

requirements: {
	"R-01": {title: "Event・Story・Entryの型（epic-00002 の D-03）が `shipcast.model` にあり、JSONと行き来できる"}
	"R-02": {title: "状態の置き場 `shipcast.state` が、出来事・話題・日誌・実行・ネタポイントを保存し、読み出せる"}
	"R-03": {
		title: "同じ出来事を二度保存しても1件のまま"
		acceptance: ["Eventのidは、出所（source）と元のID（SHAなど）から決まる"]
	}
}
