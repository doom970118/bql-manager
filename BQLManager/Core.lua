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
local tsort = table.sort
local type = type
local tostring = tostring

Addon.state = {
    active = false,
    currentWave = 1,
    completed = {},
    startedAt = nil,
    initialBiteDetected = false,
}

Addon.messageQueue = {}
Addon.queueElapsed = 0
Addon.inspectQueue = {}
Addon.inspectQueued = {}
Addon.inspectElapsed = 0
Addon.pendingInspect = nil
Addon.autoSyncPending = false
Addon.autoSyncElapsed = 0
Addon.AUTO_SYNC_DELAY = 1.0

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

function Addon:GetRosterClassKey(slot)
    local record = self:GetSlotRecord(slot)
    if not record then
        return nil
    end

    local spec = self:GetSpecDefinition(record.spec)
    if spec then
        return spec.classKey
    end

    local member = self:GetGuildMemberProfile(record.name)
    return member and member.classKey or nil
end

function Addon:GetGuildMemberProfile(name)
    if not self.db or type(self.db.guildMembers) ~= "table" then
        return nil
    end
    return self.db.guildMembers[self:NormalizeName(name)]
end

function Addon:RememberPlayerProfile(name, classKey, specId, online, isGuildMember, specSource)
    if not self.db then
        return nil
    end
    if type(self.db.guildMembers) ~= "table" then
        self.db.guildMembers = {}
    end

    name = string.gsub(self:Trim(name), "%-.*$", "")
    local key = self:NormalizeName(name)
    if key == "" then
        return nil
    end

    classKey = strupper(self:Trim(classKey))
    if not self.CLASSES[classKey] then
        classKey = nil
    end

    local member = self.db.guildMembers[key] or {}
    member.name = name
    if classKey then
        member.classKey = classKey
        local oldSpec = self:GetSpecDefinition(member.spec)
        if oldSpec and oldSpec.classKey ~= classKey then
            member.spec = ""
            member.specSource = nil
        end
    end

    local normalizedSpec = self:NormalizeSpecId(specId)
    local spec = self:GetSpecDefinition(normalizedSpec)
    if spec and (not classKey or spec.classKey == classKey) then
        member.spec = normalizedSpec
        member.classKey = spec.classKey
        member.specSource = specSource or member.specSource or "roster"
    elseif member.spec == nil then
        member.spec = ""
    end

    if online ~= nil then
        member.online = online and true or false
    end
    if isGuildMember ~= nil then
        member.inGuild = isGuildMember and true or false
    end

    self.db.guildMembers[key] = member
    return member
end

function Addon:RememberRosterPlayer(slot, specSource)
    local record = self:GetSlotRecord(slot)
    if not record or self:IsPlaceholder(slot, record.name) then
        return nil
    end

    local spec = self:GetSpecDefinition(record.spec)
    return self:RememberPlayerProfile(
        record.name,
        spec and spec.classKey or self:GetRosterClassKey(slot),
        record.spec,
        nil,
        nil,
        specSource or "roster"
    )
end

function Addon:IsGuildMemberEligibleForSlot(member, slot)
    if not member or (not member.inGuild and not member.inGroup) or not self:IsSlotActive(slot) then
        return false
    end

    local specId = self:NormalizeSpecId(member.spec)
    if specId then
        return self:IsSpecAllowedForSlot(slot, specId)
    end
    return self:ClassHasSpecForSlot(member.classKey, slot)
end

function Addon:GetGuildMemberCandidates(slot, search)
    local result = {}
    if not self.db or type(self.db.guildMembers) ~= "table" then
        return result
    end

    local query = self:NormalizeName(search)
    for _, member in pairs(self.db.guildMembers) do
        if self:IsGuildMemberEligibleForSlot(member, slot) then
            local normalizedName = self:NormalizeName(member.name)
            if query == "" or strfind(normalizedName, query, 1, true) then
                tinsert(result, member)
            end
        end
    end
    tsort(result, function(left, right)
        return self:NormalizeName(left.name) < self:NormalizeName(right.name)
    end)
    return result
end

function Addon:GetGuildMemberSpecForSlot(member, slot)
    local specId = self:NormalizeSpecId(member and member.spec)
    if specId and self:IsSpecAllowedForSlot(slot, specId) then
        return specId, false
    end

    local class = member and self.CLASSES[member.classKey]
    local onlySpec
    local count = 0
    for _, spec in ipairs(class and class.specs or {}) do
        if self:IsSpecAllowedForSlot(slot, spec.id) then
            onlySpec = spec.id
            count = count + 1
        end
    end
    if count == 1 then
        return onlySpec, true
    end
    return "", false
