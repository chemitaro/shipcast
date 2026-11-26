package spec

design: {
	"D-01": {
		title:     "collectorの約束"
		text:      "`Collector` は `collect(repo: RepoConfig, day: date) -> CollectResult`（`events`、`warnings`）を持つ。登録は `shipcast.collect.COLLECTORS`（git、specdock、orca）。`shipcast collect` は全部を呼び、結果を `Store.add_events` で保存する。"
		satisfies: ["R-01", "R-02", "R-03"]
	}
	"D-02": {
		title:     "Gitの読み方"
		text:      "`git --no-optional-locks -C <path> log <ref> --since <0時> --until <24時> --date=iso-strict --format=...`。mergeは `%P` の親の数で見分け、題名・本文・作者・SHA・変更したファイルの数を取る。"
		satisfies: ["R-01", "R-04", "F-02"]
	}
	"D-03": {
		title:     "SpecDockの読み方"
		text:      "`spec-dock scope list --json --project <path>` と `spec-dock todo list --json --project <path>` の機械向けの出力（`specdock.cli/v2`）だけを読む。カタログの内部のファイルの形は解釈しない。その日の作成・終了は、出力の時刻の項目で絞る（項目の名前は実装の最初に `--help` と実際の出力で確かめる）。"
		satisfies: ["R-02", "R-04", "F-02"]
	}
	"D-04": {
		title:     "Orcaの読み方（任意）"
		text:      "`orca` のCLI（`orca agent-context` が示す形）で、repositoryのpathとその日の時刻で絞った会話の記録を読む（候補：`orca search --path <path> --since <0時> --scope conversation --json`）。読めないときは `warnings` に理由を入れて空を返す。"
		satisfies: ["R-03", "F-01"]
	}
}
