package spec

design: {
	"D-01": {title: "`shipcast run`", text: "`--date`（既定は前日）、`--repo`（既定は全部）。repositoryごとに collect → analyze → write を呼び、例外は記録して次へ。全部が成功なら終了コード0、1つでも失敗なら1。", satisfies: ["R-01", "R-02"]}
	"D-02": {title: "lock", text: "状態の置き場の `run.lock` を `fcntl.flock` で取る。取れなければ記録して終了コード0で終える。", satisfies: ["F-01"]}
	"D-03": {title: "launchdの登録", text: "`com.shipcast.nightly.plist`。`StartCalendarInterval` は Hour 3 Minute 0。`ProgramArguments` は、`uv tool install` で入れた `shipcast` の絶対path（worktreeのcheckoutからは動かさない）と `run`。標準出力と誤りは `logs/`。登録は本人の環境への変更なので、本人が実行する。", satisfies: ["R-03"]}
	"D-04": {title: "TCCの失敗の見分け", text: "Gitの誤りの文に `Operation not permitted` があれば、許可の付け方（フルディスクアクセス）を記録に添える。", satisfies: ["F-02"]}
}
