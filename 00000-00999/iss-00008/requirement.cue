package spec

schema: "specdock/v1"

assurance: {
	level:  "light"
	reason: "まだコードのないrepositoryに、packageの骨組みと検証の土台を足すだけで、既存の利用者も外部への影響もない。PRを戻せば元に戻る"
}

purpose: "Pythonのpackageと `shipcast` のCLIの骨組みを作り、試験と検査が回る状態にする。"

requirements: {
	"R-01": {title: "`uv run shipcast --help` が、下位のコマンド（repo、collect、write、run、serve、draft、schedule）を示す"}
	"R-02": {title: "`uv run pytest -q` と `uv run ruff check` が通る"}
	"R-03": {title: "`AGENTS.md` に、検証のcommandが書かれている"}
}
