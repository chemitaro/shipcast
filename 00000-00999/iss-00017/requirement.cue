package spec

schema: "specdock/v1"

assurance: {
	level:  "strict"
	reason: "手元のHTTPの配信は、tailnetの端末から読まれるセキュリティの境界になる。パスの検査を誤ると日誌の置き場の外のファイル（設定や鍵）を返し、`</script>` の扱いや本文の生のHTMLを誤ると、日誌に混ざった文字列がページの中で動く。外へ出た内容は取り消せないので回復が難しい"
}

purpose: "`shipcast serve` で、日誌のMarkdownをデザインシステムで描くページとして返す。表紙と一覧（iss-00018）は、ここの包み方（`shipcast.page`）と配信の部品（`shipcast.serve`）を使う。"

background: """
親の epic-00005（E4 閲覧）の R-01・R-03・F-01〜F-04 を、このIssueが受け持つ（親の `slices`）。日誌のファイルの置き場と前付けの形は epic-00002 の約束で、コードでは `shipcast.model.journal_path`（`<journal_dir>/<repo>/<YYYY>/<YYYY-MM-DD>.md`）と `parse_journal`（前付けの `title`・`lead`・`date`・`repo` が必須）が正本。設定は iss-00009 の `shipcast.config.load_config()` が返す `Config`（`journal_dir`、`serve.host`・`serve.port`・`serve.design_system_dir`、`repos`）を読む。

デザインシステム（`ds.css`・`ds.js`・`vendor/marked.umd.js`）は SpecDock が配るもので、`<script type="text/markdown" id="ds-source">` の中のMarkdownを描く。`ds.js` は読むときに `<\\/script` を `</script` に戻す（大文字小文字を問わない）が、ほかの置き換えは戻さない。図（PlantUML）とコードの色分け（highlight.js）は unpkg.com から読み、PlantUMLはWebAssemblyで動く。

仕様化の中で、試作のサーバーと Orca の組み込みのブラウザーで次を確かめた（2026-11-26、`.workbench/coding-task/iss-00017/proto/`）。
- 親の F-04 のCSPのままだと、PlantUMLのWebAssemblyが `CompileError`（`'unsafe-eval' is not an allowed source`）で描けない。`script-src` に `'wasm-unsafe-eval'` を足すと、図・色分け・部品が描け、`<img onerror>` は動かない。
- 親の F-03 の「`<!--` を `<\\!--` に置き換える」は、ds.js が戻さないため、本文の中のHTMLのコメントが見える文字になり、コメントの中の `<script>` が生のHTMLとして後ろの本文（図を含む）を飲み込んだ。そのため、このIssueでは `<!--` を置き換えず、本文の後ろに閉じのコメントを1つ足す方法に改める（D-01）。
"""

includes: [
	"新しいmodule `shipcast.page`：ページの包み方 `wrap_markdown` と、案内のページ（404など）のMarkdown（画面の部分）",
	"新しいmodule `shipcast.serve`：道筋の読み取り、パスの検査 `resolve_inside`、応答のヘッダー `security_headers`、Hostの検査、HTTPの配信、デザインシステムの置き場の決定、`shipcast serve` の葉（引数・出力・終了コード）",
	"`src/shipcast/cli.py` の `serve` の行に `configure` を渡す変更と、その `import` の1行（ほかの行は変えない）",
	"試験 `tests/test_page.py`・`tests/test_serve.py`、`tests/test_cli.py` の未実装の一覧から `serve` を外す変更、見本の日誌（架空）とデザインシステムの代わりの小さなファイル",
	"開発の依存（dev group）に、HTMLの仕様どおりに読む `html5lib` を足す（`pyproject.toml`・`uv.lock`）",
	"READMEに、日誌の読み方とTailscaleでの公開の手順の節を足す",
]

excludes: [
	"表紙 `/` と一覧 `/<repo>/`（iss-00018）。このIssueでは404を返す",
	"デザインシステムのファイルの複製・同梱・書き換え（`spec-dock/design-system/` を `/_ds/` で配るだけ）",
	"Tailscaleの設定の変更（本人が1回だけ手で行う）、TLS、認証",
	"配信の常駐（launchd など）、条件付きの取得（ETag・`If-Modified-Since`）、圧縮",
	"日誌のファイルを書くこと（配信は読むだけ）",
]

constraints: [
	"このrepositoryはpublic。試験の見本の日誌は架空の内容にし、本人のrepository名・パス・会話を書かない",
	"標準ライブラリだけで動く（実行時の依存を足さない）。`html5lib` は試験だけに使う",
	"配信は日誌の置き場とデザインシステムの置き場を読むだけで、どちらにも書かない",
	"`src/shipcast/cli.py` の変更は `serve` の接続だけにする（並行する iss-00011・iss-00014 との衝突を小さくする）",
]

