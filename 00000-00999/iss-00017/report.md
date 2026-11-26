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

### 仕様のレビュー round 2（2026-11-26、仕様の変更）

- 理由：最終品質ゲート attempt 02 の ChatGPT の P1（本文の生のHTMLの `<meta name="ds-vendor-base">` で部品の読み込み先を差し替えられ、CSP が unpkg.com のオリジン全体を許していた）。ヘッドレスの Chrome で、差し替えた先の要求が CSP に止められないことを再現した（`.workbench/coding-task/iss-00017/t07/probe-before.json`）
- 変更：D-04 の CSP の `script-src` を ds.js が読む2つの版の道筋（`https://unpkg.com/@plantuml/core@1.2026.6/`、`https://unpkg.com/@highlightjs/cdn-assets@11.11.1/`）に絞る。F-04 の text・impact、requirement の decisions、design の risks、plan の T-05・T-07。手順と割り当ては変えない
- 結果：Claude `spec-reviewer`（同じレビュアー、Opus 5.5 / high）**合格**（P0 0件、P1 0件、P2 4件、P3 2件）。`.workbench/spec-review/iss-00017/round-2.json`、`round-2.check.json`（exit 0）
- 固定した文書（sha256）：
  - `requirement.cue`：`02354bd8ba0b35bbdc6951d576025911cab926ff7f5dd1ca3fac8b3901dde69e`
  - `design.cue`：`8ed402bcda10b7389433214e2b93e4f2ac0afedf83bc406c9e1c6c381cb2a4e6`
  - `plan.cue`：`54627513abf32abaf598344c842b8922b4f169e77c9edeed406918a36906de2f`
- 新しい P2（情報）：配信する ds.js は登録した repository（または `design_system_dir`）のもので、T-05 はこの repository の ds.js の版とだけ比べる。本人の repository の SpecDock が部品の版を上げると、図と色分けが描けなくなる（本文は描ける）。残りのリスクに記録
- ほかの P2/P3 は round 1 と同じ（申し送り済み）

### 仕様のレビュー round 3（2026-11-26、仕様の変更。上限の最後の回）

