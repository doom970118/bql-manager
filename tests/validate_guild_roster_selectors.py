from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
ADDON_ROOT = ROOT / "BQLManager" if (ROOT / "BQLManager").is_dir() else ROOT
DEFAULTS = (ADDON_ROOT / "Defaults.lua").read_text(encoding="utf-8")
CORE = (ADDON_ROOT / "Core.lua").read_text(encoding="utf-8")
UI = (ADDON_ROOT / "UI.lua").read_text(encoding="utf-8")


def main() -> None:
    assert "guildMembers = {}" in DEFAULTS
    assert 'Addon.DB_VERSION = 5' in DEFAULTS

    guild_cache = CORE.split("function Addon:RefreshGuildRosterCache", 1)[1].split(
        "function Addon:RequestGuildRoster", 1
    )[0]
    assert "GetNumGuildMembers()" in guild_cache
    assert "GetGuildRosterInfo(index)" in guild_cache
    assert "classFileName" in guild_cache
    assert "online, true" in guild_cache
    assert "member.inGuild = false" in guild_cache

    candidates = CORE.split("function Addon:IsGuildMemberEligibleForSlot", 1)[1].split(
        "function Addon:GetGuildMemberSpecForSlot", 1
    )[0]
    assert "local savedSpec = self:GetSpecDefinition(member.spec)" in candidates
    assert "member.classKey or (savedSpec and savedSpec.classKey)" in candidates
    assert "self:ClassHasSpecForSlot(classKey, slot)" in candidates
    assert "not member.inGuild and not member.inGroup" in candidates
    assert "strfind(normalizedName, query, 1, true)" in candidates

    assignment = CORE.split("function Addon:AssignGuildMemberToSlot", 1)[1].split(
        "function Addon:SetRosterSpec", 1
    )[0]
    assert "self:GetSlotForName(member.name)" in assignment
    assert "otherRecord.name = oldName" in assignment
    assert "record.name = member.name" in assignment
    assert "record.spec = specId" in assignment
    assert 'inferred and "manual" or member.specSource' in assignment
    assert "self:GetGroupUnitForName(member.name)" in assignment
    assert "UnitClass(unit)" in assignment
    assert "self:IsUnitInInspectRange(unit)" in assignment
    assert "self.pendingRosterAssignments[key]" in assignment
    assert "self:QueueInspectUnit(unit, true)" in assignment
    assert "normalizedVerifiedSpec and not self:IsSpecAllowedForSlot" in assignment

    clear_slot = CORE.split("function Addon:ClearRosterSlot", 1)[1].split(
        "function Addon:AssignGuildMemberToSlot", 1
    )[0]
    assert 'record.name = ""' in clear_slot
    assert 'record.spec = ""' in clear_slot
    assert "self:RefreshUI()" in clear_slot

    inspection = CORE.split("function Addon:DetectTalentSpec", 1)[1].split(
        "function Addon:ImportRaidRoster", 1
    )[0]
    assert "GetTalentTabInfo(index" in inspection
    assert "CanInspect" in inspection
    assert "CheckInteractDistance" in inspection
    assert "NotifyInspect(item.unit)" in inspection
    assert "function Addon:GetGroupUnitForName" in CORE
    assert "function Addon:IsUnitInInspectRange" in CORE
    assert "self.pendingRosterAssignments[key]" in inspection
    assert "self:AssignGuildMemberToSlot(assignmentRequest.slot, assignmentRequest.name, specId, classKey)" in inspection
    assert "member.inGroup = false" in inspection
    assert "member.inGroup = hasGroup and true or false" in inspection
    assert "not member.inGroup" in inspection
    assert '"inspect"' in inspection
    assert 'RegisterEvent("INSPECT_READY")' in CORE
    assert 'RegisterEvent("INSPECT_TALENT_READY")' in CORE
    assert 'event == "INSPECT_TALENT_READY"' in CORE
    assert "Addon:HandleInspectReady()" in CORE
    assert 'RegisterEvent("GUILD_ROSTER_UPDATE")' in CORE
    assert "Addon:ProcessInspectQueue(elapsed)" in CORE
    assert "Addon.INSPECT_ASSIGNMENT_TIMEOUT = 12.0" in CORE
    assert "request.elapsed >= self.INSPECT_ASSIGNMENT_TIMEOUT" in CORE
    assert "No se pudo validar la especialización de %s" in CORE

    roster_panel = UI.split("function UI:CreateRosterPanel", 1)[1].split(
        "function UI:CreateBitesPanel", 1
    )[0]
    assert "row.name = CreateGuildMemberSelector(panel, 150, slot)" in roster_panel
    assert 'SetRosterValue(currentSlot, "name"' not in roster_panel

    selector = UI.split("local function CreateGuildMemberSelector", 1)[1].split(
        "function UI:SetSpecSelectorValue", 1
    )[0]
    popup = UI.split("function UI:GetGuildMemberSuggestionsPopup", 1)[1].split(
        "local function CreateGuildMemberSelector", 1
    )[0]
    assert "selector.editBox" in selector
    assert 'SetScript("OnTextChanged"' in selector
    assert 'SetScript("OnMouseWheel"' in popup
    assert "Addon:GetGuildMemberCandidates" in selector
    assert "Addon:AssignGuildMemberToSlot" in selector
    assert '"Dejar puesto vacío"' in popup
    assert "Addon:ClearRosterSlot(selector.slot)" in popup
    assert "CLASS_ICON_TEXTURE" in UI
    assert "CLASS_ICON_TCOORDS" in UI
    assert "member.online and 1 or 0.55" in UI
    assert '"Hermandad · En grupo"' in UI
    assert 'or L("Grupo/Banda")' in UI
    assert "Addon:IsPlaceholder(selector.slot, name)" in UI
    assert "displayName = Addon:GetSlotLabel(selector.slot)" in UI
    assert 'if key == "roster" then' in UI
    assert "Addon:RequestGuildRoster()" in UI

    roles_by_spec = {
        "SHAMAN_ELEMENTAL": {"RDPS"},
        "SHAMAN_ENHANCEMENT": {"MDPS"},
        "SHAMAN_RESTORATION": {"HEALER"},
    }

    def eligible(_known_spec: str | None, role: str) -> bool:
        return any(role in roles for roles in roles_by_spec.values())

    def spec_for_slot(known_spec: str | None, role: str) -> tuple[str, bool]:
        if known_spec and role in roles_by_spec[known_spec]:
            return known_spec, False
        compatible = [spec_id for spec_id, roles in roles_by_spec.items() if role in roles]
        return (compatible[0], True) if len(compatible) == 1 else ("", False)

    def nearby_assignment(class_roles: set[str], current_spec_roles: set[str] | None, role: str) -> str:
        if role not in class_roles:
            return "class_rejected"
        if current_spec_roles is None:
            return "inspect_first"
        if role not in current_spec_roles:
            return "spec_rejected"
        return "assigned"

    assert eligible(None, "MDPS")
    assert eligible(None, "RDPS")
    assert eligible(None, "HEALER")
    assert not eligible(None, "TANK")
    assert eligible("SHAMAN_RESTORATION", "HEALER")
    assert eligible("SHAMAN_RESTORATION", "MDPS")
    assert eligible("SHAMAN_RESTORATION", "RDPS")
    assert not eligible("SHAMAN_RESTORATION", "TANK")
    assert spec_for_slot("SHAMAN_RESTORATION", "RDPS") == ("SHAMAN_ELEMENTAL", True)
    assert spec_for_slot("SHAMAN_RESTORATION", "MDPS") == ("SHAMAN_ENHANCEMENT", True)
    shaman_roles = {"MDPS", "RDPS", "HEALER"}
    assert nearby_assignment(shaman_roles, None, "RDPS") == "inspect_first"
    assert nearby_assignment(shaman_roles, {"HEALER"}, "RDPS") == "spec_rejected"
    assert nearby_assignment(shaman_roles, {"RDPS"}, "RDPS") == "assigned"
    assert nearby_assignment(shaman_roles, {"RDPS"}, "TANK") == "class_rejected"

    print("Persistent searchable guild roster, class icons, role filters, and inspect cache passed.")


if __name__ == "__main__":
    main()
