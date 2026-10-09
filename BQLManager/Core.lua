local Addon = _G.BQLManager
if not Addon then
    return
end

local floor = math.floor
local ipairs = ipairs
local pairs = pairs
local strfind = string.find
local strformat = string.format
local strgmatch = string.gmatch
local strlower = string.lower
local strsub = string.sub
local strupper = string.upper
local tinsert = table.insert
local tremove = table.remove
local type = type
local tostring = tostring

Addon.state = {
    active = false,
    currentWave = 1,
    completed = {},
    startedAt = nil,
}

Addon.messageQueue = {}
Addon.queueElapsed = 0

local function DeepCopy(value)
    if type(value) ~= "table" then
        return value
    end

    local copy = {}
    for key, child in pairs(value) do
        copy[DeepCopy(key)] = DeepCopy(child)
    end
    return copy
end

local function MergeDefaults(destination, defaults)
    for key, value in pairs(defaults) do
        if type(value) == "table" then
            if type(destination[key]) ~= "table" then
                destination[key] = {}
            end
            MergeDefaults(destination[key], value)
        elseif destination[key] == nil then
            destination[key] = value
        end
    end
end

function Addon:Trim(value)
    value = tostring(value or "")
    value = string.gsub(value, "^%s+", "")
    value = string.gsub(value, "%s+$", "")
    return value
end

function Addon:NormalizeName(name)
    name = self:Trim(name)
    name = string.gsub(name, "%-.*$", "")
    return strlower(name)
end

function Addon:NormalizeSpecId(value)
    local normalized = strupper(self:Trim(value))
    if self.SPEC_BY_ID[normalized] then
        return normalized
    end
    return self.LEGACY_SPEC_MAP[normalized]
end

function Addon:GetSpecDefinition(specId)
    return self.SPEC_BY_ID[self:NormalizeSpecId(specId) or ""]
end

function Addon:GetSlotRole(slot)
    if not self.SLOT_SET[slot] then
        return nil
    end

    local record = self.db and self.db.roster and self.db.roster[slot]
    if record and record.role ~= nil then
        local role = strupper(self:Trim(record.role))
        return self.ROLE_SET[role] and role or nil
    end
    return string.match(slot, "^([A-Z]+)")
end

function Addon:IsSlotActive(slot)
    return self.SLOT_SET[slot] and self:GetSlotRole(slot) ~= nil
end

function Addon:GetActiveSlotOrder()
    local result = {}
    for _, role in ipairs(self.ROLE_ORDER) do
        for _, slot in ipairs(self.SLOT_ORDER) do
            if self:GetSlotRole(slot) == role then
                tinsert(result, slot)
            end
        end
    end
    return result
end

function Addon:GetRoleCounts()
    local counts = { TANK = 0, MDPS = 0, RDPS = 0, HEALER = 0 }
    for _, slot in ipairs(self.SLOT_ORDER) do
        local role = self:GetSlotRole(slot)
        if role then
            counts[role] = counts[role] + 1
        end
    end
    return counts
end

function Addon:GetActiveRosterSize()
    return #self:GetActiveSlotOrder()
end

function Addon:GetSlotLabel(slot)
    if slot == "BOSS" then
        return "BOSS"
    end

    local role = self:GetSlotRole(slot)
    if not role then
        return tostring(slot or "?")
    end

    local number = 0
    for _, activeSlot in ipairs(self:GetActiveSlotOrder()) do
        if self:GetSlotRole(activeSlot) == role then
            number = number + 1
        end
        if activeSlot == slot then
            return role .. tostring(number)
        end
    end
    return tostring(slot or "?")
end

function Addon:ResolveSlotLabel(value, allowBoss)
    local normalized = strupper(self:Trim(value))
    if allowBoss and normalized == "BOSS" then
        return "BOSS"
    end

    for _, slot in ipairs(self:GetActiveSlotOrder()) do
        if self:GetSlotLabel(slot) == normalized then
            return slot
        end
    end
    if self:IsSlotActive(normalized) then
        return normalized
    end
    return nil
end

function Addon:IsSpecAllowedForSlot(slot, specId)
    local role = self:GetSlotRole(slot)
    local spec = self:GetSpecDefinition(specId)
    return role ~= nil and spec ~= nil and spec.roles[role] == true
end

function Addon:ClassHasSpecForSlot(classKey, slot)
    local class = self.CLASSES[classKey]
    if not class then
        return false
    end

    for _, spec in ipairs(class.specs) do
        if self:IsSpecAllowedForSlot(slot, spec.id) then
            return true
        end
    end
    return false
end

function Addon:IsPlaceholder(slot, name)
    name = self:Trim(name)
    return name == ""
        or strupper(name) == strupper(slot or "")
        or strupper(name) == self:GetSlotLabel(slot)
