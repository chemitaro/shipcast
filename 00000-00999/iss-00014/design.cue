package spec

goals: [
	"外部のモデルへの送信の入口を1か所にし、伏せる処理と `agy` の守りを、経路の実装から飛ばせないようにする",
]

design: {
	"D-01": {
		title: "`shipcast.models`：経路の部品と共通の入口"
		text: """
		- `Route` の約束：`complete(prompt: str, *, system: str, want_json: bool) -> str`。
		- `get_route(model_cfg) -> GuardedRoute`。`GuardedRoute` が共通の入口で、順に (1) 経路が `antigravity` なら D-03 の判定、(2) `redact()` で prompt と system を伏せる、(3) 経路の実装を時間の上限（既定10分）付きで呼ぶ。経路の実装は `GuardedRoute` の外からは作らない。
		- 経路の表と呼び方は epic-00004 の D-01（`codex exec … -`、`agy -p … --output-format json`、`claude -p --tools ""`、`fake`）。正確な引数は実装の最初に `--help` で確かめる（本物の `agy` は起動しない。`agy --help` も呼ばず、文書と本人の手動の確認に頼る）。
		- 外部のコマンドは `subprocess.run(..., timeout=…)` で呼び、失敗と時間切れは `RouteFailed` にする。子のプロセスを作る関数（runner）は差し替えられるようにし、試験では常に偽のrunnerを渡す。試験とエージェントの作業で、本物の `agy`・`codex`・`claude` を起動しない。
		"""
		satisfies: ["R-01", "F-02"]
	}
	"D-02": {
		title: "`shipcast.redact`"
		text: """
		`redact(text: str) -> str`。正規表現で、R-02 の型の文字列を `[伏せた]` に置き換える。置き換えの規則は表にして、試験で1つずつ確かめる。例外は握りつぶさず上げる（F-03）。
		"""
		satisfies: ["R-02", "F-03"]
	}
	"D-03": {
		title: "エージェントの中の検出"
		text:  "`in_agent_context(env) -> bool`。F-01 の印のどれかがあれば真。`GuardedRoute` は、経路が `antigravity` で真なら、子のプロセスを作る前に `RouteRefused` を投げる。環境は引数で渡せるようにし、試験では作った環境を渡す。"
		satisfies: ["F-01"]
	}
	"D-04": {
		title: "モデルの名前の確認"
		text:  "`codex` のモデルの一覧の出し方（`codex --help` など）を確かめ、分析に使える最も安いモデルを設定の見本に書く。"
		satisfies: ["R-03"]
	}
}

risks: [
	"エージェントの印の環境変数は、各道具の版で変わりうる。2026-12-19 のAntigravityの規約の読み直しのときに、印も見直す",
	"伏せる規則に当てはまらない形の秘密は伏せられない。規則は増やせるように表にする",
]
