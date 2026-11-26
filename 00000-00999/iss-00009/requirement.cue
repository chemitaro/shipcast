package spec

schema: "specdock/v1"

assurance: {
	level:  "standard"
	reason: "設定ファイルの形と `repo add` の書き方は、ほかの全Issueが読む共通の約束になる。誤ると本人の手元の設定を壊しうるが、ファイルは手元だけにあり、PRを戻して設定を書き直せば回復できる"
}

purpose: "設定ファイルを読み、対象のrepositoryを登録・一覧できるようにする。"

requirements: {
	"R-01": {
		title: "設定ファイル（epic-00002 の D-02 の形）を読み、型のついた設定にする"
		acceptance: [
			"`~` を展開し、`SHIPCAST_CONFIG` があればその場所を読む",
			"書かれていない項目には既定値（epic-00002 の D-02）が入る",
		]
	}
	"R-02": {
		title: "`shipcast repo add <path> [--id] [--title]` で、repositoryを設定に足す"
		acceptance: ["`spec-dock/workspace.json` がないrepositoryは足さずに止まる", "同じidは二重に足さない"]
	}
	"R-03": {
		title: "`shipcast repo list` で、登録したrepositoryを示す"
		acceptance: ["登録した順に、id・title・path・ref が1行ずつ出る"]
	}
	"R-04": {
		title: "設定ファイルがないとき、`shipcast repo add` は既定の内容で作ってから足す"
		acceptance: ["作ったファイルを `load_config` で読み直すと、足したrepositoryが1件ある"]
	}
}

failures: {
	"F-01": {title: "設定ファイルが壊れているときは、行と直し方を示して止まる"}
}
