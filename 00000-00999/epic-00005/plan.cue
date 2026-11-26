package spec

slices: {
	"iss-00017": {covers: ["R-01", "R-03", "F-01", "F-02"], text: "配信と日誌のページ"}
	"iss-00018": {covers: ["R-02"], text: "表紙と一覧", after: ["iss-00017"]}
}

verification: "見本の日誌（tests/fixtures）で `shipcast serve` を立て、ブラウザーで表紙・一覧・各日が描かれ、スマートフォンの幅で横にはみ出さない。"
