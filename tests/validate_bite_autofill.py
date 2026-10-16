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
        if wave == 1:
            for edge in wave_edges:
                edge["source"] = "BOSS"
        else:
            used = set()
            for edge in wave_edges:
                if edge["source"] in infected and edge["source"] not in used:
                    used.add(edge["source"])
                else:
                    edge["source"] = ""
            for edge in wave_edges:
                if not edge["source"]:
                    edge["source"] = next(source for source in infected if source not in used)
                    used.add(edge["source"])
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
    swapped_target = False
    for other_index, other in enumerate(edges):
        if other_index != index and other["target"] == target:
            other["target"] = old_target
            swapped_target = True
            break
    selected["target"] = target
    for edge in edges:
        if edge["source"] == old_target:
            edge["source"] = target
        elif swapped_target and edge["source"] == target:
            edge["source"] = old_target
    rebuild_sources(edges)
    return True


def set_source(edges, index, source):
    selected = edges[index]
    if selected["wave"] == 1:
        return False
    infected = {
        edge["target"]
        for edge in edges
        if edge["wave"] < selected["wave"]
    }
    if source not in infected:
        return False
    old_source = selected["source"]
    for other_index, other in enumerate(edges):
        if other_index != index and other["wave"] == selected["wave"] and other["source"] == source:
            other["source"] = old_source
            break
    selected["source"] = source
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
    assert set_source(edges, 2, "RDPS1")
    assert edges[2]["source"] == "RDPS1"
    assert edges[3]["source"] == "RDPS2"
    assert not set_source(edges, 0, "RDPS1")
    assert not set_target(edges, 3, "RDPS2")
    assert len({edge["target"] for edge in edges}) == 16

    for snippet in (
        "function Addon:RebuildBiteSources",
        'item.edge.source = "BOSS"',
        "usedSources[source]",
        "function Addon:IsBiteSourceAvailable",
        "function Addon:SetBiteSource",
        "otherEdge.source = oldSource",
        "function Addon:IsBiteTargetAvailable",
        "otherWave < selectedWave",
        "function Addon:SetBiteTarget",
        "otherEdge.target = oldTarget",
        "otherEdge.source = slot",
        "self:RebuildBiteSources()",
    ):
        assert snippet in CORE

    assert "row.source = CreateBitePlayerSelector" in UI
    assert 'Addon:SetBiteSlot(currentIndex, "source", slot)' in UI
    assert "Addon:IsBiteSourceAvailable(currentIndex, slot)" in UI
    assert "Addon:IsBiteTargetAvailable(currentIndex, slot)" in UI
    assert "self:SetBitePlayerSelectorValue(row.source, edge.source)" in UI

    print("Bite target uniqueness, searchable source swaps, and safe rebuilding passed.")


if __name__ == "__main__":
    main()
