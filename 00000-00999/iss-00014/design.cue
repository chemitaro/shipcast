package spec

goals: [
	"外部のモデルへの送信の入口を1か所（`GuardedRoute.complete`）にし、伏せる処理と `agy` の守りを、経路の実装から飛ばせないようにする",
	"本物のコマンドを起動せずに、全経路の引数・標準入力・応答の取り出し・失敗を試験で確かめられるようにする（runner の差し替え）",
]

current: "`main` には `shipcast.config`（`ModelConfig(route, model, effort, thinking)` と、経路の名前の検証）があるが、モデルを呼ぶ部品と伏せる処理はない。"

target: """
```text
呼ぶ側（iss-00015・iss-00016）
  └─ get_route(cfg.models.analyst | cfg.models.writer) -> GuardedRoute
       └─ GuardedRoute.complete(prompt, system=, want_json=)
            1. 入力の型を確かめる（str でなければ TypeError）
            2. 経路が antigravity なら、エージェントの印を調べる → あれば RouteRefused
            3. redact(prompt)、redact(system)（例外はそのまま上げる）
            4. want_json なら system の末尾に決まった1文を足す
            5. 経路の実装 → runner（子のプロセス。試験では偽物）
            6. 応答の本文を取り出す。失敗・時間切れ・空は RouteFailed
```
"""

compatibility: "新しいモジュール2つを足すだけで、既存の公開の関数と設定の形（schema 1）は変えない。`DEFAULT_CONFIG_TEXT` は注記を1行足すだけで、`parse_config` の結果は変わらない。"

