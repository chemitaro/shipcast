package spec

goal: "見本の日誌（tests/fixtures）を使い、E2・E3を待たずに、日誌のページ・表紙・一覧を安全に配信できるようにする。"

slices: {
	"iss-00017": {covers: ["R-01", "R-03", "F-01", "F-02", "F-03", "F-04"], text: "配信と日誌のページ、防御の1か所（strict）。パスの検査・ヘッダー・配信はCodex、ページの枠と見た目は Opus 5.5"}
	"iss-00018": {covers: ["R-02"], text: "表紙と一覧（light）。画面なので Opus 5.5 が直接実装する", after: ["iss-00017"]}
}

verification: "見本の日誌（tests/fixtures）で `shipcast serve` を立て、実際のブラウザーで表紙・一覧・各日が描かれ、CSPの下で部品と図が描け、スマートフォンの幅（390px）で横にはみ出さない。"

// 本人の決定 20：画面のデザイン・レイアウト・表示の部分は、GPT-6.2 Sol に頼まず Opus 5.5 が直接実装する。
ui_implementation: {
	who:   "Claude Opus 5.5（各Issueの plan.cue の `impl-ui` のセッション。strict の iss-00017 は high、light の iss-00018 は medium）"
	scope: "ページの枠（`wrap_markdown` の `<head>` の構成）、表紙の `:::cards` と一覧の `:::timeline` の組み方、見た目の確かめ（実際のブラウザー、390px）"
	not:   "パスの検査、応答のヘッダー、HTTPの道筋は、テストで確かめられるロジックなので Codex（GPT-6.2 Sol / medium）が実装する"
}

execution: sessions: {
	impl: {task: "ロジック（パスの検査、ヘッダー、配信）", model: "GPT-6.2 Sol", effort: "medium", rationale: "方針§2のテストで確かめられる実装"}
	"impl-ui": {task: "画面のデザイン・レイアウト・表示", model: "Claude Opus 5.5", effort: "iss-00017 は high、iss-00018 は medium", rationale: "本人の決定 20、方針§2のフロントエンドの行"}
}
