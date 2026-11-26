package spec

schema: "specdock/v1"

assurance: {
	level:  "light"
	reason: "手元だけの新しい道具の一部で、PRを戻せば元に戻る"
}

purpose: "Orcaの会話の記録を、任意の連携として集める。本人はOrcaを使うので、基本は動く前提で作る。"

requirements: {
	"R-01": {title: "そのrepositoryのpathでの、その日の会話（本人とエージェントの発言）を、Event（conversation）にする"}
	"R-02": {title: "設定の `orca = false` のrepositoryでは集めない"}
}

failures: {
	"F-01": {title: "Orcaが動いていない・CLIがない・読めないときは、警告を残して空を返す"}
}
