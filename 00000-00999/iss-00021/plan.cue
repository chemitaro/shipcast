package spec

steps: {
	"S-01": {title: "run のコマンドと記録", realizes: ["R-01", "R-02"], session: "impl"}
	"S-02": {title: "lock と TCCの見分け", realizes: ["F-01", "F-02"], after: ["S-01"], session: "impl"}
	"S-03": {title: "再実行の確かめ", realizes: ["R-03"], after: ["S-01"], session: "impl"}
}

tests: {
	"T-01": {title: "2つのrepositoryのうち1つが失敗しても、もう1つの日誌ができる", verifies: ["R-01", "R-02"]}
	"T-02": {title: "2回実行してもEventが増えない", verifies: ["R-03"]}
	"T-03": {title: "lockが取れないときは何もせずに終わる", verifies: ["F-01"]}
}

execution: sessions: {
	spec: {task: "仕様化（起動した側が選んだ値の記録）", model: "Claude Opus 5.5", effort: "この会話の設定"}
	impl: {task: "実装", model: "GPT-6.2 Sol", effort: "medium"}
}
