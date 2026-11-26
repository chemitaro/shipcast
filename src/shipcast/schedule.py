import plistlib
import shutil
from collections.abc import Mapping
from pathlib import Path

from shipcast.config import DEFAULT_CONFIG_PATH

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
