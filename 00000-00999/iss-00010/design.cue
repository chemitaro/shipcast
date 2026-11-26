package spec

goals: [
	"後のIssueが、型・表・日誌のパスと前付けの名前を自分で決めず、`shipcast.model` と `shipcast.state` を読み込むだけで済むようにする",
	"同じ日を何度集め直しても、出来事・話題・日誌・ネタポイントが増えない（冪等）",
	"標準のライブラリだけで、手元の `tmp_path` で全部を試験できる",
]

current: "`src/shipcast/` には `__init__.py`、`__main__.py`、`cli.py`（iss-00008 の骨組み）だけがある。型・状態・日誌の契約はない。"
target:  "`shipcast.model` に型・ID・JSON・日誌の契約が、`shipcast.state` に `Store` が1か所ずつあり、`uv run pytest -q` で全部の約束が確かめられる。"

design: {
	"D-01": {
		title: "誤りの型と共通の検査（`shipcast.model`）"
		text: """
		```python
		SCHEMA_VERSION = 1                      # JSONの "schema" の値
		SOURCES = ("git", "specdock", "orca")
		REPO_ID_PATTERN = re.compile(r"[a-z0-9-]+")   # fullmatch で使う

		class ModelError(ValueError): ...       # 型の値の誤り（F-01、F-04）
		class JournalFormatError(ValueError): ...  # 前付けの誤り（F-02）
		```

		- 誤りの文は、必ず `<型の名前>.<項目>` を含める（例 `Event.at: 時差（タイムゾーン）がありません`、`Story.neta.score: 0〜3の整数ではありません: 4`）。試験は、この項目の名前が誤りの文にあることで確かめる。
		- `repo_id` の検査は `REPO_ID_PATTERN.fullmatch` で行う（空、英大文字、`/`、`.`、`_` は誤り）。
		"""
		satisfies: ["F-01", "F-04"]
	}
	"D-02": {
		title: "Event・Neta・Story・Entry の型（`shipcast.model`）"
		text: """
		すべて `@dataclass(frozen=True)`。`__post_init__` で値を検査し（直接作ったときも `from_dict` で作ったときも同じ）、`list` で渡された並びは `tuple` に直して持つ（`object.__setattr__`）。`date` の項目は `datetime.date`（`datetime.datetime` は誤り）、時刻の項目は時差付きの `datetime.datetime`（`tzinfo` がないか `utcoffset()` が `None` なら誤り）。

		| 型 | 項目（順） | 既定値のある項目 |
		|---|---|---|
		| `Event` | `id: str`、`repo_id: str`、`source: str`（`SOURCES` のどれか）、`kind: str`、`at: datetime`、`title: str`、`body: str`、`refs: tuple[str, ...]`、`actor: str` | `body=""`、`refs=()`、`actor=""` |
		| `Neta` | `score: int`（0〜3。`bool` は誤り）、`reason: str`、`channels: tuple[str, ...]` | `reason=""`、`channels=()` |
		| `Story` | `id: str`、`repo_id: str`、`date: date`、`title: str`、`what: str`、`why: str`、`neta: Neta`、`notice: tuple[str, ...]`、`waiting: tuple[str, ...]`、`event_ids: tuple[str, ...]` | `notice=()`、`waiting=()`、`event_ids=()` |
		| `Entry` | `repo_id: str`、`date: date`、`path: str`、`analyst: str`、`writer: str`、`generated_at: datetime`、`story_ids: tuple[str, ...]` | `story_ids=()` |

		- `kind` は空でない文字列なら何でもよい（commit、merge、scope_opened、scope_closed、todo_open、todo_done、conversation などは collector が決める）。`id`・`title`・`what`・`why`・`path`・`analyst`・`writer` も空でない文字列。`body`・`reason`・`actor` は空でもよい。
		- `analyst`・`writer` の値は `<経路>/<モデル>`（例 `codex/gpt-6.2-sol`、`fake/fake`）。形は検査しない。
		- `Entry.path` は日誌のファイルのパスの文字列（`journal_path` の結果を `str()` したもの）。
		"""
		satisfies: ["R-01", "F-01"]
	}
	"D-03": {
		title: "JSONとの行き来"
		text: """
		各型（`Event`・`Story`・`Entry`）に `to_dict() -> dict`、`to_json() -> str`、`@classmethod from_dict(data: Mapping) -> Self`、`@classmethod from_json(text: str) -> Self` を付ける。`Neta` は `Story` の中だけで使い、`to_dict`・`from_dict` だけを持つ（`schema` を入れない）。

		```json
		{"schema": 1, "id": "3f2a9c0d1e4b5a67", "repo_id": "demo-app", "source": "git", "kind": "commit",
		 "at": "2026-11-26T10:15:00+09:00", "title": "架空の変更", "body": "", "refs": ["0123abcd"], "actor": "taro"}
		{"schema": 1, "id": "…", "repo_id": "demo-app", "date": "2026-11-26", "title": "…", "what": "…", "why": "…",
		 "notice": ["…"], "waiting": [], "event_ids": ["…"], "neta": {"score": 2, "reason": "…", "channels": ["x"]}}
		{"schema": 1, "repo_id": "demo-app", "date": "2026-11-26", "path": "/tmp/j/demo-app/2026/2026-11-26.md",
		 "analyst": "fake/fake", "writer": "fake/fake", "generated_at": "2026-11-27T03:00:00+09:00", "story_ids": ["…"]}
		```

		- 鍵の順は、`schema` の後に上の表の項目の順。`to_json` は `json.dumps(self.to_dict(), ensure_ascii=False)`（同じ値なら同じ文字列）。
		- `date` は `date.isoformat()`（`YYYY-MM-DD`）、時刻は `datetime.isoformat()`（元の時差のまま）。読むときは `date.fromisoformat`・`datetime.fromisoformat`。
		- `from_dict`：`schema` がないか1でなければ `ModelError`（項目 `schema`）。既定値のない項目がなければ `ModelError`（その項目）。文字列の項目に文字列でないもの、並びの項目に文字列の並びでないもの、`score` に整数でないものが来れば `ModelError`。知らない鍵は捨てる。`from_json` は、JSONとして読めないか最上位が辞書でなければ `ModelError`（項目 `json`）。
		- `__eq__` は dataclass の既定（時刻は同じ瞬間なら等しい）。往復の試験は、同じ値から作った同じ時差の値で確かめる。
		"""
		satisfies: ["R-01", "F-01"]
	}
	"D-04": {
		title: "安定したID：`event_id` と `story_id`"
		text: """
		```python
		def event_id(source: str, repo_id: str, native_id: str) -> str
		def story_id(repo_id: str, day: date, event_ids: Iterable[str]) -> str
		```

		- `event_id`：`hashlib.sha256("\\x1f".join(["event", source, repo_id, native_id]).encode("utf-8")).hexdigest()[:16]`。`native_id` は git ならコミットのSHA（全40桁）、specdock なら `<Scope ID>:<opened|closed>` や todo のID、orca なら会話のIDと発言の番号など、出所の中で一意のもの（何を入れるかは各collectorが決め、自分の仕様に書く）。`source` が `SOURCES` にないか `repo_id` が形に合わなければ `ModelError`、`native_id` が空なら `ModelError`。
		- `story_id`：`event_ids` を重複を除いて並べ替え、`"\\x1f".join(["story", repo_id, day.isoformat(), *ids])` の sha256 の先頭16桁。並びの順に依らない。`event_ids` が空なら `ModelError`。分析（iss-00015）は、同じ出来事のまとまりから同じ話題のIDを得て、`save_stories` と `add_neta` の冪等さに使える。
		- 区切りに `\\x1f`（単位区切り）を使うのは、`("a-b", "c")` と `("a", "b-c")` のような継ぎ目の取り違えを避けるため。
		"""
		satisfies: ["R-01", "R-03", "F-01"]
	}
	"D-05": {
		title: "日誌のパスと前付けの契約（`shipcast.model`）"
		text: """
		epic-00002 の D-05 をコードにする。ほかのIssueは、パスや項目の名前を自分で書かず、ここだけを使う。

		```python
		JOURNAL_REQUIRED_FIELDS = ("title", "lead", "date", "repo")
		JOURNAL_FIELDS = (*JOURNAL_REQUIRED_FIELDS, "category", "analyst", "writer", "generated_at", "schema")

		@dataclass(frozen=True)
		class JournalMeta:
		    title: str
		    lead: str
		    date: date
		    repo: str
		    category: str | None = None
		    analyst: str | None = None
		    writer: str | None = None
		    generated_at: str | None = None   # ISO 8601 の文字列のまま持つ（読む側は使わない）
		    schema: int | None = None

		def journal_path(journal_dir: str | os.PathLike[str], repo: str, day: date) -> Path
		def write_frontmatter(meta: JournalMeta) -> str
		def parse_journal(text: str) -> tuple[JournalMeta, str]   # (前付け, 本文)
		def read_frontmatter(path: str | os.PathLike[str]) -> JournalMeta
		```

		- **パス**：`Path(journal_dir) / repo / f"{day:%Y}" / f"{day.isoformat()}.md"`。`~` の展開はしない（設定の側で済ませる）。ファイルやディレクトリを作らない。`repo` が `REPO_ID_PATTERN` に合わなければ `ModelError`（F-04）。
		- **JournalMeta の検査**（`__post_init__`。誤りは `JournalFormatError`、文に項目の名前）：必須の文字列が空でない。`date` は `datetime.date`（`datetime` でない）。`repo` は `REPO_ID_PATTERN`。文字列の値（任意の項目を含む）は、改行（`\\n`、`\\r`）を含まず、前後に空白がなく、空でない（任意の項目は、ないなら `None`）。`schema` は0以上の `int`（`bool` は誤り）。この検査のため、作れた `JournalMeta` は必ず書いて読み戻せる。
		- **書く**：`"---\\n"`、`JOURNAL_FIELDS` の順に値が `None` でない項目を `f"{key}: {value}\\n"`（`date` は `isoformat()`、`schema` は `str(int)`）、`"---\\n"`。本文は、書く段（iss-00016）が後ろに足す。
		- **読む**（`parse_journal`）：
		  1. 先頭の BOM（`\\ufeff`）は捨てる。1行目（行末の空白と `\\r` を除く）が `---` でなければ誤り。
		  2. 次に `---` だけの行が来るまでを前付けとする。なければ誤り（「閉じの `---` がありません」）。
		  3. 前付けの各行：空白だけの行は飛ばす。最初の `:` で分け、鍵（前後の空白を除く）が `[a-z_]+` でないか `:` がなければ、ファイルの何行目かを名指して誤り。値は前後の空白を除く。同じ鍵が2回あれば、その鍵を名指して誤り。知らない鍵は捨てる。任意の項目の空の値は `None` と読む。
		  4. 必須の項目のうち、ないか空のものを `JOURNAL_REQUIRED_FIELDS` の順に全部集め、1つ以上あれば `JournalFormatError("前付けに必須の項目がありません: lead, date")` の形で名指す。
		  5. `date` は `date.fromisoformat`、`schema` は数字だけなら `int`。読めなければ、その項目を名指して誤り。
		  6. 本文は、閉じの `---` の行（改行を含む）の直後から終わりまでの文字列をそのまま返す。
		- **ファイル**：`read_frontmatter(path)` は UTF-8 で読み、`parse_journal(...)[0]` を返す。ファイルがないときの `FileNotFoundError` は、そのまま上げる。
		- 値に `:` を含んでよい（最初の `:` だけで分けるので `title: shipcast: 日誌` は `shipcast: 日誌` と読む）。引用符は解釈しない（YAMLではない）。
		"""
		satisfies: ["R-04", "F-02", "F-04"]
	}
	"D-06": {
		title: "状態の置き場 `shipcast.state.Store`"
		text: """
		```python
		STATE_SCHEMA_VERSION = 1
		STATE_FILENAME = "state.sqlite3"

		class StateError(RuntimeError): ...

		@dataclass(frozen=True)
		class Run:
		    repo_id: str
		    started_at: datetime        # 時差付き
		    finished_at: datetime       # 時差付き
		    result: str                 # "ok" | "failed"
		    error: str = ""

		class Store:
		    def __init__(self, state_dir: str | os.PathLike[str]) -> None
		    path: Path                                   # state_dir / "state.sqlite3"
		    def close(self) -> None                      # __enter__ / __exit__ も持つ
		    def add_events(self, events: Iterable[Event]) -> int          # 新しく入った件数
		    def events_for(self, repo_id: str, day: date, *, tz: tzinfo) -> list[Event]
		    def save_stories(self, stories: Iterable[Story]) -> int       # 書いた件数（新規＋更新）
		    def stories_for(self, repo_id: str, day: date) -> list[Story]
		    def save_entry(self, entry: Entry) -> None
		    def entry_for(self, repo_id: str, day: date) -> Entry | None
		    def record_run(self, run: Run) -> int                         # 実行の記録の番号
		    def runs_for(self, repo_id: str) -> list[Run]
		    def add_neta(self, story: Story) -> bool                      # 新しく足したら True
		    def neta_balance(self, repo_id: str) -> int
		    def unconsumed_neta(self, repo_id: str) -> list[str]          # 未消化の話題のID
		    def consume_neta(self, story_ids: Iterable[str]) -> int       # 消化にした件数
		```

		- `Run` の検査（`__post_init__`、誤りは `ModelError`）：`repo_id` の形、時刻の時差、`result` が `ok`・`failed` のどちらか、`finished_at >= started_at`。
		- **開く**：`Path(state_dir).mkdir(parents=True, exist_ok=True)` の後に `sqlite3.connect(path)`。`PRAGMA user_version` を読む（ここで `sqlite3.DatabaseError` なら接続を閉じて `StateError`）。1より大きければ、接続を閉じ、何も書かずに `StateError`（文に path と版）。0なら、1つのトランザクションで D-07 の表を作り `PRAGMA user_version = 1` にする。1なら、表を `IF NOT EXISTS` で確かめるだけ。
		- **書く**：書く関数は、それぞれ `with self._conn:` の1つのトランザクション（途中の誤りで半端に入らない）。入れる行の `json` の列は、その型の `to_json()`。読むときは `from_json`。
		- `add_events`：`INSERT OR IGNORE`。戻り値は、新しく入った行の数（`changes()` の合計）。
		- `events_for`：`start = datetime.combine(day, time(0), tzinfo=tz)`、`end = datetime.combine(day + timedelta(days=1), time(0), tzinfo=tz)` をUTCに直し、`repo_id = ? AND at_utc >= ? AND at_utc < ? ORDER BY at_utc, id`。`tz` はキーワードだけで、既定値を持たない（日の区切りを呼ぶ側に必ず決めさせる）。
		- `save_stories`：`INSERT ... ON CONFLICT(id) DO UPDATE SET repo_id=excluded.repo_id, date=excluded.date, json=excluded.json`（後の内容で上書き。行の `rowid` は保つ）。`stories_for` は `repo_id = ? AND date = ? ORDER BY rowid`（最初に保存した順）。
		- `save_entry`：`(repo_id, date)` を主キーに同じく上書き。`entry_for` は、なければ `None`。
		- `record_run`：`INSERT` して `lastrowid` を返す。`runs_for` は `ORDER BY started_at_utc, id`。
		- `add_neta`：`INSERT OR IGNORE INTO neta_ledger(story_id, repo_id, points, consumed) VALUES (?, ?, story.neta.score, 0)`。同じ話題は、点数が後で変わっても最初の1回だけ（iss-00019 の「同じ話題は二度足さない」）。`neta_balance` は `consumed = 0` の `points` の合計（なければ0）。`unconsumed_neta` は `consumed = 0` の話題のIDを `points DESC, rowid` の順。`consume_neta` は `consumed = 1` にした行の数を返す（すでに消化済みや知らないIDは数えない）。
		- `Store` は1つのプロセス・1つのスレッドで使う（夜の実行も逐次）。同時の書込みへの備えは、SQLiteの既定のロックに任せる。
		"""
		satisfies: ["R-02", "R-03", "F-03"]
	}
	"D-07": {
		title: "SQLiteの表（版1）"
		text: """
		```sql
		CREATE TABLE IF NOT EXISTS events (
		  id      TEXT PRIMARY KEY,
		  repo_id TEXT NOT NULL,
		  source  TEXT NOT NULL,
		  kind    TEXT NOT NULL,
		  at      TEXT NOT NULL,   -- 元の時差の ISO 8601
		  at_utc  TEXT NOT NULL,   -- UTC の 'YYYY-MM-DDTHH:MM:SS.ffffffZ'（桁が揃い、文字の順＝時刻の順）
		  json    TEXT NOT NULL
		);
		CREATE INDEX IF NOT EXISTS events_repo_at ON events (repo_id, at_utc);

		CREATE TABLE IF NOT EXISTS stories (
		  id      TEXT PRIMARY KEY,
		  repo_id TEXT NOT NULL,
		  date    TEXT NOT NULL,   -- YYYY-MM-DD
		  json    TEXT NOT NULL
		);
		CREATE INDEX IF NOT EXISTS stories_repo_date ON stories (repo_id, date);

		CREATE TABLE IF NOT EXISTS entries (
		  repo_id TEXT NOT NULL,
		  date    TEXT NOT NULL,
		  path    TEXT NOT NULL,
		  json    TEXT NOT NULL,
		  PRIMARY KEY (repo_id, date)
		);

		CREATE TABLE IF NOT EXISTS runs (
		  id              INTEGER PRIMARY KEY AUTOINCREMENT,
		  repo_id         TEXT NOT NULL,
		  started_at      TEXT NOT NULL,   -- 元の時差の ISO 8601
		  started_at_utc  TEXT NOT NULL,
		  finished_at     TEXT NOT NULL,
		  result          TEXT NOT NULL CHECK (result IN ('ok', 'failed')),
		  error           TEXT NOT NULL DEFAULT ''
		);

		CREATE TABLE IF NOT EXISTS neta_ledger (
		  story_id TEXT PRIMARY KEY,
		  repo_id  TEXT NOT NULL,
		  points   INTEGER NOT NULL CHECK (points BETWEEN 0 AND 3),
		  consumed INTEGER NOT NULL DEFAULT 0 CHECK (consumed IN (0, 1))
		);
		```

		- epic-00002 の D-04 の5つの表。`runs` は D-04 の「開始・終了・結果・誤り」、`neta_ledger` は「話題ごとのポイントと、消化済みか」。
		- 列を足すような変更は、後のIssueで `STATE_SCHEMA_VERSION` を上げ、移行を書いてから行う（このIssueは版1だけ）。
		"""
		satisfies: ["R-02", "R-03"]
	}
	"D-08": {
		title: "試験の形（`tests/test_model.py`、`tests/test_journal.py`、`tests/test_state.py`）"
		text: """
		- 見本は架空の値（repository は `demo-app`、作者は `taro` など）。時差は `timezone(timedelta(hours=9))` を使い、OSの時差のデータ（`zoneinfo`）に頼らない。
		- 状態の試験は `Store(tmp_path / "state")` だけを使い、利用者のディレクトリや環境変数に触れない。表の確かめは、同じファイルを `sqlite3.connect` で開いて `sqlite_master` と `PRAGMA user_version` を読む。
		- F-03 の試験：(a) 先に `sqlite3` で `PRAGMA user_version = 2` のファイルを作り、`Store` が `StateError` を上げ、その後もファイルのバイト列が同じで、表が作られていない。(b) `state.sqlite3` に SQLite でない文字列を書いておき、`StateError`。
		- 誤りの試験は `pytest.raises(ModelError / JournalFormatError / StateError, match=<項目の名前>)`。
		- 外部のコマンドやネットワークを使わない。
		"""
		satisfies: ["R-01", "R-02", "R-03", "R-04", "F-01", "F-02", "F-03", "F-04"]
	}
}

compatibility: "新しいmoduleを足すだけで、既存のCLI（iss-00008）と設定（iss-00009）には触れない。ここで決めた名前・JSONの形・表・前付けの項目は、後の全Issueの約束になる。変えるときは、epic-00002 の D-03〜D-05 とこのIssueの設計を先に直し、`SCHEMA_VERSION`・`STATE_SCHEMA_VERSION` を上げる。"

risks: [
	"後のIssueが、ここにない項目を欲しくなりうる（例：Event の変更したファイルの数）。`body` や `refs` に入れるか、このIssueの設計を直して版を上げる。各Issueで勝手に列を足さない",
	"`save_stories` は上書きで、その日の古い話題を消さない。分析をやり直して話題のまとまりが変わると、前の話題が残る。iss-00015 が `story_id` で同じまとまりから同じIDを得ることで減らし、残る分は iss-00015 で扱う（このIssueでは消す関数を作らない）",
	"`events_for` の日の区切りは呼ぶ側の `tz` に依る。collector と執筆で違う `tz` を渡すと、日の境の出来事がずれる。どちらも設定の `timezone`（iss-00009）を渡す",
]
