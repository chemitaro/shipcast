package spec

goal: "見本の置き場で `/` に表紙（`:::cards`）、`/<repo>/` に一覧（`:::timeline`）が描かれ、前付けの値が形を崩さず、390pxの幅で横にはみ出さない状態で main へ入れる。"

steps: {
	"S-01": {
		title: "表紙と一覧のMarkdownと、前付けの値のエスケープ（画面の部分）"
		text: """
		D-03・D-04。`JournalDay`、`markdown_text`、`index_markdown`・`repo_markdown`、`index_page`・`repo_page` を `src/shipcast/page.py` に足す。T-01・T-02 を `tests/test_page.py` に先に書いて落ちることを確かめ（Red）、通す（Green）。D-05 の `NOT_FOUND_PAGE` の文もここで直す。
		完了の条件：`uv run pytest -q tests/test_page.py` と `uv run ruff check` が通る。
		"""
		realizes: ["R-01", "R-02", "R-03"]
		session:  "impl-ui"
		status:   "done"
	}
	"S-02": {
		title: "置き場を歩く関数と道筋、起動の表示とREADME、ブラウザーでの確かめ"
		text: """
		D-01・D-02・D-05・D-06。`split_path` の末尾の `/`、`journal_repos`・`journal_files`・`read_meta`・`journal_days`・`latest_journals`、`do_GET` の道筋、起動の表示、README。T-03〜T-05 を `tests/test_serve.py` に先に書いて落ちることを確かめ（Red）、通す（Green）。iss-00017 の試験のうち、`/`・`/demo-app/` を404とみなす項目と起動の表示の項目を、この仕様に合わせて直す。
		T-06：本物の `spec-dock/design-system/` と一時の見本の置き場（敵対的な題名・lead、長い名前を含む）で `shipcast serve` を立て、Orca の組み込みのブラウザーで表紙と一覧を確かめ、結果と画面の写しを報告に記録する。
		完了の条件：`test_commands` がすべて終了コード0で、T-06 の結果が報告にある。
		"""
		realizes: ["R-01", "R-02", "R-03", "R-04"]
		after:   ["S-01"]
		session: "impl-ui"
		status:  "doing"
	}
}

tests: {
	"T-01": {title: "`markdown_text` が `string.punctuation` の32字をすべて `&#NN;` にし、英数字・空白・ASCIIでない字（日本語）を変えない。結果は `(?:[^!-/:-@\\[-`{-~]|&#[0-9]+;)*` に全体が合う", verifies: ["R-03"]}
	"T-02": {title: "`index_markdown`：2つの repository の `latest` で `:::cards` の中に見出しが2つ、順が入力の順、見出しの行の末尾が `{href=/<repo>/<day> badge=<repo>,<day> more=この日を読む}`、本文が lead。`latest` が空なら `:::note まだ日誌がありません` と `shipcast run`。repos のリンク `/<repo>/`。`repo_markdown`：3日（2つの月にまたがる、1日は `meta` が `None`）で、月の見出しが新しい順に2つ、各 `:::timeline` の項目が新しい順、項目が `**[<day>](/<repo>/<day>)** — ` で始まり、`None` の日は固定の文、表紙へのリンク。`{href=https://evil.example}`・`## x`・`:::`・`**`・`[x](https://evil.example)`・`<img src=x onerror=alert(1)>` を含む題名と lead でも、見出しと項目の数が日の数と同じで、`evil.example` へのリンクの書き方（`](https://`、`href=https`）と `<img` が Markdown に出ない", verifies: ["R-01", "R-02", "R-03"]}
	"T-03": {title: "`split_path`：`/demo-app/` → `(\"demo-app\", \"\")`、`/_ds/vendor/` → `(\"_ds\", \"vendor\", \"\")`、`/demo-app//`・`//x`・`/a//b` → `None`、`/` → `()`。iss-00017 の表のほかの項目は変わらない", verifies: ["R-02"]}
	"T-04": {title: "置き場を歩く関数：`journal_repos` が `.x`・`Demo`・ファイル・外への symlink のディレクトリを除いて名前の順。`journal_files` が新しい順で、`2026-02-30.md`・`2025/2026-01-01.md`（年が違う）・`.2026-11-01.md`・`notes.txt`・外への symlink のファイルと年のディレクトリを除く。`latest_journals` が前付けの壊れた最新の日を飛ばして次の日を取り、読めない日だけの repository を出さず、日付の新しい順。壊れた日で `on_error` が呼ばれる。置き場がないとき `[]`", verifies: ["R-01", "R-02", "F-01", "F-02"]}
	"T-05": {title: "配信：`/` が200で `ds-source` に `:::cards` と2枚の見出し（新しい順）、置き場の外の symlink の印の文字列が応答に出ない。空の置き場・置き場がないときも200で `まだ日誌がありません`。`/demo-app/` が200で `:::timeline`、壊れた日の固定の文、`<title>` が `demo-app の日誌`。`/demo-app` が301で `Location: /demo-app/`。`/nothing/`・`/Demo/`・`/demo-app/2026-11-26/`・`/demo-app//`・`/_ds/` が404。どの応答にも `security_headers()` の3つ。`HEAD /` は同じ状態で本文が空。起動の表示が `http://<authority>/ で日誌を読めます`", verifies: ["R-01", "R-02", "F-01", "F-02"]}
	"T-06": {title: "実際のブラウザー（Orca の組み込みのブラウザー）で、本物のデザインシステムの下で、表紙のカードと一覧の時系列が描け、敵対的な題名・lead が文字で見えて `onerror` が動かず、390px と 1280px の幅で `scrollWidth <= clientWidth`、CSPの違反がコンソールにない（S-02 で手で確かめ、報告に記録する）", verifies: ["R-03", "R-04"]}
}

