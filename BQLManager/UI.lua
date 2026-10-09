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

local function GetSlotRoleColor(slot)
    if slot == "BOSS" then
        return COLORS.boss
    end

    local role = Addon:GetSlotRole(slot)
    if role == "MDPS" then
        return COLORS.melee
    elseif role == "RDPS" then
        return COLORS.ranged
    elseif role == "HEALER" then
        return COLORS.healers
    end
    return COLORS.neutral
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

function UI:SetSpecSelectorValue(selector, specId)
    local spec = Addon:GetSpecDefinition(specId)
    selector.selectedSpecId = spec and spec.id or nil

    if not spec then
        selector.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        selector.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        selector:SetBackdropBorderColor(0.30, 0.30, 0.36, 1)
        return
    end

    selector.icon:SetTexture(spec.icon)
    selector.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    local color = _G.RAID_CLASS_COLORS and _G.RAID_CLASS_COLORS[spec.classKey]
    if color then
        selector:SetBackdropBorderColor(color.r, color.g, color.b, 1)
    else
        selector:SetBackdropBorderColor(0.30, 0.30, 0.36, 1)
    end
end

local function MoveClassMenuArrow(level)
    local list = _G["DropDownList" .. tostring(level)]
    if not list or not list.numButtons then
        return
    end

    local buttonName = "DropDownList" .. tostring(level) .. "Button" .. tostring(list.numButtons)
    local button = _G[buttonName]
    local arrow = _G[buttonName .. "ExpandArrow"] or (button and button.expandArrow)
    local icon = _G[buttonName .. "Icon"] or (button and button.icon)
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
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    SetBackdrop(frame, COLORS.darkPurple, COLORS.border)

    frame:SetScript("OnDragStart", function(self)
        if not Addon.db.options.locked then
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
    frame:SetScript("OnShow", function()
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
        Addon.db.options.locked = button:GetChecked() and true or false
    end)
    self.lockCheck:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -48, -42)

    self.tabs = {}
    self.panels = {}
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
    start:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -44)

    local stop = CreateButton(panel, "Detener", 92, 24, function()
        Addon:StopEncounter("manual", true)
    end)
    stop:SetPoint("LEFT", start, "RIGHT", 5, 0)

    local reset = CreateButton(panel, "Reiniciar", 92, 24, function()
        Addon:ResetEncounter(true)
    end)
    reset:SetPoint("LEFT", stop, "RIGHT", 5, 0)

    local announce = CreateButton(panel, "Anunciar plan", 112, 24, function()
        Addon:AnnounceFullPlan()
    end)
    announce:SetPoint("LEFT", reset, "RIGHT", 14, 0)

    local sync = CreateButton(panel, "Sincronizar", 104, 24, function()
        Addon:SyncConfiguration()
    end)
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

    self.validationText = CreateText(panel, "GameFontHighlightSmall", "", "TOPLEFT", panel, "TOPLEFT", 18, -382)
    self.validationText:SetWidth(775)
    self.validationText:SetHeight(45)
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
            row.name = CreateInput(panel, 150, 20)
            row.name:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)
            row.spec = CreateSpecSelector(panel, slot)
            row.spec:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)

            local currentSlot = slot
            row.name:SetScript("OnEditFocusLost", function(box)
                Addon:SetRosterValue(currentSlot, "name", box:GetText())
            end)
            self.rosterRows[slot] = row
        end
    end
end

