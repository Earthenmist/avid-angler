-- Avid Angler
-- Minimap and addon-compartment launcher.

local ADDON_NAME, AvidAngler = ...
local L = AvidAngler.L

local Launcher = {}
AvidAngler.UI = AvidAngler.UI or {}
AvidAngler.UI.Launcher = Launcher

local ICON_TEXTURE = "Interface\\AddOns\\AvidAngler\\Media\\AvidAngler-logo.png"
local DEFAULT_MINIMAP_ANGLE = 225
local MINIMAP_RADIUS = 80

local minimapButton
local dragging = false

local function AngleFromDelta(y, x)
    if math.atan2 then
        return math.deg(math.atan2(y, x))
    end

    if x == 0 then
        return y >= 0 and 90 or 270
    end

    local angle = math.deg(math.atan(y / x))
    if x < 0 then
        angle = angle + 180
    elseif y < 0 then
        angle = angle + 360
    end
    return angle
end

local function GetLauncherSettings()
    if not AvidAngler.DB then
        return nil
    end
    AvidAngler.DB.settings.launcher = AvidAngler.DB.settings.launcher or {}
    return AvidAngler.DB.settings.launcher
end

local function SetMinimapPosition(angle)
    if not minimapButton then
        return
    end

    local radians = math.rad(angle or DEFAULT_MINIMAP_ANGLE)
    minimapButton:ClearAllPoints()
    minimapButton:SetPoint("CENTER", Minimap, "CENTER", math.cos(radians) * MINIMAP_RADIUS, math.sin(radians) * MINIMAP_RADIUS)
end

local function SaveMinimapPosition()
    local settings = GetLauncherSettings()
    if not settings or not minimapButton then
        return
    end

    local centerX, centerY = Minimap:GetCenter()
    local buttonX, buttonY = minimapButton:GetCenter()
    if not centerX or not centerY or not buttonX or not buttonY then
        return
    end

    settings.minimapAngle = AngleFromDelta(buttonY - centerY, buttonX - centerX)
end

local function UpdateMinimapDrag()
    local centerX, centerY = Minimap:GetCenter()
    local cursorX, cursorY = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale()
    if not centerX or not centerY or not cursorX or not cursorY or not scale then
        return
    end

    cursorX = cursorX / scale
    cursorY = cursorY / scale
    SetMinimapPosition(AngleFromDelta(cursorY - centerY, cursorX - centerX))
end

local function OpenMainWindow()
    if AvidAngler.IsRuntimeDisabled and AvidAngler:IsRuntimeDisabled() then
        return
    end

    if AvidAngler.UI and AvidAngler.UI.MainWindow then
        AvidAngler.UI.MainWindow:Show()
    end
end

local function ToggleFishingVisual()
    if AvidAngler.IsRuntimeDisabled and AvidAngler:IsRuntimeDisabled() then
        return
    end

    local casting = AvidAngler.Modules and AvidAngler.Modules.Casting
    if not casting or not casting.SetControlsHidden or not casting.AreControlsHidden then
        return
    end

    if InCombatLockdown() then
        AvidAngler:Print(L["LAUNCHER_VISUAL_COMBAT"])
        return
    end

    local nextHidden = not casting:AreControlsHidden()
    casting:SetControlsHidden(nextHidden)
    AvidAngler:Print(nextHidden and L["LAUNCHER_VISUAL_HIDDEN"] or L["LAUNCHER_VISUAL_SHOWN"])
end

local function ShowTooltip(owner)
    GameTooltip:SetOwner(owner, "ANCHOR_BOTTOMLEFT", 36, -4)
    GameTooltip:SetText(L["LAUNCHER_TOOLTIP_TITLE"])
    GameTooltip:AddLine(L["LAUNCHER_TOOLTIP_LEFT"], 0.9, 0.82, 0.2, true)
    GameTooltip:AddLine(L["LAUNCHER_TOOLTIP_RIGHT"], 0.9, 0.82, 0.2, true)
    GameTooltip:Show()
end

local function HandleClick(button)
    if button == "RightButton" then
        ToggleFishingVisual()
    else
        OpenMainWindow()
    end
end

function Launcher:CreateMinimapButton()
    if minimapButton or not Minimap then
        return
    end

    local settings = GetLauncherSettings()

    minimapButton = CreateFrame("Button", "AvidAnglerMinimapButton", Minimap)
    minimapButton:SetSize(32, 32)
    minimapButton:SetFrameStrata("MEDIUM")
    minimapButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    minimapButton:RegisterForDrag("LeftButton")

    local icon = minimapButton:CreateTexture(nil, "BACKGROUND")
    icon:SetTexture(ICON_TEXTURE)
    icon:SetSize(22, 22)
    icon:SetPoint("CENTER", 0, 0)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    local border = minimapButton:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetSize(54, 54)
    border:SetPoint("TOPLEFT")

    minimapButton:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    SetMinimapPosition(settings and settings.minimapAngle or DEFAULT_MINIMAP_ANGLE)

    minimapButton:SetScript("OnClick", function(_, button)
        if dragging then
            return
        end
        HandleClick(button)
    end)
    minimapButton:SetScript("OnEnter", function(self)
        ShowTooltip(self)
    end)
    minimapButton:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    minimapButton:SetScript("OnDragStart", function(self)
        dragging = true
        self:SetScript("OnUpdate", UpdateMinimapDrag)
    end)
    minimapButton:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
        SaveMinimapPosition()
        C_Timer.After(0.05, function()
            dragging = false
        end)
    end)
end

function AvidAngler_AddonCompartment_OnClick(_, button)
    HandleClick(button)
end

function AvidAngler_AddonCompartment_OnEnter(_, button)
    ShowTooltip(button)
end

function AvidAngler_AddonCompartment_OnLeave()
    GameTooltip:Hide()
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:SetScript("OnEvent", function(_, _, addonName)
    if addonName == ADDON_NAME then
        Launcher:CreateMinimapButton()
    end
end)
