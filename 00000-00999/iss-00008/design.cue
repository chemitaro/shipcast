package spec

goals: [
	"後のIssueが、自分の下位のコマンドの中身を1か所に足すだけで済む入口にする",
	"手元とCIが、同じ3つのcommand（`uv sync --locked`、`uv run ruff check`、`uv run pytest -q`）で同じ結果になる",
]

current: "コードはない。`AGENTS.md` の「Gitと検証」は「検証のcommandは、実装を始めるときにここへ書きます」のまま。CIもない。"
target:  "`uv run shipcast --help` が7つの下位のコマンドを示し、手元とPRのCIで試験と検査が通る。"

design: {
	"D-01": {
		title: "packageと開発の土台"
		text: """
		`uv init --package --build-backend uv` 相当の形にする。

		```text
		pyproject.toml          # [project] name = "shipcast"、requires-python = ">=3.12"、dependencies = []
		uv.lock                 # Gitに入れる（CIは --locked で読む）
		.python-version         # 3.12
		src/shipcast/__init__.py    # __version__ は importlib.metadata から
		src/shipcast/__main__.py    # python -m shipcast → cli.main()
		src/shipcast/cli.py
		tests/test_cli.py
		```

		- `[project.scripts]` に `shipcast = "shipcast.cli:main"`。
		- `[dependency-groups] dev = ["pytest", "ruff"]`（版は `uv add --dev` が決めたものを `uv.lock` に固定）。
		- `[tool.ruff]`：`target-version = "py312"`、`line-length = 100`、`[tool.ruff.lint] select = ["E", "F", "I", "B", "UP"]`。
		- `[tool.pytest.ini_options]`：`testpaths = ["tests"]`。
		- `uv init` が作る見本の `hello` の関数や `README.md` の書き換えは残さない（README は今のものを保つ）。
		"""
		satisfies: ["R-02"]
	}
	"D-02": {
		title: "CLIの入口 `shipcast.cli`"
		text: """
		- `build_parser() -> argparse.ArgumentParser` と `main(argv: list[str] | None = None) -> int`。`main` は終了コードを返し、`[project.scripts]` の入口は `sys.exit(main())` と同じに動く。
		- 下位のコマンドは表（`COMMANDS`）で1か所に登録する。各行は、名前、日本語の説明、その下のコマンド、中身を作るIssueのID。

		| コマンド | その下 | 中身を作るIssue |
		|---|---|---|
		| `repo` | `add`、`list` | iss-00009 |
		| `collect` | ― | iss-00011 |
		| `write` | ― | iss-00016 |
		| `run` | ― | iss-00021 |
		| `serve` | ― | iss-00017 |
		| `draft` | `x` | iss-00020 |
		| `schedule` | `install`、`uninstall` | iss-00022 |

		- 中身のない葉は、共通の `not_implemented(command, issue_id)` を呼ぶ。標準エラーに `shipcast <コマンド>: 未実装です（<issue_id> で作ります）` を出し、2を返す。ファイルを開かず、ディレクトリを作らない（F-01）。
		- 下位のコマンドを付けずに `shipcast` だけを打つと、使い方を示して2を返す。
		- 知らない名前や引数は、argparseの既定の動き（使い方を標準エラーに出して2で終わる）に任せる（F-02）。
		- 後のIssueは、自分の行の葉の関数を差し替えるだけで中身を足す。引数の追加も、その行の中で行う。
		- `--version` で `shipcast <版>` を示す。
		"""
		satisfies: ["R-01", "F-01", "F-02"]
	}
	"D-03": {
		title: "試験 `tests/test_cli.py`"
		text: """
		`main([...])` を直接呼び、`capsys` で出力を、戻り値（または `SystemExit.code`）で終了コードを確かめる。`--help` はargparseが `SystemExit(0)` を投げるので、`pytest.raises(SystemExit)` で受ける。

		- 未実装の葉の試験は、`tmp_path` を作業ディレクトリにし、`HOME` と `XDG_*` を `tmp_path` の下に向けた上で呼び、呼んだ後に `tmp_path` の中身が増えていないことを確かめる。
		- `AGENTS.md` と `ci.yml` の中身の試験は、文字列で必要なcommandが含まれるかだけを見る（YAMLの解析の依存を足さない）。
		- 外部のコマンド（`agy`、`codex`、`claude`、`gh`、`git` の書込み）を呼ばない。
		"""
		satisfies: ["R-01", "R-02", "R-03", "R-04", "F-01", "F-02"]
	}
	"D-04": {
		title: "`AGENTS.md` の「Gitと検証」"
		text: """
		最後の行（「検証のcommandは、実装を始めるときにここへ書きます（まだコードはありません）。」）を、次の内容に置き換える。ほかの行は変えない。

		```markdown
		- 検証のcommand（この順に、手元とCIで同じものを流す）：
		  1. `uv sync --locked`
		  2. `uv run ruff check`
		  3. `uv run pytest -q`
		- 試験とエージェントの作業では、外部のモデルを呼ばない。モデルの経路は `fake` を使い、`agy` を呼ばない。
		- PRはCI（`.github/workflows/ci.yml`）の合格を観測してから、統括がマージする。
		```
		"""
		satisfies: ["R-03"]
	}
	"D-05": {
		title: "CI `.github/workflows/ci.yml`"
		text: """
		```yaml
		name: ci
		on:
		  pull_request:
		  push:
		    branches: [main]
		permissions:
		  contents: read
		jobs:
		  test:
		    runs-on: ubuntu-latest
		    steps:
		      - uses: actions/checkout@v7
		      - uses: astral-sh/setup-uv@v10
		        with:
		          python-version: "3.12"
		      - run: uv sync --locked
		      - run: uv run ruff check
		      - run: uv run pytest -q
		```

		- actionの版は、2026-11-26 に確かめた最新のメジャー版（`actions/checkout` v7.0.1、`astral-sh/setup-uv` v10.4.0）に固定する。実装のときに版が変わっていれば、そのときの最新のメジャー版にし、報告に書く。
		- secretsを使わず、外部のサービスへ何も送らない。
		"""
		satisfies: ["R-04"]
	}
}

compatibility: "最初の版で、既存の利用者はいない。下位のコマンドの名前は、epic-00002 の R-01 の約束として後のIssueが使う。"

risks: [
	"`uv init` が作る見本のファイル（`hello` の関数、README）が残ると、検査や見た目が崩れる。D-01 のとおり取り除く",
	"GitHub Actionsのactionの版が上がると、`setup-uv` の引数が変わりうる。CIが落ちたら、その版のREADMEで引数を確かめる",
]
