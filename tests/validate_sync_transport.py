from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
ADDON_ROOT = ROOT / "BQLManager" if (ROOT / "BQLManager").is_dir() else ROOT
CORE = (ADDON_ROOT / "Core.lua").read_text(encoding="utf-8")


def main() -> None:
    for snippet in (
        'local MESSAGE_SEPARATOR = "@"',
        'local PACKED_RECORD_SEPARATOR = "|"',
        'string.gsub(value, "@", "%%40")',
        'string.gsub(value, "|", "%%7C")',
        'table.concat(encoded, MESSAGE_SEPARATOR)',
        "Addon.AUTO_SYNC_DELAY = 0.25",
        "Addon.ADDON_MESSAGE_INTERVAL = 0.03",
        "Addon.MAX_ADDON_MESSAGE_BYTES = 230",
        "Addon.SYNC_DISCOVERY_DELAY = 1.0",
        "Addon.SYNC_REPORT_TIMEOUT = 10.0",
        'item.kind == "ADDON" and self.ADDON_MESSAGE_INTERVAL',
        'local target = item.target or (UnitName and UnitName("player")) or ""',
        "SendAddonMessage(self.MESSAGE_PREFIX, item.message, item.channel, target)",
        "function Addon:CreateSyncId()",
        "function Addon:RegisterSyncResponse(kind, syncId, sender, version, status)",
        "function Addon:ProcessSyncReport(elapsed)",
        "function Addon:QueuePackedSync(records, syncId, channel, category)",
        'EncodeMessage({ "PACK", syncId, index, total, payload })',
        'self:QueueSync({ "HELLO", syncId }, channel, "CONTROL")',
        '{ "BEGIN", self.DB_VERSION, syncId }',
        'tinsert(records, { "END", syncId })',
        "self:QueuePackedSync(records, syncId, channel, category)",
        'kind == "PRESENT" or kind == "ACK"',
        'self:QueueSync({ "PRESENT", fields[2], self.VERSION',
        'self:QueueSync({ "ACK", completedSyncId, self.VERSION, "APPLIED" }',
        "Addon:ReceiveSync(message, sender, channel)",
        "function Addon:ReceivePackedSync(fields, sender, distribution)",
        "Addon:ProcessSyncReport(elapsed)",
        'self:Print(L("Configuración aplicada por %s.", tostring(sender)))',
    ):
        assert snippet in CORE

    assert 'table.concat(encoded, "|")' not in CORE

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
    assert 'kind == "PACK"' in receive
    assert "self:ReceivePackedSync(fields, sender, distribution)" in receive

    print("WotLK-compatible packed transport, discovery, and sync acknowledgements passed.")


if __name__ == "__main__":
    main()
