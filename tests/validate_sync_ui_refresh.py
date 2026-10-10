from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
ADDON_ROOT = ROOT / "BQLManager" if (ROOT / "BQLManager").is_dir() else ROOT
CORE = (ADDON_ROOT / "Core.lua").read_text(encoding="utf-8")
UI = (ADDON_ROOT / "UI.lua").read_text(encoding="utf-8")


def main() -> None:
    refresh = CORE.split("function Addon:RefreshUI", 1)[1].split("\nend", 1)[0]
    assert "fromSync and self.UI.RefreshFromSync" in refresh

    receive = CORE.split("function Addon:ReceiveSync", 1)[1].split(
        "function Addon:HandleSlashCommand", 1
    )[0]
    end_block = receive.split('kind == "END"', 1)[1].split(
        'kind == "ROSTER"', 1
    )[0]
    assert "self:RefreshUI(true)" in end_block

    sync_refresh = UI.split("function UI:RefreshFromSync", 1)[1].split(
        "function UI:Refresh()", 1
    )[0]
    for snippet in (
        "self.applyingSyncRefresh = true",
        "CloseDropDownMenus()",
        "self.guildSuggestionsPopup:Hide()",
        "row.name.editBox:ClearFocus()",
        "input:ClearFocus()",
        "self.applyingSyncRefresh = false",
        "self:Refresh()",
    ):
        assert snippet in sync_refresh

    assert "if UI.applyingSyncRefresh then" in UI
    for snippet in (
        "function Addon:ScheduleSyncUIRefresh()",
        "function Addon:ProcessSyncUIRefresh(elapsed)",
        "Addon.SYNC_UI_REFRESH_DELAY = 0.08",
        "Addon:ProcessSyncUIRefresh(elapsed)",
    ):
        assert snippet in CORE
    assert CORE.count("self:ScheduleSyncUIRefresh()") >= 5
    print("Completed synchronization force-refreshes focused controls on the visible tab.")


if __name__ == "__main__":
    main()
