package spec

schema: "specdock/v1"

assurance: {
	level:  "standard"
	reason: "話題（Story）の形とネタポイントは、執筆（iss-00016）とおまけ（iss-00019）が読む約束になる。誤ると日誌の中身が崩れるが、出来事は状態に残るので、PRを戻して分析し直せば回復できる"
}

purpose: "その日の出来事を、分析のモデルで話題（Story）にまとめ、保存する。実データはGitとSpecDockの収集（iss-00011、iss-00012）から来るが、試験は見本の出来事で行う。"

background: """
親の epic-00004 の R-02（分析のモデルが出来事を話題にまとめる、形が合わなければ1回だけ頼み直す）と F-01（モデルの失敗で材料を失わない）のうち、まとめる段を、このIssueが受け持つ（epic-00004 の `plan.cue` の `slices`、D-02）。書く段（iss-00016）は、このIssueの `analyze` が返す話題の一覧を受け取って日誌を書く。

`main` にすでにある次のものを、名前を変えずに使う（iss-00009・iss-00011〜iss-00014 で入った）。

- `shipcast.model`：`Event`（`id`・`repo_id`・`source`・`kind`・`at`・`title`・`body`・`refs`・`actor`）、`Story`（`id`・`repo_id`・`date`・`title`・`what`・`why`・`neta`・`notice`・`waiting`・`event_ids`）、`Neta`（`score` は0〜3の整数、`reason`、`channels`）、`story_id(repo_id, day, event_ids)`（出来事のIDの集まりから決まる16桁のID）、`ModelError`
- `shipcast.state.Store`：`add_events`（`INSERT OR IGNORE`）、`save_stories`（同じIDは上書き）、`stories_for(repo_id, day)`
- `shipcast.models`：`get_route(model_cfg)` が返す `GuardedRoute`。`complete(prompt, *, system="", want_json=False) -> str` は、`redact()` で prompt と system を伏せてから経路を呼ぶ。失敗は `RouteError` の子（`RouteFailed`・`RouteRefused`）。`fake` の経路は `responder(prompt, system, want_json)` を渡すと、その戻り値を返す
- iss-00014 の申し送り：JSONを渡すとき、prompt の全体を1つのJSONの物にし、指示は system に書く（伏せる処理がJSONの構造をたどれるように）

実行の記録（`runs` の表）は、まとめる段では書かない。`shipcast run`（iss-00021）が repositoryごとの成功と失敗を記録する（iss-00011 の design.cue の D-01 と同じ分け方）。このIssueの「失敗として記録」は、呼ぶ側がそのまま `runs` の誤りに書ける、型の決まった例外と日本語の理由を返すことを指す。
"""

includes: [
	"`src/shipcast/analyze.py`：`analyze`、`parse_stories`、`AnalyzeFailed`、`MAX_ATTEMPTS`、`PROMPT_PATH` の読み込み",
	"`src/shipcast/prompts/analyze.md`：分析のモデルへの指示（system の本文）",
	"`tests/test_analyze.py`：fake の経路の `responder` と一時ディレクトリの `Store` を使う試験",
]

excludes: [
	"日誌の本文を書くこと、`shipcast write` のコマンド（iss-00016）",
	"`runs` の表への記録（iss-00021）。ネタポイントの帳簿 `neta_ledger` への登録（iss-00019）",
	"公開の方針（公開の範囲・NGワード）による出来事の絞り込み（epic-00006 以降。このIssueは受け取った出来事を、伏せる処理だけを通して渡す）",
	"同じ日を分析し直して話題の分け方が変わったときに、前の話題を状態から消すこと（後の申し送り。design.cue の risks）",
	"本物の `codex`・`claude`・`agy` を呼ぶ試験。本物の経路での確かめは、本人の手動の実行だけ",
	"`shipcast.model`・`shipcast.state`・`shipcast.models`・`shipcast.redact`・`shipcast.config`・`shipcast.cli` の変更",
]

