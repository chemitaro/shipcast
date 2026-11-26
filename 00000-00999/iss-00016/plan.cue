package spec

goal: "書き手の応答の形とプロンプトを先に固め、その上に数と組み立て・拡張点・置き換えを積み、最後に書き手への依頼と1日の流れとCLIをつなぐ。試験は fake の経路の `responder` と一時ディレクトリだけで行う。"

steps: {
	"S-01": {
		status:   "done"
		title:    "書き手のプロンプトと応答の形（`parse_draft`）"
		text:     "D-01・D-08。T-01・T-02・T-03 を `tests/test_write.py` に先に書いて落ちることを確かめ（Red）、`src/shipcast/prompts/write.md` と、`src/shipcast/write.py` の `PROMPT_PATH`・プロンプトを読む関数・`Draft`・`parse_draft` を書いて通す（Green）。完了の条件：その試験が通り、`uv run ruff check` が通る。"
		realizes: ["R-02", "F-02"]
		session:  "impl"
	}
	"S-02": {
		status:   "doing"
		title:    "数（`count_metrics`）、組み立て（`build_entry`）と拡張点、置き換え（`write_atomic`）"
		text:     "D-03・D-04・D-05・D-06。T-04〜T-08 を先に書いて Red、`Metric`・`count_metrics`・`_inline`・`build_entry`・`JournalExtension`・`EXTENSIONS`・`write_atomic` を書いて Green。完了の条件：`test_commands` がすべて終了コード0。"
		realizes: ["R-02", "R-03", "R-04", "R-05", "F-01", "F-02"]
		after:    ["S-01"]
		session:  "impl"
	}
	"S-03": {
		status:   "todo"
		title:    "書き手への依頼（`compose`）、1日の流れ（`write_day`）、CLI `shipcast write`"
		text:     "D-02・D-07。T-09〜T-12 を先に書いて Red、`MAX_ATTEMPTS`・`WriteFailed`・`compose`・`WriteResult`・`write_day`・`configure`・`run` を書き、`cli.py` の `write` の葉に `write.configure` を渡し、`tests/test_cli.py` の未実装の一覧から `write` を外して Green。完了の条件：`test_commands` がすべて終了コード0。"
		realizes: ["R-01", "R-02", "R-03", "F-01", "F-02"]
		after:    ["S-02"]
		session:  "impl"
	}
}

