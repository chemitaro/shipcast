package spec

goals: [
	"防御（パスの検査、エスケープ、応答のヘッダー、Hostの検査）を、それぞれ1か所の関数にし、単独で試験できるようにする",
	"すべての応答が1つの出口（`end_headers`）を通り、ヘッダーの付け忘れが起きない形にする",
	"表紙と一覧（iss-00018）が、`wrap_markdown` と道筋の読み取りをそのまま使える",
]

current: "`shipcast serve` は iss-00008 の「未実装」の葉（終了コード2）。日誌の置き場と前付けの読み書き（`shipcast.model`）と設定（`shipcast.config`）はある。"
target:  "`shipcast serve` が `ThreadingHTTPServer` で立ち、`/<repo>/<YYYY-MM-DD>` で日誌のページを、`/_ds/<file>` でデザインシステムのファイルを返す。"

design: {
	"D-01": {
		title: "包む関数 `shipcast.page.wrap_markdown(markdown, title) -> str`（画面の部分）"
		text: """
		epic-00005 の D-01 の薄い形。返す文字列は次のとおり（改行も含めて固定。`{…}` が差し込み）。

		```html
		<!doctype html>
		<html lang="ja">
		<head>
		<meta charset="utf-8">
		<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
		<meta name="color-scheme" content="light dark">
		<title>{html.escape(title)}</title>
		<link rel="icon" href="data:,">
		<link rel="stylesheet" href="/_ds/ds.css">
		<script type="text/markdown" id="ds-source">
		{守ったMarkdown}
		<!-- -->
		</script>
		<script src="/_ds/ds.js"></script>
		</head>
		<body></body>
		</html>
		```

		- 守ったMarkdown：`re.compile(r"</(script)", re.IGNORECASE | re.ASCII)` で `</script` を `<\\/script`（元の大小の字はそのまま）に置き換えたもの。`<!--` は置き換えない。HTMLのトークナイザーと ds.js の戻し（`/<\\\\\\/script/gi`）はASCIIの大小だけを同じとみなすので、`re.ASCII` で揃える（`ſ`・`K` などの字を巻き込まない）。
		- 末尾の `\\n<!-- -->\\n`：本文の終わりでトークナイザーが script data state・escaped・double escaped のどれにいても、先頭の改行で途中の状態がこの3つのどれかに落ち着き、`<!--` と ` -->` を通って script data state に戻る。そのため次の `</script>` が必ず `ds-source` を閉じる。Markdownでは見えないHTMLのコメントになる（本文が閉じていないコードの囲みで終わるときだけ、コードの中に `<!-- -->` が見える。報告の残りのリスク）。
		- 保たれない変換（ds.js とHTMLの仕様による。避けられない）：本文に元からある `<\\/script`（バックスラッシュ付き）は、ds.js の戻しで `</script` として描かれる。HTMLの入力の処理で、CR・CRLF は LF に、NUL は U+FFFD になる。R-01 の「元に戻る」は、これらを含まない日誌について言う。
		- `title` は `html.escape(title, quote=True)`。`<title>` はRCDATAなので、`</title>` を含む題名もエスケープで閉じない。ds.js も前付けの `title` で `document.title` を上書きする（どちらも文字として扱う）。
		- 日誌の中身はそのまま（前付けを含む）入れる。ds.js が前付けの `title`・`lead`・`category` をページの頭に描く。`ds.js` が `</SCRIPT` を小文字の `</script` に戻すので、大小の字は描くときに小文字になる（意味は変わらない）。
		- `<link rel="icon" href="data:,">` で、ブラウザーの `/favicon.ico` の要求を出さない。
		- 置き換えと足しは、この関数の1か所だけで行う。ほかのmoduleはMarkdownを自分でHTMLに入れない。
		"""
		satisfies: ["R-01", "F-03"]
	}
	"D-02": {
		title: "案内のページ `shipcast.page.notice_page(title, lead, body) -> str`（画面の部分）"
		text: """
		404・500のときに返すページ。前付け（`title`・`lead`・`category: shipcast`）と本文のMarkdownを組み、`wrap_markdown` で包む。差し込むのはコードに書いた固定の文だけで、要求の道筋・ファイルの道筋・例外の文を入れない（反射した文字列がMarkdownやHTMLとして動かないように）。

		| 場面 | 状態 | 題名 | 本文の要点 |
		|---|---|---|---|
		| 道筋に当たるものがない | 404 | ページが見つかりません | 日誌のURLの形 `/<repo>/<YYYY-MM-DD>`、その日の日誌がまだないかもしれないこと |
		| 前付けを読めない・UTF-8で読めない | 500 | 日誌を読めません | 前付けの形（`title`・`lead`・`date`・`repo`）を確かめること、配信の端末の標準エラーに理由があること |

		本文は `:::note` などデザインシステムの部品で、日誌と同じ見た目にそろえる。`shipcast.page` は404・500の文を `NOT_FOUND_PAGE`・`BROKEN_JOURNAL_PAGE` の定数（`str`、包んだHTML）として持ち、配信はそれを返す。
		"""
		satisfies: ["R-01"]
	}
	"D-03": {
		title: "道筋の読み取りとパスの検査（`shipcast.serve` のロジック）"
		text: """
		- `split_path(target: str) -> tuple[str, ...] | None`：要求の対象から `?` と `#` の後ろを外し、`/` で始まらなければ `None`。`/` だけは `()`。それ以外は、**復号する前に** 生の `/` で分け（先頭の空を除く）、部分ごとに `urllib.parse.unquote(part, errors="strict")` で1回だけ復号する（UTF-8で読めなければ `None`）。復号した部分のどれかが空・`.`・`..`・`.` で始まる、または `/`（`%2f`）・バックスラッシュ（`%5c` を含む）・NULを含むなら `None`。符号化した区切り（`%2f`・`%5c`）は、置き場の中を指していても受けない（親 epic-00005 の F-02）。
		- `resolve_inside(root: Path, parts: Sequence[str]) -> Path | None`：`base = root.resolve()`、`candidate = base.joinpath(*parts).resolve()`。`candidate.is_relative_to(base)` なら `candidate`、でなければ `None`。ファイルの有無は見ない（呼ぶ側が `is_file()` を確かめる）。日誌とデザインシステムの両方で、この関数だけを使う。
		- 道筋：
		  - `("_ds", *rest)`（`rest` が1つ以上）→ デザインシステムの置き場の `resolve_inside` → 普通のファイルで、拡張子が下の表にあれば200、ほかは404。
		  - `(repo, day)` で、`repo` が `REPO_ID_PATTERN` に合い、`day` が `\\d{4}-\\d{2}-\\d{2}` に合って `date.fromisoformat` で読める → `journal_path(journal_dir, repo, day)` を `journal_dir` からの相対の部分に直して `resolve_inside` → 普通のファイルなら読む。なければ404。
		  - ほか（`()`・`(repo,)` を含む）→ 404（表紙と一覧は iss-00018）。

		| 拡張子 | `Content-Type` |
		|---|---|
		| `.css` | `text/css; charset=utf-8` |
		| `.js`・`.mjs` | `text/javascript; charset=utf-8` |
		| `.json` | `application/json` |
		| `.wasm` | `application/wasm` |
		| `.woff2` | `font/woff2` |
		| `.md`・`.txt` | `text/plain; charset=utf-8` |

		- 日誌は `bytes` で読み、`decode("utf-8")`（BOMは `parse_journal` が外す）。`UnicodeDecodeError` か `JournalFormatError` なら500（`BROKEN_JOURNAL_PAGE`）と、標準エラーに道筋と理由の1行。読めたら `wrap_markdown(text, meta.title)`。
		- 中身は要求のたびにディスクから読む（日誌は夜に書き換わる）。キャッシュの見出しは付けない。
		- 検査と読む間にsymlinkを差し替える競合（TOCTOU）は、置き場に書ける者が要るので、この脅威の外とする。
		"""
		satisfies: ["R-01", "R-02", "F-02"]
	}
	"D-04": {
		title: "応答のヘッダー `security_headers()` と、1つの出口"
		text: """
		`security_headers() -> tuple[tuple[str, str], ...]` は次の3つを返す。

		```text
		Content-Security-Policy: default-src 'self'; script-src 'self' 'wasm-unsafe-eval' https://unpkg.com/@plantuml/core@1.2026.6/ https://unpkg.com/@highlightjs/cdn-assets@11.11.1/; style-src 'self' 'unsafe-inline' https://fonts.googleapis.com; font-src 'self' https://fonts.gstatic.com; img-src 'self' data:; object-src 'none'; base-uri 'none'; frame-ancestors 'none'; form-action 'none'
		X-Content-Type-Options: nosniff
		Referrer-Policy: no-referrer
		```

		- 親の D-05 からの変更：`'wasm-unsafe-eval'`（PlantUMLのWebAssemblyに要る。試作で確かめた）、`form-action 'none'`（本文に混ざった `<form>` で外へ送らせない。デザインシステムはformを使わない）、`Referrer-Policy: no-referrer`（日誌のURLとtailnetの名前をunpkg.com・Googleのフォントへ送らない）。
		- `style-src 'unsafe-inline'` は、ds.js が部品に `style` の属性を書くので要る。scriptには `'unsafe-inline'`・`'unsafe-eval'` を許さない。
		- unpkg.com は、ds.js が決まった版のPlantUML（`@plantuml/core@1.2026.6`）とhighlight.js（`@highlightjs/cdn-assets@11.11.1`）を読む **2つの道筋だけ** を許す（末尾の `/` で、その下だけに当たる）。unpkg.com のオリジン全体は許さない。理由（最終品質ゲートの ChatGPT の P1、2026-11-26、ブラウザーで再現）：ds.js は本文を文書に入れた後に `document.querySelector('meta[name="ds-vendor-base"]')` で部品の読み込み先を決めるので、本文の生のHTMLの `<meta name="ds-vendor-base" content="https://unpkg.com/<誰かのパッケージ>/">` で、第三者が unpkg に置いたscriptを日誌の生まれで動かせる。道筋を絞ると、差し替えた先はCSPで拒まれ、ds.js は次の候補（決まった版のCDN）から読む。版の値は ds.js の `PLANTUML_VERSION`・`HLJS_VERSION` と同じにし、試験でそろっていることを確かめる。
		- 本文の生のHTMLが `<script src=…>` を足しても、`innerHTML` で入れたscriptは動かない。同じ生まれの道筋をscriptとして読ませても、日誌のページと案内は `text/html` で `nosniff` なので動かない。
		- 配信のハンドラーは `end_headers()` を上書きし、`security_headers()` を送ってから親の `end_headers()` を呼ぶ。`send_error`（400・404・405・501など標準ライブラリが返すものを含む）もここを通るので、すべての応答に付く。`server_version = "shipcast"`、`sys_version = ""` で、Pythonの版を `Server` に出さない。
		"""
		satisfies: ["F-04"]
	}
	"D-05": {
		title: "Hostの検査 `host_allowed(host: str | None) -> bool`"
		text: """
		- `None`・空なら `False`。`[…]:port`・`name:port` からポートを外し、小文字にする。
		- `True` になるもの：`ipaddress.ip_address` で読めるもの（`[::1]` は角かっこを外して読む）、`localhost`、`.ts.net` で終わる名前（英数字・`-`・`.` だけ）。ほかは `False`。点のない1語の名前（MagicDNSの短い名前など）は受けない：OSのDNSの検索ドメインで外の名前空間の名前に解決されうるので、付け替えの攻撃に使われうる（仕様レビュー round 2 の ChatGPT の P1）。`tailscale serve` で読むときのHostは `.ts.net` の名前か、中継の `127.0.0.1` になる。
		- ハンドラーは、道筋を読む前に確かめ、`False` なら400（本文は短い文字）を返し、ファイルを読まない。
		- 理由：DNSの付け替えの攻撃では、外のWebページの名前（点を含む外の名前）がHostに入る。IPの書き方とtailnetの名前は、外のページが自分のものとして使えない。
		"""
		satisfies: ["F-05"]
	}
	"D-06": {
		title: "配信の部品 `create_server(host, port, journal_dir, design_dir) -> ThreadingHTTPServer`"
		text: """
		- 標準の `http.server.ThreadingHTTPServer`（`daemon_threads = True`）。ハンドラーは `BaseHTTPRequestHandler` の子で、`journal_dir`・`design_dir` を部品の属性として持つ（グローバルを使わない）。試験は `port=0` で立てて `server.server_address` を読む。
		- `GET` と `HEAD` だけを受ける。`HEAD` は `GET` と同じ状態とヘッダー（`Content-Length` を含む）で、本文を書かない。`POST`・`PUT`・`DELETE`・`PATCH`・`OPTIONS` は405と `Allow: GET, HEAD`。ほかの方法は標準ライブラリの501（D-04 の出口を通る）。
		- 応答の本文はいつも `Content-Length` を付ける。HTMLは `text/html; charset=utf-8`。
		- 要求の記録は標準ライブラリの `log_message`（標準エラー）のまま。
		"""
		satisfies: ["R-01", "R-02", "F-04"]
	}
	"D-07": {
		title: "デザインシステムの置き場 `find_design_system(config) -> Path`"
		text: """
		- `config.serve.design_system_dir` があれば、そこだけを見る。なければ `config.repos` の順に `repo.path / "spec-dock" / "design-system"` を見る。`ds.css` と `ds.js` が両方とも普通のファイルである最初のものを `resolve()` して返す。
		- 見つからなければ `DesignSystemNotFound`（見た場所の一覧を持つ）。`shipcast serve` は標準エラーに次を出して終了コード2：見た場所（なければ「登録したrepositoryがありません」）、設定ファイルの道筋（`config_path()`）、`[serve]` の `design_system_dir = "/…/spec-dock/design-system"` の書き方、`spec-dock installation update` で入れられること。
		"""
		satisfies: ["F-01"]
	}
	"D-08": {
		title: "`shipcast serve` の葉（`configure(parser)`・`run(args)`）と `cli.py` の接続"
		text: """
		- 引数：`--host HOST`（省けば `config.serve.host`）、`--port PORT`（1〜65535の整数。省けば `config.serve.port`）。
		- 順：`load_config()`（`ConfigError` なら `shipcast serve: {error}` を標準エラーに出して1）→ `find_design_system`（なければ D-07 の案内で2）→ `create_server`（`OSError` なら `shipcast serve: {host}:{port} で待ち受けられません: {理由}` で1）→ 標準出力に `http://{host}:{port}/<repo>/<YYYY-MM-DD> で日誌を読めます`・日誌の置き場・デザインシステムの置き場・`Ctrl+C で止まります` → `serve_forever()`。`KeyboardInterrupt` で `server_close()` して0。IPv6の待ち受けはURLで `[…]` に包む。
		- 日誌の置き場がまだないときも立ち、標準エラーに「日誌の置き場がまだありません（`shipcast run` で作られます）」を出す。
		- 待ち受けがループバック（`ipaddress` で `is_loopback`、または `localhost`）でなければ、標準エラーに「tailnetやLANの端末から直接読めます。`tailscale serve` で 127.0.0.1 の配信を公開する方法を勧めます（README）」を出す。
		- `cli.py`：`from shipcast import serve  # isort: skip` の1行と、`COMMANDS` の `serve` の `Entry` に `serve.configure` を渡す変更だけ。`tests/test_cli.py` の未実装の一覧から `serve` の1行を外す。
		"""
		satisfies: ["R-03", "F-01"]
	}
	"D-09": {
		title: "README の「日誌を読む」の節"
		text: """
		「License」の前に節を足す。内容：`shipcast serve` の起動、既定の 127.0.0.1:8765、日誌のURLの形、デザインシステムの置き場の決まりと `design_system_dir`、Tailscaleでの公開（本人が1回だけ `tailscale serve --bg 8765`、表示された `https://<端末>.<tailnet>.ts.net/` で読む、止めるのは `tailscale serve --https=443 off`）、Funnel を使わない注意。shipcastはTailscaleの設定を変えない（epic-00005 の D-04）。「状態」の節は変えない（並行の作業と衝突させない）。
		"""
		satisfies: ["R-03"]
	}
	"D-10": {
		title: "試験の道具立て"
		text: """
		- 見本の日誌（架空）：`tests/fixtures/journal/demo-app/2026/2026-11-26.md`。前付けの4項目と `category`、`:::summary`・`:::warning` の部品、PlantUMLの図、`</script>` を含むコードの囲み、`<img src=x onerror=…>` を含む。iss-00018 も使える。
		- デザインシステムの代わり：試験は `tmp_path` に小さな `ds.css`・`ds.js`・`vendor/marked.umd.js` を作る（本物を写さない）。symlinkの試験も `tmp_path` の中で作る。
		- HTMLの読み取り：`html5lib`（dev group）でHTMLの仕様どおりに読み、`ds-source` の `textContent`、`<script>` の数と `src`、`<title>` を確かめる。
		- 配信の試験は `create_server(…, port=0)` をthreadで立て、`http.client` で生の道筋（`/%2e%2e/…` など、クライアントが正規化しない形）を送る。
		- ブラウザーでの確かめ（T-07）は自動の試験に入れず、S-04 で Orca の組み込みのブラウザーを使い、結果を報告に記録する。
		"""
		satisfies: ["R-01", "R-02", "F-02", "F-03"]
	}
}

compatibility: "既存のコマンドと設定の形は変えない。`cli.py` は `serve` の接続だけを変える。実行時の依存は増えない（`html5lib` は dev group）。"

risks: [
	"デザインシステムが将来インラインのscript・別のCDN・別のWebAssemblyの読み方を使うと、D-04 の方針で描けなくなる。T-07 のブラウザーでの確かめで気づき、最小の許可を足す",
	"CSPの unpkg.com の道筋は ds.js の部品の版に結び付く。デザインシステムが部品の版を上げると図と色分けが描けなくなる（本文は描ける）。試験で ds.js の版とCSPの道筋がそろっていることを確かめ、上げるときは同じ変更でCSPを直す",
	"Hostの検査は、`.ts.net` でない独自の名前（自分のドメインなど）で読む使い方を拒む。必要になったら許す名前を設定に足す（別のIssue）",
	"本文が閉じていないコードの囲みで終わる日誌では、末尾の `<!-- -->` がコードの中に見える",
]
