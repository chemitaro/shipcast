package spec

goals: [
	"外部のモデルへの送信の入口を1か所（`GuardedRoute.complete`）にし、伏せる処理と `agy` の守りを、経路の実装から飛ばせないようにする",
	"本物のコマンドを起動せずに、全経路の引数・標準入力・応答の取り出し・失敗と、本物の runner の `subprocess.run` への渡し方を試験で確かめられるようにする",
]

current: "`main` には `shipcast.config`（`ModelConfig(route, model, effort, thinking)` と、経路の名前の検証）があるが、モデルを呼ぶ部品と伏せる処理はない。"

target: """
```text
呼ぶ側（iss-00015・iss-00016）
  └─ get_route(cfg.models.analyst | cfg.models.writer) -> GuardedRoute
       └─ GuardedRoute.complete(prompt, system=, want_json=)
            1. 入力の型を確かめる（str でなければ TypeError）
            2. 環境を1回だけ写し取る（dict）。写せなければ antigravity は RouteRefused、ほかは RouteFailed
            3. 経路が antigravity なら、写しでエージェントの印を調べる → あれば RouteRefused
            4. redact(prompt)、redact(system)（例外はそのまま上げる）
            5. want_json なら system の末尾に決まった1文を足す
            6. antigravity なら、最終の text の長さを調べる → 超えれば RouteFailed
            7. 経路の実装 → runner（写しを子の環境に渡す。試験では偽物）
            8. 応答の本文を取り出す。失敗・時間切れ・空・読めない応答は RouteFailed
```
"""

compatibility: "新しいモジュール2つを足すだけで、既存の公開の関数と設定の形（schema 1）は変えない。`DEFAULT_CONFIG_TEXT` は注記を1行足すだけで、`parse_config` の結果は変わらない。"

