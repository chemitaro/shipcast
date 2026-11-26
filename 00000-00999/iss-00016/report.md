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
- 外部モデルを呼ばない作業条件に合わせ、ステージ済み差分の確認後に日本語のメッセージを手書きして通常の `git commit` を使用。

## Verification

- 基準（`36eea14aef0ad8e5039398dd98c8fed24e6e9abb`） — `shasum -a 256` はレビュー合格の3ファイルと一致。`uv sync --locked`・`uv run ruff check`・`uv run pytest -q` はすべて終了コード0、671 passed。記録は `.workbench/implement/iss-00016/start.md`。
- S-01 Red — `uv run pytest -q tests/test_write.py` の対象を `-k` で選択。`reads_plain` は公開モジュール未実装で3件失敗、`invalid_json` は未検査で6件失敗、`field_errors or all_fields or story_markdown` はフィールド検査未実装で37件失敗・許容例1件成功、`packaged` はリソース未配置で1件失敗。
- S-01 Green — 同じ対象で順に3・6・38・1件が成功。`uv run pytest -q tests/test_write.py` は48 passed、`uv run ruff check`・`git diff --cached --check` は終了コード0。コミット後の作業ツリーは clean。

## Residual Risks / Follow-ups
