package spec

schema: "specdock/v1"

assurance: {
	level:  "standard"
	reason: "Event・Story・Entryの型とSQLiteの表は、収集・執筆・配信・夜の実行の全部が読む共通のデータの約束になる。誤ると後続の全Issueに波及するが、状態は手元のSQLiteだけで、消して集め直せば回復できる"
}

purpose: "Event・Story・Entryの型と、SQLiteの状態の置き場を作る。ほかのIssueはここを読み込む。"

requirements: {
	"R-01": {
		title: "Event・Story・Entryの型（epic-00002 の D-03）が `shipcast.model` にあり、JSONと行き来できる"
		acceptance: ["3つの型をJSONにして戻すと、元と等しい", "JSONには `schema: 1` が入る"]
	}
	"R-02": {
		title: "状態の置き場 `shipcast.state` が、出来事・話題・日誌・実行・ネタポイントを保存し、読み出せる"
		acceptance: ["`Store(state_dir)` が `state.sqlite3` と5つの表を作る", "保存したEventを `events_for(repo, date)` で、時刻の順に読み出せる"]
	}
	"R-03": {
		title: "同じ出来事を二度保存しても1件のまま"
		acceptance: ["Eventのidは、出所（source）と元のID（SHAなど）から決まる"]
	}
	"R-04": {
		title: "日誌のパスと前付けの契約（epic-00002 の D-05）が `shipcast.model` にある"
		acceptance: [
			"`journal_path(journal_dir, \"shipcast\", date(2026, 11, 26))` が `<journal_dir>/shipcast/2026/2026-11-26.md` を返す",
			"`write_frontmatter` で書いて `read_frontmatter` で読むと元に戻り、必須の項目が欠けると項目を名指して失敗する",
		]
	}
}
