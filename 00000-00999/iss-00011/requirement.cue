package spec

schema: "specdock/v1"

assurance: {
	level:  "light"
	reason: "手元だけの新しい道具の一部で、PRを戻せば元に戻る"
}

purpose: "collectorの約束と `shipcast collect` を作り、Gitの出来事を集める。"

requirements: {
	"R-01": {title: "collectorの約束（epic-00003 の D-01）と `shipcast collect --repo --date` がある"}
	"R-02": {title: "その日に正本のbranch（設定の ref）に入ったcommitとmergeを、Eventにする"}
	"R-03": {title: "読むだけの操作で集める（fetch、checkout、indexの書換えをしない）"}
}

failures: {
	"F-01": {title: "pathがGitでない・refがないときは、そのrepositoryを失敗として記録する"}
}
