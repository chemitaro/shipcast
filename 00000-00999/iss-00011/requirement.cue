package spec

schema: "specdock/v1"

assurance: {
	level:  "standard"
	reason: "collectorの共通の約束（`shipcast.collect.base`）は、SpecDockとOrcaの収集（iss-00012、iss-00013）が使う境界になる。対象のrepositoryを読むだけで書き換えず、誤っても日誌が欠けるだけで、PRを戻して集め直せば回復できる"
}

purpose: "collectorの共通の約束と `shipcast collect` を作り、Gitの出来事を集める。SpecDockとOrcaのcollectorは、この約束に従って後から足す。"

requirements: {
	"R-01": {
		title: "collectorの約束（epic-00003 の D-01）と `shipcast collect --repo --date` がある"
		acceptance: [
			"`shipcast.collect.base` に `Collector`、`CollectResult`、登録の `COLLECTORS` がある",
			"`shipcast collect` が登録された全collectorを呼び、Eventを `Store.add_events` で保存し、件数と警告を示す",
		]
	}
	"R-02": {
		title: "その日に正本のbranch（設定の ref）に入ったcommitとmergeを、Eventにする"
		acceptance: [
			"その日（設定の timezone の0時〜24時）のcommitが kind `commit`、親が2つ以上のものが kind `merge` になる",
			"作業用のbranchの未統合のcommitは入らない",
		]
	}
	"R-03": {
		title: "読むだけの操作で集める（fetch、checkout、indexの書換えをしない）"
		acceptance: ["収集の前後で、対象のrepositoryの `HEAD`、index、作業ツリーの状態が変わらない", "Gitは `--no-optional-locks` を付けて呼ぶ"]
	}
}

failures: {
	"F-01": {title: "pathがGitでない・refがないときは、そのrepositoryを失敗として記録する"}
}