design: {
	"D-01": {
		title: "`shipcast.redact`：伏せる規則の表"
		text: """
		`redact(text: str) -> str`。`str` でなければ `TypeError`。表の規則を上から順に、文字列全体へ `re.sub` で当て、当たった部分を `[伏せた]`（定数 `REDACTED`）に置き換える。規則は、モジュールの定数 `RULES`（`(名前, 正規表現, 置き換え)` の組の tuple）に表として持ち、足すときは表に1行足す。例外は握りつぶさない（F-03）。

		| 番号 | 対象 | 正規表現（Python） | 置き換え |
		|---|---|---|---|
		| RD-01 | PEMの秘密鍵の塊 | `-----BEGIN[ A-Z0-9]*PRIVATE KEY-----.*?(?:-----END[ A-Z0-9]*PRIVATE KEY-----\\|\\Z)`（`re.S`。閉じがなければ末尾まで） | `[伏せた]` |
		| RD-02 | URLの中の利用者:パスワード | `([A-Za-z][A-Za-z0-9+.-]*://)[^\\s/:@]+:[^\\s/@]+@` | `\\1[伏せた]@` |
		| RD-03 | `Bearer` の後の値 | `(?i)\\b(bearer)[ \\t]+[A-Za-z0-9._~+/=-]{8,}` | `\\1 [伏せた]` |
		| RD-04 | 秘密の名前の鍵の値（その行の末尾まで） | `(?i)(?<![A-Za-z0-9_])(["']?[A-Za-z0-9_.-]*(?:PASSWORD\\|PASSWD\\|SECRET\\|TOKEN\\|API[_-]?KEY\\|ACCESS[_-]?KEY\\|PRIVATE[_-]?KEY\\|CREDENTIALS?)[A-Za-z0-9_.-]*["']?[ \\t]*[:=][ \\t]*)[^\\s\\n][^\\n]*` | `\\1[伏せた]` |
		| RD-05 | GitHub のトークン | `\\bgh[pousr]_[A-Za-z0-9]{20,}` | `[伏せた]` |
		| RD-06 | GitHub の細かい権限のトークン | `\\bgithub_pat_[A-Za-z0-9_]{20,}` | `[伏せた]` |
		| RD-07 | `sk-` の鍵（OpenAI・Anthropic など） | `(?<![A-Za-z0-9_-])sk-[A-Za-z0-9_-]{16,}` | `[伏せた]` |
		| RD-08 | AWS のアクセスキーID | `\\b(?:AKIA\\|ASIA)[0-9A-Z]{16}\\b` | `[伏せた]` |
		| RD-09 | Slack のトークン | `\\bxox[abposr]-[A-Za-z0-9-]{10,}` | `[伏せた]` |
		| RD-10 | Google の API の鍵 | `\\bAIza[0-9A-Za-z_-]{35}(?![0-9A-Za-z_-])` | `[伏せた]` |
		| RD-11 | JWT | `\\beyJ[A-Za-z0-9_-]{8,}\\.[A-Za-z0-9_-]{8,}\\.[A-Za-z0-9_-]{8,}` | `[伏せた]` |

		- 表の正規表現の `\\|` は、Markdown の表の中で `|` を書くための書き方で、コードでは `|`（または）と書く。
		- RD-04 は、`PASSWORD=`・`TOKEN=`・`SECRET=` の行（R-02）を広げたもの。鍵の名前の大小を問わず、前に `export ` や引用符があっても、`=` でも `:` でも当たる。`max_tokens: 1000` のような秘密でない値も伏せる（伏せすぎは受け入れ、閉じる側に倒す）。値が空の行（`TOKEN=` で行が終わる）は変えない。
		- 順は、複数行の RD-01、文脈で当てる RD-02〜RD-04、形で当てる RD-05〜RD-11。置き換えた `[伏せた]` はどの規則にも当たらないので、もう一度通しても変わらない（冪等）。
		- 規則に当てはまらない形の秘密は伏せられない（risks）。
		"""
		satisfies: ["R-02", "F-03"]
	}
	"D-02": {
		title: "エージェントの中の検出：`agent_markers(env)` と `in_agent_context(env)`"
		text: """
		- `AGENT_MARKERS = ("CLAUDECODE", "AI_AGENT", "ORCA_AGENT_SESSION_ID")`、`AGENT_MARKER_PREFIXES = ("CODEX_",)`。
		- `agent_markers(env: Mapping[str, str]) -> tuple[str, ...]`：env の鍵のうち、`AGENT_MARKERS` のどれかと同じか、`AGENT_MARKER_PREFIXES` のどれかで始まる名前を、名前の順に並べて返す。値は見ない（空の文字列でも印）。
		- `in_agent_context(env) -> bool`：`agent_markers` が空でなければ真。env が `Mapping` でない、または鍵を読む途中で例外が起きたら真（閉じる側に倒す。F-01）。このとき `agent_markers` は `("<環境を読めない>",)` を返す。
		- `GuardedRoute` は呼ぶたびに（`get_route` のときではなく `complete` のたびに）調べる。日誌の書き手を作っただけで出来事のない日（モデルを呼ばない）は止めない。
		"""
		satisfies: ["F-01"]
	}
	"D-03": {
		title: "経路の実装と呼び方の表"
		text: """
		経路の実装は、モジュールの中の非公開のクラス（`_FakeRoute`・`_CodexRoute`・`_ClaudeRoute`・`_AntigravityRoute`）で、`get_route` だけが作り、`GuardedRoute` に包んで返す。どれも `invoke(prompt, system, want_json) -> str` を持ち、受け取る prompt・system は伏せた後のもの。`text` は、system が空なら prompt、そうでなければ `system + "\\n\\n---\\n\\n" + prompt`。外部のコマンドの経路は、空の一時ディレクトリ（`tempfile.TemporaryDirectory`）を作業ディレクトリ（`cwd`）にし、呼んだ後に消す。

		| 経路 | argv（この順） | 標準入力 | 応答の本文の取り出し |
		|---|---|---|---|
		| `fake` | 子のプロセスを作らない | ― | `responder` がなければ `json.dumps({"model", "prompt", "route": "fake", "system", "want_json"}, ensure_ascii=False, sort_keys=True)`。あれば `responder(prompt, system, want_json)` の戻り値（`str` でなければ `RouteFailed`） |
		| `codex` | `codex exec --model <model>`、effort があれば `-c model_reasoning_effort=<effort>`、`--sandbox read-only --skip-git-repo-check --ephemeral --ignore-user-config --ignore-rules --color never --cd <空のcwd> --output-last-message <一時ディレクトリの last-message.txt> -` | `text` | `last-message.txt` の中身（UTF-8）。ファイルがなければ `RouteFailed` |
		| `claude` | `claude -p --model <model>`、effort があれば `--effort <effort>`、`--output-format text --no-session-persistence --strict-mcp-config --disable-slash-commands`、system が空でなければ `--system-prompt <system>`、最後に `--tools ""`（空の文字列の1引数） | `prompt` | 標準出力 |
		| `antigravity` | `agy -p <text> --output-format json --model <slug> --mode plan --sandbox --disable-slash-commands`。`slug` は thinking があれば `<model>-<thinking>`（例 `gemini-4-neon-high`）、なければ `<model>` | なし（`subprocess.DEVNULL`） | 標準出力の、空でない最後の行をJSONの物として読み、`status` が `"SUCCESS"` で `response` が空でない文字列なら `response`。それ以外は `RouteFailed`（理由に `status` と、伏せて500文字に切った `error`） |

		- 引数の確かめ（2026-11-26）：`codex`（codex-cli 0.172.0）と `claude` は `--help` で確かめた。`agy`（1.5.12）は起動せず、公式の文書 https://antigravity.google/docs/cli/headless/ と https://antigravity.google/docs/cli/reference/ で確かめた（`-p` は print、応答は標準出力、`json` の形は `{conversation_id, status, response, error?, duration_seconds, num_turns, usage}`、`status` は `SUCCESS`・`ERROR` など、モデルの名前に深さが入る `gemini-4-neon-high` など、`--mode` は `accept-edits`・`auto`・`plan`、許可を取れない道具は拒まれて続く）。文書は、ふつうの標準入力からプロンプトを読む方法を示さないので、プロンプトは `-p` の引数で渡す（F-04 の長さの上限）。
		- `codex` は thinking を使わず、`claude` と `codex` は model と effort だけを使う。`antigravity` は effort を使わない。
		- 道具を使わせない：`claude` は `--tools ""`。`codex` は read-only の sandbox、利用者の設定（MCP、フック）を読まない、空の cwd。`antigravity` は `plan` のモードと sandbox、空の cwd。`codex` と `antigravity` の道具を完全に止める引数はない（risks）。
		- 子の環境は、印を調べたのと同じ env（D-04）を `dict` にして渡す（認証のため `HOME` などが要る）。
		"""
		satisfies: ["R-01", "F-04"]
	}
	"D-04": {
		title: "共通の入口：`get_route` と `GuardedRoute`"
		text: """
		```python
		ROUTES = ("antigravity", "claude", "codex", "fake")
		DEFAULT_TIMEOUT = 600.0
		JSON_INSTRUCTION = "Return only one JSON value. Do not add code fences or any other text."
		MAX_ARGV_PROMPT_BYTES = 200_000

		def get_route(model_cfg: ModelConfig, *, runner: Runner | None = None,
		              env: Mapping[str, str] | None = None, timeout: float = DEFAULT_TIMEOUT,
		              responder: Callable[[str, str, bool], str] | None = None) -> GuardedRoute

		class GuardedRoute:
		    name: str    # 経路の名前
		    model: str   # 設定の model
		    def complete(self, prompt: str, *, system: str = "", want_json: bool = False) -> str
		```

		- `get_route`：`model_cfg.route` が `ROUTES` になければ `UnknownRoute`（文に4つの名前）。`timeout` が正の有限の数でなければ `ValueError`。`responder` を `fake` 以外に渡したら `ValueError`。`runner` を省くと `run_subprocess`（D-06）。子のプロセスは作らない。
		- `complete` の順（target の図）：(1) prompt・system が `str` でなければ `TypeError`。(2) 経路が `antigravity` なら、env（`get_route` に渡した env、省いたら呼ぶときの `os.environ`）で `agent_markers` を調べ、印があれば `RouteRefused`。(3) `redact(prompt)`、`redact(system)`。例外は包まずにそのまま上げる。(4) `want_json` が真なら、system の末尾に（空でなければ改行2つを挟んで）`JSON_INSTRUCTION` を足す。(5) antigravity なら、`text` の UTF-8 の長さが `MAX_ARGV_PROMPT_BYTES` を超えたら `RouteFailed`（F-04）。(6) 経路の実装を呼ぶ。runner には `timeout` を渡す。(7) 応答の本文が空か空白だけなら `RouteFailed`。応答はそのまま返す（前後の空白も変えない）。
		- (2)〜(5) は、子のプロセスと `responder` の前に必ず通る。経路の実装は `GuardedRoute` を通さずに作れない（非公開のクラス、`get_route` だけが作る）。
		- 応答は伏せない（excludes）。
		"""
		satisfies: ["R-01", "R-02", "F-01", "F-03", "F-04"]
	}
	"D-05": {
		title: "例外"
		text: """
		| 例外 | 親 | 属性 | いつ |
		|---|---|---|---|
		| `RouteError` | `Exception` | ― | この部品の例外の親 |
		| `UnknownRoute` | `RouteError` | `route` | 知らない経路の名前（R-01） |
		| `RouteRefused` | `RouteError` | `route`、`markers`（印の名前の tuple） | エージェントの中の antigravity（F-01）。文は「エージェントの中では antigravity の経路を呼べません（印：CLAUDECODE, …）。普通の端末か launchd から実行してください」の形で、値は含めない |
		| `RouteFailed` | `RouteError` | `route`、`returncode`（`int` か `None`）、`stderr_tail`（`str`）、`timed_out`（`bool`）、`reason`（`str`） | F-02、F-04 |

		- `RouteFailed` に包むもの：runner の `subprocess.TimeoutExpired`（`timed_out=True`、`returncode=None`）、`OSError`（`FileNotFoundError` を含む。コマンドが見つからない・起動できない。`returncode=None`）、終了コードが0でない、応答が空か空白だけ、出力のファイルがない、antigravity のJSONが読めないか `status` が `SUCCESS` でないか `response` が空、`responder` が文字列でないものを返した、F-04 の長さ。
		- `stderr_tail` は標準エラーの末尾の2000文字を `redact()` に通したもの。伏せる処理が失敗したら空の文字列にする（手元の記録だけで、外部へは送らない）。
		- `redact()` の例外（`TypeError` を含む）と `RouteRefused` は `RouteFailed` に包まない。`responder` が上げた例外もそのまま上げる。
		"""
		satisfies: ["R-01", "F-01", "F-02", "F-03", "F-04"]
	}
	"D-06": {
		title: "runner（子のプロセスを作る関数）の差し替え"
		text: """
		```python
		@dataclass(frozen=True)
		class Completed:
		    returncode: int
		    stdout: str
		    stderr: str

		class Runner(Protocol):
		    def __call__(self, argv: Sequence[str], *, stdin: str | None, cwd: Path,
		                 env: Mapping[str, str], timeout: float) -> Completed: ...

		def run_subprocess(argv, *, stdin, cwd, env, timeout) -> Completed
		```

		- `run_subprocess` は `subprocess.run(list(argv), input=stdin, stdin=subprocess.DEVNULL if stdin is None else None, capture_output=True, text=True, encoding="utf-8", errors="replace", cwd=cwd, env=dict(env), timeout=timeout, check=False)`。`TimeoutExpired` と `OSError` は呼んだ側（`GuardedRoute`）が `RouteFailed` に包む。
		- 重ねの守り：`run_subprocess` は、`Path(argv[0]).name` が `agy` で、本物の `os.environ` に印があれば、`subprocess.run` を呼ばずに `RouteRefused` を投げる（試験で env を差し替えても、本物の作業者の中では `agy` を起動しない）。
		- 試験は常に偽の runner（呼ばれた argv・stdin・cwd・env・timeout を記録し、決めた `Completed` を返すか例外を上げる）を渡す。`tests/test_models.py` は、`shipcast.models.subprocess.run` を、呼ばれたら試験を落とす関数に差し替える autouse の fixture を持つ。
		"""
		satisfies: ["R-01", "F-01", "F-02"]
	}
	"D-07": {
		title: "設定の見本：分析のモデルの注記"
		text: """
		`DEFAULT_CONFIG_TEXT` の `[models.analyst]` の行 `model = "gpt-6.2-sol"` の後に、同じ行の注記として `# より安い: "gpt-6-luna"（codex debug models で確認。2026-11-26）` を書く（行の長さは `ruff` の100文字に収める。収まらなければ、`model` の行の直前の注記の1行にする）。既定の値と、ほかの行は変えない。
		- 確かめ方：`codex debug models`（モデルを呼ばず、一覧のJSONを出す）。visibility が `list` のうち、説明が「Fast and affordable model for easier tasks.」の今の世代が `gpt-6-luna`。
		"""
		satisfies: ["R-03"]
	}
}

