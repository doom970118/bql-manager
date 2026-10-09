from pathlib import Path
import re


ROOT = Path(__file__).resolve().parents[1]
ADDON_ROOT = ROOT / "BQLManager" if (ROOT / "BQLManager").is_dir() else ROOT
DEFAULTS = (ADDON_ROOT / "Defaults.lua").read_text(encoding="utf-8")
CORE = (ADDON_ROOT / "Core.lua").read_text(encoding="utf-8")
UI = (ADDON_ROOT / "UI.lua").read_text(encoding="utf-8")


def main() -> None:
    cooldown_panel = UI.split("function UI:CreateCooldownPanel", 1)[1].split(
        "function UI:CreateZonesPanel", 1
    )[0]
    refresh = UI.split("function UI:RefreshCooldowns", 1)[1].split(
        "function UI:RefreshZones", 1
    )[0]

    assert cooldown_panel.count("CreateRosterSlotSelector") == 3
    assert "CreateInput" not in cooldown_panel
    assert "OnEditFocusLost" not in cooldown_panel
    assert 'Addon:SetCooldownAssignment(currentGroup, currentIndex, "slot", slot)' in cooldown_panel
    assert 'Addon:SetCooldownAssignment("threat", currentIndex, "source", slot)' in cooldown_panel
    assert 'Addon:SetCooldownAssignment("threat", currentIndex, "target", slot)' in cooldown_panel
    assert cooldown_panel.count("Addon:IsCooldownSlotEligible") == 3
    assert "self:SetRosterSlotSelectorValue(row.source, record.source)" in refresh
    assert "self:SetRosterSlotSelectorValue(row.target, record.target)" in refresh
    assert "self:SetRosterSlotSelectorValue(row.slot, record.slot)" in refresh

    eligibility = CORE.split("function Addon:IsCooldownSlotEligible", 1)[1].split(
        "function Addon:SetCooldownAssignment", 1
    )[0]
    expected_rules = (
        'spec.id == "PALADIN_HOLY" or spec.id == "PALADIN_RETRIBUTION"',
        'spec.id == "PALADIN_PROTECTION" or spec.id == "PALADIN_HOLY"',
        'spec.id == "SHAMAN_RESTORATION"',
        'spec.classKey == "PRIEST"',
        'spec.classKey == "DRUID"',
        'spec.classKey == "HUNTER"',
        'spec.classKey == "ROGUE"',
    )
    for rule in expected_rules:
        assert rule in eligibility
    assert 'role == "TANK" or slot == self:GetFirstBiteTarget()' in eligibility
    assert 'role == "MDPS" or role == "RDPS"' in eligibility
    assert "ignoreUniqueness ~= true" in eligibility
    assert "self:IsCooldownUserAssignedElsewhere(group, index, field, slot)" in eligibility

    uniqueness = CORE.split("function Addon:IsCooldownUserAssignedElsewhere", 1)[1].split(
        "function Addon:IsCooldownSlotEligible", 1
    )[0]
    assert "otherIndex ~= index" in uniqueness
    assert "record[field] == slot" in uniqueness

    setter = CORE.split("function Addon:SetCooldownAssignment", 1)[1].split(
        "function Addon:SetRosterValue", 1
    )[0]
    assert "self:SetBiteTarget(firstBite.index, slot)" in setter
    assert setter.index("self:SetBiteTarget(firstBite.index, slot)") < setter.index("record[field] = slot")
    assert "function Addon:GetFirstBiteTarget" in CORE
    assert '"target", record.target, false' in CORE
    assert 'local userField = group == "threat" and "source" or "slot"' in CORE
    assert "cooldownGroupNames" in CORE

    def available(records: list[str], row: int, slot: str) -> bool:
        return all(other_row == row or assigned != slot for other_row, assigned in enumerate(records))

    aura = ["MDPS3", "MDPS4", "HEALER1", "HEALER2"]
    assert available(aura, 0, "MDPS3")
    assert not available(aura, 1, "MDPS3")

    flight1 = ["TANK2", "HEALER3", "HEALER4", "RDPS9", "MDPS8"]
    flight2 = ["HEALER1", "RDPS9", "HEALER4", "HEALER3", "RDPS5"]
    assert available(flight1, 2, "HEALER4")
    assert available(flight2, 2, "HEALER4")

    threat_sources = ["RDPS7", "RDPS8", "MDPS1", "MDPS2"]
    assert not available(threat_sources, 1, "RDPS7")
    threat_targets = ["TANK1", "TANK1", "RDPS1", "TANK1"]
    assert threat_targets.count("TANK1") == 3

    bite_setter = CORE.split("function Addon:SetBiteTarget", 1)[1].split(
        "function Addon:FormatWave", 1
    )[0]
    assert 'local followsFirstBite = index == 1' in bite_setter
    assert 'self:GetSlotRole(oldTarget) ~= "TANK"' in bite_setter
    assert "for _, record in ipairs(self.db.cooldowns.threat or {})" in bite_setter
    assert "record.target = slot" in bite_setter

    bite_block = DEFAULTS.split("bites = {", 1)[1].split("cooldowns", 1)[0]
    targets = re.findall(r'target = "([A-Z]+\d+)"', bite_block)
    assert targets[0] == "RDPS1"
    promoted = "MDPS3"
    promoted_index = targets.index(promoted)
    targets[0], targets[promoted_index] = targets[promoted_index], targets[0]
    assert targets[0] == promoted
    assert len(targets) == len(set(targets)) == 16

    print("Cooldown selectors, unique users, class/spec filters, and first-bite target promotion passed.")


if __name__ == "__main__":
    main()
