package spec

design: {
	"D-01": {
		title: "ページの包み方"
		text: """
		SpecDockの説明資料と同じ薄い形で、Markdownを包んで返す。

		```html
		<!doctype html><html lang="ja"><head><meta charset="utf-8">
		<meta name="viewport" content="width=device-width, initial-scale=1">
		<title>…</title>
		<link rel="stylesheet" href="/_ds/ds.css">
		<script type="text/markdown" id="ds-source">（日誌のMarkdown。`</script` は `<\\/script` に置き換える）</script>
		<script src="/_ds/ds.js"></script></head><body></body></html>
		```
		`/_ds/` は、設定の `serve.design_system_dir`（空なら登録したrepositoryの `spec-dock/design-system/`）のファイルを返す。デザインシステムをこのrepositoryに写さない。
		"""
		satisfies: ["R-01", "F-01"]
	}
	"D-02": {
		title:     "表紙と一覧もMarkdownで作る"
		text:      "表紙は `:::cards`（repositoryごとに最新の日誌の題名・lead・日付、`href` でその日へ）。一覧は `:::timeline`（日付と lead）。同じ包み方で描く。"
		satisfies: ["R-02"]
	}
	"D-03": {
		title:     "配信の部品"
		text:      "標準の `http.server.ThreadingHTTPServer`。道筋は `/`、`/<repo>/`、`/<repo>/<YYYY-MM-DD>`、`/_ds/<file>`。pathは日誌の置き場の中に解決できるものだけを返す。"
		satisfies: ["R-01", "R-02", "F-02"]
	}
	"D-04": {
		title:     "Tailscaleでの公開"
		text:      "shipcastはTailscaleの設定を変えない。本人が1回だけ `tailscale serve --bg 8765`（または本人の `tailscale-html-preview` の仕組み）を実行する手順をREADMEに書く。"
		satisfies: ["R-03"]
	}
}
