---
種別: レポート（Issue）
ID: "iss-00019"
関連GitHub: ["#19"]
最終更新: "2026-11-26"
依存: ["requirement.cue", "design.cue", "plan.cue"]
---

# Result Summary

詳細: [Report Guide](../../../docs/authoring/report.md)

## Outcome

- 話題を保存するとき（`Store.save_stories`）、同じ取引でネタポイントを台帳 `neta_ledger` に一度だけ加える。未消化の話題を読む `Store.unconsumed_stories(repo_id, *, limit=None)` を足した（iss-00020 も使う）。
- 新しい `shipcast.neta.NetaSprout` が、残高がしきい値以上の日に `:::tip 発信の芽（ネタポイント N）` と題名（最大3件、文字参照）を返す。`shipcast.write.journal_extensions(store, threshold)` が `(*EXTENSIONS, NetaSprout)` を作り、`shipcast write` の `run` が `write_day` に渡す。`cli.py`・`EXTENSIONS`・`JournalExtension` は変えていない。
- 実装のコミット：S-01 `448618d1c661a61291bddddb59125bb7bc921bf4`、S-01 補足 `3a23aab81776f68fb133cf8738ad101abd5d0943`、S-02 `0402c2f8a695407f7f32ca00d62db2d2ba69278b`（合格のコミット）。

## モデルと推論

- タスク担当・仕様化：Claude Opus 5.5 / medium（統括が方針§2の light のタスク担当の行から選んだ。事実の記録）
- 実装担当 `impl`（S-01・S-02）：Codex GPT-6.2 Sol / medium（方針§2の実装担当（バックエンド）の light の行、統括の依頼）
- 仕様レビュー `spec-reviewer`：Opus 5.5 / medium。最終品質ゲート `quality-gate-reviewer`：Opus 5.5 / medium

## レビュー記録

### 仕様レビュー（spec-review）

- 1回目：**合格**（P0 0・P1 0・P2 0・P3 1）。`spec-reviewer`（Opus 5.5 / medium）。結果 `.workbench/spec-review/iss-00019/round-1.json`、検査 `round-1.check.json`（status pass）。repository の `HEAD` `ef3075fdcdaba36311df209b8fb44b7aff2df65a`（clean）
- 対象の sha256：
  - `requirement.cue` `e3c62d73a31f7c9872bcdb4f42ef4db2819519c912132121ce8cb48d2937d4c0`
  - `design.cue` `5b169bef8ed0509d113191fabaea97c1b327598931df6506b1a5c648a85b435a`
  - `plan.cue` `5d2a376efb39fb101ae0929cc9ac1f4955fd68d6920d1823cc66dd8ef104f2d9`
  - `explanation.html` `fb8c3d02adc58d69aa5360dec993382dad0d9de5bdbf8145c6ff08322341bf32`
- P3（記録のみ）：点数を変えて保存し直した話題では、`unconsumed_stories` の並び（台帳の `points`）と返る `Story.neta.score` が食い違い得る。D-01 の SQL のとおり台帳の `points` で並べる（実装担当への注意として渡す）

## 逸脱と判断

- 実装担当の判断：`unconsumed_stories` の `limit` が SQLite の整数範囲を超えるときは `2**63 - 1` に収める（1未満・整数でないときは全件）。題名のエスケープは `write.py` への循環を避けるため `neta.py` に同じ規則で実装（D-02 のとおり）。
- 逸脱なし（セッションの値と手順の割り当ては計画どおり。実装担当 Codex `ctx_c057bc5bfb92`、launch.effective gpt-6.2-sol / medium）。

## Verification

- Red → Green（実装担当の報告 `.workbench/implement/iss-00019/result.md`）：S-01 T-02 2 failed→2 passed、T-01 1 failed→3 passed、補足 1→1、S-02 T-03 3 failed→3 passed、T-04 2 failed→2 passed。
- 基準：`ef3075f` で 792 passed。最終 `0402c2f` で 800 passed。

### 最終品質ゲート

- **合格**（1回目）。campaign `.workbench/final-quality-gate/iss-00019-fqg-1/`、`closure.md`。合格のコミット `0402c2f8a695407f7f32ca00d62db2d2ba69278b`
- `quality-gate-reviewer`（Opus 5.5 / medium）：P0 0・P1 0・P2 0・P3 0、coverage_complete true（観点 functional-correctness・requirements-closure・test-adequacy・security-baseline）
- 試験：`uv sync --locked` 0、`uv run ruff check` 0、`uv run pytest -q` 0（800 passed）
- 説明資料：ヘッドレスの Chrome で描画し、PlantUML の図が `data-status="success"` で描けることを確かめた

## Residual Risks / Follow-ups

- 同じ日を分析し直して話題の分け方が変わると、id が変わり別の話題として点数が足される（requirement.cue の excludes）
- iss-00021（`shipcast run`）は `journal_extensions(store, config.neta.threshold)` を `write_day` に渡す必要がある（申し送り）
