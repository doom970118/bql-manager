local Addon = _G.BQLManager or {}
_G.BQLManager = Addon

Addon.NAME = "BQL Manager"
Addon.VERSION = "1.13.0"
Addon.DB_VERSION = 5
Addon.MESSAGE_PREFIX = "BQLM1"

Addon.SLOT_ORDER = {
    "TANK1", "TANK2",
    "MDPS1", "MDPS2", "MDPS3", "MDPS4", "MDPS5", "MDPS6", "MDPS7", "MDPS8",
    "RDPS1", "RDPS2", "RDPS3", "RDPS4", "RDPS5", "RDPS6", "RDPS7", "RDPS8", "RDPS9", "RDPS10",
    "HEALER1", "HEALER2", "HEALER3", "HEALER4", "HEALER5",
}

Addon.SLOT_SET = {}
for _, slot in ipairs(Addon.SLOT_ORDER) do
    Addon.SLOT_SET[slot] = true
end

Addon.ZONE_POSITION_ROLES = {}
Addon.DEFAULT_ZONE_ASSIGNMENTS = {}
for _, slot in ipairs(Addon.SLOT_ORDER) do
    Addon.ZONE_POSITION_ROLES[slot] = string.match(slot, "^([A-Z]+)")
    Addon.DEFAULT_ZONE_ASSIGNMENTS[slot] = slot
end

Addon.ROLE_ORDER = { "TANK", "MDPS", "RDPS", "HEALER" }
Addon.ROLE_SET = {}
for _, role in ipairs(Addon.ROLE_ORDER) do
    Addon.ROLE_SET[role] = true
end
Addon.ROLE_MINIMUMS = { HEALER = 1 }
Addon.ROLE_MAXIMUMS = { TANK = 2 }
Addon.MAX_ROSTER_SIZE = 25

Addon.CLASS_ORDER = {
    "DEATHKNIGHT", "DRUID", "HUNTER", "MAGE", "PALADIN",
    "PRIEST", "ROGUE", "SHAMAN", "WARLOCK", "WARRIOR",
}

