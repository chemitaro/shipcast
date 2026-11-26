---
種別: レポート（Issue）
ID: "iss-00011"
関連GitHub: ["#11"]
最終更新: "2026-11-26"
依存: ["requirement.cue", "design.cue", "plan.cue"]
---

# Result Summary

詳細: [Report Guide](../../../docs/authoring/report.md)

## レビュー記録

### 仕様のレビュー（2026-11-26）

- レビュアー：Claude `spec-reviewer`（Opus 5.5 / high）、保証レベル standard。worktree の `HEAD` は `f68349a`（clean）、文書は sha256 で固定。
- 1回目：不合格（P0 0、P1 1、P2 1、P3 2）。P1 は `max_merged` の打ち切りの数え方（`M` 自身を含む）。P2・P3 も含めて直した（`.workbench/spec-review/iss-00011/review-response.md`）。
- 2回目：**合格**（P0 0、P1 0、P2 0、P3 0）。結果は `.workbench/spec-review/iss-00011/round-2.json`。
- 合格の sha256：
  - `requirement.cue`：`49ebc1756878615f80061a20484498f69238f3d3661fe8f4b30989bf98599e33`
  - `design.cue`：`2f11485aac3e8f5da4d3ff323455438c512bcb585a1de6b34528834a86f5c89c`
  - `plan.cue`：`77cc84bc8da152a03054a9b2b5a0a223a2b1eb53129acdf39865ccd5321992b1`（合格の後に変えるのは手順の `status` だけ）

### 最終品質ゲート（2026-11-26）

- キャンペーン `iss-00011-fqg-1`：開始 `f68349a` から合格のコミット **`e6c7e8977afb00e93d09db947f360f061dc86ec9`** まで。attempt 01 で合格。
- レビュー：`quality-gate-reviewer`（Opus 5.5 / medium）。観点 functional-correctness、requirements-closure、test-adequacy、api-contract、security-baseline。P0 0・P1 0・P2 0・P3 0、範囲を全部確かめた。2人目は none（standard）。
- 試験：`uv sync --locked` 0、`uv run ruff check` 0、`uv run pytest -q` 0（191 passed）。
- 記録：`.workbench/final-quality-gate/iss-00011-fqg-1/closure.md`（worktree `/Volumes/990p2t/workspace/worktrees/orca/shipcast/iss-00011`）。

## Outcome

- `shipcast.collect.base`：`Collector`（Protocol）、`CollectResult`、`CollectError`、`day_bounds`、`RepoCollection`、`collect_repo`。`shipcast.collect.COLLECTORS = (GitCollector(),)`。
- `shipcast collect [--repo ID] [--date YYYY-MM-DD]`：repositoryごとに件数・警告・失敗を示し、失敗があれば終了コード1。`runs` には書かない。
- `shipcast.collect.git.GitCollector`：first-parent の列でその日のcommitとmerge、mergeが取り込んだcommit（mergeの時刻）を、`git --no-optional-locks -C` の `rev-parse`・`log`・`diff-tree` だけで読む。
- コミット：S-01 `a79ccf1`、S-02 `0cf9754`、S-03 `e6c7e89`（実装担当 Codex GPT-6.2 Sol / medium、dispatch `ctx_4b3cabf74ea0`）。

## Verification

- 開始のコミットの基準：165 passed。合格のコミットで `test_commands` すべて0（191 passed）。
- `spec-dock scope check iss-00011`：誤り0・警告0。
- CI：PRの作成後に記録する。

## 逸脱と判断

- 実装担当：日の区切りの比較をUTCに直して行う（`Store.events_for` と同じ瞬間の比較。DSTの曖昧さを避ける）。部分クローンで取得が起きないよう `GIT_NO_LAZY_FETCH=1`・`GIT_ALLOW_PROTOCOL=` を子プロセスに足した。`load_config` が直接投げる `OSError` もCLIで終了コード1にした。外部モデルを使う `git-autocommit` の代わりに通常の `git commit` を使った。どれも仕様の約束を強める方向で、最終品質ゲートで確かめた。
- タスク担当：plan.cue の観点 `security` を、レビューの観点の名前 `security-baseline` に直した（合格の後の `status` の更新と同じ時に。意味は同じ）。

## Residual Risks / Follow-ups

- iss-00012・iss-00013 の仕様は `collect(repo, day)` の前提で書かれている。この Issue で `collect(repo, day, tz)` にしたので、具体化のときに読み替える。`COLLECTORS` は `shipcast.collect` にある。
- fast-forward で正本に入ったcommitは、commitの時刻の日に数える（Gitに入った時刻がない）。
- 1つのmergeが200件を超えるcommitを取り込むと、超えた分は集めず警告を出す。
- timeout と git の非0終了の `CollectError` の文は試験していない（plan の範囲外。レビューの記録）。
