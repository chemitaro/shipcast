package spec

goal: "ハッカソンの最初の15分で、ほかの作業者が並行に始められる約束をmainに入れる。"

slices: {
	"iss-00008": {covers: ["R-01"], text: "packageとCLIの骨組み、検証のcommand、CI"}
	"iss-00009": {covers: ["R-02", "F-01"], text: "設定と `repo add|list`", after: ["iss-00008"]}
	"iss-00010": {covers: ["R-03", "R-04", "R-05"], text: "型と状態、日誌のパスと前付けの契約", after: ["iss-00008"]}
}

verification: "`uv run shipcast --help`、`uv run pytest -q`、`uv run ruff check` が通り、PRでCIが合格する。"