tests: {
	"T-01": {title: "`parse_draft` が正しい応答（`lead`・`summary` 3件・`story` に `###` の見出し2つ）から、前後の空白を除いた `Draft` を返し、誤りが空。```` ```json ```` の囲みと前後の空白に包まれていても読め、知らない鍵は捨てられる", verifies: ["R-02"]}
	"T-02": {title: "`parse_draft` の誤りの表（パラメーター化）：W-01（JSONでない・空・`NaN`・深すぎる入れ子）、W-02（配列が全体）、W-03（`lead` がない・空白だけ・改行を含む・201文字・`<!--` を含む・数）、W-04（`summary` がない・空の配列・6件・要素が空白だけ・改行を含む・`<b>` を含む・`:::tip` で始まる・数）、W-05（`story` がない・空白だけ・行頭の `:::warning`・行頭の空白の後の `:::`・文の途中の `:::`・`- :::tip`・`> :::metrics`・`## 見出し`・`# 見出し`・`#`だけの行・`1. ## 見出し`・`> # 見出し`・段落の次の `===` の行・段落の次の `---` の行・閉じない ```` ``` ````・`~~~`・`- ```` ``` `````・`<script>`・`<!-- x -->`）、W-06（`lead`・`summary` の要素・`story` に、JSONのエスケープ `\\ud800` で入れた対のないサロゲート）。それぞれ `Draft` が `None` で、誤りが1件以上、期待する場所の文字列を含み、応答に入れた目印の値を含まない。`### 小見出し`・`- ### 項目`・`a < b`・`- 箇条書き`・`1. 番号つき`・`> 引用` は誤りにならない", verifies: ["R-02", "F-02"]}
	"T-03": {title: "`prompts/write.md` が `importlib.resources` で読め、`要約＋読み物`・`です・ます調`・`lead`・`summary`・`story`・`:::`・`previous_errors`・`話題にない事実` を含み、`redact()` を通しても変わらない", verifies: ["R-02", "F-02"]}
	"T-04": {title: "`count_metrics` に、架空の出来事（git の merge 2件・commit 3件、SpecDock の scope_closed 1件・scope_opened 1件・todo_open 3件（うち1件は同じ todo のIDの todo_done がある）・todo_done 1件、Orca の conversation 1件、同じIDの重複1件）を渡すと、`merge` 2・`commit` 3・`閉じたScope` 1・`新しい本人待ちのtodo` 2 をこの順で返す。空の入力では4つとも0", verifies: ["R-04"]}
	"T-05": {title: "`build_entry` が、見本（話題2件で notice と waiting を持つ、出来事、`Draft`、`analyst=\"fake/fake-analyst\"`・`writer=\"fake/fake-writer\"`、時間帯つきの `generated_at`）から、D-04 の形の全文（試験に書いた期待の文字列）と等しい文字列を返す。`parse_journal` で読むと前付けの9項目が期待の値で、`write_frontmatter` の形と等しい。notice も waiting もない話題だけなら `:::warning`・`:::checklist` の塊がない。notice の `<script>alert(1)</script>` と改行を含む値は、`&lt;script&gt;` を含む1行になり、全文に `<script` が現れない。`_inline` の表（パラメーター化）：`:::tip 偽` → `\\:::tip 偽`、`## 見出し` → `\\## 見出し`、`- 入れ子` → `\\- 入れ子`、`1. 番号` → `1\\. 番号`、```` ``` ```` → `` \\` `` で始まる、`a & b` → `a &amp; b`、` 前後 ` → `前後`。notice が空白だけの要素しかない話題だけなら `:::warning` の塊がない（waiting も同じ）。出来事が1件以上で `draft=None` なら `ValueError`", verifies: ["R-01", "R-02", "R-04", "F-02"]}
	"T-06": {title: "`build_entry` に、`:::tip 発信の芽` の囲みを返す試験用の部品と、`None` を返す部品と、空白だけを返す部品を渡すと、`:::metrics` の塊の後に空行1つを挟んで `:::tip` の囲みが1つだけ足され、それがファイルの最後の塊になる。部品は `(repo_id, day, stories, events)` を受け取る。`EXTENSIONS == ()` で、`extensions` を省いた結果は空の一覧を渡した結果と等しい。部品が例外を投げると、その例外がそのまま上がる。`monkeypatch` で `shipcast.write.EXTENSIONS` を差し替えると、`extensions` を省いた `build_entry` と `write_day` がその部品を使う", verifies: ["R-05"]}
	"T-07": {title: "出来事が0件の `build_entry` が、前付け（`title`・`lead`=「大きな動きはありませんでした。」・`date`・`repo`・`category`・`generated_at`・`schema`。`analyst`・`writer` はない）と空行と「大きな動きはありませんでした。」の1行だけを返し、渡した拡張点の部品は呼ばれない", verifies: ["R-03"]}
	"T-08": {title: "`write_atomic` が、ない親フォルダーを作って書き、既にあるファイルを置き換える。`os.replace`（または `os.fsync`）を差し替えて例外を投げさせると、その例外が上がり、前のファイルの中身が変わらず、フォルダーに一時ファイル（`.<名前>.…tmp`）が残らない", verifies: ["F-01"]}
	"T-09": {title: "`compose`：1回目が W-05 の誤り、2回目が正しい応答の `responder` で、呼び出しが2回、2回目の prompt が `json.loads` で読め、`stories` が1回目と同じ、`previous_errors` に `story` を含む誤りが入る。1回目が正しければ1回。どの呼び出しも `want_json=True` で、system が `prompts/write.md` の本文の後に `\\n\\n` と `JSON_INSTRUCTION` を足したもの。prompt の `stories` の各要素の鍵がちょうど `title`・`what`・`why`・`notice`・`waiting` で、出来事の本文（試験で入れた目印）を含まない。2回とも誤りなら `WriteFailed`（`attempts == 2`、文が「書き手の応答が2回とも決まった形になりませんでした」で始まり、応答の目印を含まない）。`RouteFailed` はそのまま上がり、呼び出しは1回。空の `stories` は `ValueError` で、呼ばれない", verifies: ["F-01", "F-02"]}
	"T-10": {title: "`write_day`：架空の出来事を入れた `Store` と、同じ日の古い話題（目印の題名）を先に `save_stories` した状態で、fake の分析と書き手の `responder` で書くと、`journal_path` のファイルの全文が `build_entry` に `analyze` の戻り値を渡したものと等しく、古い話題の目印を含まない。`entry_for` がパス・`analyst`・`writer`・話題のIDの順を返す。出来事が0件の日は、両方の `responder` が呼ばれず、1行の日誌ができ、`entry_for` の `analyst`・`writer` が `none`、`story_ids` が空", verifies: ["R-01", "R-03"]}
	"T-11": {title: "`write_day` の失敗：既に日誌のファイルと `entries` がある日に、(a) 書き手が2回とも誤る（`WriteFailed`）、(b) 分析が2回とも誤る（`AnalyzeFailed`）、(c) 拡張点の部品が例外を投げる、のどれでも例外が上がり、ファイルの中身と `entry_for` が前のままで、一時ファイルが残らない", verifies: ["F-01"]}
	"T-12": {title: "CLI：`SHIPCAST_CONFIG` の一時の設定（経路は `fake`、repository 2件）と偽の collector・`responder` で、`main([\"write\", \"--repo\", \"demo-app\", \"--date\", \"2026-11-26\"])` が0を返し、`demo-app` の日誌だけができ、標準出力に `demo-app 2026-11-26: 日誌を書きました` と path が出る。`--repo` を省くと2件とも書く。登録されていない id は終了コード1で何も書かない。collector が `CollectError` を投げる repositoryは書かれず、標準エラーに「収集に失敗したため、日誌を書きませんでした」が出て終了コード1、もう一方は書かれる。書き手が2回とも誤ると標準エラーに `shipcast write: 失敗: demo-app:` と `WriteFailed` の文が出て終了コード1。`shipcast.write.EXTENSIONS` を `RuntimeError` を投げる部品に差し替えると、2件の repository のどちらも `shipcast write: 失敗: <id>: RuntimeError:` の行が出て、traceback で止まらず、終了コード1で、日誌は書かれない。`shipcast write --help` に `--repo` と `--date` がある", verifies: ["R-01", "F-01"]}
}

