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
    roster = re.findall(r'^\s*([A-Z]+\d+) = .* spec = "([A-Z_]+)"', DEFAULTS, re.MULTILINE)
    role_rows = re.findall(r'id = "([A-Z_]+)".*roles = \{ ([^}]+) \}', DEFAULTS)
    role_map = {
        spec_id: set(re.findall(r'(TANK|MDPS|RDPS|HEALER) = true', roles))
        for spec_id, roles in role_rows
    }
    legacy_block = DEFAULTS.split("Addon.LEGACY_SPEC_MAP = {", 1)[1].split("}", 1)[0]
    legacy_specs = re.findall(r'= "([A-Z_]+)"', legacy_block)

    assert len(classes) == 10
    assert len(set(classes)) == 10
    assert len(specs) == 30
    assert len(spec_ids) == 30
    assert all(icon.startswith("Interface\\\\Icons\\") for _, icon in specs)
    assert len(roster) == 25
    assert {spec_id for _, spec_id in roster} <= spec_ids
    assert len(role_map) == 30
    for slot, spec_id in roster:
        slot_role = re.match(r'^[A-Z]+', slot).group()
        assert slot_role in role_map[spec_id], f"{spec_id} is not compatible with {slot}"
    assert role_map["SHAMAN_ELEMENTAL"] == {"RDPS"}
    assert role_map["SHAMAN_ENHANCEMENT"] == {"MDPS"}
    assert role_map["SHAMAN_RESTORATION"] == {"HEALER"}
    assert role_map["DRUID_FERAL"] == {"TANK", "MDPS"}
    assert role_map["DEATHKNIGHT_BLOOD"] == {"TANK"}
    assert role_map["DEATHKNIGHT_FROST"] == {"TANK", "MDPS"}
    assert role_map["DEATHKNIGHT_UNHOLY"] == {"TANK", "MDPS"}
    assert len(legacy_specs) == 16
    assert set(legacy_specs) <= spec_ids

    assert "function Addon:NormalizeSpecId" in CORE
    assert "function Addon:SetRosterSpec" in CORE
    assert "function Addon:IsSpecAllowedForSlot" in CORE
    assert "function Addon:ClassHasSpecForSlot" in CORE
    assert 'field ~= "name" and field ~= "spec"' not in CORE
    assert "member.classFile or member.class" not in CORE
    assert "UIDropDownMenu_Initialize" in UI
    assert "local function MoveClassMenuArrow" in UI
    assert "MoveClassMenuArrow(level)" in UI
    assert 'arrow:SetPoint("LEFT", button, "LEFT", 1, 0)' in UI
    assert 'icon:SetPoint("LEFT", arrow, "RIGHT", 2, 0)' in UI
    assert "Addon:ClassHasSpecForSlot(classKey, slot)" in UI
    assert "Addon:IsSpecAllowedForSlot(slot, spec.id)" in UI
    assert 'info.text = "            "' in UI
    assert "info.tooltipTitle = class.name" in UI
    assert 'info.text = "      "' in UI
    assert "info.tooltipTitle = spec.name" in UI
    assert 'info.text = spec.name .. " - " .. class.name' not in UI
    assert "info.checked = selector.selectedSpecId == specId" not in UI
    assert "row.spec = CreateSpecSelector(panel, slot)" in UI
    assert 'SetRosterValue(currentSlot, "spec"' not in UI
    assert "selector:SetWidth(24)" in UI
    assert "selector.label" not in UI

    print("WotLK specialization catalog, migration, and selector validation passed.")


if __name__ == "__main__":
    main()