end

function Addon:Print(message)
    local text = "|cffc94cffBQL Manager:|r " .. tostring(message or "")
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage(text)
    end
end

function Addon:NormalizeRosterRole(value, slot)
    if value == nil then
        local inferred = string.match(tostring(slot or ""), "^([A-Z]+)")
        return self.ROLE_SET[inferred] and inferred or nil
    end

    local role = strupper(self:Trim(value))
    return self.ROLE_SET[role] and role or nil
end

function Addon:PrepareRoster()
    for _, slot in ipairs(self.SLOT_ORDER) do
        local record = self.db.roster[slot]
        record.role = self:NormalizeRosterRole(record.role, slot) or ""
    end

    for _, slot in ipairs(self.SLOT_ORDER) do
        local record = self.db.roster[slot]
        local specId = self:NormalizeSpecId(record.spec)
        record.spec = self:IsSpecAllowedForSlot(slot, specId) and specId or ""
    end

    if self.db.bites and self.db.bites[1] then
        self.db.bites[1].source = "BOSS"
    end
end

function Addon:InitializeDatabase()
    if type(_G.BQLManagerDB) ~= "table" then
        _G.BQLManagerDB = DeepCopy(self.DEFAULTS)
    else
        MergeDefaults(_G.BQLManagerDB, self.DEFAULTS)
    end

    self.db = _G.BQLManagerDB
    self:PrepareRoster()
    self.db.version = self.DB_VERSION
end

function Addon:ResetDatabase()
    _G.BQLManagerDB = DeepCopy(self.DEFAULTS)
    self.db = _G.BQLManagerDB
    self:PrepareRoster()
    self:ResetEncounter(false)
    self:RefreshUI()
    self:Print("Configuración inicial restaurada.")
end

function Addon:RefreshUI()
    if self.UI and self.UI.Refresh then
        self.UI:Refresh()
    end
end

function Addon:GetSlotRecord(slot)
    if not self.db or not self.db.roster then
        return nil
    end
    return self.db.roster[slot]
end

function Addon:GetSlotName(slot)
    if slot == "BOSS" then
        return "BQL"
    end

    local record = self:GetSlotRecord(slot)
    if not record then
        return slot or "?"
    end

    local name = self:Trim(record.name)
    if self:IsPlaceholder(slot, name) then
        return self:GetSlotLabel(slot)
    end
    return name
end

function Addon:GetSlotForName(name)
    local normalized = self:NormalizeName(name)
    if normalized == "" or not self.db then
        return nil
    end

    for _, slot in ipairs(self:GetActiveSlotOrder()) do
        local record = self.db.roster[slot]
        if record and self:NormalizeName(record.name) == normalized then
            return slot
        end
    end
    return nil
end

function Addon:GetSlotDisplay(slot)
    if slot == "BOSS" then
        return "BQL"
    end
    return self:GetSlotLabel(slot) .. " · " .. self:GetSlotName(slot)
end

function Addon:SetRosterValue(slot, field, value)
    if not self.SLOT_SET[slot] then
        return
    end
    if field ~= "name" then
        return
    end

    self.db.roster[slot][field] = self:Trim(value)
    self:RefreshUI()
end

function Addon:SetRosterSpec(slot, specId)
    if not self.SLOT_SET[slot] then
        return false
    end

    local normalized = self:NormalizeSpecId(specId)
    if not normalized or not self:IsSpecAllowedForSlot(slot, normalized) then
        return false
    end

    self.db.roster[slot].spec = normalized
    self:RefreshUI()
    return true
end

function Addon:GetSlotReference(slot)
    for index, edge in ipairs(self.db.bites) do
        if edge.source == slot or edge.target == slot then
            return "mordidas (fila " .. tostring(index) .. ")"
        end
    end

    for group, records in pairs(self.db.cooldowns) do
        for index, record in ipairs(records) do
            if record.slot == slot or record.source == slot or record.target == slot then
                return "cooldowns (" .. tostring(group) .. " " .. tostring(index) .. ")"
            end
        end
    end
    return nil
end

function Addon:AddRosterRole(role)
    role = strupper(self:Trim(role))
    if not self.ROLE_SET[role] then
        return false
    end

    local counts = self:GetRoleCounts()
    local maximum = self.ROLE_MAXIMUMS[role]
    if maximum and counts[role] >= maximum then
        self:Print(role .. " admite como máximo " .. tostring(maximum) .. " puestos.")
        return false
    end
    if self:GetActiveRosterSize() >= self.MAX_ROSTER_SIZE then
        self:Print("La plantilla ya tiene " .. tostring(self.MAX_ROSTER_SIZE) .. " puestos. Quita uno antes de añadir otro.")
        return false
    end

    for _, slot in ipairs(self.SLOT_ORDER) do
        if not self:IsSlotActive(slot) then
            local record = self.db.roster[slot]
            local wasPlaceholder = self:IsPlaceholder(slot, record.name)
            record.role = role
            record.spec = ""
            if wasPlaceholder then
                record.name = self:GetSlotLabel(slot)
            end
            self:Print("Puesto " .. self:GetSlotLabel(slot) .. " añadido. Selecciona una especialización compatible.")
            self:RefreshUI()
            return true
        end
    end
    return false
