package spec

goals: [
	"出所ごとのcollectorを、1つの共通の約束（`shipcast.collect.base`）に揃え、後から出所を足せるようにする",
	"どの出所も、機械向けの出力を読むだけにし、対象のrepositoryと道具の状態を変えない",
]

design: {
	"D-01": {
		title: "collectorの共通の約束（`shipcast.collect.base`）"
		text: """
		`Collector` は `name: str` と `collect(repo: RepoConfig, day: date) -> CollectResult`（`events`、`warnings`）を持つ。登録は `shipcast.collect.COLLECTORS`（git、specdock、orca の順）。`shipcast collect` は全部を呼び、結果を `Store.add_events` で保存する。

		iss-00011 がこの約束とGitのcollectorを作り、iss-00012（SpecDock）と iss-00013（Orca）は、この約束に従うcollectorを1つずつ足す。そのため iss-00012 は iss-00011 の後に始める。
		"""
		satisfies: ["R-01", "R-02", "R-03"]
	}
	"D-02": {
		title:     "Gitの読み方"
		text:      "`git --no-optional-locks -C <path> log <ref> --since <0時> --until <24時> --date=iso-strict --format=...`。mergeは `%P` の親の数で見分け、題名・本文・作者・SHA・変更したファイルの数を取る。"
		satisfies: ["R-01", "R-04", "F-02"]
	}
	"D-03": {
		title: "SpecDockの読み方"
		text: """
		機械向けの出力だけを読み、カタログの内部のファイルの形は解釈しない。`spec-dock scope list --json` の出力には時刻がないので、ScopeのGitHubのIssueの時刻を `gh` で読むだけで併用する（本人の決定 23）。

		| 読むもの | コマンド | 使う項目 |
		|---|---|---|
		| Scopeの一覧 | `spec-dock scope list --json --project <path>` | `id`、`kind`、`title`、`parent_id`、`number`、`url`、`github_ref` |
		| Scopeの時刻 | `gh issue list --repo <owner/name> --state all --limit 500 --json number,title,state,createdAt,closedAt,url` | `number`、`createdAt`、`closedAt` |
		| todo | `spec-dock todo list --status all --json --project <path>` | 状態と時刻（項目の名前は実装の最初に実際の出力で確かめる） |

		Scopeは `number` でIssueとつなぎ、その日の `createdAt` は scope_opened、`closedAt` は scope_closed にする。`gh` が使えないときは、Scopeの出来事を警告にしてtodoだけを集める。
		"""
		satisfies: ["R-02", "R-04", "F-02"]
	}
	"D-04": {
		title: "Orcaの読み方（任意）"
		text: """
		`orca search` は全文の検索で、問い合わせの語が要り、その日の会話を漏れなく並べる用途に向かないので使わない。確かめた2つのコマンドを読む。

		1. `orca agent list --json`：`result.agents[]` の `orcaSessionId`、`worktreeId`（`<repo-id>::<path>`）、`title`、`updatedAt`（ミリ秒）。`worktreeId` のpathが登録したrepositoryのpath、またはその配下のworktreeで、`updatedAt` がその日のものを選ぶ。
		2. `orca agent read <orcaSessionId> --limit 100 --json`：`result.entries[]` のうち `kind` が `message` のもの（`role`、`text`）。道具の呼び出し（`kind` が `tool`）は入れない。

		発言には時刻がないので、その日の判定は会話の `updatedAt` で行う。読めないときは `warnings` に理由を入れて空を返す。
		"""
		satisfies: ["R-03", "F-01"]
	}
}

risks: [
	"Orca CLIの出力の形は版で変わりうる。項目の名前は見本（tests/fixtures、架空の値）に固定し、変われば試験で気づく",
	"`gh issue list` の `--limit 500` を超えるIssueのrepositoryでは古いScopeの時刻が取れない。MVPでは対象外とし、超えたら警告を出す",
]
