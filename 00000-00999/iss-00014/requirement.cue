package spec

schema: "specdock/v1"

assurance: {
	level:  "strict"
	reason: "外部のモデルへ情報を送る唯一の境界（伏せる処理 `redact()` を必ず通す）と、エージェントの中から `agy` を呼ばない守り（Antigravityの規約の遵守）を持つ。誤ると、秘密情報が外部へ出る、または規約に反する呼び出しが起き、送った情報は取り消せないので回復が難しい"
}

purpose: "分析と書き手のモデルを、設定の経路の名前で呼び分ける部品と、外部へ渡す前に秘密情報らしい文字列を伏せる処理を作る。外部のモデルへの送信は、すべてこの部品を通る。"

background: """
- 親の epic-00004 の R-01・F-02・F-03 を、この Issue が受け持つ（epic-00004 の `plan.cue` の `slices`）。後の iss-00015（まとめる）と iss-00016（書く）は、この Issue の `get_route` と `GuardedRoute.complete` だけを通してモデルを呼ぶ。
- 設定は `main` の `shipcast.config` が読む。`ModelConfig(route, model, effort, thinking)` で、`models.analyst.route` は `codex`・`claude`・`fake`、`models.writer.route` は `antigravity`・`claude`・`codex`・`fake` だけが通る（読む段で検証済み）。
- 本人の決定（`content/decisions/20261126-journal-format-and-hackathon-plan.md`）：書き手は Antigravity（`agy -p`）の Gemini 4 Neon（決定9）。分析は安いモデル（GPT-6.2 Sol、足りるならさらに安い Luna など。決定10）。Orca の会話のログは、どちらのモデルに渡す前にも秘密情報らしい文字列を機械で伏せる（決定14）。エージェント（Claude Code・Codex・Orca の作業者）は `agy` を呼ばない（同じ文書の末尾）。
"""

includes: [
	"`src/shipcast/redact.py`（伏せる処理）と `tests/test_redact.py`",
	"`src/shipcast/models.py`（経路の部品、共通の入口、エージェントの中の検出）と `tests/test_models.py`",
	"設定の見本 `shipcast.config.DEFAULT_CONFIG_TEXT` の、分析のモデルの行への注記（1行）と、その試験",
]

excludes: [
	"話題へのまとめ・日誌の本文・プロンプトの文面（iss-00015・iss-00016）",
	"`want_json` の応答のJSONの形の検証と頼み直し（iss-00015。この Issue は文字列を返すだけ）",
	"モデルの応答を伏せること（応答は手元の日誌になるだけで、外部へ送らない）",
	"本物の `codex`・`claude`・`agy` を呼ぶ試験。本物の経路での確かめは、本人の手動の実行だけ",
	"既定の分析のモデルを Luna に替えること（足りるかの判断は、本物の経路で比べた後の本人の判断）",
]

constraints: [
	"試験とエージェントの作業では、外部のモデルと本物の `agy` を呼ばない。`agy --help` も起動しない。子のプロセスは差し替えた偽の runner だけで作る（AGENTS.md、本人の決定）",
	"新しい依存のパッケージを足さない（標準ライブラリだけ）",
	"このrepositoryは public。試験の秘密らしい文字列は、明らかに架空のダミー値（`EXAMPLE`・`DUMMY`・`0000` などを含む）にする",
	"並行する iss-00011・iss-00017 とぶつからないよう、変えるファイルは `src/shipcast/models.py`・`src/shipcast/redact.py`・`tests/test_models.py`・`tests/test_redact.py` と、`src/shipcast/config.py` の `DEFAULT_CONFIG_TEXT` の分析のモデルの1行（と、その試験を足す `tests/test_config.py`）に限る",
]

requirements: {
	"R-01": {
		title: "経路 codex・antigravity・claude・fake を、設定の `models.analyst` と `models.writer` から選んで呼べる"
		text:  "`get_route(model_cfg)` が `GuardedRoute` を返し、`GuardedRoute.complete(prompt, *, system=\"\", want_json=False) -> str` でモデルの応答の本文を返す。経路ごとの呼び方は design.cue の D-03 の表のとおり。"
		acceptance: [
			"`get_route(cfg.models.analyst)` と `get_route(cfg.models.writer)` が、設定の `route` の名前の経路を持つ `GuardedRoute` を返し、`name` と `model` が設定の値になる",
			"知らない経路の名前（例 `gemini`）は、使える4つの名前を示す `UnknownRoute` で止まり、子のプロセスを作らない",
			"`fake` の経路は、子のプロセスを作らずに、受け取った system・prompt・want_json と model から決まるJSONの文字列を返す（同じ入力なら同じ文字列）。`responder` を渡すと、伏せた後の prompt・system・want_json でそれを呼んだ戻り値を返す",
			"`codex`・`claude`・`antigravity` の経路は、D-03 の表の引数と標準入力で runner を1回呼び、表の取り出し方で応答の本文を返す",
		]
	}
	"R-02": {
		title: "どの経路も、呼ぶ前に必ず `redact()` を通す"
		text:  "伏せる処理は、経路の個々の実装ではなく、共通の入口 `GuardedRoute.complete` で行い、経路の実装が飛ばせないようにする。規則は design.cue の D-01 の表（RD-01〜RD-11）。置き換えた後の文字列は `[伏せた]`。"
		acceptance: [
			"`fake`（`responder` を含む）・`codex`・`claude`・`antigravity` の全経路で、経路の実装に届くプロンプトとsystemの文字列（runner の引数・標準入力・一時ファイル、`responder` の引数）が、伏せた後のものになっている",
			"`ghp_`・`gho_` などの GitHub のトークン、`github_pat_`、`sk-`、`AKIA`・`ASIA`、`xox[bp]-` などの Slack のトークン、`AIza` の Google の鍵、JWT、`Bearer` の後の値、URLの中の利用者:パスワード、`-----BEGIN ... PRIVATE KEY-----` の塊（閉じのないものは末尾まで）、`PASSWORD`・`TOKEN`・`SECRET` などを名前に含む鍵の `=` か `:` の後の値が、D-01 の表のとおり `[伏せた]` になる",
			"秘密を含まない文（日本語の文、RD-04 の鍵の名前を含まないコードやログ）は変わらない。伏せた文字列をもう一度 `redact()` に通しても変わらない",
		]
	}
	"R-03": {
		title: "Codexのより安いモデル（Luna）の名前を確かめ、設定の見本に書く"
		text:  "確かめた結果（2026-11-26、codex-cli 0.172.0 の `codex debug models`）：一覧（visibility `list`）で最も安い今の世代は `gpt-6-luna`（「Fast and affordable model for easier tasks.」）。`gpt-6.2` の Luna はない。既定は `gpt-6.2-sol` のまま変えない（決定10の「足りるなら」は本人が比べて決める）。"
		acceptance: ["`shipcast.config.DEFAULT_CONFIG_TEXT` の `[models.analyst]` の `model` の行に、より安い名前 `gpt-6-luna` と、確かめ方（`codex debug models`）が注記として書かれ、`parse_config` の結果は変わらない"]
	}
}

