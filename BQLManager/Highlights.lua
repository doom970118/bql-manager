local Addon = _G.BQLManager
if not Addon then
    return
end

local Highlights = {}
Addon.BiteHighlights = Highlights

local ipairs = ipairs
local pairs = pairs
local sin = math.sin
local tostring = tostring

local UPDATE_INTERVAL = 0.05
local SCAN_INTERVAL = 0.50
local TEST_DURATION = 15
local FRIENDLY_NAMEPLATE_CVAR = "nameplateShowFriends"
local FALLBACK_BITE_ICON = "Interface\\Icons\\Spell_Shadow_LifeDrain02"

local biteIcon = FALLBACK_BITE_ICON
if GetSpellInfo then
    local _, _, detectedIcon = GetSpellInfo(71726)
    biteIcon = detectedIcon or biteIcon
end

local STYLE = {
    biter = {
        color = { 0.72, 0.30, 0.95 },
        label = "TE MUERDE",
    },
    target = {
        color = { 1.00, 0.22, 0.08 },
        label = "MUERDE",
    },
}

Highlights.elapsed = 0
Highlights.scanElapsed = SCAN_INTERVAL
Highlights.overlays = setmetatable({}, { __mode = "k" })
Highlights.activeOverlays = setmetatable({}, { __mode = "k" })
Highlights.testSourceSlot = nil
Highlights.testTargetSlot = nil
Highlights.testEndsAt = nil
Highlights.forcedFriendlyNameplates = false
Highlights.previousFriendlyNameplates = nil
Highlights.visualActive = false

local function Now()
    return GetTime and GetTime() or 0
end

local function IsVisible(frame)
    return not frame.IsShown or frame:IsShown()
end

local function FindHealthBar(frame)
    local children = { frame:GetChildren() }
    for _, child in ipairs(children) do
        if child.GetObjectType and child:GetObjectType() == "StatusBar" and IsVisible(child) then
            return child
        end
    end
    return nil
end

local function FindAssignmentInRegions(frame, assignments)
    local regions = { frame:GetRegions() }
    for _, region in ipairs(regions) do
        if region.GetObjectType and region:GetObjectType() == "FontString" then
            local text = region:GetText()
            local assignment = text and assignments[Addon:NormalizeName(text)]
            if assignment then
                return assignment
            end
        end
    end
    return nil
end

local function FindAssignment(frame, assignments)
    local assignment = FindAssignmentInRegions(frame, assignments)
    if assignment then
        return assignment
    end
    local children = { frame:GetChildren() }
    for _, child in ipairs(children) do
        assignment = FindAssignmentInRegions(child, assignments)
        if assignment then
            return assignment
        end
    end
    return nil
end

function Highlights:IsTestActive()
    return self.testEndsAt ~= nil and Now() < self.testEndsAt
end

function Highlights:SetFriendlyNameplates(required)
    if required and not self.forcedFriendlyNameplates then
        self.previousFriendlyNameplates = GetCVar and GetCVar(FRIENDLY_NAMEPLATE_CVAR) or nil
        if SetCVar and self.previousFriendlyNameplates ~= "1" then
            SetCVar(FRIENDLY_NAMEPLATE_CVAR, "1")
        end
        self.forcedFriendlyNameplates = true
    elseif not required and self.forcedFriendlyNameplates then
        if SetCVar and self.previousFriendlyNameplates ~= nil then
            SetCVar(FRIENDLY_NAMEPLATE_CVAR, self.previousFriendlyNameplates)
        end
        self.previousFriendlyNameplates = nil
        self.forcedFriendlyNameplates = false
    end
end

function Highlights:HideAll()
    for _, overlay in pairs(self.overlays) do
        overlay:Hide()
    end
    self.activeOverlays = setmetatable({}, { __mode = "k" })
end

