package spec

goals: [
	"日誌のファイルの形（前付け・囲みの順・数）をshipcastが機械で決め、書き手のモデルには文章だけを書かせる",
	"書き手の応答の形は1つの関数 `parse_draft` で検査し、誤りは場所とどう直すかを日本語で返す（頼み直しと失敗の理由に使う）",
	"どこで失敗しても前の日誌を壊さない（一時ファイルと `os.replace`）",
	"iss-00019 が、書く段の中を書き換えずに日誌の末尾へ囲みを足せる",
	"試験は fake の経路の `responder` と一時ディレクトリだけで行い、外部を呼ばない",
]

current: "出来事を集める段（`shipcast collect`）と、話題にまとめる段（`shipcast.analyze`）はある。`shipcast write` は未実装の印を出して終了コード2で終わる。"
target:  "`shipcast write --repo <id> --date <日付>` が、集めて、まとめて、書き手に文章を書かせ、決まった形の日誌のMarkdownを `journal_path` に置き換えで書き、`entries` に記録する。"

design: {
	"D-01": {
		title: "書き手への入力と応答の形、`parse_draft`"
		text: """
		**入力（prompt）**：`json.dumps(payload, ensure_ascii=False)`。全体が1つのJSONの物。

		```json
		{
		  "repo": "demo-app",
		  "date": "2026-11-26",
		  "stories": [
		    {"title": "…", "what": "…", "why": "…", "notice": ["…"], "waiting": ["…"]}
		  ]
		}
		```

		`stories` は `analyze` が返した順。各要素は `Story` の `title`・`what`・`why`・`notice`・`waiting` だけ（`id`・`neta`・`event_ids` と出来事は渡さない。F-02）。頼み直しの prompt は、同じ物に `"previous_errors": ["lead: 1行にしてください", …]` を足したもの（前の応答そのものは入れない）。

		**応答**：

		```json
		{
		  "lead": "今日の要約の1〜2文",
		  "summary": ["要約の1行", "…"],
		  "story": "### 話題の小見出し\\n\\nです・ます調の本文…"
		}
		```

		```python
		@dataclass(frozen=True)
		class Draft:
		    lead: str                  # 前後の空白を除いたもの
		    summary: tuple[str, ...]   # 各行の前後の空白を除いたもの
		    story: str                 # 前後の空白・改行を除いたもの

		def parse_draft(text: str) -> tuple[Draft | None, list[str]]: ...
		```

		返すのは（形に合った `Draft`、誤りの一覧）。誤りが1件でもあれば `Draft` は `None`。誤りの文は「場所: どう直すか」の形で、応答の値を写さない。知らない鍵は捨てる。

		「生のHTML」は、`<` の直後に英字・`/`・`!`・`?` が続く並び（正規表現 `<[A-Za-z/!?]`）とする。「ブロックの印を除いた行頭」は、行頭から、空白・引用の `>`・箇条書きの印（`-`・`*`・`+` と後ろの空白、`数字.`・`数字)` と後ろの空白）の並びを繰り返し除いた残り（marked はリストと引用の中身もブロックとして読み直すため。正規表現 `^(?:\\s|>|[-*+](?:\\s|$)|\\d+[.)](?:\\s|$))*`）。

		| # | 条件 | 誤りの場所 |
		|---|---|---|
		| W-01 | 前後の空白を除き、全体を囲む1組のコードの囲み（1行目が ```` ``` ```` か ```` ```json ````、最後の行が ```` ``` ````）があれば除いた文字列が、JSONとして読める（`NaN`・`Infinity` は不可、`RecursionError` も誤り） | `応答` |
		| W-02 | 全体が物 | `応答` |
		| W-03 | `lead` が文字列で、前後の空白を除いて空でなく、改行（`\\n`・`\\r`）を含まず、200文字以内で、`<`・`>` を含まない | `lead` |
		| W-04 | `summary` が1〜5件の文字列の配列で、各要素が前後の空白を除いて空でなく、改行を含まず、生のHTMLを含まず、`:::` で始まらない | `summary`・`summary[0]` |
		| W-05 | `story` が文字列で、前後の空白を除いて空でなく、全体に生のHTMLと `:::` を含まず、どの行も「ブロックの印を除いた行頭」（下の注）が `#` 1〜2個の見出し（`#` か `##` の後が空白か行の終わり）・コードの囲み（```` ``` ```` か `~~~`）で始まらず、`=` だけ・`-` だけ（前後の空白は除く）の行でない（setext の見出しを防ぐ。`###` 以下の見出しはよい） | `story` |
		| W-06 | 上のすべての文字列が UTF-8 に符号化できる（対のないサロゲートを含まない） | `lead`・`summary[0]`・`story` |

		W-01・W-02 に当たれば、その後の検査はしない。W-03〜W-06 は、それぞれの項目に当たる誤りをすべて集める。
		"""
		satisfies: ["R-02", "F-02"]
	}
	"D-02": {
		title: "`compose`（書き手への依頼と頼み直し）と `WriteFailed`"
		text: """
		```python
		MAX_ATTEMPTS = 2
		PROMPT_PATH = "prompts/write.md"   # shipcast の package の中。importlib.resources で読む

		class _Completer(Protocol):
		    name: str
		    model: str
		    def complete(self, prompt: str, *, system: str = "", want_json: bool = False) -> str: ...

		def compose(stories: Sequence[Story], route: _Completer, *, repo_id: str, day: date) -> Draft: ...

		class WriteFailed(Exception):
		    attempts: int            # 呼んだ回数（MAX_ATTEMPTS）
		    errors: tuple[str, ...]  # 最後の応答の形の誤り
		```

		1. `stories` が空なら `ValueError`（経路を呼ばない。出来事のない日は `write_day` が `compose` を呼ばない）。
		2. system は `prompts/write.md` の本文（D-08）。prompt は D-01 の入力のJSON。`route.complete(prompt, system=system, want_json=True)` を呼ぶ。
		3. 応答を `parse_draft` に通す。誤りがあれば、`MAX_ATTEMPTS` に達するまで、`previous_errors` を足した prompt で、もう1回だけ呼ぶ。
		4. 形に合えば `Draft` を返す。2回とも合わなければ `WriteFailed` を投げる。

		`WriteFailed` の文は「書き手の応答が2回とも決まった形になりませんでした：<errors の先頭の5件を「、」でつないだもの>」。応答の本文を含まない。`RouteError` の子にしない。`route.complete` の例外（`RouteError` など）は受け止めず、頼み直さず、そのまま投げる。
		"""
		satisfies: ["R-02", "F-01", "F-02"]
	}
	"D-03": {
		title: "`count_metrics`（`:::metrics` の数）"
		text: """
		```python
		@dataclass(frozen=True)
		class Metric:
		    value: int
		    label: str

		def count_metrics(events: Iterable[Event]) -> tuple[Metric, ...]: ...
		```

		いつも次の4つを、この順で返す（同じ `Event.id` は1回だけ数える）。

		| 順 | `label` | 数えるもの |
		|---|---|---|
		| 1 | `merge` | `source == "git"` かつ `kind == "merge"` |
		| 2 | `commit` | `source == "git"` かつ `kind == "commit"`（mergeは含めない） |
		| 3 | `閉じたScope` | `source == "specdock"` かつ `kind == "scope_closed"` |
		| 4 | `新しい本人待ちのtodo` | `source == "specdock"` かつ `kind == "todo_open"` の出来事のうち、`refs` の先頭（todoのID）が、同じ入力の `kind == "todo_done"` の出来事の `refs` の先頭にないもの。`refs` が空の `todo_open` は数える |

		Orcaの会話（`conversation`）と `scope_opened` は数えない。
		"""
		satisfies: ["R-04"]
	}
	"D-04": {
		title: "`build_entry`（日誌のMarkdownの組み立て）"
		text: """
		```python
		def build_entry(
		    repo_id: str,
		    day: date,
		    stories: Sequence[Story],
		    events: Sequence[Event],
		    draft: Draft | None,
		    *,
		    analyst: str | None,       # "<経路>/<モデル>"。出来事のない日は None
		    writer: str | None,
		    generated_at: datetime,    # 時間帯つき
		    extensions: Sequence[JournalExtension] | None = None,   # None なら呼んだ時点の EXTENSIONS
		) -> str: ...
		```

		**前付け**は `write_frontmatter(JournalMeta(...))` だけで作る（iss-00017 の申し送り）。`title` は `f"{repo_id} の開発日誌 {day.isoformat()}"`、`category` は `開発日誌`、`generated_at` は `generated_at.isoformat(timespec="seconds")`、`schema` は `1`。`JournalMeta` の検査に通らない値は `JournalFormatError` のまま投げる。

		**出来事のある日**（`events` が1件以上）：`draft` が `None` なら `ValueError`。`lead` は `draft.lead`。前付けの後は次のとおり（各塊の間は空行1つ、ファイルの終わりは改行1つ）。

		```markdown
		:::summary 今日の要約
		- <draft.summary の各行>
		:::

		:::warning あなたが知っておくべきこと
		- <stories の notice を話題の順に、各話題の中の順に並べたもの>
		:::

		## 今日の物語

		<draft.story>

		:::checklist あなたを待っていること
		- <stories の waiting を同じ順に並べたもの>
		:::

		:::metrics
		- <value> | <label>
		:::

		<拡張点が返した囲み>
		```

		- `:::warning` は notice が1件もなければ、`:::checklist` は waiting が1件もなければ、塊ごと書かない。
		- `- ` の後ろに入れる文字列（要約の行、notice、waiting）は `_inline` を通す：(1) 空白の並び（改行を含む）を1つの空白にし、前後の空白を除く。(2) `&` → `&amp;`、`<` → `&lt;`、`>` → `&gt;` に置き換える（F-02。marked は生のHTMLを通すため）。(3) 先頭の文字が `#`・`:`・`-`・`*`・`+`・`=`・`` ` ``・`~`・`|` のどれかなら、その前に `\\` を1つ足す。先頭が `数字.` か `数字)` なら、`.`・`)` の前に `\\` を足す（箇条書きの中でブロックとして読み直されても、囲み・見出し・入れ子の箇条書き・コードにならないように）。`_inline` の後に空になった項目は書かない。
		- `:::warning`・`:::checklist` を省くかどうかは、`_inline` の後に残った項目の数で決める（全部が空になれば塊ごと書かない）。
		- `draft.story` はそのまま入れる（D-01 の W-05 で検査済み）。
		- 拡張点：`extensions` の順に `render(repo_id, day, stories, events)` を呼ぶ（D-05）。

		**出来事のない日**（`events` が0件）：`lead` は「大きな動きはありませんでした。」、`analyst`・`writer` は書かない。前付けの後は空行1つと「大きな動きはありませんでした。」の1行だけ。`draft`・`stories`・`extensions` は使わない（拡張点を呼ばない）。
		"""
		satisfies: ["R-02", "R-03", "R-04", "F-02"]
	}
	"D-05": {
		title: "拡張点 `JournalExtension` と `EXTENSIONS`"
		text: """
		```python
		class JournalExtension(Protocol):
		    def render(
		        self, repo_id: str, day: date, stories: Sequence[Story], events: Sequence[Event]
		    ) -> str | None: ...

		EXTENSIONS: tuple[JournalExtension, ...] = ()   # iss-00019 が「発信の芽」をここに足す
		```

		`extensions` が `None` のときは、呼んだ時点の `shipcast.write.EXTENSIONS` を読む（関数の既定値に固めない。iss-00019 の登録と試験の差し替えが効くように）。`build_entry` は、出来事のある日に、`:::metrics` の塊の後で、各部品の `render` を順に呼ぶ。戻り値が `None` か空白だけの文字列なら足さない。そうでなければ前後の空白・改行を除いた文字列を、空行1つを挟んで足す。中身の検査はしない（部品の責任。部品は生のHTMLを入れないこと）。`render` の例外は受け止めず、そのまま投げる（日誌は書かれない）。
		"""
		satisfies: ["R-05"]
	}
	"D-06": {
		title: "`write_atomic`（ファイルの置き換え）"
		text: """
		```python
		def write_atomic(path: Path, text: str) -> None: ...
		```

		1. `path.parent.mkdir(parents=True, exist_ok=True)`。
		2. `tempfile.mkstemp(dir=path.parent, prefix=f".{path.name}.", suffix=".tmp")` で同じフォルダーに一時ファイルを作り、`text` を UTF-8 で書き（改行は `\\n` のまま）、`flush`・`os.fsync` し、`os.chmod(tmp, 0o644)` する。
		3. `os.replace(tmp, path)`。
		4. 2・3 のどこかで例外が起きたら、一時ファイルを消して（消せなくても元の例外を優先）、元の例外を投げる。前の `path` は変わらない。
		"""
		satisfies: ["F-01"]
	}
	"D-07": {
		title: "`write_day`（1日の流れ）と CLI `shipcast write`"
		text: """
		```python
		@dataclass(frozen=True)
		class WriteResult:
		    path: Path
		    events: int                  # その日の出来事の数
		    stories: tuple[Story, ...]   # 日誌に書いた話題（analyze の戻り値）

		def write_day(
		    store: Store,
		    repo_id: str,
		    day: date,
		    *,
		    tz: tzinfo,
		    journal_dir: Path,
		    analyst: _Completer,
		    writer: _Completer,
		    now: datetime,
		    extensions: Sequence[JournalExtension] | None = None,   # None なら呼んだ時点の EXTENSIONS
		) -> WriteResult: ...
		```

		1. `events = store.events_for(repo_id, day, tz=tz)`。
		2. 0件なら、経路を呼ばずに `build_entry(..., draft=None, analyst=None, writer=None)`。
		3. 1件以上なら `stories = analyze(events, analyst, store=store, repo_id=repo_id, day=day)`（戻り値を使う。`stories_for` を使わない）、`draft = compose(stories, writer, repo_id=repo_id, day=day)`、`build_entry(..., analyst=f"{analyst.name}/{analyst.model}", writer=f"{writer.name}/{writer.model}", generated_at=now)`。
		4. `write_atomic(journal_path(journal_dir, repo_id, day), text)`。
		5. `store.save_entry(Entry(repo_id, day, str(path), analyst=<3の値 か "none">, writer=<同じ>, generated_at=now, story_ids=<話題のIDの順>))`。

		どの段の例外（`AnalyzeFailed`・`WriteFailed`・`RouteError`・`OSError`・`StateError`・拡張点の例外）も受け止めず、そのまま投げる。4より前で投げれば、ファイルと `entries` は変わらない。

		**CLI**：`shipcast.write.configure(parser)` が `--repo ID`（省けば登録したすべて）と `--date YYYY-MM-DD`（`date.fromisoformat`。省けば設定の時間帯の今日）を足し、`run(args)` を `func` にする。`cli.py` の `write` の葉に `configure` を渡す。`run` は `shipcast collect` の `run` と同じ順と文で、設定の読み込み・repositoryの選択・`Store` を開く前検査をし（失敗は `shipcast write: …` と直し方、終了コード1）、次に `get_route(config.models.analyst)`・`get_route(config.models.writer)` を作る（`RouteError`・`ValueError` は `shipcast write: モデルの経路を作れません: <理由>` で終了コード1）。repositoryごとに：

		1. `collect_repo(store, repo, day, tz=tz, collectors=COLLECTORS)`。警告は `shipcast write: 警告: <id>: <文>` で出す。誤りが1件でもあれば `shipcast write: 失敗: <id>: <文>` を誤りごとに出し、さらに `shipcast write: 失敗: <id>: 収集に失敗したため、日誌を書きませんでした` を出して、この repositoryを飛ばす（終了コード1）。
		2. `write_day(store, repo.id, day, tz=tz, journal_dir=config.journal_dir, analyst=…, writer=…, now=datetime.now(tz))`。
		3. 成功なら標準出力に `<id> <日付>: 日誌を書きました（出来事 <n>件、話題 <m>件）: <path>`。`write_day` が `Exception` の子のどれか（`AnalyzeFailed`・`WriteFailed`・`RouteError`・`JournalFormatError`・`OSError`・`StateError`・`UnicodeError`・拡張点の任意の例外を含む）を投げたら、`shipcast write: 失敗: <id>: <例外の文>`（`AnalyzeFailed`・`WriteFailed`・`RouteError`・`JournalFormatError`・`OSError`・`StateError` 以外は `<例外の型の名前>: <例外の文>`）を標準エラーに出して終了コード1にし、次の repositoryへ進む。`KeyboardInterrupt` などの `BaseException` だけの子は受け止めない。

		試験は `shipcast.write` の名前 `COLLECTORS`・`get_route`・`datetime` を差し替えて、外部を呼ばない。
		"""
		satisfies: ["R-01", "R-03", "F-01"]
	}
	"D-08": {
		title: "プロンプト `src/shipcast/prompts/write.md`"
		text: """
		書き手のモデルへの system の本文（日本語）。`importlib.resources.files("shipcast") / "prompts" / "write.md"` を UTF-8 で読む。本文は `redact()` を通しても変わらない文にする。中身は次の節を持つ。

		1. 役目：入力のJSON（`repo`・`date`・`stories`）の話題から、その日の開発日誌の文章を書く。読み手は、エージェントに開発を任せている本人。
		2. 文体：「要約＋読み物」。です・ます調。`lead` は1〜2文、`summary` は3〜5行（話題が少なければ減らしてよい）、`story` は話題ごとに `###` の小見出しを付けた読み物。
		3. 応答の形：D-01 の応答のJSONの見本と各項目の意味。
		4. 使ってよい書式：`story` の中は、`###` 以下の見出し、段落、箇条書き、`` `code` ``、リンクだけ。`:::` の囲み、`#`・`##` の見出し、HTMLは使わない（囲みと数字はshipcastが付ける）。
		5. 守ること（創作の禁止）：話題にない事実、数字、人名、理由を足さない。数を数えて書かない。`[伏せた]` の中身を推し量らない。JSONだけを返す。
		6. 頼み直し：入力に `previous_errors` があれば、それを直した応答を返す。

		試験で確かめる語：`要約＋読み物`、`です・ます調`、`lead`、`summary`、`story`、`:::`、`previous_errors`、`話題にない事実`。
		"""
		satisfies: ["R-02", "F-02"]
	}
}

