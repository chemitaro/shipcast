package spec

schema: "specdock/v1"

assurance: {
	level:  "light"
	reason: "手元だけの新しい道具の一部で、PRを戻せば元に戻る"
}

purpose: "設定ファイルを読み、対象のrepositoryを登録・一覧できるようにする。"

requirements: {
	"R-01": {
		title: "設定ファイル（epic-00002 の D-02 の形）を読み、型のついた設定にする"
		acceptance: ["`~` を展開し、`SHIPCAST_CONFIG` があればその場所を読む"]
	}
	"R-02": {
		title: "`shipcast repo add <path> [--id] [--title]` で、repositoryを設定に足す"
		acceptance: ["`spec-dock/workspace.json` がないrepositoryは足さずに止まる", "同じidは二重に足さない"]
	}
	"R-03": {title: "`shipcast repo list` で、登録したrepositoryを示す"}
	"R-04": {title: "設定ファイルがないとき、`shipcast repo add` は既定の内容で作ってから足す"}
}

failures: {
	"F-01": {title: "設定ファイルが壊れているときは、行と直し方を示して止まる"}
}
