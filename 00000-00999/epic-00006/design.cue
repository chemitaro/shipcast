package spec

design: {
	"D-01": {title: "ネタポイントの台帳", text: "`neta_ledger`（話題のid、点数、消化済みか）。`neta_balance(repo)` は未消化の合計。", satisfies: ["R-01"]}
	"D-02": {title: "日誌の印", text: "書く段の拡張点（epic-00004 の D-05、iss-00016 の `JournalExtension`）に部品を1つ登録する。残高がしきい値以上なら `:::tip 発信の芽（ネタポイント N）` と話題の題名を返し、未満なら何も足さない。書く段の中は書き換えない。", satisfies: ["R-02"]}
	"D-03": {title: "Xの下書き", text: "未消化の話題から上位を選び、書き手のモデルで280字（日本語は140字程度）以内の本文と、ハッシュタグの案を作る。`drafts/<repo>/<日付>-x.md`。", satisfies: ["R-03"]}
}
