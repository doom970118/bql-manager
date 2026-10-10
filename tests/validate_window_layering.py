from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
ADDON_ROOT = ROOT / "BQLManager" if (ROOT / "BQLManager").is_dir() else ROOT
UI = (ADDON_ROOT / "UI.lua").read_text(encoding="utf-8")


def main() -> None:
    main_frame = UI.split("function UI:CreateMainFrame", 1)[1].split(
        "function UI:CreateSummaryPanel", 1
    )[0]
    assert 'frame:SetFrameStrata("MEDIUM")' in main_frame
    assert 'frame:SetFrameStrata("DIALOG")' not in main_frame
    assert "frame:SetToplevel(true)" in main_frame
    assert 'frame:SetScript("OnMouseDown"' in main_frame
    assert 'frame:SetScript("OnShow"' in main_frame
    assert main_frame.count("self:Raise()") == 2
    assert "self.lockCheck.label:GetStringWidth()" in main_frame
    assert 'self.lockCheck:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -(lockLabelWidth + 54), -42)' in main_frame
    assert 'self.lockCheck:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -48, -42)' not in main_frame

    zones_panel = UI.split("function UI:CreateZonesPanel", 1)[1].split(
        "function UI:ShowTab", 1
    )[0]
    help_start = zones_panel.index('local help = CreateText(panel, "GameFontDisableSmall"')
    help_end = zones_panel.index("help:SetTextColor", help_start)
    help_block = zones_panel[help_start:help_end]
    assert "help:SetWidth(275)" in help_block
    assert "help:SetHeight(24)" in help_block
    assert 'help:SetJustifyH("LEFT")' in help_block
    assert 'help:SetJustifyV("TOP")' in help_block

    print("Non-modal window layering and bounded zone help text passed.")


if __name__ == "__main__":
    main()