end

function Addon:RemoveRosterRole(role)
    role = strupper(self:Trim(role))
    if not self.ROLE_SET[role] then
        return false
    end

    local counts = self:GetRoleCounts()
    local minimum = self.ROLE_MINIMUMS[role] or 0
    if counts[role] <= minimum then
        self:Print(role .. " debe conservar al menos " .. tostring(minimum) .. " puesto(s).")
        return false
    end

    local slot
    for _, candidate in ipairs(self.SLOT_ORDER) do
        if self:GetSlotRole(candidate) == role then
            slot = candidate
        end
    end
    if not slot then
        return false
    end

    local reference = self:GetSlotReference(slot)
    if reference then
        self:Print("No se puede quitar " .. self:GetSlotLabel(slot) .. " porque todavía se usa en " .. reference .. ".")
        return false
    end

    local oldLabel = self:GetSlotLabel(slot)
    local record = self.db.roster[slot]
    local wasPlaceholder = self:IsPlaceholder(slot, record.name)
    record.role = ""
    record.spec = ""
    if wasPlaceholder then
        record.name = slot
    end
    self:Print(oldLabel .. " retirado. Su posición queda disponible para otro rol.")
    self:RefreshUI()
    return true
end

function Addon:SetBiteSlot(index, field, slot)
    index = tonumber(index)
    if not index or not self.db.bites[index] then
        return false
    end
    if field ~= "source" and field ~= "target" then
        return false
    end

    if index == 1 and field == "source" then
        self.db.bites[index].source = "BOSS"
        self:RefreshUI()
        return slot == "BOSS"
    end
    if not self:IsSlotActive(slot) then
        return false
    end

    self.db.bites[index][field] = slot
    self:RefreshUI()
    return true
end

function Addon:GetWaveEdges(wave)
    local result = {}
    if not self.db then
        return result
    end

    for index, edge in ipairs(self.db.bites) do
        if tonumber(edge.wave) == tonumber(wave) then
            tinsert(result, { index = index, edge = edge })
        end
    end
    return result
end

function Addon:FormatWave(wave, includeSlots)
    local parts = {}
    for _, item in ipairs(self:GetWaveEdges(wave)) do
        local edge = item.edge
        local source = includeSlots and self:GetSlotDisplay(edge.source) or self:GetSlotName(edge.source)
        local target = includeSlots and self:GetSlotDisplay(edge.target) or self:GetSlotName(edge.target)
        tinsert(parts, source .. " > " .. target)
    end
    return table.concat(parts, " / ")
end

function Addon:FormatCooldownGroup(group)
    local parts = {}
    local records = self.db.cooldowns[group] or {}
    for _, record in ipairs(records) do
        if group == "threat" then
            tinsert(parts, record.label .. " " .. self:GetSlotName(record.source) .. " > " .. self:GetSlotName(record.target))
        else
            tinsert(parts, record.label .. ": " .. self:GetSlotName(record.slot))
        end
    end
    return table.concat(parts, " / ")
end

function Addon:GetRaidChannel()
    if GetNumRaidMembers and GetNumRaidMembers() > 0 then
        if self.db.options.raidWarnings and ((IsRaidLeader and IsRaidLeader()) or (IsRaidOfficer and IsRaidOfficer())) then
            return "RAID_WARNING"
        end
        return "RAID"
    end
    if GetNumPartyMembers and GetNumPartyMembers() > 0 then
        return "PARTY"
    end
    return nil
end

function Addon:EnqueueChat(message, channel, target)
    tinsert(self.messageQueue, {
        kind = "CHAT",
        message = tostring(message or ""),
        channel = channel,
        target = target,
    })
end

function Addon:EnqueueAddon(message, channel, target)
    tinsert(self.messageQueue, {
        kind = "ADDON",
        message = tostring(message or ""),
        channel = channel,
        target = target,
    })
end

function Addon:ProcessMessageQueue(elapsed)
    if #self.messageQueue == 0 then
        self.queueElapsed = 0
        return
    end

    self.queueElapsed = self.queueElapsed + elapsed
    if self.queueElapsed < 0.22 then
        return
    end
    self.queueElapsed = 0

    local item = tremove(self.messageQueue, 1)
    if item.kind == "CHAT" then
        if SendChatMessage and item.channel then
            SendChatMessage(item.message, item.channel, nil, item.target)
        end
    elseif item.kind == "ADDON" then
        if SendAddonMessage and item.channel then
            SendAddonMessage(self.MESSAGE_PREFIX, item.message, item.channel, item.target)
        end
    end
