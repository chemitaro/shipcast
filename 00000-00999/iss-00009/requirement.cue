package spec

schema: "specdock/v1"

assurance: {
	level:  "standard"
	reason: "設定ファイルの形と `repo add` の書き方は、ほかの全Issueが読む共通の約束になる。誤ると本人の手元の設定を壊しうるが、ファイルは手元だけにあり、PRを戻して設定を書き直せば回復できる"
}

purpose: "設定ファイル `config.toml` を型のついた設定として読み、日誌の対象のrepositoryを `shipcast repo add` で登録し、`shipcast repo list` で一覧できるようにする。ほかのIssueは `shipcast.config.load_config()` だけで設定を読めるようにする。"

background: """
親の epic-00002 の R-02（設定ファイルで、対象のrepositoryとモデルの経路と置き場を決める）と F-01（設定ファイルがない・壊れているときは直し方を示して止まる）を、このIssueが受け持つ。設定ファイルの形は epic-00002 の D-02 が正本、置き場は init-00001 の D-02（`~/.config/shipcast/config.toml`、環境変数 `SHIPCAST_CONFIG` で変えられる）が正本。

iss-00008 で、`shipcast repo add` と `shipcast repo list` は「未実装」の葉として登録済み（`src/shipcast/cli.py` の `COMMANDS`）。このIssueは、その2つの葉の中身を作る。後の収集（epic-00003）は `RepoConfig` を受け取り、執筆・配信・夜の実行は `Config` の置き場とモデルの経路を読む。

本人の決定（`content/decisions/20261126-journal-format-and-hackathon-plan.md` の 2）：対象は、SpecDockを使うrepositoryのうち、設定ファイルに前もって登録したものだけ。
"""

includes: [
	"新しいmodule `shipcast.config`：設定の型、置き場の決め方、読み込みと検証、`repo add` の書き足し",
	"新しいmodule `shipcast.repo`：`repo add` と `repo list` の引数と処理（CLIの葉）",
	"`src/shipcast/cli.py` の `COMMANDS` の `repo` の行に、2つの葉の `configure` を付ける変更（ほかの行は変えない）",
	"試験 `tests/test_config.py` と `tests/test_repo.py`、および `tests/test_cli.py` の「未実装の葉」の一覧から `repo add`・`repo list` を外す変更",
]

excludes: [
	"`repo remove` などの登録の削除・変更のコマンド（本人が設定ファイルを直接直す）",
	"設定の値を使う処理（収集、モデルの呼び出し、配信、夜の実行。各Issueが作る）",
	"`XDG_CONFIG_HOME` による置き場の変更（init-00001 の D-02 は `~/.config/shipcast/config.toml` と `SHIPCAST_CONFIG` だけを決めている）",
	"登録の時に、対象のrepositoryの既定のbranchを調べること（`ref` の既定は `main`、`--ref` で変えられる）",
	"README・設定の見本のファイル（`config.example.toml`）の追加（iss-00014 などの後のIssueに任せる）",
	"外部のモデル・外部のサービスの呼び出し",
]

requirements: {
	"R-01": {
		title: "設定ファイル（epic-00002 の D-02 の形）を読み、型のついた設定 `Config` にする"
		text: """
		`load_config(path=None)` が、`path` を省くと置き場の規則（環境変数 `SHIPCAST_CONFIG`、なければ `~/.config/shipcast/config.toml`）でファイルを決めて読む。値の形と範囲を確かめ、書かれていない項目に既定値を入れた `Config` を返す。
		"""
		acceptance: [
			"環境変数 `SHIPCAST_CONFIG` があればその場所を、なければ `~/.config/shipcast/config.toml` を読む。どちらの道筋も `~` を展開する",
			"epic-00002 の D-02 の見本と同じ内容のファイルを読むと、すべての値が型のついた項目（文字列、整数、真偽、`Path`）として取り出せる",
			"空のファイル、または一部の項目だけのファイルを読むと、書かれていない項目に既定値（epic-00002 の D-02 の値。`[[repos]]` は0件）が入る",
			"`journal_dir`・`state_dir`・`repos[].path`・`serve.design_system_dir` の `~` が展開され、絶対の `Path` になる",
			"`repos` は、ファイルに書かれた順の `RepoConfig` の並び（`tuple`）で、各 `RepoConfig` は `id`・`path`・`ref`・`title`・`orca` を持つ",
		]
	}
	"R-02": {
		title: "`shipcast repo add <path> [--id ID] [--title TITLE] [--ref REF]` で、repositoryを設定に足す"
		acceptance: [
			"`<path>/spec-dock/workspace.json` があるrepositoryは、設定の `[[repos]]` の末尾に1件足され、終了コード0で、足した `id` と絶対の `path` を標準出力に示す",
			"`<path>` がない・ディレクトリでない・`spec-dock/workspace.json` がないときは、足さずに終了コード1で止まり、設定ファイルを作らず、変えない",
			"同じ `id`、または同じ絶対の `path` がすでに登録されているときは、足さずに終了コード1で止まり、設定ファイルを変えない",
			"既存の設定ファイルの中身（行、コメント、空行、項目の順）は、1バイトも変わらずに先頭に残り、足した塊はその後に続く",
			"`--id` を省くと、ディレクトリの名前から `id` を作る（英小文字にし、英小文字・数字以外の連なりを `-` 1つにし、両端の `-` を除く）。`--title` を省くとディレクトリの名前、`--ref` を省くと `main`。`orca` は `true`",
			"対象のrepositoryの中のファイルを書き換えず、`git` を実行しない（読むのは `spec-dock/workspace.json` があるかだけ）",
		]
	}
	"R-03": {
		title: "`shipcast repo list` で、登録したrepositoryを示す"
		acceptance: [
			"登録した順に、1件1行で `id`・`title`・`path`・`ref` をタブで区切って標準出力に出し、終了コード0",
			"登録が0件のときは、標準出力に何も出さず、標準エラーに登録の仕方を示して終了コード0",
		]
	}
	"R-04": {
		title: "設定ファイルがないとき、`shipcast repo add` は既定の内容で作ってから足す"
		acceptance: [
			"親のディレクトリがなければ作り、既定の内容（epic-00002 の D-02 の項目と既定値、説明のコメント。`[[repos]]` の見本は含めない）の後に、足したrepositoryの塊を書く",
			"作ったファイルを `load_config` で読み直すと、足したrepositoryが1件あり、ほかの値は、空のファイルを読んだときの既定値と等しい",
			"作ったことを標準出力に示す",
		]
	}
}

