from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
ADDON_ROOT = ROOT / "BQLManager" if (ROOT / "BQLManager").is_dir() else ROOT
CORE = (ADDON_ROOT / "Core.lua").read_text(encoding="utf-8")
UI = (ADDON_ROOT / "UI.lua").read_text(encoding="utf-8")


def main() -> None:
    drag = UI.split('frame:SetScript("OnDragStart"', 1)[1].split(
        'frame:SetScript("OnDragStop"', 1
    )[0]
    assert "not Addon.db.options.locked" in drag
    assert "IsConfigurationLocked" not in drag

    encounter_end = CORE.split("function Addon:ProcessEncounterEnd", 1)[1].split(
        "function Addon:ImportRaidRoster", 1
    )[0]
    assert "self.encounterCombatObserved" in encounter_end
    assert "self.encounterCombatCheckElapsed < 1" in encounter_end
    assert "self:IsGroupCombatActive()" in encounter_end
    assert "self.encounterEndElapsed >= 3" in encounter_end
    assert 'self:StopEncounter("combat_end", false)' in encounter_end

    summary = UI.split("function UI:RefreshSummary", 1)[1].split(
        "function UI:RefreshRoster", 1
    )[0]
    assert "Addon:GetValidationIssues()" not in summary
    assert "Addon.validationHasRun" in summary
    assert "Addon.lastValidationIssues" in summary

    options = UI.split("function UI:CreateOptionsPanel", 1)[1].split(
        "function UI:ShowTab", 1
    )[0]
    assert 'self.optionSections.general = general' in options
    assert 'self.optionSections.bites = bites' in options
    assert 'CreateCheck(general, "Auto-sincronización"' in options
    assert 'CreateCheck(bites, "Mostrar iconos locales' in options

    sync = CORE.split("function Addon:SyncConfiguration", 1)[1].split(
        "function Addon:BroadcastState", 1
    )[0]
    receive = CORE.split("function Addon:ReceiveSync", 1)[1]
    assert 'tinsert(records, { "ZONE", key, note })' in sync
    assert "self:GetRosterClassKey(slot) or" in sync
    assert "self:RememberPlayerProfile(record.name, fields[6]" in receive
    assert 'kind == "ZONE"' in receive
    assert "self.db.zones[fields[2]] = fields[3] or" in receive

    print("Live-raid window recovery, manual validation, option submenus, and reminder sync passed.")


if __name__ == "__main__":
    main()
