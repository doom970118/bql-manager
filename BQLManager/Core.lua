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
local strlen = string.len
local strlower = string.lower
local strsub = string.sub
local strupper = string.upper
local tinsert = table.insert
local tremove = table.remove
local tsort = table.sort
local type = type
local tostring = tostring
local L = function(text, ...)
    return Addon:Text(text, ...)
end
local MESSAGE_SEPARATOR = "@"
local PACKED_RECORD_SEPARATOR = "|"
local TRUSTED_SPEC_SOURCES = {
    talents = true,
    inspect = true,
    manual = true,
}

Addon.state = {
    active = false,
    currentWave = 1,
    completed = {},
    startedAt = nil,
    initialBiteDetected = false,
}
Addon.plannedBitesSnapshot = nil

Addon.messageQueue = {}
Addon.queueElapsed = 0
Addon.inspectQueue = {}
Addon.inspectQueued = {}
Addon.inspectElapsed = 0
Addon.pendingInspect = nil
Addon.pendingSpecVerifications = {}
Addon.rosterVerification = nil
Addon.lastValidationIssues = nil
Addon.validationHasRun = false
Addon.encounterCombatObserved = false
Addon.encounterEndElapsed = 0
Addon.encounterCombatCheckElapsed = 0
Addon.autoSyncPending = false
Addon.autoSyncElapsed = 0
Addon.AUTO_SYNC_DELAY = 0.25
Addon.CHAT_MESSAGE_INTERVAL = 0.22
Addon.ADDON_MESSAGE_INTERVAL = 0.03
Addon.MAX_ADDON_MESSAGE_BYTES = 230
Addon.SYNC_DISCOVERY_DELAY = 1.0
Addon.SYNC_REPORT_TIMEOUT = 10.0
Addon.SYNC_UI_REFRESH_DELAY = 0.08
Addon.INSPECT_ASSIGNMENT_TIMEOUT = 12.0
Addon.INSPECT_VERIFICATION_QUEUE_TIMEOUT = 60.0
Addon.syncSequence = 0
Addon.syncReport = nil
Addon.outgoingSyncActive = false
Addon.pendingManualSync = false
Addon.syncUIRefreshPending = false
Addon.syncUIRefreshElapsed = 0
Addon.receivingPackedSync = nil
Addon.verifiedGroupSpecs = {}

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
        local incomingSource = specSource or member.specSource or "roster"
        local existingSpec = self:NormalizeSpecId(member.spec)
        local existingTrusted = TRUSTED_SPEC_SOURCES[member.specSource] == true
        local incomingTrusted = TRUSTED_SPEC_SOURCES[incomingSource] == true
        if not existingSpec or incomingTrusted or not existingTrusted then
            member.spec = normalizedSpec
            member.classKey = spec.classKey
            member.specSource = incomingSource
        end
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

    local savedSpec = self:GetSpecDefinition(member.spec)
    local classKey = member.classKey or (savedSpec and savedSpec.classKey)
    return self:ClassHasSpecForSlot(classKey, slot)
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
    self:NormalizeCooldownAssignments()
    self.db.version = self.DB_VERSION
end

function Addon:ResetDatabase()
    if not self:CanModifyConfiguration() then
        return false
    end
    _G.BQLManagerDB = DeepCopy(self.DEFAULTS)
    self.db = _G.BQLManagerDB
    self:PrepareRoster()
    self.lastValidationIssues = nil
    self.validationHasRun = false
    self:ResetEncounter(false)
    self:RefreshUI()
    self:Print(L("Configuración inicial restaurada."))
    return true
end

function Addon:RefreshUI(fromSync)
    if not self.UI then
        return
    end
    if fromSync and self.UI.RefreshFromSync then
        self.UI:RefreshFromSync()
    elseif self.UI.Refresh then
        self.UI:Refresh()
    end
end

function Addon:IsConfigurationLocked()
    return self.state and self.state.active == true
end

function Addon:CanEditConfiguration(silent)
    local allowed = true
    if GetNumRaidMembers and GetNumRaidMembers() > 0 then
        allowed = ((IsRaidLeader and IsRaidLeader()) or (IsRaidOfficer and IsRaidOfficer())) and true or false
    elseif GetNumPartyMembers and GetNumPartyMembers() > 0 then
        allowed = (IsPartyLeader and IsPartyLeader()) and true or false
    end
    if not allowed and not silent then
        self:Print(L("Modo lectura: solo el líder o un asistente puede modificar la configuración."))
    end
    return allowed
end

function Addon:CanModifyConfiguration(silent)
    if not self:CanEditConfiguration(silent) then
        return false
    end
    if self:IsConfigurationLocked() then
        if not silent then
            self:Print(L("La configuración está bloqueada durante el encuentro. Usa Detener para editarla."))
        end
        return false
    end
    return true
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
    if not self:CanModifyConfiguration() then
        return false
    end
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
    elseif strfind(label, "Marea", 1, true) or strfind(label, "Mana Tide", 1, true) then
        return "MANA_TIDE"
    elseif strfind(label, "Himno", 1, true) or strfind(label, "Hymn", 1, true) then
        return "HYMN"
    elseif strfind(label, "Tranquilidad", 1, true) or strfind(label, "Tranquility", 1, true) then
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

function Addon:IsCooldownSlotAssignedInOtherFlight(group, index, slot)
    slot = self:Trim(slot)
    if slot == "" or (group ~= "flight1" and group ~= "flight2") then
        return false
    end

    index = tonumber(index)
    local otherGroup = group == "flight1" and "flight2" or "flight1"
    local otherRecords = self.db and self.db.cooldowns and self.db.cooldowns[otherGroup]
    local otherRecord = index and otherRecords and otherRecords[index]
    return otherRecord and self:Trim(otherRecord.slot) == slot or false
end

function Addon:GetCooldownRequiredClass(kind)
    if kind == "AURA_MASTERY" or kind == "DSAC" then
        return "PALADIN"
    elseif kind == "MANA_TIDE" then
        return "SHAMAN"
    elseif kind == "HYMN" then
        return "PRIEST"
    elseif kind == "TRANQUILITY" then
        return "DRUID"
    elseif kind == "MISDIRECTION" then
        return "HUNTER"
    elseif kind == "TRICKS" then
        return "ROGUE"
    end
    return nil
end

function Addon:IsCooldownSlotEligible(group, index, field, slot, allowDpsPromotion)
    index = tonumber(index)
    local records = self.db and self.db.cooldowns and self.db.cooldowns[group]
    local record = index and records and records[index]
    if not record then
        return false
    end

    local validField = (group == "threat" and (field == "source" or field == "target"))
        or (group ~= "threat" and field == "slot")
    if not validField then
        return false
    end

    slot = self:Trim(slot)
    if slot == "" then
        return true
    end
    if not self:IsSlotActive(slot) then
        return false
    end
    local slotRecord = self:GetSlotRecord(slot)
    if not slotRecord or self:IsPlaceholder(slot, slotRecord.name) then
        return false
    end
    if field == "slot" and (group == "flight1" or group == "flight2") then
        if self:IsCooldownSlotAssignedInOtherFlight(group, index, slot) then
            return false
        end
        local otherIndex = self:GetCooldownUserAssignment(group, index, field, slot)
        if otherIndex and record.slot ~= ""
            and self:IsCooldownSlotAssignedInOtherFlight(group, otherIndex, record.slot) then
            return false
        end
    end

    local kind = self:GetCooldownKind(group, index)
    if group == "threat" and field == "target" then
        local role = self:GetSlotRole(slot)
        if role == "TANK" or slot == self:GetFirstBiteTarget() then
            return true
        end
        return allowDpsPromotion == true and (role == "MDPS" or role == "RDPS")
    end

    local requiredClass = self:GetCooldownRequiredClass(kind)
    local classKey = self:GetRosterClassKey(slot)
    if not requiredClass or classKey ~= requiredClass then
        return false
    end

    local verifiedSpecId = slotRecord
        and self.verifiedGroupSpecs[self:NormalizeName(slotRecord.name)]
        or nil
    local spec = self:GetSpecDefinition(verifiedSpecId)
        or (slotRecord and self:GetSpecDefinition(slotRecord.spec))
    if not spec then
        return true
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

