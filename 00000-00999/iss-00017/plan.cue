package spec

goal: "見本の日誌（tests/fixtures）で `shipcast serve` を立て、日誌のページとデザインシステムのファイルを安全に返す。iss-00018（表紙と一覧）が `shipcast.page` と `shipcast.serve` に足すだけで済む形にして main へ入れる。"

steps: {
	"S-01": {
		title: "包む関数と案内のページ（画面の部分）"
		text: """
		D-01、D-02、D-10 の見本の日誌と `html5lib`。`uv add --dev html5lib` で dev group に足す。`tests/fixtures/journal/demo-app/2026/2026-11-26.md`（架空）を置く。T-01 と T-10 のうち `notice_page` の部分を `tests/test_page.py` に先に書いて落ちることを確かめ（Red）、`src/shipcast/page.py` の `wrap_markdown`・`notice_page`・`NOT_FOUND_PAGE`・`BROKEN_JOURNAL_PAGE` で通す（Green）。
		完了の条件：`uv run pytest -q tests/test_page.py` が通り、`uv run ruff check` が通る。
		"""
		realizes: ["R-01", "F-03"]
		session:  "impl-ui"
		status:   "done"
	}
	"S-02": {
		title: "道筋の読み取り、パスの検査、ヘッダー、Hostの検査の関数"
		text: """
		D-03 の `split_path`・`resolve_inside`・拡張子の表、D-04 の `security_headers`、D-05 の `host_allowed`。T-03・T-05・T-08 の関数の部分を `tests/test_serve.py` に先に書いて落ちることを確かめ（Red）、`src/shipcast/serve.py` で通す（Green）。配信はまだ立てない。
		完了の条件：`uv run pytest -q tests/test_serve.py` と `uv run ruff check` が通る。
		"""
		realizes: ["F-02", "F-04", "F-05"]
		after: ["S-01"]
		session: "impl"
		status:  "done"
	}
	"S-03": {
		title: "配信の部品と道筋、デザインシステムの確かめ、`shipcast serve` の葉"
		text: """
		D-03 の道筋、D-04 の出口（`end_headers`）、D-06、D-07、D-08（`cli.py` の接続と `tests/test_cli.py` の1行）。T-02〜T-06・T-08〜T-10 の配信の部分を先に書いて落ちることを確かめ（Red）、`create_server`・`find_design_system`・`configure`・`run` で通す（Green）。日誌のページは S-01 の `wrap_markdown`、404・500は `NOT_FOUND_PAGE`・`BROKEN_JOURNAL_PAGE` を使い、`shipcast.page` を変えない（変える必要があればタスク担当に問う）。
		完了の条件：`test_commands` がすべて終了コード0。
		"""
		realizes: ["R-01", "R-02", "R-03", "F-01", "F-02", "F-04", "F-05"]
		after: ["S-02"]
		session: "impl"
		status:  "done"
	}
	"S-04": {
		title: "READMEの手順と、ブラウザーでの描画の確かめ"
		text: """
		D-09 の README の節と、T-06 の README の部分の試験。T-07：この repository の `spec-dock/design-system/` を `design_system_dir` にした一時の設定と見本の日誌で `shipcast serve` を立て、Orca の組み込みのブラウザーで、部品・図・コードの色分けが描け、`<img onerror>` が動かず、`</script>` のコードが文字のまま見え、390px の幅で横にはみ出さず、CSPの違反がコンソールに出ないことを確かめ、画面の写しと結果を報告に記録する。描けないときだけ D-04 の許可を最小に足し、仕様の変更としてタスク担当（自分）が仕様のレビューをやり直す。
		完了の条件：`test_commands` がすべて終了コード0で、T-07 の結果が報告にある。
		"""
		realizes: ["R-01", "R-03", "F-03", "F-04"]
		after: ["S-03"]
		session: "impl-ui-verify"
		status:  "done"
	}
}