function Highlights:GetOverlay(nameplate)
    local overlay = self.overlays[nameplate]
    if overlay then
        return overlay
    end

    overlay = CreateFrame("Frame", nil, nameplate)
    overlay:EnableMouse(false)
    overlay:SetBackdrop({
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })

    overlay.fill = overlay:CreateTexture(nil, "BACKGROUND")
    overlay.fill:SetPoint("TOPLEFT", overlay, "TOPLEFT", 3, -3)
    overlay.fill:SetPoint("BOTTOMRIGHT", overlay, "BOTTOMRIGHT", -3, 3)

    overlay.iconBorder = CreateFrame("Frame", nil, overlay)
    overlay.iconBorder:SetWidth(38)
    overlay.iconBorder:SetHeight(38)
    overlay.iconBorder:SetPoint("BOTTOM", overlay, "TOP", 0, 3)
    overlay.iconBorder:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 10,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    overlay.iconBorder:SetBackdropColor(0.02, 0.02, 0.03, 0.96)

    overlay.icon = overlay.iconBorder:CreateTexture(nil, "ARTWORK")
    overlay.icon:SetPoint("TOPLEFT", overlay.iconBorder, "TOPLEFT", 4, -4)
    overlay.icon:SetPoint("BOTTOMRIGHT", overlay.iconBorder, "BOTTOMRIGHT", -4, 4)
    overlay.icon:SetTexture(biteIcon)
    overlay.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    overlay.label = overlay:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    overlay.label:SetPoint("BOTTOM", overlay.iconBorder, "TOP", 0, 2)
    overlay.label:SetShadowOffset(1, -1)
    overlay:Hide()
    self.overlays[nameplate] = overlay
    return overlay
end

function Highlights:ShowOnNameplate(nameplate, healthBar, assignment, pulse)
    local overlay = self:GetOverlay(nameplate)
    local style = STYLE[assignment.kind] or STYLE.target
    local color = style.color

    overlay:ClearAllPoints()
    overlay:SetPoint("TOPLEFT", healthBar, "TOPLEFT", -5, 5)
    overlay:SetPoint("BOTTOMRIGHT", healthBar, "BOTTOMRIGHT", 5, -5)
    overlay:SetFrameLevel((healthBar.GetFrameLevel and healthBar:GetFrameLevel() or nameplate:GetFrameLevel()) + 12)
    overlay:SetBackdropBorderColor(color[1], color[2], color[3], 1)
    overlay.fill:SetTexture(color[1], color[2], color[3], 0.24)
    overlay.iconBorder:SetBackdropBorderColor(color[1], color[2], color[3], 1)
    overlay.icon:SetVertexColor(color[1], color[2], color[3], 1)
    overlay.label:SetText(assignment.label or style.label)
    overlay.label:SetTextColor(color[1], color[2], color[3])
    overlay:SetAlpha(pulse)
    overlay:Show()
    self.activeOverlays[overlay] = true
end

function Highlights:PulseVisible(pulse)
    for overlay in pairs(self.activeOverlays) do
        overlay:SetAlpha(pulse)
    end
end

function Highlights:AddSlotAssignment(assignments, slot, kind, label)
    if slot == "BOSS" or not Addon:IsSlotActive(slot) then
        return
    end
    local name = Addon:GetSlotName(slot)
    if Addon:IsPlaceholder(slot, name) then
        return
    end
    assignments[Addon:NormalizeName(name)] = {
        slot = slot,
        name = name,
        kind = kind,
        label = label,
    }
end

function Highlights:BuildAssignments()
    local assignments = {}
    if not Addon.db then
        return assignments
    end

    if self:IsTestActive() then
        self:AddSlotAssignment(assignments, self.testSourceSlot, "biter", "MORDEDOR")
        self:AddSlotAssignment(assignments, self.testTargetSlot, "target", "MORDIDO")
        return assignments
    end

    if not Addon.db.options.biteHighlights or not Addon.state.active then
        return assignments
    end

    local playerName = UnitName and UnitName("player") or ""
    local playerSlot = Addon:GetSlotForName(playerName)
    if not playerSlot then
        return assignments
    end

    for _, item in ipairs(Addon:GetWaveEdges(Addon.state.currentWave)) do
        local edge = item.edge
        if not Addon.state.completed[item.index] then
            if edge.source == playerSlot then
                self:AddSlotAssignment(assignments, edge.target, "target", "MUERDE")
            elseif edge.target == playerSlot then
                self:AddSlotAssignment(assignments, edge.source, "biter", "TE MUERDE")
            end
        end
    end
    return assignments