verification: "`test_commands` を順に流し、すべて終了コード0。試験は fake の経路の `responder` だけで、外部のモデルと `agy` を呼ばない。PRを作った後に、GitHub ActionsのCIの合格を `github-pr-checks` で観測する。本物の経路（codex と antigravity）での確かめは、本人の手動の実行だけ。"
rollback:     "PRを戻す（revert）だけで元に戻る。状態の表の形は変えない（`entries` に行が足されるだけ）。書いた日誌のファイルは `journal_dir` に残るが、配信は前付けの契約だけを読むので害はない。"
exit:         "PRが最終品質ゲートとCIに合格し、タスク担当が統括にPR・合格のコミット・CIの結果・closure.md を報告した時点で、このIssueの作業は終わる。マージと `spec-dock work finish` は統括が行う。"

// 関門（coding-task）。保証レベル standard の既定と、本人の決定 18〜21（init-00001 の plan.cue の delivery）に従う。
gates: {
	spec_review: "Claude `spec-reviewer`（Opus 5.5 / high）。P0・P1がなくなるまで、3回まで"
	checkpoints: "なし。理由：手順は3つで、1人の実装担当が続けて書き、どれもこのIssueの新しいmodule（`write.py`・`prompts/write.md`）と試験が中心で、既存のコードは `cli.py` の1行と `tests/test_cli.py` の一覧だけを変える。後の手順が依る境界（`Draft` と `build_entry` の形）は S-01・S-02 の試験と最終品質ゲートの `api-contract` の観点で確かめる"
	final_quality_gate: {
		scope:          "開始のコミット（統括が作ったworktreeの作業の始めの `HEAD`、`36eea14`）から S-03 の後の `HEAD` まで"
		perspectives:   ["functional-correctness", "requirements-closure", "test-adequacy", "api-contract", "security-baseline"]
		test_commands:  ["uv sync --locked", "uv run ruff check", "uv run pytest -q"]
		record_paths:   ["spec-dock/initiatives/00000-00999/iss-00016/report.md（SpecDockの自動の保存で記録する。Gitのcommitは要らない）"]
		second_opinion: "none"
	}
	merge:            "agent"
	merger:           "統括。タスク担当と実装担当はマージしない（本人の決定 21）。条件は `coding-task` の `references/merge.md`（CIの合格の観測を含む）"
	merge_permission: "本人の「PR のマージは各ワーカーが行わず、統括（Antigravity）が行う」（2026-11-26、`content/decisions/20261126-journal-format-and-hackathon-plan.md` の 21。init-00001 の `plan.cue` の `delivery.gates_by_level.standard.merge`）"
	pr:               "branchは `chemitaro/iss-00016`（統括が作ったworktreeのbranch）。PRの本文に、合格のコミット、最終品質ゲートの結果、CIの結果を書く。Issueを自動で閉じる書き方（Closes #16）は使わず、`Refs #16` にする"
}

execution: {
	sessions: {
		spec: {task: "仕様化（起動した側が選んだ値の記録）", provider: "claude", model: "Claude Opus 5.5", effort: "medium", rationale: "統括が起動したOrcaの作業者。値は起動した側が方針§2の standard のタスク担当の行から決めた（事実の記録）"}
		owner: {task: "タスク担当（仕様、説明資料、レビュー、最終品質ゲート、PR、CIの観測）", provider: "claude", model: "Claude Opus 5.5", effort: "medium", rationale: "方針§2のタスク担当の standard の行。spec と同じセッション"}
		impl: {task: "実装（S-01〜S-03）。このworktreeで起動するOrcaの作業者", provider: "codex", model: "GPT-6.2 Sol", effort: "medium", rationale: "方針§2の、テストで確かめられる実装（バックエンド）の行、本人の決定 19、統括の依頼"}
	}
	reviews: {
		spec_review: {role: "仕様のレビューの `spec-reviewer`", model: "Claude Opus 5.5", effort: "high"}
		final_gate: {role: "最終品質ゲートの `quality-gate-reviewer`", after: "S-03", model: "Claude Opus 5.5", effort: "medium"}
	}
	assignment:   "S-01, S-02, S-03 → impl（連続）"
	same_session: "なし（実装担当の提供元がタスク担当と違い、統括の依頼が Codex の実装担当を名指すため、別のセッションにする）"
}
