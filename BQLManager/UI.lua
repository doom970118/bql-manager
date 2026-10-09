local Addon = _G.BQLManager
if not Addon then
    return
end

local UI = {}
Addon.UI = UI

local ipairs = ipairs
local pairs = pairs
local strformat = string.format
local tinsert = table.insert
local tostring = tostring
local unpack = unpack

local COLORS = {
    purple = { 0.72, 0.30, 0.95 },
    darkPurple = { 0.15, 0.05, 0.20, 0.96 },
    panel = { 0.055, 0.055, 0.075, 0.96 },
    border = { 0.50, 0.20, 0.67, 1 },
    muted = { 0.65, 0.65, 0.70 },
    green = { 0.25, 0.95, 0.45 },
    red = { 1.00, 0.30, 0.30 },
    yellow = { 1.00, 0.82, 0.20 },
    melee = { 1.00, 0.75, 0.82 },
    ranged = { 0.62, 0.52, 0.96 },
    healers = { 0.20, 0.72, 1.00 },
    flames = { 1.00, 0.55, 0.12 },
    boss = { 0.78, 0.05, 0.05 },
    neutral = { 0.22, 0.22, 0.25 },
}

local CLASS_ICON_TEXTURE = "Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes"
local CLASS_ICON_TCOORDS = _G.CLASS_ICON_TCOORDS or {
    WARRIOR = { 0, 0.25, 0, 0.25 },
    MAGE = { 0.25, 0.49609375, 0, 0.25 },
    ROGUE = { 0.49609375, 0.7421875, 0, 0.25 },
    DRUID = { 0.7421875, 0.98828125, 0, 0.25 },
    HUNTER = { 0, 0.25, 0.25, 0.5 },
    SHAMAN = { 0.25, 0.49609375, 0.25, 0.5 },
    PRIEST = { 0.49609375, 0.7421875, 0.25, 0.5 },
    WARLOCK = { 0.7421875, 0.98828125, 0.25, 0.5 },
    PALADIN = { 0, 0.25, 0.5, 0.75 },
    DEATHKNIGHT = { 0.25, 0.49609375, 0.5, 0.75 },
}

local ROLE_ICON_TEXTURE = "Interface\\LFGFrame\\LFGRole"
local ROLE_ICON_TCOORDS = {
    TANK = { 0.5, 0.75, 0, 1 },
    MDPS = { 0.25, 0.5, 0, 1 },
    RDPS = { 0.25, 0.5, 0, 1 },
    HEALER = { 0.75, 1, 0, 1 },
}

local function SetRoleIcon(texture, role, alpha)
    local coords = ROLE_ICON_TCOORDS[role] or ROLE_ICON_TCOORDS.RDPS
    texture:SetTexture(ROLE_ICON_TEXTURE)
    texture:SetTexCoord(unpack(coords))
    texture:SetVertexColor(1, 1, 1, 1)
    texture:SetAlpha(alpha or 1)
end

local function SetDropDownRoleIcon(info, role)
    local coords = ROLE_ICON_TCOORDS[role] or ROLE_ICON_TCOORDS.RDPS
    info.icon = ROLE_ICON_TEXTURE
    info.tCoordLeft, info.tCoordRight, info.tCoordTop, info.tCoordBottom = unpack(coords)
    return coords
end

local function GetRoleColor(role)
    if role == "MDPS" then
        return COLORS.melee
    elseif role == "RDPS" then
        return COLORS.ranged
    elseif role == "HEALER" then
        return COLORS.healers
    end
    return COLORS.neutral
end

local function GetSlotRoleColor(slot)
    if slot == "BOSS" then
        return COLORS.boss
    end
    return GetRoleColor(Addon:GetSlotRole(slot))
end

-- Mapa G1:Z14 de la hoja de referencia. Los números conservan las zonas
-- pintadas del Excel: 4=MDPS, 5=RDPS, 6=healers, 7=flames y 8=BQL.
local ZONE_MAP_ROWS = {
    { 0, 0, 0, 0, 2, 2, 2, 4, 4, 0, 0, 4, 4, 2, 2, 2, 0, 0, 0, 0 },
    { 0, 0, 0, 2, 4, 0, 0, 0, 4, 0, 0, 4, 0, 0, 0, 4, 2, 0, 0, 0 },
    { 0, 0, 2, 4, 4, 0, 0, 0, 4, 8, 8, 4, 0, 0, 0, 4, 4, 2, 0, 0 },
    { 0, 2, 7, 7, 4, 0, 0, 0, 4, 0, 0, 4, 0, 0, 0, 4, 7, 7, 2, 0 },
    { 0, 2, 7, 7, 5, 4, 4, 4, 4, 0, 0, 4, 4, 4, 4, 5, 7, 7, 2, 0 },
    { 2, 7, 7, 5, 5, 5, 4, 4, 4, 0, 0, 4, 4, 4, 5, 5, 5, 7, 7, 2 },
    { 2, 7, 5, 0, 0, 5, 5, 5, 4, 4, 4, 4, 5, 5, 5, 0, 0, 7, 7, 2 },
    { 7, 7, 5, 5, 5, 5, 5, 5, 5, 6, 6, 5, 5, 5, 5, 5, 5, 5, 7, 7 },
    { 7, 7, 5, 5, 5, 5, 5, 5, 6, 6, 6, 6, 5, 5, 5, 5, 5, 5, 7, 7 },
    { 7, 0, 0, 5, 0, 0, 5, 0, 0, 6, 6, 0, 0, 5, 0, 0, 5, 0, 0, 7 },
    { 7, 5, 5, 5, 5, 5, 5, 6, 6, 6, 6, 6, 6, 5, 5, 5, 5, 5, 5, 7 },
    { 7, 5, 5, 5, 5, 5, 5, 6, 6, 0, 0, 6, 6, 5, 5, 5, 5, 5, 5, 7 },
    { 7, 0, 0, 5, 0, 0, 5, 6, 6, 6, 6, 6, 6, 5, 0, 0, 5, 0, 0, 7 },
    { 7, 5, 5, 5, 5, 5, 5, 0, 0, 6, 6, 0, 0, 5, 5, 5, 5, 5, 5, 7 },
}

local ZONE_MARKERS = {
    { slot = "TANK1", row = 1, col = 10, span = 2 },
    { slot = "MDPS3", row = 2, col = 6, span = 3 },
    { slot = "TANK2", row = 2, col = 10, span = 2 },
    { slot = "MDPS6", row = 2, col = 13, span = 3 },
    { slot = "MDPS4", row = 3, col = 6, span = 3 },
    { slot = "BOSS", row = 3, col = 10, span = 2 },
    { slot = "MDPS7", row = 3, col = 13, span = 3 },
    { slot = "MDPS5", row = 4, col = 6, span = 3 },
    { slot = "MDPS1", row = 4, col = 10, span = 2 },
    { slot = "MDPS8", row = 4, col = 13, span = 3 },
    { slot = "MDPS2", row = 5, col = 10, span = 2 },
    { slot = "RDPS1", row = 7, col = 4, span = 2 },
    { slot = "RDPS6", row = 7, col = 16, span = 2 },
    { slot = "RDPS2", row = 10, col = 2, span = 2 },
    { slot = "RDPS3", row = 10, col = 5, span = 2 },
    { slot = "HEALER1", row = 10, col = 8, span = 2 },
    { slot = "HEALER2", row = 10, col = 12, span = 2 },
    { slot = "RDPS7", row = 10, col = 15, span = 2 },
    { slot = "RDPS8", row = 10, col = 18, span = 2 },
    { slot = "HEALER3", row = 12, col = 10, span = 2 },
    { slot = "RDPS4", row = 13, col = 2, span = 2 },
    { slot = "RDPS5", row = 13, col = 5, span = 2 },
    { slot = "RDPS9", row = 13, col = 15, span = 2 },
    { slot = "RDPS10", row = 13, col = 18, span = 2 },
    { slot = "HEALER4", row = 14, col = 8, span = 2 },
    { slot = "HEALER5", row = 14, col = 12, span = 2 },
}

local widgetCounter = 0

local function NextName(prefix)
    widgetCounter = widgetCounter + 1
    return "BQLManager" .. prefix .. tostring(widgetCounter)
end

local function SetBackdrop(frame, background, border)
    frame:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    frame:SetBackdropColor(background[1], background[2], background[3], background[4] or 1)
    frame:SetBackdropBorderColor(border[1], border[2], border[3], border[4] or 1)
end

local function CreateText(parent, font, text, anchor, relativeTo, relativeAnchor, x, y)
    local label = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlightSmall")
    label:SetPoint(anchor or "TOPLEFT", relativeTo or parent, relativeAnchor or anchor or "TOPLEFT", x or 0, y or 0)
    label:SetText(text or "")
    return label
end

