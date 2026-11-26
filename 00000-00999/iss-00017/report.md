---
種別: レポート（Issue）
ID: "iss-00017"
関連GitHub: ["#17"]
最終更新: "2026-11-26"
依存: ["requirement.cue", "design.cue", "plan.cue"]
---

# Result Summary

詳細: [Report Guide](../../../docs/authoring/report.md)

## レビュー記録

### 仕様のレビュー（2026-11-26）

- 結果：**合格**（round 1。Claude：P0 0件、P1 0件、P2 3件、P3 2件。ChatGPT：取得できず）
- 1人目：Claude `spec-reviewer`（Opus 5.5 / high。strict の既定）。作成者から独立した読み取り専用のsubagent
- 2人目：ChatGPT（GPT-6 / Extra High、`chatgpt-spec-review-strict`）。canonical の `dc5695cedc5376d7bb5d44874b6bb392a8cc4d39`（`spec-dock/canonical`、upstream と同じ、下の sha256 と同じ中身）で送信したが、60分の間に思考の表示も応答もなく打ち切った（Oracle の session `required-strict-github-connector-verificati-1554`）。spec-review の規則により、この回は2人のレビューではない
- 固定した文書（sha256）：
  - `requirement.cue`：`c0cd4a9421e7219bcf36d5bd300a7d79c0f05e5f37a45ba1db03bcb6d9931895`
  - `design.cue`：`7b52fae0adc229aa81d545a188adc20d97306f6f26beb891563be37682ebc715`
  - `plan.cue`：`57bdbb7cf8cc07f2e374cb7ca31eda4aab2cd936ed01f5acb99168867f742a4e`
- worktree の `HEAD`：`f68349a24851528b6c42e4f0ad6e84388e29ea91`（clean。レビューの前後で digest は同じ）
- 結果のファイル：shipcast の worktree の `.workbench/spec-review/iss-00017/round-1.json`、検証は `round-1.check.json`（`validate-review.py` が exit 0、status pass）、応答は `review-response.md`
- 情報の指摘（止めない。文書は直さず、意味を保つ解釈として申し送る）：
  - P2：T-07 の「CSPの違反がない」と、見本の `<img onerror>` を止めたときの違反が両立しない。申し送り：「見本の `onerror` を止めた1件以外の違反がない」と読み、その1件は想定内として記録する
  - P2：`split_path` が `/<repo>/` を `None` にする。申し送り：このIssueでは `/<repo>/` は404でよい。iss-00018 が一覧を足すときに、末尾の `/` の扱いを `split_path` に足す
  - P2：BOM付きの日誌で `ds-source` にBOMが残り、ds.js が前付けを読めない。申し送り（S-03）：包む前に先頭のBOMを1つ外す（`parse_journal` と同じ扱い）。試験を1件足す
  - P3：標準の `ThreadingHTTPServer` はIPv6で立たない。申し送り（S-03）：`host` に `:` を含むときは `AF_INET6` のサーバーで立てる
  - P3：親 epic-00005 の F-03・D-01・D-05 が `<!--` の置き換えのまま。統括へ申し送る（親の文書は統括の範囲）

## Outcome

## Verification

## 逸脱と判断

- ブランチ：計画の `gates.pr` は `iss-00017` だが、統括の指示（2026-11-26、本人の指示の伝達）で、`spec-dock work start iss-00017 --branch chemitaro/iss-00017` を仕様レビューの完了前に実行し、現在のブランチ `chemitaro/iss-00017` をそのまま使う。PRもこのブランチから作る

## Residual Risks / Follow-ups
