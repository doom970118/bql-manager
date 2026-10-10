from pathlib import Path
import re


ROOT = Path(__file__).resolve().parents[1]
ADDON_ROOT = ROOT / "BQLManager" if (ROOT / "BQLManager").is_dir() else ROOT
DEFAULTS = (ADDON_ROOT / "Defaults.lua").read_text(encoding="utf-8")
CORE = (ADDON_ROOT / "Core.lua").read_text(encoding="utf-8")
UI = (ADDON_ROOT / "UI.lua").read_text(encoding="utf-8")
TOC = (ADDON_ROOT / "BQLManager.toc").read_text(encoding="utf-8")


def main() -> None:
    assert 'Addon.VERSION = "1.12.10"' in DEFAULTS
    assert "Addon.DB_VERSION = 5" in DEFAULTS
    assert 'Addon.ROLE_ORDER = { "TANK", "MDPS", "RDPS", "HEALER" }' in DEFAULTS
    assert "Addon.ROLE_MINIMUMS = { HEALER = 1 }" in DEFAULTS
    assert "Addon.ROLE_MAXIMUMS = { TANK = 2 }" in DEFAULTS
    assert "Addon.MAX_ROSTER_SIZE = 25" in DEFAULTS
    assert "## Version: 1.12.10" in TOC

    slot_block = DEFAULTS.split("Addon.SLOT_ORDER = {", 1)[1].split("}", 1)[0]
    slots = re.findall(r'"([A-Z]+\d+)"', slot_block)
    roles = {slot: re.match(r'^[A-Z]+', slot).group() for slot in slots}
    assert len(slots) == 25
    assert sum(role == "TANK" for role in roles.values()) == 2
    assert sum(role == "HEALER" for role in roles.values()) == 5

    removed_slot = next(slot for slot in reversed(slots) if roles[slot] == "HEALER")
    roles[removed_slot] = None
    assert removed_slot == "HEALER5"
    assert sum(role == "HEALER" for role in roles.values()) == 4
    assert sum(role is not None for role in roles.values()) == 24

    roles[removed_slot] = "RDPS"
    ranged_slots = [slot for slot in slots if roles[slot] == "RDPS"]
    assert ranged_slots.index(removed_slot) + 1 == 11
    assert sum(role is not None for role in roles.values()) == 25

    for function_name in (
        "GetActiveSlotOrder",
        "GetRoleCounts",
        "GetSlotLabel",
        "ResolveSlotLabel",
        "AddRosterRole",
        "RemoveRosterRole",
        "GetSlotReference",
    ):
        assert f"function Addon:{function_name}" in CORE

    assert 'record.role = ""' in CORE
    assert 'record.spec = ""' in CORE
    assert 'record.role or ""' in CORE
    assert "self:IsSlotActive(edge.source)" in CORE
    assert "self:IsSlotActive(edge.target)" in CORE

    assert "self.roleControls = {}" in UI
    assert "Addon:RemoveRosterRole(currentRole)" in UI
    assert "Addon:AddRosterRole(currentRole)" in UI
    assert "Addon:GetActiveSlotOrder()" in UI
    assert "row.slot:SetText(Addon:GetSlotLabel(slot))" in UI
    assert "Addon:SetCooldownAssignment" in UI
    assert 'Addon:SetBiteSlot(currentIndex, "target", slot)' in UI
    assert "Addon:IsBiteTargetAvailable(currentIndex, slot)" in UI
    assert "Addon:IsSlotActive(slot)" in UI

    print("Flexible roster roles, limits, labels, synchronization, and map integration passed.")


if __name__ == "__main__":
    main()