function UI:CreateBitesPanel(parent)
    local panel = CreatePanel(parent)
    self.panels.bites = panel
    self.biteRows = {}

    CreateSectionTitle(panel, "Árbol editable de mordidas", 16, -12)
    local help = CreateText(panel, "GameFontDisableSmall", "Usa puestos, no nombres. La primera fuente debe ser BOSS.", "TOPLEFT", panel, "TOPLEFT", 270, -18)
    help:SetTextColor(COLORS.muted[1], COLORS.muted[2], COLORS.muted[3])

    CreateText(panel, "GameFontNormalSmall", "Ronda", "TOPLEFT", panel, "TOPLEFT", 18, -48)
    CreateText(panel, "GameFontNormalSmall", "Origen", "TOPLEFT", panel, "TOPLEFT", 82, -48)
    CreateText(panel, "GameFontNormalSmall", "Personaje", "TOPLEFT", panel, "TOPLEFT", 190, -48)
    CreateText(panel, "GameFontNormalSmall", "Destino", "TOPLEFT", panel, "TOPLEFT", 392, -48)
    CreateText(panel, "GameFontNormalSmall", "Personaje", "TOPLEFT", panel, "TOPLEFT", 500, -48)

    for index = 1, 16 do
        local y = -70 - ((index - 1) * 23)
        local row = {}
        row.state = CreateText(panel, "GameFontHighlightSmall", "-", "TOPLEFT", panel, "TOPLEFT", 18, y)
        row.wave = CreateText(panel, "GameFontHighlightSmall", "", "TOPLEFT", panel, "TOPLEFT", 43, y)
        row.wave:SetWidth(30)
        row.source = CreateInput(panel, 94, 19)
        row.source:SetPoint("TOPLEFT", panel, "TOPLEFT", 78, y + 5)
        row.sourceName = CreateText(panel, "GameFontHighlightSmall", "", "TOPLEFT", panel, "TOPLEFT", 190, y)
        row.sourceName:SetWidth(180)
        row.sourceName:SetJustifyH("LEFT")
        row.target = CreateInput(panel, 94, 19)
        row.target:SetPoint("TOPLEFT", panel, "TOPLEFT", 386, y + 5)
        row.targetName = CreateText(panel, "GameFontHighlightSmall", "", "TOPLEFT", panel, "TOPLEFT", 500, y)
        row.targetName:SetWidth(190)
        row.targetName:SetJustifyH("LEFT")

        local currentIndex = index
        row.source:SetScript("OnEditFocusLost", function(box)
            local edge = Addon.db.bites[currentIndex]
            if edge then
                local slot = Addon:ResolveSlotLabel(box:GetText(), true)
                if slot then
                    edge.source = slot
                end
            end
            UI:Refresh()
        end)
        row.target:SetScript("OnEditFocusLost", function(box)
            local edge = Addon.db.bites[currentIndex]
            if edge then
                local slot = Addon:ResolveSlotLabel(box:GetText(), false)
                if slot then
                    edge.target = slot
                end
            end
            UI:Refresh()
        end)
        self.biteRows[index] = row
    end
end

function UI:CreateCooldownPanel(parent)
    local panel = CreatePanel(parent)
    self.panels.cooldowns = panel
    self.cooldownRows = {}

    CreateSectionTitle(panel, "Cooldowns y amenaza", 16, -12)
    local help = CreateText(panel, "GameFontDisableSmall", "Edita los puestos; los nombres se resuelven desde la plantilla.", "TOPLEFT", panel, "TOPLEFT", 230, -18)
    help:SetTextColor(COLORS.muted[1], COLORS.muted[2], COLORS.muted[3])

    local function BuildStandardGroup(group, title, x, y)
        local color = group == "aura" and COLORS.yellow or COLORS.healers
        CreateSectionTitle(panel, title, x, y, color)
        local records = Addon.db.cooldowns[group]
        for index = 1, #records do
            local rowY = y - 29 - ((index - 1) * 28)
            local row = { group = group, index = index }
            row.label = CreateText(panel, "GameFontHighlightSmall", "", "TOPLEFT", panel, "TOPLEFT", x + 4, rowY)
            row.label:SetWidth(125)
            row.label:SetJustifyH("LEFT")
            row.slot = CreateInput(panel, 82, 20)
            row.slot:SetPoint("TOPLEFT", panel, "TOPLEFT", x + 130, rowY + 5)
            row.name = CreateText(panel, "GameFontHighlightSmall", "", "TOPLEFT", panel, "TOPLEFT", x + 228, rowY)
            row.name:SetWidth(145)
            row.name:SetJustifyH("LEFT")

            local currentGroup = group
            local currentIndex = index
            row.slot:SetScript("OnEditFocusLost", function(box)
                local slot = Addon:ResolveSlotLabel(box:GetText(), false)
                if slot then
                    Addon.db.cooldowns[currentGroup][currentIndex].slot = slot
                end
                UI:Refresh()
            end)
            tinsert(UI.cooldownRows, row)
        end
    end

    local function BuildThreatGroup(group, title, x, y)
        CreateSectionTitle(panel, title, x, y, COLORS.flames)
        local records = Addon.db.cooldowns[group]
        for index = 1, #records do
            local rowY = y - 29 - ((index - 1) * 30)
            local row = { group = group, index = index }
            row.label = CreateText(panel, "GameFontHighlightSmall", "", "TOPLEFT", panel, "TOPLEFT", x + 4, rowY)
            row.label:SetWidth(48)
            row.source = CreateInput(panel, 78, 20)
            row.source:SetPoint("TOPLEFT", panel, "TOPLEFT", x + 52, rowY + 5)
            row.arrow = CreateText(panel, "GameFontHighlightSmall", ">", "TOPLEFT", panel, "TOPLEFT", x + 142, rowY)
            row.target = CreateInput(panel, 78, 20)
            row.target:SetPoint("TOPLEFT", panel, "TOPLEFT", x + 158, rowY + 5)
            row.name = CreateText(panel, "GameFontHighlightSmall", "", "TOPLEFT", panel, "TOPLEFT", x + 248, rowY)
            row.name:SetWidth(130)
            row.name:SetJustifyH("LEFT")

            local currentIndex = index
            row.source:SetScript("OnEditFocusLost", function(box)
                local slot = Addon:ResolveSlotLabel(box:GetText(), false)
                if slot then
                    Addon.db.cooldowns.threat[currentIndex].source = slot
                end
                UI:Refresh()
            end)
            row.target:SetScript("OnEditFocusLost", function(box)
                local slot = Addon:ResolveSlotLabel(box:GetText(), false)
                if slot then
                    Addon.db.cooldowns.threat[currentIndex].target = slot
                end
                UI:Refresh()
            end)
            tinsert(UI.cooldownRows, row)
        end
    end

    BuildStandardGroup("aura", "Aura Mastery", 18, -49)
    BuildStandardGroup("flight1", "Primer vuelo", 18, -207)
    BuildStandardGroup("flight2", "Segundo vuelo", 418, -49)
    BuildThreatGroup("threat", "MD / Tricks", 418, -236)
