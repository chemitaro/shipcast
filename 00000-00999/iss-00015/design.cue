package spec

goals: [
	"`analyze` の戻り値と保存した話題が、iss-00016（書く）と iss-00019（ネタポイント）がそのまま読める `Story` になる",
	"応答の形は1つの関数 `parse_stories` で検査し、誤りは場所とどう直すかを日本語で返す（頼み直しと失敗の理由に使う）",
	"モデルへの送信は `GuardedRoute.complete` だけを通し、prompt の全体を1つのJSONの物にする",
	"試験は fake の経路の `responder` だけで行い、外部を呼ばない",
]

current: "`shipcast.model.Story` と `Store.save_stories` はあるが、出来事から話題を作る段はない。"
target:  "`shipcast.analyze.analyze(events, route, store=..., repo_id=..., day=...)` が、出来事を保存し、分析のモデルの応答から話題を作り、保存してから返す。"

design: {
	"D-01": {
		title: "`shipcast.analyze.analyze` の流れ"
		text: """
		```python
		MAX_ATTEMPTS = 2
		PROMPT_PATH = "prompts/analyze.md"   # shipcast の package の中。importlib.resources で読む

		class _Completer(Protocol):
		    def complete(self, prompt: str, *, system: str = "", want_json: bool = False) -> str: ...

		def analyze(
		    events: Sequence[Event],
		    route: _Completer,          # ふだんは get_route(cfg.models.analyst) の GuardedRoute
		    *,
		    store: Store,
		    repo_id: str,
		    day: date,
		) -> list[Story]: ...
		```

		1. 入力を確かめる：`events` の各要素が `Event` で、`repo_id` が引数の `repo_id` と同じ。違えば `ValueError`（モデルを呼ばず、何も保存しない）。`repo_id` の形と `day` の型は `story_id` と同じ検査（`ModelError`）。
		2. `events` が空なら、モデルを呼ばず、何も保存せず `[]` を返す。
		3. `store.add_events(events)` で出来事を保存する（R-03。同じIDは捨てられる）。
		4. system は `prompts/analyze.md` の本文（D-04）。prompt は D-02 の入力のJSON。`route.complete(prompt, system=system, want_json=True)` を呼ぶ。
		5. 応答を `parse_stories(response, event_ids=<入力の出来事のIDの集まり>)` に通す（D-02）。誤りの一覧が空でなければ、`MAX_ATTEMPTS` に達するまで、入力のJSONに `previous_errors`（誤りの一覧）を足した prompt で、もう1回だけ呼ぶ。
		6. 形に合えば、各話題に `id = story_id(repo_id, day, event_ids)`・`repo_id`・`date=day` を付けた `Story` を作り、`store.save_stories(stories)` で保存してから、その一覧を返す。
		7. 2回とも形に合わなければ、話題を保存せず `AnalyzeFailed`（D-03）を投げる。

		`route.complete` が投げる例外（`RouteError` とその子、`TypeError` など）は、受け止めず、頼み直さず、そのまま呼ぶ側へ投げる。そのとき話題は保存されず、手順3で保存した出来事は残る。`StateError` と SQLite の例外も受け止めない。

		`analyze` は `runs` の表と `neta_ledger` に書かない。

		手順6のうち `Story` の組み立て（`id`・`repo_id`・`date` を付ける）は S-02、`save_stories` の呼び出しは S-03 で書く（plan.cue）。
		"""
		satisfies: ["R-01", "R-02", "R-03", "F-01"]
	}
	"D-02": {
		title: "入力と応答のJSONの形、`parse_stories`"
		text: """
		**入力（prompt）**：`json.dumps(payload, ensure_ascii=False)`。全体が1つのJSONの物。

		```json
		{
		  "repo": "demo-app",
		  "date": "2026-11-26",
		  "events": [
		    {"id": "…", "source": "git", "kind": "merge", "at": "2026-11-26T10:00:00+09:00",
		     "title": "…", "body": "…", "refs": ["…"], "actor": "…"}
		  ]
		}
		```

		`events` は受け取った順で、各要素は `Event.to_dict()` から `schema` と `repo_id` を除いたもの。頼み直しの prompt は、同じ物に `"previous_errors": ["stories[0].neta.score: 0〜3の整数にしてください", …]` を足したもの（前の応答そのものは入れない）。

		**応答**：

		```json
		{
		  "stories": [
		    {
		      "title": "話題の短い名前",
		      "what": "何をしたか",
		      "why": "なぜしたか",
		      "notice": ["人が知っておくべきこと"],
		      "waiting": ["人を待っていること"],
		      "neta": {"score": 2, "reason": "点の理由", "channels": ["x"]},
		      "event_ids": ["…"]
		    }
		  ]
		}
		```

		```python
		def parse_stories(text: str, *, event_ids: Collection[str]) -> tuple[list[dict], list[str]]: ...
		```

		返すのは（形に合った話題の値の一覧、誤りの一覧）。誤りが1件でもあれば、話題の一覧は空。話題の値は `Story` の `title`・`what`・`why`・`notice`・`waiting`・`neta`（`Neta`）・`event_ids`（組）の鍵を持つ dict。

		検査（どれも誤りの一覧に足し、例外にしない。誤りの文は「場所: どう直すか」の形で、応答の値を写さない）：

		| # | 条件 | 誤りの場所の例 |
		|---|---|---|
		| V-01 | 前後の空白を除き、全体を囲む1組のコードの囲み（1行目が ```` ``` ```` か ```` ```json ````、最後の行が ```` ``` ````）があれば除いた文字列が、JSONとして読める | `応答` |
		| V-02 | 全体が物で、`stories` が配列 | `応答`・`stories` |
		| V-03 | `stories` が1件以上（入力の出来事は必ず1件以上なので） | `stories` |
		| V-04 | 各話題が物で、`title`・`what`・`why` が空白だけでない文字列 | `stories[0].what` |
		| V-05 | `notice`・`waiting` は、省けば空、あれば文字列の配列 | `stories[0].notice` |
		| V-06 | `neta` が物で、`score` が0〜3の整数（`bool` と小数の値は不可）。`reason` は省けば空の文字列、あれば文字列。`channels` は省けば空、あれば文字列の配列 | `stories[0].neta.score` |
		| V-07 | `event_ids` が1件以上の文字列の配列で、どれも入力の出来事のID、同じ話題の中で重ならない | `stories[0].event_ids` |
		| V-08 | 1つの出来事は1つの話題にだけ入る | `stories[1].event_ids` |
		| V-09 | 話題の中のすべての文字列（`title`・`what`・`why`・`notice`・`waiting`・`neta.reason`・`neta.channels` の各要素）が UTF-8 に符号化できる（`\\ud800` のような対のないサロゲートを含まない。含むと `Store.save_stories` で `UnicodeEncodeError` になり、型の決まった失敗にならないため） | `stories[0].title` |

		知らない鍵は捨てる。V-01・V-02 に当たれば、その後の検査はしない。誤りは最大20件まで集め、それを超えたら「ほかにも誤りがあります」の1件を足して止める。`json.loads` の `RecursionError` も V-01 の誤りにする。
		"""
		satisfies: ["R-01", "R-02"]
	}
	"D-03": {
		title: "`AnalyzeFailed`"
		text: """
		```python
		class AnalyzeFailed(Exception):
		    attempts: int            # 呼んだ回数（MAX_ATTEMPTS）
		    errors: tuple[str, ...]  # 最後の応答の形の誤り
		```

		文は「分析の応答が2回とも決まった形になりませんでした：<errors の先頭の5件を「、」でつないだもの>」。応答の本文を含まない。`RouteError` の子にしない（経路の失敗と区別するため）。
		"""
		satisfies: ["F-01"]
	}
	"D-04": {
		title: "プロンプト `src/shipcast/prompts/analyze.md`"
		text: """
		分析のモデルへの system の本文（日本語）。`importlib.resources.files("shipcast") / "prompts" / "analyze.md"` を UTF-8 で読む（package に入るように、`src/shipcast/prompts/` に置く。`__init__.py` は要らない）。中身は次の節を持つ。

		1. 役目：入力のJSON（`repo`・`date`・`events`）の、その日のソフトウェア開発の出来事を、関係するものごとに話題にまとめる。
		2. 応答の形：D-02 の応答のJSONの見本と、各項目の意味（`what` 何をしたか、`why` なぜしたか、`notice` 人が知っておくべきこと、`waiting` 人を待っていること、`event_ids` 話題の元の出来事のID）。1つの出来事は1つの話題にだけ入れる。
		3. ネタポイント（`neta.score`）の基準：変化の大きさ、読者への価値、見せやすさの3つで、0（発信には向かない）〜3（そのまま発信の芽になる）の整数。`reason` に理由、`channels` に向く場（`x`・`note`・`reddit` から）。
		4. 守ること：出来事にない事実を足さない。`[伏せた]` の中身を推し量らない。応答は日本語で、JSONだけを返す。
		5. 頼み直し：入力に `previous_errors` があれば、それを直した応答を返す。

		見出しの語（`ネタポイント`、`変化の大きさ`、`読者への価値`、`見せやすさ`、`previous_errors`、`event_ids`）は試験で確かめる。
		"""
		satisfies: ["R-01", "R-02"]
	}
}