tests: {
	"T-01": {title: "`</script>`・`</SCRIPT >`・`</script/`・閉じない `<!--<script>`・閉じた `<!-- <script> -->`・末尾の `<!--`・末尾の `<script`・末尾の `<!-`・末尾の `<` を含むMarkdownを `wrap_markdown` で包み、`html5lib` で読むと、`ds-source` がちょうど1つで、その `textContent` に ds.js と同じ戻しをすると `\"\\n\" + 元のMarkdown + \"\\n<!-- -->\\n\"`（`</SCRIPT` は小文字）になり、`/_ds/ds.js` の `<script>` が `head` にある。`ſ` を含む `</ſcript` は置き換えない", verifies: ["F-03"]}
	"T-02": {title: "見本の日誌のページが200・`text/html; charset=utf-8` で、`ds-source` と `/_ds/ds.css`・`/_ds/ds.js` の読み込みがあり、`<title>` が前付けの `title`（`<b>` を含む題名はエスケープされる）。`/_ds/ds.css`・`/_ds/ds.js`・`/_ds/vendor/marked.umd.js` が表の `Content-Type` で200、中身がバイト列で同じ。`HEAD` は同じ状態・ヘッダーで本文が空", verifies: ["R-01", "R-02"]}
	"T-03": {title: "`/_ds/../x`・`/_ds/%2e%2e/x`・`/_ds/..%2fx`・`/_ds/%2e%2e%2fx`・`/_ds/..%5cx`・`//x`・`/_ds//ds.css`・`/_ds/.x`・`/_ds/%00`・`/_ds/%ff`、置き場の外へのsymlink（デザインシステムの中のファイル、日誌のファイル、repoのディレクトリ）、`/_ds/explanation-skeleton.html`・`/_ds/vendor` が404になり、外のファイルの印の文字列が応答に出ない。`split_path` と `resolve_inside` の単独の試験を含む", verifies: ["F-02", "R-02"]}
	"T-04": {title: "デザインシステムがないとき（登録なし、`design_system_dir` に `ds.js` がない、repositoryに `spec-dock/design-system/` がない）、`shipcast serve` が終了コード2で、標準エラーに見た場所・設定ファイルの道筋・`design_system_dir` の書き方があり、待ち受けを作らない。1件目のrepositoryになく2件目にあるときは2件目を使う。`design_system_dir` を書いたのにないときは、repositoryにあっても使わない", verifies: ["F-01"]}
	"T-05": {title: "200（ページ・デザインシステム）、404、405、400（Host）、500（壊れた日誌）、501（知らない方法）のすべての応答に、`security_headers()` の3つ（CSPは D-04 の文字列と同じ）があり、`Server` にPythonの版がない。CSPの `script-src` は unpkg.com のオリジン全体を含まず、許す2つの道筋の版がこの repository の `spec-dock/design-system/ds.js` の `PLANTUML_VERSION`・`HLJS_VERSION` と同じ", verifies: ["F-04"]}
	"T-06": {title: "既定の設定で `shipcast serve` を `--host` なしで実行すると `create_server` が `127.0.0.1`・`8765` で呼ばれ、`--host 0.0.0.0 --port 9000` ではその値と標準エラーの案内。READMEに `shipcast serve`・`tailscale serve --bg 8765`・止め方・Funnel の注意がある", verifies: ["R-03"]}
	"T-07": {title: "実際のブラウザー（Orca の組み込みのブラウザー）で、本物のデザインシステムとCSPの下で、見本の日誌の部品・図・コードの色分けが描け、`<img onerror>` が動かず、`</script>` を含むコードが文字で見え、390px の幅で横にはみ出さず、CSPの違反がない。本文に `<meta name=\"ds-vendor-base\" content=\"https://unpkg.com/<ほかのパッケージ>/\">` を含む日誌では、その先のscriptの要求がCSPで拒まれ、色分けは決まった版から読まれる（S-04 で手で確かめ、報告に記録する）", verifies: ["R-01", "F-03", "F-04"]}
	"T-08": {title: "`host_allowed` の表（`127.0.0.1:8765`・`[::1]:8765`・`localhost`・`mac.tail1234.ts.net`・`mac` は真、`evil.example`・`127.0.0.1.evil.example`・`ts.net.evil.example`・空・`None` は偽）と、Hostが `evil.example` の要求・Hostのない要求（HTTP/1.0）が400で、日誌の中身が応答に出ない", verifies: ["F-05"]}
	"T-09": {title: "設定ファイルがない・壊れているときは終了コード1で標準エラーに `直し方:`。ポートが使用中なら終了コード1で理由。日誌の置き場がないときは案内を出して立つ。`serve_forever` が `KeyboardInterrupt` を受けると終了コード0", verifies: ["R-03"]}
	"T-10": {title: "日誌のない日、形の違う `<repo>`（`Demo`）・日付（`2026-02-30`・`20261126`）、`/`・`/demo-app/` は404の案内のページ、前付けの壊れた日誌・UTF-8でない日誌は500の案内のページで、どちらもデザインシステムで描く形（`ds-source` がある）で、本文に要求の道筋と日誌の置き場の道筋が出ない", verifies: ["R-01"]}
}

verification: "`test_commands` を順に流し、すべて終了コード0。S-04 で T-07 をブラウザーで確かめて報告に記録する。PRを作った後に、`github-pr-checks` でCIの合格を観測する。"
rollback:     "PRを戻す（revert）だけで、`shipcast serve` は未実装の応答に戻る。配信は読むだけで、本人の手元のファイルを書かない。本人が `tailscale serve` を設定していたら `tailscale serve --https=443 off` で外す。"
exit:         "PRが最終品質ゲートとCIに合格し、タスク担当が統括にPR・合格のコミット・CIの結果を報告した時点で、このIssueの作業は終わる。マージと `spec-dock work finish` は、統括が本人に確かめてから行う。"