local function CreateButton(parent, text, width, height, callback)
    local button = CreateFrame("Button", NextName("Button"), parent, "UIPanelButtonTemplate")
    button:SetWidth(width or 100)
    button:SetHeight(height or 22)
    button:SetText(text or "")
    button:SetScript("OnClick", callback)
    return button
end

local function CreateInput(parent, width, height)
    local input = CreateFrame("EditBox", NextName("Input"), parent, "InputBoxTemplate")
    input:SetWidth(width or 110)
    input:SetHeight(height or 20)
    input:SetAutoFocus(false)
    input:SetFontObject("ChatFontNormal")
    input:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
    end)
    input:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
        UI:Refresh()
    end)
    return input
end

local GUILD_SUGGESTION_ROWS = 8

function UI:SetGuildMemberSelectorValue(selector, name)
    if not selector or not selector.editBox then
        return
    end

    local displayName = name
    if Addon:IsPlaceholder(selector.slot, name) then
        displayName = Addon:GetSlotLabel(selector.slot)
    end

    if not selector.editBox:HasFocus() then
        selector.suppressSearch = true
        selector.editBox:SetText(tostring(displayName or ""))
        selector.suppressSearch = false
    end

    local member = Addon:GetGuildMemberProfile(name)
    local classKey = member and member.classKey or Addon:GetRosterClassKey(selector.slot)
    local coords = CLASS_ICON_TCOORDS[classKey]
    if coords then
        selector.classIcon:SetTexture(CLASS_ICON_TEXTURE)
        selector.classIcon:SetTexCoord(unpack(coords))
        selector.classIcon:SetVertexColor(1, 1, 1, 1)
        selector.classIcon:SetAlpha(1)
    else
        SetRoleIcon(selector.classIcon, Addon:GetSlotRole(selector.slot))
    end
end