end

function Addon:RefreshGuildRosterCache()
    if not self.db or not GetNumGuildMembers or not GetGuildRosterInfo then
        return
    end

    local total = GetNumGuildMembers() or 0
    if total <= 0 and (not GetGuildInfo or not GetGuildInfo("player")) then
        for _, member in pairs(self.db.guildMembers) do
            member.inGuild = false
            member.online = false
        end
        self:RefreshUI()
        return
    end

    for _, member in pairs(self.db.guildMembers) do
        member.inGuild = false
        member.online = false
    end

    for index = 1, total do
        local name, _, _, _, _, _, _, _, online, _, classFileName = GetGuildRosterInfo(index)
        if name then
            self:RememberPlayerProfile(name, classFileName, nil, online, true)
        end
    end
    self:RefreshUI()
end

function Addon:RequestGuildRoster()
    if GuildRoster and (not IsInGuild or IsInGuild()) then
        GuildRoster()
    end
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

function Addon:PrepareZoneAssignments()
    if not self.db then
        return
    end
    if type(self.db.zoneAssignments) ~= "table" then
        self.db.zoneAssignments = {}
    end

    local used = {}
    for _, zoneId in ipairs(self.SLOT_ORDER) do
        local role = self.ZONE_POSITION_ROLES[zoneId]
        local slot = self.db.zoneAssignments[zoneId]
        if self:IsSlotActive(slot) and self:GetSlotRole(slot) == role and not used[slot] then
            used[slot] = true
        else
            self.db.zoneAssignments[zoneId] = ""
        end
    end

    for _, zoneId in ipairs(self.SLOT_ORDER) do
        if self.db.zoneAssignments[zoneId] == "" then
            local role = self.ZONE_POSITION_ROLES[zoneId]
            for _, slot in ipairs(self:GetActiveSlotOrder()) do
                if self:GetSlotRole(slot) == role and not used[slot] then
                    self.db.zoneAssignments[zoneId] = slot
                    used[slot] = true
                    break
                end
            end
        end
    end
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

    for _, slot in ipairs(self:GetActiveSlotOrder()) do
        self:RememberRosterPlayer(slot, "roster")
    end

    self:PrepareZoneAssignments()
    self:RebuildBiteSources()
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

function Addon:GetZoneAssignment(zoneId)
    if not self.ZONE_POSITION_ROLES[zoneId] or not self.db or not self.db.zoneAssignments then
        return nil
    end
    local slot = self.db.zoneAssignments[zoneId]
    if self:IsSlotActive(slot) and self:GetSlotRole(slot) == self.ZONE_POSITION_ROLES[zoneId] then
        return slot
    end
    return nil
end

function Addon:SetZoneAssignment(zoneId, slot)
    local role = self.ZONE_POSITION_ROLES[zoneId]
    if not role or not self:IsSlotActive(slot) or self:GetSlotRole(slot) ~= role then
        return false
    end

    local oldSlot = self:GetZoneAssignment(zoneId)
    if oldSlot == slot then
        return true
    end

    for _, otherZoneId in ipairs(self.SLOT_ORDER) do
        if otherZoneId ~= zoneId and self.db.zoneAssignments[otherZoneId] == slot then
            self.db.zoneAssignments[otherZoneId] = oldSlot or ""
            break
        end
    end
    self.db.zoneAssignments[zoneId] = slot
    self:ScheduleAutoSync()
    self:RefreshUI()
    return true
end

function Addon:GetCooldownKind(group, index)
    local record = self.db and self.db.cooldowns and self.db.cooldowns[group] and self.db.cooldowns[group][index]
    if not record then
        return nil
    end

    local label = self:Trim(record.label)
    if group == "aura" or strfind(label, "Aura Mastery", 1, true) then
        return "AURA_MASTERY"
    elseif label == "DSAC" then
        return "DSAC"
    elseif strfind(label, "Marea", 1, true) then
        return "MANA_TIDE"
    elseif strfind(label, "Himno", 1, true) then
        return "HYMN"
    elseif strfind(label, "Tranquilidad", 1, true) then
        return "TRANQUILITY"
    elseif strupper(label) == "MD" then
        return "MISDIRECTION"
    elseif strfind(label, "Tricks", 1, true) then
        return "TRICKS"
    end
    return nil
end

