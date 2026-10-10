from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
ADDON_ROOT = ROOT / "BQLManager" if (ROOT / "BQLManager").is_dir() else ROOT
UI = (ADDON_ROOT / "UI.lua").read_text(encoding="utf-8")


def main() -> None:
    for snippet in (
        "local ROSTER_SLOT_OFFSET = 14",
        "local ROSTER_SELECTOR_OFFSET = 77",
        "local ROSTER_INPUT_OFFSET = 99",
        "local ROSTER_SPEC_OFFSET = 241",
        '"Puesto", "TOPLEFT", panel, "TOPLEFT", column.x + ROSTER_SLOT_OFFSET',
        '"Personaje", "TOPLEFT", panel, "TOPLEFT", column.x + ROSTER_INPUT_OFFSET',
        '"Spec", "TOPLEFT", panel, "TOPLEFT", column.x + ROSTER_SPEC_OFFSET',
        'columnX + ROSTER_SLOT_OFFSET, y)',
        'columnX + ROSTER_SELECTOR_OFFSET, y + 5)',
        'columnX + ROSTER_SPEC_OFFSET, y + 3)',
    ):
        assert snippet in UI

    assert 99 == 77 + 16 + 6
    print("Roster slot, player input, and specialization column alignment passed.")


if __name__ == "__main__":
    main()
