import argparse
import os
import plistlib
import shlex
import shutil
import subprocess
import sys
import tempfile
from collections.abc import Mapping
from pathlib import Path

from shipcast.config import DEFAULT_CONFIG_PATH, ConfigError, load_config

LABEL = "com.shipcast.nightly"
PLIST_NAME = f"{LABEL}.plist"
HOUR = 3
MINUTE = 0
LOG_DIRNAME = "logs"
STDOUT_LOG = "nightly.out.log"
STDERR_LOG = "nightly.err.log"


def build_plist(program: Path, log_dir: Path, environment: Mapping[str, str]) -> bytes:
    if not program.is_absolute() or not log_dir.is_absolute():
        raise ValueError("program と log_dir は絶対パスで指定してください")

    job = {
        "Label": LABEL,
        "ProgramArguments": [str(program), "run"],
        "StartCalendarInterval": {"Hour": HOUR, "Minute": MINUTE},
        "StandardOutPath": str(log_dir / STDOUT_LOG),
        "StandardErrorPath": str(log_dir / STDERR_LOG),
        "ProcessType": "Background",
    }
    if environment:
        job["EnvironmentVariables"] = dict(environment)
    return plistlib.dumps(job, fmt=plistlib.FMT_XML, sort_keys=True)


def nightly_environment(environ: Mapping[str, str]) -> dict[str, str]:
    environment = {}
    if "PATH" in environ:
        environment["PATH"] = environ["PATH"]
    if "SHIPCAST_CONFIG" in environ:
        path = Path(environ["SHIPCAST_CONFIG"] or DEFAULT_CONFIG_PATH)
        environment["SHIPCAST_CONFIG"] = str(path.expanduser().absolute())
    return environment


class ScheduleError(Exception):
    def __init__(self, problem: str, hint: str):
        super().__init__(problem)
        self.problem = problem
        self.hint = hint

    def __str__(self) -> str:
        return f"{self.problem}\n直し方: {self.hint}"


def find_program() -> Path:
    executable = shutil.which("shipcast")
    if executable is None:
        raise ScheduleError(
            "PATH に shipcast が見つかりません",
            "`uv tool install` で shipcast を入れ、"
            "`uv tool update-shell` で PATH に足してから、もう一度実行してください",
        )

    program = Path(executable).absolute()
    if ".venv" in program.parts or ".venv" in program.resolve().parts:
        raise ScheduleError(
            f"checkout の .venv の shipcast は登録しません: {program}",
            "`uv tool install` で入れた shipcast を使ってください"
            "（`uv run` ではなく、`shipcast schedule install` を直接実行します）",
        )
    return program


def plist_path() -> Path:
    return Path.home() / "Library" / "LaunchAgents" / PLIST_NAME


def gui_domain() -> str:
    return f"gui/{os.getuid()}"


def interpreter_path() -> Path:
    return Path(sys.executable).resolve()


def _replace_plist(plist: Path, data: bytes) -> None:
    path = None
    try:
        with tempfile.NamedTemporaryFile(dir=plist.parent, delete=False) as temporary:
            path = Path(temporary.name)
            temporary.write(data)
        path.chmod(0o644)
        os.replace(path, plist)
    finally:
        if path is not None:
            path.unlink(missing_ok=True)


