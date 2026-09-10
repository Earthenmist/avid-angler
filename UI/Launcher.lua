-- Avid Angler
-- Minimap and addon-compartment launcher.

local ADDON_NAME, AvidAngler = ...
local L = AvidAngler.L

local Launcher = {}
AvidAngler.UI = AvidAngler.UI or {}
AvidAngler.UI.Launcher = Launcher

local ICON_TEXTURE = "Interface\\AddOns\\AvidAngler\\Media\\AvidAngler-logo.png"
local LAUNCHER_NAME = "Avid Angler"
local DEFAULT_MINIMAP_ANGLE = 225
local minimapRegistered = false

local function GetLauncherSettings()
    if not AvidAngler.DB then
        return nil
    end
    local settings = AvidAngler.DB.settings
    settings.launcher = settings.launcher or {}
    local launcher = settings.launcher
    -- Migrate the custom launcher's angle once; library settings take precedence.
    if launcher.minimapPos == nil then
        launcher.minimapPos = tonumber(launcher.minimapAngle) or DEFAULT_MINIMAP_ANGLE
    end
    return launcher
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
    if minimapRegistered or not Minimap then
        return
    end
    local settings = GetLauncherSettings()
    if not settings then
        return
    end
    local ldb = LibStub("LibDataBroker-1.1")
    local broker = ldb:GetDataObjectByName(LAUNCHER_NAME) or ldb:NewDataObject(LAUNCHER_NAME, {
        type = "launcher",
        label = L["LAUNCHER_TOOLTIP_TITLE"],
        icon = ICON_TEXTURE,
        iconCoords = {0.08, 0.92, 0.08, 0.92},
        OnClick = function(_, button) HandleClick(button) end,
        OnEnter = ShowTooltip,
        OnLeave = function() GameTooltip:Hide() end,
    })
    LibStub("LibDBIcon-1.0"):Register(LAUNCHER_NAME, broker, settings)
    minimapRegistered = true
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
