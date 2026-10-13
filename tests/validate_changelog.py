from pathlib import Path
import re


ROOT = Path(__file__).resolve().parents[1]
ADDON_ROOT = ROOT / "BQLManager" if (ROOT / "BQLManager").is_dir() else ROOT
DEFAULTS = (ADDON_ROOT / "Defaults.lua").read_text(encoding="utf-8")
CHANGELOG = (ROOT / "CHANGELOG.md").read_text(encoding="utf-8")
README = (ROOT / "README.md").read_text(encoding="utf-8")


def main() -> None:
    version_match = re.search(r'Addon\.VERSION = "([^"]+)"', DEFAULTS)
    assert version_match, "No se encontró Addon.VERSION"
    version = version_match.group(1)

    assert "## [Sin publicar]" in CHANGELOG
    assert f"## [{version}] - " in CHANGELOG
    assert CHANGELOG.index("## [Sin publicar]") < CHANGELOG.index(f"## [{version}] - ")
    assert "[CHANGELOG.md](CHANGELOG.md)" in README

    print(f"Changelog includes current addon version {version} and is linked from README.")


if __name__ == "__main__":
    main()
