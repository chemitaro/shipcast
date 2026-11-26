package spec

design: {
	"D-01": {
		title:     "`shipcast.write`"
		text:      "プロンプト `prompts/write.md`（文体：要約＋読み物、です・ます調。使ってよいタグ：summary、warning、checklist。話題にない事実を書かない）。前付けと `:::metrics` はshipcastが機械で作る。書き手のモデルに渡すのは、話題の骨組み（JSON）だけで、出来事の本文は渡さない。"
		satisfies: ["R-01", "R-02", "F-02"]
	}
	"D-02": {
		title:     "ファイルの置き換え"
		text:      "同じフォルダーの一時ファイルに書き、`os.replace` で置き換える。"
		satisfies: ["F-01"]
	}
	"D-03": {
		title:     "出来事のない日"
		text:      "Eventが0件なら、前付けと1行だけを書く。"
		satisfies: ["R-03"]
	}
	"D-04": {
		title: "組み立ての関数と拡張点"
		text: """
		`build_entry(repo, day, stories, events, body_md, *, extensions) -> str`。

		- `events` から `:::metrics` の数を数える（R-04）。
		- `extensions` は `JournalExtension` の一覧。`JournalExtension` は `render(repo, day, stories, events) -> str | None` を持ち、空でない文字列を末尾に足す（R-05）。既定の一覧は `shipcast.write.EXTENSIONS`（このIssueでは空）。iss-00019 が「発信の芽」をここに登録する。
		"""
		satisfies: ["R-02", "R-04", "R-05"]
	}
}
