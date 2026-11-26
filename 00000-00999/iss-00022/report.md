---
種別: レポート（Issue）
ID: "iss-00022"
関連GitHub: ["#22"]
最終更新: "2026-11-26"
依存: ["requirement.cue", "design.cue", "plan.cue"]
---

# Result Summary

詳細: [Report Guide](../../../docs/authoring/report.md)

## レビュー記録

### 仕様のレビュー（2026-11-27）

- 結果：**合格**（2回目。P0 0件、P1 0件、P2 0件、P3 0件。`validate-review.py` exit 0、status pass）
- 固定した文書（sha256。合格の対象）：
  - `requirement.cue`：`641feaaa57031df4264e15e444eca04ee67240277393cc49aa28509a8e1d61a7`
  - `design.cue`：`6bee270d59573aef8137c1848fd3e9f97f7d5b42ec07a56ea54eec2bfb8dc773`
  - `plan.cue`：`196a0441d63f3f455960530353cd82b05f42cda2d122551428082c77b777c3e4`（実装中は各 step の `status` だけを書き換える）
- レビュアー：Claude `spec-reviewer`（Opus 5.5 / high）。作成者から独立した読み取り専用のsubagent。1回目・2回目とも同じレビュアー。worktree の `HEAD`：`e101f4009db44fbf3a4dc7d1c9ba249720f1bd0f`（clean。レビューの前後で digest は同じ）
- 経緯：1回目は合格（P2 1件：夜の実行の TCC の案内（`run.py` の `_TCC_HINT`）が install・README の案内と食い違う。P3 2件：F-01 の題名が判定より強い、timezone のずれを README に書く約束が D-08・T-09 にない）。安価で、夜の失敗時に本人が読む案内に効くので受け入れて直し（R-05・D-07・T-10 の追加、F-01 の題名、D-08・T-09 の timezone）、2回目で全体を見直してもらった
- 結果のファイル：shipcastの `.workbench/spec-review/iss-00022/`（`round-1.json`・`round-2.json` と `.check.json`、`review-response.md`）

### 最終品質ゲート（2026-11-27）

- 結果：**合格**（キャンペーン `iss-00022-fqg-1` の attempt 02）
- 合格のコミット：`0c6a5aedf54941e55bfcf77bfe87bdd42b696c8c`（範囲 `e101f40..0c6a5ae`、clean）
- 経緯：attempt 01 は `1d92763` で合格（P0〜P3 0、848 passed）。PR 作成後に main（PR #36、iss-00020）と `tests/test_cli.py` で衝突したため、タスク担当が `origin/main` を通常のマージで取り込み（`0c6a5ae`。両方の変更で未実装の葉がなくなったので、未実装の葉の試験を、印の仕組み `_configure_leaf` を見本の葉で直接確かめる形にした）、attempt 02 で全範囲を見直した
- 主：Claude `quality-gate-reviewer`（Opus 5.5 / medium）。pass、P0 0・P1 0・P2 0・P3 0、coverage complete。観点 functional-correctness・requirements-closure・test-adequacy・api-contract・security-baseline
- 試験：`uv sync --locked`、`uv run ruff check`、`uv run pytest -q`（897 passed）がすべて exit 0（タスク担当の試験レーン）
- 2人目：none（standard）
- 記録：shipcastの `.workbench/final-quality-gate/iss-00022-fqg-1/closure.md`

### PR と CI（2026-11-27）

- PR：https://github.com/chemitaro/shipcast/pull/37（`chemitaro/iss-00022` → `main`、`Refs #22`、自動で閉じる語句なし）。head `0c6a5aedf54941e55bfcf77bfe87bdd42b696c8c`（合格のコミットと同じ。記録のみのコミットなし）
- CI：`github-pr-checks` の observer で exit 0、`OBSERVED_CI_PASS`（2026-11-26T15:26:17Z）。Actions の `ci`（run 45848895312、event pull_request、head 0c6a5ae）が success。coverage ACTIONS_AND_COMMIT_STATUSES、expected_inventory UNSPECIFIED、merge_readiness READY（MERGEABLE、CLEAN）
- 最初の観測（head 1d92763）は main との衝突で CI が起動せず `STARTUP_GRACE_EXPIRED`（exit 2）。main を取り込んだ後に観測し直した
- マージと `spec-dock work finish` は統括が行う

## Outcome

- 実装担当：Codex（gpt-6.2-sol / medium、Orca dispatch `ctx_3871ec17ceaa`）。区切りのレビューはなし（plan の関門）
- S-01 `e901cae`：`shipcast.schedule` の `build_plist`・`nightly_environment`・`find_program`（`.venv` を断る）
- S-02 `2bad8b4`：`schedule install`（plist と `logs/`、既定は読み込みのコマンドを示すだけ、`--load` のときだけ bootout → bootstrap）・`uninstall`（`--unload` のときだけ bootout）、`cli.py` の接続
- S-03 `0101347`：`run.journal_extensions_for` を `write.journal_extensions(store, config.neta.threshold)` に接続、TCC の案内を「`shipcast schedule install` が示す Python の実行ファイル」に統一
- S-04 `1d92763`：README の「導入と毎晩の実行（`shipcast schedule`）」の節

## Verification

- 開始 `e101f40` で `test_commands` 全 exit 0（828 passed）。各 step で Red → Green（実装メモ `.workbench/implement/iss-00022/report.md`）。最終 848 passed
- 試験は一時の HOME・`shutil.which`／`launchctl` の偽物・`subprocess.run` の見張りだけで、本物の `~/Library/LaunchAgents/`・`launchctl`・外部モデルに触れない

## Residual Risks / Follow-ups

- 本人の手動の確かめ：`shipcast schedule install --load` での読み込み、3時の起動、外付けvolumeでのフルディスクアクセス（Python の実体で足りるか。requirement の questions）
- launchd の 03:00 は Mac の時計の時刻。設定の `timezone` と違うと前日の境目がずれる（README に記載）
- 並行の iss-00020 と `cli.py`・`tests/test_cli.py`・README の付近で行の衝突がありうる
- README の「状態」の節（「動くコードはまだありません」）は古いが、このIssueの外

## 逸脱と判断

- 空の `SHIPCAST_CONFIG` は `config_path()` に合わせ、既定の設定パスを絶対化して plist に入れる（実装担当の判断）
- 書き出し失敗時は一時 plist を消し、既存の plist を保持する（実装担当の判断）
- `launchctl` の失敗に出力がないときは終了コードを示す（実装担当の判断）

