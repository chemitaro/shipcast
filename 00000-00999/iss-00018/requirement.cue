package spec

schema: "specdock/v1"

assurance: {
	level:  "light"
	reason: "iss-00017 の包み方と道筋の上に、表紙と一覧のMarkdownを組むだけで、影響は2つのページに閉じる。読むだけで日誌を変えず、PRを戻せば元に戻る"
}

purpose: "表紙（全repositoryの最新）と、repositoryごとの日付の一覧を、Markdownで作って同じ包み方で描く。"

background: """
親の epic-00005（E4 閲覧）の R-02 と D-02（表紙は `:::cards`、一覧は `:::timeline`）を、このIssueが受け持つ。iss-00017（main に統合済み、`b7832b8`）が `shipcast serve`、包む関数 `shipcast.page.wrap_markdown`、道筋の読み取り `shipcast.serve.split_path`、パスの検査 `resolve_inside`、案内のページ `NOT_FOUND_PAGE`・`BROKEN_JOURNAL_PAGE` を作った。今は `/` と `/<repo>/` が404を返す。

iss-00017 の申し送り（`iss-00017/report.md` の Residual Risks）：`split_path` は末尾の `/` を含む道筋（`/demo-app/`）を `None` にする。一覧を足すときに、末尾の `/` の扱いを足す。

日誌の置き場は `<journal_dir>/<repo>/<YYYY>/<YYYY-MM-DD>.md`（`shipcast.model.journal_path`）、前付けは `parse_journal` が読む（`title`・`lead`・`date`・`repo` が必須で、値は1行）。前付けの値は、夜の実行でエージェントが commit の文や会話から書くので、Markdownの記号や生のHTMLを含みうる。

デザインシステムの部品（`spec-dock/design-system/ds.js`）：
- `:::cards`：本文を見出しで区切り、見出しごとに1枚のカード。見出しの末尾の `{href=… badge=a,b more=…}` を属性として読み、`href` があればカード全体が `<a>` になる。見出しの文字は `ctx.inline`（行の中のMarkdown）、本文は `ctx.md` で描く。
- `:::timeline`：本文の箇条書きの各項目を `**題名** — 説明 {属性}` に分け、題名を日付の欄、説明を本文の欄に描く。
- どちらも、生のMarkdownの記号（行頭の `#`・`:::`、末尾の `{…}`、`**`、`[…](…)`）を、文字を入れる前に解釈する。
"""

includes: [
	"`shipcast.serve.split_path` に、末尾の `/` を最後の空の部分として返す扱いを足す（ほかの空の部分は今までどおり拒む）",
	"`shipcast.serve` に、日誌の置き場を歩いて repository と日付の一覧を作る関数（読むだけ）と、`/`・`/<repo>/`・`/<repo>` の道筋",
	"`shipcast.page` に、表紙と一覧のMarkdownを組む関数と、前付けの値をMarkdownの文字として入れるエスケープの関数（画面の部分）",
	"`NOT_FOUND_PAGE` の本文と `shipcast serve` の起動の表示に、表紙と一覧の道筋を足す。READMEの「日誌を読む」の節の道筋の説明",
	"試験（`tests/test_page.py`・`tests/test_serve.py`）。見本の日誌は試験の中で `tmp_path` に作る（架空）",
]

excludes: [
	"日誌の1日のページ（`/<repo>/<YYYY-MM-DD>`）の描き方の変更（iss-00017 のまま）",
	"デザインシステムのファイルの変更、新しい部品",
	"検索、ページ送り、件数の上限、キャッシュ",
	"設定の `repos` との照合（表紙は日誌の置き場にある repository を並べる）",
	"日誌のファイルを書くこと（配信は読むだけ）",
]

constraints: [
	"このrepositoryはpublic。試験の見本は架空の内容にし、本人のrepository名・パス・会話を書かない",
	"標準ライブラリだけで動く（実行時の依存を足さない）",
	"iss-00017 の防御（`wrap_markdown` の1か所の包み、`resolve_inside` のパスの検査、すべての応答のヘッダー、Hostの検査）をそのまま通す。一覧を歩くときも、読むファイルはすべて `resolve_inside` で置き場の中と確かめる",
	"試験とエージェントの作業で外部のモデルを呼ばない",
]

decisions: [
	"本人の決定 20：画面のデザイン・レイアウト・Markdownの組み立て・表示の確かめは Opus 5.5 が直接実装する（GPT-6.2 Sol に頼まない）",
	"親 epic-00005 の D-02：表紙は `:::cards`、一覧は `:::timeline`",
	"タスク担当の判断（2026-11-26）：表紙に並べる repository は、日誌の置き場にあるディレクトリから決める（設定の `repos` を見ない）。配信は日誌の置き場だけを持ち、登録を外した repository の日誌も読めるようにするため",
	"タスク担当の判断（2026-11-26）：前付けの値（`title`・`lead`）は、ASCIIの記号をすべて文字参照（`&` は `&amp;`、ほかは数値の `&#NN;`）にしてからMarkdownに入れる。部品の属性・見出し・箇条書きの区切りとして解釈されず、文字として見える（R-03）",
	"タスク担当の判断（2026-11-26、S-02 のブラウザーでの確かめによる仕様の変更）：`&` を数値の `&#38;` にすると、marked が `&#38;amp&#59;` を実体参照 `&amp;` に戻して `&` と描くため、`&` だけ名前の参照 `&amp;` にする。カードの `badge` に repository の名前を入れると、長い名前が折り返さず390pxの幅ではみ出すため、`badge` は日付だけにし、repository の名前はカードの本文（折り返す）に書く",
	"タスク担当の判断（2026-11-26）：一覧は月ごとの見出しで区切り、各項目に日付（その日へのリンク）と、題名・lead を出す。親の「日付と lead」に題名を足すのは、lead だけでは1日を見分けにくいため",
	"タスク担当の判断（2026-11-26）：`/<repo>`（末尾の `/` なし）は `/<repo>/` へ301で移す",
]

