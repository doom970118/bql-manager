from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
ADDON_ROOT = ROOT / "BQLManager" if (ROOT / "BQLManager").is_dir() else ROOT
CORE = (ADDON_ROOT / "Core.lua").read_text(encoding="utf-8")


def main() -> None:
    authorization = CORE.split("function Addon:IsAuthorizedSender", 1)[1].split(
        "\nend", 1
    )[0]
    for snippet in (
        "GetNumPartyMembers",
        'local unit = "party" .. tostring(index)',
        "UnitName and UnitName(unit)",
        "UnitIsPartyLeader(unit)",
        "GetPartyLeaderIndex",
    ):
        assert snippet in authorization

    broadcast = CORE.split("function Addon:BroadcastState", 1)[1].split(
        "\nend", 1
    )[0]
    assert "self:CanSynchronizeConfiguration()" in broadcast
    assert "self:CanLeadRaid()" not in broadcast
    assert 'return "PARTY"' in CORE.split("function Addon:GetAddonChannel", 1)[1]

    print("Party-leader configuration and encounter-state synchronization passed.")


if __name__ == "__main__":
    main()
