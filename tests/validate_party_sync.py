from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
ADDON_ROOT = ROOT / "BQLManager" if (ROOT / "BQLManager").is_dir() else ROOT
CORE = (ADDON_ROOT / "Core.lua").read_text(encoding="utf-8")


def main() -> None:
    permission = CORE.split("function Addon:CanSynchronizeConfiguration", 1)[1].split(
        "\nend", 1
    )[0]
    for snippet in (
        "GetNumRaidMembers",
        "self:CanLeadRaid()",
        "GetNumPartyMembers",
        "IsPartyLeader and IsPartyLeader()",
    ):
        assert snippet in permission

    receive = CORE.split("function Addon:ReceiveSync", 1)[1].split(
        "function Addon:HandleSlashCommand", 1
    )[0]
    assert "IsAuthorizedSender" not in receive
    assert receive.index('kind == "HELLO"') < receive.index(
        "not self.db.options.acceptSync"
    )

    broadcast = CORE.split("function Addon:BroadcastState", 1)[1].split(
        "\nend", 1
    )[0]
    assert "self:CanSynchronizeConfiguration()" in broadcast
    assert "self:CanLeadRaid()" not in broadcast
    assert 'return "PARTY"' in CORE.split("function Addon:GetAddonChannel", 1)[1]

    print("Leader-sent synchronization is accepted by every regular party or raid receiver.")


if __name__ == "__main__":
    main()
