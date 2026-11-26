package spec

steps: {
	"S-01": {title: "Orca CLIで会話を読む方法を確かめ、出力の見本を置く", realizes: ["R-01"], session: "impl"}
	"S-02": {title: "Orcaのcollector", realizes: ["R-01", "R-02", "F-01"], after: ["S-01"], session: "impl"}
}

tests: {
	"T-01": {title: "見本の出力から、会話がEventになる", verifies: ["R-01"]}
	"T-02": {title: "orcaのCLIがないとき、警告だけで空を返す", verifies: ["F-01"]}
}

execution: sessions: {
	spec: {task: "仕様化（起動した側が選んだ値の記録）", model: "Claude Opus 5.5", effort: "この会話の設定"}
	impl: {task: "実装", model: "GPT-6.2 Sol", effort: "medium"}
}
