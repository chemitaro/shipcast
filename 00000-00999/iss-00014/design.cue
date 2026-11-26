package spec

design: {
	"D-01": {title: "`shipcast.models`", text: "epic-00004 の D-01 の表。`get_route(cfg.models.writer)`。", satisfies: ["R-01", "F-02"]}
	"D-02": {title: "`shipcast.redact`", text: "`ghp_`・`github_pat_`・`sk-`・`AKIA`・`xox[bp]-` で始まる文字列、`-----BEGIN ... PRIVATE KEY-----` の塊、`PASSWORD=`・`TOKEN=`・`SECRET=` の行の値を `[伏せた]` に置き換える。", satisfies: ["R-02"]}
	"D-03": {title: "エージェントの中の検出", text: "環境変数 `CLAUDECODE`、`CODEX_` で始まるもの、Orcaの作業者の印（実装で確かめる）があれば、antigravity の経路は `RouteRefused` を投げる。", satisfies: ["F-01"]}
	"D-04": {title: "モデルの名前の確認", text: "`codex` のモデルの一覧の出し方を確かめ、分析に使える最も安いモデルを設定の見本に書く。", satisfies: ["R-03"]}
}