function UI:UpdateGuildMemberSuggestions(selector, resetOffset)
    if resetOffset then
        selector.offset = 1
    end

    local candidates = Addon:GetGuildMemberCandidates(selector.slot, selector.search or "")
    selector.candidates = candidates
    local maximumOffset = #candidates - GUILD_SUGGESTION_ROWS + 1
    if maximumOffset < 1 then
        maximumOffset = 1
    end
    if selector.offset > maximumOffset then
        selector.offset = maximumOffset
    elseif selector.offset < 1 then
        selector.offset = 1
    end

    for rowIndex, button in ipairs(selector.suggestionButtons) do
        local member = candidates[selector.offset + rowIndex - 1]
        button.member = member
        if member then
            local coords = CLASS_ICON_TCOORDS[member.classKey]
            button.icon:SetTexture(CLASS_ICON_TEXTURE)
            if coords then
                button.icon:SetTexCoord(unpack(coords))
            else
                button.icon:SetTexCoord(0, 1, 0, 1)
            end
            button.icon:SetVertexColor(1, 1, 1, 1)
            button.icon:SetAlpha(member.online and 1 or 0.55)
            button.label:SetText(member.name)
            local color = _G.RAID_CLASS_COLORS and _G.RAID_CLASS_COLORS[member.classKey]
            if color then
                button.label:SetTextColor(color.r, color.g, color.b)
            else
                button.label:SetTextColor(0.90, 0.90, 0.95)
            end
            button:Show()
        elseif rowIndex == 1 and #candidates == 0 then
            SetRoleIcon(button.icon, Addon:GetSlotRole(selector.slot), 0.6)
            button.label:SetText("Sin coincidencias compatibles")
            button.label:SetTextColor(COLORS.muted[1], COLORS.muted[2], COLORS.muted[3])
            button:Show()
        else
            button:Hide()
        end
    end

    selector.footer:SetText(tostring(#candidates) .. " candidato(s) · rueda para desplazar")
end

function UI:ShowGuildMemberSuggestions(selector, resetOffset)
    if self.activeGuildSelector and self.activeGuildSelector ~= selector then
        self.activeGuildSelector.popup:Hide()
    end
    self.activeGuildSelector = selector
    self:UpdateGuildMemberSuggestions(selector, resetOffset)

    local popup = selector.popup
    popup:ClearAllPoints()
    local bottom = selector:GetBottom()
    if bottom and bottom < popup:GetHeight() + 20 then
        popup:SetPoint("BOTTOMLEFT", selector, "TOPLEFT", 0, 2)
    else
        popup:SetPoint("TOPLEFT", selector, "BOTTOMLEFT", 0, -2)
    end
    popup:Show()
end

local function CreateGuildMemberSelector(parent, width, slot)
    local selector = CreateFrame("Frame", NextName("GuildMemberSelector"), parent)
    local selectorWidth = width or 150
    selector:SetWidth(selectorWidth)
    selector:SetHeight(20)
    selector.slot = slot
    selector.offset = 1
    selector.search = ""

    selector.classIcon = selector:CreateTexture(nil, "ARTWORK")
    selector.classIcon:SetWidth(16)
    selector.classIcon:SetHeight(16)
    selector.classIcon:SetPoint("LEFT", selector, "LEFT", 0, 0)

    selector.editBox = CreateInput(selector, selectorWidth - 42, 20)
    selector.editBox:SetPoint("LEFT", selector.classIcon, "RIGHT", 6, 0)

    selector.arrow = CreateFrame("Button", NextName("GuildArrow"), selector, "UIPanelButtonTemplate")
    selector.arrow:SetWidth(18)
    selector.arrow:SetHeight(20)
    selector.arrow:SetPoint("RIGHT", selector, "RIGHT", 0, 0)
    selector.arrow:SetText("v")

    local popup = CreateFrame("Frame", NextName("GuildSuggestions"), UIParent)
    selector.popup = popup
    popup:SetWidth(260)
    popup:SetHeight((GUILD_SUGGESTION_ROWS * 22) + 50)
    popup:SetFrameStrata("DIALOG")
    popup:SetFrameLevel(120)
    popup:SetClampedToScreen(true)
    popup:EnableMouse(true)
    popup:EnableMouseWheel(true)
    SetBackdrop(popup, { 0.035, 0.035, 0.055, 0.99 }, COLORS.border)
    popup:Hide()

    selector.clearButton = CreateFrame("Button", NextName("GuildClearSlot"), popup)
    selector.clearButton:SetHeight(22)
    selector.clearButton:SetPoint("TOPLEFT", popup, "TOPLEFT", 5, -5)
    selector.clearButton:SetPoint("TOPRIGHT", popup, "TOPRIGHT", -5, -5)
    selector.clearButton:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
    selector.clearButton.icon = selector.clearButton:CreateTexture(nil, "ARTWORK")
    selector.clearButton.icon:SetWidth(16)
    selector.clearButton.icon:SetHeight(16)
    selector.clearButton.icon:SetPoint("LEFT", selector.clearButton, "LEFT", 3, 0)
    selector.clearButton.icon:SetTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up")
    selector.clearButton.label = CreateText(selector.clearButton, "GameFontHighlightSmall", "Dejar puesto vacío", "LEFT", selector.clearButton.icon, "RIGHT", 5, 0)
    selector.clearButton.label:SetTextColor(COLORS.red[1], COLORS.red[2], COLORS.red[3])
    selector.clearButton:SetScript("OnMouseDown", function()
        Addon:ClearRosterSlot(selector.slot)
        selector.editBox:ClearFocus()
        UI:SetGuildMemberSelectorValue(selector, "")
        popup:Hide()
    end)
    selector.clearButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Dejar puesto vacío")
        GameTooltip:AddLine("Conserva el puesto y sus asignaciones, pero limpia el jugador y la spec.", 0.75, 0.75, 0.75, true)
        GameTooltip:Show()
    end)
    selector.clearButton:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    selector.suggestionButtons = {}
    for rowIndex = 1, GUILD_SUGGESTION_ROWS do
        local button = CreateFrame("Button", NextName("GuildSuggestion"), popup)
        button:SetHeight(22)
        button:SetPoint("TOPLEFT", popup, "TOPLEFT", 5, -27 - ((rowIndex - 1) * 22))
        button:SetPoint("TOPRIGHT", popup, "TOPRIGHT", -5, -27 - ((rowIndex - 1) * 22))
        button:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
        button.icon = button:CreateTexture(nil, "ARTWORK")
        button.icon:SetWidth(16)
        button.icon:SetHeight(16)
        button.icon:SetPoint("LEFT", button, "LEFT", 3, 0)
        button.label = CreateText(button, "GameFontHighlightSmall", "", "LEFT", button.icon, "RIGHT", 5, 0)
        button.label:SetWidth(220)
        button.label:SetJustifyH("LEFT")
        button:SetScript("OnMouseDown", function(self)
            if self.member then
                Addon:AssignGuildMemberToSlot(selector.slot, self.member.name)
                selector.editBox:ClearFocus()
                UI:SetGuildMemberSelectorValue(selector, Addon:GetSlotRecord(selector.slot).name)
                popup:Hide()
            end
        end)
        button:SetScript("OnEnter", function(self)
            if not self.member then
                return
            end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(self.member.name)
            local class = Addon.CLASSES[self.member.classKey]
            if class then
                GameTooltip:AddLine(class.name, 1, 1, 1)
            end
            local spec = Addon:GetSpecDefinition(self.member.spec)
            if spec then
                GameTooltip:AddLine("Spec guardada: " .. spec.name, 0.75, 0.75, 0.75)
            else
                GameTooltip:AddLine("Spec todavía desconocida", 1, 0.82, 0.20)
            end
            local source = self.member.inGuild and (self.member.inGroup and "Hermandad · En grupo" or "Hermandad") or "Grupo/Banda"
            GameTooltip:AddLine(source, 0.62, 0.52, 0.96)
            GameTooltip:AddLine(self.member.online and "Conectado" or "Offline", self.member.online and 0.25 or 0.65, self.member.online and 0.95 or 0.65, self.member.online and 0.45 or 0.70)
            GameTooltip:Show()
        end)
        button:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
        selector.suggestionButtons[rowIndex] = button
    end

    selector.footer = CreateText(popup, "GameFontDisableSmall", "", "BOTTOMLEFT", popup, "BOTTOMLEFT", 8, 6)
    selector.footer:SetWidth(244)
    selector.footer:SetJustifyH("LEFT")

    popup:SetScript("OnMouseWheel", function(_, delta)
        selector.offset = selector.offset - delta
        UI:UpdateGuildMemberSuggestions(selector, false)
    end)
    selector.arrow:SetScript("OnClick", function()
        selector.search = ""
        selector.editBox:SetFocus()
        selector.editBox:HighlightText()
        UI:ShowGuildMemberSuggestions(selector, true)
    end)
    selector.editBox:SetScript("OnEditFocusGained", function(self)
        selector.search = ""
        self:HighlightText()
        UI:ShowGuildMemberSuggestions(selector, true)
    end)
    selector.editBox:SetScript("OnTextChanged", function(self)
        if selector.suppressSearch or not self:HasFocus() then
            return
        end
        selector.search = self:GetText()
        UI:ShowGuildMemberSuggestions(selector, true)
    end)
    selector.editBox:SetScript("OnEnterPressed", function(self)
        local candidates = Addon:GetGuildMemberCandidates(selector.slot, self:GetText())
        local selected
        for _, member in ipairs(candidates) do
            if Addon:NormalizeName(member.name) == Addon:NormalizeName(self:GetText()) then
                selected = member
                break
            end
        end
        selected = selected or (#candidates == 1 and candidates[1] or nil)
        if selected then
            Addon:AssignGuildMemberToSlot(selector.slot, selected.name)
        else
            UI:SetGuildMemberSelectorValue(selector, Addon:GetSlotRecord(selector.slot).name)
        end
        self:ClearFocus()
        UI:SetGuildMemberSelectorValue(selector, Addon:GetSlotRecord(selector.slot).name)
        popup:Hide()
    end)
    selector.editBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
        popup:Hide()
        UI:SetGuildMemberSelectorValue(selector, Addon:GetSlotRecord(selector.slot).name)
    end)
    selector.editBox:SetScript("OnEditFocusLost", function()
        if not MouseIsOver or not MouseIsOver(popup) then
            popup:Hide()
            UI:SetGuildMemberSelectorValue(selector, Addon:GetSlotRecord(selector.slot).name)
        end
    end)
    selector:SetScript("OnHide", function()
        popup:Hide()
    end)
    selector:EnableMouse(true)
    selector:SetScript("OnMouseDown", function()
        selector.search = ""
        selector.editBox:SetFocus()
        selector.editBox:HighlightText()
        UI:ShowGuildMemberSuggestions(selector, true)
    end)

    UI:SetGuildMemberSelectorValue(selector, Addon:GetSlotRecord(slot).name)
    return selector
end

function UI:SetSpecSelectorValue(selector, specId)
    local spec = Addon:GetSpecDefinition(specId)
    selector.selectedSpecId = spec and spec.id or nil

    if not spec then
        selector.icon:SetWidth(16)
        selector.icon:SetHeight(16)
        SetRoleIcon(selector.icon, Addon:GetSlotRole(selector.slot))
        selector:SetBackdropBorderColor(0.30, 0.30, 0.36, 1)
        return
    end

    selector.icon:SetWidth(20)
    selector.icon:SetHeight(20)
    selector.icon:SetTexture(spec.icon)
    selector.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    selector.icon:SetVertexColor(1, 1, 1, 1)
    selector.icon:SetAlpha(1)
    local color = _G.RAID_CLASS_COLORS and _G.RAID_CLASS_COLORS[spec.classKey]
    if color then
        selector:SetBackdropBorderColor(color.r, color.g, color.b, 1)
    else
        selector:SetBackdropBorderColor(0.30, 0.30, 0.36, 1)
    end
end

local function GetLatestDropDownButton(level)
    local list = _G["DropDownList" .. tostring(level)]
    if not list or not list.numButtons then
        return nil, nil, nil
    end

    local buttonName = "DropDownList" .. tostring(level) .. "Button" .. tostring(list.numButtons)
    local button = _G[buttonName]
    local arrow = _G[buttonName .. "ExpandArrow"] or (button and button.expandArrow)
    local icon = _G[buttonName .. "Icon"] or (button and button.icon)
    return button, arrow, icon
end

local function ResetDropDownButtonLayout(level, iconCoords)
    local button, arrow, icon = GetLatestDropDownButton(level)
    if not button then
        return
    end

    if arrow then
        arrow:ClearAllPoints()
        arrow:SetPoint("RIGHT", button, "RIGHT", -5, 0)
    end
    if icon then
        icon:ClearAllPoints()
        icon:SetPoint("RIGHT", button, "RIGHT", -5, 0)
        icon:SetWidth(16)
        icon:SetHeight(16)
        if iconCoords then
            icon:SetTexCoord(unpack(iconCoords))
        else
            icon:SetTexCoord(0, 1, 0, 1)
        end
    end
end

local function MoveClassMenuArrow(level)
    local button, arrow, icon = GetLatestDropDownButton(level)
    if not button or not arrow or not icon then
        return
    end

    arrow:ClearAllPoints()
    arrow:SetPoint("LEFT", button, "LEFT", 1, 0)
    icon:ClearAllPoints()
    icon:SetPoint("LEFT", arrow, "RIGHT", 2, 0)
end

local function CreateSpecSelector(parent, slot)
    local selector = CreateFrame("Button", NextName("SpecSelector"), parent)
    selector.slot = slot
    selector:SetWidth(24)
    selector:SetHeight(24)
    SetBackdrop(selector, { 0.03, 0.03, 0.04, 0.98 }, { 0.30, 0.30, 0.36, 1 })

    selector.icon = selector:CreateTexture(nil, "ARTWORK")
    selector.icon:SetWidth(20)
    selector.icon:SetHeight(20)
    selector.icon:SetPoint("CENTER", selector, "CENTER", 0, 0)

    selector:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
    selector.menu = CreateFrame("Frame", NextName("SpecMenu"), selector, "UIDropDownMenuTemplate")
    UIDropDownMenu_Initialize(selector.menu, function(_, level, menuList)
        if level == 1 then
            for _, classKey in ipairs(Addon.CLASS_ORDER) do
                if Addon:ClassHasSpecForSlot(classKey, slot) then
                    local class = Addon.CLASSES[classKey]
                    local info = UIDropDownMenu_CreateInfo()
                    -- El texto invisible reserva espacio para que la flecha amarilla
                    -- del submenú no se dibuje encima del icono de la clase.
                    info.text = "            "
                    info.value = classKey
                    info.hasArrow = true
                    info.menuList = classKey
                    info.notCheckable = true
                    info.icon = CLASS_ICON_TEXTURE
                    info.tooltipTitle = class.name
                    info.tooltipText = "Ver especializaciones compatibles"
                    info.tooltipOnButton = true
                    local coords = CLASS_ICON_TCOORDS[classKey]
                    if coords then
                        info.tCoordLeft, info.tCoordRight, info.tCoordTop, info.tCoordBottom = unpack(coords)
                    end
                    UIDropDownMenu_AddButton(info, level)
                    MoveClassMenuArrow(level)
                end
            end
        elseif level == 2 and menuList then
            local class = Addon.CLASSES[menuList]
            if class then
                for _, spec in ipairs(class.specs) do
                    if Addon:IsSpecAllowedForSlot(slot, spec.id) then
                        local specId = spec.id
                        local info = UIDropDownMenu_CreateInfo()
                        info.text = "      "
                        info.value = specId
                        info.icon = spec.icon
                        info.notCheckable = true
                        info.tooltipTitle = spec.name
                        info.tooltipText = class.name
                        info.tooltipOnButton = true
                        info.func = function()
                            Addon:SetRosterSpec(slot, specId)
                            CloseDropDownMenus()
                        end
                        UIDropDownMenu_AddButton(info, level)
                        ResetDropDownButtonLayout(level)
                    end
                end
            end
        end
    end, "MENU")

    selector:SetScript("OnClick", function(self)
        ToggleDropDownMenu(1, nil, self.menu, self, 0, 0)
    end)
    selector:SetScript("OnEnter", function(self)
        local spec = Addon:GetSpecDefinition(self.selectedSpecId)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if spec then
            GameTooltip:SetText(spec.name)
            GameTooltip:AddLine(spec.className, 1, 1, 1)
        else
            GameTooltip:SetText("Seleccionar especialización")
        end
        GameTooltip:AddLine("Haz clic para elegir una clase y una especialización.", 0.75, 0.75, 0.75, true)
        GameTooltip:Show()
    end)
    selector:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    UI:SetSpecSelectorValue(selector, nil)
    return selector
end

function UI:SetRosterSlotSelectorValue(selector, slot)
    selector.value = slot
    if slot == "BOSS" then
        selector.label:SetText("BOSS")
        selector.label:SetTextColor(COLORS.boss[1], COLORS.boss[2], COLORS.boss[3])
        selector:SetBackdropBorderColor(COLORS.boss[1], COLORS.boss[2], COLORS.boss[3], 1)
        return
    end

    if Addon:IsSlotActive(slot) then
        selector.label:SetText(Addon:GetSlotLabel(slot))
        local color = GetSlotRoleColor(slot)
        selector.label:SetTextColor(color[1], color[2], color[3])
        selector:SetBackdropBorderColor(color[1], color[2], color[3], 1)
    else
        selector.label:SetText("Seleccionar...")
        selector.label:SetTextColor(COLORS.muted[1], COLORS.muted[2], COLORS.muted[3])
        selector:SetBackdropBorderColor(0.30, 0.30, 0.36, 1)
    end
end

local function CreateRosterSlotSelector(parent, width, callback, lockedValue, slotFilter)
    local selector = CreateFrame("Button", NextName("SlotSelector"), parent)
    selector:SetWidth(width or 94)
    selector:SetHeight(20)
    SetBackdrop(selector, { 0.03, 0.03, 0.04, 0.98 }, { 0.30, 0.30, 0.36, 1 })

    selector.label = CreateText(selector, "GameFontHighlightSmall", "", "LEFT", selector, "LEFT", 6, 0)
    selector.label:SetWidth((width or 94) - 24)
    selector.label:SetJustifyH("LEFT")
    selector.arrow = CreateText(selector, "GameFontNormalSmall", "v", "RIGHT", selector, "RIGHT", -6, 1)
    selector.arrow:SetTextColor(COLORS.muted[1], COLORS.muted[2], COLORS.muted[3])
    selector:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")

    if lockedValue then
        selector.locked = true
        selector.arrow:Hide()
        selector:Disable()
    else
        selector.menu = CreateFrame("Frame", NextName("SlotMenu"), selector, "UIDropDownMenuTemplate")
        UIDropDownMenu_Initialize(selector.menu, function(_, level)
            if level ~= 1 then
                return
            end
            for _, slot in ipairs(Addon:GetActiveSlotOrder()) do
                if not slotFilter or slotFilter(slot) then
                    local currentSlot = slot
                    local record = Addon:GetSlotRecord(slot)
                    local spec = record and Addon:GetSpecDefinition(record.spec)
                    local info = UIDropDownMenu_CreateInfo()
                    local iconCoords
                    info.text = Addon:GetSlotLabel(slot) .. " · " .. Addon:GetSlotName(slot)
                    info.value = slot
                    info.notCheckable = true
                    if spec then
                        info.icon = spec.icon
                    else
                        iconCoords = SetDropDownRoleIcon(info, Addon:GetSlotRole(slot))
                    end
                    info.func = function()
                        callback(currentSlot)
                        CloseDropDownMenus()
                    end
                    UIDropDownMenu_AddButton(info, level)
                    ResetDropDownButtonLayout(level, iconCoords)
                end
            end
        end, "MENU")
        selector:SetScript("OnClick", function(self)
            ToggleDropDownMenu(1, nil, self.menu, self, 0, 0)
        end)
    end

    selector:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if self.value == "BOSS" then
            GameTooltip:SetText("BOSS")
            GameTooltip:AddLine("Origen fijo de la primera mordida.", 1, 1, 1)
        elseif Addon:IsSlotActive(self.value) then
            GameTooltip:SetText(Addon:GetSlotLabel(self.value))
            GameTooltip:AddLine(Addon:GetSlotName(self.value), 1, 1, 1)
            if self.locked then
                GameTooltip:AddLine("Origen calculado automáticamente.", 0.75, 0.75, 0.75)
            end
        else
            GameTooltip:SetText("Seleccionar puesto")
        end
        GameTooltip:Show()
    end)
    selector:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    UI:SetRosterSlotSelectorValue(selector, lockedValue)
    return selector
