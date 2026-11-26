package spec

schema: "specdock/v1"

assurance: {
	level:  "standard"
	reason: "ほかの全Epicが使う約束を決める。手元だけの新しい道具で、作り直せる"
}

purpose: "ほかのEpicが同時に作業できるように、CLI・設定・データの形・状態の置き場の約束を、最初に動く形で決める。"

requirements: {
	"R-01": {
		title: "`shipcast` のコマンドが動き、下位のコマンドの骨組みがある"
		text:  "下位のコマンド：`repo add|list`、`collect`、`write`、`run`、`serve`、`draft`、`schedule`。中身は各Epicが作る。"
		acceptance: ["`uv run shipcast --help` が下位のコマンドを示す", "`uv run pytest -q` が通る"]
	}
	"R-02": {
		title: "設定ファイルで、対象のrepositoryとモデルの経路と置き場を決められる"
		acceptance: [
			"`shipcast repo add <path>` で、SpecDockを使うrepositoryが設定に加わる",
			"SpecDockを使っていない（`spec-dock/workspace.json` がない）repositoryは加えずに止まる",
		]
	}
	"R-03": {
		title: "出来事（Event）・話題（Story）・日誌（Entry）のデータの形が、コードの型として1か所にある"
		acceptance: ["各Epicが同じ型を読み込んで使う", "型には `schema = 1` の版がある"]
	}
	"R-04": {
		title: "状態（出来事、話題、実行の記録、ネタポイント）がrepositoryの外のSQLiteに残る"
		acceptance: ["同じ出来事を二度保存しても、1件のまま（安定したIDで重複を除く）"]
	}
}

failures: {
	"F-01": {title: "設定ファイルがない・壊れているときは、直し方を示して止まる"}
}
