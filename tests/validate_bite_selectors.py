from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
ADDON_ROOT = ROOT / "BQLManager" if (ROOT / "BQLManager").is_dir() else ROOT
DEFAULTS = (ADDON_ROOT / "Defaults.lua").read_text(encoding="utf-8")
CORE = (ADDON_ROOT / "Core.lua").read_text(encoding="utf-8")
UI = (ADDON_ROOT / "UI.lua").read_text(encoding="utf-8")


def main() -> None:
    bite_block = DEFAULTS.split("bites = {", 1)[1].split("cooldowns", 1)[0]
    assert '{ wave = 1, source = "BOSS", target = "RDPS1" }' in bite_block
    assert "function Addon:SetBiteSlot" in CORE
    assert "function Addon:RebuildBiteSources" in CORE
    assert "function Addon:IsBiteTargetAvailable" in CORE
    assert "function Addon:SetBiteTarget" in CORE
    assert 'item.edge.source = "BOSS"' in CORE
    assert 'item.edge.source = infectedOrder[position] or ""' in CORE

    assert "local function CreateRosterSlotSelector" in UI
    assert "function UI:SetRosterSlotSelectorValue" in UI
    assert "Addon:GetActiveSlotOrder()" in UI
    assert 'info.text = Addon:GetSlotLabel(slot) .. " · " .. Addon:GetSlotName(slot)' in UI
    assert "info.icon = spec and spec.icon" in UI
    assert "if not slotFilter or slotFilter(slot)" in UI

    bite_panel = UI.split("function UI:CreateBitesPanel", 1)[1].split("function UI:CreateCooldownPanel", 1)[0]
    assert "row.source = CreateRosterSlotSelector" in bite_panel
    assert 'row.source = CreateRosterSlotSelector(panel, 94, nil, edge and edge.source or "")' in bite_panel
    assert "row.target = CreateRosterSlotSelector" in bite_panel
    assert "Addon:IsBiteTargetAvailable(currentIndex, slot)" in bite_panel
    assert "row.source = CreateInput" not in bite_panel
    assert "row.target = CreateInput" not in bite_panel
    assert "OnEditFocusLost" not in bite_panel

    print("Filtered bite targets and locked automatic sources passed.")


if __name__ == "__main__":
    main()
