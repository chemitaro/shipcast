---
種別: レポート（Issue）
ID: "iss-00014"
関連GitHub: ["#14"]
最終更新: "2026-11-26"
依存: ["requirement.cue", "design.cue", "plan.cue"]
---

# Result Summary

詳細: [Report Guide](../../../docs/authoring/report.md)

## レビュー記録

### 仕様のレビュー（2026-11-26）

- 結果：**合格**（2つ目の系列の1回目。両レビュアーとも P0 0件、P1 0件）
- 固定した文書（sha256。合格の対象）：
  - `requirement.cue`：`bd0e3e3ba3eabf1fccbfc6a11c74d2834621002f91f06dfdbc192fc27fb16ce5`
  - `design.cue`：`23c9e445f5c9927ece2f5594393f59b4ea9445238bd87fe8a9731815ae0bcfbf`
  - `plan.cue`：`aebe96181c1618f4cafc5b5777610d826fa24ec70314ea0f180fad3fac043f29`（実装中は各 step の `status` だけを書き換える）
- 1人目：Claude `spec-reviewer`（Opus 5.5 / high）。作成者から独立した読み取り専用のsubagent。系列1の1〜3回目と系列2の1回目をすべて同じレビュアーで行った。結果は pass（P2 1件）。主のrepositoryの `HEAD`：`f68349a24851528b6c42e4f0ad6e84388e29ea91`（clean。レビューの前後で digest は同じ）
- 2人目：ChatGPT GPT-6 / Extra High（`chatgpt-spec-review-strict`、同じ会話の続き）。カタログのcommit `6f966f76a7f9acb122849c765587ce46a450bc2b`（branch `spec-dock/canonical`、上の sha256 と一致）に固定。結果は pass（P2 1件）。モデルの選択の証拠は1回目で verified（GPT-6）、続きの回は Oracle が前の選択を引き継ぐため skipped。思考の深さは毎回 Extra High verified
- 経緯：系列1は3回の上限に達した（spec-reviewer は1〜3回目とも合格、ChatGPT は1回目 P1 9件、2回目 P1 4件、3回目 P1 2件）。統括が新しい系列を承認した（2026-11-26、Orca の msg_e497023d6022）。2回目の後に、JSONに書き出した文字列へ正規表現を当てる形の弱さが同じ根で続いたため、伏せる処理を「JSONの構造をたどる層＋文の規則の層」に設計し直した。3回目と系列2の1回目への送信は、Oracle の送信確認が時間切れになったが、同じ会話を `--harvest --no-recover`／`--live --no-recover` で読み直して回答を取り戻した（新しい送信はしていない）
- 本人の判断：`agy -p` の道具による残る危険（F-05）は、本人が選択肢 (1) を採用した（2026-11-26、統括を通じた本人の了承。requirement.cue の decisions の Q-01）。epic-00004 の design.cue の D-01 を合わせて直した
- 結果のファイル：shipcastの `.workbench/spec-review/iss-00014/`（`round-1〜3.json` と `.check.json`、`s2-round-1.json` と `.check.json`（`validate-review.py` が exit 0、status pass）、ChatGPT の回答 `chatgpt-*`、分析 `review-response.md`）
- 情報の指摘（止めない。実装担当への申し送り）：
  - SR-P2（spec-reviewer）：決定14の例外（Q-01 の本人の採用）が、AGENTS.md の決めた置き場 `content/decisions/` にない。この Issue の変えるファイルの外なので、統括に申し送る（本人の採用の記録を `content/decisions/` に足すかは統括と本人が決める）
  - CG-P2（ChatGPT）：RD-04 は、区切りの後の空白として ASCII のスペースとタブだけを読むので、`TOKEN=\r\n` の `\r` や全角の空白だけの値も `[伏せた]` にする（伏せすぎで、漏れはない）。申し送り：D-01 のコードのとおりに実装し、T-02 の「空白だけの値は変わらない」は ASCII のスペースとタブの場合として確かめる（解釈。`## 逸脱と判断` に記録する）

### 仕様のレビュー（最終品質ゲートの1回目の後の仕様の変更。2026-11-26）

