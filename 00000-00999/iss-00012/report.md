---
種別: レポート（Issue）
ID: "iss-00012"
関連GitHub: ["#12"]
最終更新: "2026-11-26"
依存: ["requirement.cue", "design.cue", "plan.cue"]
---

# Result Summary

詳細: [Report Guide](../../../docs/authoring/report.md)

## レビュー記録

### 仕様のレビュー（2026-11-26）

- レビュアー：Claude `spec-reviewer`（Opus 5.5 / medium）、保証レベル light。worktree の `HEAD` は `119ec95`（clean）、文書は sha256 で固定。
- 1回目：合格（P0 0、P1 0、P2 1、P3 2）。P2（`scope list` が道具のキャッシュを新しくしうる）と P3（spec-dock の誤りの検査の順、空の題名で `ModelError`）も直した（`.workbench/spec-review/iss-00012/review-response.md`）。
- 2回目：**合格**（P0 0、P1 0、P2 0、P3 0）。結果は `.workbench/spec-review/iss-00012/round-2.json`。
- 合格の sha256：
  - `requirement.cue`：`c94a7d43ff4f4440e9217271dc80232a2bc2fcde04fb6f328ccdb3cca63a1d66`
  - `design.cue`：`360eebb21b2e409ff36e73bccae6a6ff799f78c90ece9eee0057e4fe3245b83c`
  - `plan.cue`：`fdc4bd1a72105c4c8a54865bcd7cd08a28a6ad6bde948bbf5bf6b41081586566`（合格の後に変えるのは手順の `status` だけ）

### 最終品質ゲート（2026-11-26）

- キャンペーン `iss-00012-fqg-1`：開始 `119ec95` から合格のコミット **`b9c9e5403c582d1571eee1e51a08ce3557f37729`** まで。attempt 01 で合格。
- レビュー：`quality-gate-reviewer`（Opus 5.5 / medium）。観点 functional-correctness、requirements-closure、test-adequacy、security-baseline。P0 0・P1 0・P2 0・P3 0、範囲を全部確かめた。2人目は none（light）。
- 試験：`uv sync --locked` 0、`uv run ruff check` 0、`uv run pytest -q` 0（219 passed）。
- 記録：`.workbench/final-quality-gate/iss-00012-fqg-1/closure.md`（worktree `/Volumes/990p2t/workspace/worktrees/orca/shipcast/iss-00012`）。

## Outcome

- `shipcast.collect.specdock.SpecDockCollector`（`name` `specdock`）：`spec-dock scope list --offline --json`・`spec-dock todo list --status all --offline --json`・`gh issue list --state all --json ...` を読むだけで、その日の `scope_opened`・`scope_closed`・`todo_open`・`todo_done` をEventにする。SpecDockを使わないrepositoryでは何も呼ばない。`gh` の失敗は警告、`spec-dock` の失敗は `CollectError`。
- `shipcast.collect.COLLECTORS = (GitCollector(), SpecDockCollector())`。
- コミット：S-01 `3eefa33`、S-02 `b9c9e54`（実装担当 Codex GPT-6.2 Sol / medium、dispatch `ctx_3aaa3e0d6fba`）。

## Verification

- 開始のコミットの基準：191 passed。合格のコミットで `test_commands` すべて0（219 passed）。
- `spec-dock scope check iss-00012`：誤り0・警告0。
- CI：PR #27（https://github.com/chemitaro/shipcast/pull/27）で GitHub Actions `ci`（run 45814732610）が `b9c9e54` に対して success。observer の exit 0、observable_ci PASS、merge_readiness READY（2026-11-26T11:55:33Z）。

## 逸脱と判断

- 実装担当：日の境の比較はUTCに直して行い、`Event.at` は入力の時刻のまま。todoの見本の `problem` などを、SpecDockの実際の出力の形に合わせた。外部モデルを使う `git-autocommit` の代わりに通常の `git commit` を使った。
- タスク担当：仕様のレビューの1回目の P2・P3 を直してから2回目で合格させた（`--offline` を付ける、誤りの検査の順、空の題名の代わりの題名）。

## Residual Risks / Follow-ups

- `--offline` で読むので、手元の観測が古いとScopeの `閉じた理由` が古いことがある（作成・終了の判定は `gh` の時刻）。
- `gh issue list --limit 500` を超えるIssueのrepositoryでは古いScopeの時刻が取れない（警告を出す）。
- 一度閉じて再び開いたIssueは、その日に閉じていても `scope_closed` を出さない。
