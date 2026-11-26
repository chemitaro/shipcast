package spec

steps: {
	"S-01": {title: "包む関数", realizes: ["R-01"], session: "impl"}
	"S-02": {title: "配信の部品と道筋", realizes: ["R-01", "R-02", "F-01", "F-02"], after: ["S-01"], session: "impl"}
	"S-03": {title: "READMEの手順", realizes: ["R-03"], session: "impl"}
}

tests: {
	"T-01": {title: "`</script>` を含むMarkdownも壊れずに包まれる", verifies: ["R-01"]}
	"T-02": {title: "見本の日誌のページとds.cssが200で返る", verifies: ["R-01", "R-02"]}
	"T-03": {title: "`..` のpathが404になる", verifies: ["F-02"]}
}

execution: sessions: {
	spec: {task: "仕様化（起動した側が選んだ値の記録）", model: "Claude Opus 5.5", effort: "この会話の設定"}
	impl: {task: "実装", model: "GPT-6.2 Sol", effort: "medium"}
}