- 結果：**合格**（系列3の1回目。両レビュアーとも P0 0件、P1 0件）。この合格が、上の合格に代わる今の合格
- 固定した文書（sha256）：
  - `requirement.cue`：`b74e5168e888048e956f648ced2e01c5fcee53a2c120958ca7e55fdcced17104`
  - `design.cue`：`8f7e9254b8c35de43a59d9e3101124f1bc74a25a61411cd12f7b9b4534d1b853`
  - `plan.cue`：`935125495a14e39a7cb46dc7c35fc1db7d2bbece9b8ad8253cf862f23a3e51ba`（実装中は各 step の `status` だけを書き換える）
- 変更の理由：最終品質ゲートの1回目（`7cdb371`）で、ChatGPT の2人目が P1（引用の中のエスケープで値の残りが漏れる）と P2（規則の時間が長い入力で2乗に増える）を出し、どちらも再現した。coding-task の手順7で仕様を直した（D-01 のコード、R-02 の受入、F-06、T-02、T-11、S-05）
- 経緯：系列2の2回目・3回目で、ChatGPT が時間の2乗の別の形を1件ずつ P1 で出した（RD-04 の `token` の繰り返し、`SECRET_KEY`）。spec-reviewer も P2 で `b'password=…'` の退行と RD-11 の `eyJ-` を出した。系列2が3回の上限に達し、統括が系列3を承認した（2026-11-26、msg_690f11deafbd）。継ぎ足しをやめ、全規則を総当たりで測った（29の書き出し×14の区切り×4の形。128,000 文字で最悪0.23秒）
- 1人目：Claude `spec-reviewer`（Opus 5.5 / high、同じレビュアー）。pass（P3 1件。D-01 に総当たりの記述がないとの指摘は、131行の注記にあるので読み違いとみる。止めない）
- 2人目：ChatGPT GPT-6 / Extra High（同じ会話の続き）。カタログのcommit `01baa5ae1231f5bb3e569c22dca48a6f32368084` に固定。pass（P0〜P3 0件。独立に53例と、T-11 の100件の時間を測った）。送信の確認が時間切れになったが、同じ会話を `--harvest --no-recover` で読み直して回答を取り戻した（新しい送信はしていない）
- 結果のファイル：shipcastの `.workbench/spec-review/iss-00014/`（`s2-round-2.json`・`s2-round-3.json`・`s3-round-1.json` と `.check.json`、`chatgpt-s2-round-2.raw.md`・`chatgpt-s2-round-3.raw.md`・`chatgpt-s3-round-1.raw.md`、`review-response.md`、時間の総当たりの `perf_fuzz2.py`）

### 区切りのレビュー CP-1（2026-11-26）

- 結果：**合格**（1回目。P0 0件、P1 0件、P2 0件、P3 0件。`validate-review.py` exit 0、status pass）
- 範囲：`f68349a24851528b6c42e4f0ad6e84388e29ea91..31a643cc0c2b5013a876362f43993cef56fd92c2`（S-01〜S-03。clean。branch を通常の push で公開）
- レビュアー：Claude `code-reviewer`（Opus 5.5 / medium、axis both）。タスク担当が `31a643c` で `uv run ruff check` と `uv run pytest -q`（308 passed）の合格を確かめてから依頼した
- 結果のファイル：shipcastの `.workbench/code-review/iss-00014-cp1/round-1.json`、`round-1.check.json`

### 最終品質ゲート（2026-11-26）

