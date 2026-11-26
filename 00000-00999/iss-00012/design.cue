package spec

goals: [
	"iss-00011 の `Collector` の約束に従うクラスを1つ書き、`COLLECTORS` に1行足すだけで、SpecDockの出来事が `shipcast collect` に加わる",
	"SpecDockとGitHubの機械向けの出力を読むだけにし、カタログの内部のファイルの形に依らない",
	"`gh` がなくても、todoの出来事は集まる",
	"試験は見本のJSONだけで行い、本物の `spec-dock`・`gh` とネットワークを使わない",
]

current: "`shipcast.collect.COLLECTORS` は `(GitCollector(),)` だけ。SpecDockの出来事は集めない。"
target:  "`shipcast collect` が、SpecDockを使うrepositoryで、その日に作られた・閉じたScopeと、その日に登録された・完了したtodoを、`source` が `specdock` のEventとして保存する。"

design: {
	"D-01": {
		title: "`shipcast.collect.specdock.SpecDockCollector`"
		text: """
		```python
		class SpecDockCollector:
		    name = "specdock"
		    def __init__(self, *, spec_dock: str = "spec-dock", gh: str = "gh",
		                 timeout: float = 60.0, issue_limit: int = 500): ...
		    def collect(self, repo: RepoConfig, day: date, tz: tzinfo) -> CollectResult: ...
		```

		iss-00011 の `Collector` の約束（`shipcast.collect.base` の docstring）に従う：読むだけにする、返すEventは `source == "specdock"`・`repo_id == repo.id`・`day_bounds(day, tz)` の `[start, end)` の中、`id` は `event_id("specdock", repo.id, <native_id>)`、読めなければ `CollectError`、続けられることは `warnings`。

		`shipcast/collect/__init__.py` は `COLLECTORS: tuple[Collector, ...] = (GitCollector(), SpecDockCollector())` にする（順は git、specdock。iss-00013 が orca を足す）。

		外部のコマンドは、すべて1つの内部の関数を通す：`subprocess.run(argv, capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=self.timeout, env=<下記>, check=False)`。試験が置き換えられるように、モジュールの `subprocess` の `run` を呼ぶ（`from subprocess import run` にしない）。環境は `os.environ` の写しに `GH_PROMPT_DISABLED=1`、`GH_NO_UPDATE_NOTIFIER=1`、`NO_COLOR=1` を足したもの（問い合わせの画面で止まらない、色の符号を入れない）。`cwd` は指定しない（`spec-dock` は `--project`、`gh` は `--repo` で対象を決める）。
		"""
		satisfies: ["R-01", "R-02", "R-03"]
	}
	"D-02": {
		title: "読むもの（3つのコマンドと、使う項目）"
		text: """
		呼ぶのは次の3つの形だけ（`<path>` は `str(repo.path)`）。2026-11-26 に `spec-dock` 0.9.10・`gh` 2.103.3 の実際の出力で項目を確かめた。

		| # | argv | 使う項目 |
		|---|---|---|
		| 1 | `[spec_dock, "scope", "list", "--offline", "--json", "--project", <path>]` | 外側 `status`、`error.code`・`error.message`。`data.result.items[]` の `id`、`kind`、`title`、`parent_id`、`backend`、`github_ref`（`gh:<owner>/<name>#<number>`）、`number`、`url`、`state_reason` |
		| 2 | `[spec_dock, "todo", "list", "--status", "all", "--offline", "--json", "--project", <path>]` | 外側は1と同じ。`data.result.repositories[]` の `repository`・`status`・`problem`。`data.result.items[].todo` の `id`、`title`、`kind`、`status`（`open`、`snoozed`、`done`、`cancelled`）、`created_at`、`due`、`origin.by`、`scopes.related`、`resolution`（`null` か `at`・`by`・`choice`・`record` を持つ物） |
		| 3 | `[gh, "issue", "list", "--repo", "<owner>/<name>", "--state", "all", "--limit", str(issue_limit), "--json", "number,title,state,createdAt,closedAt,url"]` | 配列の各要素の `number`、`state`（`OPEN`、`CLOSED`）、`createdAt`、`closedAt`（`null` か時刻）、`url` |

		`spec-dock` の出力は、成功でも失敗でも標準出力に1つのJSONの封筒（`schema_version` `specdock.cli/v2`）を出す。時刻は `2026-11-26T11:36:14Z` の形で、`datetime.fromisoformat` で読む（Python 3.12 は `Z` を読める）。`--offline` は、`spec-dock` がGitHubに問い合わせず、手元の保存した観測を読むようにする（SpecDockの手元のキャッシュを新しくしない。道具の状態を変えないため。使う項目のID・題名・親・番号はカタログにあり、時刻は3の `gh` で取るので、観測が古くても困らない）。`todo` の `subtasks` と `history` は読まない。カタログの中のファイル（`todos/*.json` など）は開かない。
		"""
		satisfies: ["R-03"]
	}
	"D-03": {
		title: "手順とEventの作り方"
		text: """
		`start, end = day_bounds(day, tz)`。時刻の比較は `start <= at < end`（aware の datetime どうし）。

		1. `repo.path / "spec-dock" / "workspace.json"` が普通のファイルでなければ、何も呼ばずに `CollectResult()` を返す（SpecDockを使わないrepository。中身は読まない）。
		2. 1のコマンド（scope list）を読む。D-04 の誤りは `CollectError`。
		3. 2のコマンド（todo list）を読む。D-04 の誤りは `CollectError`。`repositories[]` の `status` が `ok` でない項目ごとに、警告 `todoのカタログを読めません: {repository}: {problem}` を足す。
		4. Scope：`backend == "github"` で、`github_ref` が正規表現 `^gh:([^/#\\s]+/[^/#\\s]+)#([0-9]+)$` に合い、`number` が int の項目を、`<owner>/<name>` ごとに分ける（ほかの項目は飛ばす）。`<owner>/<name>` の辞書順に、3のコマンド（gh issue list）を1回ずつ読む。D-04 の `gh` の誤りは、その `<owner>/<name>` の分を飛ばし警告にする（F-01）。返った件数が `issue_limit` 以上なら、警告 `{owner/name} のIssueが{issue_limit}件以上あるので、古いScopeの時刻を読めないことがあります` を足す。Issueを `number` で引き、見つからないScopeは飛ばす。
		   - `createdAt` がその日 → kind `scope_opened`、`at` は `createdAt`、native_id `scope:{id}:opened`
		   - `state == "CLOSED"` で `closedAt` がその日 → kind `scope_closed`、`at` は `closedAt`、native_id `scope:{id}:closed`
		5. todo：`items[].todo` ごとに（サブタスクは見ない）。
		   - `created_at` がその日 → kind `todo_open`、`at` は `created_at`、native_id `todo:{id}:open`（今の `status` によらない）
		   - `status == "done"` で `resolution` が物で `resolution.at` がその日 → kind `todo_done`、`at` は `resolution.at`、native_id `todo:{id}:done`
		   - `cancelled` の取消しは出さない（登録がその日なら `todo_open` は出す）

		Eventの形（`actor` はどれも空。`body` は下の行を `\\n` でつなぐ。値が空・`null` の行は書かない）：

		| kind | `title` | `refs` | `body` の行 |
		|---|---|---|---|
		| `scope_opened` | Scopeの `title` | `(id, url)` | `Scope: {id}（{kind}）`、`親: {parent_id}`、`URL: {url}` |
		| `scope_closed` | 同じ | 同じ | 上の3行と `閉じた理由: {state_reason}` |
		| `todo_open` | todoの `title` | `(id, *scopes.related)` | `todo: {id}（{kind}）`、`今の状態: {status}`、`期限: {due}`、`関連するScope: {related を "、" でつなぐ}`、`登録した側: {origin.by}` |
		| `todo_done` | 同じ | 同じ | `todo: {id}（{kind}）`、`完了した側: {resolution.by}`、`選んだ選択肢: {resolution.choice}`、`記録: {resolution.record}`、`関連するScope: …` |

		Scopeの `url` が空なら、Issueの `url` を使う。`title` が空の文字列なら、`（題名のないScope）`・`（題名のないtodo）` にする（`Event` は空の `title` を許さず、`ModelError` は `collect_repo` が受け止めないため）。返すEventの順は、Scope（`<owner>/<name>` の順、その中は `scope list` の順、各Scopeで opened・closed の順）、次にtodo（`todo list` の順、各todoで open・done の順）。保存の順は `Store` が決めるので、試験はIDの集合と各項目で確かめる。
		"""
		satisfies: ["R-01", "R-02"]
	}
	"D-04": {
		title: "誤りと警告"
		text: """
		`spec-dock`（D-02 の1・2。`<sub>` は `scope list` か `todo list`）は `CollectError`（F-02）：

		- `FileNotFoundError` → `spec-dockのコマンドが見つかりません: {self.spec_dock}`
		- `subprocess.TimeoutExpired` → `spec-dock {sub} が{timeout}秒で終わりませんでした: {path}`
		- 終了コードが0でない → `spec-dock {sub} が失敗しました: {path}: {理由}`。`{理由}` は、標準出力がJSONの物で `error` が物なら `{error.code}: {error.message の最初の空でない行}`、そうでなければ標準エラーの最後の空でない行（空なら `終了コード {n}`）
		- 終了コードが0で、標準出力がJSONの物として読めない → `spec-dock {sub} の出力をJSONとして読めません: {path}`
		- 終了コードが0で、封筒の `status` が `succeeded` でない → 終了コードが0でないときと同じ文
		（検査はこの順に行う）
		- `data.result.items` が配列でない、または使う項目の型が違う（`id`・`title`・`kind`・`status`・`created_at` が文字列でない、時刻が読めない、`todo` が物でない、など） → `spec-dock {sub} の出力の形が想定と違います: {path}: {項目の名前}`

		`gh`（D-02 の3）は警告にし、その `<owner>/<name>` のScopeの出来事を出さない（F-01）。文は `gh issue list を読めませんでした（{owner/name}）: {理由}。Scopeの作成と終了は集めていません`。`{理由}` は次のどれか：

		- `FileNotFoundError` → `ghのコマンドが見つかりません: {self.gh}`
		- `TimeoutExpired` → `{timeout}秒で終わりませんでした`
		- 終了コードが0でない → 標準エラーの最後の空でない行（認証がないときもここ）
		- 配列として読めない、要素が物でない、`number` が int でない、`createdAt` が読めない、`closedAt` が `null` でも読める時刻でもない → `出力の形が想定と違います`

		どの場合も、todoの出来事は返す。
		"""
		satisfies: ["F-01", "F-02"]
	}
	"D-05": {
		title: "試験の継ぎ目と見本"
		text: """
		- 見本：`tests/fixtures/specdock/scope-list.json`、`todo-list.json`、`gh-issue-list.json`。D-02 の実際の出力の形（項目の名前・入れ子・封筒）を保ち、値は架空にする（repository `github.com/example-org/demo-app`、`github_ref` `gh:example-org/demo-app#<n>`、URL `https://github.com/example-org/demo-app/issues/<n>`、架空の題名・本文）。手元の実際の出力の値（題名、本文、path、repository名）を写さない。
		- 継ぎ目：`shipcast.collect.specdock.subprocess.run` を、argv を記録し、argv に応じて見本の文字列（と終了コード・標準エラー）を返す偽物に置き換える（`monkeypatch.setattr`）。失敗は、偽物が `FileNotFoundError`・`subprocess.TimeoutExpired` を投げる、終了コードを0以外にする、壊れたJSONを返す、で作る。
		- repositoryは `tmp_path` に作り、`spec-dock/workspace.json`（中身は `{}` でよい）を置く。`RepoConfig(id="demo", path=tmp_path, ref="main", title="demo", orca=False)`。日は 2026-11-26、tz は `ZoneInfo("Asia/Tokyo")`（その日は UTC の 2026-11-25T15:00:00Z から 2026-11-26T15:00:00Z の前まで）。
		"""
		satisfies: ["R-01", "R-02", "R-03", "F-01", "F-02"]
	}
}

risks: [
	"`spec-dock` と `gh` のJSONの形は版で変わりうる。使う項目を見本に固定し、変われば `出力の形が想定と違います` の誤りか警告で気づく",
	"`gh issue list --limit 500` を超えるIssueのrepositoryでは、古いScopeの時刻が取れない。警告を出す（epic-00003 の risks）",
	"`--offline` で読むので、SpecDockの手元の観測が古いと、Scopeの `state_reason`（本文の `閉じた理由`）が古いことがある。Scopeの作成と終了の判定は `gh` の時刻で行うので、Eventの有無は変わらない",
	"一度閉じて再び開いたIssueは、`gh` の `state` が `OPEN` になるので、その日に閉じていても `scope_closed` を出さない",
]
