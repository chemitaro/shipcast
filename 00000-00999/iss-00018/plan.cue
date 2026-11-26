package spec

steps: {
	"S-01": {title: "前付けの読み取り", realizes: ["R-01", "R-02"], session: "impl"}
	"S-02": {title: "表紙と一覧のMarkdownと道筋", realizes: ["R-01", "R-02"], after: ["S-01"], session: "impl"}
}

tests: {
	"T-01": {title: "見本の置き場から、表紙と一覧のMarkdownが期待どおりにできる", verifies: ["R-01", "R-02"]}
}

execution: sessions: {
	spec: {task: "仕様化（起動した側が選んだ値の記録）", model: "Claude Opus 5.5", effort: "この会話の設定"}
	impl: {task: "実装", model: "GPT-6.2 Sol", effort: "medium"}
}
