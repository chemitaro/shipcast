package spec

goal: "経路の部品（送信の境界）を先に固め、見本の出来事で話題のまとめと日誌の組み立てを作り、`shipcast write` で日誌のファイルができるようにする。"

slices: {
	"iss-00014": {covers: ["R-01", "F-02", "F-03"], text: "経路の部品、伏せる処理、エージェントの中の守り（strict）。E1の iss-00009 の後すぐに始められる"}
	"iss-00015": {covers: ["R-02", "F-01"], text: "話題へのまとめ（standard）。実データのため、E2の iss-00011・iss-00012 も待つ", after: ["iss-00014"]}
	"iss-00016": {covers: ["R-03", "R-04", "R-05", "R-06", "F-04"], text: "日誌のMarkdownを書く、`:::metrics` の events、拡張点（standard）", after: ["iss-00015"]}
}

verification: "`fake` の経路で `shipcast write` が日誌を作る試験が通る。本物の経路（codex と antigravity）で shipcast自身の日誌を1本作るのは、本人の手動の実行だけ（エージェントは `agy` を呼ばない）。"
