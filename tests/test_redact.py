import json

import pytest

from shipcast.redact import redact

MASK = "[伏せた]"
GITHUB = "ghp_" + "DUMMYEXAMPLE" * 2
PAT = "github_pat_" + "DUMMY_EXAMPLE" * 2
OPENAI = "sk-" + "DUMMY_EXAMPLE_0000"
AWS = "AKIA" + "DUMMYEXAMPLE0000"
SLACK = "xoxb-" + "DUMMY-EXAMPLE"
GOOGLE = "AIza" + "DUMMY" * 7
JWT = "eyJ" + "DUMMYEXAMPLE" + ".e30." + "0000"


@pytest.mark.parametrize(
    ("source", "expected"),
    [
        (
            "before\n-----BEGIN RSA PRIVATE KEY-----\nDUMMY\n-----END RSA PRIVATE KEY-----\nafter",
            f"before\n{MASK}\nafter",
        ),
        (
            "before\n-----BEGIN PRIVATE KEY-----\nDUMMY\n-----END RSA PRIVATE KEY-----\nafter",
            f"before\n{MASK}",
        ),
        ("before\n-----BEGIN PRIVATE KEY-----\nDUMMY", f"before\n{MASK}"),
        (
            "before https://demo:DUMMY@example.test/path after",
            f"before https://{MASK}@example.test/path after",
        ),
        ("before Bearer " + "DUMMYEXAMPLE" + " after", f"before Bearer {MASK} after"),
        ('export DB_PASSWORD="DUMMY" && keep', f'export DB_PASSWORD="{MASK}" && keep'),
        ("api_token: DUMMY", f"api_token: {MASK}"),
        ("password: DUMMY EXAMPLE 0000", f"password: {MASK}"),
        ("DB_PASSWORD=DUMMY]EXAMPLE", f"DB_PASSWORD={MASK}"),
        ("DB_PASSWORD=DUMMY}0000", f"DB_PASSWORD={MASK}"),
        ('"password": "DUMMY', f'"password": {MASK}'),
        (
            'payload: {"api_token": "DUMMY", "title": "keep"}',
            f'payload: {{"api_token": "{MASK}", "title": "keep"}}',
        ),
        (r"{\"password\": \"DUMMY\"", r"{\"password\": \"" + MASK + r"\""),
        (f"PASSWORD={MASK}DUMMY_EXAMPLE", f"PASSWORD={MASK}"),
        (r"PASSWORD=DUMMY\nEXAMPLE", f"PASSWORD={MASK}"),
        ("TOKEN=", "TOKEN="),
        ("TOKEN= \t ", "TOKEN= \t "),
        ("TOKEN=\r\n", f"TOKEN={MASK}\n"),
        ("TOKEN=　", f"TOKEN={MASK}"),
        *[
            (f"前{token}後", f"前{MASK}後")
            for token in (GITHUB, PAT, OPENAI, AWS, SLACK, GOOGLE, JWT)
        ],
        ("risk-assessment-framework", "risk-assessment-framework"),
        ('日本語の文\nprint("こんにちは")', '日本語の文\nprint("こんにちは")'),
    ],
)
def test_redact_text(source, expected):
    assert redact(source) == expected
    assert redact(expected) == expected


@pytest.mark.parametrize(
    ("source", "expected"),
    [
        ({"password": "DUMMY", "title": "keep"}, {"password": MASK, "title": "keep"}),
        (
            {"max_tokens": 20, "credentials": {"user": "demo"}, "token": None, "secret": ""},
            {"max_tokens": MASK, "credentials": MASK, "token": None, "secret": ""},
        ),
        ({GITHUB: "keep"}, {MASK: "keep"}),
        (
            [json.dumps({GITHUB: "keep"})],
            [json.dumps({MASK: "keep"}, ensure_ascii=False)],
        ),
        *[([f"トークン{token}"], [f"トークン{MASK}"]) for token in (GITHUB, AWS, OPENAI)],
        (
            {
                "body": "応答: " + json.dumps({"password": 'DUMMY"EXAMPLE', "user": "demo"}),
                "events": ["keep"],
            },
            {"body": f'応答: {{"password": "{MASK}", "user": "demo"}}', "events": ["keep"]},
        ),
        (
            [json.dumps({"password": 'DUMMY"EXAMPLE', "user": "demo"}), "keep"],
            [json.dumps({"password": MASK, "user": "demo"}, ensure_ascii=False), "keep"],
        ),
        (["PASSWORD=DUMMY\nnormal line"], [f"PASSWORD={MASK}\nnormal line"]),
    ],
)
def test_redact_json(source, expected):
    result = redact(json.dumps(source))
    assert json.loads(result) == expected
    assert redact(result) == result


def test_redact_normalizes_json_repaired_by_text_rule():
    result = redact(r'{"password":"DUMMY\qEXAMPLE","x":1}')
    assert result == f'{{"password": "{MASK}", "x": 1}}'
    assert redact(result) == result


def test_redact_rejects_non_string():
    with pytest.raises(TypeError):
        redact(None)