function Addon:GetFirstBiteTarget()
    local firstBite = self:GetWaveEdges(1)[1]
    return firstBite and firstBite.edge.target or nil
end

function Addon:GetCooldownUserAssignment(group, index, field, slot)
    if not slot or slot == "" then
        return nil
    end

    local records = self.db and self.db.cooldowns and self.db.cooldowns[group]
    if not records then
        return nil
    end

    index = tonumber(index)
    for otherIndex, record in ipairs(records) do
        if otherIndex ~= index and record[field] == slot then
            return otherIndex, record
        end
    end
    return nil
end

function Addon:IsCooldownSlotEligible(group, index, field, slot, allowDpsPromotion)
    if not self:IsSlotActive(slot) then
        return false
    end

    local kind = self:GetCooldownKind(group, index)
    if group == "threat" and field == "target" then
        local role = self:GetSlotRole(slot)
        if role == "TANK" or slot == self:GetFirstBiteTarget() then
            return true
        end
        return allowDpsPromotion == true and (role == "MDPS" or role == "RDPS")
    end

    if (group == "threat" and field ~= "source") or (group ~= "threat" and field ~= "slot") then
        return false
    end

    local record = self:GetSlotRecord(slot)
    local spec = record and self:GetSpecDefinition(record.spec)
    if not spec then
        return false
    end

    if kind == "AURA_MASTERY" then
        return spec.id == "PALADIN_HOLY" or spec.id == "PALADIN_RETRIBUTION"
    elseif kind == "DSAC" then
        return spec.id == "PALADIN_PROTECTION" or spec.id == "PALADIN_HOLY"
    elseif kind == "MANA_TIDE" then
        return spec.id == "SHAMAN_RESTORATION"
    elseif kind == "HYMN" then
        return spec.classKey == "PRIEST"
    elseif kind == "TRANQUILITY" then
        return spec.classKey == "DRUID"
    elseif kind == "MISDIRECTION" then
        return spec.classKey == "HUNTER"
    elseif kind == "TRICKS" then
        return spec.classKey == "ROGUE"
    end
    return false
end

function Addon:SetCooldownAssignment(group, index, field, slot)
    index = tonumber(index)
    local record = index and self.db.cooldowns[group] and self.db.cooldowns[group][index]
    if not record or not self:IsCooldownSlotEligible(group, index, field, slot, true) then
        return false
    end

    if group == "threat" and field == "target" then
        local role = self:GetSlotRole(slot)
        if role ~= "TANK" and slot ~= self:GetFirstBiteTarget() then
            local firstBite = self:GetWaveEdges(1)[1]
            if not firstBite or not self:SetBiteTarget(firstBite.index, slot) then
                return false
            end
            self:Print(self:GetSlotName(slot) .. " pasa a ser la primera mordida para la asignación de " .. tostring(record.label) .. ".")
        end
    end

    local userField = group == "threat" and "source" or "slot"
    if field == userField then
        local _, otherRecord = self:GetCooldownUserAssignment(group, index, field, slot)
        if otherRecord then
            otherRecord[field] = record[field]
        end
    end

    record[field] = slot
    self:ScheduleAutoSync()
    self:RefreshUI()
    return true
end

function Addon:SetRosterValue(slot, field, value)
    if not self.SLOT_SET[slot] then
        return
    end
    if field ~= "name" then
        return
    end

    self.db.roster[slot][field] = self:Trim(value)
    self:RememberRosterPlayer(slot, "manual")
    self:ScheduleAutoSync()
    self:RefreshUI()
end

function Addon:ClearRosterSlot(slot)
    if not self:IsSlotActive(slot) then
        return false
    end

    local record = self.db.roster[slot]
    record.name = ""
    record.spec = ""
    self:ScheduleAutoSync()
    self:RefreshUI()
    return true
end