end

function Addon:Announce(message)
    local channel = self:GetRaidChannel()
    if channel then
        self:EnqueueChat("[BQL] " .. message, channel)
    else
        self:Print(message)
    end
end

function Addon:Whisper(player, message)
    player = self:Trim(player)
    if player == "" then
        return
    end
    self:EnqueueChat("[BQL] " .. message, "WHISPER", player)
end

function Addon:AnnounceWave(wave, whisperPlayers)
    local text = self:FormatWave(wave, false)
    if text == "" then
        self:Print("La ronda " .. tostring(wave) .. " no tiene asignaciones.")
        return
    end

    self:Announce("Mordida " .. tostring(wave) .. ": " .. text)

    if whisperPlayers and self.db.options.whisperAssignments and wave > 1 then
        for _, item in ipairs(self:GetWaveEdges(wave)) do
            local edge = item.edge
            local sourceName = self:GetSlotName(edge.source)
            local targetName = self:GetSlotName(edge.target)
            if not self:IsPlaceholder(edge.source, sourceName) then
                self:Whisper(sourceName, "En la mordida " .. tostring(wave) .. " muerde a " .. targetName .. " (" .. edge.target .. ").")
            end
        end
    end
end

function Addon:AnnounceFullPlan()
    for wave = 1, 5 do
        local text = self:FormatWave(wave, false)
        if text ~= "" then
            self:Announce("Mordida " .. tostring(wave) .. ": " .. text)
        end
    end
    self:Announce("Aura Mastery: " .. self:FormatCooldownGroup("aura"))
    self:Announce("Primer vuelo: " .. self:FormatCooldownGroup("flight1"))
    self:Announce("Segundo vuelo: " .. self:FormatCooldownGroup("flight2"))
    self:Announce("MD/Tricks: " .. self:FormatCooldownGroup("threat"))
end

function Addon:StartEncounter(announce)
    self.state.active = true
    self.state.currentWave = 1
    self.state.completed = {}
    self.state.startedAt = GetTime and GetTime() or 0
    if announce ~= false then
        self:Announce("Seguimiento iniciado.")
        self:AnnounceWave(1, false)
    end
    self:BroadcastState()
    self:RefreshUI()
end

function Addon:StopEncounter(reason, announce)
    if not self.state.active then
        return
    end
    self.state.active = false
    if announce ~= false then
        if reason == "victory" then
            self:Announce("Encuentro completado.")
        else
            self:Announce("Seguimiento detenido.")
        end
    end
    self:BroadcastState()
    self:RefreshUI()
end

function Addon:ResetEncounter(announce)
    self.state.active = false
    self.state.currentWave = 1
    self.state.completed = {}
    self.state.startedAt = nil
    if announce then
        self:Announce("Progreso de mordidas reiniciado.")
    end
    self:BroadcastState()
    self:RefreshUI()
end

function Addon:SetWave(wave, announce)
    wave = floor(tonumber(wave) or 1)
    if wave < 1 then
        wave = 1
    elseif wave > 5 then
        wave = 5
    end

    self.state.currentWave = wave
    self.state.active = true
    self.state.completed = {}
    if announce ~= false then
        self:AnnounceWave(wave, true)
    end
    self:BroadcastState()
    self:RefreshUI()
end

function Addon:IsWaveComplete(wave)
    local edges = self:GetWaveEdges(wave)
    if #edges == 0 then
        return false
    end
    for _, item in ipairs(edges) do
        if not self.state.completed[item.index] then
            return false
        end
    end
    return true
end

function Addon:AdvanceWaveIfComplete()
    local wave = self.state.currentWave
    if not self:IsWaveComplete(wave) then
        return
    end

    if wave >= 5 then
        self:Announce("Árbol de mordidas completado.")
        self.state.currentWave = 5
        self:BroadcastState()
        self:RefreshUI()
        return
    end

    self.state.currentWave = wave + 1
    self:AnnounceWave(self.state.currentWave, true)
    self:BroadcastState()
    self:RefreshUI()
end

function Addon:MarkBite(sourceName, targetName)
    if not self.state.active then
        return false
    end

    local sourceSlot = sourceName and self:GetSlotForName(sourceName) or nil
    local targetSlot = self:GetSlotForName(targetName)
    if not targetSlot then
        return false
    end

    for _, item in ipairs(self:GetWaveEdges(self.state.currentWave)) do
        local edge = item.edge
        local sourceMatches = not sourceSlot or edge.source == sourceSlot or edge.source == "BOSS"
        if not self.state.completed[item.index] and edge.target == targetSlot and sourceMatches then
            self.state.completed[item.index] = true
            self:Print("Mordida registrada: " .. self:GetSlotName(edge.source) .. " > " .. self:GetSlotName(edge.target) .. ".")
            self:AdvanceWaveIfComplete()
            self:RefreshUI()
            return true
        end
    end
    return false
