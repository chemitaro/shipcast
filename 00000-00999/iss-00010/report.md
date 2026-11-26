---
種別: レポート（Issue）
ID: "iss-00010"
関連GitHub: ["#10"]
最終更新: "2026-11-26"
依存: ["requirement.cue", "design.cue", "plan.cue"]
---

# Result Summary

詳細: [Report Guide](../../../docs/authoring/report.md)

## レビュー記録

### 仕様のレビュー（2026-11-26）

- 結果：**合格**（1回目。P0 0件、P1 0件、P2 3件、P3 0件）
- レビュアー：Claude `spec-reviewer`（Opus 5.5 / high。保証レベル standard の既定）。作成者から独立した読み取り専用のsubagent。ChatGPTの2人目はなし（standard）
- 固定した文書（sha256）：
  - `requirement.cue`：`df42354c5d036915978fcfa2ae3abde53b3f5e23ba0d489832a7977fd4489821`
  - `design.cue`：`da0e8eb1668b38f725fd0252b63d227b49cecacac101548419b9b8a8cbe28ef0`
  - `plan.cue`：`09f4cc69d8e53d0e6743b32be4da98fb348abbcb14d3a8acf3f4af38e3025665`
- 照らした正本：`content/decisions/20261126-journal-format-and-hackathon-plan.md`、`AGENTS.md`、epic-00002 の要件・設計・計画、init-00001 の `plan.cue`（delivery）、`spec-dock/docs/authoring/cue.md`
- 主のrepositoryの `HEAD`：`279f747e516213e1341b9e8e566bb52f3bcb6d84`（clean。レビューの前後で digest は同じ）
- 結果のファイル：shipcastの `.workbench/spec-review/iss-00010/round-1.json`、検証は `round-1.check.json`（`validate-review.py` が exit 0、status pass）
- 情報の指摘（止めない。文書は直さず記録だけ。実装担当への申し送り）：
  - P2-1：Story の `to_dict` の鍵の順が、D-02 の表（`neta` が `why` の後）と D-03 のJSONの例（`neta` が最後）で食い違う。申し送り：D-03 の「上の表」は D-02 の表を指すので、**D-02 の表の順（dataclassの項目の順）** を正とする。JSONの例は鍵の集まりの見本として読む（解釈。`## 逸脱と判断` に記録する）
  - P2-2：`from_dict` で日付・時刻の文字列が読めないとき（`"2026-13-01"` など）に `ModelError` になる約束が D-03 にない。申し送り：F-01 の「型が違う」の一つとして、`fromisoformat` の `ValueError` を項目を名指す `ModelError` に包む。T-04 に1件足してよい（F-01 の意味を保つ解釈）
  - P2-3：未消化の話題のIDから Story を読む関数（前の日の話題を含む）がなく、iss-00019・iss-00020 が題名や中身を読むときに足りない。このIssueの受入は阻害しない。後のIssue（iss-00019 か iss-00020）の申し送りとして残す（そのIssueの設計で、このIssueの D-06 に読み出しの関数を足し、`Store` に1か所で書く）

### 最終品質ゲート（2026-11-26）

- 結果：**合格**（attempt 01。P0 0件、P1 0件、P2 0件、P3 0件、coverage complete）
- 合格のコミット：`018aa49b59a1e5cb7af95fb83ca7df23c8c763b5`（範囲 `279f747..018aa49`）
- レビュアー：Claude `quality-gate-reviewer`（Opus 5.5 / medium）。観点 functional-correctness、requirements-closure、test-adequacy、api-contract。second_opinion none（standard）
- テスト：`uv sync --locked`、`uv run ruff check`、`uv run pytest -q`（106 passed）がすべて exit 0
- 記録：shipcastの `.workbench/final-quality-gate/iss-00010-fqg-1/closure.md`
- 経緯：1回目の呼び出しでレビュアーが結果のファイルを書かずに返した（機械的な失敗）。同じレビュアーに再依頼し、書かれた結果を検証した（回数に数えない）
- 区切りのレビュー：なし（`plan.cue` の `gates.checkpoints` の理由のとおり）
- `plan.cue` は仕様レビューの合格後に、各 step の `status: "done"` を足しただけ（中身の変更なし）

## Outcome

- 実装担当：Codex（GPT-6.2 Sol / medium、Orcaの作業者 `ctx_28bfa59f28f2`、このworktree）。開始のコミット `279f747`。
- S-01 `f1d99cd56ffd959517c373e312a2d1b2f28a461d`：`shipcast.model` に `ModelError`、`Event`・`Neta`・`Story`・`Entry`、`event_id`・`story_id`、`to_dict`・`to_json`・`from_dict`・`from_json`。
- S-02 `73e4cf4e135003a9056894676768fc8b859f7766`：`JournalFormatError`、`JOURNAL_REQUIRED_FIELDS`・`JOURNAL_FIELDS`、`JournalMeta`、`journal_path`、`write_frontmatter`、`parse_journal`、`read_frontmatter`。
- S-03 `018aa49b59a1e5cb7af95fb83ca7df23c8c763b5`：`shipcast.state` に `StateError`、`Run`、`Store` と5つの表（版1）。
- 変えたファイルは `src/shipcast/model.py`、`src/shipcast/state.py`、`tests/test_model.py`、`tests/test_journal.py`、`tests/test_state.py` だけ（iss-00009 と重ならない）。

## Verification

- 開始のコミットのベースライン：3つの test_commands がすべて0（pytest 25 passed）。
- S-01：Red 8件（Event 2、Story 2、Entry 2、ID 1、JSONの解釈の誤り 1）→ Green（モデルの試験 38件）。
- S-02：Red 30件（パス 7、前付け 23）→ Green（前付け 30件、モデルと合わせて 68件）。
- S-03：Red 13件（初期化 3、Event 2、Story・Entry 2、Run 5、ネタ 1）→ Green（状態 13件）。
- 最後の `HEAD` で `uv sync --locked`、`uv run ruff check`、`uv run pytest -q`（106 passed）がすべて0。仕様3点の sha256 は、実装の前後ともレビュー記録と一致。

## 逸脱と判断

- P2-1（解釈）：Story の `to_dict` の `schema` の後の鍵の順は、D-02 の表の順（`id, repo_id, date, title, what, why, neta, notice, waiting, event_ids`）にした。
- P2-2（解釈）：`from_dict` で日付・時刻の文字列が読めないとき、`fromisoformat` の `ValueError` を項目を名指す `ModelError` に包み、T-04 で確かめた。
- 区切りのレビューはなし（`plan.cue` の理由のとおり）。

## Residual Risks / Follow-ups

- P2-3（上）：未消化の話題の中身を読む `Store` の関数は、iss-00019・iss-00020 で足す。
- PR：https://github.com/chemitaro/shipcast/pull/24（branch `chemitaro/iss-00010`、head `018aa49b59a1e5cb7af95fb83ca7df23c8c763b5`、base `main` `279f747`）。`Refs #10`（自動で閉じる書き方は使わない）
- CI：`ci` run 45805357159（pull_request、`018aa49`）が success。`github-pr-checks` の観測は OBSERVED_CI_PASS、coverage ACTIONS_AND_COMMIT_STATUSES、merge_readiness READY（2026-11-26T10:53:40Z）。外部の CheckRun は観測の範囲外。
- マージと `spec-dock work finish` は統括が行う。
