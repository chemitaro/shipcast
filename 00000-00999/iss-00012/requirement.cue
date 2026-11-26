package spec

schema: "specdock/v1"

assurance: {
	level:  "light"
	reason: "手元だけの新しい道具の一部で、PRを戻せば元に戻る"
}

purpose: "SpecDockのScopeとtodoの、その日の変化をEventにする。"

requirements: {
	"R-01": {title: "その日に作られた・閉じたScopeを、Event（scope_opened、scope_closed）にする"}
	"R-02": {title: "開いている本人待ちのtodoを、Event（todo_open）にする。その日に閉じたtodoは todo_done にする"}
	"R-03": {title: "SpecDockのCLIの機械向けの出力だけを読む"}
}
