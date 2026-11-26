package spec

schema: "specdock/v1"

assurance: {
	level:  "standard"
	reason: "夜の処理の入口で、全repositoryの収集・分析・執筆を順に動かし、実行の記録を残す。誤ると毎晩の日誌が欠け、重ねて動くと状態が乱れるが、手元の処理だけで、PRを戻して同じ日を実行し直せば回復できる"
}

purpose: "`shipcast run` で、登録した全repositoryの日誌を一度に作る。"

requirements: {
	"R-01": {
		title: "全repository（または `--repo`）の、`--date`（既定は前日）の日誌を、collect → analyze → write で作る"
		acceptance: ["`--date` を省くと、設定の timezone での前日になる", "fake の経路で、登録した2つのrepositoryの日誌ができる"]
	}
	"R-02": {
		title: "repositoryごとの成功と失敗を実行の記録に残し、1つの失敗でほかを止めない"
		acceptance: ["`runs` の表に、repositoryごとの開始・終了・結果・誤りが入る", "全部が成功なら終了コード0、1つでも失敗なら1"]
	}
	"R-03": {
		title: "同じ日の再実行で重複しない"
		acceptance: ["2回目の実行で、Eventの件数が増えず、日誌のファイルが置き換わる"]
	}
}

failures: {
	"F-01": {title: "前の実行が動いているときは、重ねずに終わる"}
	"F-02": {title: "TCCで読めないときは、直し方を記録に添える"}
}