failures: {
	"F-01": {
		title: "設定ファイルが壊れているときは、どこが・どう直すかを示して止まる"
		text: """
		- TOMLの文法の誤りは、ファイルの道筋と行の番号（`tomllib` の誤りの文）を示す。
		- 値の誤り（型の違い、許されない値、知らない項目、必須の項目の欠け、`id` の形、`id` の重複、絶対でない道筋、`schema` が1でない）は、ファイルの道筋と項目の名前（例 `repos[2].path`、`models.writer.route`）を示す。
		- どちらも、続けて「直し方:」の1行（何をどう書けばよいか）を示す。
		- `load_config` は `ConfigError` を投げ、CLIは標準エラーに示して終了コード1で終わる。`repo add` は書き足さず、ファイルを変えない。
		"""
	}
	"F-02": {
		title: "設定ファイルがないとき、`load_config` と `repo list` は、作り方を示して止まる"
		text:  "道筋と「直し方: `shipcast repo add <path>` で作れます」を示す。`load_config` は `ConfigError` を投げ、`repo list` は終了コード1で終わる。何も作らない。"
	}
}

constraints: [
	"repositoryはpublic。試験の見本は架空のdata（`tmp_path` の下に作る偽のrepositoryと設定）だけを使い、本人の実際の設定やrepositoryの名前を書かない（AGENTS.md）",
	"設定ファイルはrepositoryの外に置く。試験は `SHIPCAST_CONFIG` と `HOME` を `tmp_path` の下に向け、本人の `~/.config/shipcast/` に触れない",
	"情報源のrepositoryは読むだけ。`repo add` は `git` を実行せず、対象のrepositoryに何も書かない（AGENTS.md）",
	"実行時の依存は標準のライブラリだけ（`tomllib`、`argparse`、`dataclasses`、`pathlib`、`zoneinfo`、`re`、`os`、`tempfile`）。TOMLを書くライブラリを足さない",
	"外部のモデルを呼ばない。`agy` を呼ばない",
	"並行する iss-00010（`shipcast.model`・`shipcast.state`）とぶつからないよう、共有のファイルは `src/shipcast/cli.py` の `repo` の行と `tests/test_cli.py` の未実装の一覧だけを変える",
	"開発は通常の `coding-task`。マージは統括が行い、タスク担当と実装担当はマージしない（本人の決定 21）",
]

decisions: [
	"F-01 の「行を示す」は、TOMLの文法の誤りでは行の番号、値の誤りでは項目の名前で示す（`tomllib` は値の行を返さないため。タスク担当の判断、2026-11-26）",
	"知らない項目は誤りにする（打ち間違いを黙って既定値で動かさないため。後のIssueが項目を足すときは `shipcast.config` に足す。タスク担当の判断）",
	"同じ `id` に加え、同じ絶対の `path` の二重の登録も止める（同じrepositoryの日誌が2つできるのを防ぐ。タスク担当の判断）",
	"`--ref` を足す（`ref` は R-03 で示す項目で、`main` 以外のrepositoryを登録の時に指せるようにする。タスク担当の判断）",
	"終了コード：処理の誤り（設定の誤り、SpecDockのないrepository、重複）は1、使い方の誤りはargparseの2（iss-00008 の約束のまま）",
]
