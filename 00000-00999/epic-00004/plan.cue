package spec

slices: {
	"iss-00014": {covers: ["R-01", "F-02", "F-03"], text: "経路の部品と伏せる処理"}
	"iss-00015": {covers: ["R-02", "F-01"], text: "話題へのまとめ", after: ["iss-00014"]}
	"iss-00016": {covers: ["R-03", "R-04", "F-04"], text: "日誌のMarkdownを書く", after: ["iss-00015"]}
}

verification: "`fake` の経路で `shipcast write` が日誌を作る試験が通る。本人の手で、本物の経路（codex と antigravity）で shipcast自身の日誌を1本作る。"