function Addon:AssignGuildMemberToSlot(slot, name)
    if not self:IsSlotActive(slot) then
        return false
    end

    local member = self:GetGuildMemberProfile(name)
    if not self:IsGuildMemberEligibleForSlot(member, slot) then
        return false
    end

    local record = self.db.roster[slot]
    local oldName = record.name
    local oldSpec = record.spec
    local otherSlot = self:GetSlotForName(member.name)
    if otherSlot and otherSlot ~= slot then
        local otherRecord = self.db.roster[otherSlot]
        if self:IsPlaceholder(slot, oldName) then
            otherRecord.name = self:GetSlotLabel(otherSlot)
            otherRecord.spec = ""
        else
            otherRecord.name = oldName
            otherRecord.spec = self:IsSpecAllowedForSlot(otherSlot, oldSpec) and oldSpec or ""
            self:RememberRosterPlayer(otherSlot, "roster")
        end
    end

    local specId, inferred = self:GetGuildMemberSpecForSlot(member, slot)
    record.name = member.name
    record.spec = specId
    if specId ~= "" then
        self:RememberPlayerProfile(member.name, member.classKey, specId, member.online, member.inGuild, inferred and "role" or member.specSource)
    end

    if specId == "" then
        self:Print(member.name .. " no tiene una spec conocida todavía. Selecciona una spec compatible; quedará guardada para el futuro.")
    end
    self:ScheduleAutoSync()
    self:RefreshUI()
    return true
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
    self:RememberRosterPlayer(slot, "manual")
    self:ScheduleAutoSync()
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
            self:PrepareZoneAssignments()
            self:ScheduleAutoSync()
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
    self:PrepareZoneAssignments()
    self:ScheduleAutoSync()
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

    if field == "source" then
        self:RebuildBiteSources()
        self:RefreshUI()
        return self.db.bites[index].source == slot
    end

    return self:SetBiteTarget(index, slot)
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

function Addon:RebuildBiteSources()
    if not self.db or not self.db.bites then
        return
    end

    local infected = {}
    local infectedOrder = {}
    for wave = 1, 5 do
        local edges = self:GetWaveEdges(wave)
        for position, item in ipairs(edges) do
            if wave == 1 then
                item.edge.source = "BOSS"
            else
                item.edge.source = infectedOrder[position] or ""
            end
        end

        for _, item in ipairs(edges) do
            local target = item.edge.target
            if self:IsSlotActive(target) and not infected[target] then
                infected[target] = true
                tinsert(infectedOrder, target)
            end
        end
    end
end

function Addon:IsBiteTargetAvailable(index, slot)
    index = tonumber(index)
    local edge = index and self.db and self.db.bites and self.db.bites[index]
    if not edge or not self:IsSlotActive(slot) then
        return false
    end

    local selectedWave = tonumber(edge.wave)
    if not selectedWave then
        return false
    end

    for otherIndex, otherEdge in ipairs(self.db.bites) do
        local otherWave = tonumber(otherEdge.wave)
        if otherIndex ~= index and otherWave and otherWave < selectedWave and otherEdge.target == slot then
            return false
        end
    end
    return true
end

function Addon:SetBiteTarget(index, slot, skipAutoSync)
    index = tonumber(index)
    if not self:IsBiteTargetAvailable(index, slot) then
        return false
    end

    local edge = self.db.bites[index]
    local oldTarget = edge.target
    local followsFirstBite = index == 1 and oldTarget ~= slot and self:GetSlotRole(oldTarget) ~= "TANK"
    if oldTarget ~= slot then
        for otherIndex, otherEdge in ipairs(self.db.bites) do
            if otherIndex ~= index and otherEdge.target == slot then
                otherEdge.target = oldTarget
                break
            end
        end
        edge.target = slot
    end

    if followsFirstBite then
        for _, record in ipairs(self.db.cooldowns.threat or {}) do
            if record.target == oldTarget then
                record.target = slot
            end
        end
    end

    self:RebuildBiteSources()
    if not skipAutoSync then
        self:ScheduleAutoSync()
    end
    self:RefreshUI()
    return true
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

function Addon:EnqueueMessage(item)
    if item.category ~= "CONFIG" then
        for index, queued in ipairs(self.messageQueue) do
            if queued.category == "CONFIG" then
                tinsert(self.messageQueue, index, item)
                return
            end
        end
    end
    tinsert(self.messageQueue, item)
end

function Addon:EnqueueChat(message, channel, target)
    self:EnqueueMessage({
        kind = "CHAT",
        message = tostring(message or ""),
        channel = channel,
        target = target,
    })
end

