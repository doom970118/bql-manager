from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
ADDON_ROOT = ROOT / "BQLManager" if (ROOT / "BQLManager").is_dir() else ROOT
DEFAULTS = (ADDON_ROOT / "Defaults.lua").read_text(encoding="utf-8")
CORE = (ADDON_ROOT / "Core.lua").read_text(encoding="utf-8")
UI = (ADDON_ROOT / "UI.lua").read_text(encoding="utf-8")


def main() -> None:
    assert "autoSync = false" in DEFAULTS
    for snippet in (
        "function Addon:CanSynchronizeConfiguration()",
        "function Addon:ScheduleAutoSync()",
        "function Addon:CancelAutoSync()",
        "function Addon:ProcessAutoSync(elapsed)",
        "self.receivingSync or not self:CanSynchronizeConfiguration()",
        "self.autoSyncElapsed < self.AUTO_SYNC_DELAY",
        "self:SyncConfiguration(true)",
        "function Addon:DiscardQueuedConfigurationSync()",
        'category == "CONFIG"',
        "self:DiscardQueuedConfigurationSync()",
        "Addon:ProcessAutoSync(elapsed)",
        "self:SetBiteTarget(firstBite.index, targetSlot, true, true)",
    ):
        assert snippet in CORE

    assert CORE.count("self:ScheduleAutoSync()") >= 10
    assert 'CreateCheck(general, "Auto-sincronización"' in UI
    assert "Addon:CancelAutoSync()" in UI
    assert "self.autoSyncCheck:SetChecked(Addon.db.options.autoSync)" in UI
    assert "Addon:ScheduleAutoSync()" in UI
    assert "Addon.db.zones[key] ~= value" in UI

    print("Leader-gated, debounced, replaceable automatic synchronization passed.")


if __name__ == "__main__":
    main()
