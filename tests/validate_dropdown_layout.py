from pathlib import Path
import re


ROOT = Path(__file__).resolve().parents[1]
ADDON_ROOT = ROOT / "BQLManager" if (ROOT / "BQLManager").is_dir() else ROOT
UI = (ADDON_ROOT / "UI.lua").read_text(encoding="utf-8")


def main() -> None:
    helpers = UI.split("local function GetLatestDropDownButton", 1)[1].split(
        "local function CreateSpecSelector", 1
    )[0]
    assert "local function ResetDropDownButtonLayout" in UI
    assert 'arrow:SetPoint("RIGHT", button, "RIGHT", -5, 0)' in helpers
    assert 'icon:SetPoint("RIGHT", button, "RIGHT", -5, 0)' in helpers
    assert "icon:SetTexCoord(0, 1, 0, 1)" in helpers
    assert "local function MoveClassMenuArrow" in helpers

    reset_calls = re.findall(r"ResetDropDownButtonLayout\(level(?:, iconCoords)?\)", UI)
    standard_resets = len(reset_calls) - 1
    assert standard_resets == 3, f"Expected three standard menu resets, found {standard_resets}"

    spec_selector = UI.split("local function CreateSpecSelector", 1)[1].split(
        "function UI:SetRosterSlotSelectorValue", 1
    )[0]
    submenu_add = spec_selector.rfind("UIDropDownMenu_AddButton(info, level)")
    submenu_reset = spec_selector.rfind("ResetDropDownButtonLayout(level)")
    assert submenu_add < submenu_reset

    roster_selector = UI.split("local function CreateRosterSlotSelector", 1)[1].split(
        "local function CreateNoteInput", 1
    )[0]
    assert "UIDropDownMenu_AddButton(info, level)\n                    ResetDropDownButtonLayout(level, iconCoords)" in roster_selector

    zone_selector = UI.split('NextName("ZoneMenu")', 1)[1].split(
        'marker:SetScript("OnClick"', 1
    )[0]
    assert "UIDropDownMenu_AddButton(info, level)\n                        ResetDropDownButtonLayout(level, iconCoords)" in zone_selector

    print("Reusable dropdown buttons reset icon anchors and texture coordinates correctly.")


if __name__ == "__main__":
    main()
