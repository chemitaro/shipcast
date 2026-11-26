package spec

slices: {
	"iss-00011": {covers: ["R-01", "R-04", "F-02"], text: "Gitの収集と、collectorの約束と `shipcast collect`"}
	"iss-00012": {covers: ["R-02"], text: "SpecDockの収集"}
	"iss-00013": {covers: ["R-03", "F-01"], text: "Orcaの収集（任意）", after: ["iss-00012"]}
}

verification: "shipcast自身のrepositoryで `shipcast collect --repo shipcast --date <今日>` を動かし、3つの出所のEventが状態に入る（Orcaは動いていれば）。"
