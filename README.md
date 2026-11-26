# shipcast

**ソフトウェアファクトリーの時代の開発者のための、エージェントが書く開発日誌。**

AIエージェントが開発をほぼ自動で進めると、物事は前に進みます。一方で、何が起き、なぜそうなったのかを人間が理解しないまま進んでしまいます。shipcastは、その日に起きたことをエージェントが集め、人間が読みやすい文体の開発日誌を、プロジェクトごとのきれいなWebページにします。

おまけとして、日誌の中の話題に「ネタポイント」がたまると、「そろそろXに投稿できる」「noteの記事にまとめられる」と知らせ、下書きを出します。

1. Git・SpecDock・登録した成果から、出来事（Event）を集めます。
2. 意味のある話題（Story）にまとめ、事実の骨組みを作ります。
3. 人間が読みやすい文体に清書し、日誌のページを作ります。
4. 話題ごとにネタポイントをため、たまったら発信の下書き（X・note・Reddit）を出します。

**外への投稿は、必ず人間が行います。** shipcastは下書きまでを作り、自分では投稿しません。

## 状態

構想と仕様を作っている段階です。動くコードはまだありません。議論と決定は[`content/`](content/)にあります。

## 置き場の原則

- このrepositoryには汎用のエンジンだけを置きます。公開してよい内容に限ります。
- 個人の設定（対象のrepository、公開範囲）と実行の状態（素材、日誌、下書き、投稿の履歴）は、このrepositoryの外に置きます。

## 導入と毎晩の実行（`shipcast schedule`）

### 導入

```sh
uv tool install git+https://github.com/chemitaro/shipcast
uv tool update-shell
```

手元のソースから導入する場合は、main の checkout で `uv tool install .` を実行します。更新は `uv tool upgrade shipcast` です。夜間の登録には `uv tool install` で入れた `shipcast` を直接実行してください。開発用 worktree の `.venv` にある実行ファイルや、`uv run` 経由で見つかる `.venv` の実行ファイルは登録できません。

### 登録とログ

対象の repository を `shipcast repo add <path>` で登録し、macOS で次を実行します。

```sh
shipcast schedule install
```

出力に表示された `launchctl bootstrap gui/<uid> ...` を実行すると読み込まれます。すでに読み込んでいる場合は、先に出力に表示された `launchctl bootout ...` を実行します。書き出しと読み込みをまとめて行うには `shipcast schedule install --load` を使います。

毎日 03:00（Mac の時計の時刻）に `shipcast run` が動き、設定の `timezone` での前日の日誌を作ります。Mac と設定の時間帯が異なると、どの日を前日とするかの境目がずれます。登録時の `PATH` が夜間の実行に使われるため、`PATH` を変えたら登録をやり直してください。

標準出力は `<state_dir>/logs/nightly.out.log`、標準エラーは `<state_dir>/logs/nightly.err.log` に記録します。既定のログの置き場は `~/.local/state/shipcast/logs/` です。repository ごとの実行結果は `<state_dir>/state.sqlite3` の `runs` に記録します。

### 解除

`shipcast schedule uninstall` で plist を削除し、表示された `launchctl bootout ...` で読み込んだ登録を外します。まとめて行うには `shipcast schedule uninstall --unload` を使います。

### 外付けvolumeを読むためのフルディスクアクセス

「システム設定」→「プライバシーとセキュリティ」→「フルディスクアクセス」で、`shipcast schedule install` が表示した Python の実行ファイルを追加します。追加画面で `Cmd+Shift+G` を押すと、表示されたパスを入力できます。Python を入れ替えたら追加し直してください。手で `shipcast run` を動かす場合は、実行するターミナルに許可を付けます。

## 日誌を読む（`shipcast serve`）

日誌は、デザインシステムで描くWebページとして、手元のPCから配信して読みます。

```sh
shipcast serve
```

- 既定では `http://127.0.0.1:8765/` で待ち受けます（同じPCからだけ読めます）。`--host`・`--port`、または設定ファイルの `[serve]` の `host`・`port` で変えられます。
- 表紙は `/` です。repositoryごとに、いちばん新しい日の日誌がカードで並びます。
- repositoryごとの一覧は `/<repo>/` です（例 `/demo-app/`）。日誌のある日が、新しい順に月ごとに並びます。
- 1日のページは `/<repo>/<YYYY-MM-DD>` です（例 `/demo-app/2026-11-26`）。`<repo>` は `shipcast repo add` で登録した id です。
- 止めるときは `Ctrl+C` を押します。
- 配信は日誌の置き場を読むだけで、何も書きません。置き場の外のファイル、`..` やsymlinkで外を指す道筋には404を返します。

### デザインシステムの置き場

ページの見た目は、SpecDockが配るデザインシステム（`ds.css`・`ds.js`）が描きます。shipcastはデザインシステムを同梱せず、次の順に探して `/_ds/` で配ります。

1. 設定ファイルの `[serve]` の `design_system_dir`
2. 空なら、登録したrepositoryの `spec-dock/design-system/`（登録の順に、`ds.css` と `ds.js` がある最初のもの）

見つからないときは、見た場所と設定の書き方を示して止まります。

```toml
[serve]
design_system_dir = "/path/to/repository/spec-dock/design-system"
```

### Tailscaleで、ほかの端末から読む

スマートフォンなど、自分のtailnetの端末から読むときは、本人が1回だけ次を実行します。shipcastはTailscaleの設定を変えません。

```sh
tailscale serve --bg 8765
```

表示された `https://<端末の名前>.<tailnetの名前>.ts.net/` を開くと、表紙が出ます。`tailscale serve` は、tailnetの端末からの要求を手元の `127.0.0.1:8765` に中継します。

- 公開をやめるときは `tailscale serve --https=443 off` を実行します（設定の一覧は `tailscale serve status`）。
- 443番をほかの用途で使っているときは、`tailscale serve --bg --https=8443 8765` のように別のポートで公開し、`https://<端末の名前>.<tailnetの名前>.ts.net:8443/` で開きます（止めるのは `tailscale serve --https=8443 off`）。ページは `/_ds/` を読むので、`--set-path` で道筋の下に置く方法は使えません。
- **Tailscale Funnel（`tailscale funnel`）は使いません。** Funnel はインターネットの誰にでも公開します。日誌は本人だけが読むものです。
- `--host 0.0.0.0` などで直接ネットワークに待ち受けると、同じLANの端末からも読めます。その場合は警告を出します。`tailscale serve` で `127.0.0.1` の配信を中継する方法を勧めます。
- Host が `127.0.0.1`、`localhost`、ほかのIPアドレス、または `.ts.net` の名前であれば受け付けます。それ以外は、ほかのWebページからの DNS rebinding を防ぐため400で拒みます。

## License

MIT