requirements: {
	"R-01": {
		title: "関係する出来事を1つの話題にまとめ、what・why・notice・waiting・neta（0〜3）を付ける"
		text:  "`analyze(events, route, *, store, repo_id, day)` が、その日の出来事を分析のモデルに1つのJSONとして渡し、応答の `stories` から `Story` の一覧を作って返す。`id`・`repo_id`・`date` はshipcastが機械で付ける（`id` は `story_id(repo_id, day, event_ids)`）。形は design.cue の D-02。"
		acceptance: [
			"fake の応答から、`event_ids` で出来事を指す話題ができ、各項目（`title`・`what`・`why`・`notice`・`waiting`・`neta`）が応答のとおりに埋まり、`id` が `story_id(repo_id, day, event_ids)`、`repo_id`・`date` が引数の値になる。順は応答の順",
			"neta.score は0〜3の整数で、範囲の外（`-1`・`4`）、整数でない値（`1.5`・`\"2\"`・`true`）は形の誤りとする",
			"`event_ids` が空、入力にない出来事のIDを含む、同じ話題の中で重なる、ほかの話題と同じ出来事を含む、のどれも形の誤りとする",
			"出来事が0件なら、モデルを呼ばずに空の一覧を返し、何も保存しない",
		]
	}
	"R-02": {
		title: "応答は決まったJSONの形で受け、形が合わなければ1回だけ頼み直す"
		text:  "形の検査は `parse_stories(text, *, event_ids)`（D-02）。1回目の応答が形に合わなければ、形の誤りの一覧を添えて、もう1回だけ頼む。"
		acceptance: [
			"頼み直しのプロンプトに、前の応答の形の誤り（項目の場所と、どう直すか）が添えられ、1回目と同じ出来事が入る",
			"呼び出しは最大2回。1回目が形に合えば1回で終わる",
			"どの呼び出しも `want_json=True` で、system が `prompts/analyze.md` の本文、prompt の全体が1つのJSONの物（`json.loads` で読め、`events` を持つ）",
		]
	}
	"R-03": {
		title: "話題を状態に保存してから、次の段へ渡す"
		text:  "形に合った話題の一覧を `Store.save_stories` で保存してから返す。出来事は、モデルを呼ぶ前に `Store.add_events` で保存する（epic-00004 の F-01 の「材料はモデルを呼ぶ前に保存」。収集が保存済みなら、重複は捨てられる）。"
		acceptance: [
			"`analyze` が返る前に、`Store.stories_for(repo_id, day)` で同じ話題が読める（その日の話題がまだ保存されていない状態から始めれば、返した一覧と等しい。同じ日の分析し直しは design.cue の risks）",
			"モデルを呼ぶ時点で、渡した出来事が状態に保存されている",
		]
	}
}

failures: {
	"F-01": {
		title:    "2回とも形が合わないときは、失敗として記録し、出来事は残す"
		text:     "`AnalyzeFailed`（D-03）を投げる。理由は日本語で、呼ぶ側がそのまま `runs` の誤りに書ける。話題は保存しない。出来事は状態に残る。経路そのものの失敗（`RouteError`）は頼み直さず、そのまま呼ぶ側へ投げる（話題は保存しない、出来事は残る）。"
		impact:   "その日の話題ができず、日誌が書けない"
		recovery: "出来事は状態に残っているので、同じ日を実行し直すと、同じ材料から分析し直す"
	}
}

constraints: [
	"標準のライブラリだけで書く（依存を足さない）",
	"試験とエージェントの作業では、外部のモデルを呼ばない。モデルの経路は `fake`（`responder` で応答を決める）だけを使い、`agy` を呼ばない（AGENTS.md）",
	"このrepositoryはpublic。見本の出来事と話題は架空の値にする",
	"モデルへは `GuardedRoute.complete` だけを通して渡す（伏せる処理を飛ばさない。epic-00004 の F-02）",
	"開発は通常の `coding-task`。マージは統括が行い、タスク担当と実装担当はマージしない（`content/decisions/20261126-journal-format-and-hackathon-plan.md` の 18〜21）",
]

decisions: [
	"関数の形は `analyze(events, route, *, store, repo_id, day) -> list[Story]`。Issueの題の `analyze(events, route)` に、保存（R-03）と `story_id` に要る `store`・`repo_id`・`day` を名前付きの引数で足す（タスク担当の判断、2026-11-26。本人の決定 6「細部の設計はエージェントが詰める」の範囲）",
	"`runs` の表には書かない。失敗は型の決まった例外 `AnalyzeFailed` で返し、記録は iss-00021 が行う。iss-00011 の収集と同じ分け方で、2か所で記録して重ならないようにするため（タスク担当の判断、同じ範囲）",
	"応答の前後の空白と、全体を囲む1組のコードの囲み（```` ```json ```` ～ ```` ``` ````）は取り除いてから読む。`JSON_INSTRUCTION` で禁じても、モデルがよく付けるため、頼み直しを減らす（タスク担当の判断、同じ範囲）",
	"応答の知らない鍵は捨てる（誤りにしない）。話題の形に要るのは決めた鍵だけで、余分な鍵で頼み直す利得がないため（タスク担当の判断、同じ範囲）",
	"出来事が1件以上あるのに `stories` が空なら、形の誤りとする。出来事のある日に話題のない日誌を作らないため。出来事がどの話題にも入らないことは許す（小さな出来事を落としてよい。`:::metrics` は iss-00016 が出来事から数える）（タスク担当の判断、同じ範囲）",
	"経路の失敗（`RouteError`）は頼み直さない。R-02 の頼み直しは形の誤りのためのもので、時間切れや拒否を繰り返すと、待ち時間と費用が倍になるため（タスク担当の判断、同じ範囲）",
	"作業のbranchは統括が作ったworktreeの `chemitaro/iss-00015` を使う",
]
