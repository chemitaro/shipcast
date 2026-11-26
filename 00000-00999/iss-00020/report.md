---
種別: レポート（Issue）
ID: "iss-00020"
関連GitHub: ["#20"]
最終更新: "2026-11-26"
依存: ["requirement.cue", "design.cue", "plan.cue"]
---

# Result Summary

詳細: [Report Guide](../../../docs/authoring/report.md)

## Outcome

`shipcast draft x` の S-01・S-02 の実装とローカル検証を完了。実装の最終 HEAD は `31be37f085cb57540255eba3ddfcc0ded9d1c413`。

## モデルと推論

- タスク担当・仕様化：Claude Opus 5.5 / medium（統括が方針§2の light のタスク担当の行から選んだ。事実の記録）
- 実装担当 `impl`（S-01・S-02）：Codex GPT-6.2 Sol / medium（方針§2の実装担当（バックエンド）の light の行、統括の依頼）
- 仕様レビュー `spec-reviewer`：Opus 5.5 / medium。最終品質ゲート `quality-gate-reviewer`：Opus 5.5 / medium

## レビュー記録

### 仕様レビュー（spec-review）

- 1回目：**合格**（P0 0・P1 0・P2 1・P3 1）。`spec-reviewer`（Opus 5.5 / medium）。結果 `.workbench/spec-review/iss-00020/round-1.json`、検査 `round-1.check.json`（status pass）。repository の `HEAD` `52ce03d6b3060e92b289b535887347b152b85649`（clean）
- 対象の sha256：
  - `requirement.cue` `21a86fdebebcee196b09147cc17bdcdaa0c871c033986b564adc625a5bce903c`
  - `design.cue` `c96d2344363b9a99e02e28e0731df62ec0602b313ad59b1421bb919de44b0638`
  - `plan.cue` `3d453bc04ba2ecf6a39956bafb9a40df7c69c57cc2a695f9b0fc2fe1458f0ccc`
  - `explanation.html` `72dc851a5e32cbd7ea46963a4b4885d52e97dff3ddc7b7ab40a0b5ca8eabd24c`
- P2（記録のみ）：`text` の検査に UTF-8 に変換できるかの確認がなく、対になっていないサロゲート（`\ud800`）を含む応答で `write_atomic` が `UnicodeEncodeError` を上げ得る（`write._string_errors` は確かめている）。実装担当への注意として渡す
- P3（記録のみ）：スキームのないドメイン（`example.com`）は X がリンクにして固定の長さで数えるので、`x_length` が上限の近くで実際より小さくなり得る（残る危険）

## 逸脱と判断

- P2 を反映し、本文と各ハッシュタグを既存の `write._string_errors` で検査する。UTF-8 に変換できない応答は項目名だけを含む誤りとして返し、一度だけ頼み直す。T-01 と T-02 で単独のサロゲートを検証した。

- 同じ台帳を使う下書き作成が重なっても上書きや同じ話題の選択が起きないよう、POSIX では台帳の親ディレクトリを確認から消化までロックした。非 POSIX ではこの並行実行保護はない。
- スキームのないドメインはレビュー時の扱いを維持した。外部モデルの利用禁止に従い、コミットメッセージはローカルで作成した。

## Verification

- 基準 `52ce03d6b3060e92b289b535887347b152b85649` は `uv sync --locked`、`uv run ruff check`、`uv run pytest -q` がすべて終了コード0、800件通過。
- S-01 `cbcee40e0a392d7c07a43d79d7b480b752f4d817` は T-01 が30件失敗から30件通過、T-02 が4件失敗から4件通過。同じ3コマンドがすべて終了コード0、834件通過。
- S-02 `31be37f085cb57540255eba3ddfcc0ded9d1c413` は T-03 が7件失敗から7件通過、T-04 が7件失敗から7件通過。同日付での並行実行の回帰試験は1件失敗から1件通過。同じ3コマンドがすべて終了コード0、848件通過。
- `spec-dock scope check iss-00020 --offline` で各手順の状態更新後に CUE を検証。

### 最終品質ゲート

- **合格**。campaign `.workbench/final-quality-gate/iss-00020-fqg-1/`、`closure.md`。1回目 `31be37f` で合格の後、統括の承認で `origin/main`（PR #35 の iss-00021）を merge commit `f46f7a3d4a0de82db70b51a80edb3edf47f7cbea` で取り込み（`tests/test_cli.py` の未実装の一覧の衝突を、`run` と `draft x` の両方の行を外して解消）、2回目 `f46f7a3` でも合格（P0〜P3 0、876 passed）。**合格のコミットは `f46f7a3`**
- `quality-gate-reviewer`（Opus 5.5 / medium）：P0 0・P1 0・P2 0・P3 0、coverage_complete true（観点 functional-correctness・requirements-closure・test-adequacy・security-baseline）。実装担当が足した POSIX flock も害なしと確認
- 試験：`uv sync --locked` 0、`uv run ruff check` 0、`uv run pytest -q` 0（848 passed）
- 説明資料：ヘッドレスの Chrome で描画し、PlantUML の図が `data-status="success"` で描けることを確かめた

### PR と CI

- PR https://github.com/chemitaro/shipcast/pull/36（`chemitaro/iss-00020` → `main`、head `f46f7a3`、`Refs #20`）
- CI：1回目の観測（head `31be37f`）は PR が CONFLICTING で CI が起動せず `STARTUP_GRACE_EXPIRED`（exit 2）。取り込みの後の `watch-pr-checks` は exit 0、OBSERVED_CI_PASS、Actions の `ci` run 45847104409 success（head `f46f7a3`）、merge_readiness READY（MERGEABLE・CLEAN、2026-11-26T15:15:55Z）。マージは統括

## Residual Risks / Follow-ups

- 公開範囲・NGワードによる絞り込みがまだない。書き手に渡す項目を `title`・`what`・`why` に絞り、経路の伏せ字と本人の確認に任せる
- 消化を戻すコマンドがない（台帳の `consumed` を0にすれば戻る）。下書きを置いた後の消化で落ちると、下書きはあり話題は未消化のまま残る
- スキームのないドメインは X の URL の数え方で数えない（仕様レビューの P3）。非 POSIX では同時実行の直列化がない
- 並行の iss-00021 との `tests/test_cli.py` の衝突は、取り込みで解消済み