Addon.CLASSES = {
    DEATHKNIGHT = {
        name = "Caballero de la Muerte",
        specs = {
            { id = "DEATHKNIGHT_BLOOD", name = "Sangre", icon = "Interface\\Icons\\Spell_Deathknight_BloodPresence", roles = { TANK = true } },
            { id = "DEATHKNIGHT_FROST", name = "Escarcha", icon = "Interface\\Icons\\Spell_Deathknight_FrostPresence", roles = { TANK = true, MDPS = true } },
            { id = "DEATHKNIGHT_UNHOLY", name = "Profano", icon = "Interface\\Icons\\Spell_Deathknight_UnholyPresence", roles = { TANK = true, MDPS = true } },
        },
    },
    DRUID = {
        name = "Druida",
        specs = {
            { id = "DRUID_BALANCE", name = "Equilibrio", icon = "Interface\\Icons\\Spell_Nature_StarFall", roles = { RDPS = true } },
            { id = "DRUID_FERAL", name = "Combate feral", icon = "Interface\\Icons\\Ability_Druid_CatForm", roles = { TANK = true, MDPS = true } },
            { id = "DRUID_RESTORATION", name = "Restauración", icon = "Interface\\Icons\\Spell_Nature_HealingTouch", roles = { HEALER = true } },
        },
    },
    HUNTER = {
        name = "Cazador",
        specs = {
            { id = "HUNTER_BEASTMASTERY", name = "Dominio de bestias", icon = "Interface\\Icons\\Ability_Hunter_BeastTaming", roles = { RDPS = true } },
            { id = "HUNTER_MARKSMANSHIP", name = "Puntería", icon = "Interface\\Icons\\Ability_Marksmanship", roles = { RDPS = true } },
            { id = "HUNTER_SURVIVAL", name = "Supervivencia", icon = "Interface\\Icons\\Ability_Hunter_SwiftStrike", roles = { RDPS = true } },
        },
    },
    MAGE = {
        name = "Mago",
        specs = {
            { id = "MAGE_ARCANE", name = "Arcano", icon = "Interface\\Icons\\Spell_Holy_MagicalSentry", roles = { RDPS = true } },
            { id = "MAGE_FIRE", name = "Fuego", icon = "Interface\\Icons\\Spell_Fire_FireBolt02", roles = { RDPS = true } },
            { id = "MAGE_FROST", name = "Escarcha", icon = "Interface\\Icons\\Spell_Frost_FrostBolt02", roles = { RDPS = true } },
        },
    },
    PALADIN = {
        name = "Paladín",
        specs = {
            { id = "PALADIN_HOLY", name = "Sagrado", icon = "Interface\\Icons\\Spell_Holy_HolyBolt", roles = { HEALER = true } },
            { id = "PALADIN_PROTECTION", name = "Protección", icon = "Interface\\Icons\\Spell_Holy_DevotionAura", roles = { TANK = true } },
            { id = "PALADIN_RETRIBUTION", name = "Reprensión", icon = "Interface\\Icons\\Spell_Holy_AuraOfLight", roles = { MDPS = true } },
        },
    },
    PRIEST = {
        name = "Sacerdote",
        specs = {
            { id = "PRIEST_DISCIPLINE", name = "Disciplina", icon = "Interface\\Icons\\Spell_Holy_PowerWordShield", roles = { HEALER = true } },
            { id = "PRIEST_HOLY", name = "Sagrado", icon = "Interface\\Icons\\Spell_Holy_HolyBolt", roles = { HEALER = true } },
            { id = "PRIEST_SHADOW", name = "Sombras", icon = "Interface\\Icons\\Spell_Shadow_ShadowWordPain", roles = { RDPS = true } },
        },
    },
    ROGUE = {
        name = "Pícaro",
        specs = {
            { id = "ROGUE_ASSASSINATION", name = "Asesinato", icon = "Interface\\Icons\\Ability_Rogue_Eviscerate", roles = { MDPS = true } },
            { id = "ROGUE_COMBAT", name = "Combate", icon = "Interface\\Icons\\Ability_BackStab", roles = { MDPS = true } },
            { id = "ROGUE_SUBTLETY", name = "Sutileza", icon = "Interface\\Icons\\Ability_Stealth", roles = { MDPS = true } },
        },
    },
    SHAMAN = {
        name = "Chamán",
        specs = {
            { id = "SHAMAN_ELEMENTAL", name = "Elemental", icon = "Interface\\Icons\\Spell_Nature_Lightning", roles = { RDPS = true } },
            { id = "SHAMAN_ENHANCEMENT", name = "Mejora", icon = "Interface\\Icons\\Spell_Nature_LightningShield", roles = { MDPS = true } },
            { id = "SHAMAN_RESTORATION", name = "Restauración", icon = "Interface\\Icons\\Spell_Nature_MagicImmunity", roles = { HEALER = true } },
        },
    },
    WARLOCK = {
        name = "Brujo",
        specs = {
            { id = "WARLOCK_AFFLICTION", name = "Aflicción", icon = "Interface\\Icons\\Spell_Shadow_DeathCoil", roles = { RDPS = true } },
            { id = "WARLOCK_DEMONOLOGY", name = "Demonología", icon = "Interface\\Icons\\Spell_Shadow_Metamorphosis", roles = { RDPS = true } },
            { id = "WARLOCK_DESTRUCTION", name = "Destrucción", icon = "Interface\\Icons\\Spell_Shadow_RainOfFire", roles = { RDPS = true } },
        },
    },
    WARRIOR = {
        name = "Guerrero",
        specs = {
            { id = "WARRIOR_ARMS", name = "Armas", icon = "Interface\\Icons\\Ability_Warrior_SavageBlow", roles = { MDPS = true } },
            { id = "WARRIOR_FURY", name = "Furia", icon = "Interface\\Icons\\Ability_Warrior_InnerRage", roles = { MDPS = true } },
            { id = "WARRIOR_PROTECTION", name = "Protección", icon = "Interface\\Icons\\Ability_Warrior_DefensiveStance", roles = { TANK = true } },
        },
    },
}

