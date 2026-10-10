from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
ADDON_ROOT = ROOT / "BQLManager" if (ROOT / "BQLManager").is_dir() else ROOT
CORE = (ADDON_ROOT / "Core.lua").read_text(encoding="utf-8")


def automatic_match(verified_spec, class_roles, slot_role):
    if verified_spec is not None:
        return verified_spec if slot_role in verified_spec[1] else None
    possible_roles = set().union(*(roles for _, roles in class_roles))
    return "" if possible_roles == {slot_role} else None


def main() -> None:
    matcher = CORE.split(
        "function Addon:GetAutomaticRaidMemberSpecForSlot", 1
    )[1].split("function Addon:GetGroupUnitTokens", 1)[0]
    for snippet in (
        "self:GetGuildMemberProfile(member.name)",
        "self.verifiedGroupSpecs and self.verifiedGroupSpecs[key]",
        "self:IsSpecAllowedForSlot(slot, specId)",
        "local possibleRoles = {}",
        "roleCount == 1 and possibleRoles[slotRole]",
    ):
        assert snippet in matcher

    importer = CORE.split("function Addon:ImportRaidRoster", 1)[1].split(
        "local function EscapeField", 1
    )[0]
    for snippet in (
        "self:RefreshGroupMemberProfiles()",
        "self:RememberPlayerProfile(member.name, member.classFile",
        "self:GetAutomaticRaidMemberSpecForSlot(candidate, slot)",
        'record.spec = matchedSpec or ""',
        "rellenados por rol",
        "siguen vacíos hasta conocer una spec compatible",
    ):
        assert snippet in importer
    assert "local nextMember" not in importer

    profiles = CORE.split("function Addon:RememberPlayerProfile", 1)[1].split(
        "function Addon:RememberRosterPlayer", 1
    )[0]
    assert "TRUSTED_SPEC_SOURCES" in profiles
    assert "incomingTrusted or not existingTrusted" in profiles

    inspection = CORE.split("function Addon:RefreshGroupMemberProfiles", 1)[1].split(
        "function Addon:UpdateAssignedPlayerSpec", 1
    )[0]
    assert 'local playerName = UnitName("player")' in inspection
    assert "self.verifiedGroupSpecs[playerKey] = specId" in inspection
    assert "not member.inGroup" in inspection

    inspect_ready = CORE.split("function Addon:HandleInspectReady", 1)[1].split(
        "function Addon:ProcessInspectQueue", 1
    )[0]
    assert "self.verifiedGroupSpecs[self:NormalizeName(pending.name)] = specId" in inspect_ready

    mage = [
        ("MAGE_ARCANE", {"RDPS"}),
        ("MAGE_FIRE", {"RDPS"}),
        ("MAGE_FROST", {"RDPS"}),
    ]
    druid = [
        ("DRUID_BALANCE", {"RDPS"}),
        ("DRUID_FERAL", {"TANK", "MDPS"}),
        ("DRUID_RESTORATION", {"HEALER"}),
    ]

    assert automatic_match(None, mage, "MDPS") is None
    assert automatic_match(None, mage, "RDPS") == ""
    assert automatic_match(("DRUID_BALANCE", {"RDPS"}), druid, "MDPS") is None
    assert automatic_match(("DRUID_BALANCE", {"RDPS"}), druid, "RDPS") == (
        "DRUID_BALANCE",
        {"RDPS"},
    )
    assert automatic_match(None, druid, "MDPS") is None
    assert automatic_match(None, druid, "RDPS") is None

    print("Raid completion matches confirmed specs and never guesses hybrid roles.")


if __name__ == "__main__":
    main()