verification: "`test_commands` を順に流し、すべて終了コード0。S-02 で T-06 をブラウザーで確かめて報告に記録する。PRを作った後に、`github-pr-checks` でCIの合格を観測する。"
rollback:     "PRを戻す（revert）だけで、`/` と `/<repo>/` は404に戻る。配信は読むだけで、本人の手元のファイルを書かない。"
exit:         "PRが最終品質ゲートとCIに合格し、タスク担当が統括にPR・合格のコミット・CIの結果を報告した時点で、このIssueの作業は終わる。マージと `spec-dock work finish` は統括が行う。"

// 関門（coding-task）。保証レベル light の既定に従う。
gates: {
	spec_review: "Claude `spec-reviewer`（Opus 5.5 / medium。light の既定）。P0・P1がなくなるまで、3回まで"
	checkpoints: "なし（2つの手順を同じセッションが続けて行い、最終品質ゲートで全体を見る）"
	final_quality_gate: {
		scope:               "開始のコミット `b7832b86e0ac3e538729e4b06f9fcb321ab8e563`（このworktreeの作業の始めの `HEAD`）から S-02 まで"
		perspectives:        ["functional-correctness", "requirements-closure", "test-adequacy", "security"]
		perspectives_reason: "`security`：前付けの値を表紙と一覧のMarkdownに入れるエスケープと、置き場を歩くときのパスの検査"
		test_commands:       ["uv sync --locked", "uv run ruff check", "uv run pytest -q", "uv run shipcast serve --help"]
		record_paths:        ["spec-dock/initiatives/00000-00999/iss-00018/report.md（SpecDockの自動の保存で記録する。Gitのcommitは要らない）", "spec-dock/initiatives/00000-00999/iss-00018/plan.cue の各 step の `status`"]
		second_opinion:      "none"
	}
	merge:  "agent"
	merger: "統括がマージする（coordinated の使い方。`coding-task` の `references/merge.md`、CIの合格の観測を含む）。タスク担当はマージしない"
	pr:     "branchは `chemitaro/iss-00018`。PRの本文に、合格のコミット、最終品質ゲートの結果、CIの結果、T-06 の結果を書く。Issueを自動で閉じる書き方（Closes #18）は使わない"
}

execution: {
	sessions: {
		spec: {task: "仕様化（起動した側が選んだ値の記録）", provider: "claude", model: "Claude Opus 5.5", effort: "medium", rationale: "統括が起動したOrcaの作業者（タスク担当）。値は統括が方針§2の light のタスク担当の行で決めた（事実の記録）"}
		owner: {task: "タスク担当（仕様、レビュー、最終品質ゲート、PR、CIの観測）", provider: "claude", model: "Claude Opus 5.5", effort: "medium", rationale: "方針§2のタスク担当の light の行"}
		"impl-ui": {task: "実装 S-01・S-02（表紙と一覧の画面、道筋、置き場を歩く関数、ブラウザーでの確かめ）", provider: "claude", model: "Claude Opus 5.5", effort: "medium", rationale: "本人の決定 20（画面のデザインは Opus 5.5 が直接実装）と方針§2のフロントエンドの light の行。タスク担当と同じモデルで手順が2つなので、同じセッション（タスク担当）が実装する"}
	}
	reviews: {
		final_gate: {role: "最終品質ゲートの `quality-gate-reviewer`", after: "S-02", model: "Claude Opus 5.5", effort: "medium"}
	}
	assignment:   "S-01・S-02 → impl-ui（連続）"
	same_session: "impl-ui はタスク担当のこのセッションが実装する（`coding-task` の手順5の同じセッションの例外：実装の手順が2つ以下で、実装担当がタスク担当と同じモデル。本人の決定 20 が画面の部分を Opus 5.5 に割り当てる）"
}
