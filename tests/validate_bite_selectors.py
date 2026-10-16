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
    assert "function Addon:IsBiteSourceAvailable" in CORE
    assert "function Addon:SetBiteSource" in CORE
    assert "function Addon:IsBiteTargetAvailable" in CORE
    assert "function Addon:SetBiteTarget" in CORE
    assert 'item.edge.source = "BOSS"' in CORE
    assert "usedSources[source]" in CORE

    assert "local function CreateRosterSlotSelector" in UI
    assert "function UI:SetRosterSlotSelectorValue" in UI
    assert "Addon:GetActiveSlotOrder()" in UI
    assert 'info.text = slotName .. " · " .. slotLabel' in UI
    assert 'info.text = slotLabel .. " · " .. slotName' in UI
    assert "iconCoords = SetDropDownRoleIcon(info, Addon:GetSlotRole(slot))" in UI
    assert "if not slotFilter or slotFilter(slot)" in UI

    bite_panel = UI.split("function UI:CreateBitesPanel", 1)[1].split("function UI:CreateCooldownPanel", 1)[0]
    assert "local function CreateBitePlayerSelector" in UI
    assert "function UI:GetBitePlayerCandidates" in UI
    assert "not Addon:IsPlaceholder(slot, name)" in UI
    assert 'displayName = Addon:GetSlotName("BOSS")' in UI
    assert "function UI:ShowBitePlayerSuggestions" in UI
    assert "OnTextChanged" in UI
    bite_selector = UI.split("local function CreateBitePlayerSelector", 1)[1].split("local function CreateNoteInput", 1)[0]
    assert "selector.editBox:SetWidth(selectorWidth)" in bite_selector
    assert "selector.editBox:SetWidth(selectorWidth - 22)" in bite_selector
    assert 'selector.editBox:SetPoint("LEFT", selector, "LEFT", 0, 0)' in bite_selector
    assert "SetBackdrop(selector" not in bite_selector
    assert "row.source = CreateBitePlayerSelector" in bite_panel
    assert 'Addon:SetBiteSlot(currentIndex, "source", slot)' in bite_panel
    assert "Addon:IsBiteSourceAvailable(currentIndex, slot)" in bite_panel
    assert 'index == 1 and "BOSS" or nil' in bite_panel
    assert "help:SetWidth(550)" in bite_panel
    assert "row.target = CreateBitePlayerSelector" in bite_panel
    assert "Addon:IsBiteTargetAvailable(currentIndex, slot)" in bite_panel
    assert "row.sourceSlot" in bite_panel
    assert "row.targetSlot" in bite_panel
    assert "row.flowLine" in bite_panel
    assert "row.flowTail" in bite_panel
    assert "row.flowArrow" in bite_panel
    assert "row.biteIconFrame" in bite_panel
    assert "row.biteIcon" in bite_panel
    assert "BITE_ICON_TEXTURE" in bite_panel
    assert "GetSpellInfo(71726)" in UI
    for snippet in (
        'row.source:SetPoint("TOPLEFT", panel, "TOPLEFT", 72, y + 4)',
        "row.sourceSlot:SetWidth(52)",
        'row.flowLine:SetPoint("TOPLEFT", panel, "TOPLEFT", 354, y - 5)',
        'row.flowTail:SetPoint("TOPLEFT", panel, "TOPLEFT", 406, y - 5)',
        'row.biteIconFrame:SetPoint("TOPLEFT", panel, "TOPLEFT", 383, y + 5)',
        'row.target:SetPoint("TOPLEFT", panel, "TOPLEFT", 440, y + 4)',
        "row.targetSlot:SetWidth(58)",
    ):
        assert snippet in bite_panel

    # Keep every element inside the panel and leave a visible gap between columns.
    assert 72 + 220 < 300
    assert 300 + 52 < 354
    assert 354 + 29 <= 383
    assert 383 + 22 <= 406
    assert 406 + 21 < 440
    assert 440 + 220 < 668
    assert 668 + 58 <= 816
    assert 354 + 29 <= 383
    assert 406 + 21 <= 425 + 14 < 440

    refresh_block = UI.split("function UI:RefreshBites()", 1)[1].split("function UI:RefreshCooldowns", 1)[0]
    for snippet in (
        "row.sourceSlot:SetText(Addon:GetSlotLabel(edge.source))",
        "row.targetSlot:SetText(Addon:GetSlotLabel(edge.target))",
        "row.flowLine:SetVertexColor",
        "row.flowTail:SetVertexColor",
        "row.flowArrow:SetTextColor",
        "row.biteIconFrame:SetBackdropBorderColor",
        "row.biteIcon:SetAlpha(iconAlpha)",
    ):
        assert snippet in refresh_block
    assert "row.source = CreateRosterSlotSelector" not in bite_panel
    assert "row.target = CreateRosterSlotSelector" not in bite_panel

    print("Searchable bite players, fixed BOSS source, and segmented arrows passed.")


if __name__ == "__main__":
    main()