- 理由：round 2 の ChatGPT（GPT-6 / Extra High、session `required-strict-github-connector-verificati-1565`、canonical `1c440c0`）の P1 3件。(1) 元からある `<\/script`・CR・NUL が保たれないのに R-01 が「元に戻る」と言い切っていた (2) Host の点のない1語の名前は DNS の検索ドメインで外の名前になりうる (3) `%2f` を復号してから分けるので、親 epic-00005 の F-02 の「符号化した `%2f` を拒む」と食い違う。3件とも正しいと判断（`.workbench/spec-review/iss-00017/review-response.md`）
- 変更：D-01 に保たれない変換を明記し R-01 を限定。D-05・F-05・T-08 で1語の名前を受けない。D-03・F-02 で生の `/` で分けてから部分ごとに復号し、復号した部分の `/`・`\`・NUL を拒む。T-03・T-01 に例を足す
- 固定した文書（sha256）：
  - `requirement.cue`：`d0442a3631d2efda6402dc3e23ead2798e367dc7ff50d48cdf36ead78ce6e9c9`
  - `design.cue`：`5ffc5108c48e35313851faed10b1220fa7f86fcd6613c0ad075504f31e42cc97`
  - `plan.cue`：`ff3f7a43bc688b22015d86a4fda0aee0eedb4f35440227ef131e96c06a5b38f4`
- Claude `spec-reviewer`（同じレビュアー）：**合格**（P0 0、P1 0、P2 4、P3 3）。`round-3.json`、`round-3.check.json`（exit 0）。新しい P3：保たれない変換の一覧に、大文字の `</SCRIPT` が小文字になることが入っていない（D-01 の別の行に書いてある）
- ChatGPT（同じ会話の続き、session `required-strict-github-connector-verificati-1567`、canonical `288c17e`）：pass（P0 0、P1 0、P2 2）。round 2 の P1 3件を「閉じてよい」と判断。P2 は round 2 と同じ2件（CSP の版の試験が実行時のデザインシステムを見ない、起動の検査が `vendor/marked.umd.js` の欠けを見ない）。注：この続きの回は選択画面を飛ばしたため、モデルの選択の証拠が `verified=no`（思考は Extra High が verified）。同じ会話の round 2 では GPT-6 が verified。どちらの判断でも P0/P1 はない
- 判定：**round 3 で合格**（Claude pass、ChatGPT の P0/P1 なし）。`.workbench/spec-review/iss-00017/round-3.chatgpt.txt`

### 区切りのレビュー CP-1（2026-11-26）

- 結果：**合格**（round 1。規約の観点 P0〜P3 0件、仕様の観点 P0〜P3 0件）
- 範囲：`f68349a24851528b6c42e4f0ad6e84388e29ea91..ea6c4b4bd114571e4c15914e27c0013be7d67174`（S-01〜S-03）。レビューの前に `chemitaro/iss-00017` を push（upstream と同じ）
- レビュアー：Claude `code-reviewer`（Opus 5.5 / medium。strict の既定）を `axis: standards` と `axis: spec` の2人で並行
- 結果のファイル：shipcast の worktree の `.workbench/code-review/iss-00017-cp1/round-1-{standards,spec}.json` と `.check.json`（`validate-review.py` が両方 exit 0、status pass）。前後の digest は同じ

## Outcome

- S-01 `d7146d9`（impl-ui：タスク担当 Opus 5.5 / high、同じセッション）：`shipcast.page` の `wrap_markdown`（`</script` の ASCII の大小を問わない置き換えと、末尾の `\n<!-- -->\n`）、`notice_page`・`NOT_FOUND_PAGE`・`BROKEN_JOURNAL_PAGE`、架空の見本の日誌、dev の `html5lib`。
- S-02 `006490f`（impl：Codex GPT-6.2 Sol / medium、dispatch `ctx_7dcbd70ff6a0`）：`split_path`・`resolve_inside`・`security_headers`・`host_allowed`。
- S-03 `ea6c4b4`（impl）：`create_server`（`end_headers` の1つの出口、GET/HEAD、405・501、IPv6）、`find_design_system`、`shipcast serve` の葉と `cli.py` の接続。
- S-04 `5509559`（impl-ui-verify：タスク担当）：README の「日誌を読む（`shipcast serve`）」の節と `tests/test_readme.py`、T-07 のブラウザーでの確かめ（下）。

## Verification

開始の HEAD `f68349a` の基準（`.workbench/implement/iss-00017/start.md`）：`uv sync --locked`・`uv run ruff check`・`uv run pytest -q`（165 passed）・`uv run shipcast serve --help` がすべて exit 0。

| ステップ | Red | Green |
|---|---|---|
| S-01（T-01・T-10 の一部） | `uv run pytest -q tests/test_page.py` が収集の誤り（`shipcast.page` がない） | 同じコマンドで 29 passed。全体 194 passed、ruff 合格 |
| S-02（T-03・T-05・T-08 の関数） | `uv run pytest -q tests/test_serve.py -k <関数>`：split_path 16 失敗ほか | 32 passed、ruff 合格 |
| S-03（T-02〜T-06・T-08〜T-10 の配信） | 同じ形で各試験の失敗を確認（実装担当の報告） | 全体 292 passed |
| S-04（T-06 の README） | `uv run pytest -q tests/test_readme.py` が 2 failed | 2 passed。全体 294 passed |

S-04 の後の `test_commands`：`uv sync --locked` 0、`uv run ruff check` 0、`uv run pytest -q` 0（294 passed）、`uv run shipcast serve --help` 0。

### T-07 ブラウザーでの確かめ（2026-11-26）

- 方法：この worktree の `spec-dock/design-system/` を `design_system_dir` にした一時の設定（`.workbench/coding-task/iss-00017/t07/config.toml`）で `uv run shipcast serve`（127.0.0.1:18768）を立て、ヘッドレスの Chrome を CDP で操作（幅 1280 と 390、`--disable-features=MacAppCodeSignClone`、`Browser.close` で閉じた）。結果は `.workbench/coding-task/iss-00017/t07/t07-result.json`、画面の写しは同じ場所の `t07-page*-{1280,390}.png`。Orca の組み込みのブラウザーは幅の模擬が効かず、`frame-ancestors 'none'` で枠に入れられないため、CDP を使った（計画の「Orca の組み込みのブラウザー」からの逸脱。確かめる内容は同じ）。
- 見本の日誌（`/demo-app/2026-11-26`）：部品（`:::summary`・`:::warning`）、PlantUML の図（1/1 描画、unpkg から）、コードの色分け（highlight.js）が描けた。`document.title` は前付けの題名のままで、`<img onerror>` と `</script><script>` のコードは動かず、コードは文字のまま見えた。390px で `scrollWidth` 390（横にはみ出さない）。
- コンソール：CSP の違反は、見本の `onerror` を止めた1件（`Executing inline event handler violates … script-src`）だけ（仕様レビューの申し送りどおり想定内）。ほかに `<img src=x>` の 404 が1件。図の部品は `'wasm-unsafe-eval'` の下で描けた。
- 閉じない `<!--<script>` を本文に含む日誌（`/demo-app/2026-11-29`）：包みが閉じ、ds.js が起動して本文・コード・フッターまで描けた。
- BOM 付きの日誌（`/demo-app/2026-11-28`）：前付けが読まれ、題名と lead が描けた。
- 404（`/nope`）：デザインシステムで描いた案内のページ。
- 実サーバーで `curl`：Host `evil.example` は 400、`/_ds/%2e%2e/%2e%2e/README.md` は 404、`/_ds/ds.css` は 200 `text/css; charset=utf-8`、どの応答にも CSP・nosniff・no-referrer と `Server: shipcast`。
- Ctrl+C：プロセスグループへの SIGINT で、`python -m shipcast serve` と `uv run shipcast serve` の両方が終了コード 0。

## 逸脱と判断

- ブランチ：計画の `gates.pr` は `iss-00017` だが、統括の指示（2026-11-26、本人の指示の伝達）で、`spec-dock work start iss-00017 --branch chemitaro/iss-00017` を仕様レビューの完了前に実行し、現在のブランチ `chemitaro/iss-00017` をそのまま使う。PRもこのブランチから作る
- T-07 の確かめは、Orca の組み込みのブラウザーではなく、ヘッドレスの Chrome を CDP で操作して行った（理由は Verification の T-07）
- CP-1 の後、Codex の実装担当は返事を待たずに worker_done で終わった。直しがなかったので影響はない
- 実装担当（S-02・S-03）の判断：標準のハンドラーが先頭の連続する `/` を1つにまとめるため、道筋の検査には元の要求の行の対象を使う。Host が複数あるときも 400。HTTP/0.9 の要求の 400 にも状態行とヘッダーを返す。ファイルの解決の失敗・消失は 404、日誌を読むときのほかの入出力の誤りは 500 の案内と標準エラーの1行。コミットの文は手元で書いた（外部のモデルを呼ばない規則のため）
- 仕様の `perspectives` の `security` は、最終品質ゲートの契約の観点 `security-baseline` として扱った

## Residual Risks / Follow-ups

- **前付けの値の生のHTML（デザインシステム側の挙動）**：前付けの `lead` に閉じない `<!--` があると、ds.js がページの頭（シェル）を組むときに壊れ、`mountShell` の例外で本文が描かれない（T-07 で確認。本文の中の `<!--` では起きない）。日誌の書き手（iss-00016）は前付けの値に生のHTMLを書かないこと。shipcast の包みでは防げない（ds.js の中の処理）。
- 本文が閉じていないコードの囲みで終わる日誌では、末尾の `<!-- -->` がコードの中に見える。
- `https://unpkg.com` 全体を script に許している（ds.js が決まった版の部品を読むため）。
- Host の検査は、`.ts.net` でない独自の名前で読む使い方を拒む。
- iss-00018 への申し送り：一覧 `/<repo>/` を足すとき、`split_path` に末尾の `/` の扱いを足す（今は `None`）。
- 統括への申し送り：親 epic-00005 の F-03・D-01・D-05 が `<!--` を `<\!--` に置き換える案のまま。子の decisions と試作の証拠に合わせて親を直すかの判断。
- ChatGPT の仕様レビューの2人目は取得できなかった（60分応答なし）。
