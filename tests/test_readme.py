from pathlib import Path

README = Path(__file__).resolve().parents[1] / "README.md"


def test_readme_explains_nightly_schedule_before_serve():
    text = README.read_text(encoding="utf-8")
    start = text.index("## 導入と毎晩の実行（`shipcast schedule`）")
    end = text.index("\n## ", start + 1)
    assert text.index("## 置き場の原則") < start < end
    assert end + 1 == text.index("## 日誌を読む（`shipcast serve`）")

    section = text[start:end]
    for phrase in (
        "uv tool install",
        "shipcast schedule install",
        "--load",
        "shipcast schedule uninstall",
        "--unload",
        "logs/",
        "フルディスクアクセス",
        "timezone",
    ):
        assert phrase in section


def _serve_section() -> str:
    text = README.read_text(encoding="utf-8")
    start = text.index("## 日誌を読む（`shipcast serve`）")
    end = text.index("\n## ", start + 1)
    return text[start:end]


def test_readme_explains_serve_and_tailscale():
    section = _serve_section()

    for phrase in (
        "shipcast serve",
        "127.0.0.1:8765",
        "/<repo>/<YYYY-MM-DD>",
        "design_system_dir",
        "tailscale serve --bg 8765",
        "tailscale serve --https=443 off",
        "Funnel",
    ):
        assert phrase in section


def test_readme_serve_section_comes_before_license():
    text = README.read_text(encoding="utf-8")
    assert text.index("## 日誌を読む（`shipcast serve`）") < text.index("## License")
