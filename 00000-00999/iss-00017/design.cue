package spec

goals: [
	"パスの検査、エスケープ、応答のヘッダーを、それぞれ1か所の関数にし、単独で試験できるようにする",
]

design: {
	"D-01": {
		title: "包む関数 `wrap_markdown(md, title) -> str`（画面の部分）"
		text: """
		epic-00005 の D-01 の薄い形。`title` はHTMLとしてエスケープする。本文は F-03 の置き換えをしてから `ds-source` に入れる。ページの見た目（`<head>` の構成、表紙・一覧と共通の枠）は画面のデザインの部分で、Opus 5.5 が直接実装する。
		"""
		satisfies: ["R-01", "F-03"]
	}
	"D-02": {
		title: "配信の部品 `shipcast.serve`（ロジックの部分）"
		text: """
		- 標準の `http.server.ThreadingHTTPServer`。道筋は `/<repo>/<YYYY-MM-DD>`、`/_ds/<file>`（表紙 `/` と一覧 `/<repo>/` は iss-00018）。`GET` と `HEAD` だけを受ける。
		- `resolve_inside(root, rel) -> Path | None`：URLを復号した後に `Path.resolve()` し、`root` の中でなければ `None`（F-02）。日誌とデザインシステムの両方で使う。
		- `security_headers()`：F-04 のヘッダー。すべての応答（404を含む）に付ける。
		- 起動のときに、デザインシステムの置き場を確かめる（F-01）。置き場は `serve.design_system_dir`、空なら登録したrepositoryの `spec-dock/design-system/`。
		"""
		satisfies: ["R-01", "R-02", "F-01", "F-02", "F-04"]
	}
	"D-03": {
		title:     "README"
		text:      "読み方とTailscaleの手順（epic-00005 の D-04）。shipcastはTailscaleの設定を変えない。"
		satisfies: ["R-03"]
	}
}

risks: [
	"デザインシステムが将来インラインのscriptや外部の別のCDNを使うと、F-04 の方針で描けなくなる。試験とブラウザーでの確かめで気づけるようにする",
]
