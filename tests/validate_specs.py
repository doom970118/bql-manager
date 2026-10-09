from pathlib import Path
import re


ROOT = Path(__file__).resolve().parents[1]
ADDON_ROOT = ROOT / "BQLManager" if (ROOT / "BQLManager").is_dir() else ROOT
DEFAULTS = (ADDON_ROOT / "Defaults.lua").read_text(encoding="utf-8")
CORE = (ADDON_ROOT / "Core.lua").read_text(encoding="utf-8")
UI = (ADDON_ROOT / "UI.lua").read_text(encoding="utf-8")


def main() -> None:
    order = DEFAULTS.split("Addon.CLASS_ORDER = {", 1)[1].split("}", 1)[0]
    classes = re.findall(r'"([A-Z]+)"', order)
    specs = re.findall(r'id = "([A-Z_]+)", name = "[^"]+", icon = "([^"]+)"', DEFAULTS)
    spec_ids = {spec_id for spec_id, _ in specs}
    roster_specs = re.findall(r'^\s*[A-Z]+\d+ = .* spec = "([A-Z_]+)"', DEFAULTS, re.MULTILINE)
    legacy_block = DEFAULTS.split("Addon.LEGACY_SPEC_MAP = {", 1)[1].split("}", 1)[0]
    legacy_specs = re.findall(r'= "([A-Z_]+)"', legacy_block)

    assert len(classes) == 10
    assert len(set(classes)) == 10
    assert len(specs) == 30
    assert len(spec_ids) == 30
    assert all(icon.startswith("Interface\\\\Icons\\") for _, icon in specs)
    assert len(roster_specs) == 25
    assert set(roster_specs) <= spec_ids
    assert len(legacy_specs) == 16
    assert set(legacy_specs) <= spec_ids

    assert "function Addon:NormalizeSpecId" in CORE
    assert "function Addon:SetRosterSpec" in CORE
    assert 'field ~= "name" and field ~= "spec"' not in CORE
    assert "member.classFile or member.class" not in CORE
    assert "UIDropDownMenu_Initialize" in UI
    assert "row.spec = CreateSpecSelector(panel, slot)" in UI
    assert 'SetRosterValue(currentSlot, "spec"' not in UI
    assert "selector:SetWidth(24)" in UI
    assert "selector.label" not in UI

    print("WotLK specialization catalog, migration, and selector validation passed.")


if __name__ == "__main__":
    main()
