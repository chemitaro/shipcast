package spec

design: {
	"D-01": {
		title: "Xの長さと応答の検査（`shipcast.draft.x_length`・`parse_x_draft`）"
		text: """
		epic-00006 の D-03。新しい module `src/shipcast/draft.py`。

		```python
		X_LIMIT = 280
		MAX_HASHTAGS = 3

		@dataclass(frozen=True)
		class XDraft:
		    text: str
		    hashtags: tuple[str, ...]

		    @property
		    def post(self) -> str: ...  # 本文、ハッシュタグがあれば空行と空白区切りのハッシュタグ

		def x_length(text: str) -> int: ...
		def parse_x_draft(text: str) -> tuple[XDraft | None, list[str]]: ...
		```

		- `x_length`：`unicodedata.normalize("NFC", text)` の各文字について、符号位置が U+0000〜U+10FF、U+2000〜U+200D、U+2010〜U+201F、U+2032〜U+2037 のどれかなら1、ほかは2を足した値。例：`"abc"` は3、`"日本語"` は6、`"か\\u3099"`（濁点の合成）は NFC で `"が"` になり2。
		- `XDraft.post`：ハッシュタグが空なら `text`、あれば `text + "\\n\\n" + " ".join(hashtags)`。
		- `parse_x_draft`：`shipcast.write.parse_draft` と同じく、前後の空白を除き、全体が ```` ``` ```` または ```` ```json ```` の囲みなら中を取り出し、`json.loads(..., parse_constant=拒否)` で読む。JSON でない・オブジェクトでないときは、それぞれ1件の誤りを返す。
		- 検査（誤りは日本語で、応答の値をそのまま写さない）：
		  - `text`：空でない文字列。前後の空白を除いて使う。改行（`\\n`）は許し、`\\r` とほかの制御文字（`unicodedata.category` が `Cc` の文字のうち `\\n` 以外）は許さない。`http://`・`https://`（大文字小文字を問わない）を含まない。`@` の直後に英数字か `_` が続く宛先を含まない。
		  - `hashtags`：なければ空として扱う。あるなら0〜3件の文字列の配列。各要素は前後の空白を除いた後、正規表現 `#\\w+`（Unicode の `\\w`）の全体に一致し、`#` の後が数字だけではない。同じものを2度入れない（大文字小文字を区別して比べる）。
		  - 上の誤りがないときだけ、`x_length(XDraft.post) <= X_LIMIT` を確かめ、超えたら長さと上限を含む誤り（例 `post: Xの数え方で 300 です。280 以内にしてください`）を返す。
		- 誤りがなければ `XDraft(text.strip(), tuple(hashtags))` と空の一覧を返す。
		"""
		satisfies: ["R-01"]
	}
	"D-02": {
		title: "書き手への依頼（`shipcast.draft.compose_x`）とプロンプト `prompts/x.md`"
		text: """
		```python
		MAX_ATTEMPTS = 2
		PROMPT_PATH = "prompts/x.md"

		class XDraftFailed(Exception):
		    attempts: int
		    errors: tuple[str, ...]

		def compose_x(stories: Sequence[Story], route: _Completer, *, repo_id: str, day: date) -> XDraft: ...
		```

		- `stories` が空なら `ValueError`。
		- system は `importlib.resources.files("shipcast")` から読む `prompts/x.md`。入力は `{"repo": repo_id, "date": day.isoformat(), "stories": [{"title", "what", "why"} ...]}` を `json.dumps(ensure_ascii=False)` にしたもの。`notice`・`waiting`・`neta`・`event_ids`・出来事は渡さない。
		- `route.complete(prompt, system=system, want_json=True)` を最大2回呼ぶ。2回目は入力に `previous_errors`（1回目の誤りの一覧）を足す。2回とも誤りなら `XDraftFailed(2, 最後の誤り)`（メッセージは `shipcast.write.WriteFailed` と同じく、先頭の5件をつなぐ）。経路の例外（`RouteError` など）は受け止めず、頼み直さない。
		- `prompts/x.md` は `prompts/write.md` と同じ見出しの組（役目、文体、応答の形、守ること、頼み直し）で書く。要点：
		  - 読み手は X のタイムラインの開発者。です・ます調でも常体でもよいが、1本の投稿として自然な日本語にする
		  - 本文は日本語で140字程度。ハッシュタグを含む投稿の全体が X の数え方で280以内（日本語の1字は2と数える）
		  - 応答は `{"text": "本文", "hashtags": ["#shipcast"]}` の JSON だけ。ハッシュタグは0〜3個、`#` で始まる1語
		  - 話題にない事実・数字・人名・理由を足さない。URL と `@` の宛先を入れない。`[伏せた]` の中身を推し量らない。秘密や顧客の情報、公開していない製品の名前を書かない
		  - 入力に `previous_errors` があれば、挙げられた箇所を直す
		- プロンプトは `shipcast.redact.redact` を通しても変わらない文にする（`write.md` の試験と同じ確かめ）。
		"""
		satisfies: ["R-01"]
	}
	"D-03": {
		title: "下書きのファイル（`draft_path`・`render_x_draft`）と消化の順（`make_x_draft`）"
		text: """
		```python
		DRAFT_STORIES = 3

		def draft_path(state_dir: str | PathLike[str], repo_id: str, day: date) -> Path:
		    # state_dir / "drafts" / repo_id / f"{day.isoformat()}-x.md"。repo_id と day は journal_path と同じ規則で検査する

		def render_x_draft(draft: XDraft, stories: Sequence[Story], *, repo_id: str, day: date,
		                   writer: str, generated_at: datetime) -> str: ...

		@dataclass(frozen=True)
		class XDraftResult:
		    path: Path
		    draft: XDraft
		    stories: tuple[Story, ...]
		    consumed: int

		class DraftExists(Exception): ...   # path を持つ
		class NoStories(Exception): ...     # repo_id を持つ

		def make_x_draft(store: Store, repo_id: str, day: date, *, state_dir: Path,
		                 writer: _Completer, now: datetime) -> XDraftResult: ...
		```

		- `render_x_draft` の形（末尾に改行1つ。`writer` は `"<経路>/<モデル>"`）：

		```markdown
		# Xの下書き（demo-app 2026-11-26）

		:::note
		shipcastは投稿しません。内容を確かめてから、本人が投稿してください。
		:::

		## 投稿の本文

		（XDraft.post をそのまま）

		## 確かめること

		- 長さ：Xの数え方で 142 / 280
		- ハッシュタグの案：#shipcast #個人開発（なければ「なし」）
		- 書き手：fake/fake-writer
		- 作った時刻：2026-11-26T22:00:00+09:00

		## 使った話題

		- 題名A
		- 題名B
		```

		  - 使った話題の題名は、空白を1つにまとめた1行にする（このファイルは配信しないので文字参照にはしない）。
		- `make_x_draft` の順：
		  1. `path = draft_path(...)`。`path.exists()` なら `DraftExists`（モデルを呼ばない）。
		  2. `stories = store.unconsumed_stories(repo_id, limit=DRAFT_STORIES)`。空なら `NoStories`（モデルを呼ばない）。
		  3. `draft = compose_x(stories, writer, repo_id=repo_id, day=day)`。
		  4. `shipcast.write.write_atomic(path, render_x_draft(...))`（親のフォルダーを作る）。
		  5. `consumed = store.consume_neta(story.id for story in stories)`。
		  6. `XDraftResult(path, draft, tuple(stories), consumed)` を返す。
		- 3・4で例外が出たら、5を行わずにそのまま上げる（話題は未消化のまま。4の失敗では `write_atomic` が一時ファイルを消す）。
		- `shipcast.draft` は `shipcast.write`（`write_atomic`）を import してよい。`write` は `draft` を import しない。
		"""
		satisfies: ["R-02"]
	}
	"D-04": {
		title: "CLI（`shipcast draft x`）への配線"
		text: """
		```python
		def configure_x(parser: argparse.ArgumentParser) -> None:
		    # --repo ID（必須）、--date YYYY-MM-DD（date.fromisoformat、既定は設定のタイムゾーンでの今日）、func=run_x

		def run_x(args: argparse.Namespace) -> int: ...
		```

		- `run_x` の順と出力（誤りは標準エラー、接頭辞 `shipcast draft x: `。`shipcast write` の `run` と同じ言い回しにそろえる）：
		  1. `load_config()`。`ConfigError` と `OSError` は1。
		  2. `args.repo` が `config.repos` の id になければ1（`shipcast repo list` で確かめる直し方を添える）。
		  3. `Store(config.state_dir)`。`StateError`・`OSError` は1。以降は `with store:` の中。
		  4. `get_route(config.models.writer)`。`RouteError`・`ValueError` は1。
		  5. `make_x_draft(store, repo, day, state_dir=config.state_dir, writer=route, now=datetime.now(tz))`。
		     - `DraftExists`：1。`同じ日付の下書きがあります: <path>` と、消すか別の `--date` を使う直し方。
		     - `NoStories`：1。`未消化の話題がありません: <repo>`（`shipcast write` で日誌を書くと話題がたまる旨）。
		     - `XDraftFailed`・`RouteError`・`OSError`・`StateError`：1。`失敗: <repo>: <error>`。
		  6. 成功は0。標準出力に `<repo> <date>: Xの下書きを作りました（話題 N件、Xの数え方で L / 280）: <path>` と、次の行に `shipcastは投稿しません。内容を確かめてから、本人が投稿してください。`。
		- `src/shipcast/cli.py` は、`from shipcast import draft  # isort: skip` の1行と、`Entry("x", "X向けの下書きを作る", draft.configure_x)` の変更だけ。`Command` の `issue_id` はそのまま。
		- `tests/test_cli.py` は、未実装の一覧（`test_unimplemented_leaf_reports_issue_without_writing` の引数）から `("draft x", "iss-00020")` の行を外すだけ。`draft --help` に `x` が出る試験はそのまま通る。
		"""
		satisfies: ["R-01", "R-02"]
	}
}
