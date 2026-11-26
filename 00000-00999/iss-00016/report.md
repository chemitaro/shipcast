---
種別: レポート（Issue）
ID: "iss-00016"
関連GitHub: ["#16"]
最終更新: "2026-11-26"
依存: ["requirement.cue", "design.cue", "plan.cue"]
---

# Result Summary

詳細: [Report Guide](../../../docs/authoring/report.md)

## レビュー記録

### 仕様のレビュー（2026-11-26）

- 結果：**合格**（2回目。P0 0件、P1 0件、P2 0件、P3 2件。`validate-review.py` exit 0、status pass）
- 固定した文書（sha256。合格の対象）：
  - `requirement.cue`：`ea04d9380c5dc23d4b42aff03ec1e070e42bd0c6b4874663133bc40fad4b9e46`
  - `design.cue`：`6e9078857faaad7ca9e01d91e317102812d816b19f6394441d1c48e710eaf34c`
  - `plan.cue`：`c6cd66a60e9e9631a404fa29ded8766b7e3284745bf1fe2c6c0ba6afdf0033e7`（実装中は各 step の `status` だけを書き換える）
- レビュアー：Claude `spec-reviewer`（Opus 5.5 / high）。作成者から独立した読み取り専用のsubagent。1回目・2回目とも同じレビュアー。主のrepositoryの `HEAD`：`36eea14aef0ad8e5039398dd98c8fed24e6e9abb`（clean。レビューの前後で digest は同じ）
- 経緯：1回目は合格（P2 3件：W-05 がリスト・引用の中の囲みと見出しを拒めない、閉じないコードの囲み、CLIが拡張点の例外を受け止めない。P3 2件：`_inline` で空になる項目の囲み、`collect_repo` の置き場所）。1回目の結果のファイルは題名の長さで機械的に弾かれ、同じ内容を `round-1b.json` に書き直してもらった。安価に直せるので受け入れて直し、2回目で全体を見直してもらった
- 2回目の P3（直さず申し送り）：(1) `_inline` が先頭の `*`・`` ` `` を常に打ち消すので、`**太字**` や `` `code` `` で始まる行の見た目が崩れる（中身は失われない）。(2) W-05 の `=`・`-` だけの行の検査はブロックの印を除く前に行うため、引用の中の setext 見出し（`> ===`）が通る（見出しが1つ増える見た目だけ）
- 結果のファイル：shipcastの `.workbench/spec-review/iss-00016/`（`round-1.json`・`round-1b.json`・`round-2.json` と `.check.json`、`review-response.md`）

## Outcome

- S-01 — `54373b30b5038489de9d29507fbb8e28a6f7a5f9`。書き手の入力指示と応答の検査を追加。検査を JSON 全体と各フィールドに分け、エラー文には応答の値を載せない。引用内の `> ===` はレビュー時の申し送りどおり許容する。
- S-02 — `00d24f751d4bb54fcb766dc720aa6bf24f393b71`。4つの数、前付け・本文・拡張点の囲み、ファイルの置き換えを追加。集計は最初に現れた同一 ID を採用し、数を書き出す順は固定。文字参照には `html.escape(quote=False)` を使い、先頭の太字・インラインコードの印は申し送りどおり打ち消す。
- S-03 — `24391b250ac4c4e865a400f428681512e9ce1901`。書き手への依頼と再試行、1日の分析・執筆・保存、CLI を接続。経路の読み取り専用属性は `Protocol` のプロパティで表現し、話題の順は `analyze` の戻り値を保つ。W-03・W-04 の1行条件は文字列の先頭・末尾の改行にも適用する。
- 外部モデルを呼ばない作業条件に合わせ、ステージ済み差分の確認後に日本語のメッセージを手書きして通常の `git commit` を使用。

## Verification

- 基準（`36eea14aef0ad8e5039398dd98c8fed24e6e9abb`） — `shasum -a 256` はレビュー合格の3ファイルと一致。`uv sync --locked`・`uv run ruff check`・`uv run pytest -q` はすべて終了コード0、671 passed。記録は `.workbench/implement/iss-00016/start.md`。
- S-01 Red — `uv run pytest -q tests/test_write.py` の対象を `-k` で選択。`reads_plain` は公開モジュール未実装で3件失敗、`invalid_json` は未検査で6件失敗、`field_errors or all_fields or story_markdown` はフィールド検査未実装で37件失敗・許容例1件成功、`packaged` はリソース未配置で1件失敗。
- S-01 Green — 同じ対象で順に3・6・38・1件が成功。`uv run pytest -q tests/test_write.py` は48 passed、`uv run ruff check`・`git diff --cached --check` は終了コード0。コミット後の作業ツリーは clean。

- S-02 Red — `uv run pytest -q tests/test_write.py` の対象を `-k` で選択。数は `Metric` 未実装で1件、本文は `build_entry` 未実装で13件・空日1件、拡張点は登録と引数が未実装で2件、置き換えは `write_atomic` 未実装で3件失敗。
- S-02 Green — 数1件、本文と空日14件、拡張点2件、置き換え3件が成功。`uv sync --locked`・`uv run ruff check`・`uv run pytest -q`・`git diff --cached --check` はすべて終了コード0、739 passed。コミット後の作業ツリーは clean。

- S-03 Red — `uv run pytest -q tests/test_write.py` の対象を `-k` で選択。書き手への依頼は `compose`・`WriteFailed` 未実装で4件、1日の処理は `write_day` 未実装で5件、CLI は未実装の葉で7件失敗。先頭・末尾に改行を含む応答の追加2件は、それまで許容していたため失敗。
- S-03 Green — 書き手への依頼4件、1日の処理5件、CLI の事前検査・中断を含む11件、フィールドエラー38件が成功。`uv sync --locked`・`uv run ruff check`・`uv run pytest -q`・`git diff --cached --check` はすべて終了コード0、760 passed。`uv run shipcast write --help` で2つのオプションを確認。
- 正本 — `spec-dock scope check iss-00016` はエラー・警告とも0。計画の3つの `status` を `todo` に戻したバイト列の SHA-256 はレビュー合格時と一致。要件・設計の SHA-256 も一致し、正本は Git の差分に含まれない。

## Residual Risks / Follow-ups

- D-07 に記載のとおり、ファイルの置き換え後に `Store.save_entry` が失敗すると、ファイルと記録の更新時点がずれる。同じ日の再実行で両方を書き直す。
- 実装の検証には fake の responder を使用。実環境でのモデル実行は本人の手動検証の範囲で、レビュー・最終品質ゲート・PR はタスク担当の工程。
