package spec

schema: "specdock/v1"

assurance: {
	level:  "light"
	reason: "手元だけの新しい道具の一部で、PRを戻せば元に戻る"
}

purpose: "`shipcast run` で、登録した全repositoryの日誌を一度に作る。"

requirements: {
	"R-01": {title: "全repository（または `--repo`）の、`--date`（既定は前日）の日誌を、collect → analyze → write で作る"}
	"R-02": {title: "repositoryごとの成功と失敗を実行の記録に残し、1つの失敗でほかを止めない"}
	"R-03": {title: "同じ日の再実行で重複しない"}
}

failures: {
	"F-01": {title: "前の実行が動いているときは、重ねずに終わる"}
	"F-02": {title: "TCCで読めないときは、直し方を記録に添える"}
}
