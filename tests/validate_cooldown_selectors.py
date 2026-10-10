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
    assert cooldown_panel.count("end, nil, true)") == 3
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
    assert 'if slot == "" then' in eligibility
    assert eligibility.index('if slot == "" then') < eligibility.index("self:IsSlotActive(slot)")
    assert "self:GetCooldownUserAssignment(group, index, field, slot)" in eligibility
    assert "self:IsCooldownSlotAssignedInOtherFlight(group, otherIndex, record.slot)" in eligibility

    assignment_lookup = CORE.split("function Addon:GetCooldownUserAssignment", 1)[1].split(
        "function Addon:IsCooldownSlotAssignedInOtherFlight", 1
    )[0]
    assert "otherIndex ~= index" in assignment_lookup
    assert "record[field] == slot" in assignment_lookup
    assert "return otherIndex, record" in assignment_lookup

    cross_flight = CORE.split("function Addon:IsCooldownSlotAssignedInOtherFlight", 1)[1].split(
        "function Addon:IsCooldownSlotEligible", 1
    )[0]
    assert 'group ~= "flight1" and group ~= "flight2"' in cross_flight
    assert 'group == "flight1" and "flight2" or "flight1"' in cross_flight
    assert "self:Trim(otherRecord.slot) == slot" in cross_flight
    assert "self:IsCooldownSlotAssignedInOtherFlight(group, index, slot)" in eligibility

    setter = CORE.split("function Addon:SetCooldownAssignment", 1)[1].split(
        "function Addon:SetRosterValue", 1
    )[0]
    assert "self:SetBiteTarget(firstBite.index, slot)" in setter
    assert setter.index("self:SetBiteTarget(firstBite.index, slot)") < setter.index("record[field] = slot")
    assert 'local userField = group == "threat" and "source" or "slot"' in setter
    assert "self:GetCooldownUserAssignment(group, index, field, slot)" in setter
    assert "otherRecord[field] = record[field]" in setter
    assert setter.index("otherRecord[field] = record[field]") < setter.index("record[field] = slot")
    assert "function Addon:GetFirstBiteTarget" in CORE
    assert '"target", record.target, false' in CORE
    assert 'local userField = group == "threat" and "source" or "slot"' in CORE
    assert "cooldownGroupNames" in CORE
    assert 'L("%s no puede usar %s en ambos vuelos."' in CORE

    def swap_assignment(records: list[str], row: int, slot: str) -> None:
        old_slot = records[row]
        if slot:
            for other_row, assigned in enumerate(records):
                if other_row != row and assigned == slot:
                    records[other_row] = old_slot
                    break
        records[row] = slot

    aura = ["MDPS3", "MDPS4", "HEALER1", "HEALER2"]
    swap_assignment(aura, 1, "MDPS3")
    assert aura == ["MDPS4", "MDPS3", "HEALER1", "HEALER2"]
    assert len(aura) == len(set(aura))
    swap_assignment(aura, 1, "")
    assert aura == ["MDPS4", "", "HEALER1", "HEALER2"]
    swap_assignment(aura, 0, "")
    assert aura == ["", "", "HEALER1", "HEALER2"]

    flight1 = ["TANK2", "HEALER3", "HEALER4", "RDPS9", "MDPS8"]
    flight2 = ["HEALER1", "RDPS9", "", "HEALER3", "RDPS5"]
    swap_assignment(flight1, 3, "HEALER3")
    assert flight1 == ["TANK2", "RDPS9", "HEALER4", "HEALER3", "MDPS8"]
    assert flight2[2] == ""

    def available_in_flight(other_flight: list[str], row: int, slot: str) -> bool:
        return not slot or other_flight[row] != slot

    assert not available_in_flight(flight1, 0, "TANK2")
    assert available_in_flight(flight1, 0, "HEALER1")
    assert available_in_flight(flight1, 0, "")

    indirect_flight1 = ["HEALER1", "HEALER2"]
    indirect_flight2 = ["HEALER3", "HEALER1"]
    selected_slot = indirect_flight1[1]
    displaced_slot = indirect_flight1[0]
    assert indirect_flight2[0] != selected_slot
    assert indirect_flight2[1] == displaced_slot

    flight1_defaults = DEFAULTS.split("flight1 = {", 1)[1].split("flight2 = {", 1)[0]
    flight2_defaults = DEFAULTS.split("flight2 = {", 1)[1].split("threat = {", 1)[0]
    flight1_slots = re.findall(r'slot = "([A-Z0-9]*)"', flight1_defaults)
    flight2_slots = re.findall(r'slot = "([A-Z0-9]*)"', flight2_defaults)
    assert len(flight1_slots) == len(flight2_slots) == 5
    assert all(not left or not right or left != right for left, right in zip(flight1_slots, flight2_slots))

    threat_sources = ["RDPS7", "RDPS8", "MDPS1", "MDPS2"]
    swap_assignment(threat_sources, 1, "RDPS7")
    assert threat_sources == ["RDPS8", "RDPS7", "MDPS1", "MDPS2"]
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

    print("Cooldown selectors, empty assignments, cross-flight restrictions, occupied-user swaps, class/spec filters, and first-bite target promotion passed.")


if __name__ == "__main__":
    main()
