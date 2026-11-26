package spec

design: {
	"D-01": {title: "台帳と残高", text: "epic-00006 の D-01。話題の保存（iss-00015 の `Store.save_stories`）の後に、未記録の話題の `neta.score` を `neta_ledger` に足す。同じ話題は二度足さない。", satisfies: ["R-01"]}
	"D-02": {title: "印", text: "epic-00006 の D-02。iss-00016 の拡張点（`JournalExtension`）を1つ作り、`shipcast.write.EXTENSIONS` に登録する。`render` は残高がしきい値以上のとき `:::tip 発信の芽（ネタポイント N）` と話題の題名を返し、未満なら `None` を返す。", satisfies: ["R-02"]}
}
