---
種別: レポート（Issue）
ID: "iss-00009"
関連GitHub: ["#9"]
最終更新: "2026-11-26"
依存: ["requirement.cue", "design.cue", "plan.cue"]
---

# Result Summary

詳細: [Report Guide](../../../docs/authoring/report.md)

## レビュー記録

### 仕様のレビュー（2026-11-26）

- 結果：**合格**（1回目。P0 0件、P1 0件、P2 3件、P3 1件）
- レビュアー：Claude `spec-reviewer`（Opus 5.5 / high。保証レベル standard の既定）。作成者から独立した読み取り専用のsubagent。ChatGPTの2人目はなし（standard）
- 固定した文書（sha256）：
  - `requirement.cue`：`42ce9b333a643e086f1dac8495b219f31811944df5393f6fc76e65d61cada3b2`
  - `design.cue`：`9f62082a7698d1eb252362a1c5ec90ef0346c214e2bf170de9fd6cb51575f482`
  - `plan.cue`：`d0c0c063cdbc495f2ac04a509a150fac8b1f094952c78dd936c4be3cdaed2d90`
- 照らした正本：`content/decisions/20261126-journal-format-and-hackathon-plan.md`、`AGENTS.md`、epic-00002 の要件・設計・計画、init-00001 の `design.cue`・`plan.cue`、`spec-dock/docs/authoring/cue.md`、`src/shipcast/cli.py`、`tests/test_cli.py`
- worktree の `HEAD`：`279f747e516213e1341b9e8e566bb52f3bcb6d84`（clean。レビューの前後で digest は同じ）
- 結果のファイル：shipcastの `.workbench/spec-review/iss-00009/round-1.json`、検証は `round-1.check.json`（`validate-review.py` が exit 0、status pass）
- 情報の指摘（止めない。文書は直さず、実装担当への申し送り＝意味を保つ解釈として渡す）：
  - P2：`repos = [...]`（インラインの配列）の設定に `[[repos]]` を足すと、`tomllib` は手順6の比較の前に文法の誤りを投げる。申し送り：元の中身は読めたのに合成後の文字列が読めないときは、D-06 手順6と同じ誤り（直し方「`repos` を `[[repos]]` の形で書いてください」）にする
  - P2：UTF-8の文字列で読むとCRLFが `\n` に変わり、先頭のバイト列が変わりうる。申し送り：読み書きとも改行を変換しない（`newline=""` かバイト列）。CRLFのファイルの試験を T-09 に足す
  - P2：タブ・改行を含む `title`・`path` で `repo list` の1件1行が崩れる。申し送り：`repo list` の出力では各値の `\` を `\\`、タブを `\t`、改行を `\n`、CRを `\r` に置き換えて1件1行を保つ（T-15 に1件足す）
  - P3：要件の「`cli.py` の `repo` の行だけ」と、設計 D-01 の `import` の1行の追加の食い違い。D-01 に従う（`import` の1行は `repo` の行の変更に付随するもの）

### 最終品質ゲート（2026-11-26）

- 結果：**合格**（attempt 01。P0 0件、P1 0件、P2 0件、P3 0件、coverage complete）
- 合格のコミット：`9e5a113923fa0f50a88fe56c44867b79ebdc9c71`（範囲 `279f747..9e5a113`）
- レビュアー：Claude `quality-gate-reviewer`（Opus 5.5 / medium）。観点 functional-correctness、requirements-closure、test-adequacy、api-contract、reliability-recovery。second_opinion none（standard）
- テスト：`uv sync --locked`、`uv run ruff check`、`uv run pytest -q`（84 passed）、`uv run shipcast --help`、`uv run shipcast repo --help` がすべて exit 0
- 記録：shipcastの worktree の `.workbench/final-quality-gate/iss-00009-fqg-1/closure.md`
- 実装担当の追加の判断（仕様にない並行登録のロック、設定先が登録対象の内側なら止める動き、`cli.py` の `# isort: skip`）は、レビュアーが「正しく安全で、仕様の意味に反しない」と判断した
- `plan.cue` は仕様レビューの合格後に、各 step の `status: "done"` を書いただけ（中身の変更なし）

## Outcome

- S-01 `e822849452208bd375e315a0349b3fd0b90655b7` で、schema 1 の設定を読み込み、検証済みの凍結 dataclass を返す API を追加した。
- S-02 `0c428f22f90c5604b339874c5b2e5539a816b957` で、`shipcast repo add` に既定設定の作成と既存設定への追記を追加した。置き換えに失敗した場合は元の設定が残る。
- S-03 `9e5a113923fa0f50a88fe56c44867b79ebdc9c71` で、`shipcast repo list` に登録順の表示と、未登録・設定異常時の案内を追加した。最終 HEAD はこのコミット。

## Verification

開始 HEAD は `279f747e516213e1341b9e8e566bb52f3bcb6d84`。開始時と実装完了時に、レビュー合格記録の仕様3点の SHA-256 と一致することを確認した。

| コマンド（実行順） | 開始時の終了コード・結果 | S-03 完了時の終了コード・結果 |
|---|---|---|
| `uv sync --locked` | 0 | 0 |
| `uv run ruff check` | 0 | 0 |
| `uv run pytest -q` | 0、25件合格 | 0、84件合格 |
| `uv run shipcast --help` | 0 | 0 |
| `uv run shipcast repo --help` | 0 | 0 |

| ステップ | Red | Green |
|---|---|---|
| S-01（T-01〜T-07） | `uv run pytest -q tests/test_config.py --tb=no` は1、設定モジュールの未実装で25件失敗 | `uv run pytest -q tests/test_config.py` は0、25件合格。`uv run ruff check` は0 |
| S-02（T-08〜T-14） | `uv run pytest -q tests/test_repo.py --tb=short` は1、`repo add` と登録用 API の未実装で29件失敗 | `uv run pytest -q` は0、追加の保護・並行登録テストを含む80件合格。`uv run ruff check` は0 |
| S-03（T-15〜T-17） | `uv run pytest -q tests/test_repo.py -k test_list --tb=short` は1、`repo list` の未実装で5件失敗 | `uv run pytest -q tests/test_repo.py -k test_list` は0、5件合格。全体の結果は上表のとおり |

## 逸脱と判断

- T-13 では、元の `repos = [...]` が読めても、`[[repos]]` を足した後に再解析できなければ D-06 手順6と同じ案内（「`repos` を `[[repos]]` の形で書いてください」）を返すことを確認した。
- 読み込みはバイト列の UTF-8 デコード、書き込みは `newline=""` を使用した。T-09 では CRLF の設定でも先頭のバイト列が一致することを確認した。
- 一覧では各値のバックスラッシュ、タブ、LF、CR をそれぞれ `\\`、`\t`、`\n`、`\r` に変換する。T-15 では4件目の題名にこれらの文字を含めて1件1行を確認した。
- `cli.py` の変更は `from shipcast import repo` の追加と `repo` の2つの `Entry` への接続。既存のバージョン import の行を保つため、追加した import に `# isort: skip` を付けた。
- 設定の書き込み先を解決した結果が登録対象の内側なら、対象の読み取り専用の条件を守るためエラーにした。設定先が対象内へのシンボリックリンクであるケースを試験した。
- POSIX では親ディレクトリをロックし、読み込み後に原文が変わっていた場合は再読み込みしてから追記する。macOS 上で同じ設定に対する2件の同時登録が両方残ることを試験した。非 POSIX 環境の書き込みは D-07 の不可分な置き換えを使用する。

## Residual Risks / Follow-ups
