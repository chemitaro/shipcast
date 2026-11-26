package spec

steps: {
	"S-01": {title: "`uv init --package` 相当の骨組みと pyproject を作る", realizes: ["R-02"], session: "impl"}
	"S-02": {title: "CLIの入口と下位のコマンドの登録", realizes: ["R-01"], after: ["S-01"], session: "impl"}
	"S-03": {title: "`AGENTS.md` の「Gitと検証」に検証のcommandを書く", realizes: ["R-03"], after: ["S-01"], session: "impl"}
}

tests: {
	"T-01": {title: "`--help` に7つの下位のコマンドが出る", verifies: ["R-01"]}
}

execution: sessions: {
	spec: {task: "仕様化（起動した側が選んだ値の記録）", model: "Claude Opus 5.5", effort: "この会話の設定"}
	impl: {task: "実装", model: "GPT-6.2 Sol", effort: "medium"}
}
