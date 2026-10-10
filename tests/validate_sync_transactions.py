from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
ADDON_ROOT = ROOT / "BQLManager" if (ROOT / "BQLManager").is_dir() else ROOT
CORE = (ADDON_ROOT / "Core.lua").read_text(encoding="utf-8")


def main() -> None:
    for snippet in (
        "Addon.outgoingSyncActive = false",
        "Addon.pendingManualSync = false",
        "completesConfiguration = completesConfiguration and true or false",
        "if item.completesConfiguration then",
        "self.outgoingSyncActive = false",
        "if self.pendingManualSync then",
        "if self.outgoingSyncActive then",
        "self.autoSyncElapsed = self.AUTO_SYNC_DELAY",
        "self.outgoingSyncActive = true",
        'self:QueueSync({ "END", syncId }, channel, category, true)',
    ):
        assert snippet in CORE

    sync = CORE.split("function Addon:SyncConfiguration", 1)[1].split(
        "function Addon:BroadcastState", 1
    )[0]
    assert "self:DiscardQueuedConfigurationSync()" not in sync
    assert "if not silent then\n        self.syncReport = nil" in sync

    auto = CORE.split("function Addon:ProcessAutoSync", 1)[1].split(
        "function Addon:ScheduleSyncUIRefresh", 1
    )[0]
    ready = auto.split("self.autoSyncElapsed < self.AUTO_SYNC_DELAY", 1)[1]
    assert ready.index("if self.outgoingSyncActive then") < ready.index(
        "self:CancelAutoSync()"
    )

    print("Rapid edits preserve the active transaction and queue the newest state afterward.")


if __name__ == "__main__":
    main()
