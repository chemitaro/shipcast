package spec

steps: {
	"S-01": {title: "設定の型と読み込み", realizes: ["R-01", "F-01"], session: "impl"}
	"S-02": {title: "`repo add` と `repo list`", realizes: ["R-02", "R-03", "R-04"], after: ["S-01"], session: "impl"}
}

tests: {
	"T-01": {title: "見本の設定を読み、既定値が補われる", verifies: ["R-01"]}
	"T-02": {title: "SpecDockのないrepositoryは足さない・同じidは二重にしない", verifies: ["R-02"]}
	"T-03": {title: "壊れた設定で、直し方を示して止まる", verifies: ["F-01"]}
	"T-04": {title: "`repo list` が登録した順に示す", verifies: ["R-03"]}
	"T-05": {title: "設定ファイルがないとき、作ってから足す", verifies: ["R-04"]}
}

execution: sessions: {
	spec: {task: "仕様化（起動した側が選んだ値の記録）", model: "Claude Opus 5.5", effort: "この会話の設定"}
	impl: {task: "実装", model: "GPT-6.2 Sol", effort: "medium"}
}
