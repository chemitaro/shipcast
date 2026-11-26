package spec

steps: {
	"S-01": {title: "plistの生成と install・uninstall", realizes: ["R-01", "R-02"], session: "impl"}
	"S-02": {title: "READMEの手順", realizes: ["R-03"], session: "impl"}
}

tests: {
	"T-01": {title: "plistに3時、shipcastの絶対path、ログの置き場が入る", verifies: ["R-01"]}
}

execution: sessions: {
	spec: {task: "仕様化（起動した側が選んだ値の記録）", model: "Claude Opus 5.5", effort: "この会話の設定"}
	impl: {task: "実装", model: "GPT-6.2 Sol", effort: "medium"}
}
