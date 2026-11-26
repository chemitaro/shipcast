package spec

steps: {
	"S-01": {title: "パスの検査とヘッダーの関数", realizes: ["F-02", "F-04"], session: "impl"}
	"S-02": {title: "配信の部品と道筋、デザインシステムの確かめ", realizes: ["R-02", "F-01", "F-02", "F-04"], after: ["S-01"], session: "impl"}
	"S-03": {title: "包む関数とページの枠（画面の部分）", realizes: ["R-01", "F-03"], after: ["S-02"], session: "impl-ui"}
	"S-04": {title: "READMEの手順と、ブラウザーでの描画の確かめ", realizes: ["R-03", "F-04"], after: ["S-03"], session: "impl-ui"}
}

tests: {
	"T-01": {title: "`</script>`・`</SCRIPT >`・`<!--<script>` を含むMarkdownでも、ds-source が包んだ閉じのところで閉じる", verifies: ["F-03"]}
	"T-02": {title: "見本の日誌のページとds.cssが200で返る", verifies: ["R-01", "R-02"]}
	"T-03": {title: "`..`・`%2e%2e`・`%2f`・置き場の外へのsymlinkのpathが404になり、中身を読まない", verifies: ["F-02"]}
	"T-04": {title: "デザインシステムがないとき、設定の仕方を示して止まる", verifies: ["F-01"]}
	"T-05": {title: "すべての応答（404を含む）にCSPとnosniffのヘッダーがある", verifies: ["F-04"]}
	"T-06": {title: "既定の待ち受けが 127.0.0.1 で、READMEにTailscaleの手順がある", verifies: ["R-03"]}
	"T-07": {title: "実際のブラウザーで、CSPの下で見本の日誌の部品と図が描け、`<img onerror>` が動かない", verifies: ["R-01", "F-04"]}
}

execution: sessions: {
	spec: {task: "仕様化（起動した側が選んだ値の記録）", model: "Claude Opus 5.5", effort: "この会話の設定"}
	impl: {task: "実装（ロジック：パスの検査、ヘッダー、配信）", model: "GPT-6.2 Sol", effort: "medium"}
	"impl-ui": {task: "実装（画面のデザイン・ページの枠・README）。本人の方針で Opus 5.5 が直接実装する", model: "Claude Opus 5.5", effort: "high"}
}