requirements: {
	"R-01": {
		title: "`/` に、repositoryごとの最新の日誌が `:::cards` で並ぶ"
		text: """
		日誌の置き場の直下の、名前が `REPO_ID_PATTERN` に合うディレクトリを repository とみなす。各 repository の、前付けを読める最も新しい日の日誌を1枚のカードにする（題名、lead、repository、日付。カードを押すとその日のページ）。カードは日付の新しい順、同じ日は repository の名前の順。
		"""
		acceptance: [
			"見本の置き場（2つの repository、一方に3日分）で `/` が200・`text/html; charset=utf-8` で、`ds-source` のMarkdownに `:::cards` があり、repository ごとに1枚、最も新しい日の題名と lead と `href=/<repo>/<YYYY-MM-DD>` が、日付の新しい順に並ぶ",
			"最も新しい日の前付けが読めないときは、読める日のうち最も新しい日を出す。どの日も読めない repository は出さない",
			"日誌が1つもない（置き場がない場合を含む）ときも200で、日誌がまだないことと `shipcast run` で作られることを案内する",
			"表紙に各 repository の一覧（`/<repo>/`）へのリンクがある",
		]
	}
	"R-02": {
		title: "`/<repo>/` に、日付と lead が `:::timeline` で新しい順に並ぶ"
		acceptance: [
			"見本の repository で `/demo-app/` が200で、`ds-source` のMarkdownに `:::timeline` があり、日誌のある日がすべて、新しい順に、日付（`/<repo>/<YYYY-MM-DD>` へのリンク）・題名・lead で並ぶ。月が変わるところに `YYYY年M月` の見出しがある",
			"前付けを読めない日も、日付のリンクと「前付けを読めないため要約を表示できません」の固定の文で並ぶ",
			"日誌が1つもない repository、置き場にない repository、名前が `REPO_ID_PATTERN` に合わない道筋（`/Demo/`）は404の案内のページ",
			"`/demo-app`（末尾の `/` なし）は301で `Location: /demo-app/`。`/demo-app/2026-11-26/`・`/demo-app//`・`/_ds/` は404",
			"一覧から表紙（`/`）へ戻るリンクがある",
		]
	}
	"R-03": {
		title: "前付けの値が、表紙と一覧の形を崩さず文字のまま見える"
		text:  "前付けの値に `{href=…}`、行頭の `#`・`:::`、`**`、`[x](y)`、`<img src=x onerror=…>`、`&amp;`（`&amp;` の5字のまま見える）があっても、カードや項目が増えたり、別の先へのリンクや属性になったり、HTMLの要素になったりしない。"
		acceptance: [
			"エスケープの関数の結果に、`&#NN;` と `&amp;` のほかのASCIIの記号が残らず、ASCIIの英数字と空白とASCIIでない文字はそのまま",
			"そうした題名・lead の日誌で、表紙のカードの数と一覧の項目の数が日誌の数と同じで、カードの見出しの行の末尾の属性が、組む関数が書いたものだけ",
			"実際のブラウザーで、そうした題名・lead が文字として見え、`onerror` が動かない（S-02 で確かめ、報告に記録する）",
		]
	}
	"R-04": {
		title: "表紙と一覧が、スマートフォンの幅（390px）で横にはみ出さない"
		acceptance: [
			"本物のデザインシステムで、表紙と一覧を390pxの幅で開くと `document.documentElement.scrollWidth` が `clientWidth` を超えない。長い題名・lead・repository名でも同じ（S-02 で確かめ、報告に記録する）",
		]
	}
}

failures: {
	"F-01": {
		title:    "日誌の置き場を歩くときに、置き場の外のファイルを読まない"
		text:     "repository や年のディレクトリ、日誌のファイルが、置き場の外への symlink のとき。名前が `.` で始まるもの、形の違う名前（`2026-02-30.md`、年のディレクトリと年の違うファイル）のとき。"
		impact:   "置き場の外のファイルの前付け（または中身の一部）が、表紙や一覧に出る"
		recovery: "読む前に、repository・年・ファイルの各段で `resolve_inside(journal_dir, …)` を通し、外なら黙って飛ばす。名前の形（`REPO_ID_PATTERN`、`YYYY`、`YYYY-MM-DD.md` で実在の日、年のディレクトリと同じ年）に合わないものも飛ばす"
	}
	"F-02": {
		title:    "前付けを読めない日誌があっても、表紙と一覧は返る"
		impact:   "1日の壊れた日誌で、表紙や一覧の全体が500になり、ほかの日も読めなくなる"
		recovery: "UTF-8で読めない・前付けが壊れている日誌は、標準エラーに道筋と理由の1行を出し、表紙では飛ばし、一覧では固定の文で並べる。読み取りの `OSError` も同じに扱う"
	}
}

questions: []