end

local function CreateNoteInput(parent, width, height)
    local input = CreateFrame("EditBox", NextName("Note"), parent)
    input:SetWidth(width)
    input:SetHeight(height)
    input:SetMultiLine(true)
    input:SetAutoFocus(false)
    input:SetFontObject("ChatFontNormal")
    input:SetTextInsets(7, 7, 7, 7)
    input:SetMaxLetters(100)
    input:EnableMouse(true)
    SetBackdrop(input, { 0.03, 0.03, 0.04, 0.95 }, { 0.30, 0.30, 0.36, 1 })
    input:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
        UI:Refresh()
    end)
    return input
end

local function CreateCheck(parent, text, callback)
    local check = CreateFrame("CheckButton", NextName("Check"), parent)
    check:SetWidth(22)
    check:SetHeight(22)
    check:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
    check:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down")
    check:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight")
    check:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
    check.label = CreateText(check, "GameFontHighlightSmall", text, "LEFT", check, "RIGHT", 2, 0)
    check:SetScript("OnClick", callback)
    return check
end

local function CreatePanel(parent)
    local panel = CreateFrame("Frame", nil, parent)
    panel:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, -104)
    panel:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -12, 14)
    SetBackdrop(panel, COLORS.panel, { 0.22, 0.22, 0.28, 1 })
    panel:Hide()
    return panel
end

local function CreateSectionTitle(parent, text, x, y, color)
    local title = CreateText(parent, "GameFontNormalLarge", text, "TOPLEFT", parent, "TOPLEFT", x, y)
    color = color or COLORS.purple
    title:SetTextColor(color[1], color[2], color[3])
    return title
end

local function SetInputText(input, value)
    if input and not input:HasFocus() then
        input:SetText(tostring(value or ""))
    end
end

function UI:RegisterConfigurationPanel(panel)
    local overlay = CreateFrame("Frame", nil, panel)
    overlay:SetAllPoints(panel)
    overlay:SetFrameLevel(panel:GetFrameLevel() + 100)
    overlay:EnableMouse(true)
    overlay.notice = CreateText(overlay, "GameFontNormal", "Configuración bloqueada durante el encuentro", "TOPRIGHT", overlay, "TOPRIGHT", -18, -14)
    overlay.notice:SetTextColor(COLORS.red[1], COLORS.red[2], COLORS.red[3])
    overlay:Hide()
    tinsert(self.configurationLockOverlays, overlay)
end

