package spec

goals: [
	"後のcollector（iss-00012、iss-00013）が、`Collector` の約束に従うクラスを1つ書き、`COLLECTORS` に1行足すだけで収集に加わる",
	"収集の実行（呼ぶ・確かめる・保存する）を `collect_repo` の1か所にし、`collect`・`write`・`run` のコマンドが同じものを呼ぶ",
	"対象のrepositoryを読むだけにし、`HEAD`・index・ref・作業ツリーを変えない",
	"標準のライブラリだけで、`tmp_path` の架空のGitのrepositoryで全部を試験できる",
]

current: "`shipcast collect` は未実装の印（終了コード2）を返す。`src/shipcast/collect/` はない。"
target:  "`shipcast collect --repo <id> --date <日付>` が、Gitのcollectorでその日に正本のbranchに入ったcommitとmergeを集め、状態に保存し、件数と警告と失敗を示す。"

design: {
	"D-01": {
		title: "collectorの約束（`shipcast.collect.base`）"
		text: """
		```python
		class CollectError(Exception):
		    \"\"\"そのrepositoryを、この出所から読めない（F-01）。文は人が読む日本語で、直す対象（path、ref）を含める。\"\"\"

		@dataclass(frozen=True)
		class CollectResult:
		    events: tuple[Event, ...] = ()
		    warnings: tuple[str, ...] = ()      # 続けられたが人に知らせること
		    # __post_init__ で list も tuple に直す（object.__setattr__）

		class Collector(Protocol):
		    name: str                            # shipcast.model.SOURCES のどれか。Event.source と同じ値
		    def collect(self, repo: RepoConfig, day: date, tz: tzinfo) -> CollectResult: ...

		def day_bounds(day: date, tz: tzinfo) -> tuple[datetime, datetime]:
		    # (datetime.combine(day, time(0), tzinfo=tz), datetime.combine(day + timedelta(days=1), time(0), tzinfo=tz))
		    # Store.events_for と同じ区切り。collectorはこの範囲 [start, end) のEventだけを返す
		```

		collectorの約束（後のcollectorが守ること。docstring にも書く）：

		1. `collect` は読むだけにする。対象のrepositoryと道具の状態を変えない。
		2. 返すEventは、`source == self.name`、`repo_id == repo.id`、`start <= at < end`（`day_bounds(day, tz)`）。`id` は `event_id(self.name, repo.id, <出所の中で一意の値>)`。
		3. そのrepositoryをこの出所から読めないときは `CollectError` を投げる（そのrepositoryの失敗になる）。続けられるが知らせたいことは `warnings` に入れる（Orcaが動いていない、など。epic-00003 の F-01）。
		4. 想定していない例外（プログラムの誤り）は投げたままにする。`collect_repo` は `CollectError` だけを受け止める。
		"""
		satisfies: ["R-01"]
	}
	"D-02": {
		title: "収集の実行（`collect_repo`）と登録（`COLLECTORS`）"
		text: """
		```python
		# shipcast/collect/base.py
		@dataclass(frozen=True)
		class RepoCollection:
		    repo_id: str
		    day: date
		    events: tuple[Event, ...]    # 確かめて保存に回したEvent（collectorの順、各collectorの返した順）
		    saved: int                   # Store.add_events の戻り値（新しく入った件数）
		    warnings: tuple[str, ...]    # "<collectorのname>: <文>"
		    errors: tuple[str, ...]      # "<collectorのname>: <文>"
		    @property
		    def ok(self) -> bool: return not self.errors

		def collect_repo(store: Store, repo: RepoConfig, day: date, *, tz: tzinfo,
		                 collectors: Sequence[Collector]) -> RepoCollection: ...

		# shipcast/collect/__init__.py
		from shipcast.collect.git import GitCollector
		COLLECTORS: tuple[Collector, ...] = (GitCollector(),)   # 順は git、specdock、orca（iss-00012・00013 が足す）
		```

		`collect_repo` の処理：

		1. `collectors` を順に呼ぶ。`CollectError` は `errors` に `f"{collector.name}: {error}"` を足して次のcollectorへ進む。
		2. 戻り値を確かめる。`CollectResult` でない、Eventでない要素がある、`source != collector.name`、`repo_id != repo.id`、`at` が `day_bounds` の外のEventが1つでもあれば、そのcollectorのEventを全部捨て、`errors` に `f"{collector.name}: 約束に合わないEventを返しました（<理由。最初の1件のIDか型>）"` を足す。警告は残す。
		3. 合ったcollectorの `warnings` を `f"{collector.name}: {warning}"` にして足す。
		4. 全collectorの後に、合ったEventを1回の `store.add_events` で保存する（失敗したcollectorがあっても、ほかのcollectorのEventは保存する。保存は同じIDを無視するので、集め直しても増えない）。Eventが0件でも呼んでよい。
		5. `runs` の表には書かない（iss-00021 が `RepoCollection` から記録する）。`StateError` と SQLite の例外は受け止めず、呼ぶ側へ投げる。

		`COLLECTORS` の `name` は重ならず、どれも `SOURCES` にある（試験で確かめる）。`collect_repo` の `collectors` は必須の引数にし、既定で `COLLECTORS` を読まない（試験で架空のcollectorを渡せるようにし、`base` と `git` の読み込みの循環を避ける）。
		"""
		satisfies: ["R-01"]
	}
	"D-03": {
		title: "`shipcast collect` のコマンド（`shipcast.collect.command`）"
		text: """
		```python
		def configure(parser: argparse.ArgumentParser) -> None:
		    # --repo ID（省くと登録の全部）、--date YYYY-MM-DD（省くと設定の timezone の今日）
		    # --date は date.fromisoformat で読み、読めなければ argparse の誤り（終了コード2、usage）
		    # parser.set_defaults(func=run)
		def run(args: argparse.Namespace) -> int: ...
		```

		`src/shipcast/cli.py` は、`from shipcast.collect import command as collect_command  # isort: skip` の1行（`from shipcast import repo` の行の隣）と、`Command(Entry("collect", "日誌の素材を集める", collect_command.configure), "iss-00011")` への1行の書き換えだけを変える。

		`command.py` は `from shipcast.collect import COLLECTORS` で読み込み、`run` の中でモジュールの名前 `COLLECTORS` を読む（試験が `shipcast.collect.command.COLLECTORS` を架空のcollectorに置き換えられるようにする）。

		`run` の処理と表示（`<day>` は `YYYY-MM-DD`）：

		1. `load_config()`。`ConfigError` なら標準エラーに `shipcast collect: {error}`、終了コード1。
		2. `tz = ZoneInfo(config.timezone)`、`day = args.date or datetime.now(tz).date()`。
		3. 対象：`--repo` があれば、その `id` の1つ。登録になければ標準エラーに 「shipcast collect: 登録されていないrepositoryです: {id}」 と次の行「直し方: `shipcast repo list` で登録済みのidを確かめてください」、終了コード1。登録が0件なら標準エラーに 「shipcast collect: 登録されたrepositoryはありません。`shipcast repo add <path>` で登録できます」、終了コード1。
		4. `Store(config.state_dir)` を開く（`with`）。`StateError` なら標準エラーに `shipcast collect: {error}`、終了コード1。
		5. 対象のrepositoryごとに、設定の順で `collect_repo(store, repo, day, tz=tz, collectors=COLLECTORS)` を呼び、次を示す。
		   - 警告ごとに標準エラーへ `shipcast collect: 警告: {repo.id}: {warning}`
		   - 失敗ごとに標準エラーへ `shipcast collect: 失敗: {repo.id}: {error}`
		   - 標準出力へ `{repo.id} {day}: {len(events)}件を集め、{saved}件を新しく保存しました`（失敗があっても示す）
		6. 1つでも `errors` のあるrepositoryがあれば終了コード1、なければ0（警告だけなら0）。
		"""
		satisfies: ["R-01", "F-02"]
	}
	"D-04": {
		title: "Gitのcollector（`shipcast.collect.git.GitCollector`）の読み方"
		text: """
		```python
		class GitCollector:
		    name = "git"
		    def __init__(self, *, git: str = "git", timeout: float = 60.0, max_merged: int = 200): ...
		    def collect(self, repo: RepoConfig, day: date, tz: tzinfo) -> CollectResult: ...
		```

		Gitの呼び出しは、すべて1つの内部の関数を通す：`subprocess.run([self.git, "--no-optional-locks", "-C", str(repo.path), <subcommand>, ...], capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=self.timeout, env=<下記>, check=False)`。試験が置き換えられるように、モジュールの `subprocess` の `run` を呼ぶ（`subprocess.run` を名前で読み込まない）。

		- 環境：`os.environ` の写しから `GIT_DIR`、`GIT_WORK_TREE`、`GIT_INDEX_FILE`、`GIT_OBJECT_DIRECTORY`、`GIT_ALTERNATE_OBJECT_DIRECTORIES`、`GIT_COMMON_DIR`、`GIT_NAMESPACE` を消し、`GIT_OPTIONAL_LOCKS=0`、`GIT_TERMINAL_PROMPT=0` を足す（呼んだ側の環境で別のrepositoryを読まないため）。
		- 呼ぶsubcommandは `rev-parse`、`log`、`diff-tree` の3つだけ。
		- `FileNotFoundError`（gitがない）、`subprocess.TimeoutExpired`、終了コードが0でない（下の1・2の判定を除く）は `CollectError` にする：`gitのコマンドが見つかりません: {self.git}`、`git {subcommand} が{timeout}秒で終わりませんでした: {path}`、`git {subcommand} が失敗しました: {path}: {標準エラーの最後の空でない行}`。

		手順：

		1. `repo.path.is_dir()` でなければ `CollectError(f"{path}: ディレクトリがありません")`。
		2. `rev-parse --show-toplevel`。終了コードが0でなければ `CollectError(f"{path}: Gitのrepositoryではありません")`。出力のpathを `Path(...).resolve()` にして `repo.path.resolve()` と違えば `CollectError(f"{path}: Gitのrepositoryの最上位ではありません（最上位: {top}）")`（親のrepositoryを読み違えないため）。
		3. refを確かめる。`repo.ref` が `-` で始まれば `CollectError(f"{path}: ref {ref} がありません")`。`rev-parse --verify --quiet --end-of-options <ref>^{commit}` の終了コードが0でなければ同じ誤り。出力のSHA（40桁）を `tip` とし、以後は `tip` だけを読む。
		4. 正本の歴史：`log --first-parent -z --no-show-signature --no-color --format=<FMT> --since=<S> --until=<U> --end-of-options {tip}`。`<S>`・`<U>` は `day_bounds` の両端をUTCに直した `"%Y-%m-%d %H:%M:%S +0000"`。gitの `--since`・`--until` は枝を刈るためだけに使い、各commitの時刻 `committed` を `start <= committed < end` で絞り直す（端の秒の扱いをgitに任せない）。
		5. 各mergeが取り込んだcommit：4で残った親が2つ以上の `M` ごとに、`log -z --no-show-signature --no-color --format=<FMT> --max-count={max_merged + 1} --end-of-options {M} ^{Mの第1の親}` を読み、`M` 自身を除く。`max_merged` 件を超えたら先頭（新しい方）の `max_merged` 件だけにし、警告 `マージ {M[:12]} が取り込んだcommitが{max_merged}件を超えたので、{max_merged}件だけを集めました` を足す。
		6. 変更したファイルの数：commit `C` ごとに、親があれば `diff-tree -r -z --no-commit-id --name-only {Cの第1の親} {C}`、親がなければ `diff-tree -r -z --no-commit-id --name-only --root {C}` を読み、NULで区切った空でない項目を数える（mergeは第1の親との違い、つまり正本に入った変更）。

		`<FMT>` は `%H%x1f%P%x1f%cI%x1f%an%x1f%s%x1f%b`。`-z` でcommitの間がNULになるので、出力をNULで分け、空の項目を捨て、各項目を `\\x1f` で最大5回分ける（本文は最後の項目なので、本文の中の `\\x1f` も残る）。`%P` は空白で分ける（`--first-parent` でも全部の親が出ることを確かめた。git 2.56）。`%cI` は `datetime.fromisoformat` で読む。

		Eventの形（`native_id` はcommitのSHAの全40桁）：

		| 項目 | 正本の歴史のcommit（4） | mergeが取り込んだcommit（5） |
		|---|---|---|
		| `id` | `event_id("git", repo.id, sha)` | 同じ |
		| `kind` | 親が2つ以上なら `merge`、ほかは `commit` | 同じ（そのcommit自身の親の数） |
		| `at` | `%cI` の時刻（元の時差のまま） | 取り込んだmerge `M` の `at` |
		| `title` | `%s`。空なら `（題名のないcommit）` | 同じ |
		| `body` | 下の本文 | 下の本文 |
		| `refs` | `(sha,)` | `(sha, M)` |
		| `actor` | `%an` | 同じ |

		本文は、`%b` の末尾の空白を除いたものに、空でなければ空行を挟んで、次の付記の行を `\\n` でつないで足す。

		- いつも：`変更したファイル: {n}件`
		- 正本の歴史のmergeだけ：`取り込んだcommit: {k}件`（5で集めた件数。打ち切ったときは打ち切った後の件数）
		- 取り込んだcommitだけ：`マージ {M[:12]} で入った（commitの時刻 {%cI}）`

		返すEventの順は、4の古い順に並べ、各mergeの直後にそれが取り込んだcommitを古い順に置く（保存の順は `Store` が時刻とIDで決めるので、試験はIDの集合と各項目で確かめる）。警告は5の打ち切りだけ。
		"""
		satisfies: ["R-02", "R-03", "F-01"]
	}
	"D-05": {
		title: "読むだけであることの確かめ方"
		text: """
		- 実装：D-04 の `--no-optional-locks` と、`rev-parse`・`log`・`diff-tree` だけを使う。`status`・`fetch`・`checkout`・`switch`・`reset`・`update-index`・`gc` などは呼ばない。
		- 試験の継ぎ目：`shipcast.collect.git.subprocess.run` を、元の関数を呼ぶ記録の関数に置き換え、呼んだ引数の全部が `[git, "--no-optional-locks", "-C", str(path), sub, ...]` で `sub` が3つのどれかであることを見る。
		- 試験の観察：収集の前後で、対象のrepositoryの `.git/HEAD` のバイト列、`.git/index` のバイト列と `st_mtime_ns`、`git --no-optional-locks for-each-ref` の出力、`git --no-optional-locks status --porcelain=v1 --untracked-files=all` の出力、作業ツリーの変更済みと未追跡のファイルのバイト列が同じこと。
		"""
		satisfies: ["R-03"]
	}
}

risks: [
	"fast-forward で正本に入ったcommitは、入った時刻の記録がGitにないので、commitの時刻の日に数える。その日を先に集めていれば、そのcommitはどの日にも入らない。GitHubのPRのmerge（merge commit、squash、rebase）では起きない。excludes に書いた",
	"gitの `--since` は、時刻が前後するcommit（時計のずれ）があると、正本の歴史の途中で読むのを早めに止めることがある。正本の歴史では時刻がほぼ単調なので、MVPでは受け入れる",
	"1つのmergeが `max_merged`（200）件を超えるcommitを取り込むと、残りは集めない。警告で知らせる",
	"`Collector.collect` の引数を epic-00003 の D-01 の `(repo, day)` から `(repo, day, tz)` に変えた。iss-00012・iss-00013 の仕様は `(repo, day)` の前提で書かれているので、その仕様を具体化するときに読み替える（申し送り）",
]
