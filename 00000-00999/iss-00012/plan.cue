package spec

steps: {
	"S-01": {title: "実際の `scope list --json` と `todo list --json` の出力を確かめ、見本として tests/fixtures に置く", realizes: ["R-03"], session: "impl"}
	"S-02": {title: "SpecDockのcollector", realizes: ["R-01", "R-02"], after: ["S-01"], session: "impl"}
}

tests: {
	"T-01": {title: "見本の出力から、その日のScopeの作成と終了がEventになる", verifies: ["R-01"]}
	"T-02": {title: "見本の出力から、todoがEventになる", verifies: ["R-02"]}
}

execution: sessions: {
	spec: {task: "仕様化（起動した側が選んだ値の記録）", model: "Claude Opus 5.5", effort: "この会話の設定"}
	impl: {task: "実装", model: "GPT-6.2 Sol", effort: "medium"}
}
