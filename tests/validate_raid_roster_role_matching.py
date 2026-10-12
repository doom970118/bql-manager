from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
ADDON_ROOT = ROOT / "BQLManager" if (ROOT / "BQLManager").is_dir() else ROOT
CORE = (ADDON_ROOT / "Core.lua").read_text(encoding="utf-8")


def automatic_match(saved_spec, class_roles, slot_role):
    if not any(slot_role in roles for _, roles in class_roles):
        return None
    if saved_spec is not None and slot_role in saved_spec[1]:
        return saved_spec
    compatible = [spec for spec in class_roles if slot_role in spec[1]]
    return compatible[0] if len(compatible) == 1 else ""


def main() -> None:
    matcher = CORE.split(
        "function Addon:GetAutomaticRaidMemberSpecForSlot", 1
    )[1].split("function Addon:GetGroupUnitTokens", 1)[0]
    for snippet in (
        "self:GetGuildMemberProfile(member.name)",
        "member.classFile or (profile and profile.classKey)",
        "self:ClassHasSpecForSlot(classKey, slot)",
        "self:GetGuildMemberSpecForSlot(candidate, slot)",
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
        "siguen vacíos por no encontrar una clase compatible",
    ):
        assert snippet in importer
    assert "local nextMember" not in importer

    profiles = CORE.split("function Addon:RememberPlayerProfile", 1)[1].split(
        "function Addon:RememberRosterPlayer", 1
    )[0]
    assert "TRUSTED_SPEC_SOURCES" in profiles
    assert "incomingTrusted or not existingTrusted" in profiles

    inspection = CORE.split("function Addon:RefreshGroupMemberProfiles", 1)[1].split(
        "function Addon:FinishRosterSpecVerification", 1
    )[0]
    assert "self:DetectTalentSpec" not in inspection
    assert "self:QueueInspectUnit" not in inspection

    inspect_ready = CORE.split("function Addon:HandleInspectReady", 1)[1].split(
        "function Addon:ProcessInspectQueue", 1
    )[0]
    assert "local key = self:NormalizeName(pending.name)" in inspect_ready
    assert "self.verifiedGroupSpecs[key] = specId" in inspect_ready

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
    assert automatic_match(("DRUID_BALANCE", {"RDPS"}), druid, "MDPS") == (
        "DRUID_FERAL",
        {"TANK", "MDPS"},
    )
    assert automatic_match(("DRUID_BALANCE", {"RDPS"}), druid, "RDPS") == (
        "DRUID_BALANCE",
        {"RDPS"},
    )
    assert automatic_match(None, druid, "MDPS") == ("DRUID_FERAL", {"TANK", "MDPS"})
    assert automatic_match(None, druid, "RDPS") == ("DRUID_BALANCE", {"RDPS"})

    print("Raid completion uses class capabilities without real-time specialization inspection.")


if __name__ == "__main__":
    main()