end

function Highlights:StartTest(sourceSlot, targetSlot)
    if not Addon:IsSlotActive(sourceSlot) or not Addon:IsSlotActive(targetSlot) then
        Addon:Print("Selecciona un mordedor y un mordido válidos para la prueba.")
        return false
    end
    if sourceSlot == targetSlot then
        Addon:Print("El mordedor y el mordido deben ser jugadores diferentes.")
        return false
    end
    if Addon:IsPlaceholder(sourceSlot, Addon:GetSlotName(sourceSlot))
        or Addon:IsPlaceholder(targetSlot, Addon:GetSlotName(targetSlot)) then
        Addon:Print("La prueba necesita dos puestos ocupados por jugadores.")
        return false
    end

    self.testSourceSlot = sourceSlot
    self.testTargetSlot = targetSlot
    self.testEndsAt = Now() + TEST_DURATION
    self:RefreshNow()
    Addon:Print("Prueba visual activa durante " .. tostring(TEST_DURATION) .. " segundos.")
    return true
end

function Highlights:StopTest()
    self.testSourceSlot = nil
    self.testTargetSlot = nil
    self.testEndsAt = nil
    self:RefreshNow()
    if Addon.UI and Addon.UI.RefreshOptions then
        Addon.UI:RefreshOptions()
    end
end

function Highlights:RefreshNow()
    self.elapsed = UPDATE_INTERVAL
    self.scanElapsed = SCAN_INTERVAL
    self:Update(0)
end

function Highlights:Update(elapsed)
    self.elapsed = self.elapsed + (elapsed or 0)
    if self.elapsed < UPDATE_INTERVAL then
        return
    end
    local updateElapsed = self.elapsed
    self.elapsed = 0

    if self.testEndsAt and not self:IsTestActive() then
        self.testSourceSlot = nil
        self.testTargetSlot = nil
        self.testEndsAt = nil
        if Addon.UI and Addon.UI.RefreshOptions then
            Addon.UI:RefreshOptions()
        end
    end

    local testing = self:IsTestActive()
    local visualActive = testing or (Addon.db and Addon.db.options.biteHighlights and Addon.state.active)
    local forceNameplates = visualActive and Addon.db and Addon.db.options.forceFriendlyNameplates
    self:SetFriendlyNameplates(forceNameplates and true or false)

    if not visualActive then
        if self.visualActive then
            self:HideAll()
        end
        self.visualActive = false
        self.scanElapsed = SCAN_INTERVAL
        return
    end
    self.visualActive = true
    self.scanElapsed = self.scanElapsed + updateElapsed

    local pulse = 0.72 + (0.28 * ((sin(Now() * 5) + 1) / 2))
    self:PulseVisible(pulse)
    if self.scanElapsed < SCAN_INTERVAL then
        return
    end
    self.scanElapsed = 0

    local assignments = self:BuildAssignments()
    self:HideAll()
    if not next(assignments) then
        return
    end

    local nameplates = { WorldFrame:GetChildren() }
    for _, nameplate in ipairs(nameplates) do
        if IsVisible(nameplate) then
            local healthBar = FindHealthBar(nameplate)
            if healthBar then
                local assignment = FindAssignment(nameplate, assignments)
                if assignment then
                    self:ShowOnNameplate(nameplate, healthBar, assignment, pulse)
                end
            end
        end
    end
end

Highlights.frame = CreateFrame("Frame")
Highlights.frame:SetScript("OnUpdate", function(_, elapsed)
    Highlights:Update(elapsed)
end)
Highlights.frame:RegisterEvent("PLAYER_LOGOUT")
Highlights.frame:SetScript("OnEvent", function()
    Highlights:SetFriendlyNameplates(false)
end)