- 結果：**合格**（キャンペーン `iss-00014-fqg-2` の attempt 01）
- 合格のコミット：`74a6322bdca167605db10e8e6bc39fcc2f012084`（範囲 `f68349a..74a6322`、clean、upstream と一致）
- 主：Claude `quality-gate-reviewer`（Opus 5.5 / high）。pass、P0 0・P1 0・P2 1、coverage complete。観点 functional-correctness・requirements-closure・test-adequacy・api-contract・security-baseline（計画の `security` は契約の観点の名前 `security-baseline` に当てた）
- 試験：`uv sync --locked`、`uv run ruff check`、`uv run pytest -q`（420 passed）がすべて exit 0
- 2人目：ChatGPT GPT-6 / Extra High（`chatgpt-code-review-strict`、選択の証拠 verified）。fail、P1 1（文の中の複数行の JSON の断片で、鍵と値の間に改行があると値が残る）。タスク担当が再現し、受け入れた仕様の文の層の限界（R-02 の受入にない形、D-01・risks の「規則に当てはまらない形の秘密は伏せられない」）として、証拠を付けて反論した（コードを変えない）。2人目の判定は合格の条件ではない
- 経緯：前のキャンペーン `iss-00014-fqg-1` の attempt 01（`7cdb371`）で、主と試験は合格、ChatGPT の P1（引用の中のエスケープで値の残りが漏れる）と P2（規則の時間の2乗）を再現した。仕様を直して仕様レビューに合格し（上の「最終品質ゲートの1回目の後の仕様の変更」）、S-05 を実装した。権威の文書が変わったため、新しいキャンペーン fqg-2 で全範囲を見直した
- 記録：shipcastの `.workbench/final-quality-gate/iss-00014-fqg-2/closure.md`（と `review-response.md`）、前の経緯は `.workbench/final-quality-gate/iss-00014-fqg-1/`

## Outcome

- S-01 `55cd0ee36be55027a8f1ec7a76a72bfb5b165ecb`。文章・JSONの伏せる処理（T-02）。
- S-02 `03ff1fdb60e6ac65c3492c5846fd54314d1def13`。エージェントの印の検出（T-04 の関数）。
- S-03 `31a643cc0c2b5013a876362f43993cef56fd92c2`。4経路、共通の入口、エラー処理、runner（T-01、T-03〜06、T-08〜10）。
- S-04 `7cdb3715a0491bfcb9395c7b0f22cf71fee4a972`。設定見本の分析モデルの行に `gpt-6-luna` と確認コマンドの注記を追加し、T-07 で解析後の設定が `ModelConfig("codex", "gpt-6.2-sol", "low", None)` のままであることを確認。
- S-05 `74a6322bdca167605db10e8e6bc39fcc2f012084`。RD-04 は引用内のエスケープを値の一部として読み、RD-02・RD-04・RD-11 と JSON の秘密鍵名の判定は、改訂 D-01 に従って再走査を抑える。T-02 に引用・エスケープの例、T-11 に128,000文字の繰り返し25種×4形式の回帰試験を追加。

## Verification

- 開始点 `f68349a24851528b6c42e4f0ad6e84388e29ea91`。仕様レビューで固定した3つの SHA-256 と一致。順に `uv sync --locked`、`uv run ruff check`、`uv run pytest -q` が成功（165件、既存の失敗なし）。実装 worktree の `.workbench/implement/iss-00014/start.md` に記録。
- S-01。Red は `uv run pytest -q tests/test_redact.py::test_redact_text --maxfail=1`（関数を提供するモジュールなし）、`uv run pytest -q tests/test_redact.py -k 'json or non_string'`（文の層だけでは5件失敗）。Green は文の層28件、JSON・型12件。最後に `uv run ruff check` と `uv run pytest -q tests/test_redact.py`（40件）が成功。
- S-02。Red は `uv run pytest -q tests/test_models.py --maxfail=1`（関数を提供するモジュールなし）。Green は `uv run pytest -q tests/test_models.py`（10件）。`uv run ruff check` と `uv run pytest -q tests/test_redact.py tests/test_models.py`（50件）が成功。
- S-03。Red → Green は `uv run pytest -q tests/test_models.py -k <選択>`。経路の選択と fake は10失敗 → 10合格、runner は5失敗 → 5合格、環境の守りは24失敗 → 34合格、CLIの呼び方と伏せる境界は10失敗 → 11合格、応答と失敗は22失敗 → 25合格、長さと UTF-8 はそれぞれ1失敗 → 合計5合格、timeoutの型と応答の Unicode 改行は3失敗 → 7合格。最後に `uv sync --locked`、`uv run ruff check`、`uv run pytest -q tests/test_redact.py tests/test_models.py`（143件）、`uv run pytest -q`（308件）が成功。CLIの呼び方は偽の runner で確認。

