package spec

schema: "specdock/v1"

assurance: {
	level:  "light"
	reason: "手元に下書きのファイルを作るだけで、投稿はしない（本人が行う）。誤っても下書きを消せば元に戻る"
}

purpose: "`shipcast draft x --repo <id>` で、未消化の話題の上位から、書き手のモデルでXの投稿の下書き（本文とハッシュタグの案）を作り、状態の置き場の `drafts/<repo>/<日付>-x.md` に置き、使った話題を消化済みにする。外へは何も投稿しない。"

background: """
親の epic-00006 の R-03 と D-03 を、このIssueが受け持つ（epic-00006 の `plan.cue` の `slices`）。`main` にすでにある次のものを、名前を変えずに使う。

- `shipcast.state.Store`：`unconsumed_stories(repo_id, *, limit=None) -> list[Story]`（点数1以上の未消化の話題を、台帳の点数の大きい順・台帳に入った順で返す。iss-00019）、`neta_balance(repo_id)`、`consume_neta(story_ids) -> int`（iss-00010）
- `shipcast.models.get_route(ModelConfig, ...)`：経路（`fake` を含む）。`GuardedRoute.complete` は送る前に秘密らしい文字列を伏せ、エージェントの中では `antigravity` の経路を拒む（iss-00014）
- `shipcast.config.load_config()`：`Config.models.writer`、`Config.state_dir`、`Config.timezone`、`Config.repos`
- `shipcast.write.write_atomic(path, text)`：同じフォルダーに書き終えてから置き換える（iss-00016）
- `shipcast.cli`：`draft` の下の `x` は今は未実装の印（`not_implemented`）で、`iss-00020` を指している

先行のIssueからの申し送り：

- iss-00019：`unconsumed_stories` は iss-00020 のために足した。話題を消化すること（`consume_neta` を呼ぶこと）は iss-00020 が受け持つ。
- 並行の iss-00021（`shipcast run`）が別のworktreeで進む。共有のファイル（特に `cli.py` と `tests/test_cli.py`）の変更を最小にする。
- 本人の決定（`content/decisions/20261126-journal-format-and-hackathon-plan.md` の 17）：おまけはネタポイントの印とXの下書き1本までをハッカソンの範囲に入れる。noteは後に回す。
"""

requirements: {
	"R-01": {
		title: "未消化の話題の上位から、Xの本文とハッシュタグの案を、書き手のモデルで作る"
		text:  "`shipcast draft x --repo <id>` が、その repository の未消化の話題（点数1以上）を、点数の大きい順に最大3件選び、設定の書き手（`models.writer`）の経路に、話題の題名・何をしたか・なぜかだけを渡して、Xの本文とハッシュタグの案（0〜3個）を頼む。応答が決まった形に合わなければ、誤りを添えて一度だけ頼み直す。"
		acceptance: [
			"本文とハッシュタグを合わせた投稿の全体が、Xの数え方（日本語の文字は2、英数字は1）で280以内になる（日本語なら140字程度）",
			"本文に URL（`http://`・`https://`）と `@` の宛先が入らない。ハッシュタグは `#` で始まる1語で、数字だけではない",
			"書き手に渡す入力は、選んだ話題の `title`・`what`・`why` と repository の id・日付だけで、`notice`・`waiting`・出来事は渡さない",
			"2回とも形に合わなければ、下書きを置かず、話題も消化せず、終了コード1で誤りの箇所を示す",
		]
	}
	"R-02": {
		title: "下書きを `drafts/<repo>/<日付>-x.md` に置き、使った話題を消化済みにする"
		text:  "下書きを、状態の置き場（設定の `state_dir`）の `drafts/<repo>/<日付>-x.md` に Markdown で置く。日付は `--date`（既定は設定のタイムゾーンでの今日）。置けた後にだけ、使った話題を台帳で消化済みにする。外へは投稿しない。"
		acceptance: [
			"下書きのファイルに、本文、ハッシュタグの案、Xの数え方での長さ、使った話題の題名、「shipcastは投稿しない。本人が確かめて投稿する」旨の注意が入る",
			"下書きを置いた後、使った話題が `unconsumed_stories` から消え、`neta_balance` がその点数の分だけ減る。選ばなかった話題は未消化のまま",
			"同じ日付の下書きがすでにあれば、モデルを呼ばず、上書きせず、話題も消化せず、終了コード1で止まる",
			"未消化の話題がなければ、モデルを呼ばず、ファイルを作らず、終了コード1で知らせる",
			"外部への投稿の API を呼ばない（shipcast に投稿の経路がない）",
		]
	}
}