function Addon:NormalizeCooldownAssignments()
    if not self.db or not self.db.cooldowns then
        return false
    end

    local changed = false
    for group, records in pairs(self.db.cooldowns) do
        for index, record in ipairs(records) do
            if group == "threat" then
                if record.source and record.source ~= ""
                    and not self:IsCooldownSlotEligible(group, index, "source", record.source, false) then
                    record.source = ""
                    changed = true
                end
                if record.target and record.target ~= ""
                    and not self:IsCooldownSlotEligible(group, index, "target", record.target, false) then
                    record.target = ""
                    changed = true
                end
            elseif record.slot and record.slot ~= ""
                and not self:IsCooldownSlotEligible(group, index, "slot", record.slot, false) then
                record.slot = ""
                changed = true
            end
        end
    end
    return changed
end

function Addon:SetCooldownAssignment(group, index, field, slot)
    if not self:CanModifyConfiguration() then
        return false
    end
    index = tonumber(index)
    slot = self:Trim(slot)
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
            self:Print(L("%s pasa a ser la primera mordida para la asignación de %s.", self:GetSlotName(slot), L(record.label)))
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
    if not self:CanModifyConfiguration() then
        return false
    end
    if not self.SLOT_SET[slot] then
        return
    end
    if field ~= "name" then
        return
    end

    self.db.roster[slot][field] = self:Trim(value)
    self:RememberRosterPlayer(slot, "manual")
    self:NormalizeCooldownAssignments()
    self:ScheduleAutoSync()
    self:RefreshUI()
end

function Addon:ClearRosterSlot(slot)
    if not self:CanModifyConfiguration() then
        return false
    end
    if not self:IsSlotActive(slot) then
        return false
    end

    self:CancelPendingSpecVerificationForSlot(slot)
    local record = self.db.roster[slot]
    record.name = ""
    record.spec = ""
    self:NormalizeCooldownAssignments()
    self:ScheduleAutoSync()
    self:RefreshUI()
    return true
end

function Addon:ClearRoster()
    if not self:CanModifyConfiguration() then
        return false
    end

    self.pendingSpecVerifications = {}
    self.rosterVerification = nil
    self.inspectQueue = {}
    self.inspectQueued = {}
    self.pendingInspect = nil
    if ClearInspectPlayer and (not InspectFrame or not InspectFrame:IsShown()) then
        ClearInspectPlayer()
    end

    for _, slot in ipairs(self.SLOT_ORDER) do
        local record = self.db.roster[slot]
        record.name = ""
        record.spec = ""
    end
    self:NormalizeCooldownAssignments()
    self:ScheduleAutoSync()
    self:RefreshUI()
    self:Print(L("Plantilla limpiada. Se conservaron los puestos, las mordidas y las zonas."))
    return true
end

function Addon:CancelPendingSpecVerificationForSlot(slot)
    local canceled = 0
    for key, request in pairs(self.pendingSpecVerifications or {}) do
        if request.slot == slot then
            self.pendingSpecVerifications[key] = nil
            canceled = canceled + 1
        end
    end
    if canceled > 0 and self.rosterVerification then
        self.rosterVerification.pending = math.max(0, self.rosterVerification.pending - canceled)
        self.rosterVerification.unavailable = self.rosterVerification.unavailable + canceled
        self:FinishRosterSpecVerification()
    end
end

function Addon:AssignGuildMemberToSlot(slot, name)
    if not self:CanModifyConfiguration() then
        return false
    end
    if not self:IsSlotActive(slot) then
        return false
    end

    self:CancelPendingSpecVerificationForSlot(slot)
    local member = self:GetGuildMemberProfile(name)
    local unit = member and self:GetGroupUnitForName(member.name) or nil
    local actualClassKey
    if unit and UnitClass then
        local _
        _, actualClassKey = UnitClass(unit)
    end
    actualClassKey = strupper(self:Trim(actualClassKey))
    if not self.CLASSES[actualClassKey] then
        actualClassKey = nil
    end
    if member and unit and actualClassKey then
        local connected = not UnitIsConnected or UnitIsConnected(unit)
        member = self:RememberPlayerProfile(member.name, actualClassKey, nil, connected, member.inGuild)
        member.inGroup = true
    end

    if not self:IsGuildMemberEligibleForSlot(member, slot) then
        if member and actualClassKey then
            local class = self.CLASSES[actualClassKey]
            self:Print(L("No se asignó %s a %s: su clase actual (%s) no es compatible.", member.name, self:GetSlotLabel(slot), class and class.name or actualClassKey))
        end
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
        local specSource = inferred and "manual" or member.specSource
        self:RememberPlayerProfile(member.name, member.classKey, specId, member.online, member.inGuild, specSource)
    end

    if specId == "" then
        self:Print(L("%s no tiene una spec conocida todavía. Selecciona una spec compatible; quedará guardada para el futuro.", member.name))
    end
    self:NormalizeCooldownAssignments()
    self:ScheduleAutoSync()
    self:RefreshUI()
    return true
end

function Addon:SetRosterSpec(slot, specId)
    if not self:CanModifyConfiguration() then
        return false
    end
    if not self.SLOT_SET[slot] then
        return false
    end

    local normalized = self:NormalizeSpecId(specId)
    if not normalized or not self:IsSpecAllowedForSlot(slot, normalized) then
        return false
    end

    self.db.roster[slot].spec = normalized
    self:RememberRosterPlayer(slot, "manual")
    self:NormalizeCooldownAssignments()
    self:ScheduleAutoSync()
    self:RefreshUI()
    return true
end

function Addon:GetSlotReference(slot)
    for index, edge in ipairs(self.db.bites) do
        if edge.source == slot or edge.target == slot then
            return L("mordidas (fila %d)", index)
        end
    end

    for group, records in pairs(self.db.cooldowns) do
        for index, record in ipairs(records) do
            if record.slot == slot or record.source == slot or record.target == slot then
                return L("cooldowns (%s %d)", tostring(group), index)
            end
        end
    end
    return nil
end

function Addon:AddRosterRole(role)
    if not self:CanModifyConfiguration() then
        return false
    end
    role = strupper(self:Trim(role))
    if not self.ROLE_SET[role] then
        return false
    end

    local counts = self:GetRoleCounts()
    local maximum = self.ROLE_MAXIMUMS[role]
    if maximum and counts[role] >= maximum then
        self:Print(L("%s admite como máximo %d puestos.", role, maximum))
        return false
    end
    if self:GetActiveRosterSize() >= self.MAX_ROSTER_SIZE then
        self:Print(L("La plantilla ya tiene %d puestos. Quita uno antes de añadir otro.", self.MAX_ROSTER_SIZE))
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
            self:Print(L("Puesto %s añadido. Selecciona una especialización compatible.", self:GetSlotLabel(slot)))
            self:PrepareZoneAssignments()
            self:ScheduleAutoSync()
            self:RefreshUI()
            return true
        end
    end
    return false
end

function Addon:RemoveRosterRole(role)
    if not self:CanModifyConfiguration() then
        return false
    end
    role = strupper(self:Trim(role))
    if not self.ROLE_SET[role] then
        return false
    end

    local counts = self:GetRoleCounts()
    local minimum = self.ROLE_MINIMUMS[role] or 0
    if counts[role] <= minimum then
        self:Print(L("%s debe conservar al menos %d puesto(s).", role, minimum))
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
        self:Print(L("No se puede quitar %s porque todavía se usa en %s.", self:GetSlotLabel(slot), reference))
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
    self:Print(L("%s retirado. Su posición queda disponible para otro rol.", oldLabel))
    self:PrepareZoneAssignments()
    self:ScheduleAutoSync()
    self:RefreshUI()
    return true
end

function Addon:SetBiteSlot(index, field, slot)
    if not self:CanModifyConfiguration() then
        return false
    end
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

