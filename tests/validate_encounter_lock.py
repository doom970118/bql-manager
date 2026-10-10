from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
ADDON_ROOT = ROOT / "BQLManager" if (ROOT / "BQLManager").is_dir() else ROOT
CORE = (ADDON_ROOT / "Core.lua").read_text(encoding="utf-8")
UI = (ADDON_ROOT / "UI.lua").read_text(encoding="utf-8")


def main() -> None:
    for snippet in (
        "function Addon:IsConfigurationLocked()",
        "function Addon:CanModifyConfiguration(silent)",
        "La configuración está bloqueada durante el encuentro",
        "if self.state.active and kind ~=",
        "and receivingConfiguration and self.SLOT_SET",
        "self:SetBiteTarget(firstBite.index, targetSlot, true, true)",
        "function UI:RegisterConfigurationPanel(panel)",
        "function UI:RefreshConfigurationLock()",
        "self.stopButton:Enable()",
        "self.stopButton:Disable()",
        "CloseDropDownMenus()",
        "Addon:CanModifyConfiguration(true)",
        "· Configuración bloqueada",
    ):
        assert snippet in CORE or snippet in UI

    guarded_functions = (
        "ResetDatabase",
        "SetZoneAssignment",
        "SetCooldownAssignment",
        "SetRosterValue",
        "ClearRosterSlot",
        "AssignGuildMemberToSlot",
        "SetRosterSpec",
        "AddRosterRole",
        "RemoveRosterRole",
        "SetBiteSlot",
        "ImportRaidRoster",
        "ResetEncounter",
        "SetWave",
        "SyncConfiguration",
    )
    for name in guarded_functions:
        block = CORE.split(f"function Addon:{name}", 1)[1].split("\nend", 1)[0]
        assert "CanModifyConfiguration" in block, name

    assert "allowDuringEncounter and not self:CanModifyConfiguration()" in CORE
    assert UI.count("self:RegisterConfigurationPanel(panel)") == 4
    assert "overlay:EnableMouse(true)" in UI
    assert "overlay.notice" not in UI
    assert "not Addon.db.options.locked and not Addon:IsConfigurationLocked()" in UI
    assert "self:RefreshConfigurationLock()" in UI

    print("Encounter configuration locking and automatic first-bite exception passed.")


if __name__ == "__main__":
    main()
