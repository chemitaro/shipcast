package spec

steps: {
	"S-01": {title: "書き手のプロンプト", realizes: ["R-02", "F-02"], session: "impl"}
	"S-02": {title: "日誌の組み立てと置き換え", realizes: ["R-02", "F-01"], after: ["S-01"], session: "impl"}
	"S-03": {title: "write のコマンド（collect と analyze をつなぐ）", realizes: ["R-01", "R-03"], after: ["S-02"], session: "impl"}
}

tests: {
	"T-01": {title: "fake の経路で、決まった形の日誌ができる", verifies: ["R-01", "R-02"]}
	"T-02": {title: "出来事のない日は1行の日誌になり、モデルを呼ばない", verifies: ["R-03"]}
	"T-03": {title: "書き手が失敗しても前のファイルが残る", verifies: ["F-01"]}
}

execution: sessions: {
	spec: {task: "仕様化（起動した側が選んだ値の記録）", model: "Claude Opus 5.5", effort: "この会話の設定"}
	impl: {task: "実装", model: "GPT-6.2 Sol", effort: "medium"}
}
