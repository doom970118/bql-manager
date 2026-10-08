local Addon = _G.BQLManager or {}
_G.BQLManager = Addon

Addon.NAME = "BQL Manager"
Addon.VERSION = "1.1.0"
Addon.DB_VERSION = 1
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
        locked = false,
    },
    window = {
        point = "CENTER",
        relativePoint = "CENTER",
        x = 0,
        y = 0,
        width = 840,
        height = 560,
    },
    roster = {
        TANK1 = { name = "Renncor", spec = "BDK" },
        TANK2 = { name = "Opes", spec = "PPAL" },
        MDPS1 = { name = "Pulposalsero", spec = "CROGUE" },
        MDPS2 = { name = "Larslz", spec = "CROGUE" },
        MDPS3 = { name = "Bebio", spec = "RETRI" },
        MDPS4 = { name = "MDPS4", spec = "RETRI" },
        MDPS5 = { name = "Akku", spec = "FWAR" },
        MDPS6 = { name = "Urukubar", spec = "FWAR" },
        MDPS7 = { name = "Tachita", spec = "DKUNH" },
        MDPS8 = { name = "MDPS8", spec = "CAT" },
        RDPS1 = { name = "Pyroboo", spec = "FMAGE" },
        RDPS2 = { name = "RDPS2", spec = "FMAGE" },
        RDPS3 = { name = "Chimichurri", spec = "DEMO" },
        RDPS4 = { name = "Stephenson", spec = "AFFLY" },
        RDPS5 = { name = "Izanagixzz", spec = "BOOMIE" },
        RDPS6 = { name = "Youdud", spec = "BOOMIE" },
        RDPS7 = { name = "Jatzi", spec = "HUNTER" },
        RDPS8 = { name = "RDPS8", spec = "HUNTER" },
        RDPS9 = { name = "Nevado", spec = "SPRIEST" },
        RDPS10 = { name = "RDPS10", spec = "SPRIEST" },
        HEALER1 = { name = "Flytergt", spec = "HPAL" },
        HEALER2 = { name = "HEALER2", spec = "HPAL" },
        HEALER3 = { name = "Cach", spec = "DISCI" },
        HEALER4 = { name = "Orcwaldo", spec = "RSHAMMY" },
        HEALER5 = { name = "Arquicuatro", spec = "RSHAMMY" },
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
}
