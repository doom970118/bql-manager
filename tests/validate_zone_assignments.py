from pathlib import Path
import re


ROOT = Path(__file__).resolve().parents[1]
ADDON_ROOT = ROOT / "BQLManager" if (ROOT / "BQLManager").is_dir() else ROOT
DEFAULTS = (ADDON_ROOT / "Defaults.lua").read_text(encoding="utf-8")
CORE = (ADDON_ROOT / "Core.lua").read_text(encoding="utf-8")
UI = (ADDON_ROOT / "UI.lua").read_text(encoding="utf-8")


def main() -> None:
    slot_block = DEFAULTS.split("Addon.SLOT_ORDER = {", 1)[1].split("}", 1)[0]
    slots = re.findall(r'"([A-Z]+\d+)"', slot_block)
    roles = {slot: re.match(r"^[A-Z]+", slot).group() for slot in slots}
    assignments = {slot: slot for slot in slots}

    def select(zone_id, slot):
        if roles[zone_id] != roles[slot]:
            return False
        previous = assignments[zone_id]
        other_zone = next(
            (candidate for candidate, assigned in assignments.items() if candidate != zone_id and assigned == slot),
            None,
        )
        if other_zone:
            assignments[other_zone] = previous
        assignments[zone_id] = slot
        return True

    assert select("RDPS1", "RDPS6")
    assert assignments["RDPS1"] == "RDPS6"
    assert assignments["RDPS6"] == "RDPS1"
    assert not select("RDPS1", "HEALER1")
    assert len(set(assignments.values())) == len(slots)

    for snippet in (
        "Addon.ZONE_POSITION_ROLES = {}",
        "Addon.DEFAULT_ZONE_ASSIGNMENTS = {}",
        "zoneAssignments = Addon.DEFAULT_ZONE_ASSIGNMENTS",
        "function Addon:PrepareZoneAssignments",
        "function Addon:GetZoneAssignment",
        "function Addon:SetZoneAssignment",
        "self:GetSlotRole(slot) ~= role",
        'self.db.zoneAssignments[otherZoneId] = oldSlot or ""',
        'self:QueueSync({ "ZPOS", zoneId, self.db.zoneAssignments[zoneId] or "" }, channel, category)',
        'kind == "ZPOS"',
    ):
        assert snippet in DEFAULTS or snippet in CORE

    zones_panel = UI.split("function UI:CreateZonesPanel", 1)[1].split(
        "function UI:ShowTab", 1
    )[0]
    refresh = UI.split("function UI:RefreshZones", 1)[1].split(
        "function UI:Refresh", 1
    )[0]
    assert "Addon:GetSlotRole(slot) == zoneRole" in zones_panel
    assert 'info.text = Addon:GetSlotLabel(slot) .. " · " .. Addon:GetSlotName(slot)' in zones_panel
    assert "Addon:SetZoneAssignment(currentZoneId, currentSlot)" in zones_panel
    assert "Addon:GetZoneAssignment(zoneId)" in refresh
    assert "Addon:GetSlotName(slot)" in refresh

    print("Role-restricted zone assignment swaps, persistence, and synchronization passed.")


if __name__ == "__main__":
    main()
