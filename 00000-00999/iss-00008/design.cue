package spec

design: {
	"D-01": {
		title:     "CLIの入口 `shipcast.cli:main`"
		text:      "`argparse` の下位のコマンドを登録する。中身がまだのコマンドは「未実装」と示して終了コード2を返す。`pyproject.toml` の `[project.scripts]` に `shipcast` を登録する。"
		satisfies: ["R-01"]
	}
	"D-02": {
		title:     "開発の土台"
		text:      "`pyproject.toml`（Python 3.12、dev依存に pytest と ruff）、`src/shipcast/__init__.py`、`tests/test_cli.py`。"
		satisfies: ["R-02", "R-03"]
	}
}
