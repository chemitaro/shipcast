package spec

schema: "specdock/v1"

assurance: {
	level:  "standard"
	reason: "本人のmacOSのlaunchdに定期の実行を登録するplistを作る。誤ると毎晩の処理が動かない・ログが残らないが、plistを外せば元に戻り、読み込み（`launchctl`）は本人が行う"
}

purpose: "`shipcast schedule install|uninstall` で、毎日3時のlaunchdの登録を作り、外せるようにする。"

requirements: {
	"R-01": {
		title: "`schedule install` が、epic-00007 の D-03 のplistを書き、読み込みのcommandを示す"
		acceptance: ["plistに Hour 3 Minute 0、`shipcast` の絶対path、`run`、ログの置き場が入る", "`--load` がなければ `launchctl` を呼ばず、本人が打つcommandを示すだけ"]
	}
	"R-02": {
		title: "`schedule uninstall` が、plistを外す"
		acceptance: ["plistのファイルが消え、外すcommand（`launchctl bootout`）を示す", "plistがないときも、誤りにせず終わる"]
	}
	"R-03": {
		title: "READMEに、`uv tool install` と、外付けvolumeのときの許可の付け方を書く"
		acceptance: ["READMEに、導入・登録・外し方・フルディスクアクセスの付け方の節がある"]
	}
}