includes: [
	"新しい `src/shipcast/draft.py`：Xの長さの数え方、応答の検査、書き手への依頼、下書きのMarkdownの組み立て、置き場の道筋、CLI の `configure_x`・`run_x`",
	"新しい `src/shipcast/prompts/x.md`：Xの下書きの書き手への指示",
	"`src/shipcast/cli.py`：`draft x` の `Entry` に `draft.configure_x` を渡す配線と、`draft` の import の1行だけ",
	"試験：新しい `tests/test_draft.py`、`tests/test_cli.py` の未実装の一覧から `draft x` を外す",
]

excludes: [
	"X・note・Redditなど外部への投稿、外部の投稿のAPI、認証情報（AGENTS.md の「外へ投稿しない」）",
	"note・Reddit の下書き（本人の決定 17 で後に回す）",
	"発信の公開の方針（設定の公開範囲・NGワード）による話題の絞り込み。設定にまだその項目がない。書き手に渡す項目を `title`・`what`・`why` に絞り、経路の伏せ字と、本人の確認に任せる（残る危険として記録する）",
	"下書き・承認・投稿済みの状態の区別と確認の画面（構想の pending → published。後に回す）。このIssueでは、下書きを置いた時点で消化済みにする（epic-00006 の R-03）",
	"しきい値（`neta.threshold`）による制限。本人が明示に `draft x` を頼んだときは、残高がしきい値未満でも、未消化の話題があれば下書きを作る",
	"`shipcast run`（iss-00021）・`schedule`（iss-00022）からの呼び出し",
	"`Store`・表の形・`write.py`・`neta.py` の変更",
]

constraints: [
	"外部のモデルと `agy` を呼ばない。試験は fake の経路の `responder` と一時ディレクトリだけで行う",
	"publicのrepositoryなので、試験の見本は架空のもの（`demo-app` など）にする",
	"`cli.py` と `tests/test_cli.py` の変更は、`draft x` の配線の最小の差分にする（並行の iss-00021 との衝突を避ける）",
]

decisions: [
	"長さの上限は、本文とハッシュタグを空行でつないだ投稿の全体に掛ける。そのまま貼って投稿できるようにするため（タスク担当の判断、同じ範囲）",
	"Xの数え方は、X の公開の数え方（twitter-text の重み）の要点に合わせる：NFC に正規化した後、U+0000〜U+10FF、U+2000〜U+200D、U+2010〜U+201F、U+2032〜U+2037 の文字は1、ほかは2。URL を許さないので、URL の短縮の数え方は持たない（タスク担当の判断、同じ範囲）",
	"選ぶ話題は最大3件（`unconsumed_stories(repo_id, limit=3)`）。1本の短い投稿に入る量で、日誌の「発信の芽」に並ぶ題名と同じ件数（タスク担当の判断、同じ範囲）",
	"同じ日付の下書きがあるときは上書きしない。上書きすると、先に消化した話題の下書きが失われるため（タスク担当の判断、同じ範囲）",
	"消化は下書きを置けた後に行う。置く前に落ちても話題は残る。置いた後の消化で落ちると、下書きはあり話題は未消化のまま残る（同じ日付では再実行が止まる。残る危険として記録する）（タスク担当の判断、同じ範囲）",
	"`--repo` は必須にする（epic-00006 の R-03 の `shipcast draft x --repo <id>`）（タスク担当の判断、同じ範囲）",
	"下書きは状態の置き場の下に置き、日誌の置き場（`journal_dir`）には置かない。`shipcast serve` が配らないようにし、epic-00006 の R-03 の「状態の置き場の `drafts/`」に合わせる（タスク担当の判断、同じ範囲）",
]