function UI:CreateMainFrame()
    local frame = CreateFrame("Frame", "BQLManagerMainFrame", UIParent)
    self.frame = frame
    frame:SetWidth(Addon.db.window.width or 840)
    frame:SetHeight(Addon.db.window.height or 560)
    frame:SetPoint(
        Addon.db.window.point or "CENTER",
        UIParent,
        Addon.db.window.relativePoint or "CENTER",
        Addon.db.window.x or 0,
        Addon.db.window.y or 0
    )
    frame:SetFrameStrata("MEDIUM")
    frame:SetToplevel(true)
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    SetBackdrop(frame, COLORS.darkPurple, COLORS.border)

    frame:SetScript("OnDragStart", function(self)
        if not Addon.db.options.locked and not Addon:IsConfigurationLocked() then
            self:StartMoving()
        end
    end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relativePoint, x, y = self:GetPoint(1)
        Addon.db.window.point = point
        Addon.db.window.relativePoint = relativePoint
        Addon.db.window.x = x
        Addon.db.window.y = y
    end)
    frame:SetScript("OnMouseDown", function(self)
        self:Raise()
    end)
    frame:SetScript("OnShow", function(self)
        self:Raise()
        UI:Refresh()
    end)

    local titleBar = CreateFrame("Frame", nil, frame)
    titleBar:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, -4)
    titleBar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, -4)
    titleBar:SetHeight(34)
    titleBar:SetBackdrop({ bgFile = "Interface\\ChatFrame\\ChatFrameBackground" })
    titleBar:SetBackdropColor(0.28, 0.08, 0.38, 0.96)

    local title = CreateText(titleBar, "GameFontNormalLarge", "BQL Manager", "LEFT", titleBar, "LEFT", 12, 0)
    title:SetTextColor(0.95, 0.78, 1.00)
    self.versionText = CreateText(titleBar, "GameFontDisableSmall", "v" .. Addon.VERSION, "LEFT", title, "RIGHT", 8, -1)

    local close = CreateFrame("Button", NextName("Close"), frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -3, -3)

    self.statusText = CreateText(frame, "GameFontHighlight", "", "TOPLEFT", frame, "TOPLEFT", 16, -45)
    self.statusText:SetWidth(560)
    self.statusText:SetJustifyH("LEFT")

    self.lockCheck = CreateCheck(frame, "Bloquear ventana", function(button)
        if Addon:IsConfigurationLocked() then
            UI:Refresh()
            return
        end
        Addon.db.options.locked = button:GetChecked() and true or false
    end)
    local lockLabelWidth = self.lockCheck.label:GetStringWidth()
    self.lockCheck:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -(lockLabelWidth + 54), -42)

    self.tabs = {}
    self.panels = {}
    self.configurationLockOverlays = {}
    local tabNames = {
        { key = "summary", label = "Resumen" },
        { key = "roster", label = "Plantilla" },
        { key = "bites", label = "Mordidas" },
        { key = "cooldowns", label = "Cooldowns" },
        { key = "zones", label = "Zonas" },
    }

    local previous
    for _, info in ipairs(tabNames) do
        local tabKey = info.key
        local tab = CreateButton(frame, info.label, 112, 24, function()
            UI:ShowTab(tabKey)
        end)
        if previous then
            tab:SetPoint("LEFT", previous, "RIGHT", 5, 0)
        else
            tab:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -72)
        end
        self.tabs[tabKey] = tab
        previous = tab
    end

    self:CreateSummaryPanel(frame)
    self:CreateRosterPanel(frame)
    self:CreateBitesPanel(frame)
    self:CreateCooldownPanel(frame)
    self:CreateZonesPanel(frame)
    self:ShowTab("summary")
    frame:Hide()
end

function UI:CreateSummaryPanel(parent)
    local panel = CreatePanel(parent)
    self.panels.summary = panel

    CreateSectionTitle(panel, "Control del intento", 16, -14)

    local start = CreateButton(panel, "Iniciar", 92, 24, function()
        Addon:StartEncounter(true)
    end)
    self.startButton = start
    start:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -44)

    local stop = CreateButton(panel, "Detener", 92, 24, function()
        Addon:StopEncounter("manual", true)
    end)
    self.stopButton = stop
    stop:SetPoint("LEFT", start, "RIGHT", 5, 0)

    local reset = CreateButton(panel, "Reiniciar", 92, 24, function()
        Addon:ResetEncounter(true)
    end)
    self.resetButton = reset
    reset:SetPoint("LEFT", stop, "RIGHT", 5, 0)

    local announce = CreateButton(panel, "Anunciar plan", 112, 24, function()
        Addon:AnnounceFullPlan()
    end)
    announce:SetPoint("LEFT", reset, "RIGHT", 14, 0)

    local sync = CreateButton(panel, "Sincronizar", 104, 24, function()
        Addon:SyncConfiguration()
    end)
    self.syncButton = sync
    sync:SetPoint("LEFT", announce, "RIGHT", 5, 0)

    local validate = CreateButton(panel, "Validar", 88, 24, function()
        Addon:ValidateAndReport()
        UI:Refresh()
    end)
    validate:SetPoint("LEFT", sync, "RIGHT", 5, 0)

    self.summaryState = CreateText(panel, "GameFontHighlight", "", "TOPLEFT", panel, "TOPLEFT", 18, -82)
    self.summaryState:SetWidth(760)
    self.summaryState:SetJustifyH("LEFT")

    CreateSectionTitle(panel, "Árbol de mordidas", 16, -112)
    self.waveTexts = {}
    for wave = 1, 5 do
        local label = CreateText(panel, "GameFontHighlightSmall", "", "TOPLEFT", panel, "TOPLEFT", 22, -140 - ((wave - 1) * 25))
        label:SetWidth(770)
        label:SetJustifyH("LEFT")
        self.waveTexts[wave] = label
    end

    CreateSectionTitle(panel, "Opciones", 16, -278)
    self.autoStartCheck = CreateCheck(panel, "Inicio automático al detectar a Lana'thel", function(button)
        Addon.db.options.autoStart = button:GetChecked() and true or false
    end)
    self.autoStartCheck:SetPoint("TOPLEFT", panel, "TOPLEFT", 18, -306)

    self.whisperCheck = CreateCheck(panel, "Susurrar objetivos de mordida", function(button)
        Addon.db.options.whisperAssignments = button:GetChecked() and true or false
    end)
    self.whisperCheck:SetPoint("TOPLEFT", panel, "TOPLEFT", 18, -334)

    self.warningCheck = CreateCheck(panel, "Usar aviso de banda si tengo permisos", function(button)
        Addon.db.options.raidWarnings = button:GetChecked() and true or false
    end)
    self.warningCheck:SetPoint("TOPLEFT", panel, "TOPLEFT", 310, -306)

    self.syncCheck = CreateCheck(panel, "Aceptar sincronización de líder/asistentes", function(button)
        Addon.db.options.acceptSync = button:GetChecked() and true or false
    end)
    self.syncCheck:SetPoint("TOPLEFT", panel, "TOPLEFT", 310, -334)

    self.autoSyncCheck = CreateCheck(panel, "Auto-sincronización", function(button)
        Addon.db.options.autoSync = button:GetChecked() and true or false
        if Addon.db.options.autoSync then
            Addon:ScheduleAutoSync()
        else
            Addon:CancelAutoSync()
        end
    end)
    self.autoSyncCheck:SetPoint("TOPLEFT", panel, "TOPLEFT", 18, -362)

    self.validationText = CreateText(panel, "GameFontHighlightSmall", "", "TOPLEFT", panel, "TOPLEFT", 18, -394)
    self.validationText:SetWidth(775)
    self.validationText:SetHeight(38)
    self.validationText:SetJustifyH("LEFT")
    self.validationText:SetJustifyV("TOP")
end

function UI:CreateRosterPanel(parent)
    local panel = CreatePanel(parent)
    self.panels.roster = panel
    self.rosterRows = {}
    self.roleControls = {}

    CreateSectionTitle(panel, "Plantilla", 16, -12)
    self.rosterTotal = CreateText(panel, "GameFontDisableSmall", "", "TOPLEFT", panel, "TOPLEFT", 103, -18)
    self.rosterTotal:SetTextColor(COLORS.muted[1], COLORS.muted[2], COLORS.muted[3])

    local roleX = { TANK = 190, MDPS = 295, RDPS = 400, HEALER = 505 }
    for _, role in ipairs(Addon.ROLE_ORDER) do
        local x = roleX[role]
        local currentRole = role
        local control = {}
        control.label = CreateText(panel, "GameFontNormalSmall", role, "TOPLEFT", panel, "TOPLEFT", x, -17)
        control.remove = CreateButton(panel, "-", 18, 18, function()
            Addon:RemoveRosterRole(currentRole)
        end)
        control.remove:SetPoint("TOPLEFT", panel, "TOPLEFT", x + 48, -11)
        control.count = CreateText(panel, "GameFontHighlightSmall", "", "TOPLEFT", panel, "TOPLEFT", x + 70, -17)
        control.count:SetWidth(18)
        control.count:SetJustifyH("CENTER")
        control.add = CreateButton(panel, "+", 18, 18, function()
            Addon:AddRosterRole(currentRole)
        end)
        control.add:SetPoint("TOPLEFT", panel, "TOPLEFT", x + 87, -11)
        self.roleControls[role] = control
    end

    local import = CreateButton(panel, "Completar desde banda", 160, 22, function()
        Addon:ImportRaidRoster()
    end)
    self.importButton = import
    import:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -15, -10)

    local columns = {
        { x = 16, startIndex = 1, endIndex = 13 },
        { x = 408, startIndex = 14, endIndex = 25 },
    }

    for _, column in ipairs(columns) do
        CreateText(panel, "GameFontNormalSmall", "Puesto", "TOPLEFT", panel, "TOPLEFT", column.x + 14, -47)
        CreateText(panel, "GameFontNormalSmall", "Personaje", "TOPLEFT", panel, "TOPLEFT", column.x + 83, -47)
        CreateText(panel, "GameFontNormalSmall", "Spec", "TOPLEFT", panel, "TOPLEFT", column.x + 240, -47)

        for index = column.startIndex, column.endIndex do
            local slot = Addon.SLOT_ORDER[index]
            local row = {}
            row.online = CreateText(panel, "GameFontHighlightSmall", "o", "TOPLEFT", panel, "TOPLEFT", 0, 0)
            row.slot = CreateText(panel, "GameFontHighlightSmall", slot, "TOPLEFT", panel, "TOPLEFT", 0, 0)
            row.slot:SetWidth(64)
            row.name = CreateGuildMemberSelector(panel, 150, slot)
            row.name:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)
            row.spec = CreateSpecSelector(panel, slot)
            row.spec:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)
            self.rosterRows[slot] = row
        end
    end
    self:RegisterConfigurationPanel(panel)
