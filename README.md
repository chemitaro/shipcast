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

## 日誌を読む（`shipcast serve`）

日誌は、デザインシステムで描くWebページとして、手元のPCから配信して読みます。

```sh
shipcast serve
```

- 既定では `http://127.0.0.1:8765/` で待ち受けます（同じPCからだけ読めます）。`--host`・`--port`、または設定ファイルの `[serve]` の `host`・`port` で変えられます。
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

表示された `https://<端末の名前>.<tailnetの名前>.ts.net/` に、日誌の道筋（`/<repo>/<YYYY-MM-DD>`）を付けて開きます。`tailscale serve` は、tailnetの端末からの要求を手元の `127.0.0.1:8765` に中継します。

- 公開をやめるときは `tailscale serve --https=443 off` を実行します（設定の一覧は `tailscale serve status`）。
- 443番をほかの用途で使っているときは、`tailscale serve --bg --https=8443 8765` のように別のポートで公開し、`https://<端末の名前>.<tailnetの名前>.ts.net:8443/` で開きます（止めるのは `tailscale serve --https=8443 off`）。ページは `/_ds/` を読むので、`--set-path` で道筋の下に置く方法は使えません。
- **Tailscale Funnel（`tailscale funnel`）は使いません。** Funnel はインターネットの誰にでも公開します。日誌は本人だけが読むものです。
- `--host 0.0.0.0` などで直接ネットワークに待ち受けると、同じLANの端末からも読めます。その場合は警告を出します。`tailscale serve` で `127.0.0.1` の配信を中継する方法を勧めます。
- Host が `127.0.0.1`、`localhost`、ほかのIPアドレス、または `.ts.net` の名前であれば受け付けます。それ以外は、ほかのWebページからの DNS rebinding を防ぐため400で拒みます。

## License

MIT
