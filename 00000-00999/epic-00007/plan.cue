package spec

slices: {
	"iss-00021": {covers: ["R-01", "R-02", "F-01", "F-02"], text: "shipcast run"}
	"iss-00022": {covers: ["R-03"], text: "launchdの登録", after: ["iss-00021"]}
}

verification: "`shipcast run --date <今日>` を2回動かして重複しないこと。plistを作り、`launchctl` の読み込みは本人が行う。"