seams: {
	"SE-01": {title: "fake の経路の `responder`", text: "`get_route(ModelConfig(\"fake\", \"fake-writer\", None, None), responder=...)` で応答を試験が決め、受け取った prompt・system・want_json と呼ばれた回数を記録する。分析と書き手で別の `responder` を使う。外部を呼ばない"}
	"SE-02": {title: "一時ディレクトリの `Store` と `journal_dir`", text: "`Store(tmp_path / \"state\")` に見本の出来事を `add_events` で入れ、`journal_dir = tmp_path / \"journal\"` に書かせる。結果は `parse_journal`・`entry_for`・ファイルの中身で読む"}
	"SE-03": {title: "`build_entry` の決まった文字列", text: "見本の話題・出来事・`Draft`・`generated_at` から、日誌の全文を試験の中の期待の文字列と比べる"}
	"SE-04": {title: "`os.replace` と `os.fsync` の差し替え", text: "`monkeypatch` で `shipcast.write.os.replace` などに例外を投げさせ、前のファイルが変わらず、一時ファイルが残らないことを確かめる"}
	"SE-05": {title: "CLI の差し替え", text: "`SHIPCAST_CONFIG` で一時の設定（経路は `fake`）を読ませ、`shipcast.write.COLLECTORS` を偽の collector に、`shipcast.write.get_route` を `responder` を足す関数に差し替えて `main([\"write\", …])` を呼ぶ"}
}