decisions: [
	"本人の決定 11・12（`content/decisions/20261126-journal-format-and-hackathon-plan.md`）：読み手は本人だけ、配信はTailscale",
	"本人の決定 20：画面のデザイン・ページの枠・表示は Opus 5.5 が直接実装する",
	"本人の決定 24：このIssueの保証レベルは `strict`",
	"タスク担当の判断（2026-11-26、試作の結果による）：CSPの `script-src` に `'wasm-unsafe-eval'` を足す。`'unsafe-eval'` と `'unsafe-inline'` はscriptに許さない",
	"タスク担当の判断（2026-11-26、試作の結果による）：`<!--` は置き換えず、包む本文の末尾に閉じのコメント `<!-- -->` を足して、`<script>` の終わりを守る（親の F-03 の置き換えの方法を改める。守る目的は同じ）",
	"タスク担当の判断（2026-11-26）：DNSの付け替え（DNS rebinding）で外のWebページから手元の配信を読まれないよう、Hostのヘッダーを確かめる（F-05）",
	"タスク担当の判断（2026-11-26、最終品質ゲートの ChatGPT の P1 をブラウザーで再現して採用）：CSPの `script-src` は unpkg.com のオリジン全体ではなく、ds.js が読む決まった版の2つの道筋だけを許す（F-04、D-04）。本文の生のHTMLの `<meta name=\"ds-vendor-base\">` で部品の読み込み先を差し替えられるため",
]

requirements: {
	"R-01": {
		title: "`/<repo>/<YYYY-MM-DD>` で、日誌のMarkdownを epic-00005 の D-01 の形に包んで返す"
		text: """
		`<repo>` は `shipcast.model.REPO_ID_PATTERN`（英小文字・数字・`-`）、日付は `YYYY-MM-DD` の実在する日。ファイルは `journal_path(journal_dir, repo, day)`。ファイルの中身（前付けを含む）をそのまま `ds-source` に入れ、`<title>` には前付けの `title` を入れる。
		"""
		acceptance: [
			"見本の日誌で `200`、`Content-Type: text/html; charset=utf-8` が返り、`<script type=\"text/markdown\" id=\"ds-source\">` がちょうど1つあり、その `textContent` から ds.js と同じ戻しをすると日誌のファイルの中身に閉じのコメントを足したものになり、`/_ds/ds.css` と `/_ds/ds.js` を読む",
			"`<title>` に前付けの `title` がHTMLのエスケープをして入る（`<b>` を含む題名でも要素にならない）",
			"日誌がない日、`<repo>` や日付の形が違う道筋は404。前付けを読めない日誌は500で、どちらもデザインシステムで描く案内のページを返し、要求の道筋やファイルの道筋を本文に書かない",
			"`HEAD` は `GET` と同じ状態とヘッダーで、本文を返さない",
		]
	}
	"R-02": {
		title: "`/_ds/` で、デザインシステムのファイル（ds.css、ds.js、vendor）を返す"
		acceptance: [
			"`/_ds/ds.css`・`/_ds/ds.js`・`/_ds/vendor/marked.umd.js` が、`text/css; charset=utf-8`・`text/javascript; charset=utf-8` で200で返り、中身がファイルとバイト列で同じ",
			"許した拡張子（D-03 の表）でないファイル（`explanation-skeleton.html` など）、ディレクトリ、名前が `.` で始まる部分を含む道筋は404",
		]
	}
	"R-03": {
		title: "既定で 127.0.0.1 に立ち、READMEにTailscaleでの公開の手順を書く"
		text: """
		`shipcast serve [--host HOST] [--port PORT]`。省いた値は設定の `serve.host`・`serve.port`（既定 `127.0.0.1`・`8765`）。立ったら、読むURL・日誌の置き場・デザインシステムの置き場を標準出力に示し、Ctrl+C で止まって終了コード0。
		"""
		acceptance: [
			"既定の設定で `--host` を付けないとき、待ち受けは 127.0.0.1 だけ",
			"ループバック（127.0.0.0/8、`::1`、`localhost`）でない待ち受けを選ぶと、標準エラーに、tailnetやLANから直接読めることと `tailscale serve` を勧める案内を出す",
			"READMEに、`shipcast serve` の起動と、本人が1回だけ行う `tailscale serve --bg 8765` の手順・止め方、Funnel（インターネットへの公開）を使わない注意がある",
			"設定ファイルがない・壊れているときは、iss-00009 の `ConfigError` の文と `直し方:` を標準エラーに出して終了コード1。ポートが使用中などで立てないときは、理由を示して終了コード1",
		]
	}
}