Addon.SPEC_BY_ID = {}
for classKey, class in pairs(Addon.CLASSES) do
    for _, spec in ipairs(class.specs) do
        spec.classKey = classKey
        spec.className = class.name
        Addon.SPEC_BY_ID[spec.id] = spec
    end
end

Addon.LEGACY_SPEC_MAP = {
    BDK = "DEATHKNIGHT_BLOOD",
    DKUNH = "DEATHKNIGHT_UNHOLY",
    BOOMIE = "DRUID_BALANCE",
    CAT = "DRUID_FERAL",
    HUNTER = "HUNTER_MARKSMANSHIP",
    FMAGE = "MAGE_FIRE",
    HPAL = "PALADIN_HOLY",
    PPAL = "PALADIN_PROTECTION",
    RETRI = "PALADIN_RETRIBUTION",
    DISCI = "PRIEST_DISCIPLINE",
    SPRIEST = "PRIEST_SHADOW",
    CROGUE = "ROGUE_COMBAT",
    RSHAMMY = "SHAMAN_RESTORATION",
    AFFLY = "WARLOCK_AFFLICTION",
    DEMO = "WARLOCK_DEMONOLOGY",
    FWAR = "WARRIOR_FURY",
}

Addon.SPELLS = {
    VAMPIRIC_BITE = {
        [71726] = true,
    },
    ESSENCE = {
        [70867] = true,
        [71473] = true,
        [71532] = true,
        [71533] = true,
    },
    FRENZY = {
        [70877] = true,
    },
}

Addon.BOSS_NAMES = {
    ["blood-queen lana'thel"] = true,
    ["blood queen lana'thel"] = true,
    ["reina de sangre lana'thel"] = true,
    ["reina de sangre lanathel"] = true,
}

