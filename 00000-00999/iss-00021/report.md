---
種別: レポート（Issue）
ID: "iss-00021"
関連GitHub: ["#21"]
最終更新: "2026-11-26"
依存: ["requirement.cue", "design.cue", "plan.cue"]
---

# Result Summary

詳細: [Report Guide](../../../docs/authoring/report.md)

## レビュー記録

### 仕様のレビュー（2026-11-26）

- 結果：**合格**（2回目。P0 0件、P1 0件、P2 0件、P3 1件。`validate-review.py` exit 0、status pass）
- 固定した文書（sha256。合格の対象）：
  - `requirement.cue`：`39f245a9b97acaa0cd0692e235e7ecbf5fec1f8e19585857bf24b8f1a23a9e33`
  - `design.cue`：`20d2c876ceeeb1b1f3daefc766fc47f0e962a9f3eb3b85e8e44db8867adb316e`
  - `plan.cue`：`52bd748e425ad913f6a98bd656cf3f3b8cecbeba0cf2fdabaf979a03856523ce`（実装中は各 step の `status` だけを書き換える）
- レビュアー：Claude `spec-reviewer`（Opus 5.5 / high）。作成者から独立した読み取り専用のsubagent。1回目・2回目とも同じレビュアー。主のrepositoryの `HEAD`：`ef3075fdcdaba36311df209b8fb44b7aff2df65a`（clean。レビューの前後で digest は同じ）
- 経緯：1回目は合格（P2 3件：TCC の見分けが `rev-parse` の失敗で効かない、失敗のrepositoryの標準出力の行、iss-00019 の `journal_extensions` の配線の引き受け手。P3 2件：import の別名、例外時の lock の解放）。安価に直せ F-02 と連携に効くので受け入れて直し（`probe_readable`、失敗の行、差し込み口 `journal_extensions_for`、`run_command.configure`、`finally`）、2回目で全体を見直してもらった
- 2回目の P3（直さず申し送り）：モデルの経路を作れないとき（D-01 の手順6）、`runs` には repositoryごとの `failed` を書くが、標準出力に repositoryごとの失敗の行と件数の行が出ない。実装担当の裁量で出してよい
- 結果のファイル：shipcastの `.workbench/spec-review/iss-00021/`（`round-1.json`・`round-2.json` と `.check.json`、`review-response.md`）

### 最終品質ゲート（2026-11-26）

- 結果：**合格**（キャンペーン `iss-00021-fqg-1` の attempt 01）
- 合格のコミット：`f8182d7f215486466d35b00f619d841799366402`（範囲 `ef3075f..f8182d7`、clean）
- 主：Claude `quality-gate-reviewer`（Opus 5.5 / medium）。pass、P0 0・P1 0・P2 0・P3 0、coverage complete。観点 functional-correctness・requirements-closure・test-adequacy・api-contract・security-baseline
- 試験：`uv sync --locked`、`uv run ruff check`、`uv run pytest -q`（820 passed）がすべて exit 0（タスク担当の試験レーン）
- 2人目：none（standard）
- 記録：shipcastの `.workbench/final-quality-gate/iss-00021-fqg-1/closure.md`

### PR と CI（2026-11-26）

- PR：https://github.com/chemitaro/shipcast/pull/35（`chemitaro/iss-00021` → `main`、`Refs #21`、自動で閉じる語句なし）。head `f8182d7f215486466d35b00f619d841799366402`（合格のコミットと同じ。記録のみのコミットなし）
- CI：`github-pr-checks` の observer で exit 0、`OBSERVED_CI_PASS`（2026-11-26T14:54:34Z）。Actions の `ci`（run 45843506926、event pull_request、head f8182d7）が success。coverage ACTIONS_AND_COMMIT_STATUSES、expected_inventory UNSPECIFIED、merge_readiness READY
- マージと `spec-dock work finish` は統括が行う

## Outcome

- S-01 `bca2662`。前日・指定日と対象 repository の選択を CLI に接続し、収集・日誌作成・repository ごとの実行記録をつないだ。入口と各 repository の失敗を扱い、処理中の一件の失敗で残りを止めない。
- S-02 `834c57d`。状態の置き場をロックしてから処理を始める。収集前に読み取り権限を確かめ、TCC の印があれば案内を記録する。
- S-03 `f8182d7`。同日の再実行で出来事と日誌の行は増えず、日誌は再実行時刻で置き換わり、実行履歴だけが積み上がることを試験にした。

## Verification

- 基準 `ef3075fdcdaba36311df209b8fb44b7aff2df65a`。 `uv sync --locked` → `uv run ruff check` → `uv run pytest -q` はすべて終了コード 0、792 件合格。
- S-01 `bca2662`。 `uv run pytest -q tests/test_run.py` の対象を絞って実行し、T-01 は前日計算の未実装で 4 件失敗 → 4 件合格、T-02 は未接続の CLI で 3 件失敗 → 3 件合格、T-03 は失敗処理の欠落で 4 件失敗 → 4 件合格、T-04 は入口の失敗処理の欠落で 6 件失敗 → 6 件合格（Red は終了コード 1、Green は 0）。基準と同じ 3 コマンドは順にすべて終了コード 0、全 808 件合格。
- S-02 `834c57d`。 `uv run pytest -q tests/test_run.py -k "locked_state or releases_lock"` はロックなしで 3 件失敗 → 3 件合格。`-k tcc_hint` は案内・読み取り確認の欠落で 6 件失敗・1 件合格、経路の初期化失敗を確認した `-k setup_failure` は 1 件失敗・1 件合格 → 両者を合わせた `-k "tcc_hint or setup_failure"` で 9 件合格。基準と同じ 3 コマンドは順にすべて終了コード 0、全 819 件合格。
- S-03 `f8182d7`。 `uv run pytest -q tests/test_run.py -k rerunning_same_day` は既存の重複防止で最初から 1 件合格。 `uv run python -` で 2 回目の CLI 実行時だけ、同じプロセス内で `Store.add_events` の SQL を `INSERT OR IGNORE` から `INSERT` に差し替え、pytest を起動すると `UNIQUE constraint failed: events.id` で 1 件失敗（終了コード 1）。差し替えは試験プロセス内に限定し、既存 module のファイルへの変更はない。基準と同じ 3 コマンドを通常どおり再実行し、順にすべて終了コード 0、全 820 件合格。
- ログは `.workbench/implement/iss-00021/` に保存した。実行するモデル経路は `fake` のみ。

## Residual Risks / Follow-ups

- 外付けボリュームでの macOS の TCC と実モデルでの動作は、本人が手動で確認する。 `os.scandir` が通り Git だけが拒まれた場合、案内は collector のエラー文に印がある場合に限られる。
- iss-00019 と本 Issue の統合後に、`journal_extensions_for` を台帳へつなぐ。
- 最終品質ゲートと PR はタスク担当に引き継ぐ。

## 逸脱と判断

- D-01 手順 6 は設計本文どおり、経路を作れない理由を標準エラーと各 repository の `runs` に残す。P3 で裁量とされた標準出力の行は追加しなかった。
- D-03 の件数は日誌作成の結果を数える。実行記録を保存できなかったときは別の標準エラーを出し、終了コードを 1 にする。
- プロジェクトの外部モデル利用禁止に従い、メッセージ生成に外部モデルを使う `git-autocommit` の代わりに通常のローカル `git commit` でチェックポイントを作る。
- D-04 の案内は、D-01 手順 6 でも同じ印があれば、標準エラーと `runs` の同じ理由に添える。
