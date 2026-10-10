from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
ADDON_ROOT = ROOT / "BQLManager" if (ROOT / "BQLManager").is_dir() else ROOT
DEFAULTS = (ADDON_ROOT / "Defaults.lua").read_text(encoding="utf-8")
HIGHLIGHTS = (ADDON_ROOT / "Highlights.lua").read_text(encoding="utf-8")
UI = (ADDON_ROOT / "UI.lua").read_text(encoding="utf-8")
TOC = (ADDON_ROOT / "BQLManager.toc").read_text(encoding="utf-8")


def assignments(player_slot, wave_edges, completed=None):
    completed = completed or set()
    result = {}
    for index, (source, target) in enumerate(wave_edges, start=1):
        if index in completed:
            continue
        if source == player_slot:
            result[target] = "target"
        elif target == player_slot and source != "BOSS":
            result[source] = "biter"
    return result


def main() -> None:
    assert "biteHighlights = true" in DEFAULTS
    assert "forceFriendlyNameplates = true" in DEFAULTS
    assert "Core.lua\nHighlights.lua\nUI.lua" in TOC

    production = HIGHLIGHTS.split("function Highlights:BuildAssignments", 1)[1].split(
        "function Highlights:StartTest", 1
    )[0]
    for snippet in (
        "Addon.state.currentWave",
        "Addon.state.completed[item.index]",
        "edge.source == playerSlot",
        'edge.target, "target", "MUERDE"',
        "edge.target == playerSlot",
        'edge.source, "biter", "TE MUERDE"',
    ):
        assert snippet in production

    visuals = HIGHLIGHTS.split("function Highlights:GetOverlay", 1)[1].split(
        "function Highlights:AddSlotAssignment", 1
    )[0]
    for snippet in (
        'overlay.icon:SetTexture(biteIcon)',
        "overlay:SetBackdropBorderColor",
        "overlay.fill:SetTexture",
        "overlay:SetAlpha(pulse)",
        'overlay.label:SetText(assignment.label or style.label)',
    ):
        assert snippet in visuals

    scanning = HIGHLIGHTS.split("function Highlights:Update", 1)[1]
    assert "WorldFrame:GetChildren()" in scanning
    assert 'region:GetObjectType() == "FontString"' in HIGHLIGHTS
    assert 'child:GetObjectType() == "StatusBar"' in HIGHLIGHTS
    assert 'SetCVar(FRIENDLY_NAMEPLATE_CVAR, "1")' in HIGHLIGHTS
    assert "self.previousFriendlyNameplates" in HIGHLIGHTS

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
    assert assignments("RDPS1", wave) == {"RDPS2": "target"}
    assert assignments("RDPS2", wave) == {"RDPS1": "biter"}
    assert assignments("RDPS3", wave, {2}) == {}
    assert assignments("RDPS9", wave) == {}

    print("Personal bite icons, pulsing nameplate bars, and visual test controls passed.")


if __name__ == "__main__":
    main()
