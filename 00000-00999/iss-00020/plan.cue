package spec

steps: {
	"S-01": {title: "Xのプロンプトと draft のコマンド", realizes: ["R-01", "R-02"], session: "impl"}
}

tests: {
	"T-01": {title: "fake の経路で下書きができ、話題が消化済みになる", verifies: ["R-01", "R-02"]}
}

execution: sessions: {
	spec: {task: "仕様化（起動した側が選んだ値の記録）", model: "Claude Opus 5.5", effort: "この会話の設定"}
	impl: {task: "実装", model: "GPT-6.2 Sol", effort: "medium"}
}