rejected: [
	"書き手にMarkdownの全文（囲みを含む）を書かせる案：囲みの順と種類（R-02）、`notice`・`waiting` の写し、生のHTMLの混入を書き手の出来に頼ることになる。検査も重くなる",
	"`Store.stories_for` で話題を読む案：同じ日の再分析で古い話題が残る（iss-00015 の risks）",
	"書き手に出来事の本文も渡す案：骨組みだけを渡す（epic-00004 の F-04）。出来事の本文は分析の段で話題にまとめ済み",
	"`:::warning` を前付けの `lead` 同様に書き手に要約させる案：本人が知るべきことは言い換えずにそのまま見せる方が誤りが少ない",
	"収集を `write` の外（`shipcast run`）だけで行う案：R-01 は `write` 単独で集める→まとめる→書くを通すことを求める",
]

risks: [
	"拡張点の部品が生のHTMLを返すと配信のページが壊れうる。このIssueでは中身を検査しない（iss-00019 が自分の囲みを機械で作るときに守る。申し送り）",
	"書き手が W-05 の検査に通る形で話題にない事実を書く可能性は残る。プロンプトで禁じ、骨組みだけを渡して減らすが、機械では見分けられない",
	"`Store.save_entry` が `write_atomic` の後で失敗すると、ファイルは新しく、`entries` は古い。次の実行で両方が書き直される",
]
