package spec

schema: "specdock/v1"

assurance: {
	level:  "strict"
	reason: "手元のHTTPの配信は、tailnetの端末から読まれるセキュリティの境界になる。パスの検査を誤ると日誌の置き場の外のファイル（設定や鍵）を返し、`</script>` の扱いや本文の生のHTMLを誤ると、日誌に混ざった文字列がページの中で動く。外へ出た内容は取り消せないので回復が難しい"
}

purpose: "`shipcast serve` で、日誌のMarkdownをデザインシステムで描くページとして返す。表紙と一覧（iss-00018）は、ここの包み方と道筋を使う。"

requirements: {
	"R-01": {
		title: "`/<repo>/<YYYY-MM-DD>` で、日誌のMarkdownを epic-00005 の D-01 の形に包んで返す"
		acceptance: [
			"見本の日誌で200が返り、本文が `<script type=\"text/markdown\" id=\"ds-source\">` の中にあり、`/_ds/ds.css` と `/_ds/ds.js` を読む",
			"`<title>` に前付けの `title` が入る",
		]
	}
	"R-02": {
		title: "`/_ds/` で、デザインシステムのファイル（ds.css、ds.js、vendor）を返す"
		acceptance: ["`/_ds/ds.css` と `/_ds/ds.js` が、正しい `Content-Type` で200で返る"]
	}
	"R-03": {
		title: "既定で 127.0.0.1 に立ち、READMEにTailscaleでの公開の手順を書く"
		acceptance: ["`--host` を付けないとき、待ち受けは 127.0.0.1 だけ", "READMEに、本人が1回だけ行う `tailscale serve` の手順がある"]
	}
}

failures: {
	"F-01": {
		title:    "デザインシステムが見つからないときは、設定の仕方を示して止まる"
		impact:   "止めずに立つと、部品の描かれない崩れたページになり、原因が分からない"
		recovery: "起動のときに `ds.css` と `ds.js` の有無を確かめ、`serve.design_system_dir` の書き方を示して終了コード2で止まる。本人が設定を直して立ち上げ直す"
	}
	"F-02": {
		title:    "置き場の外を指すpathは404にする"
		text:     "`..`、URLで符号化した `%2e%2e`・`%2f`、絶対path、置き場の外へのsymlinkを含む。"
		impact:   "置き場の外の設定・鍵・ほかのファイルが、tailnetの端末に返る"
		recovery: "pathを `Path.resolve()` してから、日誌の置き場（`/_ds/` はデザインシステムの置き場）の中にあるか（`is_relative_to`）を確かめ、外なら中身を読まずに404。返ってしまった場合は配信を止め、見えたファイルの秘密を作り直す"
	}
	"F-03": {
		title:    "Markdownの中の `</script` と `<!--` で、包んだ `<script>` が途中で閉じたり崩れたりしない"
		impact:   "日誌の本文（commitの文や会話から来る）に `</script>` があると、その後ろがHTMLとして動き、ページの中でscriptが動きうる"
		recovery: "包む前に、大文字小文字を問わず `</script` を `<\\/script`（ds.js が読むときに戻す）に、`<!--` を `<\\!--` に置き換える。置き換えは `wrap_markdown` の1か所だけで行う"
	}
	"F-04": {
		title:    "日誌の本文に混ざった生のHTMLのscriptやイベントの属性は動かない"
		text:     "デザインシステムのMarkdownは生のHTMLをそのまま描くので、応答のヘッダーで防ぐ。"
		impact:   "`<img onerror=…>` などがページの中で動き、同じ配信のほかの日誌を読まれうる"
		recovery: "すべての応答に `Content-Security-Policy: default-src 'self'; script-src 'self' https://unpkg.com; style-src 'self' 'unsafe-inline' https://fonts.googleapis.com; font-src 'self' https://fonts.gstatic.com; img-src 'self' data:; object-src 'none'; base-uri 'none'; frame-ancestors 'none'` と `X-Content-Type-Options: nosniff` を付ける（インラインのscriptとイベントの属性を止める）。デザインシステムの描画がこの方針で動くことを、実際のブラウザーで確かめる。描けないときは、要る最小の許可（例 `'wasm-unsafe-eval'`）だけを足し、`'unsafe-inline'` をscriptに許さず、理由を報告に記録する"
	}
}
