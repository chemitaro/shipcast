package spec

schema: "specdock/v1"

assurance: {
	level:  "standard"
	reason: "本人のmacOSに定期の実行を登録し、毎晩の処理の入口を作る。誤ると日誌が欠けるが、手元の処理だけで、登録を外せば元に戻る"
}

purpose: "毎晩3時に、登録した全repositoryの前日の日誌を自動で作る。"

requirements: {
	"R-01": {
		title: "`shipcast run` が、登録した全repositoryの指定した日（既定は前日）の日誌を作る"
		acceptance: ["1つのrepositoryの失敗で、ほかのrepositoryを止めない", "実行の記録（開始、終了、結果、誤り）が状態に残る"]
	}
	"R-02": {
		title: "同じ日を何度実行しても、同じ日の日誌を作り直すだけで、重複しない"
		acceptance: ["2回目の実行で、Eventの件数が増えず、日誌のファイルが置き換わる"]
	}
	"R-03": {
		title: "`shipcast schedule install` で、毎日3時のlaunchdの登録ができ、`uninstall` で外せる"
		acceptance: ["`~/Library/LaunchAgents/` にplistが置かれ、ログは状態の置き場の `logs/` に出る"]
	}
}

failures: {
	"F-01": {title: "前の実行がまだ動いているときは、重ねて動かさずに終わる（lockのファイル）"}
	"F-02": {title: "外付けvolumeのrepositoryがmacOSの許可（TCC）で読めないときは、その理由と直し方を実行の記録に残す"}
}