end

function UI:CreateBitesPanel(parent)
    local panel = CreatePanel(parent)
    self.panels.bites = panel
    self.biteRows = {}

    CreateSectionTitle(panel, "Árbol editable de mordidas", 16, -12)
    local help = CreateText(panel, "GameFontDisableSmall", "Elige destinos; los orígenes se calculan y bloquean automáticamente. BOSS siempre inicia el árbol.", "TOPLEFT", panel, "TOPLEFT", 245, -18)
    help:SetTextColor(COLORS.muted[1], COLORS.muted[2], COLORS.muted[3])

    CreateText(panel, "GameFontNormalSmall", "Ronda", "TOPLEFT", panel, "TOPLEFT", 18, -48)
    CreateText(panel, "GameFontNormalSmall", "Origen", "TOPLEFT", panel, "TOPLEFT", 82, -48)
    CreateText(panel, "GameFontNormalSmall", "Personaje", "TOPLEFT", panel, "TOPLEFT", 190, -48)
    CreateText(panel, "GameFontNormalSmall", "Destino", "TOPLEFT", panel, "TOPLEFT", 392, -48)
    CreateText(panel, "GameFontNormalSmall", "Personaje", "TOPLEFT", panel, "TOPLEFT", 500, -48)

    for index = 1, 16 do
        local y = -70 - ((index - 1) * 23)
        local row = {}
        local currentIndex = index
        row.state = CreateText(panel, "GameFontHighlightSmall", "-", "TOPLEFT", panel, "TOPLEFT", 18, y)
        row.wave = CreateText(panel, "GameFontHighlightSmall", "", "TOPLEFT", panel, "TOPLEFT", 43, y)
        row.wave:SetWidth(30)
        local edge = Addon.db.bites[index]
        row.source = CreateRosterSlotSelector(panel, 94, nil, edge and edge.source or "")
        row.source:SetPoint("TOPLEFT", panel, "TOPLEFT", 78, y + 4)
        row.sourceName = CreateText(panel, "GameFontHighlightSmall", "", "TOPLEFT", panel, "TOPLEFT", 190, y)
        row.sourceName:SetWidth(180)
        row.sourceName:SetJustifyH("LEFT")
        row.target = CreateRosterSlotSelector(panel, 94, function(slot)
            Addon:SetBiteSlot(currentIndex, "target", slot)
        end, nil, function(slot)
            return Addon:IsBiteTargetAvailable(currentIndex, slot)
        end)
        row.target:SetPoint("TOPLEFT", panel, "TOPLEFT", 386, y + 4)
        row.targetName = CreateText(panel, "GameFontHighlightSmall", "", "TOPLEFT", panel, "TOPLEFT", 500, y)
        row.targetName:SetWidth(190)
        row.targetName:SetJustifyH("LEFT")
        self.biteRows[index] = row
    end
    self:RegisterConfigurationPanel(panel)
end

function UI:CreateCooldownPanel(parent)
    local panel = CreatePanel(parent)
    self.panels.cooldowns = panel
    self.cooldownRows = {}

    CreateSectionTitle(panel, "Cooldowns y amenaza", 16, -12)
    local help = CreateText(panel, "GameFontDisableSmall", "Los selectores muestran solo puestos compatibles; el nombre se resuelve desde la plantilla.", "TOPLEFT", panel, "TOPLEFT", 230, -18)
    help:SetTextColor(COLORS.muted[1], COLORS.muted[2], COLORS.muted[3])

    local function BuildStandardGroup(group, title, x, y)
        local color = group == "aura" and COLORS.yellow or COLORS.healers
        CreateSectionTitle(panel, title, x, y, color)
        local records = Addon.db.cooldowns[group]
        for index = 1, #records do
            local rowY = y - 29 - ((index - 1) * 28)
            local row = { group = group, index = index }
            local currentGroup = group
            local currentIndex = index
            row.label = CreateText(panel, "GameFontHighlightSmall", "", "TOPLEFT", panel, "TOPLEFT", x + 4, rowY)
            row.label:SetWidth(125)
            row.label:SetJustifyH("LEFT")
            row.slot = CreateRosterSlotSelector(panel, 82, function(slot)
                Addon:SetCooldownAssignment(currentGroup, currentIndex, "slot", slot)
            end, nil, function(slot)
                return Addon:IsCooldownSlotEligible(currentGroup, currentIndex, "slot", slot, true)
            end)
            row.slot:SetPoint("TOPLEFT", panel, "TOPLEFT", x + 130, rowY + 5)
            row.name = CreateText(panel, "GameFontHighlightSmall", "", "TOPLEFT", panel, "TOPLEFT", x + 228, rowY)
            row.name:SetWidth(145)
            row.name:SetJustifyH("LEFT")
            tinsert(UI.cooldownRows, row)
        end
    end

    local function BuildThreatGroup(group, title, x, y)
        CreateSectionTitle(panel, title, x, y, COLORS.flames)
        local records = Addon.db.cooldowns[group]
        for index = 1, #records do
            local rowY = y - 29 - ((index - 1) * 30)
            local row = { group = group, index = index }
            local currentIndex = index
            row.label = CreateText(panel, "GameFontHighlightSmall", "", "TOPLEFT", panel, "TOPLEFT", x + 4, rowY)
            row.label:SetWidth(48)
            row.source = CreateRosterSlotSelector(panel, 78, function(slot)
                Addon:SetCooldownAssignment("threat", currentIndex, "source", slot)
            end, nil, function(slot)
                return Addon:IsCooldownSlotEligible("threat", currentIndex, "source", slot, true)
            end)
            row.source:SetPoint("TOPLEFT", panel, "TOPLEFT", x + 52, rowY + 5)
            row.arrow = CreateText(panel, "GameFontHighlightSmall", ">", "TOPLEFT", panel, "TOPLEFT", x + 142, rowY)
            row.target = CreateRosterSlotSelector(panel, 78, function(slot)
                Addon:SetCooldownAssignment("threat", currentIndex, "target", slot)
            end, nil, function(slot)
                return Addon:IsCooldownSlotEligible("threat", currentIndex, "target", slot, true)
            end)
            row.target:SetPoint("TOPLEFT", panel, "TOPLEFT", x + 158, rowY + 5)
            row.name = CreateText(panel, "GameFontHighlightSmall", "", "TOPLEFT", panel, "TOPLEFT", x + 248, rowY)
            row.name:SetWidth(130)
            row.name:SetJustifyH("LEFT")
            tinsert(UI.cooldownRows, row)
        end
    end

    BuildStandardGroup("aura", "Aura Mastery", 18, -49)
    BuildStandardGroup("flight1", "Primer vuelo", 18, -207)
    BuildStandardGroup("flight2", "Segundo vuelo", 418, -49)
    BuildThreatGroup("threat", "MD / Tricks", 418, -236)
    self:RegisterConfigurationPanel(panel)
end

