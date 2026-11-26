package spec

goal: "ネタポイントがたまったことを日誌で知らせ、本人が投稿するときの下書きを手元に作る。shipcastは投稿しない。"

slices: {
	"iss-00019": {covers: ["R-01", "R-02"], text: "台帳と日誌の印（light）。E3の iss-00016 の拡張点を使うので、その後に始める"}
	"iss-00020": {covers: ["R-03"], text: "Xの下書き（light）。投稿はしない", after: ["iss-00019"]}
}

verification: "fake の経路で、ポイントが閾値を超えた日の日誌に印が出て、`draft x` で下書きができる。"
