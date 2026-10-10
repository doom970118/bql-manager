from pathlib import Path
import re


ROOT = Path(__file__).resolve().parents[1]
ADDON_ROOT = ROOT / "BQLManager" if (ROOT / "BQLManager").is_dir() else ROOT
LOCALE = (ADDON_ROOT / "Locale.lua").read_text(encoding="utf-8")
DEFAULTS = (ADDON_ROOT / "Defaults.lua").read_text(encoding="utf-8")
CORE = (ADDON_ROOT / "Core.lua").read_text(encoding="utf-8")
HIGHLIGHTS = (ADDON_ROOT / "Highlights.lua").read_text(encoding="utf-8")
UI = (ADDON_ROOT / "UI.lua").read_text(encoding="utf-8")
TOC = (ADDON_ROOT / "BQLManager.toc").read_text(encoding="utf-8")


def main() -> None:
    assert "Locale.lua\nDefaults.lua\nCore.lua\nHighlights.lua\nUI.lua" in TOC
    assert 'locale == "esES" or locale == "esMX"' in LOCALE
    assert 'local locale = GetLocale and GetLocale() or "enUS"' in LOCALE
    assert "local translations = self.IS_SPANISH and SPANISH or ENGLISH" in LOCALE
    assert "local text = translations[key] or key" in LOCALE

    translations = dict(
        re.findall(
            r'^\s*\["((?:\\.|[^"\\])*)"\]\s*=\s*"((?:\\.|[^"\\])*)",?$',
            LOCALE.split("local SPANISH = {", 1)[0],
            re.MULTILINE,
        )
    )
    for spanish, english in (
        ("Plantilla", "Roster"),
        ("Mordidas", "Bites"),
        ("Opciones", "Options"),
        ("Caballero de la Muerte", "Death Knight"),
        ("Restauración", "Restoration"),
        ("TE MUERDE", "BITES YOU"),
        ("MUERDE", "BITE"),
        ("Seguimiento detenido", "Tracking stopped"),
    ):
        assert translations[spanish] == english

    used_keys: set[str] = set()
    for source in (DEFAULTS, CORE, HIGHLIGHTS, UI):
        used_keys.update(re.findall(r'\bL\("((?:\\.|[^"\\])*)"', source))
    assert used_keys <= translations.keys(), sorted(used_keys - translations.keys())

    assert 'name = L("Caballero de la Muerte")' in DEFAULTS
    assert 'name = L("Restauración")' in DEFAULTS
    assert 'label = L("Marea de maná")' in DEFAULTS
    assert 'local L = function(text, ...)' in CORE
    assert 'local L = function(text, ...)' in HIGHLIGHTS
    assert 'label:SetText(L(text or ""))' in UI
    assert 'button:SetText(L(text or ""))' in UI
    assert 'row.label:SetText(L(record.label or ""))' in UI
    assert 'SetInputText(input, L(Addon.db.zones[key]))' in UI

    assert "## Notes: Organizes the roster" in TOC
    assert "## Notes-esES:" in TOC
    assert "## Notes-esMX:" in TOC

    print("Spanish locales and universal English fallback localization passed.")


if __name__ == "__main__":
    main()
