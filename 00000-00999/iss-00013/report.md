---
種別: レポート（Issue）
ID: "iss-00013"
関連GitHub: ["#13"]
最終更新: "2026-11-26"
依存: ["requirement.cue", "design.cue", "plan.cue"]
---

# Result Summary

詳細: [Report Guide](../../../docs/authoring/report.md)

## レビュー記録

### 仕様のレビュー（2026-11-26）

- レビュアー：Claude `spec-reviewer`（Opus 5.5 / medium）、保証レベル light。worktree の `HEAD` は `6055bb9`（clean）、文書は sha256 で固定。
- 1回目：不合格（P0 0、P1 1、P2 1、P3 0）。P1（`COLLECTORS` に足すと既存の試験が別のプロセスで本物の `orca` を呼び、登録の順の試験も落ちるのに、計画にない）と P2（配下のpathの規則が入れ子の別のrepositoryを取り込む）を直した（`.workbench/spec-review/iss-00013/review-response.md`）。
- 2回目：**合格**（P0 0、P1 0、P2 0、P3 0）。結果は `.workbench/spec-review/iss-00013/round-2.json`。
- 合格の sha256：
  - `requirement.cue`：`8ad1ff72c50b9a7a86831871abb774c86d96061cc3b33531d27b2090132c6a91`
  - `design.cue`：`6aa477dbc75f575845623995a36819264658e8dc30dc35a457beb38507f20f31`
  - `plan.cue`：`14c8caad0cb1296ab935ffcfc13fc26a2e2d88c19dfa95e435f98dc3d0da712b`（合格の後に変えるのは手順の `status` だけ）

### 最終品質ゲート（2026-11-26）

- キャンペーン `iss-00013-fqg-1`：開始 `6055bb9` から合格のコミット **`e157d9f507d67394361b4d7b532bb7c2453d9a74`** まで。attempt 01 で合格。
- レビュー：`quality-gate-reviewer`（Opus 5.5 / medium）。観点 functional-correctness、requirements-closure、test-adequacy、security-baseline。P0 0・P1 0・P2 0・P3 0、範囲を全部確かめた。2人目は none（light）。
- 試験：`uv sync --locked` 0、`uv run ruff check` 0、`uv run pytest -q` 0（234 passed）。
- 記録：`.workbench/final-quality-gate/iss-00013-fqg-1/closure.md`（worktree `/Volumes/990p2t/workspace/worktrees/orca/shipcast/iss-00013`）。

## Outcome

- `shipcast.collect.orca.OrcaCollector`（`name` `orca`）：`orca agent list --json`・`orca repo list --json`・`orca agent read orca_session_id:<id> --limit 100 --json` を読むだけで、そのrepository（Orcaのrepository IDで結びつく、pathの外のworktreeを含む）の、その日に `updatedAt` が入る会話を、1会話1件の `conversation` のEventにする。本文は `user`・`assistant` の発言だけ。`orca = false` では何も呼ばない。どの失敗も警告で、`CollectError` にしない。
- `shipcast.collect.COLLECTORS = (GitCollector(), SpecDockCollector(), OrcaCollector())`。既存の試験の2か所（`write_config` に `orca = false`、登録の順）を直した。
- コミット：S-01 `e27ca05`、S-02 `e157d9f`（実装担当 Codex GPT-6.2 Sol / medium、dispatch `ctx_56a5a96ebe57`）。

## Verification

- 開始のコミットの基準：219 passed。合格のコミットで `test_commands` すべて0（234 passed）。`orca` のない `PATH` でも 234 passed（実装担当の報告）。
- 見本と差分に実際のOrcaの記録（手元のpath、本物のセッションID・repository名）がないことを、タスク担当が `git diff` の検索で確かめた。

## 逸脱と判断

- タスク担当：epic-00003 の D-04 の2つのコマンドに `orca repo list --json` を足した（Orcaのworktreeは登録したpathの外にあるため）。native_id に日を入れた。仕様のレビューの1回目の P1・P2 を直してから2回目で合格させた。
- 実装担当：変換できない範囲の `updatedAt` は形の合わない行として飛ばす。`ok` が false でも `error` の `code`・`message` が欠けるときは、標準エラーの最後の行か終了コードを理由にする。外部モデルを使う `git-autocommit` の代わりに通常の `git commit` を使った。

## Residual Risks / Follow-ups

- 会話は最後に動いた日（`updatedAt`）にだけ入る。過去の日を後から集め直すと、その後に動いた会話はその日に入らない。
- 1つの会話は最新の100件の記録（道具の呼び出しを含む）だけを読む。
- `orca repo list` が読めないとき、pathの外のworktreeの会話は入らず、入れ子の別のrepositoryも見分けられない（警告を出す）。
- 会話の本文はそのまま状態に入る。公開の方針での絞り込みは後の段が受け持つ。