function Addon:SetBiteTarget(index, slot, skipAutoSync, allowDuringEncounter)
    if not allowDuringEncounter and not self:CanModifyConfiguration() then
        return false
    end
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
    for index, record in ipairs(records) do
        if group == "threat" then
            local sourceValid = self:IsCooldownSlotEligible(group, index, "source", record.source, false)
            local targetValid = self:IsCooldownSlotEligible(group, index, "target", record.target, false)
            local sourceName = sourceValid and record.source ~= "" and self:GetSlotName(record.source) or L("Sin asignar")
            local targetName = targetValid and record.target ~= "" and self:GetSlotName(record.target) or L("Sin asignar")
            tinsert(parts, L(record.label) .. " " .. sourceName .. " > " .. targetName)
        else
            local slotValid = self:IsCooldownSlotEligible(group, index, "slot", record.slot, false)
            local slotName = slotValid and record.slot ~= "" and self:GetSlotName(record.slot) or L("Sin asignar")
            tinsert(parts, L(record.label) .. ": " .. slotName)
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

function Addon:EnqueueAddon(message, channel, target, category, completesConfiguration)
    self:EnqueueMessage({
        kind = "ADDON",
        message = tostring(message or ""),
        channel = channel,
        target = target,
        category = category,
        completesConfiguration = completesConfiguration and true or false,
    })
end

function Addon:ProcessMessageQueue(elapsed)
    if #self.messageQueue == 0 then
        self.queueElapsed = 0
        return
    end

    self.queueElapsed = self.queueElapsed + elapsed
    local item = self.messageQueue[1]
    local interval = item.kind == "ADDON" and self.ADDON_MESSAGE_INTERVAL or self.CHAT_MESSAGE_INTERVAL
    if self.queueElapsed < interval then
        return
    end
    self.queueElapsed = 0

    item = tremove(self.messageQueue, 1)
    if item.kind == "CHAT" then
        if SendChatMessage and item.channel then
            SendChatMessage(item.message, item.channel, nil, item.target)
        end
    elseif item.kind == "ADDON" then
        if SendAddonMessage and item.channel then
            local target = item.target or (UnitName and UnitName("player")) or ""
            SendAddonMessage(self.MESSAGE_PREFIX, item.message, item.channel, target)
        end
    end

    if item.completesConfiguration then
        self.outgoingSyncActive = false
        if self.pendingManualSync then
            self.pendingManualSync = false
            self:SyncConfiguration(false)
        end
    end
end

function Addon:Announce(message)
    if not self:CanEditConfiguration(true) then
        return false
    end
    local channel = self:GetRaidChannel()
    if channel then
        self:EnqueueChat("[BQL] " .. message, channel)
    else
        self:Print(message)
    end
    return true
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
        self:Print(L("La ronda %d no tiene asignaciones.", wave))
        return
    end

    self:Announce(L("Mordida %d: %s", wave, text))

    if whisperPlayers and self.db.options.whisperAssignments and self:CanSendAssignmentWhispers() and wave > 1 then
        for _, item in ipairs(self:GetWaveEdges(wave)) do
            local edge = item.edge
            local sourceName = self:GetSlotName(edge.source)
            local targetName = self:GetSlotName(edge.target)
            if not self:IsPlaceholder(edge.source, sourceName) then
                self:Whisper(sourceName, L("En la mordida %d muerde a %s (%s).", wave, targetName, edge.target))
            end
        end
    end
end

function Addon:AnnounceFullPlan()
    if not self:CanEditConfiguration() then
        return false
    end
    for wave = 1, 5 do
        local text = self:FormatWave(wave, false)
        if text ~= "" then
            self:Announce(L("Mordida %d: %s", wave, text))
        end
    end
    self:Announce("Aura Mastery: " .. self:FormatCooldownGroup("aura"))
    self:Announce(L("Primer vuelo: %s", self:FormatCooldownGroup("flight1")))
    self:Announce(L("Segundo vuelo: %s", self:FormatCooldownGroup("flight2")))
    self:Announce("MD/Tricks: " .. self:FormatCooldownGroup("threat"))
    return true
end

function Addon:CapturePlannedBites()
    if not self.db or type(self.db.bites) ~= "table" then
        self.plannedBitesSnapshot = nil
        return false
    end
    self.plannedBitesSnapshot = DeepCopy(self.db.bites)
    return true
end

function Addon:RestorePlannedBites()
    local snapshot = self.plannedBitesSnapshot
    self.plannedBitesSnapshot = nil
    if not self.db or type(snapshot) ~= "table" then
        return false
    end
    self.db.bites = DeepCopy(snapshot)
    self:RebuildBiteSources()
    return true
end

function Addon:StartEncounter(announce)
    if not self:CanEditConfiguration() then
        return false
    end
    if self.state.active then
        self:Print(L("El encuentro ya está activo. Usa Detener antes de iniciarlo de nuevo."))
        return false
    end
    self:CancelAutoSync()
    self:DiscardQueuedConfigurationSync()
    self:CapturePlannedBites()
    self.state.active = true
    self.state.currentWave = 1
    self.state.completed = {}
    self.state.startedAt = GetTime and GetTime() or 0
    self.state.initialBiteDetected = false
    self.encounterCombatObserved = UnitAffectingCombat and UnitAffectingCombat("player") and true or false
    self.encounterEndElapsed = 0
    self.encounterCombatCheckElapsed = 0
    if announce ~= false then
        self:Announce(L("Seguimiento iniciado."))
        self:AnnounceWave(1, false)
    end
    self:BroadcastState()
    self:RefreshUI()
    return true
end

function Addon:StopEncounter(reason, announce)
    local automatic = reason == "victory" or reason == "combat_end"
    local canControl = self:CanEditConfiguration(automatic)
    if not automatic and not canControl then
        return false
    end
    if not self.state.active then
        return false
    end
    self.state.active = false
    self:RestorePlannedBites()
    self.encounterCombatObserved = false
    self.encounterEndElapsed = 0
    self.encounterCombatCheckElapsed = 0
    if announce ~= false and canControl then
        if reason == "victory" then
            self:Announce(L("Encuentro completado."))
        else
            self:Announce(L("Seguimiento detenido."))
        end
    end
    self:BroadcastState()
    self:RefreshUI()
    return true
end

function Addon:ResetEncounter(announce)
    if not self:CanModifyConfiguration() then
        return false
    end
    self.state.active = false
    self.state.currentWave = 1
    self.state.completed = {}
    self.state.startedAt = nil
    self.state.initialBiteDetected = false
    self.encounterCombatObserved = false
    self.encounterEndElapsed = 0
    self.encounterCombatCheckElapsed = 0
    if announce then
        self:Announce(L("Progreso de mordidas reiniciado."))
    end
    self:BroadcastState()
    self:RefreshUI()
    return true
end