function UI:CreateZonesPanel(parent)
    local panel = CreatePanel(parent)
    self.panels.zones = panel
    self.zoneInputs = {}
    self.mapMarkers = {}

    CreateSectionTitle(panel, "Mapa de zonas según color", 16, -12)
    local help = CreateText(panel, "GameFontDisableSmall", "/range 8 · Clic para asignar o intercambiar posiciones.", "TOPLEFT", panel, "TOPLEFT", 245, -12)
    help:SetWidth(275)
    help:SetHeight(24)
    help:SetJustifyH("LEFT")
    help:SetJustifyV("TOP")
    help:SetTextColor(COLORS.muted[1], COLORS.muted[2], COLORS.muted[3])

    local map = CreateFrame("Frame", nil, panel)
    map:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -43)
    map:SetWidth(504)
    map:SetHeight(298)
    SetBackdrop(map, { 0.018, 0.018, 0.025, 1 }, { 0.36, 0.36, 0.43, 1 })
    self.zoneMap = map

    local cellWidth = 25
    local cellHeight = 21
    local fillColors = {
        [0] = { 0.035, 0.035, 0.045, 1 },
        [2] = COLORS.neutral,
        [4] = COLORS.melee,
        [5] = COLORS.ranged,
        [6] = COLORS.healers,
        [7] = COLORS.flames,
        [8] = COLORS.boss,
    }

    for row = 1, 14 do
        for column = 1, 20 do
            local color = fillColors[ZONE_MAP_ROWS[row][column]] or fillColors[0]
            local cell = CreateFrame("Frame", nil, map)
            cell:SetWidth(cellWidth)
            cell:SetHeight(cellHeight)
            cell:SetPoint("TOPLEFT", map, "TOPLEFT", 2 + ((column - 1) * cellWidth), -2 - ((row - 1) * cellHeight))
            local texture = cell:CreateTexture(nil, "BACKGROUND")
            texture:SetPoint("TOPLEFT", cell, "TOPLEFT", 1, -1)
            texture:SetPoint("BOTTOMRIGHT", cell, "BOTTOMRIGHT", -1, 1)
            texture:SetTexture(color[1], color[2], color[3], color[4] or 1)
            if ZONE_MAP_ROWS[row][column] == 0 then
                texture:SetAlpha(0.35)
            else
                texture:SetAlpha(0.74)
            end
        end
    end

    for _, definition in ipairs(ZONE_MARKERS) do
        local marker = CreateFrame("Button", NextName("ZoneMarker"), map)
        marker:SetWidth((definition.span * cellWidth) - 2)
        marker:SetHeight(cellHeight - 2)
        marker:SetPoint(
            "TOPLEFT",
            map,
            "TOPLEFT",
            3 + ((definition.col - 1) * cellWidth),
            -3 - ((definition.row - 1) * cellHeight)
        )
        marker:SetFrameLevel(map:GetFrameLevel() + 5)
        local color = definition.slot == "BOSS" and COLORS.boss or GetRoleColor(Addon.ZONE_POSITION_ROLES[definition.slot])
        marker:SetBackdrop({
            bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true,
            tileSize = 8,
            edgeSize = 6,
            insets = { left = 1, right = 1, top = 1, bottom = 1 },
        })
        marker:SetBackdropColor(0.025, 0.025, 0.035, 0.94)
        marker:SetBackdropBorderColor(color[1], color[2], color[3], 1)
        marker.label = CreateText(marker, "GameFontHighlightSmall", "", "CENTER", marker, "CENTER", 0, 0)
        marker.label:SetWidth((definition.span * cellWidth) - 8)
        marker.label:SetJustifyH("CENTER")
        marker.zoneId = definition.slot
        marker.role = Addon.ZONE_POSITION_ROLES[definition.slot]
        marker.maxChars = definition.span == 2 and 8 or 12
        marker:EnableMouse(true)
        local currentZoneId = definition.slot
        local zoneRole = marker.role

        if currentZoneId ~= "BOSS" then
            marker:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
            marker.menu = CreateFrame("Frame", NextName("ZoneMenu"), marker, "UIDropDownMenuTemplate")
            UIDropDownMenu_Initialize(marker.menu, function(_, level)
                if level ~= 1 then
                    return
                end
                for _, slot in ipairs(Addon:GetActiveSlotOrder()) do
                    if Addon:GetSlotRole(slot) == zoneRole then
                        local currentSlot = slot
                        local record = Addon:GetSlotRecord(slot)
                        local spec = record and Addon:GetSpecDefinition(record.spec)
                        local info = UIDropDownMenu_CreateInfo()
                        local iconCoords
                        info.text = Addon:GetSlotLabel(slot) .. " · " .. Addon:GetSlotName(slot)
                        info.value = slot
                        info.notCheckable = true
                        if spec then
                            info.icon = spec.icon
                        else
                            iconCoords = SetDropDownRoleIcon(info, Addon:GetSlotRole(slot))
                        end
                        info.func = function()
                            Addon:SetZoneAssignment(currentZoneId, currentSlot)
                            CloseDropDownMenus()
                        end
                        UIDropDownMenu_AddButton(info, level)
                        ResetDropDownButtonLayout(level, iconCoords)
                    end
                end
            end, "MENU")
            marker:SetScript("OnClick", function(self)
                ToggleDropDownMenu(1, nil, self.menu, self, 0, 0)
            end)
        end

        marker:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            if currentZoneId == "BOSS" then
                GameTooltip:SetText("BQL")
            else
                GameTooltip:SetText("Zona " .. tostring(zoneRole))
                if self.assignedSlot then
                    GameTooltip:AddLine(Addon:GetSlotLabel(self.assignedSlot) .. " · " .. Addon:GetSlotName(self.assignedSlot), 1, 1, 1)
                else
                    GameTooltip:AddLine("Sin puesto asignado", 1, 0.35, 0.35)
                end
                GameTooltip:AddLine("Haz clic para seleccionar un puesto " .. tostring(zoneRole) .. ".", 0.75, 0.75, 0.75, true)
            end
            GameTooltip:Show()
        end)
        marker:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
        self.mapMarkers[currentZoneId] = marker
    end

    local footer = CreateText(panel, "GameFontDisableSmall", "La forma y las posiciones reproducen el bloque G1:Z14 del Excel.", "TOPLEFT", panel, "TOPLEFT", 20, -349)
    footer:SetTextColor(COLORS.muted[1], COLORS.muted[2], COLORS.muted[3])

    CreateSectionTitle(panel, "Leyenda", 540, -12)
    local legend = {
        { label = "Tanks", color = COLORS.neutral },
        { label = "MDPS", color = COLORS.melee },
        { label = "RDPS", color = COLORS.ranged },
        { label = "Healers", color = COLORS.healers },
        { label = "Flames", color = COLORS.flames },
        { label = "BQL", color = COLORS.boss },
    }
    for index, item in ipairs(legend) do
        local swatch = CreateFrame("Frame", nil, panel)
        swatch:SetWidth(14)
        swatch:SetHeight(14)
        swatch:SetPoint("TOPLEFT", panel, "TOPLEFT", 542, -39 - ((index - 1) * 17))
        swatch:SetBackdrop({ bgFile = "Interface\\ChatFrame\\ChatFrameBackground" })
        swatch:SetBackdropColor(item.color[1], item.color[2], item.color[3], 0.90)
        CreateText(panel, "GameFontHighlightSmall", item.label, "TOPLEFT", panel, "TOPLEFT", 563, -39 - ((index - 1) * 17))
    end

    CreateSectionTitle(panel, "Recordatorios", 540, -143)
    local definitions = {
        { key = "MDPS", label = "MDPS", color = COLORS.melee },
        { key = "RDPS", label = "RDPS", color = COLORS.ranged },
        { key = "HEALERS", label = "Healers", color = COLORS.healers },
        { key = "FLAMES", label = "Flames", color = COLORS.flames },
    }

    for index, definition in ipairs(definitions) do
        local y = -171 - ((index - 1) * 64)
        local title = CreateText(panel, "GameFontNormalSmall", definition.label, "TOPLEFT", panel, "TOPLEFT", 542, y)
        title:SetTextColor(definition.color[1], definition.color[2], definition.color[3])
        local input = CreateNoteInput(panel, 245, 39)
        input:SetPoint("TOPLEFT", panel, "TOPLEFT", 540, y - 15)
        local key = definition.key
        input:SetScript("OnEditFocusLost", function(box)
            if not Addon:CanModifyConfiguration(true) then
                UI:Refresh()
                return
            end
            local value = Addon:Trim(box:GetText())
            if Addon.db.zones[key] ~= value then
                Addon.db.zones[key] = value
                Addon:ScheduleAutoSync()
            end
            UI:Refresh()
        end)
        self.zoneInputs[key] = input
    end
    self:RegisterConfigurationPanel(panel)
end

function UI:ShowTab(key)
    self.currentTab = key
    if key == "roster" then
        Addon:RequestGuildRoster()
    end
    for tabKey, panel in pairs(self.panels) do
        if tabKey == key then
            panel:Show()
        else
            panel:Hide()
        end
    end

    for tabKey, button in pairs(self.tabs) do
        if tabKey == key then
            button:Disable()
        else
            button:Enable()
        end
    end
    self:Refresh()
end

function UI:GetRaidNameSet()
    local names = {}
    for _, member in ipairs(Addon:GetRaidMembers()) do
        names[Addon:NormalizeName(member.name)] = true
    end
    return names
end

