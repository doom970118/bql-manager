from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
ADDON_ROOT = ROOT / "BQLManager" if (ROOT / "BQLManager").is_dir() else ROOT
UI = (ADDON_ROOT / "UI.lua").read_text(encoding="utf-8")


def main() -> None:
    for snippet in (
        'local ROLE_ICON_TEXTURE = "Interface\\\\LFGFrame\\\\LFGRole"',
        "TANK = { 0.5, 0.75, 0, 1 }",
        "MDPS = { 0.25, 0.5, 0, 1 }",
        "RDPS = { 0.25, 0.5, 0, 1 }",
        "HEALER = { 0.75, 1, 0, 1 }",
        "local function SetRoleIcon(texture, role, alpha)",
        "local function SetDropDownRoleIcon(info, role)",
        "SetRoleIcon(selector.classIcon, Addon:GetSlotRole(selector.slot))",
        "SetRoleIcon(selector.icon, Addon:GetSlotRole(selector.slot))",
        "ResetDropDownButtonLayout(level, iconCoords)",
    ):
        assert snippet in UI

    assert UI.count("iconCoords = SetDropDownRoleIcon(info, Addon:GetSlotRole(slot))") == 2
    assert "INV_Misc_QuestionMark" not in UI
    print("Role-based tank, damage, and healer placeholder icons passed.")


if __name__ == "__main__":
    main()
