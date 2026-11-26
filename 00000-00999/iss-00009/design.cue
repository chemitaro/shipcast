package spec

design: {
	"D-01": {title: "`shipcast.config`：読み込みと既定値", text: "`load_config(path=None) -> Config`。`tomllib` で読み、既定値を補う。`Config.repos` は `RepoConfig` の一覧。", satisfies: ["R-01", "F-01"]}
	"D-02": {title: "`repo add` と `repo list`", text: "既存のファイルの末尾に `[[repos]]` の塊を文字列で足す（既存の行とコメントを保つ）。ないときは既定の内容で新しく作る。", satisfies: ["R-02", "R-03", "R-04"]}
}
