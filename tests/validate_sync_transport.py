from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
ADDON_ROOT = ROOT / "BQLManager" if (ROOT / "BQLManager").is_dir() else ROOT
CORE = (ADDON_ROOT / "Core.lua").read_text(encoding="utf-8")


def main() -> None:
    for snippet in (
        'local target = item.target or (UnitName and UnitName("player")) or ""',
        "SendAddonMessage(self.MESSAGE_PREFIX, item.message, item.channel, target)",
        "function Addon:CreateSyncId()",
        "function Addon:RegisterSyncResponse(kind, syncId, sender, version, status)",
        "function Addon:ProcessSyncReport(elapsed)",
        'self:QueueSync({ "HELLO", syncId }, channel, "CONTROL")',
        'self:QueueSync({ "BEGIN", self.DB_VERSION, syncId }, channel, category)',
        'self:QueueSync({ "END", syncId }, channel, category)',
        'kind == "PRESENT" or kind == "ACK"',
        'self:QueueSync({ "PRESENT", fields[2], self.VERSION',
        'self:QueueSync({ "ACK", completedSyncId, self.VERSION, "APPLIED" }',
        "Addon:ReceiveSync(message, sender, channel)",
        "Addon:ProcessSyncReport(elapsed)",
    ):
        assert snippet in CORE

    receive = CORE.split("function Addon:ReceiveSync", 1)[1].split(
        "function Addon:HandleSlashCommand", 1
    )[0]
    assert 'distribution ~= "PARTY"' in receive
    assert 'distribution ~= "RAID"' in receive
    assert "not self.db.options.acceptSync" in receive
    assert 'status = "DISABLED"' in receive
    assert 'status = "LOCKED"' in receive
    assert receive.index('kind == "HELLO"') < receive.index(
        "not self.db.options.acceptSync"
    )
    assert "IsAuthorizedSender" not in receive
    assert "self.receivingSyncId = fields[3]" in receive

    print("WotLK-compatible four-argument transport, discovery, and sync acknowledgements passed.")


if __name__ == "__main__":
    main()
