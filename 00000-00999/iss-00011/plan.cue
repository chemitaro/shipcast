package spec

steps: {
	"S-01": {title: "collectorの約束と collect のコマンド", realizes: ["R-01"], session: "impl"}
	"S-02": {title: "Gitのcollector", realizes: ["R-02", "R-03", "F-01"], after: ["S-01"], session: "impl"}
}

tests: {
	"T-01": {title: "一時のGitのrepositoryで、その日のcommitとmergeだけが集まる", verifies: ["R-02"]}
	"T-02": {title: "collect の実行で、Eventが状態に保存される", verifies: ["R-01"]}
	"T-03": {title: "Gitでないpathで失敗として記録される", verifies: ["F-01"]}
}

execution: sessions: {
	spec: {task: "仕様化（起動した側が選んだ値の記録）", model: "Claude Opus 5.5", effort: "この会話の設定"}
	impl: {task: "実装", model: "GPT-6.2 Sol", effort: "medium"}
}
