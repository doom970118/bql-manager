from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
ADDON_ROOT = ROOT / "BQLManager" if (ROOT / "BQLManager").is_dir() else ROOT
CORE = (ADDON_ROOT / "Core.lua").read_text(encoding="utf-8")
UI = (ADDON_ROOT / "UI.lua").read_text(encoding="utf-8")


def function_block(source: str, name: str, next_name: str) -> str:
    return source.split(f"function Addon:{name}", 1)[1].split(
        f"function Addon:{next_name}", 1
    )[0]


def main() -> None:
    authority = function_block(
        CORE, "CanEditConfiguration", "CanModifyConfiguration"
    )
    for snippet in (
        "GetNumRaidMembers",
        "IsRaidLeader and IsRaidLeader()",
        "IsRaidOfficer and IsRaidOfficer()",
        "GetNumPartyMembers",
        "IsPartyLeader and IsPartyLeader()",
        "Modo lectura: solo el líder o un asistente",
    ):
        assert snippet in authority

    modify = function_block(CORE, "CanModifyConfiguration", "GetSlotRecord")
    assert "self:CanEditConfiguration(silent)" in modify
    assert "self:IsConfigurationLocked()" in modify

    for name, next_name in (
        ("AnnounceFullPlan", "StartEncounter"),
        ("StartEncounter", "StopEncounter"),
    ):
        assert "self:CanEditConfiguration()" in function_block(
            CORE, name, next_name
        )

    stop = function_block(CORE, "StopEncounter", "ResetEncounter")
    assert 'local automatic = reason == "victory" or reason == "combat_end"' in stop
    assert "self:CanEditConfiguration(automatic)" in stop
    assert "if not automatic and not canControl then" in stop
    assert 'announce ~= false and canControl' in stop

    announce = function_block(CORE, "Announce", "Whisper")
    assert "not self:CanEditConfiguration(true)" in announce

    lock = UI.split("function UI:RefreshConfigurationLock", 1)[1].split(
        "function UI:RefreshFromSync", 1
    )[0]
    for snippet in (
        "local canEdit = Addon:CanEditConfiguration(true)",
        "local locked = encounterLocked or not canEdit",
        "self.announceButton",
        "self.validateButton",
        "self.verifySpecsButton",
        "self.clearRosterButton",
        "if encounterLocked and canEdit then",
    ):
        assert snippet in lock

    status = UI.split("function UI:Refresh()", 1)[1].split(
        "function UI:Toggle()", 1
    )[0]
    assert "Modo lectura · Solo líder/asistente puede modificar" in status
    assert "overlay.notice" not in UI

    assert "self.announceButton = announce" in UI
    assert "Addon:CanEditConfiguration(true) and Addon:IsBossName" in CORE
    assert "self:CanEditConfiguration(true) and self:IsBossName(data.sourceName)" in CORE
    assert 'event == "PARTY_MEMBERS_CHANGED"' in CORE
    assert 'event == "PLAYER_ENTERING_WORLD"' in CORE
    assert "Addon:RefreshGroupMemberProfiles()\n        Addon:RefreshUI()" in CORE
    validation = function_block(CORE, "ValidateAndReport", "GetRaidMembers")
    assert "self:CanModifyConfiguration()" in validation
    verification = function_block(
        CORE, "VerifyRosterSpecializations", "HandleInspectReady"
    )
    assert "self:CanModifyConfiguration()" in verification
    clear_roster = function_block(
        CORE, "ClearRoster", "CancelPendingSpecVerificationForSlot"
    )
    assert "self:CanModifyConfiguration()" in clear_roster

    print("Regular group and raid members are read-only while leaders and assistants retain control.")


if __name__ == "__main__":
    main()
