package spec

design: {
	"D-01": {
		title: "`shipcast.collect.specdock`"
		text: """
		iss-00011 の `Collector` の約束に従う。`subprocess` で次の3つのJSONを読み、時刻で絞る。

		1. `spec-dock scope list --json --project <path>`：ScopeのID、種類、題名、親、`number`、`url`
		2. `gh issue list --repo <owner/name> --state all --limit 500 --json number,title,state,createdAt,closedAt,url`：Issueの番号ごとの作成と終了の時刻（読むだけ）
		3. `spec-dock todo list --status all --json --project <path>`：todoの状態と時刻

		Scopeは `number` でIssueとつなぎ、その日に `createdAt` があれば scope_opened、`closedAt` があれば scope_closed にする。題名、ID、URL、親を Event の title・refs・body に入れる。`owner/name` は `scope list` の `github_ref` から取る。
		"""
		satisfies: ["R-01", "R-02", "R-03", "F-01"]
	}
}
