from pathlib import Path
import re


ROOT = Path(__file__).resolve().parents[1]
ADDON_ROOT = ROOT / "BQLManager" if (ROOT / "BQLManager").is_dir() else ROOT
CORE = (ADDON_ROOT / "Core.lua").read_text(encoding="utf-8")


def escape(value: object) -> str:
    return (
        str(value)
        .replace("%", "%25")
        .replace("@", "%40")
        .replace("|", "%7C")
        .replace("\r", "")
        .replace("\n", "%0A")
    )


def unescape(value: str) -> str:
    return (
        value.replace("%0A", "\n")
        .replace("%7C", "|")
        .replace("%40", "@")
        .replace("%25", "%")
    )


def encode(fields: list[object]) -> str:
    return "@".join(escape(field) for field in fields)


def split(message: str) -> list[str]:
    return [unescape(field) for field in message.split("@")]


def main() -> None:
    limit_match = re.search(r"Addon\.MAX_ADDON_MESSAGE_BYTES = (\d+)", CORE)
    assert limit_match
    limit = int(limit_match.group(1))
    sync_id = "leader-123456-1"

    records: list[list[object]] = [["BEGIN", 5, sync_id]]
    records.extend(
        ["ROSTER", f"RDPS{index}", f"Player{index}", "MAGE_FIRE", "RDPS"]
        for index in range(1, 26)
    )
    records.extend(
        ["BITE", index, min(5, index), "RDPS1", f"RDPS{index}"]
        for index in range(1, 17)
    )
    records.extend(
        ["CD", "aura", index, f"Aura {index}", f"HEALER{index}", "", ""]
        for index in range(1, 19)
    )
    records.extend(
        (
            ["CD", "flight1", 1, "DSAC", "", "", ""],
            ["CD", "threat", 1, "MD", "", "", "TANK1"],
            ["CD", "threat", 2, "Tricks", "", "MDPS1", ""],
        )
    )
    records.extend(
        [
            ["ZONE", "MDPS", "Melee detrás de BQL | separados @ rango 8."],
            ["ZONE", "RDPS", "Ranged en semicírculo."],
            ["ZONE", "HEALERS", "Repartidos entre ranged."],
            ["ZONE", "FLAMES", "Sombras por el borde."],
        ]
    )
    records.extend(
        ["ZPOS", f"RDPS{index}", f"RDPS{26 - index}"]
        for index in range(1, 26)
    )
    records.append(["END", sync_id])

    payloads: list[str] = []
    current = ""
    for record in records:
        encoded_record = encode(record)
        candidate = encoded_record if not current else f"{current}|{encoded_record}"
        preview = encode(["PACK", sync_id, 999, 999, candidate])
        if current and len(preview.encode("utf-8")) > limit:
            payloads.append(current)
            current = encoded_record
        else:
            current = candidate
    if current:
        payloads.append(current)

    packets = [
        encode(["PACK", sync_id, index, len(payloads), payload])
        for index, payload in enumerate(payloads, start=1)
    ]
    assert all(len(packet.encode("utf-8")) <= limit for packet in packets)
    assert len(packets) < len(records) // 2

    decoded: list[list[str]] = []
    for expected_index, packet in enumerate(packets, start=1):
        outer = split(packet)
        assert outer[:4] == ["PACK", sync_id, str(expected_index), str(len(packets))]
        decoded.extend(split(record) for record in outer[4].split("|"))

    expected = [[str(field) for field in record] for record in records]
    assert decoded == expected
    assert any(record[0] == "BITE" for record in decoded)
    assert any(record[0] == "ZPOS" for record in decoded)
    assert ["CD", "flight1", "1", "DSAC", "", "", ""] in decoded
    assert ["CD", "threat", "1", "MD", "", "", "TANK1"] in decoded
    assert ["CD", "threat", "2", "Tricks", "", "MDPS1", ""] in decoded

    for snippet in (
        "function Addon:QueuePackedSync(records, syncId, channel, category)",
        "strlen(preview) > self.MAX_ADDON_MESSAGE_BYTES",
        "index == total",
        "function Addon:ReceivePackedSync(fields, sender, distribution)",
        "packed.nextIndex ~= packetIndex",
        "self:ReceiveSync(record, sender, distribution)",
    ):
        assert snippet in CORE

    print("Packed synchronization preserves every roster, bite, cooldown, and zone record.")


if __name__ == "__main__":
    main()