end

function Addon:WarnFrenzy(playerName)
    if not self.state.active then
        return
    end

    local slot = self:GetSlotForName(playerName)
    if not slot then
        return
    end

    for _, item in ipairs(self:GetWaveEdges(self.state.currentWave)) do
        local edge = item.edge
        if edge.source == slot and not self.state.completed[item.index] then
            local targetName = self:GetSlotName(edge.target)
            if self.db.options.whisperAssignments then
                self:Whisper(playerName, "¡MUERDE AHORA a " .. targetName .. " (" .. edge.target .. ")!")
            end
            self:Print(playerName .. " debe morder a " .. targetName .. ".")
            return
        end
    end
end

function Addon:IsBossName(name)
    local normalized = self:NormalizeName(name)
    if self.BOSS_NAMES[normalized] then
        return true
    end
    return strfind(normalized, "lana'thel", 1, true) ~= nil or strfind(normalized, "lanathel", 1, true) ~= nil
end

function Addon:IsBiteSpell(spellId, spellName)
    if self.SPELLS.VAMPIRIC_BITE[tonumber(spellId)] then
        return true
    end
    local name = strlower(tostring(spellName or ""))
    return strfind(name, "vampiric bite", 1, true) ~= nil or strfind(name, "mordedura vamp", 1, true) ~= nil
end

function Addon:IsEssenceSpell(spellId, spellName)
    if self.SPELLS.ESSENCE[tonumber(spellId)] then
        return true
    end
    local name = strlower(tostring(spellName or ""))
    return strfind(name, "essence of the blood queen", 1, true) ~= nil or strfind(name, "esencia de la reina", 1, true) ~= nil
end

function Addon:IsFrenzySpell(spellId, spellName)
    if self.SPELLS.FRENZY[tonumber(spellId)] then
        return true
    end
    local name = strlower(tostring(spellName or ""))
    return strfind(name, "frenzied bloodthirst", 1, true) ~= nil or strfind(name, "sed de sangre", 1, true) ~= nil
end

function Addon:ParseCombatLog(...)
    local args = { ... }
    local data = {
        subevent = args[2],
    }

    if type(args[3]) == "boolean" then
        data.sourceGUID = args[4]
        data.sourceName = args[5]
        if type(args[9]) == "string" then
            data.destGUID = args[8]
            data.destName = args[9]
            data.spellId = args[12]
            data.spellName = args[13]
        else
            data.destGUID = args[7]
            data.destName = args[8]
            data.spellId = args[10]
            data.spellName = args[11]
        end
    else
        data.sourceGUID = args[3]
        data.sourceName = args[4]
        data.destGUID = args[6]
        data.destName = args[7]
        data.spellId = args[9]
        data.spellName = args[10]
    end
    return data
end

function Addon:HandleCombatLog(...)
    local data = self:ParseCombatLog(...)
    local subevent = data.subevent

    if subevent == "UNIT_DIED" and self:IsBossName(data.destName) then
        self:StopEncounter("victory", true)
        return
    end

    if not self.state.active and self.db.options.autoStart and self:IsBossName(data.sourceName) then
        self:StartEncounter(true)
    end

    if not self.state.active then
        return
    end

    if (subevent == "SPELL_CAST_SUCCESS" or subevent == "SPELL_AURA_APPLIED") and self:IsBiteSpell(data.spellId, data.spellName) then
        self:MarkBite(data.sourceName, data.destName)
    elseif subevent == "SPELL_AURA_APPLIED" and self:IsEssenceSpell(data.spellId, data.spellName) then
        self:MarkBite(data.sourceName, data.destName)
    elseif subevent == "SPELL_AURA_APPLIED" and self:IsFrenzySpell(data.spellId, data.spellName) then
        self:WarnFrenzy(data.destName)
    end
end