- S-04。CP-1 合格後に着手し、`uv run pytest -q tests/test_config.py::test_default_analyst_model_documents_cheaper_option` が注記なしで1件失敗、注記を足して1件合格。順に `uv sync --locked`、`uv run ruff check`、`uv run pytest -q` が成功（309件）。`uv run pytest -q tests/test_config.py`（26件）と `git diff --check f68349a HEAD` も成功。

- S-05。改訂後の3文書の SHA-256 はレビュー合格記録に一致（計画は S-05 の `status` を `todo` に戻して計算）。`uv run pytest -q tests/test_redact.py -k 'quoted_or_escaped_assignment or escaped_json_fragment'` は修正前に2件失敗、修正後に11件合格。`uv run pytest -q 'tests/test_redact.py::test_redact_long_input_finishes_within_two_seconds[a-text]'` は修正前9.576秒で失敗、修正後に合格。
- S-05 の最終検証は順に `uv sync --locked`、`uv run ruff check`、`uv run pytest -q` が成功（420件）。`uv run pytest -q tests/test_redact.py tests/test_models.py --durations=5` は254件合格。`uv run python -` で D-01 の全11規則のパターン・フラグと `SECRET_KEY` の一致、および T-11 の100件の出力の一致を確認し、`time.perf_counter` で測った `redact()` の最長は0.046185秒、合計は3.461345秒（`a-text` は0.040824秒）。`git diff --check HEAD^ HEAD` も成功。

## 逸脱と判断

- RD-04 では、値を読む前に飛ばす空白を ASCII のスペースとタブと解釈し、D-01 のコードに合わせた。`TOKEN=\r\n` の CR と全角空白だけの値は `[伏せた]` に変わることも T-02 で確認した。
- Codex の応答ファイルは改行を変換せず UTF-8 で読み、Antigravity の JSON は LF で行を区切る。後者は JSON の文字列中の Unicode 行区切り文字を本文として保つ。Antigravity の入力が UTF-8 に変換できない場合は、runner を呼ぶ前に `RouteFailed` とした。
- 外部モデルの利用を禁じる依頼とリポジトリの契約を適用し、コミットメッセージはローカルで作成した。明示パスの stage、差分確認、通常の Git コミット、コミット後の親と worktree の確認を行った。

## Residual Risks / Follow-ups

- PR：https://github.com/chemitaro/shipcast/pull/30（branch `chemitaro/iss-00014`、head `74a6322bdca167605db10e8e6bc39fcc2f012084`、base `main`。`Refs #14`、自動で閉じる書き方は使わない）。`main` は他の Issue のマージで先に進んでいるが、変えたファイルは重ならず、マージは衝突しない（`git merge-tree` で確かめた）
- CI：`ci` run 45826339321（pull_request、`74a6322`）が success。`github-pr-checks` の観測は exit 0、observable_ci PASS、coverage ACTIONS_AND_COMMIT_STATUSES、merge_readiness READY（2026-11-26T13:10:22Z）。外部の CheckRun は観測の範囲外
- マージ：strict のため、統括が本人に確かめてから行う（タスク担当と実装担当はマージしない）。`spec-dock work finish` も統括が行う

- 伏せる処理の文の層の規則で、まだ伏せられない形（規則の表 `RULES` を足す候補）：(1) 文の中の複数行の JSON の断片で、`:` の後で行が終わり、値が次の行にある形（最終品質ゲートの ChatGPT の P1、反論で閉じた）、(2) 引用の閉じの直後に続くシェルの連結（`'it'\''s…'`、`"abc"def`）の後ろ（主のレビューの P2）。JSON を prompt の全体として渡す道筋（iss-00015・iss-00016 の約束）は構造をたどって伏せるので影響しない。規則を足す別の Issue にするかは統括と本人が決める
- `agy -p` の道具による残る危険（F-05）は本人が受け入れた（Q-01）。その採用の記録を `content/decisions/` に残すかは統括と本人が決める（仕様レビューの P2）
- Antigravity の CLI が自分の道具の中で付けるエージェントの印は文書になく、2026-12-19 の規約の読み直しのときに見直す
- `agy` の引数は公式の文書だけで確かめた。最初の本物の実行は本人の手動
- 既定の分析のモデルは `gpt-6.2-sol` のまま。`gpt-6-luna` で足りるかは本人が比べて決める