function UI:RefreshSummary()
    if not self.summaryState then
        return
    end

    if Addon.state.active then
        self.summaryState:SetText("Estado: ACTIVO · Mordida actual: " .. tostring(Addon.state.currentWave))
        self.summaryState:SetTextColor(COLORS.green[1], COLORS.green[2], COLORS.green[3])
    else
        self.summaryState:SetText("Estado: detenido · Preparado para un nuevo intento")
        self.summaryState:SetTextColor(COLORS.muted[1], COLORS.muted[2], COLORS.muted[3])
    end

    for wave = 1, 5 do
        local label = self.waveTexts[wave]
        local complete = Addon:IsWaveComplete(wave)
        local marker = complete and "[OK]" or (Addon.state.active and Addon.state.currentWave == wave and ">>" or "-")
        label:SetText(marker .. "  Mordida " .. wave .. ":  " .. Addon:FormatWave(wave, false))
        if complete then
            label:SetTextColor(COLORS.green[1], COLORS.green[2], COLORS.green[3])
        elseif Addon.state.active and Addon.state.currentWave == wave then
            label:SetTextColor(COLORS.yellow[1], COLORS.yellow[2], COLORS.yellow[3])
        else
            label:SetTextColor(0.86, 0.86, 0.90)
        end
    end

    self.autoStartCheck:SetChecked(Addon.db.options.autoStart)
    self.whisperCheck:SetChecked(Addon.db.options.whisperAssignments)
    self.warningCheck:SetChecked(Addon.db.options.raidWarnings)
    self.syncCheck:SetChecked(Addon.db.options.acceptSync)
    self.autoSyncCheck:SetChecked(Addon.db.options.autoSync)

    local issues = Addon:GetValidationIssues()
    if #issues == 0 then
        self.validationText:SetText("Validación correcta. La plantilla y el árbol de mordidas no tienen conflictos.")
        self.validationText:SetTextColor(COLORS.green[1], COLORS.green[2], COLORS.green[3])
    else
        local first = issues[1] or ""
        self.validationText:SetText("Validación: " .. #issues .. " problema(s). Primero: " .. first .. " Usa el botón Validar para ver la lista completa en el chat.")
        self.validationText:SetTextColor(COLORS.red[1], COLORS.red[2], COLORS.red[3])
    end
end

function UI:RefreshRoster()
    if not self.rosterRows then
        return
    end

    local raidNames = self:GetRaidNameSet()
    local activeSlots = Addon:GetActiveSlotOrder()
    for _, slot in ipairs(Addon.SLOT_ORDER) do
        local row = self.rosterRows[slot]
        row.online:Hide()
        row.slot:Hide()
        row.name:Hide()
        row.spec:Hide()
    end

    for index, slot in ipairs(activeSlots) do
        local record = Addon.db.roster[slot]
        local row = self.rosterRows[slot]
        local columnX
        local rowNumber
        if index <= 13 then
            columnX = 16
            rowNumber = index - 1
        else
            columnX = 408
            rowNumber = index - 14
        end
        local y = -69 - (rowNumber * 28)

        row.online:ClearAllPoints()
        row.online:SetPoint("TOPLEFT", self.panels.roster, "TOPLEFT", columnX, y - 2)
        row.slot:ClearAllPoints()
        row.slot:SetPoint("TOPLEFT", self.panels.roster, "TOPLEFT", columnX + 14, y)
        row.name:ClearAllPoints()
        row.name:SetPoint("TOPLEFT", self.panels.roster, "TOPLEFT", columnX + 77, y + 5)
        row.spec:ClearAllPoints()
        row.spec:SetPoint("TOPLEFT", self.panels.roster, "TOPLEFT", columnX + 241, y + 3)

        row.online:Show()
        row.slot:Show()
        row.name:Show()
        row.spec:Show()
        row.slot:SetText(Addon:GetSlotLabel(slot))
        self:SetGuildMemberSelectorValue(row.name, record.name)
        self:SetSpecSelectorValue(row.spec, record.spec)
        if raidNames[Addon:NormalizeName(record.name)] then
            row.online:SetTextColor(COLORS.green[1], COLORS.green[2], COLORS.green[3])
        else
            row.online:SetTextColor(0.35, 0.35, 0.40)
        end
    end

    local counts = Addon:GetRoleCounts()
    local total = #activeSlots
    self.rosterTotal:SetText(tostring(total) .. "/" .. tostring(Addon.MAX_ROSTER_SIZE))
    for _, role in ipairs(Addon.ROLE_ORDER) do
        local control = self.roleControls[role]
        local count = counts[role] or 0
        control.count:SetText(tostring(count))

        local minimum = Addon.ROLE_MINIMUMS[role] or 0
        if count <= minimum then
            control.remove:Disable()
        else
            control.remove:Enable()
        end

        local maximum = Addon.ROLE_MAXIMUMS[role]
        if total >= Addon.MAX_ROSTER_SIZE or (maximum and count >= maximum) then
            control.add:Disable()
        else
            control.add:Enable()
        end
    end
end

function UI:RefreshBites()
    if not self.biteRows then
        return
    end

    for index, row in ipairs(self.biteRows) do
        local edge = Addon.db.bites[index]
        if edge then
            row.wave:SetText(tostring(edge.wave))
            self:SetRosterSlotSelectorValue(row.source, edge.source)
            self:SetRosterSlotSelectorValue(row.target, edge.target)
            row.sourceName:SetText(Addon:GetSlotName(edge.source))
            row.targetName:SetText(Addon:GetSlotName(edge.target))
            if Addon.state.completed[index] then
                row.state:SetText("OK")
                row.state:SetTextColor(COLORS.green[1], COLORS.green[2], COLORS.green[3])
            elseif Addon.state.active and Addon.state.currentWave == edge.wave then
                row.state:SetText(">")
                row.state:SetTextColor(COLORS.yellow[1], COLORS.yellow[2], COLORS.yellow[3])
            else
                row.state:SetText("-")
                row.state:SetTextColor(COLORS.muted[1], COLORS.muted[2], COLORS.muted[3])
            end
        end
    end
end

function UI:RefreshCooldowns()
    if not self.cooldownRows then
        return
    end

    for _, row in ipairs(self.cooldownRows) do
        local record = Addon.db.cooldowns[row.group][row.index]
        row.label:SetText(record.label or "")
        if row.group == "threat" then
            self:SetRosterSlotSelectorValue(row.source, record.source)
            self:SetRosterSlotSelectorValue(row.target, record.target)
            row.name:SetText(Addon:GetSlotName(record.source) .. " > " .. Addon:GetSlotName(record.target))
        else
            self:SetRosterSlotSelectorValue(row.slot, record.slot)
            row.name:SetText(Addon:GetSlotName(record.slot))
        end
    end
end

function UI:RefreshZones()
    if not self.zoneInputs then
        return
    end

    for key, input in pairs(self.zoneInputs) do
        SetInputText(input, Addon.db.zones[key])
    end
    for zoneId, marker in pairs(self.mapMarkers) do
        local slot = zoneId == "BOSS" and "BOSS" or Addon:GetZoneAssignment(zoneId)
        marker.assignedSlot = slot
        marker:Show()
        local name = slot == "BOSS" and "BQL" or (slot and Addon:GetSlotName(slot) or "Sin asignar")
        if string.len(name) > marker.maxChars then
            name = string.sub(name, 1, marker.maxChars - 1) .. "."
        end
        marker.label:SetText(name)
        local color = zoneId == "BOSS" and COLORS.boss or GetRoleColor(marker.role)
        marker:SetBackdropBorderColor(color[1], color[2], color[3], 1)
    end
end

function UI:RefreshConfigurationLock()
    local locked = Addon:IsConfigurationLocked()
    local editableControls = {
        self.startButton,
        self.resetButton,
        self.syncButton,
        self.importButton,
        self.autoStartCheck,
        self.whisperCheck,
        self.warningCheck,
        self.syncCheck,
        self.autoSyncCheck,
        self.lockCheck,
    }

    for _, control in ipairs(editableControls) do
        if locked then
            control:Disable()
        else
            control:Enable()
        end
    end
    if locked then
        self.stopButton:Enable()
        CloseDropDownMenus()
    else
        self.stopButton:Disable()
    end

    for _, overlay in ipairs(self.configurationLockOverlays) do
        if locked then
            overlay:Show()
        else
            overlay:Hide()
        end
    end

    for _, row in pairs(self.rosterRows or {}) do
        if locked then
            row.name.editBox:ClearFocus()
        end
        row.name.editBox:EnableMouse(not locked)
        if row.name.editBox.EnableKeyboard then
            row.name.editBox:EnableKeyboard(not locked)
        end
    end
    for _, input in pairs(self.zoneInputs or {}) do
        if locked then
            input:ClearFocus()
        end
        input:EnableMouse(not locked)
        if input.EnableKeyboard then
            input:EnableKeyboard(not locked)
        end
    end
end

function UI:Refresh()
    if not self.frame or not Addon.db then
        return
    end

    self.lockCheck:SetChecked(Addon.db.options.locked)
    if Addon.state.active then
        self.statusText:SetText("Seguimiento activo · Mordida " .. tostring(Addon.state.currentWave) .. " · Configuración bloqueada")
        self.statusText:SetTextColor(COLORS.green[1], COLORS.green[2], COLORS.green[3])
    else
        self.statusText:SetText("Seguimiento detenido")
        self.statusText:SetTextColor(COLORS.muted[1], COLORS.muted[2], COLORS.muted[3])
    end

    self:RefreshSummary()
    self:RefreshRoster()
    self:RefreshBites()
    self:RefreshCooldowns()
    self:RefreshZones()
    self:RefreshConfigurationLock()
end

function UI:Toggle()
    if not self.frame then
        return
    end
    if self.frame:IsShown() then
        self.frame:Hide()
    else
        self.frame:Show()
    end
end

function UI:Initialize()
    if self.frame then
        return
    end
    self:CreateMainFrame()
    self:Refresh()
end
