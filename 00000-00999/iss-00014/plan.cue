package spec

steps: {
	"S-01": {title: "codex・claude の `--help` と、agy の文書を確かめる（agy は起動しない）", realizes: ["R-01", "R-03"], session: "impl"}
	"S-02": {title: "伏せる処理", realizes: ["R-02", "F-03"], after: ["S-01"], session: "impl"}
	"S-03": {title: "経路の部品、共通の入口、fake", realizes: ["R-01", "R-02", "F-02"], after: ["S-02"], session: "impl"}
	"S-04": {title: "エージェントの中の検出", realizes: ["F-01"], after: ["S-03"], session: "impl"}
	"S-05": {title: "設定の見本にモデルの名前を書く", realizes: ["R-03"], after: ["S-01"], session: "impl"}
}

tests: {
	"T-01": {title: "fake の経路が決まった応答を返し、知らない経路の名前で止まる", verifies: ["R-01"]}
	"T-02": {title: "トークン・鍵・パスワードの行が、規則の表のとおりに伏せられる", verifies: ["R-02"]}
	"T-03": {title: "全経路で、経路の実装に届く文字列が伏せた後のものである", verifies: ["R-02"]}
	"T-04": {title: "印の環境変数のどれか1つがあると、antigravity が子のプロセスを作らずに止まる", verifies: ["F-01"]}
	"T-05": {title: "外部のコマンドの失敗と時間切れが RouteFailed になる（偽のコマンドで）", verifies: ["F-02"]}
	"T-06": {title: "redact が例外を上げたとき、経路の実装が呼ばれない", verifies: ["F-03"]}
	"T-07": {title: "設定の見本に分析のモデルの名前がある", verifies: ["R-03"]}
}

execution: sessions: {
	spec: {task: "仕様化（起動した側が選んだ値の記録）", model: "Claude Opus 5.5", effort: "この会話の設定"}
	impl: {task: "実装", model: "GPT-6.2 Sol", effort: "medium"}
}