function Addon:EnqueueAddon(message, channel, target, category)
    self:EnqueueMessage({
        kind = "ADDON",
        message = tostring(message or ""),
        channel = channel,
        target = target,
        category = category,
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

    if whisperPlayers and self.db.options.whisperAssignments and self:CanSendAssignmentWhispers() and wave > 1 then
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
    self.state.initialBiteDetected = false
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
    self.state.initialBiteDetected = false
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
    self.state.initialBiteDetected = wave > 1
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

function Addon:DetectInitialBossBite(sourceName, targetName)
    if not self.state.active or self.state.currentWave ~= 1 or self.state.initialBiteDetected then
        return false
    end
    if not self:IsBossName(sourceName) or self:Trim(targetName) == "" then
        return false
    end

    local firstBite = self:GetWaveEdges(1)[1]
    if not firstBite or self.state.completed[firstBite.index] then
        return false
    end

    self.state.initialBiteDetected = true
    local targetSlot = self:GetSlotForName(targetName)
    if not targetSlot then
        self:Print("Primera mordida detectada en " .. tostring(targetName) .. ", pero ese personaje no está en la plantilla. El árbol no se modificó.")
        return false
    end

    local plannedSlot = firstBite.edge.target
    if not self:SetBiteTarget(firstBite.index, targetSlot, true) then
        self:Print("No se pudo adaptar el árbol a la primera mordida de " .. tostring(targetName) .. ".")
        return false
    end

    if plannedSlot ~= targetSlot then
        self:Print("Primera mordida real: " .. self:GetSlotName(targetSlot) .. " (" .. self:GetSlotLabel(targetSlot) .. "). Árbol actualizado automáticamente.")
    else
        self:Print("Primera mordida confirmada: " .. self:GetSlotName(targetSlot) .. " (" .. self:GetSlotLabel(targetSlot) .. ").")
    end
    return true
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
            if self.db.options.whisperAssignments and self:CanSendAssignmentWhispers() then
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

    local isBiteEvent = (subevent == "SPELL_CAST_SUCCESS" or subevent == "SPELL_AURA_APPLIED") and self:IsBiteSpell(data.spellId, data.spellName)
    local isEssenceEvent = subevent == "SPELL_AURA_APPLIED" and self:IsEssenceSpell(data.spellId, data.spellName)
    if isBiteEvent or isEssenceEvent then
        self:DetectInitialBossBite(data.sourceName, data.destName)
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
    local infectedOrder = {}
    local expectedByWave = { 1, 1, 2, 4, 8 }
    for wave = 1, 5 do
        local edges = self:GetWaveEdges(wave)
        if #edges ~= expectedByWave[wave] then
            AddIssue("La mordida " .. wave .. " tiene " .. #edges .. " asignaciones; debe tener " .. expectedByWave[wave] .. ".")
        end

        local sources = {}
        local newTargets = {}
        local newTargetOrder = {}
        for position, item in ipairs(edges) do
            local edge = item.edge
            if wave == 1 then
                if edge.source ~= "BOSS" then
                    AddIssue("La primera mordida debe salir de BOSS.")
                end
            else
                local expectedSource = infectedOrder[position]
                if edge.source ~= expectedSource then
                    AddIssue("El origen de la fila " .. item.index .. " debe ser " .. tostring(expectedSource) .. " según el orden automático.")
                end
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
                elseif not infected[edge.target] then
                    tinsert(newTargetOrder, edge.target)
                end
                newTargets[edge.target] = true
            end
        end

        for _, target in ipairs(newTargetOrder) do
            infected[target] = true
            tinsert(infectedOrder, target)
        end
    end

    local cooldownGroupNames = {
        aura = "Aura Mastery",
        flight1 = "Primer vuelo",
        flight2 = "Segundo vuelo",
        threat = "MD/Tricks",
    }
    for group, records in pairs(self.db.cooldowns) do
        local assignedUsers = {}
        for index, record in ipairs(records) do
            local userField = group == "threat" and "source" or "slot"
            local userSlot = record[userField]
            if userSlot and userSlot ~= "" then
                if assignedUsers[userSlot] then
                    AddIssue(self:GetSlotLabel(userSlot) .. " está asignado más de una vez en " .. (cooldownGroupNames[group] or tostring(group)) .. ".")
                else
                    assignedUsers[userSlot] = true
                end
            end

            if group == "threat" then
                if not self:IsCooldownSlotEligible(group, index, "source", record.source, false) then
                    AddIssue(self:GetSlotLabel(record.source) .. " no puede lanzar " .. tostring(record.label) .. ".")
                end
                if not self:IsCooldownSlotEligible(group, index, "target", record.target, false) then
                    AddIssue("Destino inválido para " .. tostring(record.label) .. ": debe ser un tanque o la primera mordida.")
                end
            elseif not self:IsCooldownSlotEligible(group, index, "slot", record.slot, false) then
                AddIssue(self:GetSlotLabel(record.slot) .. " no puede usar " .. tostring(record.label) .. ".")
            end
        end
    end

    local positioned = {}
    for _, zoneId in ipairs(self.SLOT_ORDER) do
        local slot = self.db.zoneAssignments and self.db.zoneAssignments[zoneId] or ""
        local role = self.ZONE_POSITION_ROLES[zoneId]
        if slot ~= "" then
            if not self:IsSlotActive(slot) then
                AddIssue("Puesto inválido en la zona " .. zoneId .. ": " .. tostring(slot) .. ".")
            elseif self:GetSlotRole(slot) ~= role then
                AddIssue(self:GetSlotLabel(slot) .. " no corresponde a una zona " .. role .. ".")
            elseif positioned[slot] then
                AddIssue(self:GetSlotLabel(slot) .. " aparece en dos posiciones del mapa.")
            else
                positioned[slot] = zoneId
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

function Addon:GetGroupUnitTokens()
    local units = {}
    local raidCount = GetNumRaidMembers and GetNumRaidMembers() or 0
    if raidCount > 0 then
        for index = 1, raidCount do
            tinsert(units, "raid" .. tostring(index))
        end
        return units
    end

    tinsert(units, "player")
    local partyCount = GetNumPartyMembers and GetNumPartyMembers() or 0
    for index = 1, partyCount do
        tinsert(units, "party" .. tostring(index))
    end
    return units
end

function Addon:DetectTalentSpec(classKey, isInspect)
    local class = self.CLASSES[classKey]
    if not class or not GetTalentTabInfo then
        return nil
    end

    local talentGroup = GetActiveTalentGroup and GetActiveTalentGroup(isInspect and true or false) or nil
    local bestIndex
    local bestPoints = -1
    for index = 1, 3 do
        local _, _, pointsSpent = GetTalentTabInfo(index, isInspect and true or false, false, talentGroup)
        pointsSpent = tonumber(pointsSpent) or 0
        if pointsSpent > bestPoints then
            bestIndex = index
            bestPoints = pointsSpent
        end
    end

    if bestPoints <= 0 or not class.specs[bestIndex] then
        return nil
    end
    return class.specs[bestIndex].id
end

function Addon:QueueInspectUnit(unit)
    if not unit or not UnitExists or not UnitExists(unit) or (UnitIsUnit and UnitIsUnit(unit, "player")) then
        return
    end

    local name = UnitName(unit)
    local key = self:NormalizeName(name)
    local member = self:GetGuildMemberProfile(name)
    if key == "" or not member or not member.inGroup or self.inspectQueued[key] then
        return
    end

    self.inspectQueued[key] = true
    tinsert(self.inspectQueue, { unit = unit, name = name, key = key })
end

function Addon:RefreshGroupMemberProfiles()
    if not self.db or not UnitName or not UnitClass then
        return
    end

    for _, member in pairs(self.db.guildMembers) do
        member.inGroup = false
    end

    local raidCount = GetNumRaidMembers and GetNumRaidMembers() or 0
    local partyCount = GetNumPartyMembers and GetNumPartyMembers() or 0
    local hasGroup = raidCount > 0 or partyCount > 0
    for _, unit in ipairs(self:GetGroupUnitTokens()) do
        if not UnitExists or UnitExists(unit) then
            local name = UnitName(unit)
            local _, classKey = UnitClass(unit)
            if name and classKey then
                local connected = not UnitIsConnected or UnitIsConnected(unit)
                local member = self:RememberPlayerProfile(name, classKey, nil, connected, nil)
                member.inGroup = hasGroup and true or false
                if UnitIsUnit and UnitIsUnit(unit, "player") then
                    local specId = self:DetectTalentSpec(classKey, false)
                    if specId then
                        member = self:RememberPlayerProfile(name, classKey, specId, connected, nil, "talents")
                    end
                elseif member and member.inGroup and connected then
                    self:QueueInspectUnit(unit)
                end
            end
        end
    end
    self:RefreshUI()
end

function Addon:UpdateAssignedPlayerSpec(name, specId)
    local changed = false
    for _, slot in ipairs(self:GetActiveSlotOrder()) do
        local record = self.db.roster[slot]
        if record and self:NormalizeName(record.name) == self:NormalizeName(name) and self:IsSpecAllowedForSlot(slot, specId) then
            if record.spec ~= specId then
                record.spec = specId
                changed = true
            end
        end
    end
    if changed then
        self:ScheduleAutoSync()
    end
    return changed
end

function Addon:HandleInspectReady(guid)
    local pending = self.pendingInspect
    if not pending or (guid and pending.guid and guid ~= pending.guid) then
        return
    end
    if UnitGUID and pending.guid and UnitGUID(pending.unit) ~= pending.guid then
        self.pendingInspect = nil
        return
    end

    local _, classKey = UnitClass(pending.unit)
    local specId = classKey and self:DetectTalentSpec(classKey, true) or nil
    if specId then
        self:RememberPlayerProfile(pending.name, classKey, specId, true, nil, "inspect")
        self:UpdateAssignedPlayerSpec(pending.name, specId)
    else
        self:QueueInspectUnit(pending.unit)
    end

    self.pendingInspect = nil
    if ClearInspectPlayer and (not InspectFrame or not InspectFrame:IsShown()) then
        ClearInspectPlayer()
    end
    self:RefreshUI()
end

function Addon:ProcessInspectQueue(elapsed)
    if not self.db then
        return
    end

    if self.pendingInspect then
        self.pendingInspect.elapsed = (self.pendingInspect.elapsed or 0) + elapsed
        if self.pendingInspect.elapsed >= 6 then
            local unit = self.pendingInspect.unit
            self.pendingInspect = nil
            if ClearInspectPlayer and (not InspectFrame or not InspectFrame:IsShown()) then
                ClearInspectPlayer()
            end
            self:QueueInspectUnit(unit)
        end
        return
    end

    self.inspectElapsed = self.inspectElapsed + elapsed
    if self.inspectElapsed < 2 or #self.inspectQueue == 0 then
        return
    end
    self.inspectElapsed = 0

    local attempts = #self.inspectQueue
    while attempts > 0 do
        attempts = attempts - 1
        local item = tremove(self.inspectQueue, 1)
        self.inspectQueued[item.key] = nil
        local validUnit = UnitExists and UnitExists(item.unit)
            and self:NormalizeName(UnitName(item.unit)) == item.key
            and (not UnitIsConnected or UnitIsConnected(item.unit))
        if validUnit then
            local canInspect = CanInspect and CanInspect(item.unit)
            local inRange = not CheckInteractDistance or CheckInteractDistance(item.unit, 1)
            local inCombat = InCombatLockdown and InCombatLockdown()
            local inspectFrameOpen = InspectFrame and InspectFrame:IsShown()
            if canInspect and inRange and not inCombat and not inspectFrameOpen and NotifyInspect then
                self.pendingInspect = {
                    unit = item.unit,
                    name = item.name,
                    guid = UnitGUID and UnitGUID(item.unit) or nil,
                    elapsed = 0,
                }
                NotifyInspect(item.unit)
                return
            end
            self:QueueInspectUnit(item.unit)
        end
    end
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
    if changed > 0 then
        self:ScheduleAutoSync()
    end
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

function Addon:CanSynchronizeConfiguration()
    if GetNumRaidMembers and GetNumRaidMembers() > 0 then
        return self:CanLeadRaid()
    end
    if GetNumPartyMembers and GetNumPartyMembers() > 0 then
        return IsPartyLeader and IsPartyLeader()
    end
    return false
end

function Addon:ScheduleAutoSync()
    if not self.db or not self.db.options.autoSync or self.receivingSync or not self:CanSynchronizeConfiguration() then
        return false
    end
    self.autoSyncPending = true
    self.autoSyncElapsed = 0
    return true
end

function Addon:CancelAutoSync()
    self.autoSyncPending = false
    self.autoSyncElapsed = 0
end

function Addon:ProcessAutoSync(elapsed)
    if not self.autoSyncPending then
        return
    end
    if not self.db or not self.db.options.autoSync or self.receivingSync or not self:CanSynchronizeConfiguration() then
        self:CancelAutoSync()
        return
    end

    self.autoSyncElapsed = self.autoSyncElapsed + elapsed
    if self.autoSyncElapsed < self.AUTO_SYNC_DELAY then
        return
    end

    self:CancelAutoSync()
    self:SyncConfiguration(true)
end

function Addon:CanSendAssignmentWhispers()
    if GetNumRaidMembers and GetNumRaidMembers() > 0 then
        return self:CanLeadRaid()
    end
    if GetNumPartyMembers and GetNumPartyMembers() > 0 then
        return IsPartyLeader and IsPartyLeader()
    end
    return true
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

function Addon:DiscardQueuedConfigurationSync()
    for index = #self.messageQueue, 1, -1 do
        if self.messageQueue[index].category == "CONFIG" then
            tremove(self.messageQueue, index)
        end
    end
end

function Addon:QueueSync(fields, channel, category)
    local encoded = {}
    for _, field in ipairs(fields) do
        tinsert(encoded, EscapeField(field))
    end
    self:EnqueueAddon(table.concat(encoded, "|"), channel, nil, category)
end

function Addon:SyncConfiguration(silent)
    local channel = self:GetAddonChannel()
    if not channel then
        if not silent then
            self:Print("Debes estar en grupo o banda para sincronizar.")
        end
        return false
    end
    if not self:CanSynchronizeConfiguration() then
        if not silent then
            self:Print("Solo el líder o un asistente puede sincronizar la configuración.")
        end
        return false
    end

    self:CancelAutoSync()
    self:DiscardQueuedConfigurationSync()
    local category = "CONFIG"
    self:QueueSync({ "BEGIN", self.DB_VERSION }, channel, category)
    for _, slot in ipairs(self.SLOT_ORDER) do
        local record = self.db.roster[slot]
        self:QueueSync({ "ROSTER", slot, record.name, record.spec, record.role or "" }, channel, category)
    end
    for index, edge in ipairs(self.db.bites) do
        self:QueueSync({ "BITE", index, edge.wave, edge.source, edge.target }, channel, category)
    end
    for _, group in ipairs({ "aura", "flight1", "flight2", "threat" }) do
        for index, record in ipairs(self.db.cooldowns[group]) do
            self:QueueSync({ "CD", group, index, record.label, record.slot or "", record.source or "", record.target or "" }, channel, category)
        end
    end
    for key, note in pairs(self.db.zones) do
        self:QueueSync({ "ZONE", key, note }, channel, category)
    end
    for _, zoneId in ipairs(self.SLOT_ORDER) do
        self:QueueSync({ "ZPOS", zoneId, self.db.zoneAssignments[zoneId] or "" }, channel, category)
    end
    self:QueueSync({ "END" }, channel, category)
    if not silent then
        self:Print("Sincronización encolada para la banda.")
    end
    return true
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
            self:PrepareZoneAssignments()
            self:RebuildBiteSources()
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
        self:RememberRosterPlayer(slot, "sync")
    elseif kind == "BITE" then
        local index = tonumber(fields[2])
        if index and self.db.bites[index] then
            self.db.bites[index].wave = tonumber(fields[3]) or self.db.bites[index].wave
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
    elseif kind == "ZPOS" and self.ZONE_POSITION_ROLES[fields[2]] then
        self.db.zoneAssignments[fields[2]] = fields[3] or ""
    elseif kind == "STATE" then
        self.state.active = tonumber(fields[2]) == 1
        self.state.currentWave = tonumber(fields[3]) or 1
        self.state.initialBiteDetected = self.state.currentWave > 1
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
    self:RequestGuildRoster()
    self:RefreshGroupMemberProfiles()
    self:Print("Cargado. Usa /bql para abrir la ventana.")
end

Addon.eventFrame = CreateFrame("Frame")
Addon.eventFrame:RegisterEvent("ADDON_LOADED")
Addon.eventFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
Addon.eventFrame:RegisterEvent("CHAT_MSG_ADDON")
Addon.eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
Addon.eventFrame:RegisterEvent("RAID_ROSTER_UPDATE")
Addon.eventFrame:RegisterEvent("PARTY_MEMBERS_CHANGED")
Addon.eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
Addon.eventFrame:RegisterEvent("GUILD_ROSTER_UPDATE")
Addon.eventFrame:RegisterEvent("INSPECT_READY")

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
        Addon:RefreshGroupMemberProfiles()
        Addon:RefreshUI()
    elseif event == "PARTY_MEMBERS_CHANGED" then
        Addon:RefreshGroupMemberProfiles()
    elseif event == "PLAYER_ENTERING_WORLD" then
        Addon:RequestGuildRoster()
        Addon:RefreshGroupMemberProfiles()
    elseif event == "GUILD_ROSTER_UPDATE" then
        Addon:RefreshGuildRosterCache()
        Addon:RefreshGroupMemberProfiles()
    elseif event == "INSPECT_READY" then
        Addon:HandleInspectReady(...)
    end
end)

Addon.eventFrame:SetScript("OnUpdate", function(_, elapsed)
    Addon:ProcessMessageQueue(elapsed)
    Addon:ProcessInspectQueue(elapsed)
    Addon:ProcessAutoSync(elapsed)
end)
