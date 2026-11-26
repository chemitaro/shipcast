package spec

goals: [
	"表紙と一覧のMarkdownは、入力（日誌の一覧）から文字列を返す純粋な関数にし、ファイルを読まずに試験できるようにする",
	"置き場を歩く処理は `shipcast.serve` の1か所にし、iss-00017 の `resolve_inside` を各段で使う",
	"前付けの値をMarkdownに入れるのは、エスケープの関数を通した1つの道だけにする",
]

current: "iss-00017 の `shipcast serve` は `/<repo>/<YYYY-MM-DD>` と `/_ds/…` を返し、`/` と `/<repo>/` は404。`split_path` は `/demo-app/` を `None` にする。"
target:  "`/` が表紙（`:::cards`）、`/<repo>/` が一覧（`:::timeline`）を、`wrap_markdown` で包んで返す。"

design: {
	"D-01": {
		title: "道筋：`split_path` の末尾の `/` と、道筋の割り当て"
		text: """
		- `split_path`：今の処理で分けた部分のうち、**最後の部分だけ** は空でよい（末尾の `/`）。最後の空は `""` の要素として返す（`/demo-app/` → `("demo-app", "")`）。最後でない空（`//x`、`/a//b`、`/a//`）と、空でない部分への今までの検査（`.` で始まる、`/`・`\\\\`・NUL を含む、UTF-8で読めない）はそのまま `None`。`/` は今までどおり `()`。
		- 道筋（`do_GET`）：
		  | 部分 | 応答 |
		  |---|---|
		  | `()` | 表紙（D-03） |
		  | `("_ds", *rest)` | デザインシステム。`rest` に空の部分があれば404（`/_ds/`、`/_ds/vendor/`） |
		  | `(repo, "")` で `repo` が `REPO_ID_PATTERN` に合う | 一覧（D-03）。日が1つもなければ404 |
		  | `(repo,)` で `repo` が `REPO_ID_PATTERN` に合う | 301、`Location: /{repo}/`、本文は短い文字（`text/plain`） |
		  | `(repo, day)` | 今までどおり日誌のページ |
		  | ほか（`(repo, day, "")` を含む） | 404 |
		- 301 も 404 も、iss-00017 の `_send_body` と `end_headers` を通る（すべての応答のヘッダー）。`Location` の値は `REPO_ID_PATTERN` に合った名前だけから作る。
		"""
		satisfies: ["R-01", "R-02"]
	}
	"D-02": {
		title: "置き場を歩く関数（`shipcast.serve`）"
		text: """
		- 型 `shipcast.page.JournalDay`（`frozen` の dataclass）：`repo: str`、`day: date`、`meta: JournalMeta | None`（`None` は前付けを読めない日）。
		- `journal_repos(journal_dir: Path) -> list[str]`：`resolve_inside(journal_dir, ())` が普通のディレクトリでなければ `[]`。直下の名前のうち、`REPO_ID_PATTERN` に合い、`resolve_inside(journal_dir, (name,))` がディレクトリのものを、名前の順で返す。
		- `journal_files(journal_dir, repo) -> list[tuple[date, Path]]`：`repo` のディレクトリの直下で、名前が `\\d{4}` の年のディレクトリ（`resolve_inside` で中にあり、ディレクトリ）の直下の、名前が `YYYY-MM-DD.md` で `date.fromisoformat` で読め、年がディレクトリの名前と同じファイル（`resolve_inside` で中にあり、普通のファイル）を、日付の新しい順で返す。合わないものと `OSError` は黙って飛ばす。
		- `read_meta(path, on_error) -> JournalMeta | None`：`bytes` で読み、`decode("utf-8")`、`parse_journal`。`OSError`・`UnicodeDecodeError`・`JournalFormatError` なら `on_error(path, error)` を呼んで `None`。
		- `journal_days(journal_dir, repo, on_error) -> list[JournalDay]`：`journal_files` のすべてを `read_meta` で読む（一覧）。
		- `latest_journals(journal_dir, on_error) -> list[JournalDay]`：各 repository の `journal_files` を新しい順に読み、最初に `meta` が読めた日を1つ取る（読めなければその repository を出さない）。日付の新しい順、同じ日は repository の名前の順に並べる（表紙）。
		- ハンドラーは `on_error` に、標準エラーへ道筋と理由の1行を出す関数（`self.log_error`）を渡す。
		- 前付けの `date`・`repo` がファイルの道筋と違っても、道筋の値（ファイル名の日付、ディレクトリの名前）を使う。リンクの先が道筋と同じになるため。
		- 中身は要求のたびに読む（日誌は夜に増える）。
		"""
		satisfies: ["R-01", "R-02", "F-01", "F-02"]
	}
	"D-03": {
		title: "表紙と一覧のMarkdown（`shipcast.page`、画面の部分）"
		text: """
		`index_page(latest: Sequence[JournalDay], repos: Sequence[str]) -> str` と `repo_page(repo: str, days: Sequence[JournalDay]) -> str` は、下のMarkdownを組んで `wrap_markdown` で包んだHTMLを返す。Markdownを組む部分は `index_markdown`・`repo_markdown` として単独で試験する。`{t(…)}` は D-04 のエスケープ。

		表紙（`latest` が空でないとき）：

		```markdown
		---
		title: shipcast の日誌
		lead: repositoryごとに、いちばん新しい日の日誌を並べています。
		category: shipcast
		---

		## 最新の日誌

		:::cards
		## {t(meta.title)} {href=/{repo}/{day} badge={day} more=この日を読む}
		{t(meta.lead)}

		{repo} の日誌
		（latest の順に繰り返す）
		:::

		## repositoryごとの一覧

		- [{repo}](/{repo}/)
		（repos の名前の順に繰り返す）
		```

		- `latest` が空のときは、`## 最新の日誌` の下を `:::cards` の代わりに `:::note まだ日誌がありません` と「日誌は `shipcast run` で、登録した repository ごとに1日に1つ作られます。」にする。`repos` が空なら「repositoryごとの一覧」の節を出さない。
		- `repos` は `journal_repos` の結果（読めない日誌だけの repository も一覧へは行ける）。
		- `badge` は日付だけにする。ds.js のバッジは折り返さないので、長い repository の名前を入れると390pxの幅ではみ出す（S-02 のブラウザーで確かめた）。repository の名前は、折り返すカードの本文の最後の段落に書く。

		一覧（`days` は新しい順、空でない）：

		```markdown
		---
		title: {repo} の日誌
		lead: {repo} の日誌を、新しい日から順に並べています（{len(days)}日分）。
		category: shipcast
		---

		[表紙へ戻る](/)

		## {YYYY}年{M}月

		:::timeline
		- **[{day}](/{repo}/{day})** — **{t(meta.title)}** {t(meta.lead)}
		- **[{day}](/{repo}/{day})** — 前付けを読めないため要約を表示できません。
		:::
		（月が変わるごとに見出しと :::timeline を繰り返す）
		```

		- `repo` は `REPO_ID_PATTERN`、`day` は `date.isoformat()` なので、属性・リンクの先・前付けにそのまま入れてよい（記号は `-` だけ）。
		- 項目の説明は1行にする（`mdAuto` が行の中のMarkdownとして描く）。
		- `<title>` は表紙が `shipcast の日誌`、一覧が `{repo} の日誌`（`wrap_markdown` がエスケープする）。
		"""
		satisfies: ["R-01", "R-02", "R-04"]
	}
	"D-04": {
		title: "前付けの値のエスケープ `shipcast.page.markdown_text(value: str) -> str`"
		text: """
		- ASCIIの記号（`string.punctuation` の32字）を、`&` は `&amp;`、ほかはそれぞれ `&#{ord(c)};` に置き換える。ほかの字（英数字、空白、ASCIIでない字）はそのまま。改行（前付けの値にはない）は空白にする。
		- 理由：CommonMark（marked）は数値の文字参照を、記号として解釈せず文字として描く。ds.js の見出しの属性（末尾の `{…}`）、部品の行（`:::`）、行の中の部品（`:name[`）、`splitItem` の `**…**` は生の文字列の上の正規表現で、文字参照の `&#123;` などに当たらない。HTMLの要素にもならない（`<` が `&#60;`）。
		- `&` だけ名前の参照にする理由：marked は数値の文字参照を一度文字に戻してから、実体参照の形の並びをそのまま残して書き出す。`&amp;` の値を `&#38;amp&#59;` にすると `&amp;` として書き出され、ブラウザーで `&` と見える。`&amp;amp&#59;` なら `&amp;amp;` と書き出され、`&amp;` の5字が見える（S-02 のブラウザーで確かめた）。
		- 表紙と一覧で前付けの値を入れるのは、この関数を通した道だけ。
		"""
		satisfies: ["R-03"]
	}
	"D-05": {
		title: "案内の文・起動の表示・README"
		text: """
		- `NOT_FOUND_PAGE` の `:::note` に、表紙 `/` と一覧 `/<repo>/` の道筋を足す（`/<repo>/<YYYY-MM-DD>` の説明は残す）。
		- `shipcast serve` の起動の表示の1行目を `http://{authority}/ で日誌を読めます` にする。
		- READMEの「日誌を読む」の節で、表紙 `/` と一覧 `/<repo>/` を説明し、`tailscale serve` の後に開く道筋を表紙にする。
		"""
		satisfies: ["R-01", "R-02"]
	}
	"D-06": {
		title: "試験の道具立てとブラウザーでの確かめ"
		text: """
		- 見本の置き場は試験の中で `tmp_path` に作る（架空の `demo-app` に3日、`sample-lib` に1日、前付けの壊れた日、置き場の外への symlink、形の違う名前）。`tests/fixtures/journal` は変えない（iss-00017 の試験が `2026-11-25` がないことに頼る）。
		- ページの読み取りは iss-00017 と同じ `html5lib` で `ds-source` の `textContent` を取り、Markdownの行を確かめる。
		- ブラウザーでの確かめ（R-03・R-04）は自動の試験に入れず、S-02 で本物の `spec-dock/design-system/` と一時の見本の置き場で `shipcast serve` を立て、Orca の組み込みのブラウザーで390pxと広い幅で開き、カードと時系列が描け、敵対的な題名が文字で見え、`scrollWidth <= clientWidth` で、CSPの違反がないことを確かめ、画面の写しと結果を報告に記録する。
		"""
		satisfies: ["R-03", "R-04"]
	}
}

compatibility: "`/<repo>/<YYYY-MM-DD>` と `/_ds/…` の応答は変えない。`split_path` は、今まで `None` だった末尾の `/` の道筋だけ値を返す。iss-00017 の試験のうち `/` と `/demo-app/` を404とみなす項目と起動の表示の項目は、このIssueの仕様に合わせて直す。"

risks: [
	"表紙と一覧は要求のたびに置き場を歩いて前付けを読む。日誌が何年分にもなると一覧の応答が遅くなる（1日1ファイルで、1年に365。今は問題にならない）",
	"ds.js の部品の書き方（`:::cards` の見出しの属性、`:::timeline` の `**…** —`）が変わると、表紙と一覧の形が崩れる。デザインシステムの更新のときに S-02 の確かめをやり直す",
]
