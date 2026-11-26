package spec

design: {
	"D-01": {title: "`shipcast.write`", text: "プロンプト `prompts/write.md`（文体：要約＋読み物、です・ます調。使ってよいタグ：summary、warning、checklist、metrics。話題にない事実を書かない）。前付けと数字はshipcastが機械で作る。", satisfies: ["R-01", "R-02", "F-02"]}
	"D-02": {title: "ファイルの置き換え", text: "同じフォルダーの一時ファイルに書き、`os.replace` で置き換える。", satisfies: ["F-01"]}
	"D-03": {title: "出来事のない日", text: "Eventが0件なら、前付けと1行だけを書く。", satisfies: ["R-03"]}
}
