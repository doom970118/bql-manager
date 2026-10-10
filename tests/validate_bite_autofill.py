from pathlib import Path
import re


ROOT = Path(__file__).resolve().parents[1]
ADDON_ROOT = ROOT / "BQLManager" if (ROOT / "BQLManager").is_dir() else ROOT
DEFAULTS = (ADDON_ROOT / "Defaults.lua").read_text(encoding="utf-8")
CORE = (ADDON_ROOT / "Core.lua").read_text(encoding="utf-8")
UI = (ADDON_ROOT / "UI.lua").read_text(encoding="utf-8")


def default_edges():
    bite_block = DEFAULTS.split("bites = {", 1)[1].split("cooldowns", 1)[0]
    return [
        {"wave": int(wave), "source": source, "target": target}
        for wave, source, target in re.findall(
            r'wave = (\d+), source = "([A-Z0-9]+)", target = "([A-Z0-9]+)"',
            bite_block,
        )
    ]


def rebuild_sources(edges):
    infected = []
    for wave in range(1, 6):
        wave_edges = [edge for edge in edges if edge["wave"] == wave]
        for position, edge in enumerate(wave_edges):
            edge["source"] = "BOSS" if wave == 1 else infected[position]
        for edge in wave_edges:
            if edge["target"] not in infected:
                infected.append(edge["target"])


def set_target(edges, index, target):
    selected = edges[index]
    if any(
        other_index != index
        and other["wave"] < selected["wave"]
        and other["target"] == target
        for other_index, other in enumerate(edges)
    ):
        return False

    old_target = selected["target"]
    for other_index, other in enumerate(edges):
        if other_index != index and other["target"] == target:
            other["target"] = old_target
            break
    selected["target"] = target
    rebuild_sources(edges)
    return True


def main() -> None:
    edges = default_edges()
    assert len(edges) == 16
    rebuild_sources(edges)
    assert [edge["source"] for edge in edges] == [
        "BOSS",
        "RDPS1",
        "RDPS1", "RDPS2",
        "RDPS1", "RDPS2", "RDPS4", "RDPS5",
        "RDPS1", "RDPS2", "RDPS4", "RDPS5", "RDPS3", "RDPS6", "RDPS9", "RDPS10",
    ]

    assert set_target(edges, 0, "RDPS2")
    assert edges[0]["target"] == "RDPS2"
    assert edges[1]["target"] == "RDPS1"
    assert edges[1]["source"] == "RDPS2"
    assert edges[2]["source"] == "RDPS2"
    assert edges[3]["source"] == "RDPS1"
    assert not set_target(edges, 3, "RDPS2")
    assert len({edge["target"] for edge in edges}) == 16

    for snippet in (
        "function Addon:RebuildBiteSources",
        'item.edge.source = "BOSS"',
        'item.edge.source = infectedOrder[position] or ""',
        "function Addon:IsBiteTargetAvailable",
        "otherWave < selectedWave",
        "function Addon:SetBiteTarget",
        "otherEdge.target = oldTarget",
        "self:RebuildBiteSources()",
    ):
        assert snippet in CORE

    assert 'row.source = CreateRosterSlotSelector(panel, 94, nil, edge and edge.source or "")' in UI
    assert "Addon:IsBiteTargetAvailable(currentIndex, slot)" in UI
    assert "self:SetRosterSlotSelectorValue(row.source, edge.source)" in UI

    print("Bite target uniqueness, swaps, and automatic source rebuilding passed.")


if __name__ == "__main__":
    main()
