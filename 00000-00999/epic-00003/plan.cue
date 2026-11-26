package spec

slices: {
	"iss-00011": {covers: ["R-01", "R-04", "F-02"], text: "collectorの共通の約束（`shipcast.collect.base`）、`shipcast collect`、Gitの収集。最初に入れる"}
	"iss-00012": {covers: ["R-02"], text: "SpecDockの収集（`spec-dock` と `gh issue list` を読むだけ）", after: ["iss-00011"]}
	"iss-00013": {covers: ["R-03", "F-01"], text: "Orcaの収集（任意。`orca agent list` と `orca agent read`）", after: ["iss-00012"]}
}

goal: "Gitの収集と共通の約束を先にmainへ入れ、SpecDockとOrcaのcollectorを足して、3つの出所の出来事を1つの状態に集める。"

verification: "shipcast自身のrepositoryで `shipcast collect --repo shipcast --date <今日>` を動かし、3つの出所のEventが状態に入る（Orcaは動いていれば）。"