failures: {
	"F-01": {
		title:    "エージェントの中では antigravity の経路を呼ばずに止まる（epic-00004 の F-03）"
		text:     "印：環境変数 `CLAUDECODE`、`AI_AGENT`、`ORCA_AGENT_SESSION_ID` と、`CODEX_` で始まる名前。値によらず、名前が1つでもあれば、`agy` の子のプロセスを作る前に `RouteRefused` を投げる。環境を読めない（Mapping でない、読む途中で例外）ときも止める。"
		impact:   "エージェントやOrcaの作業者の中から `agy` が呼ばれると、個人のプランを第三者のツールから使う形になり、Antigravityの規約に反する。呼び出しは取り消せない"
		recovery: "印の判定は `agy` の起動より前に、呼ぶたびに行い、判定できないときも止める（閉じる側に倒す）。`RouteRefused` は見つけた印の名前（値は含めない）を示し、本人は普通の端末か launchd から実行し直す。試験とエージェントの作業は `fake` の経路を使う"
	}
	"F-02": {
		title:    "外部のコマンドが失敗・時間切れ・空の応答のときは、理由を持った例外にする"
		text:     "終了コードが0でない、時間の上限（既定600秒）を超えた、コマンドが見つからない・起動できない、応答の本文が空か空白だけ、応答の形が読めない（antigravity のJSONが読めない、`status` が `SUCCESS` でない）、のどれも `RouteFailed` にする。"
		impact:   "例外にしないと、空や途中の応答を正しい結果として次の段へ渡し、日誌が壊れる"
		recovery: "`RouteFailed`（経路の名前、終了コード、標準エラーの末尾を伏せたもの、時間切れか、理由）を投げ、呼んだ側が失敗として記録し、次の実行で同じ材料から書き直す（epic-00004 の F-01）"
	}
	"F-03": {
		title:    "伏せる処理が失敗したときは、外部へ送らずに止まる"
		text:     "`redact()` が例外を上げたとき（文字列でない入力の `TypeError` を含む）、`GuardedRoute.complete` はそれを握りつぶさずにそのまま上げ、経路の実装と runner を呼ばない。"
		impact:   "伏せる処理の例外を握りつぶして送ると、伏せていない文字列が外部へ出る"
		recovery: "`redact()` の例外はそのまま上げ、経路を呼ばない。失敗として記録し、本人が原因の入力を直してから実行し直す"
	}
	"F-04": {
		title:    "`agy` の命令の行が長すぎるときは、起動せずに止まる"
		text:     "antigravity の経路はプロンプトを命令の行の引数で渡す（D-03）。伏せた後の system と prompt を合わせた長さが UTF-8 で 200,000 バイトを超えたら、子のプロセスを作らずに `RouteFailed` にする。"
		impact:   "OSの引数の上限を超えると、起動の失敗が分かりにくい誤りになる。途中で切って渡すと、話題の一部が消えた日誌になる"
		recovery: "`RouteFailed`（理由に長さと上限）で止め、呼んだ側（iss-00016）が渡す骨組みを小さくする。本人は失敗の記録を見て実行し直す"
	}
}

decisions: [
	"モジュールは `src/shipcast/models.py` の1つにする（パッケージにしない）。既存の `shipcast.model`（データの型）とは別の名前のまま（タスク担当の判断、2026-11-26。epic-00004 の D-01 の名前 `shipcast.models` に従う）",
	"エージェントの印は epic-00004 の F-03 の4つ（`CODEX_` は前方一致）に限る。`CODEX_HOME` などを利用者が普段の環境に置くと、antigravity の経路は止まる。閉じる側に倒すため、これを受け入れる（タスク担当の判断、2026-11-26）",
	"`agy` の引数は、Antigravity の公式の文書（https://antigravity.google/docs/cli/headless/ と https://antigravity.google/docs/cli/reference/ 、2026-11-26 に読んだ）に従う。`agy` は起動して確かめない（AGENTS.md、本人の決定）",
]

questions: [
	"Antigravity の CLI が、自分の道具で実行するコマンドに付ける環境変数（エージェントの中の印）は、文書にない。見つかったら印に足す（2026-12-19 の規約の読み直しのとき。design.cue の risks）",
]