// 関門（coding-task）。保証レベル strict の既定と、本人の決定 18〜21・24 に従う。
gates: {
	spec_review: "Claude `spec-reviewer`（Opus 5.5 / high）と ChatGPT（GPT-6 / Extra High、`chatgpt-spec-review-strict`）の2人目。P0・P1がなくなるまで、3回まで"
	checkpoints: {
		"CP-1": {
			last_step: "S-03"
			range:     "開始のコミットから S-03 の後の `HEAD` まで"
			reviewers: "Claude `code-reviewer`（Opus 5.5 / medium。strict の既定）"
			reason:    "S-03 で、tailnetから読まれる配信の境界（パスの検査、ヘッダー、Hostの検査、道筋）が固まる。S-04 の確かめの前に、境界の誤りを止める"
		}
	}
	final_quality_gate: {
		scope:               "開始のコミット（このworktreeの作業の始めの `HEAD`）から S-04 まで"
		perspectives:        ["functional-correctness", "requirements-closure", "test-adequacy", "security", "api-contract"]
		perspectives_reason: "`security`：tailnetから読まれる配信の境界（パス、エスケープ、CSP、Host）。`api-contract`：`shipcast.page`・`shipcast.serve` は iss-00018 が使う約束"
		test_commands:       ["uv sync --locked", "uv run ruff check", "uv run pytest -q", "uv run shipcast serve --help"]
		record_paths:        ["spec-dock/initiatives/00000-00999/iss-00017/report.md（SpecDockの自動の保存で記録する。Gitのcommitは要らない）", "spec-dock/initiatives/00000-00999/iss-00017/plan.cue の各 step の `status`"]
		second_opinion:      "chatgpt"
	}
	merge:  "owner"
	merger: "統括が本人に確かめてからマージする（strict。本人の決定 21）。タスク担当と実装担当はマージしない。条件は `coding-task` の `references/merge.md`（CIの合格の観測を含む）"
	pr:     "branchは `iss-00017`（このworktreeの `chemitaro/iss-00017` を SpecDock の作業の開始で揃える）。PRの本文に、合格のコミット、最終品質ゲートの結果、CIの結果、T-07 の結果を書く。Issueを自動で閉じる書き方（Closes #17）は使わない"
}

execution: {
	sessions: {
		spec: {task: "仕様化（起動した側が選んだ値の記録）", provider: "claude", model: "Claude Opus 5.5", effort: "high", rationale: "統括が起動したOrcaの作業者（タスク担当）。値は統括が方針§2の strict のタスク担当の行で決めた（事実の記録）"}
		owner: {task: "タスク担当（仕様、レビュー、区切りのレビュー、最終品質ゲート、PR、CIの観測）", provider: "claude", model: "Claude Opus 5.5", effort: "high", rationale: "方針§2のタスク担当の strict の行"}
		"impl-ui": {task: "実装 S-01（ページの枠と案内のページ。画面の部分）", provider: "claude", model: "Claude Opus 5.5", effort: "high", rationale: "本人の決定 20 と方針§2のフロントエンドの strict の行。タスク担当と同じモデルなので同じセッション（タスク担当）が実装する"}
		impl: {task: "実装 S-02・S-03（ロジック：道筋、パスの検査、ヘッダー、Host、配信、CLI）。このworktreeのOrcaの作業者", provider: "codex", model: "GPT-6.2 Sol", effort: "medium", rationale: "方針§2の、テストで確かめられる実装の strict の行と本人の決定 19"}
		"impl-ui-verify": {task: "実装 S-04（README と、実際のブラウザーでの描画の確かめ）", provider: "claude", model: "Claude Opus 5.5", effort: "high", rationale: "本人の決定 20（表示の確かめ）と方針§2のフロントエンドの strict の行。タスク担当と同じモデルなので同じセッションが行う"}
	}
	reviews: {
		"cp-1": {role: "区切りのレビューの `code-reviewer`", after: "S-03", model: "Claude Opus 5.5", effort: "medium"}
		final_gate: {role: "最終品質ゲートの `quality-gate-reviewer`", after: "S-04", model: "Claude Opus 5.5", effort: "high"}
		final_gate_second: {role: "最終品質ゲートの2人目（`chatgpt-final-quality-gate-strict`。取れないときは GPT-6.2 Astra / high）", after: "S-04", model: "ChatGPT GPT-6", effort: "Extra High"}
	}
	assignment:   "S-01 → impl-ui、S-02・S-03 → impl（連続）、S-04 → impl-ui-verify"
	same_session: "impl-ui と impl-ui-verify はタスク担当のこのセッションが実装する（`coding-task` の手順5：実装担当がタスク担当と同じモデル。本人の決定 20 が画面の部分を Opus 5.5 に割り当てる）。impl は Codex の別のOrcaの作業者"
}