Addon.DEFAULTS = {
    version = Addon.DB_VERSION,
    options = {
        autoStart = true,
        whisperAssignments = true,
        raidWarnings = true,
        acceptSync = true,
        autoSync = false,
        locked = false,
        biteHighlights = true,
        forceFriendlyNameplates = true,
    },
    window = {
        point = "CENTER",
        relativePoint = "CENTER",
        x = 0,
        y = 0,
        width = 840,
        height = 560,
    },
    guildMembers = {},
    roster = {
        TANK1 = { name = "Renncor", spec = "DEATHKNIGHT_BLOOD" },
        TANK2 = { name = "Opes", spec = "PALADIN_PROTECTION" },
        MDPS1 = { name = "Pulposalsero", spec = "ROGUE_COMBAT" },
        MDPS2 = { name = "Larslz", spec = "ROGUE_COMBAT" },
        MDPS3 = { name = "Bebio", spec = "PALADIN_RETRIBUTION" },
        MDPS4 = { name = "MDPS4", spec = "PALADIN_RETRIBUTION" },
        MDPS5 = { name = "Akku", spec = "WARRIOR_FURY" },
        MDPS6 = { name = "Urukubar", spec = "WARRIOR_FURY" },
        MDPS7 = { name = "Tachita", spec = "DEATHKNIGHT_UNHOLY" },
        MDPS8 = { name = "MDPS8", spec = "DRUID_FERAL" },
        RDPS1 = { name = "Pyroboo", spec = "MAGE_FIRE" },
        RDPS2 = { name = "RDPS2", spec = "MAGE_FIRE" },
        RDPS3 = { name = "Chimichurri", spec = "WARLOCK_DEMONOLOGY" },
        RDPS4 = { name = "Stephenson", spec = "WARLOCK_AFFLICTION" },
        RDPS5 = { name = "Izanagixzz", spec = "DRUID_BALANCE" },
        RDPS6 = { name = "Youdud", spec = "DRUID_BALANCE" },
        RDPS7 = { name = "Jatzi", spec = "HUNTER_MARKSMANSHIP" },
        RDPS8 = { name = "RDPS8", spec = "HUNTER_MARKSMANSHIP" },
        RDPS9 = { name = "Nevado", spec = "PRIEST_SHADOW" },
        RDPS10 = { name = "RDPS10", spec = "PRIEST_SHADOW" },
        HEALER1 = { name = "Flytergt", spec = "PALADIN_HOLY" },
        HEALER2 = { name = "HEALER2", spec = "PALADIN_HOLY" },
        HEALER3 = { name = "Cach", spec = "PRIEST_DISCIPLINE" },
        HEALER4 = { name = "Orcwaldo", spec = "SHAMAN_RESTORATION" },
        HEALER5 = { name = "Arquicuatro", spec = "SHAMAN_RESTORATION" },
    },
    bites = {
        { wave = 1, source = "BOSS", target = "RDPS1" },
        { wave = 2, source = "RDPS1", target = "RDPS2" },
        { wave = 3, source = "RDPS1", target = "RDPS4" },
        { wave = 3, source = "RDPS2", target = "RDPS5" },
        { wave = 4, source = "RDPS1", target = "RDPS3" },
        { wave = 4, source = "RDPS2", target = "RDPS6" },
        { wave = 4, source = "RDPS4", target = "RDPS9" },
        { wave = 4, source = "RDPS5", target = "RDPS10" },
        { wave = 5, source = "RDPS1", target = "RDPS7" },
        { wave = 5, source = "RDPS2", target = "RDPS8" },
        { wave = 5, source = "RDPS4", target = "MDPS1" },
        { wave = 5, source = "RDPS5", target = "MDPS2" },
        { wave = 5, source = "RDPS3", target = "MDPS3" },
        { wave = 5, source = "RDPS6", target = "MDPS4" },
        { wave = 5, source = "RDPS9", target = "MDPS5" },
        { wave = 5, source = "RDPS10", target = "MDPS6" },
    },
    cooldowns = {
        aura = {
            { label = "Aura Mastery 1", slot = "MDPS3" },
            { label = "Aura Mastery 2", slot = "MDPS4" },
            { label = "Aura Mastery 3", slot = "HEALER1" },
            { label = "Aura Mastery 4", slot = "HEALER2" },
        },
        flight1 = {
            { label = "DSAC", slot = "TANK2" },
            { label = "Himno Divino", slot = "HEALER3" },
            { label = "Marea de maná", slot = "HEALER4" },
            { label = "Himno de esperanza", slot = "RDPS9" },
            { label = "Tranquilidad", slot = "MDPS8" },
        },
        flight2 = {
            { label = "DSAC", slot = "HEALER1" },
            { label = "Himno Divino", slot = "RDPS9" },
            { label = "Marea de maná", slot = "HEALER4" },
            { label = "Himno de esperanza", slot = "HEALER3" },
            { label = "Tranquilidad", slot = "RDPS5" },
        },
        threat = {
            { label = "MD", source = "RDPS7", target = "TANK1" },
            { label = "MD", source = "RDPS8", target = "TANK1" },
            { label = "Tricks", source = "MDPS1", target = "RDPS1" },
            { label = "Tricks", source = "MDPS2", target = "TANK1" },
        },
    },
    zones = {
        MDPS = "Melee agrupados detrás de BQL. Evitar la línea de los tanques.",
        RDPS = "Ranged en semicírculo, separados a /range 8.",
        HEALERS = "Repartidos entre los ranged para cubrir toda la sala.",
        FLAMES = "Con Sombras enjambradoras, salir por el borde y dejar el fuego fuera.",
    },
    zoneAssignments = Addon.DEFAULT_ZONE_ASSIGNMENTS,
}
