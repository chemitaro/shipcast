---
種別: レポート（Issue）
ID: "iss-00008"
関連GitHub: ["#8"]
最終更新: "2026-11-26"
依存: ["requirement.cue", "design.cue", "plan.cue"]
---

# Result Summary

詳細: [Report Guide](../../../docs/authoring/report.md)

## レビュー記録

### 仕様のレビュー（2026-11-26）

- 結果：**合格**（1回目。P0 0件、P1 0件、P2 1件、P3 1件）
- レビュアー：Claude `spec-reviewer`（Opus 5.5 / medium。保証レベル light の既定）。作成者から独立した読み取り専用のsubagent。ChatGPTの2人目はなし（light）
- 固定した文書（sha256）：
  - `requirement.cue`：`bcf39ad170a6b49035d4f2b461d83e04095c0c25be622773740205fa2b6b9cf7`
  - `design.cue`：`343abe92f29e93cf5109b0c9462463d18ed9dd248f8220ca11576bdfb6abd907`
  - `plan.cue`：`fc632705c2cf1013e34139ab46c8abc518fe68dc0cb220479af7cd9959d939fb`
- 照らした正本：`content/decisions/20261126-journal-format-and-hackathon-plan.md`（18〜24）、`AGENTS.md`、epic-00002 の要件・設計・計画、init-00001 の `plan.cue`（delivery）、`spec-dock/docs/authoring/cue.md`
- 主のrepositoryの `HEAD`：`606bec38f825a4a3bb8e418265fe79bf98918179`（clean。レビューの前後で digest は同じ）
- 結果のファイル：shipcastの `.workbench/spec-review/iss-00008/round-1.json`、検証は `round-1.check.json`（`validate-review.py` が exit 0、status pass）
- 情報の指摘（止めない。文書は直さず記録だけ）：
  - P2：葉を付けない `shipcast repo`・`draft`・`schedule` の動きが決まっておらず、試験もない。実装担当への申し送り：D-02 の「下位のコマンドなしは使い方を示して2」と同じに扱い（argparseの必須でないsubparsersで `func` が無いまま進まないようにする）、T-05 の中で確かめてよい（実装の裁量。`## 逸脱と判断` に記録する）
  - P3：`decisions` の「終了コード2は epic-00002 の設計のとおり」の出典は、epic-00002 の設計には書かれていない（以前の iss-00008 の設計にあった値）。値そのものはこのIssueの中で一貫している

## Outcome

- S-01 `674fc50249184ddbe1632efaef8b865ef2c5d4ff` で Python 3.12、uv の package、開発依存、lockfile、Ruff と pytest の設定を追加。
- S-02 `a984a9c10321b407dee8723c72fc245d6ae8c90b` で CLI と7つのコマンド、9つの未実装の葉を登録。コンソールスクリプトと `python -m shipcast` に同じ入口を使用。
- S-03 `07fe2f495f26a1d30dbc44b1bbf563e3b954510a` で GitHub Actions の検証 workflow と T-07 を追加。

## Verification

- 開始コミット `606bec38f825a4a3bb8e418265fe79bf98918179` のベースラインは、`uv sync --locked` が2（pyproject.toml なし）、`uv run ruff check` が0、`uv run pytest -q` と `uv run shipcast --help` が各2（実行ファイルなし）。
- S-01 の package 読み込みテストは Red が1件（`ModuleNotFoundError`）、Green が1件。新しいローカル clone で `uv sync --locked`、`uv run ruff check`、`uv run pytest -q` がすべて0。
- S-02 は `uv run pytest -q tests/test_cli.py` で Red が20件失敗・3件合格、Green が23件合格。 `uv sync --locked`、`uv run ruff check`、`uv run shipcast --help` は0。コンソールスクリプトと `python -m shipcast --help` の出力は一致。
- S-03 は `uv run pytest -q tests/test_cli.py::test_ci_runs_local_checks_for_pull_requests_and_main_pushes` で Red が1件（workflow ファイルなし）、Green が1件。
- S-03 のコミットで指定4コマンドがすべて0。pytest は24件合格。CLI のヘルプは7コマンドを表示。Git の差分チェックに合格し、仕様3ファイルの SHA-256 はレビュー記録と一致。
- D-05 のリリース確認で `actions/checkout` v7.0.1、`astral-sh/setup-uv` v10.4.0 を取得し、指定のメジャー版 `v7` と `v10` を採用。

## 逸脱と判断

- P2 の申し送りに従い、`repo`、`draft`、`schedule` に下位コマンドがなければ、そのコマンドの使い方を標準エラーに出して2で終了する。T-05 で3件を検証した。
- 新しい Ruff 設定を適用すると、既存の `.agents/skills/spec-dock-grill-with-docs/scripts/finalize-artifact.py` から14件の指摘が出た。shipcast の検査で既存のエージェント用ツールが対象になるのを避けるため、Ruff の `extend-exclude` に `.agents` を指定した。
- 外部モデルを呼ばないというタスクの指示に従い、git-autocommit によるメッセージ生成を省き、各ステップを通常の Git コミットにした。

## Residual Risks / Follow-ups

- S-04 の AGENTS.md と T-06、PR 上での GitHub Actions 実行結果 T-08 はタスク担当に引き継ぐ。
