package spec

design: {
	"D-01": {
		title: "`shipcast.collect.orca`"
		text: """
		iss-00011 の `Collector` の約束に従う。epic-00003 の D-04 の読み方。

		1. `orca agent list --json` の `result.agents` から、`worktreeId`（`<repo-id>::<path>` の形）のpathが登録したrepositoryのpath、またはその配下のworktreeのものを選び、`updatedAt`（ミリ秒）がその日のものに絞る。
		2. 選んだ会話ごとに `orca agent read <orcaSessionId> --limit 100 --json` を呼び、`result.entries` のうち `kind` が `message` のもの（`role` と `text`）だけを、順につなぐ。道具の呼び出しの行（`kind` が `tool`）は入れない。
		3. 1つの会話を1件のEvent（kind `conversation`、`refs` に `orcaSessionId`、`title` に会話の題名）にする。

		発言には時刻がないので、その日の判定は会話の `updatedAt` で行う。項目の名前は実装の最初に実際の出力で確かめ、架空の値に置き換えた見本を置く。
		"""
		satisfies: ["R-01", "R-02", "F-01"]
	}
}
