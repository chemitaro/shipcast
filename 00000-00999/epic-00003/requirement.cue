package spec

schema: "specdock/v1"

assurance: {
	level:  "standard"
	reason: "対象のrepositoryを読むだけで変えない。誤っても日誌が欠けるだけで、作り直せる"
}

purpose: "登録したrepositoryの、指定した日の出来事を、Git・SpecDock・Orcaから集め、Eventとして状態に保存する。"

requirements: {
	"R-01": {
		title: "Gitの、その日に正本のbranchに入ったcommitとmergeを集める"
		acceptance: ["`shipcast collect --repo <id> --date <日付>` で、その日のcommitがEventとして保存される", "作業用のworktreeとbranchの未統合のcommitは集めない"]
	}
	"R-02": {
		title: "SpecDockの、その日のScopeとtodoの変化を集める"
		acceptance: ["その日に作られた・閉じたScope、開いている本人待ちのtodoが、Eventとして保存される"]
	}
	"R-03": {
		title: "Orcaの、そのrepositoryでのその日の会話の記録を集める（任意）"
		acceptance: ["Orcaが動いていれば、本人とエージェントの発言がEventとして保存される"]
	}
	"R-04": {
		title: "集める処理は、対象のrepositoryを書き換えない"
		acceptance: ["`git fetch`、checkout、indexを書き換える操作を使わない（`--no-optional-locks` で読む）"]
	}
}

failures: {
	"F-01": {title: "Orcaが動いていない・CLIがない・読めないときは、警告を残し、Orcaなしで続ける"}
	"F-02": {title: "GitかSpecDockが読めないときは、そのrepositoryの収集を失敗として記録し、ほかのrepositoryは続ける"}
}
