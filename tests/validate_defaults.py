from __future__ import annotations

from collections import Counter
from pathlib import Path
import re


ROOT = Path(__file__).resolve().parents[1]
ADDON_ROOT = ROOT / "BQLManager" if (ROOT / "BQLManager").is_dir() else ROOT
DEFAULTS = (ADDON_ROOT / "Defaults.lua").read_text(encoding="utf-8")


def main() -> None:
    slots = re.findall(r'^\s*([A-Z]+\d+) = \{ name = ', DEFAULTS, re.MULTILINE)
    bite_block = DEFAULTS.split("bites = {", 1)[1].split("    },\n    cooldowns", 1)[0]
    edges = [
        (int(wave), source, target)
        for wave, source, target in re.findall(
            r'wave = (\d+), source = "([^"]+)", target = "([^"]+)"',
            bite_block,
        )
    ]

    assert len(slots) == 25, f"Expected 25 roster slots, found {len(slots)}"
    assert len(set(slots)) == 25, "Roster slots must be unique"
    assert len(edges) == 16, f"Expected 16 bite edges, found {len(edges)}"
    assert Counter(wave for wave, _, _ in edges) == Counter({1: 1, 2: 1, 3: 2, 4: 4, 5: 8})

    infected: set[str] = set()
    for wave in range(1, 6):
        wave_edges = [edge for edge in edges if edge[0] == wave]
        sources = [source for _, source, _ in wave_edges]
        targets = [target for _, _, target in wave_edges]

        if wave == 1:
            assert sources == ["BOSS"]
        else:
            assert set(sources) == infected, (
                f"Wave {wave} sources {set(sources)} do not match infected players {infected}"
            )

        assert len(targets) == len(set(targets)), f"Wave {wave} has duplicate targets"
        assert not infected.intersection(targets), f"Wave {wave} targets an infected slot"
        assert all(target in slots for target in targets), f"Wave {wave} has an invalid target"
        infected.update(targets)

    assert len(infected) == 16, f"Expected 16 unique infected slots, found {len(infected)}"

    toc_entries = [
        line.strip()
        for line in (ADDON_ROOT / "BQLManager.toc").read_text(encoding="utf-8").splitlines()
        if line.strip() and not line.startswith("##")
    ]
    for entry in toc_entries:
        assert (ADDON_ROOT / entry).is_file(), f"TOC references missing file: {entry}"

    print("Default roster, bite tree, and TOC validation passed.")


if __name__ == "__main__":
    main()