risks: [
	"エージェントの印の環境変数は、各道具の版で変わりうる。Antigravity の CLI が自分の道具の中で付ける印は文書になく、Orca の外で Antigravity の作業者が shipcast を動かすと止められない。2026-12-19 の Antigravity の規約の読み直しのときに、印も見直す（requirement.cue の questions）",
	"伏せる規則に当てはまらない形の秘密（独自の形のトークン、鍵の名前のない値など）は伏せられない。規則は `RULES` の表に1行足して増やす",
	"`codex exec` は read-only の sandbox でも、モデルがコマンドで手元のファイルを読めば、その中身がモデルに渡る（伏せる処理を通らない）。cwd を空にし、利用者の設定を読まないが、完全には止められない。`agy` の `plan` のモードも、道具を完全には止めない。プロンプトに入る出来事の中の指示（プロンプトの注入）でこれが起きうる。iss-00015・iss-00016 のプロンプトで、コマンドとファイルを使わないよう指示する",
	"`agy` の引数は文書だけで確かめ、起動していない。最初の本物の実行（本人の手動）で、引数の誤りが `RouteFailed` として見つかりうる。その場合は D-03 の表を直す",
	"antigravity の経路は、プロンプトを命令の行の引数で渡すので、同じPCのほかの利用者から `ps` で見える（伏せた後の文字列）。個人のPCの前提で受け入れる",
]
