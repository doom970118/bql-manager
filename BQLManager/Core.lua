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

function Addon:IsPlaceholder(slot, name)
    name = self:Trim(name)
    return name == "" or strupper(name) == strupper(slot or "")
end

function Addon:Print(message)
    local text = "|cffc94cffBQL Manager:|r " .. tostring(message or "")
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage(text)
    end
end

function Addon:InitializeDatabase()
    if type(_G.BQLManagerDB) ~= "table" then
        _G.BQLManagerDB = DeepCopy(self.DEFAULTS)
    else
        MergeDefaults(_G.BQLManagerDB, self.DEFAULTS)
    end

    _G.BQLManagerDB.version = self.DB_VERSION
    self.db = _G.BQLManagerDB
end

function Addon:ResetDatabase()
    _G.BQLManagerDB = DeepCopy(self.DEFAULTS)
    self.db = _G.BQLManagerDB
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
    if name == "" then
        return slot
    end
    return name
end

function Addon:GetSlotForName(name)
    local normalized = self:NormalizeName(name)
    if normalized == "" or not self.db then
        return nil
    end

    for _, slot in ipairs(self.SLOT_ORDER) do
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
    return tostring(slot or "?") .. " · " .. self:GetSlotName(slot)
end

function Addon:SetRosterValue(slot, field, value)
    if not self.SLOT_SET[slot] then
        return
    end
    if field ~= "name" and field ~= "spec" then
        return
    end

    self.db.roster[slot][field] = self:Trim(value)
    self:RefreshUI()
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

    local names = {}
    for _, slot in ipairs(self.SLOT_ORDER) do
        local record = self.db.roster[slot]
        local name = record and self:Trim(record.name) or ""
        if self:IsPlaceholder(slot, name) then
            AddIssue(slot .. " no tiene un personaje asignado.")
        else
            local normalized = self:NormalizeName(name)
            if names[normalized] then
                AddIssue(name .. " está asignado a " .. names[normalized] .. " y " .. slot .. ".")
            else
                names[normalized] = slot
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
                if not self.SLOT_SET[edge.source] then
                    AddIssue("Origen de mordida inválido: " .. tostring(edge.source) .. ".")
                elseif not infected[edge.source] then
                    AddIssue(edge.source .. " muerde en la ronda " .. wave .. " sin haber sido mordido antes.")
                end
                if sources[edge.source] then
                    AddIssue(edge.source .. " aparece dos veces como origen en la mordida " .. wave .. ".")
                end
                sources[edge.source] = true
            end

            if not self.SLOT_SET[edge.target] then
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
                if not self.SLOT_SET[record.source] then
                    AddIssue("Origen inválido en MD/Tricks: " .. tostring(record.source) .. ".")
                end
                if not self.SLOT_SET[record.target] then
                    AddIssue("Destino inválido en MD/Tricks: " .. tostring(record.target) .. ".")
                end
            elseif not self.SLOT_SET[record.slot] then
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
    for _, slot in ipairs(self.SLOT_ORDER) do
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
                if self:Trim(record.spec) == "" then
                    record.spec = member.classFile or member.class or ""
                end
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
        self:QueueSync({ "ROSTER", slot, record.name, record.spec }, channel)
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
    elseif kind == "END" then
        if self.receivingSync then
            self:Print("Configuración recibida de " .. tostring(sender) .. ".")
            self.receivingSync = nil
            self:RefreshUI()
        end
    elseif kind == "ROSTER" and self.SLOT_SET[fields[2]] then
        self.db.roster[fields[2]].name = fields[3] or ""
        self.db.roster[fields[2]].spec = fields[4] or ""
    elseif kind == "BITE" then
        local index = tonumber(fields[2])
        if index and self.db.bites[index] then
            self.db.bites[index].wave = tonumber(fields[3]) or self.db.bites[index].wave
            self.db.bites[index].source = fields[4] or self.db.bites[index].source
            self.db.bites[index].target = fields[5] or self.db.bites[index].target
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