def launchctl(*args: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(["launchctl", *args], capture_output=True, text=True, check=False)


def _launchctl_error(result: subprocess.CompletedProcess[str]) -> str | None:
    if result.returncode == 0:
        return None
    output = result.stderr.strip() or result.stdout.strip()
    if output:
        return output.splitlines()[-1].strip()
    return f"launchctl の終了コード {result.returncode}"


def _launchctl_os_error(error: OSError) -> str:
    if isinstance(error, FileNotFoundError):
        return "launchctl が見つかりません（macOS の launchd だけに対応します）"
    return str(error)


def load(plist: Path) -> str | None:
    domain = gui_domain()
    try:
        launchctl("bootout", f"{domain}/{LABEL}")
        return _launchctl_error(launchctl("bootstrap", domain, str(plist)))
    except OSError as error:
        return _launchctl_os_error(error)


def unload() -> str | None:
    try:
        return _launchctl_error(launchctl("bootout", f"{gui_domain()}/{LABEL}"))
    except OSError as error:
        return _launchctl_os_error(error)


def configure_install(parser: argparse.ArgumentParser) -> None:
    parser.add_argument(
        "--load", action="store_true", help="plist を書いた後、launchctl で読み込む"
    )
    parser.set_defaults(func=install)


def install(args: argparse.Namespace) -> int:
    prefix = "shipcast schedule install:"
    try:
        config = load_config()
    except ConfigError as error:
        print(f"{prefix} {error}", file=sys.stderr)
        return 1
    except OSError as error:
        print(f"{prefix} 設定ファイルを開けません: {error}", file=sys.stderr)
        print("直し方: 設定ファイルのパスと読み取り権限を確かめてください", file=sys.stderr)
        return 1

    try:
        program = find_program()
    except ScheduleError as error:
        print(f"{prefix} {error}", file=sys.stderr)
        return 1

    log_dir = config.state_dir / LOG_DIRNAME
    try:
        log_dir.mkdir(parents=True, exist_ok=True)
        plist = plist_path()
        plist.parent.mkdir(parents=True, exist_ok=True)
        replacing = os.path.lexists(plist)
        _replace_plist(plist, build_plist(program, log_dir, nightly_environment(os.environ)))
    except OSError as error:
        print(f"{prefix} 書き出せません: {error}", file=sys.stderr)
        return 1

    domain = gui_domain()
    service = f"{domain}/{LABEL}"
    action = "置き換えました" if replacing else "書きました"
    print(f"plist を{action}: {plist}")
    print(f"毎日 {HOUR:02d}:{MINUTE:02d} に実行します: {shlex.quote(str(program))} run")
    print(f"ログの置き場: {log_dir}")
    if not args.load:
        print("読み込むには、次を実行してください:")
        print(f"  launchctl bootstrap {domain} {shlex.quote(str(plist))}")
        print("すでに読み込んでいるときは、先に次を実行してください:")
        print(f"  launchctl bootout {service}")
    print(
        "外付けvolumeのrepositoryを読むときは、"
        f"フルディスクアクセスに次を足してください: {interpreter_path()}"
    )
    print("手順は README の「導入と毎晩の実行」の節を参照してください。")

    if args.load:
        reason = load(plist)
        if reason is not None:
            print(f"{prefix} 読み込みに失敗しました: {reason}", file=sys.stderr)
            print(
                f"直し方: `launchctl bootout {service}` を実行し、"
                "`shipcast schedule install --load` をやり直してください",
                file=sys.stderr,
            )
            return 1
        print(f"読み込みました: {service}")
    return 0


def configure_uninstall(parser: argparse.ArgumentParser) -> None:
    parser.add_argument("--unload", action="store_true", help="plist を消す前に、launchctl で外す")
    parser.set_defaults(func=uninstall)


def uninstall(args: argparse.Namespace) -> int:
    prefix = "shipcast schedule uninstall:"
    service = f"{gui_domain()}/{LABEL}"
    reason = None
    if args.unload:
        reason = unload()
        if reason is not None:
            print(
                f"{prefix} 警告: 外せませんでした（読み込んでいなかった可能性があります）: "
                f"{reason}",
                file=sys.stderr,
            )

    plist = plist_path()
    try:
        plist.unlink()
    except FileNotFoundError:
        print(f"登録はありません: {plist}")
    except OSError as error:
        print(f"{prefix} plist を消せません: {error}", file=sys.stderr)
        return 1
    else:
        print(f"plist を消しました: {plist}")

    if not args.unload:
        print("読み込んだ登録を外すには、次を実行してください:")
        print(f"  launchctl bootout {service}")
    elif reason is None:
        print(f"外しました: {service}")
    return 0
