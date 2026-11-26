package spec

steps: {
	"S-01": {title: "台帳への加算", realizes: ["R-01"], session: "impl"}
	"S-02": {title: "日誌への印", realizes: ["R-02"], after: ["S-01"], session: "impl"}
}

tests: {
	"T-01": {title: "話題の保存でポイントが加わる", verifies: ["R-01"]}
	"T-02": {title: "しきい値を超えた日にだけ囲みが出る", verifies: ["R-02"]}
}

execution: sessions: {
	spec: {task: "仕様化（起動した側が選んだ値の記録）", model: "Claude Opus 5.5", effort: "この会話の設定"}
	impl: {task: "実装", model: "GPT-6.2 Sol", effort: "medium"}
}