end

function UI:CreateZonesPanel(parent)
    local panel = CreatePanel(parent)
    self.panels.zones = panel
    self.zoneInputs = {}
    self.mapMarkers = {}

    CreateSectionTitle(panel, "Mapa de zonas según color", 16, -12)
    local help = CreateText(panel, "GameFontDisableSmall", "/range 8 · Pasa el ratón por un jugador para ver su puesto.", "TOPLEFT", panel, "TOPLEFT", 255, -18)
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
        local marker = CreateFrame("Frame", nil, map)
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
        local color = GetSlotRoleColor(definition.slot)
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
        marker.slot = definition.slot
        marker.maxChars = definition.span == 2 and 8 or 12
        marker:EnableMouse(true)
        local currentSlot = definition.slot
        marker:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(currentSlot == "BOSS" and "BQL" or Addon:GetSlotLabel(currentSlot))
            if currentSlot ~= "BOSS" then
                GameTooltip:AddLine(Addon:GetSlotName(currentSlot), 1, 1, 1)
            end
            GameTooltip:Show()
        end)
        marker:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
        self.mapMarkers[definition.slot] = marker
    end

    local footer = CreateText(panel, "GameFontDisableSmall", "La forma y las posiciones reproducen el bloque G1:Z14 del Excel.", "TOPLEFT", panel, "TOPLEFT", 20, -349)
    footer:SetTextColor(COLORS.muted[1], COLORS.muted[2], COLORS.muted[3])

    CreateSectionTitle(panel, "Leyenda", 540, -12)
    local legend = {
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
        swatch:SetPoint("TOPLEFT", panel, "TOPLEFT", 542, -39 - ((index - 1) * 20))
        swatch:SetBackdrop({ bgFile = "Interface\\ChatFrame\\ChatFrameBackground" })
        swatch:SetBackdropColor(item.color[1], item.color[2], item.color[3], 0.90)
        CreateText(panel, "GameFontHighlightSmall", item.label, "TOPLEFT", panel, "TOPLEFT", 563, -39 - ((index - 1) * 20))
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
            Addon.db.zones[key] = Addon:Trim(box:GetText())
            UI:Refresh()
        end)
        self.zoneInputs[key] = input
    end
end

function UI:ShowTab(key)
    self.currentTab = key
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
        SetInputText(row.name, record.name)
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
            SetInputText(row.source, Addon:GetSlotLabel(edge.source))
            SetInputText(row.target, Addon:GetSlotLabel(edge.target))
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
            SetInputText(row.source, Addon:GetSlotLabel(record.source))
            SetInputText(row.target, Addon:GetSlotLabel(record.target))
            row.name:SetText(Addon:GetSlotName(record.source) .. " > " .. Addon:GetSlotName(record.target))
        else
            SetInputText(row.slot, Addon:GetSlotLabel(record.slot))
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
    for slot, marker in pairs(self.mapMarkers) do
        if slot == "BOSS" or Addon:IsSlotActive(slot) then
            marker:Show()
            local name = slot == "BOSS" and "BQL" or Addon:GetSlotName(slot)
            if string.len(name) > marker.maxChars then
                name = string.sub(name, 1, marker.maxChars - 1) .. "."
            end
            marker.label:SetText(name)
            local color = GetSlotRoleColor(slot)
            marker:SetBackdropBorderColor(color[1], color[2], color[3], 1)
        else
            marker:Hide()
        end
    end
end

function UI:Refresh()
    if not self.frame or not Addon.db then
        return
    end

    self.lockCheck:SetChecked(Addon.db.options.locked)
    if Addon.state.active then
        self.statusText:SetText("Seguimiento activo · Mordida " .. tostring(Addon.state.currentWave))
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
