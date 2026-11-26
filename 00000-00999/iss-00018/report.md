---
種別: レポート（Issue）
ID: "iss-00018"
関連GitHub: ["#18"]
最終更新: "2026-11-26"
依存: ["requirement.cue", "design.cue", "plan.cue"]
---

# Result Summary

詳細: [Report Guide](../../../docs/authoring/report.md)

## レビュー記録

### 仕様のレビュー（2026-11-26）

- 結果：**合格**（round 1。P0 0件、P1 0件、P2 1件、P3 1件）
- レビュアー：Claude `spec-reviewer`（Opus 5.5 / medium。light の既定）。作成者から独立した読み取り専用のsubagent
- 固定した文書（sha256）：
  - `requirement.cue`：`c6fcfe3096c4b66a0d1c1e348ed47eaa54b20ffe5c53fbf83b76da3223cb88b9`
  - `design.cue`：`d5210c854d663767a8064e5dedfee95c956218e3ae1962f751e16b61cabb07fa`
  - `plan.cue`：`b53ee8b156c2dee3a43b9503b41b44107779cbfa972f73baae4b8b57efd6b595`
  - `explanation.html`：`a756d31020d2b40ec548e6e18bbbe848d82f3b468c6d37f7a3871ee2af02332a`
- コードの基準：`b7832b86e0ac3e538729e4b06f9fcb321ab8e563`（`chemitaro/iss-00018`、clean）
- 結果のファイル：`.workbench/spec-review/iss-00018/round-1.json`（検査 `round-1.check.json`：valid、pass）
- P2：互換性の記述が、`/missing` を404とみなす既存の試験の変化を挙げていない（情報として記録）
- P3：日を1つも持たない repository のディレクトリで、表紙のリンクが404の一覧を指す（情報として記録。残りのリスク）
- 以後、`plan.cue` の `status` のほかは要件・設計・計画を変えない

### 仕様のレビュー round 2（2026-11-26、合格の後の仕様の変更）

- 理由：S-02 のブラウザーでの確かめ（T-06）で、`&` の参照（`&amp;` が `&` と見える）とカードの `badge` の長い repository の名前（390pxで `scrollWidth` 470）が見つかり、D-03・D-04・R-03・T-01・T-02 と説明資料を直した（`.workbench/spec-review/iss-00018/review-response.md`）。セッションの値と手順の割り当ては変えない
- 結果：**合格**（同じ `spec-reviewer` を継続。P0 0件、P1 0件、P2 1件、P3 1件。round 1 と同じ指摘）
- 固定した文書（sha256）：
  - `requirement.cue`：`84b2681f3da6957dc3eb60df73e78a174f7bafe6fa358de10a3806724409b449`
  - `design.cue`：`d233cce36036ebe4660339869e00796f547c94379e83e6a1f255da5122cc5ac9`
  - `plan.cue`：`b83382241879a83036aec61b972c27173eac1b3bdca24a22ca5868d1426a5eeb`（`status` のほか）
  - `explanation.html`：`438cc1212eef2f016e4f4a28e32703232bca1709a0e5bf50ac24463287b84a9d`
- コードの基準：`bf9af47d11df2c3e80cda7f71b908af3ca24c676`（clean）
- 結果のファイル：`.workbench/spec-review/iss-00018/round-2.json`（検査 `round-2.check.json`：valid、pass）

### 最終品質ゲート（2026-11-26）

- 結果：**合格**（attempt 01。P0 0件、P1 0件、P2 0件、P3 2件、coverage complete）
- 合格のコミット：`bf9af47d11df2c3e80cda7f71b908af3ca24c676`（開始 `b7832b8` から）。記録のコミットなし
- レビュアー：`quality-gate-reviewer`（Opus 5.5 / medium）。観点：functional-correctness、requirements-closure、test-adequacy、security-baseline
- 試験：`uv sync --locked`・`uv run ruff check`・`uv run pytest -q`（659 passed）・`uv run shipcast serve --help` がすべて終了コード0
- `closure.md`：`.workbench/final-quality-gate/iss-00018-fqg/closure.md`

## Outcome