seams: {
	"SE-01": {title: "fake の経路の `responder`", text: "`get_route(ModelConfig(\"fake\", \"fake-analyst\", None, None), responder=...)` で、応答を試験が決め、受け取った prompt・system・want_json と呼ばれた回数を記録する。外部を呼ばない"}
	"SE-02": {title: "一時ディレクトリの `Store`", text: "`Store(tmp_path)` で、保存の前後を `stories_for`・`events_for` で読む。モデルを呼んだ時点の保存は、`responder` の中で `events_for` を読んで確かめる"}
}

rejected: [
	"`analyze` が `runs` に失敗を記録する案：`shipcast run`（iss-00021）も記録するので二重になる。収集（iss-00011）と同じく、記録は呼ぶ側に寄せる",
	"応答の誤りでも、経路の失敗でも頼み直す案：経路の時間切れ（既定10分）を繰り返すと待ち時間が倍になる。頼み直しは形の誤りだけにする",
	"同じ日の前の話題を消してから保存する案：`Store` の変更と `neta_ledger` との整合が要り、このIssueの範囲を超える（design.cue の risks）",
	"prompt に指示と出来事を文で混ぜる案：伏せる処理がJSONの構造をたどれなくなる（iss-00014 の申し送り）",
]

risks: [
	"同じ日を分析し直して話題の分け方が変わると、前の話題が `stories` の表に残り、`stories_for` が古い話題も返す。分け方が同じでも、`save_stories` は同じIDの行を上書きして行の順（rowid）を保つので、`stories_for` の順は前の分析の順のままになる。このIssueの後の段（iss-00016）は `analyze` の戻り値を使い、`stories_for` を使わないこと。消し方（日ごとの置き換え）は、`shipcast run` の再実行（iss-00021）か、ネタポイントの帳簿（iss-00019）を作るときに決める（統括への申し送り）",
	"出来事の本文（Orcaの会話など）が長いと、分析のモデルへの入力が大きくなる。このIssueでは切り詰めない（分析の経路 codex・claude には入力の上限を設けていない。iss-00014）",
]
