package spec

schema: "specdock/v1"

assurance: {
	level:  "strict"
	reason: "外部のモデルへ情報を送る唯一の境界（伏せる処理 `redact()` を必ず通す）と、エージェントの中から `agy` を呼ばない守り（Antigravityの規約の遵守）を持つ。誤ると、秘密情報が外部へ出る、または規約に反する呼び出しが起き、送った情報は取り消せないので回復が難しい"
}

purpose: "分析と書き手のモデルを、設定の経路の名前で呼び分ける部品と、外部へ渡す前に秘密情報らしい文字列を伏せる処理を作る。外部のモデルへの送信は、すべてこの部品を通る。"

requirements: {
	"R-01": {
		title: "経路 codex・antigravity・claude・fake を、設定の `models.analyst` と `models.writer` から選んで呼べる"
		acceptance: [
			"`get_route(cfg.models.analyst)` と `get_route(cfg.models.writer)` が、設定の `route` の名前の経路を返す",
			"知らない経路の名前は、使える名前の一覧を示して止まる",
			"`fake` の経路は、外部のコマンドを呼ばずに、入力から決まった応答を返す",
		]
	}
	"R-02": {
		title: "どの経路も、呼ぶ前に必ず `redact()` を通す"
		text:  "伏せる処理は、経路の個々の実装ではなく、共通の入口（`Route.complete` を包む部品）で行い、経路の実装が飛ばせないようにする。"
		acceptance: [
			"`fake` を含む全経路で、経路の実装に届くプロンプトとsystemの文字列が、伏せた後のものになっている",
			"`ghp_`・`github_pat_`・`sk-`・`AKIA`・`xox[bp]-` で始まる文字列、`-----BEGIN ... PRIVATE KEY-----` の塊、`PASSWORD=`・`TOKEN=`・`SECRET=` の行の値が `[伏せた]` になる",
		]
	}
	"R-03": {
		title: "Codexのより安いモデル（Luna など）の名前を確かめ、設定の見本に書く"
		acceptance: ["設定の見本（`config.example.toml` か README）の `models.analyst.model` に、確かめた名前と確かめ方が書かれる"]
	}
}

failures: {
	"F-01": {
		title:    "エージェントの中では antigravity の経路を呼ばずに止まる（epic-00004 の F-03）"
		text:     "印：環境変数 `CLAUDECODE`、`AI_AGENT`、`ORCA_AGENT_SESSION_ID`、`CODEX_` で始まるもの。1つでもあれば、`agy` を起動する前に `RouteRefused` を投げる。"
		impact:   "エージェントやOrcaの作業者の中から `agy` が呼ばれると、個人のプランを第三者のツールから使う形になり、Antigravityの規約に反する。呼び出しは取り消せない"
		recovery: "印の判定は `agy` の起動より前に行い、判定できないときも止める（閉じる側に倒す）。試験とハッカソンの作業は `fake` の経路を使う"
	}
	"F-02": {
		title:    "外部のコマンドが失敗・時間切れのときは、理由を持った例外にする"
		impact:   "例外にしないと、空や途中の応答を正しい結果として次の段へ渡し、日誌が壊れる"
		recovery: "`RouteFailed`（経路の名前、終了コード、標準エラーの末尾、時間切れか）を投げ、呼んだ側が失敗として記録し、次の実行で同じ材料から書き直す（epic-00004 の F-01）"
	}
	"F-03": {
		title:    "伏せる処理が失敗したときは、外部へ送らずに止まる"
		impact:   "伏せる処理の例外を握りつぶして送ると、伏せていない文字列が外部へ出る"
		recovery: "`redact()` の例外はそのまま上げ、経路を呼ばない。失敗として記録し、本人が原因の入力を直してから実行し直す"
	}
}