function Addon:GetValidationIssues()
    local issues = {}
    local function AddIssue(text)
        tinsert(issues, text)
    end

    local activeSlots = self:GetActiveSlotOrder()
    if #activeSlots ~= self.MAX_ROSTER_SIZE then
        AddIssue("La plantilla tiene " .. tostring(#activeSlots) .. " de " .. tostring(self.MAX_ROSTER_SIZE) .. " puestos activos.")
    end
    local roleCounts = self:GetRoleCounts()
    if roleCounts.TANK > (self.ROLE_MAXIMUMS.TANK or 2) then
        AddIssue("La plantilla no puede tener más de dos tanques.")
    end
    if roleCounts.HEALER < (self.ROLE_MINIMUMS.HEALER or 1) then
        AddIssue("La plantilla debe conservar al menos un healer.")
    end

    local names = {}
    for _, slot in ipairs(activeSlots) do
        local record = self.db.roster[slot]
        local name = record and self:Trim(record.name) or ""
        if not record or not self:GetSpecDefinition(record.spec) then
            AddIssue(self:GetSlotLabel(slot) .. " no tiene una especialización válida seleccionada.")
        elseif not self:IsSpecAllowedForSlot(slot, record.spec) then
            AddIssue(self:GetSlotLabel(slot) .. " tiene una especialización incompatible con su función.")
        end
        if self:IsPlaceholder(slot, name) then
            AddIssue(self:GetSlotLabel(slot) .. " no tiene un personaje asignado.")
        else
            local normalized = self:NormalizeName(name)
            if names[normalized] then
                AddIssue(name .. " está asignado a " .. names[normalized] .. " y " .. self:GetSlotLabel(slot) .. ".")
            else
                names[normalized] = self:GetSlotLabel(slot)
            end
        end
    end

    local infected = {}
    local expectedByWave = { 1, 1, 2, 4, 8 }
    for wave = 1, 5 do
        local edges = self:GetWaveEdges(wave)
        if #edges ~= expectedByWave[wave] then
            AddIssue("La mordida " .. wave .. " tiene " .. #edges .. " asignaciones; debe tener " .. expectedByWave[wave] .. ".")
        end

        local sources = {}
        local newTargets = {}
        for _, item in ipairs(edges) do
            local edge = item.edge
            if wave == 1 then
                if edge.source ~= "BOSS" then
                    AddIssue("La primera mordida debe salir de BOSS.")
                end
            else
                if not self:IsSlotActive(edge.source) then
                    AddIssue("Origen de mordida inválido: " .. tostring(edge.source) .. ".")
                elseif not infected[edge.source] then
                    AddIssue(edge.source .. " muerde en la ronda " .. wave .. " sin haber sido mordido antes.")
                end
                if sources[edge.source] then
                    AddIssue(edge.source .. " aparece dos veces como origen en la mordida " .. wave .. ".")
                end
                sources[edge.source] = true
            end

            if not self:IsSlotActive(edge.target) then
                AddIssue("Destino de mordida inválido: " .. tostring(edge.target) .. ".")
            else
                if infected[edge.target] then
                    AddIssue(edge.target .. " recibe otra mordida después de estar infectado.")
                end
                if newTargets[edge.target] then
                    AddIssue(edge.target .. " recibe dos mordidas en la ronda " .. wave .. ".")
                end
                newTargets[edge.target] = true
            end
        end

        for target in pairs(newTargets) do
            infected[target] = true
        end
    end

    for group, records in pairs(self.db.cooldowns) do
        for _, record in ipairs(records) do
            if group == "threat" then
                if not self:IsSlotActive(record.source) then
                    AddIssue("Origen inválido en MD/Tricks: " .. tostring(record.source) .. ".")
                end
                if not self:IsSlotActive(record.target) then
                    AddIssue("Destino inválido en MD/Tricks: " .. tostring(record.target) .. ".")
                end
            elseif not self:IsSlotActive(record.slot) then
                AddIssue("Puesto inválido en " .. tostring(record.label) .. ": " .. tostring(record.slot) .. ".")
            end
        end
    end

    return issues
end

function Addon:ValidateAndReport()
    local issues = self:GetValidationIssues()
    if #issues == 0 then
        self:Print("Validación correcta: no se detectaron conflictos.")
        return true
    end

    self:Print("Validación: " .. #issues .. " problema(s).")
    for index, issue in ipairs(issues) do
        self:Print(tostring(index) .. ". " .. issue)
    end
    return false
end

function Addon:GetRaidMembers()
    local members = {}
    if not GetNumRaidMembers then
        return members
    end

    for index = 1, GetNumRaidMembers() do
        local name, rank, subgroup, level, class, classFile = GetRaidRosterInfo(index)
        if name then
            tinsert(members, {
                name = string.gsub(name, "%-.*$", ""),
                rank = rank,
                subgroup = subgroup,
                class = class,
                classFile = classFile,
            })
        end
    end
    return members
end

function Addon:ImportRaidRoster()
    local members = self:GetRaidMembers()
    if #members == 0 then
        self:Print("No hay una banda activa para importar.")
        return
    end

    local used = {}
    for _, member in ipairs(members) do
        local slot = self:GetSlotForName(member.name)
        if slot then
            used[self:NormalizeName(member.name)] = true
        end
    end

    local nextMember = 1
    local changed = 0
    for _, slot in ipairs(self:GetActiveSlotOrder()) do
        local record = self.db.roster[slot]
        if self:IsPlaceholder(slot, record.name) then
            local member
            while nextMember <= #members and not member do
                local candidate = members[nextMember]
                nextMember = nextMember + 1
                if not used[self:NormalizeName(candidate.name)] then
                    member = candidate
                end
            end
            if member then
                record.name = member.name
                used[self:NormalizeName(member.name)] = true
                changed = changed + 1
            end
        end
    end

    self:Print("Importación completada: " .. changed .. " puesto(s) rellenados sin sobrescribir asignaciones existentes.")
    self:RefreshUI()
end

local function EscapeField(value)
    value = tostring(value or "")
    value = string.gsub(value, "%%", "%%25")
    value = string.gsub(value, "|", "%%7C")
    value = string.gsub(value, "\r", "")
    value = string.gsub(value, "\n", "%%0A")
    return value
end

local function UnescapeField(value)
    value = tostring(value or "")
    value = string.gsub(value, "%%0A", "\n")
    value = string.gsub(value, "%%7C", "|")
    value = string.gsub(value, "%%25", "%%")
    return value
end

local function SplitMessage(message)
    local fields = {}
    for field in strgmatch(tostring(message or "") .. "|", "(.-)|") do
        tinsert(fields, UnescapeField(field))
    end
    return fields
end

function Addon:GetAddonChannel()
    if GetNumRaidMembers and GetNumRaidMembers() > 0 then
        return "RAID"
    end
    if GetNumPartyMembers and GetNumPartyMembers() > 0 then
        return "PARTY"
    end
    return nil
end

function Addon:CanLeadRaid()
    return (IsRaidLeader and IsRaidLeader()) or (IsRaidOfficer and IsRaidOfficer())
end

function Addon:IsAuthorizedSender(sender)
    local normalized = self:NormalizeName(sender)
    local player = UnitName and UnitName("player") or ""
    if normalized == self:NormalizeName(player) then
        return true
    end

    for _, member in ipairs(self:GetRaidMembers()) do
        if self:NormalizeName(member.name) == normalized then
            return (member.rank or 0) >= 1
        end
    end
    return false
end

function Addon:QueueSync(fields, channel)
    local encoded = {}
    for _, field in ipairs(fields) do
        tinsert(encoded, EscapeField(field))
    end
    self:EnqueueAddon(table.concat(encoded, "|"), channel)
end

function Addon:SyncConfiguration()
    local channel = self:GetAddonChannel()
    if not channel then
        self:Print("Debes estar en grupo o banda para sincronizar.")
        return
    end
    if GetNumRaidMembers and GetNumRaidMembers() > 0 and not self:CanLeadRaid() then
        self:Print("Solo el líder o un asistente puede sincronizar la configuración.")
        return
    end

    self:QueueSync({ "BEGIN", self.DB_VERSION }, channel)
    for _, slot in ipairs(self.SLOT_ORDER) do
        local record = self.db.roster[slot]
        self:QueueSync({ "ROSTER", slot, record.name, record.spec, record.role or "" }, channel)
    end
    for index, edge in ipairs(self.db.bites) do
        self:QueueSync({ "BITE", index, edge.wave, edge.source, edge.target }, channel)
    end
    for _, group in ipairs({ "aura", "flight1", "flight2", "threat" }) do
        for index, record in ipairs(self.db.cooldowns[group]) do
            self:QueueSync({ "CD", group, index, record.label, record.slot or "", record.source or "", record.target or "" }, channel)
        end
    end
    for key, note in pairs(self.db.zones) do
        self:QueueSync({ "ZONE", key, note }, channel)
    end
    self:QueueSync({ "END" }, channel)
    self:Print("Sincronización encolada para la banda.")
end

function Addon:BroadcastState()
    local channel = self:GetAddonChannel()
    if not channel or not self:CanLeadRaid() then
        return
    end
    self:QueueSync({ "STATE", self.state.active and 1 or 0, self.state.currentWave }, channel)
end

function Addon:ReceiveSync(message, sender)
    if not self.db.options.acceptSync or not self:IsAuthorizedSender(sender) then
        return
    end

    local fields = SplitMessage(message)
    local kind = fields[1]
    if kind == "BEGIN" then
        self.receivingSync = sender
        self.receivingSyncVersion = tonumber(fields[2]) or 1
    elseif kind == "END" then
        if self.receivingSync then
            self:Print("Configuración recibida de " .. tostring(sender) .. ".")
            self.receivingSync = nil
            self.receivingSyncVersion = nil
            self:RefreshUI()
        end
    elseif kind == "ROSTER" and self.SLOT_SET[fields[2]] then
        local slot = fields[2]
        local record = self.db.roster[slot]
        record.name = fields[3] or ""
        if fields[5] ~= nil then
            record.role = self:NormalizeRosterRole(fields[5], slot) or ""
        elseif (self.receivingSyncVersion or 1) < 3 then
            record.role = self:NormalizeRosterRole(nil, slot) or ""
        end
        local specId = self:NormalizeSpecId(fields[4])
        record.spec = self:IsSpecAllowedForSlot(slot, specId) and specId or ""
    elseif kind == "BITE" then
        local index = tonumber(fields[2])
        if index and self.db.bites[index] then
            self.db.bites[index].wave = tonumber(fields[3]) or self.db.bites[index].wave
            if index == 1 then
                self.db.bites[index].source = "BOSS"
            elseif self:IsSlotActive(fields[4]) then
                self.db.bites[index].source = fields[4]
            end
            if self:IsSlotActive(fields[5]) then
                self.db.bites[index].target = fields[5]
            end
        end
    elseif kind == "CD" then
        local group = fields[2]
        local index = tonumber(fields[3])
        local record = self.db.cooldowns[group] and self.db.cooldowns[group][index]
        if record then
            record.label = fields[4] or record.label
            if group == "threat" then
                record.source = fields[6] or record.source
                record.target = fields[7] or record.target
            else
                record.slot = fields[5] or record.slot
            end
        end
    elseif kind == "ZONE" and self.db.zones[fields[2]] ~= nil then
        self.db.zones[fields[2]] = fields[3] or ""
    elseif kind == "STATE" then
        self.state.active = tonumber(fields[2]) == 1
        self.state.currentWave = tonumber(fields[3]) or 1
        self:RefreshUI()
    end
end

function Addon:HandleSlashCommand(input)
    input = self:Trim(input)
    local command, rest = string.match(input, "^(%S*)%s*(.-)$")
    command = strlower(command or "")

    if command == "" or command == "show" or command == "toggle" then
        if self.UI and self.UI.Toggle then
            self.UI:Toggle()
        end
    elseif command == "start" then
        self:StartEncounter(true)
    elseif command == "stop" then
        self:StopEncounter("manual", true)
    elseif command == "reset" then
        self:ResetEncounter(true)
    elseif command == "wave" then
        self:SetWave(rest, true)
    elseif command == "announce" or command == "anunciar" then
        self:AnnounceFullPlan()
    elseif command == "sync" or command == "sincronizar" then
        self:SyncConfiguration()
    elseif command == "validate" or command == "validar" then
        self:ValidateAndReport()
    elseif command == "defaults" then
        StaticPopup_Show("BQLMANAGER_CONFIRM_DEFAULTS")
    else
        self:Print("Comandos: show, start, stop, reset, wave 1-5, announce, sync, validate, defaults.")
    end
end

function Addon:OnAddonLoaded(addonName)
    if addonName ~= "BQLManager" then
        return
    end

    self:InitializeDatabase()
    if RegisterAddonMessagePrefix then
        RegisterAddonMessagePrefix(self.MESSAGE_PREFIX)
    end

    SLASH_BQLMANAGER1 = "/bql"
    SLASH_BQLMANAGER2 = "/bqlmanager"
    SlashCmdList.BQLMANAGER = function(input)
        Addon:HandleSlashCommand(input)
    end

    StaticPopupDialogs.BQLMANAGER_CONFIRM_DEFAULTS = {
        text = "¿Restaurar toda la configuración inicial de BQL Manager?",
        button1 = YES,
        button2 = NO,
        OnAccept = function()
            Addon:ResetDatabase()
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }

    if self.UI and self.UI.Initialize then
        self.UI:Initialize()
    end
    self:Print("Cargado. Usa /bql para abrir la ventana.")
end

Addon.eventFrame = CreateFrame("Frame")
Addon.eventFrame:RegisterEvent("ADDON_LOADED")
Addon.eventFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
Addon.eventFrame:RegisterEvent("CHAT_MSG_ADDON")
Addon.eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
Addon.eventFrame:RegisterEvent("RAID_ROSTER_UPDATE")

Addon.eventFrame:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        Addon:OnAddonLoaded(...)
    elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
        Addon:HandleCombatLog(...)
    elseif event == "CHAT_MSG_ADDON" then
        local prefix, message, channel, sender = ...
        if prefix == Addon.MESSAGE_PREFIX then
            Addon:ReceiveSync(message, sender)
        end
    elseif event == "PLAYER_REGEN_DISABLED" then
        if Addon.db and Addon.db.options.autoStart and not Addon.state.active and Addon:IsBossName(UnitName("target")) then
            Addon:StartEncounter(true)
        end
    elseif event == "RAID_ROSTER_UPDATE" then
        Addon:RefreshUI()
    end
end)

Addon.eventFrame:SetScript("OnUpdate", function(_, elapsed)
    Addon:ProcessMessageQueue(elapsed)
end)