- `/` に表紙（repositoryごとの最新の日誌の `:::cards`、repositoryごとの一覧へのリンク）、`/<repo>/` に一覧（月ごとの `:::timeline`、日付・題名・lead、新しい順）、`/<repo>` は `/<repo>/` へ301。
- 前付けの値は `shipcast.page.markdown_text` で記号を文字参照にしてから入れ、部品の属性・見出し・リンク・HTMLにならない。
- 置き場を歩くときは、repository・年・ファイルの各段で `resolve_inside` を通す。
- `split_path` は末尾の `/` を最後の空の部分として返す（iss-00017 の申し送りを解消）。

## Verification

### 実装の手順

- 開始のコミット：`b7832b86e0ac3e538729e4b06f9fcb321ab8e563`。基準の試験：`uv run pytest -q` 全合格（iss-00017 の統合の後）
- S-01 `acb0ed4`（impl-ui：タスク担当の同じセッション、Opus 5.5 / medium）：`markdown_text`・`JournalDay`・`index_markdown`/`repo_markdown`・`index_page`/`repo_page`、`NOT_FOUND_PAGE` の文。Red：`ImportError`（`JournalDay`）→ Green：`tests/test_page.py` 35 passed
- S-02 `bf9af47`（同じセッション）：`split_path` の末尾の `/`、`journal_repos`・`journal_files`・`read_meta`・`journal_days`・`latest_journals`、`/`・`/<repo>/`・`/<repo>` の道筋、起動の表示、README。T-06 で見つけた2点（`&` → `&amp;`、`badge` は日付だけ）を同じコミットで直した。Red：19 failed → Green：`tests/test_serve.py` 134 passed、全体 659 passed、ruff 合格

### T-06：実際のブラウザー（Orca の組み込みのブラウザー、2026-11-26）

- 本物の `spec-dock/design-system/` と、一時の見本の置き場（`.workbench/coding-task/iss-00018/browser/`：敵対的な題名・lead、55字の repository 名、240字の題名、空白のない長いASCII、壊れた前付け）で `shipcast serve --port 8799` を立てた
- iPhone 12 の幅（390px）：`/`・`/demo-app/`・`/<長い名前>/`・`/sample-lib/` で `scrollWidth == clientWidth == 390`、右にはみ出す要素なし（直す前は `badge` の長い名前で 470）。広い幅（エミュレーションなし、3499px）でも `scrollWidth == clientWidth`
- 表紙：カード3枚が日付の新しい順、`href` はすべて `/<repo>/<day>`。敵対的な題名 `直した {href=https://evil.example} **太字** [x](https://evil.example) :::` と lead `## x :::cards <img src=x onerror=…> &amp; :name[y] {now}` が文字のまま見え、`<img>` の要素は作られず、`document.title` は変わらない（`onerror` は動かない）
- 一覧：月の見出しと時系列、4日分（壊れた日は固定の文）、表紙へのリンク
- 画面の写し：`.workbench/coding-task/iss-00018/browser/cover-390.png`、`list-390.png`
- CSPの違反：Orca の CLI にコンソールの読み取りがないため直接は見ていない。敵対的な値から要素が作られないことで、違反の元がないことを確かめた

## Residual Risks / Follow-ups

- 日を1つも持たない repository のディレクトリも、表紙の「repositoryごとの一覧」にリンクが出て、押すと404（仕様レビューの P3）。
- 題名に U+2028/U+2029 があると、表紙のカードが前のカードに混ざる（最終品質ゲートの P3、形の崩れのみ）。日誌の書き手は前付けの値を1行の普通の文字にする。
- T-06 は Orca の CLI にコンソールの読み取りがないため、CSP の違反をコンソールで直接は見ていない（最終品質ゲートの P3）。
- 表紙と一覧は要求のたびに置き場を歩く。日誌が何年分にもなると遅くなりうる。
- ds.js の部品の書き方が変わると、表紙と一覧の形が崩れうる。デザインシステムの更新のときに T-06 をやり直す。
- 既存の試験の `/missing`（301になる）を `/missing/` に直した（仕様レビューの P2。互換性の記述の範囲の外）。
