"""会話や JSON に含まれる秘密を伏せる。"""

import json
import re
from typing import Any

REDACTED = "[伏せた]"
_A = r"(?:(?<![A-Za-z0-9_])|(?<=\\u[0-9A-Fa-f]{4})|(?<=\\[nrtbf]))"
_Z = r"(?![A-Za-z0-9_])"
_KEY = r"(?:PASSWORD|PASSWD|SECRET|TOKEN|API[_-]?KEY|ACCESS[_-]?KEY|PRIVATE[_-]?KEY|CREDENTIALS?)"
SECRET_KEY = re.compile(r"(?i)[A-Za-z0-9_.-]*" + _KEY + r"[A-Za-z0-9_.-]*")


def _rd04_repl(m: re.Match[str]) -> str:
    v = m.group(2)
    if v.startswith('\\"') and len(v) >= 4 and v.endswith('\\"'):
        return m.group(1) + '\\"' + REDACTED + '\\"'
    if v[0] in "\"'" and len(v) >= 2 and v[-1] == v[0]:
        return m.group(1) + v[0] + REDACTED + v[0]
    return m.group(1) + REDACTED


RULES = (
    (
        "RD-01",
        re.compile(
            r"-----BEGIN ((?:[A-Z0-9]+ )*)PRIVATE KEY-----.*?(?:-----END \1PRIVATE KEY-----|\Z)",
            re.S,
        ),
        REDACTED,
    ),
    (
        "RD-02",
        re.compile(r"([A-Za-z][A-Za-z0-9+.-]*://)[^\s/:@]+:[^\s/@]+@"),
        r"\1" + REDACTED + "@",
    ),
    (
        "RD-03",
        re.compile(r"(?i)" + _A + r"(bearer)[ \t]+[A-Za-z0-9._~+/=-]{8,}"),
        r"\1 " + REDACTED,
    ),
    (
        "RD-04",
        re.compile(
            r"(?i)"
            + _A
            + r"((?:\\?[\"'])?[A-Za-z0-9_.-]*"
            + _KEY
            + r"[A-Za-z0-9_.-]*(?:\\?[\"'])?[ \t]*+[:=][ \t]*+)"
            + r"(\\\"(?:(?!\\\")[^\n])*\\\"|\"(?:[^\"\\\n]|\\.)*\"|'[^'\n]*'|[^\n]+)"
        ),
        _rd04_repl,
    ),
    ("RD-05", re.compile(_A + r"gh[pousr]_[A-Za-z0-9]{20,}"), REDACTED),
    ("RD-06", re.compile(_A + r"github_pat_[A-Za-z0-9_]{20,}"), REDACTED),
    (
        "RD-07",
        re.compile(
            r"(?:(?<![A-Za-z0-9_-])|(?<=\\u[0-9A-Fa-f]{4})|(?<=\\[nrtbf]))sk-[A-Za-z0-9_-]{16,}"
        ),
        REDACTED,
    ),
    ("RD-08", re.compile(_A + r"(?:AKIA|ASIA)[0-9A-Z]{16}" + _Z), REDACTED),
    ("RD-09", re.compile(_A + r"xox[abposr]-[A-Za-z0-9-]{10,}"), REDACTED),
    ("RD-10", re.compile(_A + r"AIza[0-9A-Za-z_-]{35}(?![0-9A-Za-z_-])"), REDACTED),
    ("RD-11", re.compile(_A + r"eyJ[A-Za-z0-9_-]{5,}\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]*"), REDACTED),
)


def _redact_text(text: str) -> str:
    for _, pattern, replacement in RULES:
        text = pattern.sub(replacement, text)
    return text


def _container(s: str) -> dict[str, Any] | list[Any] | None:
    t = s.strip()
    if not t or t[0] not in "[{":
        return None
    try:
        v = json.loads(t)
    except ValueError:
        return None
    return v if isinstance(v, (dict, list)) else None


def _walk(v: Any) -> Any:
    if isinstance(v, dict):
        out = {}
        for key, value in v.items():
            out[_redact_str(key)] = (
                REDACTED if SECRET_KEY.fullmatch(key) and value not in (None, "") else _walk(value)
            )
        return out
    if isinstance(v, list):
        return [_walk(x) for x in v]
    if isinstance(v, str):
        return _redact_str(v)
    return v


def _redact_str(s: str) -> str:
    c = _container(s)
    if c is None:
        s = _redact_text(s)
        c = _container(s)
        if c is None:
            return s
    return json.dumps(_walk(c), ensure_ascii=False)


def redact(text: str) -> str:
    if not isinstance(text, str):
        raise TypeError("redact() は str だけを受け取ります")
    return _redact_str(text)
