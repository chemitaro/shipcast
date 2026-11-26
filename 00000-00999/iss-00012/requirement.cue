package spec

schema: "specdock/v1"

assurance: {
	level:  "light"
	reason: "iss-00011 の約束に、SpecDockの出来事を読むcollectorを1つ足すだけで、影響はこのcollectorに閉じる。読むだけで対象を変えず、誤っても日誌のSpecDockの部分が欠けるだけで、PRを戻せば元に戻る"
}

purpose: "SpecDockのScopeとtodoの、その日の変化をEventにする。"

requirements: {
	"R-01": {
		title: "その日に作られた・閉じたScopeを、Event（scope_opened、scope_closed）にする"
		text:  "時刻は、ScopeのGitHubのIssueの `createdAt`・`closedAt` で決める（`spec-dock scope list` の出力には時刻がないため）。"
	}
	"R-02": {title: "開いている本人待ちのtodoを、Event（todo_open）にする。その日に閉じたtodoは todo_done にする"}
	"R-03": {
		title: "読むだけの機械向けの出力だけを使う"
		text:  "`spec-dock scope list --json`、`spec-dock todo list --status all --json`、`gh issue list --state all --json number,title,state,createdAt,closedAt,url`。カタログの内部のファイルは解釈しない。"
	}
}

failures: {
	"F-01": {title: "`gh` が使えない・認証がないときは、Scopeの出来事を警告にして空を返し、todoの出来事だけを集める"}
}
