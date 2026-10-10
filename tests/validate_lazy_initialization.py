from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
ADDON_ROOT = ROOT / "BQLManager" if (ROOT / "BQLManager").is_dir() else ROOT
CORE = (ADDON_ROOT / "Core.lua").read_text(encoding="utf-8")
UI = (ADDON_ROOT / "UI.lua").read_text(encoding="utf-8")


def main() -> None:
    addon_load = CORE.split("function Addon:OnAddonLoaded", 1)[1].split(
        "Addon.eventFrame =", 1
    )[0]
    assert "self.UI:Initialize()" not in addon_load
    assert "self:RequestGuildRoster()" not in addon_load
    assert "self:RefreshGroupMemberProfiles()" not in addon_load

    entering_world = CORE.split('elseif event == "PLAYER_ENTERING_WORLD"', 1)[1].split(
        'elseif event == "GUILD_ROSTER_UPDATE"', 1
    )[0]
    assert "Addon:RequestGuildRoster()" not in entering_world
    assert "Addon:RefreshGroupMemberProfiles()" in entering_world

    toggle = UI.split("function UI:Toggle()", 1)[1].split(
        "function UI:Initialize()", 1
    )[0]
    assert "self:Initialize()" in toggle

    initialize = UI.split("function UI:Initialize()", 1)[1]
    assert "self:CreateMainFrame()" in initialize
    assert "self:Refresh()" not in initialize
    assert 'self:ShowTab("summary", true)' in UI
    assert "function UI:ShowTab(key, skipRefresh)" in UI

    assert "function UI:GetGuildMemberSuggestionsPopup()" in UI
    assert "if self.guildSuggestionsPopup then" in UI
    assert "popup.ownerSelector = selector" in UI
    assert "local selector = popup.ownerSelector" in UI
    assert UI.count('NextName("GuildSuggestions")') == 1
    assert UI.count('NextName("GuildSuggestion")') == 1
    assert "selector.suggestionButtons = popup.suggestionButtons" in UI

    print("Lazy UI initialization and shared guild selector popup passed.")


if __name__ == "__main__":
    main()