design: {
	"D-01": {
		title: "`shipcast.redact`：伏せる規則の表と、JSONの構造をたどる伏せ方"
		text: #"""
			`redact(text: str) -> str`。`str` でなければ `TypeError`。2つの層で伏せる。

			1. **JSONの層**：文字列の前後の空白を除いた全体が `{` か `[` で始まり、`json.loads` でJSONの物か配列として読めるときは、構造をたどる。物の鍵が秘密の名前（`SECRET_KEY` に全体が当たる）で、値が `None` と空の文字列でなければ、値を型によらず（数、物、配列も）文字列 `"[伏せた]"` に置き換える。ほかの文字列の値は、同じ `redact` の手順で伏せる（文字列の中のJSONも、ここで再びたどる）。数・真偽値・`null`・鍵の名前は変えない。たどった後は `json.dumps(…, ensure_ascii=False)` で1行に書き直す（元の字下げと `\u` のエスケープは保たないが、JSONとして読める）。
			2. **文の層**：JSONとして読めない文字列には、表 `RULES` の規則を上から順に、文字列全体へ当てる。

			JSONの層があるので、`json.dumps` で書き出された日本語（`\u30f3` など）、引用符（`\"`）、改行（`\n`）が規則の手掛かりを隠すことがない。規則を足すときは `RULES` に1行足す。例外は握りつぶさない（F-03）。次のコードは、タスク担当が Python 3.12 で、下の例を実際に通して確かめたもの（2026-11-26）で、実装はこの振る舞いに合わせる。

			```python
			import json, re
			REDACTED = "[伏せた]"
			_A = r"(?:(?<![A-Za-z0-9_])|(?<=\\u[0-9A-Fa-f]{4})|(?<=\\[nrtbf]))"
			_Z = r"(?![A-Za-z0-9_])"
			_KEY = r"(?:PASSWORD|PASSWD|SECRET|TOKEN|API[_-]?KEY|ACCESS[_-]?KEY|PRIVATE[_-]?KEY|CREDENTIALS?)"
			SECRET_KEY = re.compile(r"(?i)[A-Za-z0-9_.-]*" + _KEY + r"[A-Za-z0-9_.-]*")

			def _rd04_repl(m):
			    v = m.group(2)
			    if v.startswith('\\"') and len(v) >= 4 and v.endswith('\\"'):
			        return m.group(1) + '\\"' + REDACTED + '\\"'
			    if v[0] in "\"'" and len(v) >= 2 and v[-1] == v[0]:
			        return m.group(1) + v[0] + REDACTED + v[0]
			    return m.group(1) + REDACTED

			RULES = (
			    ("RD-01", re.compile(r"-----BEGIN ((?:[A-Z0-9]+ )*)PRIVATE KEY-----.*?(?:-----END \1PRIVATE KEY-----|\Z)", re.S), REDACTED),
			    ("RD-02", re.compile(r"([A-Za-z][A-Za-z0-9+.-]*://)[^\s/:@]+:[^\s/@]+@"), r"\1" + REDACTED + "@"),
			    ("RD-03", re.compile(r"(?i)" + _A + r"(bearer)[ \t]+[A-Za-z0-9._~+/=-]{8,}"), r"\1 " + REDACTED),
			    ("RD-04", re.compile(
			        r"(?i)" + _A
			        + r"((?:\\?[\"'])?[A-Za-z0-9_.-]*" + _KEY + r"[A-Za-z0-9_.-]*(?:\\?[\"'])?[ \t]*+[:=][ \t]*+)"
			        + r"(?!(?:\\?[\"'])?\[伏せた\])"
			        + r"(\\\"(?:(?!\\\")[^\n])*\\\"|\"(?:[^\"\\\n]|\\.)*\"|'[^'\n]*'|(?:(?!\\[nr])[^\n])+)"
			    ), _rd04_repl),
			    ("RD-05", re.compile(_A + r"gh[pousr]_[A-Za-z0-9]{20,}"), REDACTED),
			    ("RD-06", re.compile(_A + r"github_pat_[A-Za-z0-9_]{20,}"), REDACTED),
			    ("RD-07", re.compile(r"(?:(?<![A-Za-z0-9_-])|(?<=\\u[0-9A-Fa-f]{4})|(?<=\\[nrtbf]))sk-[A-Za-z0-9_-]{16,}"), REDACTED),
			    ("RD-08", re.compile(_A + r"(?:AKIA|ASIA)[0-9A-Z]{16}" + _Z), REDACTED),
			    ("RD-09", re.compile(_A + r"xox[abposr]-[A-Za-z0-9-]{10,}"), REDACTED),
			    ("RD-10", re.compile(_A + r"AIza[0-9A-Za-z_-]{35}(?![0-9A-Za-z_-])"), REDACTED),
			    ("RD-11", re.compile(_A + r"eyJ[A-Za-z0-9_-]{5,}\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]*"), REDACTED),
			)

			def redact_text(text):
			    for _, p, r in RULES:
			        text = p.sub(r, text)
			    return text

			def _container(s):
			    t = s.strip()
			    if not t or t[0] not in "[{":
			        return None
			    try:
			        v = json.loads(t)
			    except ValueError:
			        return None
			    return v if isinstance(v, (dict, list)) else None

			def _walk(v):
			    if isinstance(v, dict):
			        return {k: (REDACTED if SECRET_KEY.fullmatch(k) and v2 not in (None, "") else _walk(v2)) for k, v2 in v.items()}
			    if isinstance(v, list):
			        return [_walk(x) for x in v]
			    if isinstance(v, str):
			        return _redact_str(v)
			    return v

			def _redact_str(s):
			    c = _container(s)
			    if c is not None:
			        return json.dumps(_walk(c), ensure_ascii=False)
			    return redact_text(s)

			def redact(text):
			    if not isinstance(text, str):
			        raise TypeError("redact() は str だけを受け取ります")
			    return _redact_str(text)
			```

			| 番号 | 対象 | 要点 |
			|---|---|---|
			| RD-01 | PEMの秘密鍵の塊 | BEGIN と同じ種類（`RSA `・`OPENSSH `・`EC `・`ENCRYPTED `・なし）の END の行までを伏せる。同じ種類の END がなければ末尾まで（種類の違う END では止まらない） |
			| RD-02 | URLの中の利用者:パスワード | `https://user:pass@host` の `user:pass` だけ |
			| RD-03 | `Bearer` の後の値 | 大小を問わない |
			| RD-04 | 秘密の名前の鍵の値（文の層） | 鍵の名前に `PASSWORD`・`SECRET`・`TOKEN`・`API_KEY` などを含み（大小を問わない）、`=` か `:` が続く。鍵の前後の引用符は、なし・`"`・`'`・`\"` のどれでもよい。値が `\"…\"`・`"…"`・`'…'` なら、引用の中だけを `[伏せた]` にして引用符を残す。引用がなければ、行の末尾（または文字の `\n`・`\r` の手前）まで伏せる（`}`・`]`・`,` では止まらない）。値が空・空白だけなら変えない。値が `[伏せた]` で始まれば変えない（冪等） |
			| RD-05〜RD-11 | 形で分かるトークン | 前を ASCII の英数字・`_` で区切る。`\uXXXX`・`\n` などのエスケープの直後も区切りとみなす（日本語の隣でも当たる） |

			- `[伏せた]` はどの規則にも当たらず、JSONの層も同じ結果を返すので、もう一度通しても変わらない（冪等）。
			- RD-04 は `PASSWORD=`・`TOKEN=`・`SECRET=` の行（epic-00004 の F-02）を広げたもの。`max_tokens` のような秘密でない値も伏せる（伏せすぎは受け入れ、閉じる側に倒す）。文の層の引用のない値は行の末尾まで伏せる（同じ行の後ろの文も消えるが、秘密を残さない側に倒す）。1行のJSONの全体は、JSONの層が鍵ごとに伏せるので、ほかの鍵と値は残る。
			- 確かめた例（タスク担当、Python 3.12、2026-11-26。すべて漏れなし・冪等）：`json.dumps` した「トークン」の直後の `ghp_` のトークン・`AKIA` のID・`sk-` の鍵。会話の本文に入れた `json.dumps({"password": "DUMMY\"EXAMPLE", "user": "demo"})` を、さらに外側のJSONに入れたもの（`password` の値だけが伏せられ、`user` とほかの出来事が残り、結果がJSONとして読める）。`DB_PASSWORD=DUMMY]EXAMPLE`・`DB_PASSWORD=Ab}9xQ2`（値の全体）。`{"password": "…", "title": "keep"}`（`"password": "[伏せた]"`、`title` が残り、JSONとして読める）。JSONの文字列の中の `PASSWORD=…\nnormal line`（`normal line` が残る）。`payload: {"api_token": "…", "title": "keep"}` のような文の中のJSON（値だけ）。閉じのない `"password": "abc`。JSONとして読めない、エスケープの残った文 `{\"password\": \"…\"`。
			- 限界：JSONとして読めない文の中で、エスケープの残った引用（`\"…\"`）の値の中にさらに `\"` がある形は、最初の `\"` までしか伏せない。規則に当てはまらない形の秘密は伏せられない（risks）。
			"""#
		satisfies: ["R-02", "F-03"]
	}
	"D-02": {
		title: "エージェントの中の検出：`agent_markers(env)` と `in_agent_context(env)`"
		text: """
		- `AGENT_MARKERS = ("CLAUDECODE", "AI_AGENT", "ORCA_AGENT_SESSION_ID")`、`AGENT_MARKER_PREFIXES = ("CODEX_",)`。
		- `agent_markers(env: Mapping[str, str]) -> tuple[str, ...]`：env の鍵のうち、`AGENT_MARKERS` のどれかと同じか、`AGENT_MARKER_PREFIXES` のどれかで始まる名前を、名前の順に並べて返す。値は見ない（空の文字列でも印）。env が `Mapping` でない、または鍵を読む途中で例外が起きたら `(UNREADABLE_ENV,)`（`UNREADABLE_ENV = "<環境を読めない>"`）を返す（閉じる側に倒す）。
		- `in_agent_context(env) -> bool`：`agent_markers(env)` が空でなければ真。
		- `agent_markers` は鍵だけを読む。値を読むと例外を上げる Mapping でも、鍵を読めれば印の一覧を返す（その環境は `complete` の写しの段で止まる。D-04）。
		- `GuardedRoute.complete` は、呼ぶたびに（`get_route` のときではなく）環境の写しを作り、その写しで調べる（D-04）。日誌の書き手を作っただけで出来事のない日（モデルを呼ばない）は止めない。同じ `GuardedRoute` でも、呼ぶ間に印が現れれば、次の呼び出しで止まる。
		"""
		satisfies: ["F-01"]
	}
	"D-03": {
		title: "経路の実装と呼び方の表"
		text: """
		経路の実装は、モジュールの中の非公開のクラス（`_FakeRoute`・`_CodexRoute`・`_ClaudeRoute`・`_AntigravityRoute`）で、`get_route` だけが作り、`GuardedRoute` に包んで返す。受け取る prompt・system は伏せた後のもの（system には want_json のときの `JSON_INSTRUCTION` が足してある）。`text` は、system が空なら prompt、そうでなければ `system + "\\n\\n---\\n\\n" + prompt`。外部のコマンドの経路は、`tempfile.TemporaryDirectory` を1つ作り、その中の空の `work/` を作業ディレクトリ（`cwd`）にし、呼んだ後に消す。

		| 経路 | argv（この順） | 標準入力 | 応答の本文の取り出し |
		|---|---|---|---|
		| `fake` | 子のプロセスを作らない | ― | `responder` がなければ `json.dumps({"model": model, "prompt": prompt, "route": "fake", "system": system, "want_json": want_json}, ensure_ascii=False, sort_keys=True)`。あれば `responder(prompt, system, want_json)` の戻り値（`str` でなければ `RouteFailed`） |
		| `codex` | `codex exec --model <model>`、effort があれば `-c model_reasoning_effort=<effort>`、`--disable shell_tool --disable unified_exec --disable view_image --disable plugins --sandbox read-only --skip-git-repo-check --ephemeral --ignore-user-config --ignore-rules --color never --cd <work> --output-last-message <一時ディレクトリ>/last-message.txt -` | `text` | `last-message.txt` の中身（UTF-8 で読む） |
		| `claude` | `claude -p --model <model>`、effort があれば `--effort <effort>`、`--output-format text --no-session-persistence --strict-mcp-config --disable-slash-commands`、system が空でなければ `--system-prompt <system>`、最後に `--tools ""`（空の文字列の1引数） | `prompt` | 標準出力 |
		| `antigravity` | `agy -p <text> --output-format json --model <slug> --mode plan --sandbox --disable-slash-commands`。`slug` は thinking があれば `<model>-<thinking>`（例 `gemini-4-neon-high`）、なければ `<model>` | なし（`subprocess.DEVNULL`） | 標準出力の、空白でない最後の行をJSONとして読む。dict で、`status` が `"SUCCESS"`、`response` が空白だけでない `str` なら `response`。それ以外は `RouteFailed`（理由に `status` と、伏せて500文字に切った `error`） |

		- 引数の確かめ（2026-11-26）：`codex`（codex-cli 0.172.0）と `claude` は `--help` で確かめた。`codex` の4つの `--disable` は、モデルを呼ばない `codex debug prompt-input` で、手元を読む道具（`exec_command`・`write_stdin`・`view_image`・プラグインの導入）がモデルに見える道具の一覧から消えることを確かめた（requirement.cue の decisions）。`agy`（1.5.12）は起動せず、公式の文書で確かめた（`-p` は print、応答は標準出力、`json` の形は `{conversation_id, status, response, error?, duration_seconds, num_turns, usage}`、`status` は `SUCCESS`・`ERROR` など、モデルの名前に深さが入る `gemini-4-neon-high` など、`--mode` は `accept-edits`・`auto`・`plan`、許可を取れない道具は拒まれて続く、`--sandbox` はコマンドを隔離しネットワークを止める）。文書は、ふつうの標準入力からプロンプトを読む方法を示さないので、プロンプトは `-p` の引数で渡す（F-04）。
		- `codex` は thinking を使わず、`claude` と `codex` は model と effort だけを使う。`antigravity` は effort を使わない。
		- 道具（F-05）：`claude` は `--tools ""` で道具なし。`codex` は手元を読む道具を外し、利用者の設定（MCP・フック）を読まず、read-only の sandbox、空の cwd。`antigravity` は `plan` のモード、`--sandbox`、空の cwd で狭めるだけで、残る危険は本人が受け入れた（requirement.cue の decisions の Q-01）。
		- 子の環境は、`complete` が作った環境の写し（D-04）。認証のため `HOME` などが要るので、絞らない。
		"""
		satisfies: ["R-01", "F-04", "F-05"]
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

		- `get_route`：`model_cfg.route` が `ROUTES` になければ `UnknownRoute`（文に4つの名前）。`timeout` が正の有限の数でなければ `ValueError`。`responder` を `fake` 以外に渡したら `ValueError`。`runner` を省くと `run_subprocess`（D-06）。子のプロセスは作らず、環境も読まない。
		- `complete` の順（target の図）：(1) prompt・system が `str` でなければ `TypeError`。(2) 環境の写しを作る（`source` は `get_route` に渡した env、省いたら呼ぶときの `os.environ`）。`source` が `collections.abc.Mapping` でなければ、また `snapshot = {k: source[k] for k in source}` の途中で例外が起きたら、antigravity は `RouteRefused(markers=(UNREADABLE_ENV,))`、ほかの経路は `RouteFailed`（理由「環境を読めない」）。(3) 経路が `antigravity` なら `agent_markers(snapshot)` が空でなければ `RouteRefused`。(4) `redact(prompt)`、`redact(system)` の順に呼ぶ。例外は包まずにそのまま上げる。(5) `want_json` が真なら、system の末尾に（空でなければ改行2つを挟んで）`JSON_INSTRUCTION` を足す。(6) antigravity なら、D-03 の `text` の UTF-8 の長さが `MAX_ARGV_PROMPT_BYTES` を超えたら `RouteFailed`（ちょうどなら通す。F-04）。(7) 経路の実装を呼ぶ。runner には `snapshot` と `timeout` を渡す。(8) 応答の本文が空か空白だけなら `RouteFailed`。応答はそのまま返す（前後の空白も変えない）。
		- (1)〜(6) は、子のプロセスと `responder` の前に必ず通る。経路の実装は `GuardedRoute` を通さずに作れない（非公開のクラス、`get_route` だけが作る）。
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
		| `RouteRefused` | `RouteError` | `route`、`markers`（印の名前の tuple） | エージェントの中の antigravity、環境を読めない antigravity（F-01）。文は「エージェントの中では antigravity の経路を呼べません（印：CLAUDECODE, …）。普通の端末か launchd から実行してください」の形で、値は含めない |
		| `RouteFailed` | `RouteError` | `route`、`returncode`（`int` か `None`）、`stderr_tail`（`str`）、`timed_out`（`bool`）、`reason`（`str`） | F-02、F-04 |

		- 外部のコマンドの経路（codex・claude・antigravity）の実装の中で起きた、`subprocess.TimeoutExpired`（`timed_out=True`、`returncode=None`）、`OSError`（`FileNotFoundError`、出力のファイルの読み取りを含む）、`ValueError`（引数のNUL、`UnicodeDecodeError`、`json.JSONDecodeError` を含む）、`subprocess.SubprocessError` は、`RouteFailed` に包み、元の例外を `__cause__` に残す。`RouteError`（`run_subprocess` の `RouteRefused`）は包まずにそのまま上げる。
		- そのほかに `RouteFailed` にするもの：終了コードが0でない、応答が空か空白だけ、出力のファイルがない、antigravity のJSONが dict でない・`status` が `SUCCESS` でない・`response` が空白だけでない `str` でない、`responder` が `str` でないものを返した、環境を読めない（antigravity 以外）、F-04 の長さ。
		- `stderr_tail` は、標準エラーの **全体** を `redact()` に通してから、その末尾の2000文字を取ったもの（切ってから伏せると、切れ目にかかる秘密が残るため）。伏せる処理が失敗したら空の文字列にする（手元の記録だけで、外部へは送らない）。
		- `redact()` の例外（`TypeError` を含む）と `RouteRefused` は `RouteFailed` に包まない。`responder` が上げた例外もそのまま上げる（`fake` は包む対象の外）。
		"""
		satisfies: ["R-01", "F-01", "F-02", "F-03", "F-04"]
	}
	"D-06": {
		title: "runner（子のプロセスを作る関数）の差し替えと、本物の runner"
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

		- `run_subprocess` は、`stdin` が `None` なら `subprocess.run(list(argv), stdin=subprocess.DEVNULL, capture_output=True, text=True, encoding="utf-8", errors="replace", cwd=cwd, env=dict(env), timeout=timeout, check=False)`、`None` でなければ `stdin=` の代わりに `input=stdin` を渡す（ほかは同じ）。戻り値を `Completed(returncode, stdout, stderr)` にする。`TimeoutExpired` と `OSError` などは、そのまま上げる（`GuardedRoute` が包む。D-05）。
		- 重ねの守り：`run_subprocess` は、`Path(argv[0]).name` が `agy` で、本物の `os.environ` に印があれば（`agent_markers(os.environ)` が空でない）、`subprocess.run` を呼ばずに `RouteRefused` を投げる（試験で env を差し替えても、本物の作業者の中では `agy` を起動しない）。
		- 試験：経路の試験は、偽の runner（呼ばれた argv・stdin・cwd・env・timeout を記録し、決めた `Completed` を返すか例外を上げる）を渡す。`tests/test_models.py` は、`shipcast.models.subprocess.run` を、呼ばれたら試験を落とす関数に差し替える autouse の fixture を持つ。`run_subprocess` の試験だけ、その試験の中で `shipcast.models.subprocess.run` を、受け取った引数を記録して `subprocess.CompletedProcess` を返すか例外を上げる偽物に差し替える（本物のコマンドは起動しない）。
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
	"伏せる規則に当てはまらない形の秘密（独自の形のトークン、鍵の名前のない値、D-01 の限界の形）は伏せられない。規則は `RULES` の表に1行足して増やす。JSONは、呼ぶ側が prompt の全体を1つのJSONにして渡すと、構造をたどって確実に伏せられる（requirement.cue の constraints）",
	"`agy -p` の道具は、引数では止めきれない（F-05。本人が残る危険を受け入れた。requirement.cue の decisions の Q-01）。`codex` の道具の外し方は、codex-cli の版で機能の名前が変わりうる。版を上げたら `codex debug prompt-input` で確かめ直す",
	"`agy` の引数は文書だけで確かめ、起動していない。最初の本物の実行（本人の手動）で、引数の誤りが `RouteFailed` として見つかりうる。その場合は D-03 の表を直す",
	"antigravity の経路は、プロンプトを命令の行の引数で渡すので、同じPCのほかの利用者から `ps` で見える（伏せた後の文字列）。個人のPCの前提で受け入れる",
]
