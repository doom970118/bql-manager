from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
ADDON_ROOT = ROOT / "BQLManager" if (ROOT / "BQLManager").is_dir() else ROOT
DEFAULTS = (ADDON_ROOT / "Defaults.lua").read_text(encoding="utf-8")
CORE = (ADDON_ROOT / "Core.lua").read_text(encoding="utf-8")
TOC = (ADDON_ROOT / "BQLManager.toc").read_text(encoding="utf-8")


def main() -> None:
    assert 'Addon.VERSION = "1.16.0"' in DEFAULTS
    assert "## Version: 1.16.0" in TOC
    assert "initialBiteDetected = false" in CORE

    detection = CORE.split("function Addon:DetectInitialBossBite", 1)[1].split(
        "function Addon:WarnFrenzy", 1
    )[0]
    assert "self.state.currentWave ~= 1" in detection
    assert "self.state.initialBiteDetected" in detection
    assert "self:IsBossName(sourceName)" in detection
    assert "self:GetSlotForName(targetName)" in detection
    assert "self:SetBiteTarget(firstBite.index, targetSlot, true, true)" in detection
    assert "no está en la plantilla" in detection
    assert "Árbol actualizado automáticamente" in detection

    combat_log = CORE.split("function Addon:HandleCombatLog", 1)[1].split(
        "function Addon:GetValidationIssues", 1
    )[0]
    detect_position = combat_log.index("self:DetectInitialBossBite")
    mark_position = combat_log.index("self:MarkBite")
    assert detect_position < mark_position
    assert "if isBiteEvent or isEssenceEvent then" in combat_log
    assert "self:IsBiteSpell" in combat_log
    assert "self:IsEssenceSpell" in combat_log

    start = CORE.split("function Addon:StartEncounter", 1)[1].split(
        "function Addon:StopEncounter", 1
    )[0]
    stop = CORE.split("function Addon:StopEncounter", 1)[1].split(
        "function Addon:ResetEncounter", 1
    )[0]
    reset = CORE.split("function Addon:ResetEncounter", 1)[1].split(
        "function Addon:SetWave", 1
    )[0]
    assert "self.state.initialBiteDetected = false" in start
    assert "self:CapturePlannedBites()" in start
    assert "self:RestorePlannedBites()" in stop
    assert "self.state.initialBiteDetected = false" in reset
    assert "self.state.initialBiteDetected = self.state.currentWave > 1" in CORE

    capture = CORE.split("function Addon:CapturePlannedBites", 1)[1].split(
        "function Addon:RestorePlannedBites", 1
    )[0]
    restore = CORE.split("function Addon:RestorePlannedBites", 1)[1].split(
        "function Addon:StartEncounter", 1
    )[0]
    assert "DeepCopy(self.db.bites)" in capture
    assert "self.db.bites = DeepCopy(snapshot)" in restore
    assert "self:RebuildBiteSources()" in restore
    assert "self.plannedBitesSnapshot = nil" in restore

    receive_state = CORE.split('elseif kind == "STATE" then', 1)[1].split(
        "self:RefreshUI()", 1
    )[0]
    assert "local wasActive = self.state.active" in receive_state
    assert "if isActive and not wasActive then" in receive_state
    assert "elseif not isActive and wasActive then" in receive_state
    assert "self:CapturePlannedBites()" in receive_state
    assert "self:RestorePlannedBites()" in receive_state

    print("Unexpected initial boss bite detection and tree adaptation passed.")


if __name__ == "__main__":
    main()
