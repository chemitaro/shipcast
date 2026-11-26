package spec

steps: {
	"S-01": {title: "型とJSONの行き来", realizes: ["R-01", "R-03"], session: "impl"}
	"S-02": {title: "SQLiteの置き場", realizes: ["R-02", "R-03"], after: ["S-01"], session: "impl"}
}

tests: {
	"T-01": {title: "型をJSONにして戻すと同じになる", verifies: ["R-01"]}
	"T-02": {title: "保存して読み出せる", verifies: ["R-02"]}
	"T-03": {title: "同じ出来事の二度目の保存で件数が増えない", verifies: ["R-03"]}
}

execution: sessions: {
	spec: {task: "仕様化（起動した側が選んだ値の記録）", model: "Claude Opus 5.5", effort: "この会話の設定"}
	impl: {task: "実装", model: "GPT-6.2 Sol", effort: "medium"}
}
