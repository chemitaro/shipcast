package spec

design: {
	"D-01": {title: "`shipcast.analyze.analyze(events, route) -> list[Story]`", text: "プロンプト `prompts/analyze.md`：出来事の一覧（JSON）、話題のJSONの形、ネタポイントの基準（変化の大きさ、読者への価値、見せやすさ）。", satisfies: ["R-01", "R-02", "F-01"]}
	"D-02": {title: "保存", text: "`Store.save_stories`。", satisfies: ["R-03"]}
}
