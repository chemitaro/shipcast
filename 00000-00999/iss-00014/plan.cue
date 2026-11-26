package spec

steps: {
	"S-01": {title: "codex・agy・claude の `--help` を確かめる", realizes: ["R-01", "R-03"], session: "impl"}
	"S-02": {title: "経路の部品と fake", realizes: ["R-01", "F-02"], after: ["S-01"], session: "impl"}
	"S-03": {title: "伏せる処理", realizes: ["R-02"], session: "impl"}
	"S-04": {title: "エージェントの中の検出", realizes: ["F-01"], after: ["S-02"], session: "impl"}
}

tests: {
	"T-01": {title: "fake の経路が決まった応答を返す", verifies: ["R-01"]}
	"T-02": {title: "トークンや鍵が伏せられる", verifies: ["R-02"]}
	"T-03": {title: "CLAUDECODE=1 のとき antigravity が止まる", verifies: ["F-01"]}
}

execution: sessions: {
	spec: {task: "仕様化（起動した側が選んだ値の記録）", model: "Claude Opus 5.5", effort: "この会話の設定"}
	impl: {task: "実装", model: "GPT-6.2 Sol", effort: "medium"}
}
