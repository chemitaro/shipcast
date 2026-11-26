package spec

steps: {
	"S-01": {title: "分析のプロンプトとJSONの形", realizes: ["R-01", "R-02"], session: "impl"}
	"S-02": {title: "analyze の関数と頼み直し", realizes: ["R-02", "F-01"], after: ["S-01"], session: "impl"}
	"S-03": {title: "保存", realizes: ["R-03"], after: ["S-02"], session: "impl"}
}

tests: {
	"T-01": {title: "fake の応答から話題ができる", verifies: ["R-01"]}
	"T-02": {title: "1回目が壊れたJSONなら頼み直す", verifies: ["R-02"]}
	"T-03": {title: "2回とも壊れたら失敗として記録する", verifies: ["F-01"]}
}

execution: sessions: {
	spec: {task: "仕様化（起動した側が選んだ値の記録）", model: "Claude Opus 5.5", effort: "この会話の設定"}
	impl: {task: "実装", model: "GPT-6.2 Sol", effort: "medium"}
}