failures: {
	"F-01": {
		title:    "デザインシステムが見つからないときは、設定の仕方を示して止まる"
		text:     "置き場は `serve.design_system_dir`。空なら、登録したrepository（`repos` の順）の `spec-dock/design-system/` のうち、`ds.css` と `ds.js` の両方がある最初のもの。"
		impact:   "止めずに立つと、部品の描かれない崩れたページになり、原因が分からない"
		recovery: "起動のとき（待ち受けの前）に `ds.css` と `ds.js` の有無を確かめ、見た場所と、設定ファイルの道筋、`[serve]` の `design_system_dir = \"/…/spec-dock/design-system\"` の書き方を標準エラーに示して終了コード2で止まる。`design_system_dir` を書いたのにそこにないときは、ほかの場所を探さない。本人が設定を直して立ち上げ直す"
	}
	"F-02": {
		title:    "置き場の外を指すpathは404にする"
		text:     "`..`、URLで符号化した `%2e%2e`・`%2f`・`%5c`、絶対path（`//` で始まる道筋）、NUL、置き場の外へのsymlinkを含む。日誌とデザインシステムの両方に当てはまる。"
		impact:   "置き場の外の設定・鍵・ほかのファイルが、tailnetの端末に返る"
		recovery: "道筋を1回だけ復号してから、空・`.`・`..`・`.` で始まる部分、バックスラッシュ（`\\`）、NULを含むものを中身を読まずに404にし、さらに `Path.resolve()` した結果が置き場（それ自体も `resolve()` したもの）の中にあるか（`is_relative_to`）を確かめ、外なら中身を読まずに404。返ってしまった場合は配信を止め、見えたファイルの秘密を作り直す"
	}
	"F-03": {
		title:    "Markdownの中の `</script` と `<!--` で、包んだ `<script>` が途中で閉じたり崩れたりしない"
		text:     "HTMLの仕様では、`<script>` の中身は `</script` で閉じ、`<!--` の後に `<script` があると次の `</script>` で閉じなくなる（script data double escaped state）。"
		impact:   "日誌の本文（commitの文や会話から来る）に `</script>` があると、その後ろがHTMLとして動き、ページの中でscriptが動きうる。`<!--<script>` があると、ds.js の読み込みが本文に飲み込まれて、ページが空になる"
		recovery: "包む前に、ASCIIの大文字小文字を問わず `</script` を `<\\/script`（ds.js が読むときに戻す）に置き換え、本文の末尾に改行と閉じのコメント `<!-- -->` と改行を足す（どの状態からでも script data state に戻り、Markdownでは見えないコメントになる）。置き換えと足しは `wrap_markdown` の1か所だけで行う"
	}
	"F-04": {
		title:    "日誌の本文に混ざった生のHTMLのscriptやイベントの属性は動かない"
		text:     "デザインシステムのMarkdownは生のHTMLをそのまま描くので、応答のヘッダーで防ぐ。本文の生のHTMLが部品の読み込み先（`<meta name=\"ds-vendor-base\">`）を差し替えても、許した版の道筋の外のscriptは読まない。"
		impact:   "`<img onerror=…>` や、差し替えた読み込み先の第三者のscriptがページの中で動き、同じ配信のほかの日誌を読まれうる"
		recovery: "すべての応答（404・405・400・500を含む）に D-04 のCSP・`X-Content-Type-Options: nosniff`・`Referrer-Policy: no-referrer` を付ける（インラインのscriptとイベントの属性を止め、URLやtailnetの名前をCDNへ送らない）。デザインシステムの描画がこの方針で動くことを、実際のブラウザーで確かめる。描けないときは、要る最小の許可だけを足し、`'unsafe-inline'`・`'unsafe-eval'` をscriptに許さず、理由を報告に記録する"
	}
	"F-05": {
		title:    "Hostのヘッダーが手元・tailnetの名前でない要求は拒む"
		text:     "DNSの付け替え（DNS rebinding）：本人がブラウザーで開いた外のWebページが、自分の名前を 127.0.0.1 に付け替えて、手元の配信を同じ生まれ（origin）として読む攻撃。"
		impact:   "本人が外のWebページを開いただけで、日誌の中身がそのページに読まれる"
		recovery: "Hostのヘッダー（ポートを除く）が、IPアドレスの書き方、`localhost`、`.ts.net` で終わる名前、点のない1語の名前（MagicDNSの短い名前）のどれかでなければ、中身を読まずに400を返す。Hostがない要求も400。本人が別の名前で読みたいときは、READMEの案内に従い `tailscale serve` の名前で読む"
	}
}

questions: []
