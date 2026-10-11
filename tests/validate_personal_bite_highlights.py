from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
ADDON_ROOT = ROOT / "BQLManager" if (ROOT / "BQLManager").is_dir() else ROOT
DEFAULTS = (ADDON_ROOT / "Defaults.lua").read_text(encoding="utf-8")
CORE = (ADDON_ROOT / "Core.lua").read_text(encoding="utf-8")
HIGHLIGHTS = (ADDON_ROOT / "Highlights.lua").read_text(encoding="utf-8")
UI = (ADDON_ROOT / "UI.lua").read_text(encoding="utf-8")
TOC = (ADDON_ROOT / "BQLManager.toc").read_text(encoding="utf-8")


def assignments(player_slot, wave_edges, frenzy_sources=None, completed=None):
    frenzy_sources = frenzy_sources or set()
    completed = completed or set()
    result = {}
    for index, (source, target) in enumerate(wave_edges, start=1):
        if index in completed:
            continue
        if source not in frenzy_sources:
            continue
        if source == player_slot:
            result[target] = "target"
        elif target == player_slot and source != "BOSS":
            result[source] = "biter"
    return result


def main() -> None:
    assert "biteHighlights = true" in DEFAULTS
    assert "forceFriendlyNameplates" not in DEFAULTS
    assert "Core.lua\nHighlights.lua\nUI.lua" in TOC

    production = HIGHLIGHTS.split("function Highlights:BuildAssignments", 1)[1].split(
        "function Highlights:StartTest", 1
    )[0]
    for snippet in (
        "Addon.state.currentWave",
        "Addon.state.completed[item.index]",
        "self.frenzySources[edge.source]",
        "edge.source == playerSlot",
        'edge.target, "target", L("MUERDE")',
        "edge.target == playerSlot",
        'edge.source, "biter", L("TE MUERDE")',
        'self.testTargetSlot, "target", L("MORDER")',
    ):
        assert snippet in production

    visuals = HIGHLIGHTS.split("function Highlights:GetOverlay", 1)[1].split(
        "function Highlights:AddSlotAssignment", 1
    )[0]
    for snippet in (
        'overlay.icon:SetTexture(biteIcon)',
        "overlay.iconBorder:SetWidth(38)",
        "overlay.iconBorder:SetHeight(38)",
        'CreateFontString(nil, "OVERLAY", "GameFontNormal")',
        "overlay:SetBackdropBorderColor",
        "overlay.fill:SetTexture",
        "overlay:SetAlpha(pulse)",
        'overlay.label:SetText(assignment.label or style.label)',
    ):
        assert snippet in visuals

    scanning = HIGHLIGHTS.split("function Highlights:Update", 1)[1]
    assert "WorldFrame:GetChildren()" in scanning
    assert "local SCAN_INTERVAL = 0.50" in HIGHLIGHTS
    assert "self.scanElapsed < SCAN_INTERVAL" in scanning
    assert scanning.index("self:PulseVisible(pulse)") < scanning.index(
        "WorldFrame:GetChildren()"
    )
    assert scanning.index("FindHealthBar(nameplate)") < scanning.index(
        "FindAssignment(nameplate, assignments)"
    )
    assert "self.activeOverlays[overlay] = true" in HIGHLIGHTS
    assert 'region:GetObjectType() == "FontString"' in HIGHLIGHTS
    assert 'child:GetObjectType() == "StatusBar"' in HIGHLIGHTS
    assert 'SetCVar(FRIENDLY_NAMEPLATE_CVAR, "1")' in HIGHLIGHTS
    assert "GetCVar(FRIENDLY_NAMEPLATE_CVAR)" in HIGHLIGHTS
    assert "Addon.db.options.forceFriendlyNameplates" not in HIGHLIGHTS
    assert "forceNameplatesCheck" not in UI
    assert "solo se activan durante una prueba o cuando el mordedor recibe Sed de sangre frenética" in UI

    activation = HIGHLIGHTS.split("function Highlights:ActivateFrenzySource", 1)[1].split(
        "function Highlights:DeactivateFrenzySource", 1
    )[0]
    assert "Addon:GetWaveEdges(Addon.state.currentWave)" in activation
    assert "item.edge.source == slot" in activation
    assert "self.frenzySources[slot] = true" in activation
    assert "self.BiteHighlights:ActivateFrenzySource(slot)" in CORE
    assert "self.BiteHighlights:DeactivateFrenzySource(sourceSlot)" in CORE
    assert CORE.index("self:MarkBite(data.sourceName, data.destName)") < CORE.index(
        "self.BiteHighlights:DeactivateFrenzySource(sourceSlot)"
    )

    update = HIGHLIGHTS.split("function Highlights:Update", 1)[1]
    assert "local assignments = self:BuildAssignments()" in update
    assert "local visualActive = next(assignments) ~= nil" in update
    assert "self:SetFriendlyNameplates(visualActive)" in update
    assert update.index("self:SetFriendlyNameplates(visualActive)") < update.index(
        "if not visualActive then"
    )

    options = UI.split("function UI:CreateOptionsPanel", 1)[1].split(
        "function UI:ShowTab", 1
    )[0]
    for snippet in (
        'self.panels.options = panel',
        '"Probar las mordidas"',
        '"Jugador mordedor"',
        '"Jugador mordido"',
        'CreateButton(panel, "Probar"',
        "Addon.BiteHighlights:StartTest",
    ):
        assert snippet in options
    assert '{ key = "options", label = "Opciones" }' in UI
    assert "self:RefreshOptions()" in UI

    wave = [("RDPS1", "RDPS2"), ("RDPS3", "RDPS4")]
    assert assignments("RDPS1", wave) == {}
    assert assignments("RDPS2", wave) == {}
    assert assignments("RDPS1", wave, {"RDPS1"}) == {"RDPS2": "target"}
    assert assignments("RDPS2", wave, {"RDPS1"}) == {"RDPS1": "biter"}
    assert assignments("RDPS3", wave, {"RDPS3"}, {2}) == {}
    assert assignments("RDPS9", wave, {"RDPS1"}) == {}

    print("Frenzy-timed bite icons, pulsing nameplate bars, and visual test controls passed.")


if __name__ == "__main__":
    main()
