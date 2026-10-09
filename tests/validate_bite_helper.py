from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
ADDON_ROOT = ROOT / 'BQLManager' if (ROOT / 'BQLManager').is_dir() else ROOT
DEFAULTS = (ADDON_ROOT / 'Defaults.lua').read_text(encoding='utf-8')
CORE = (ADDON_ROOT / 'Core.lua').read_text(encoding='utf-8')
UI = (ADDON_ROOT / 'UI.lua').read_text(encoding='utf-8')


def main() -> None:
    for snippet in (
        'function Addon:GetLocalBiteAssignment()',
        'UnitName(\'player\')',
        'action = \'BITE\'',
        'action = \'BITTEN_BY\'',
        'not self.state.completed[item.index]',
        'function Addon:CanSendAssignmentWhispers()',
        'self.db.options.whisperAssignments and self:CanSendAssignmentWhispers()',
        'function UI:CreateBiteHelper()',
        'function UI:RefreshBiteHelper()',
        'self.biteHelperAction:SetText(\'MORDER A\')',
        'self.biteHelperAction:SetText(\'TE MUERDE\')',
        'self:RefreshBiteHelper()',
    ):
        assert snippet in CORE or snippet in UI

    assert 'biteHelper = {' in DEFAULTS
    assert 'frame:RegisterForDrag(\'LeftButton\')' in UI
    assert 'Addon.db.biteHelper.x = x' in UI and 'Addon.db.biteHelper.y = y' in UI
    assert 'self.biteHelperFrame:Hide()' in UI
    assert CORE.count('self:CanSendAssignmentWhispers()') == 2
    print('Local bite helper assignment, visibility, and persistent movement passed.')


if __name__ == '__main__':
    main()
