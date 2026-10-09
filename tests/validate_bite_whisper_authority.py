from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
ADDON_ROOT = ROOT / 'BQLManager' if (ROOT / 'BQLManager').is_dir() else ROOT
CORE = (ADDON_ROOT / 'Core.lua').read_text(encoding='utf-8')


def main() -> None:
    for snippet in (
        'function Addon:CanSendAssignmentWhispers()',
        'return self:CanLeadRaid()',
        'return IsPartyLeader and IsPartyLeader()',
        'self.db.options.whisperAssignments and self:CanSendAssignmentWhispers() and wave > 1',
        'self.db.options.whisperAssignments and self:CanSendAssignmentWhispers()',
    ):
        assert snippet in CORE

    assert CORE.count('self:CanSendAssignmentWhispers()') == 2
    print('Bite assignment whispers are restricted to raid leadership or the party leader.')


if __name__ == '__main__':
    main()