function Addon:SetWave(wave, announce)
    if not self:CanModifyConfiguration() then
        return false
    end
    self:CancelAutoSync()
    self:DiscardQueuedConfigurationSync()
    wave = floor(tonumber(wave) or 1)
    if wave < 1 then
        wave = 1
    elseif wave > 5 then
        wave = 5
    end

    self:CapturePlannedBites()
    self.state.currentWave = wave
    self.state.active = true
    self.state.completed = {}
    self.state.initialBiteDetected = wave > 1
    if announce ~= false then
        self:AnnounceWave(wave, true)
    end
    self:BroadcastState()
    self:RefreshUI()
    return true
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
        self:Announce(L("Árbol de mordidas completado."))
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
            self:Print(L("Mordida registrada: %s > %s.", self:GetSlotName(edge.source), self:GetSlotName(edge.target)))
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
        self:Print(L("Primera mordida detectada en %s, pero ese personaje no está en la plantilla. El árbol no se modificó.", tostring(targetName)))
        return false
    end

    local plannedSlot = firstBite.edge.target
    if not self.plannedBitesSnapshot then
        self:CapturePlannedBites()
    end
    if not self:SetBiteTarget(firstBite.index, targetSlot, true, true) then
        self:Print(L("No se pudo adaptar el árbol a la primera mordida de %s.", tostring(targetName)))
        return false
    end

    if plannedSlot ~= targetSlot then
        self:Print(L("Primera mordida real: %s (%s). Árbol actualizado automáticamente.", self:GetSlotName(targetSlot), self:GetSlotLabel(targetSlot)))
    else
        self:Print(L("Primera mordida confirmada: %s (%s).", self:GetSlotName(targetSlot), self:GetSlotLabel(targetSlot)))
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
            if self.BiteHighlights then
                self.BiteHighlights:ActivateFrenzySource(slot)
            end
            local targetName = self:GetSlotName(edge.target)
            if self.db.options.whisperAssignments and self:CanSendAssignmentWhispers() then
                self:Whisper(playerName, L("¡MUERDE AHORA a %s (%s)!", targetName, edge.target))
            end
            self:Print(L("%s debe morder a %s.", playerName, targetName))
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

    if not self.state.active and self.db.options.autoStart and self:CanEditConfiguration(true) and self:IsBossName(data.sourceName) then
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
        local sourceSlot = self:GetSlotForName(data.sourceName)
        if sourceSlot and self.BiteHighlights then
            self.BiteHighlights:DeactivateFrenzySource(sourceSlot)
        end
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
        AddIssue(L("La plantilla tiene %d de %d puestos activos.", #activeSlots, self.MAX_ROSTER_SIZE))
    end
    local roleCounts = self:GetRoleCounts()
    local tankMinimum = self.ROLE_MINIMUMS.TANK or 2
    if roleCounts.TANK < tankMinimum then
        AddIssue(L("La plantilla debe conservar exactamente %d tanques.", tankMinimum))
    end
    if roleCounts.TANK > (self.ROLE_MAXIMUMS.TANK or 2) then
        AddIssue(L("La plantilla no puede tener más de dos tanques."))
    end
    if roleCounts.HEALER < (self.ROLE_MINIMUMS.HEALER or 1) then
        AddIssue(L("La plantilla debe conservar al menos un healer."))
    end

    local names = {}
    for _, slot in ipairs(activeSlots) do
        local record = self.db.roster[slot]
        local name = record and self:Trim(record.name) or ""
        if self:IsPlaceholder(slot, name) then
            AddIssue(L("%s no tiene un personaje asignado.", self:GetSlotLabel(slot)))
        else
            local classKey = self:GetRosterClassKey(slot)
            if not classKey then
                AddIssue(L("%s no tiene una clase conocida.", self:GetSlotLabel(slot)))
            elseif not self:ClassHasSpecForSlot(classKey, slot) then
                AddIssue(L("%s tiene una clase incompatible con su función.", self:GetSlotLabel(slot)))
            end
            local normalized = self:NormalizeName(name)
            if names[normalized] then
                AddIssue(L("%s está asignado a %s y %s.", name, names[normalized], self:GetSlotLabel(slot)))
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
            AddIssue(L("La mordida %d tiene %d asignaciones; debe tener %d.", wave, #edges, expectedByWave[wave]))
        end

        local sources = {}
        local newTargets = {}
        local newTargetOrder = {}
        for position, item in ipairs(edges) do
            local edge = item.edge
            if wave == 1 then
                if edge.source ~= "BOSS" then
                    AddIssue(L("La primera mordida debe salir de BOSS."))
                end
            else
                local expectedSource = infectedOrder[position]
                if edge.source ~= expectedSource then
                    AddIssue(L("El origen de la fila %d debe ser %s según el orden automático.", item.index, tostring(expectedSource)))
                end
                if not self:IsSlotActive(edge.source) then
                    AddIssue(L("Origen de mordida inválido: %s.", tostring(edge.source)))
                elseif not infected[edge.source] then
                    AddIssue(L("%s muerde en la ronda %d sin haber sido mordido antes.", edge.source, wave))
                end
                if sources[edge.source] then
                    AddIssue(L("%s aparece dos veces como origen en la mordida %d.", edge.source, wave))
                end
                sources[edge.source] = true
            end

            if not self:IsSlotActive(edge.target) then
                AddIssue(L("Destino de mordida inválido: %s.", tostring(edge.target)))
            else
                if infected[edge.target] then
                    AddIssue(L("%s recibe otra mordida después de estar infectado.", edge.target))
                end
                if newTargets[edge.target] then
                    AddIssue(L("%s recibe dos mordidas en la ronda %d.", edge.target, wave))
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
        flight1 = L("Primer vuelo"),
        flight2 = L("Segundo vuelo"),
        threat = "MD/Tricks",
    }
    for group, records in pairs(self.db.cooldowns) do
        local assignedUsers = {}
        for index, record in ipairs(records) do
            local userField = group == "threat" and "source" or "slot"
            local userSlot = record[userField]
            if userSlot and userSlot ~= "" then
                if assignedUsers[userSlot] then
                    AddIssue(L("%s está asignado más de una vez en %s.", self:GetSlotLabel(userSlot), cooldownGroupNames[group] or tostring(group)))
                else
                    assignedUsers[userSlot] = true
                end
            end

            if group == "threat" then
                if not self:IsCooldownSlotEligible(group, index, "source", record.source, false) then
                    AddIssue(L("%s no puede lanzar %s.", self:GetSlotLabel(record.source), L(record.label)))
                end
                if not self:IsCooldownSlotEligible(group, index, "target", record.target, false) then
                    AddIssue(L("Destino inválido para %s: debe ser un tanque o la primera mordida.", L(record.label)))
                end
            else
                local crossFlightConflict = self:IsCooldownSlotAssignedInOtherFlight(group, index, record.slot)
                if crossFlightConflict then
                    if group == "flight2" then
                        AddIssue(L("%s no puede usar %s en ambos vuelos.", self:GetSlotLabel(record.slot), L(record.label)))
                    end
                elseif not self:IsCooldownSlotEligible(group, index, "slot", record.slot, false) then
                    AddIssue(L("%s no puede usar %s.", self:GetSlotLabel(record.slot), L(record.label)))
                end
            end
        end
    end

    local positioned = {}
    for _, zoneId in ipairs(self.SLOT_ORDER) do
        local slot = self.db.zoneAssignments and self.db.zoneAssignments[zoneId] or ""
        local role = self.ZONE_POSITION_ROLES[zoneId]
        if slot ~= "" then
            if not self:IsSlotActive(slot) then
                AddIssue(L("Puesto inválido en la zona %s: %s.", zoneId, tostring(slot)))
            elseif self:GetSlotRole(slot) ~= role then
                AddIssue(L("%s no corresponde a una zona %s.", self:GetSlotLabel(slot), role))
            elseif positioned[slot] then
                AddIssue(L("%s aparece en dos posiciones del mapa.", self:GetSlotLabel(slot)))
            else
                positioned[slot] = zoneId
            end
        end
    end

    return issues
end

function Addon:ValidateAndReport()
    if not self:CanModifyConfiguration() then
        return false
    end
    local issues = self:GetValidationIssues()
    self.lastValidationIssues = issues
    self.validationHasRun = true
    if #issues == 0 then
        self:Print(L("Validación correcta: no se detectaron conflictos."))
        return true
    end

    self:Print(L("Validación: %d problema(s).", #issues))
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

function Addon:GetAutomaticRaidMemberSpecForSlot(member, slot)
    if not member or not self:IsSlotActive(slot) then
        return nil, false
    end

    local profile = self:GetGuildMemberProfile(member.name)
    local classKey = strupper(self:Trim(member.classFile or (profile and profile.classKey)))
    if not self:ClassHasSpecForSlot(classKey, slot) then
        return nil, false
    end

    local candidate = {
        classKey = classKey,
        spec = profile and profile.classKey == classKey and profile.spec or "",
    }
    local specId = self:GetGuildMemberSpecForSlot(candidate, slot)
    return specId, true
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

function Addon:GetGroupUnitForName(name)
    local key = self:NormalizeName(name)
    if key == "" or not UnitName then
        return nil
    end

    for _, unit in ipairs(self:GetGroupUnitTokens()) do
        if (not UnitExists or UnitExists(unit)) and self:NormalizeName(UnitName(unit)) == key then
            return unit
        end
    end
    return nil
end

function Addon:IsUnitInInspectRange(unit)
    if not unit or not UnitExists or not UnitExists(unit) or (UnitIsUnit and UnitIsUnit(unit, "player")) then
        return false
    end

    local connected = not UnitIsConnected or UnitIsConnected(unit)
    local inRange = CheckInteractDistance and CheckInteractDistance(unit, 1)
    return connected and inRange and NotifyInspect ~= nil
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

function Addon:QueueInspectUnit(unit, prioritize)
    if not unit or not UnitExists or not UnitExists(unit) or (UnitIsUnit and UnitIsUnit(unit, "player")) then
        return
    end

    local name = UnitName(unit)
    local key = self:NormalizeName(name)
    local member = self:GetGuildMemberProfile(name)
    if key == "" or not member or not member.inGroup then
        return
    end

    if self.pendingInspect and self.pendingInspect.key == key then
        return
    end
    if self.inspectQueued[key] then
        if prioritize then
            for index, item in ipairs(self.inspectQueue) do
                if item.key == key then
                    tremove(self.inspectQueue, index)
                    tinsert(self.inspectQueue, 1, item)
                    self.inspectElapsed = 2
                    break
                end
            end
        end
        return
    end

    self.inspectQueued[key] = true
    local item = { unit = unit, name = name, key = key }
    if prioritize then
        tinsert(self.inspectQueue, 1, item)
        self.inspectElapsed = 2
    else
        tinsert(self.inspectQueue, item)
    end
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
            end
        end
    end
    for key in pairs(self.verifiedGroupSpecs) do
        local member = self.db.guildMembers[key]
        if not member or not member.inGroup then
            self.verifiedGroupSpecs[key] = nil
        end
    end
    self:RefreshUI()
end

function Addon:FinishRosterSpecVerification()
    local verification = self.rosterVerification
    if not verification or verification.building or verification.pending > 0 then
        return
    end

    local cooldownsChanged = self:NormalizeCooldownAssignments()
    if verification.changed or cooldownsChanged then
        self:ScheduleAutoSync()
    end
    self:Print(L(
        "Verificación de specs terminada: %d compatible(s), %d incompatible(s) y %d sin verificar.",
        verification.compatible,
        verification.incompatible,
        verification.unavailable
    ))
    self.rosterVerification = nil
    self:RefreshUI()
end

function Addon:FindEmptyCompatibleRosterSlot(specId, excludedSlot)
    for _, candidateSlot in ipairs(self:GetActiveSlotOrder()) do
        if candidateSlot ~= excludedSlot and self:IsSpecAllowedForSlot(candidateSlot, specId) then
            local candidate = self:GetSlotRecord(candidateSlot)
            if candidate and self:IsPlaceholder(candidateSlot, candidate.name) then
                return candidateSlot
            end
        end
    end
    return nil
end

function Addon:ApplyRosterSpecVerification(slot, name, classKey, specId, wasPending)
    local verification = self.rosterVerification
    if not verification then
        return
    end
    if wasPending then
        verification.pending = math.max(0, verification.pending - 1)
    end

    local record = self:GetSlotRecord(slot)
    if not record or self:NormalizeName(record.name) ~= self:NormalizeName(name) then
        verification.unavailable = verification.unavailable + 1
        self:FinishRosterSpecVerification()
        return
    end

    local normalizedSpec = self:NormalizeSpecId(specId)
    if not normalizedSpec then
        verification.unavailable = verification.unavailable + 1
    else
        local key = self:NormalizeName(name)
        self:RememberPlayerProfile(name, classKey, normalizedSpec, true, nil, "inspect")
        self.verifiedGroupSpecs[key] = normalizedSpec
        if self:IsSpecAllowedForSlot(slot, normalizedSpec) then
            if record.spec ~= normalizedSpec then
                record.spec = normalizedSpec
                verification.changed = true
            end
            verification.compatible = verification.compatible + 1
        else
            local sourceLabel = self:GetSlotLabel(slot)
            local destinationSlot = self:FindEmptyCompatibleRosterSlot(normalizedSpec, slot)
            record.name = ""
            record.spec = ""
            verification.incompatible = verification.incompatible + 1
            verification.changed = true

            if destinationSlot then
                local destination = self:GetSlotRecord(destinationSlot)
                destination.name = name
                destination.spec = normalizedSpec
                self:RememberRosterPlayer(destinationSlot, "inspect")
                self:Print(L(
                    "%s tenía una spec incompatible con %s y fue movido automáticamente a %s.",
                    name,
                    sourceLabel,
                    self:GetSlotLabel(destinationSlot)
                ))
            else
                self:Print(L(
                    "%s tenía una spec incompatible con %s y fue retirado porque no hay un puesto vacío compatible.",
                    name,
                    sourceLabel
                ))
            end
        end
    end
    self:FinishRosterSpecVerification()
end

function Addon:VerifyRosterSpecializations()
    if not self:CanModifyConfiguration() then
        return false
    end
    if InCombatLockdown and InCombatLockdown() then
        self:Print(L("No se pueden inspeccionar specs durante el combate."))
        return false
    end

    self.inspectQueue = {}
    self.inspectQueued = {}
    self.pendingInspect = nil
    self.pendingSpecVerifications = {}
    self.rosterVerification = {
        building = true,
        pending = 0,
        compatible = 0,
        incompatible = 0,
        unavailable = 0,
        changed = false,
    }

    self:RefreshGroupMemberProfiles()
    local rosterSnapshot = {}
    for _, slot in ipairs(self:GetActiveSlotOrder()) do
        local record = self:GetSlotRecord(slot)
        if record and not self:IsPlaceholder(slot, record.name) then
            table.insert(rosterSnapshot, { slot = slot, name = record.name })
        end
    end

    for _, assignment in ipairs(rosterSnapshot) do
        local slot = assignment.slot
        local name = assignment.name
        local unit = self:GetGroupUnitForName(name)
        if not unit then
            self.rosterVerification.unavailable = self.rosterVerification.unavailable + 1
        else
            local _, classKey = UnitClass(unit)
            local connected = not UnitIsConnected or UnitIsConnected(unit)
            local member = self:RememberPlayerProfile(name, classKey, nil, connected, nil)
            if member then
                member.inGroup = true
            end
            if UnitIsUnit and UnitIsUnit(unit, "player") then
                local specId = self:DetectTalentSpec(classKey, false)
                self:ApplyRosterSpecVerification(slot, name, classKey, specId, false)
            elseif self:IsUnitInInspectRange(unit) then
                local key = self:NormalizeName(name)
                self.pendingSpecVerifications[key] = {
                    slot = slot,
                    name = name,
                    elapsed = 0,
                    waitElapsed = 0,
                }
                self.rosterVerification.pending = self.rosterVerification.pending + 1
                self:QueueInspectUnit(unit, true)
            else
                self.rosterVerification.unavailable = self.rosterVerification.unavailable + 1
            end
        end
    end

    self.rosterVerification.building = false
    self:Print(L("Verificación manual iniciada para los jugadores cercanos de la plantilla."))
    self:FinishRosterSpecVerification()
    self:RefreshUI()
    return true
end

function Addon:HandleInspectReady(guid)
    local pending = self.pendingInspect
    if not pending or (guid and pending.guid and guid ~= pending.guid) then
        return
    end
    if UnitGUID and pending.guid and UnitGUID(pending.unit) ~= pending.guid then
        local replacementUnit = self:GetGroupUnitForName(pending.name)
        local prioritize = self.pendingSpecVerifications[pending.key] ~= nil
        self.pendingInspect = nil
        if replacementUnit then
            self:QueueInspectUnit(replacementUnit, prioritize)
        end
        return
    end

    local _, classKey = UnitClass(pending.unit)
    local specId = classKey and self:DetectTalentSpec(classKey, true) or nil
    if not specId then
        return
    end

    local key = self:NormalizeName(pending.name)
    self:RememberPlayerProfile(pending.name, classKey, specId, true, nil, "inspect")
    self.verifiedGroupSpecs[key] = specId
    local verificationRequest = self.pendingSpecVerifications[key]
    self.pendingSpecVerifications[key] = nil

    self.pendingInspect = nil
    if ClearInspectPlayer and (not InspectFrame or not InspectFrame:IsShown()) then
        ClearInspectPlayer()
    end
    if verificationRequest then
        self:ApplyRosterSpecVerification(
            verificationRequest.slot,
            verificationRequest.name,
            classKey,
            specId,
            true
        )
    end
end

function Addon:ProcessInspectQueue(elapsed)
    if not self.db then
        return
    end

    local expiredAssignments = {}
    for key, request in pairs(self.pendingSpecVerifications) do
        if self.pendingInspect and self.pendingInspect.key == key then
            request.elapsed = (request.elapsed or 0) + elapsed
        else
            request.waitElapsed = (request.waitElapsed or 0) + elapsed
        end
        if request.elapsed >= self.INSPECT_ASSIGNMENT_TIMEOUT
            or request.waitElapsed >= self.INSPECT_VERIFICATION_QUEUE_TIMEOUT then
            tinsert(expiredAssignments, key)
        end
    end
    for _, key in ipairs(expiredAssignments) do
        local request = self.pendingSpecVerifications[key]
        self.pendingSpecVerifications[key] = nil
        if request then
            if self.pendingInspect and self.pendingInspect.key == key then
                self.pendingInspect = nil
                if ClearInspectPlayer and (not InspectFrame or not InspectFrame:IsShown()) then
                    ClearInspectPlayer()
                end
            end
            self:Print(L("No se pudo validar la especialización de %s. Acércate, sal de combate y vuelve a intentarlo.", request.name))
            if self.rosterVerification then
                self.rosterVerification.pending = math.max(0, self.rosterVerification.pending - 1)
                self.rosterVerification.unavailable = self.rosterVerification.unavailable + 1
            end
        end
    end
    if #expiredAssignments > 0 then
        self:FinishRosterSpecVerification()
    end
    if self.pendingInspect then
        self.pendingInspect.elapsed = (self.pendingInspect.elapsed or 0) + elapsed
        if self.pendingInspect.elapsed >= 6 then
            local unit = self.pendingInspect.unit
            local key = self.pendingInspect.key
            self.pendingInspect = nil
            if ClearInspectPlayer and (not InspectFrame or not InspectFrame:IsShown()) then
                ClearInspectPlayer()
            end
            if self.pendingSpecVerifications[key] then
                self:QueueInspectUnit(unit, true)
            end
        end
        return
    end

    if #self.inspectQueue == 0 then
        self.inspectElapsed = 0
        return
    end

    self.inspectElapsed = self.inspectElapsed + elapsed
    if self.inspectElapsed < 2 then
        return
    end
    self.inspectElapsed = 0

    local attempts = #self.inspectQueue
    while attempts > 0 do
        attempts = attempts - 1
        local item = tremove(self.inspectQueue, 1)
        self.inspectQueued[item.key] = nil
        if self.pendingSpecVerifications[item.key] then
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
                    key = item.key,
                    guid = UnitGUID and UnitGUID(item.unit) or nil,
                    elapsed = 0,
                }
                NotifyInspect(item.unit)
                return
            end
            self:QueueInspectUnit(item.unit, false)
        end
        end
    end
end

function Addon:IsGroupCombatActive()
    if not UnitAffectingCombat then
        return false
    end
    for _, unit in ipairs(self:GetGroupUnitTokens()) do
        if (not UnitExists or UnitExists(unit)) and UnitAffectingCombat(unit) then
            return true
        end
    end
    return false
end

function Addon:ProcessEncounterEnd(elapsed)
    if not self.state.active or not self.encounterCombatObserved then
        self.encounterEndElapsed = 0
        self.encounterCombatCheckElapsed = 0
        return
    end

    self.encounterCombatCheckElapsed = self.encounterCombatCheckElapsed + elapsed
    if self.encounterCombatCheckElapsed < 1 then
        return
    end
    local checkedElapsed = self.encounterCombatCheckElapsed
    self.encounterCombatCheckElapsed = 0
    if self:IsGroupCombatActive() then
        self.encounterEndElapsed = 0
        return
    end

    self.encounterEndElapsed = self.encounterEndElapsed + checkedElapsed
    if self.encounterEndElapsed >= 3 then
        self:StopEncounter("combat_end", false)
    end
end

function Addon:ImportRaidRoster()
    if not self:CanModifyConfiguration() then
        return false
    end
    local members = self:GetRaidMembers()
    if #members == 0 then
        self:Print(L("No hay una banda activa para importar."))
        return
    end

    self:RefreshGroupMemberProfiles()
    for _, member in ipairs(members) do
        local profile = self:RememberPlayerProfile(member.name, member.classFile, nil, true, nil)
        if profile then
            profile.inGroup = true
        end
    end

    local used = {}
    for _, member in ipairs(members) do
        local slot = self:GetSlotForName(member.name)
        if slot then
            used[self:NormalizeName(member.name)] = true
        end
    end

    local changed = 0
    for _, slot in ipairs(self:GetActiveSlotOrder()) do
        local record = self.db.roster[slot]
        if self:IsPlaceholder(slot, record.name) then
            local matchedMember
            local matchedSpec
            for _, candidate in ipairs(members) do
                local key = self:NormalizeName(candidate.name)
                if not used[key] then
                    local specId, eligible = self:GetAutomaticRaidMemberSpecForSlot(candidate, slot)
                    if eligible then
                        matchedMember = candidate
                        matchedSpec = specId
                        break
                    end
                end
            end
            if matchedMember then
                record.name = matchedMember.name
                record.spec = matchedSpec or ""
                used[self:NormalizeName(matchedMember.name)] = true
                self:RememberRosterPlayer(slot, matchedSpec ~= "" and "raid" or "class")
                changed = changed + 1
            end
        end
    end

    local remaining = 0
    for _, slot in ipairs(self:GetActiveSlotOrder()) do
        local record = self.db.roster[slot]
        if self:IsPlaceholder(slot, record.name) then
            remaining = remaining + 1
        end
    end

    local message = L("Importación completada: %d puesto(s) rellenados por rol sin sobrescribir asignaciones existentes.", changed)
    if remaining > 0 then
        message = message .. " " .. L("%d puesto(s) siguen vacíos por no encontrar una clase compatible para ese rol.", remaining)
    end
    self:Print(message)
    if changed > 0 then
        self:NormalizeCooldownAssignments()
        self:ScheduleAutoSync()
    end
    self:RefreshUI()
    return changed > 0
end

local function EscapeField(value)
    value = tostring(value or "")
    value = string.gsub(value, "%%", "%%25")
    value = string.gsub(value, "@", "%%40")
    value = string.gsub(value, "|", "%%7C")
    value = string.gsub(value, "\r", "")
    value = string.gsub(value, "\n", "%%0A")
    return value
end

local function UnescapeField(value)
    value = tostring(value or "")
    value = string.gsub(value, "%%0A", "\n")
    value = string.gsub(value, "%%7C", "|")
    value = string.gsub(value, "%%40", "@")
    value = string.gsub(value, "%%25", "%%")
    return value
end

local function SplitMessage(message)
    local fields = {}
    for field in strgmatch(tostring(message or "") .. MESSAGE_SEPARATOR, "(.-)" .. MESSAGE_SEPARATOR) do
        tinsert(fields, UnescapeField(field))
    end
    return fields
end

local function EncodeMessage(fields)
    local encoded = {}
    for _, field in ipairs(fields) do
        tinsert(encoded, EscapeField(field))
    end
    return table.concat(encoded, MESSAGE_SEPARATOR)
end

local function SplitPackedRecords(payload)
    local records = {}
    for record in strgmatch(tostring(payload or "") .. PACKED_RECORD_SEPARATOR, "(.-)" .. PACKED_RECORD_SEPARATOR) do
        tinsert(records, record)
    end
    return records
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
    return self:GetAddonChannel() ~= nil and self:CanEditConfiguration(true)
end

function Addon:ScheduleAutoSync()
    self.lastValidationIssues = nil
    self.validationHasRun = false
    if not self.db or not self.db.options.autoSync or self:IsConfigurationLocked() or self.receivingSync or not self:CanSynchronizeConfiguration() then
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
    if not self.db or not self.db.options.autoSync or self:IsConfigurationLocked() or self.receivingSync or not self:CanSynchronizeConfiguration() then
        self:CancelAutoSync()
        return
    end

    self.autoSyncElapsed = self.autoSyncElapsed + elapsed
    if self.autoSyncElapsed < self.AUTO_SYNC_DELAY then
        return
    end
    if self.outgoingSyncActive then
        return
    end

    self:CancelAutoSync()
    self:SyncConfiguration(true)
end

function Addon:ScheduleSyncUIRefresh()
    self.syncUIRefreshPending = true
    self.syncUIRefreshElapsed = 0
end

function Addon:ProcessSyncUIRefresh(elapsed)
    if not self.syncUIRefreshPending then
        return
    end
    self.syncUIRefreshElapsed = self.syncUIRefreshElapsed + elapsed
    if self.syncUIRefreshElapsed < self.SYNC_UI_REFRESH_DELAY then
        return
    end
    self.syncUIRefreshPending = false
    self.syncUIRefreshElapsed = 0
    self:PrepareZoneAssignments()
    self:RebuildBiteSources()
    self:NormalizeCooldownAssignments()
    self:RefreshUI(true)
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

function Addon:DiscardQueuedConfigurationSync()
    for index = #self.messageQueue, 1, -1 do
        if self.messageQueue[index].category == "CONFIG" then
            tremove(self.messageQueue, index)
        end
    end
    self.outgoingSyncActive = false
    self.pendingManualSync = false
end

function Addon:QueueSync(fields, channel, category, completesConfiguration)
    self:EnqueueAddon(EncodeMessage(fields), channel, nil, category, completesConfiguration)
end

function Addon:QueuePackedSync(records, syncId, channel, category)
    local payloads = {}
    local currentPayload = ""

    for _, fields in ipairs(records) do
        local encodedRecord = EncodeMessage(fields)
        local candidate = currentPayload == ""
            and encodedRecord
            or (currentPayload .. PACKED_RECORD_SEPARATOR .. encodedRecord)
        local preview = EncodeMessage({ "PACK", syncId, 999, 999, candidate })

        if currentPayload ~= "" and strlen(preview) > self.MAX_ADDON_MESSAGE_BYTES then
            tinsert(payloads, currentPayload)
            currentPayload = encodedRecord
        else
            currentPayload = candidate
        end
    end

    if currentPayload ~= "" then
        tinsert(payloads, currentPayload)
    end

    local total = #payloads
    for index, payload in ipairs(payloads) do
        self:EnqueueAddon(
            EncodeMessage({ "PACK", syncId, index, total, payload }),
            channel,
            nil,
            category,
            index == total
        )
    end
end

function Addon:CreateSyncId()
    self.syncSequence = self.syncSequence + 1
    local player = UnitName and UnitName("player") or "player"
    local timestamp = floor(((GetTime and GetTime()) or 0) * 1000)
    return self:NormalizeName(player) .. "-" .. tostring(timestamp) .. "-" .. tostring(self.syncSequence)
end

function Addon:RegisterSyncResponse(kind, syncId, sender, version, status)
    local report = self.syncReport
    if not report or report.id ~= syncId then
        return
    end

    local player = UnitName and UnitName("player") or ""
    local key = self:NormalizeName(sender)
    if key == "" or key == self:NormalizeName(player) then
        return
    end

    report.present[key] = {
        name = sender,
        version = version or "?",
        status = status or "READY",
    }
    if kind == "ACK" then
        local firstAcknowledgement = not report.acknowledged[key]
        report.acknowledged[key] = true
        if firstAcknowledgement then
            self:Print(L("Configuración aplicada por %s.", tostring(sender)))
        end
    end
end

function Addon:ProcessSyncReport(elapsed)
    local report = self.syncReport
    if not report then
        return
    end

    report.elapsed = report.elapsed + elapsed
    if not report.discoveryReported and report.elapsed >= self.SYNC_DISCOVERY_DELAY then
        report.discoveryReported = true
        local present = 0
        local locked = 0
        local disabled = 0
        for _, peer in pairs(report.present) do
            present = present + 1
            if peer.status == "LOCKED" then
                locked = locked + 1
            elseif peer.status == "DISABLED" then
                disabled = disabled + 1
            end
        end
        if present == 0 then
            self:Print(L("Ningún otro jugador con BQLManager respondió. Revisa versión, grupo y Aceptar sincronización."))
        else
            local details = {}
            if locked > 0 then
                tinsert(details, L("%d tiene(n) el encuentro activo", locked))
            end
            if disabled > 0 then
                tinsert(details, L("%d no acepta(n) sincronizaciones", disabled))
            end
            local suffix = #details > 0 and ("; " .. table.concat(details, ", ")) or ""
            self:Print(L("BQLManager detectado en %d jugador(es)%s. Enviando configuración...", present, suffix))
        end
    end

    if report.elapsed < self.SYNC_REPORT_TIMEOUT then
        return
    end

    local present = 0
    local acknowledged = 0
    for _ in pairs(report.present) do
        present = present + 1
    end
    for _ in pairs(report.acknowledged) do
        acknowledged = acknowledged + 1
    end
    if acknowledged > 0 then
        self:Print(L("Sincronización aplicada y confirmada por %d de %d jugador(es) detectados.", acknowledged, present))
    elseif present > 0 then
        self:Print(L("Los clientes respondieron, pero ninguno confirmó la configuración completa."))
    end
    self.syncReport = nil
end

function Addon:SyncConfiguration(silent)
    if not self:CanModifyConfiguration(silent) then
        return false
    end
    local channel = self:GetAddonChannel()
    if not channel then
        if not silent then
            self:Print(L("Debes estar en grupo o banda para sincronizar."))
        end
        return false
    end
    if not self:CanSynchronizeConfiguration() then
        if not silent then
            self:Print(L("Solo el líder o un asistente puede sincronizar la configuración."))
        end
        return false
    end

    if self.outgoingSyncActive then
        if silent then
            self.autoSyncPending = true
            self.autoSyncElapsed = self.AUTO_SYNC_DELAY
        else
            self.pendingManualSync = true
            self:Print(L("Hay una sincronización en curso. Se enviará el estado más reciente al terminar."))
        end
        return true
    end

    self:CancelAutoSync()
    if not silent then
        self.syncReport = nil
    end
    local syncId = self:CreateSyncId()
    if not silent then
        self.syncReport = {
            id = syncId,
            elapsed = 0,
            discoveryReported = false,
            present = {},
            acknowledged = {},
        }
        self:QueueSync({ "HELLO", syncId }, channel, "CONTROL")
    end
    local category = "CONFIG"
    self.outgoingSyncActive = true
    local records = {
        { "BEGIN", self.DB_VERSION, syncId },
    }
    for _, slot in ipairs(self.SLOT_ORDER) do
        local record = self.db.roster[slot]
        tinsert(records, {
            "ROSTER",
            slot,
            record.name,
            record.spec,
            record.role or "",
            self:GetRosterClassKey(slot) or "",
        })
    end
    for index, edge in ipairs(self.db.bites) do
        tinsert(records, { "BITE", index, edge.wave, edge.source, edge.target })
    end
    for _, group in ipairs({ "aura", "flight1", "flight2", "threat" }) do
        for index, record in ipairs(self.db.cooldowns[group]) do
            tinsert(records, { "CD", group, index, record.label, record.slot or "", record.source or "", record.target or "" })
        end
    end
    for key, note in pairs(self.db.zones) do
        tinsert(records, { "ZONE", key, note })
    end
    for _, zoneId in ipairs(self.SLOT_ORDER) do
        tinsert(records, { "ZPOS", zoneId, self.db.zoneAssignments[zoneId] or "" })
    end
    tinsert(records, { "END", syncId })
    self:QueuePackedSync(records, syncId, channel, category)
    if not silent then
        self:Print(L("Sincronización encolada para el grupo."))
    end
    return true
end

function Addon:BroadcastState()
    local channel = self:GetAddonChannel()
    if not channel or not self:CanSynchronizeConfiguration() then
        return
    end
    self:QueueSync({ "STATE", self.state.active and 1 or 0, self.state.currentWave }, channel)
end

function Addon:ReceivePackedSync(fields, sender, distribution)
    local syncId = fields[2]
    local packetIndex = tonumber(fields[3])
    local packetTotal = tonumber(fields[4])
    local payload = fields[5] or ""
    if not syncId or not packetIndex or not packetTotal or packetIndex < 1 or packetTotal < 1 or packetIndex > packetTotal then
        return
    end

    local senderKey = self:NormalizeName(sender)
    if packetIndex == 1 then
        self.receivingPackedSync = {
            id = syncId,
            sender = senderKey,
            nextIndex = 1,
            total = packetTotal,
        }
    end

    local packed = self.receivingPackedSync
    if not packed
        or packed.id ~= syncId
        or packed.sender ~= senderKey
        or packed.total ~= packetTotal
        or packed.nextIndex ~= packetIndex
    then
        if packed then
            self:Print(L("Sincronización incompleta de %s; solicita un nuevo envío.", tostring(sender)))
            if self.receivingSync and self:NormalizeName(self.receivingSync) == senderKey then
                self.receivingSync = nil
                self.receivingSyncVersion = nil
                self.receivingSyncId = nil
                self.syncUIRefreshPending = false
                self.syncUIRefreshElapsed = 0
            end
        end
        self.receivingPackedSync = nil
        return
    end

    for _, record in ipairs(SplitPackedRecords(payload)) do
        self:ReceiveSync(record, sender, distribution)
    end

    packed.nextIndex = packetIndex + 1
    if packetIndex == packetTotal then
        self.receivingPackedSync = nil
    end
end

function Addon:ReceiveSync(message, sender, distribution)
    if distribution and distribution ~= "PARTY" and distribution ~= "RAID" and distribution ~= "BATTLEGROUND" then
        return
    end

    local fields = SplitMessage(message)
    local kind = fields[1]
    local player = UnitName and UnitName("player") or ""
    if self:NormalizeName(sender) == self:NormalizeName(player) then
        return
    end
    if kind == "PRESENT" or kind == "ACK" then
        self:RegisterSyncResponse(kind, fields[2], sender, fields[3], fields[4])
        return
    end
    if kind == "HELLO" then
        local status = "READY"
        if not self.db.options.acceptSync then
            status = "DISABLED"
        elseif self:IsConfigurationLocked() then
            status = "LOCKED"
        end
        local channel = distribution or self:GetAddonChannel()
        if channel then
            self:QueueSync({ "PRESENT", fields[2], self.VERSION, status }, channel, "CONTROL")
        end
        if status == "DISABLED" then
            self:Print(L("Sincronización ignorada de %s: Aceptar sincronización está desactivado.", tostring(sender)))
        end
        return
    end
    if not self.db.options.acceptSync then
        return
    end
    if kind == "PACK" then
        if self.state.active then
            self.receivingPackedSync = nil
            return
        end
        self:ReceivePackedSync(fields, sender, distribution)
        return
    end
    local receivingConfiguration = self.receivingSync
        and self:NormalizeName(self.receivingSync) == self:NormalizeName(sender)
    if self.state.active and kind ~= "STATE" then
        self.receivingSync = nil
        self.receivingSyncVersion = nil
        self.receivingSyncId = nil
        return
    end
    if kind == "BEGIN" then
        self.receivingSync = sender
        self.receivingSyncVersion = tonumber(fields[2]) or 1
        self.receivingSyncId = fields[3]
        self.lastValidationIssues = nil
        self.validationHasRun = false
    elseif kind == "END" then
        if receivingConfiguration then
            local completedSyncId = self.receivingSyncId
            self:Print(L("Configuración recibida de %s.", tostring(sender)))
            self.receivingSync = nil
            self.receivingSyncVersion = nil
            self.receivingSyncId = nil
            self.syncUIRefreshPending = false
            self.syncUIRefreshElapsed = 0
            self:PrepareZoneAssignments()
            self:RebuildBiteSources()
            self:NormalizeCooldownAssignments()
            self:RefreshUI(true)
            local channel = distribution or self:GetAddonChannel()
            if channel and completedSyncId and completedSyncId == fields[2] then
                self:QueueSync({ "ACK", completedSyncId, self.VERSION, "APPLIED" }, channel, "CONTROL")
            end
        end
    elseif kind == "ROSTER" and receivingConfiguration and self.SLOT_SET[fields[2]] then
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
        self:RememberPlayerProfile(record.name, fields[6], record.spec, nil, nil, "sync")
        self:RememberRosterPlayer(slot, "sync")
        self:ScheduleSyncUIRefresh()
    elseif kind == "BITE" and receivingConfiguration then
        local index = tonumber(fields[2])
        if index and self.db.bites[index] then
            self.db.bites[index].wave = tonumber(fields[3]) or self.db.bites[index].wave
            if self:IsSlotActive(fields[5]) then
                self.db.bites[index].target = fields[5]
            end
            self:ScheduleSyncUIRefresh()
        end
    elseif kind == "CD" and receivingConfiguration then
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
            self:ScheduleSyncUIRefresh()
        end
    elseif kind == "ZONE" and receivingConfiguration and self.db.zones[fields[2]] ~= nil then
        self.db.zones[fields[2]] = fields[3] or ""
        self:ScheduleSyncUIRefresh()
    elseif kind == "ZPOS" and receivingConfiguration and self.ZONE_POSITION_ROLES[fields[2]] then
        self.db.zoneAssignments[fields[2]] = fields[3] or ""
        self:ScheduleSyncUIRefresh()
    elseif kind == "STATE" then
        local wasActive = self.state.active
        local isActive = tonumber(fields[2]) == 1
        if isActive and not wasActive then
            self:CapturePlannedBites()
        elseif not isActive and wasActive then
            self:RestorePlannedBites()
        end
        self.state.active = isActive
        self.state.currentWave = tonumber(fields[3]) or 1
        self.state.initialBiteDetected = self.state.currentWave > 1
        if self.state.active then
            self.encounterCombatObserved = self:IsGroupCombatActive()
            self.encounterEndElapsed = 0
            self.encounterCombatCheckElapsed = 0
            self:CancelAutoSync()
            self:DiscardQueuedConfigurationSync()
            self.receivingSync = nil
            self.receivingSyncVersion = nil
            self.receivingSyncId = nil
            self.syncUIRefreshPending = false
            self.syncUIRefreshElapsed = 0
        end
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
        self:Print(L("Comandos: show, start, stop, reset, wave 1-5, announce, sync, validate, defaults."))
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
        text = L("¿Restaurar toda la configuración inicial de BQL Manager?"),
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
    StaticPopupDialogs.BQLMANAGER_CONFIRM_CLEAR_ROSTER = {
        text = L("¿Limpiar todos los jugadores y specs de la plantilla?"),
        button1 = YES,
        button2 = NO,
        OnAccept = function()
            Addon:ClearRoster()
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }

    self:Print(L("Cargado. Usa /bql para abrir la ventana."))
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
Addon.eventFrame:RegisterEvent("INSPECT_TALENT_READY")

Addon.eventFrame:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        Addon:OnAddonLoaded(...)
    elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
        Addon:HandleCombatLog(...)
    elseif event == "CHAT_MSG_ADDON" then
        local prefix, message, channel, sender = ...
        if prefix == Addon.MESSAGE_PREFIX then
            Addon:ReceiveSync(message, sender, channel)
        end
    elseif event == "PLAYER_REGEN_DISABLED" then
        Addon.encounterCombatObserved = true
        Addon.encounterEndElapsed = 0
        Addon.encounterCombatCheckElapsed = 0
        if Addon.db and Addon.db.options.autoStart and not Addon.state.active and Addon:CanEditConfiguration(true) and Addon:IsBossName(UnitName("target")) then
            Addon:StartEncounter(true)
        end
    elseif event == "RAID_ROSTER_UPDATE" then
        Addon:RefreshGroupMemberProfiles()
        Addon:RefreshUI()
    elseif event == "PARTY_MEMBERS_CHANGED" then
        Addon:RefreshGroupMemberProfiles()
        Addon:RefreshUI()
    elseif event == "PLAYER_ENTERING_WORLD" then
        Addon:RefreshGroupMemberProfiles()
        Addon:RefreshUI()
    elseif event == "GUILD_ROSTER_UPDATE" then
        Addon:RefreshGuildRosterCache()
        Addon:RefreshGroupMemberProfiles()
    elseif event == "INSPECT_READY" then
        Addon:HandleInspectReady(...)
    elseif event == "INSPECT_TALENT_READY" then
        Addon:HandleInspectReady()
    end
end)

Addon.eventFrame:SetScript("OnUpdate", function(_, elapsed)
    Addon:ProcessMessageQueue(elapsed)
    Addon:ProcessInspectQueue(elapsed)
    Addon:ProcessEncounterEnd(elapsed)
    Addon:ProcessAutoSync(elapsed)
    Addon:ProcessSyncReport(elapsed)
    Addon:ProcessSyncUIRefresh(elapsed)
end)
