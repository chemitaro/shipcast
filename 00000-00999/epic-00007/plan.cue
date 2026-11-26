package spec

goal: "毎晩3時に、登録した全repositoryの前日の日誌が、本人の手を借りずにできるようにする（登録の1回だけは本人が行う）。"

slices: {
	"iss-00021": {covers: ["R-01", "R-02", "F-01", "F-02"], text: "shipcast run（standard）"}
	"iss-00022": {covers: ["R-03"], text: "launchdの登録（standard）。`launchctl` の読み込みは本人が行う", after: ["iss-00021"]}
}

verification: "`shipcast run --date <今日>` を2回動かして重複しないこと。plistを作り、`launchctl` の読み込みは本人が行う。"
