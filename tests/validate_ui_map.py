from __future__ import annotations

from pathlib import Path
import re


ROOT = Path(__file__).resolve().parents[1]
ADDON_ROOT = ROOT / "BQLManager" if (ROOT / "BQLManager").is_dir() else ROOT
UI_SOURCE = (ADDON_ROOT / "UI.lua").read_text(encoding="utf-8")
DEFAULTS = (ADDON_ROOT / "Defaults.lua").read_text(encoding="utf-8")


def main() -> None:
    roster_slots = set(re.findall(r'^\s*([A-Z]+\d+) = \{ name = ', DEFAULTS, re.MULTILINE))

    map_block = UI_SOURCE.split("local ZONE_MAP_ROWS = {", 1)[1].split("\n}\n\nlocal ZONE_MARKERS", 1)[0]
    rows = []
    for row_text in re.findall(r"\{([^{}]+)\}", map_block):
        rows.append([int(value) for value in re.findall(r"\d+", row_text)])

    assert len(rows) == 14, f"Expected 14 map rows, found {len(rows)}"
    assert all(len(row) == 20 for row in rows), "Every map row must contain 20 cells"
    assert {value for row in rows for value in row}.issubset({0, 2, 4, 5, 6, 7, 8})
    assert any(8 in row for row in rows), "The map must contain the BQL area"

    marker_block = UI_SOURCE.split("local ZONE_MARKERS = {", 1)[1].split("\n}\n\nlocal widgetCounter", 1)[0]
    markers = re.findall(
        r'slot = "([A-Z]+\d*|BOSS)", row = (\d+), col = (\d+), span = (\d+)',
        marker_block,
    )
    marker_slots = [slot for slot, _, _, _ in markers]
    assert len(markers) == 26, f"Expected 25 player markers plus BQL, found {len(markers)}"
    assert len(marker_slots) == len(set(marker_slots)), "Map marker slots must be unique"
    assert set(marker_slots) == roster_slots | {"BOSS"}, "Every roster slot must appear on the map"

    for slot, row, column, span in markers:
        row_number = int(row)
        column_number = int(column)
        span_number = int(span)
        assert 1 <= row_number <= 14, f"{slot} has an invalid row"
        assert 1 <= column_number <= 20, f"{slot} has an invalid column"
        assert column_number + span_number - 1 <= 20, f"{slot} extends outside the map"

    print("Zone map geometry and 25-player marker coverage passed.")


if __name__ == "__main__":
    main()
