-- Avid Angler
-- Casting & gear automation pillar: the moment-to-moment cast/reel loop.
--
-- Cast triggers route through a SecureActionButtonTemplate button with its
-- macrotext set to a plain "/cast <spell name>" line rather than a direct
-- Lua spell cast, since spell casts of this kind must originate from a
-- real hardware event to run reliably. The spell name is resolved from its
-- ID at runtime rather than hardcoded, so this keeps working regardless of
-- the client's locale.

local ADDON_NAME, AvidAngler = ...

local Casting = {}
AvidAngler.Modules.Casting = Casting
local L = AvidAngler.L

-- The base Fishing cast. Additional fishing actions can layer on the same
-- secure-button path as the cast loop grows.
local FISHING_SPELL_ID = 7620
local DEFAULT_ONE_KEY = "CTRL-F"
local DOUBLE_RIGHT_WINDOW = 0.45
local EQUIPMENT_SET_NAME = "AvidAngler"
local DEFAULT_EQUIPMENT_SET_NAME = "Default"
local MAX_PRECAST_MACRO_LENGTH = 255
local ACTION_SLOT_COUNT = 6
local ACTION_TOY_SLOT_COUNT = 3
local DEFAULT_ACTION_SLOT_DELAY = 30
local DEFAULT_PICKER_DELAY = 300
local DEFAULT_BUTTON_SIZE = 60
local BUTTON_SIZE_DEFAULT_VERSION = 2
local RANDOM_ITEM_ID = -1
local OVERSIZED_BOBBER_SPELL_ID = 397827
local EXCLUDED_LURE_ITEM_IDS = {
    [243342] = true, -- Bloom Bauble is not offered for automatic lure upkeep.
    [278391] = true, -- Eerie Bauble is a quest-specific Midnight item, not a general lure picker choice.
}
local PICKER_KEYS = { "oversized", "bobber", "lure", "ward", "toy" }
local WATER_PICKER_KEYS = { "toy", "oversized", "bobber", "lure", "ward" }
local INPUT_MODE_OFF = "off"
local INPUT_MODE_ONE_KEY = "oneKey"
local INPUT_MODE_DOUBLE_RIGHT = "doubleRight"
local DISPLAY_MODE_HUD = "hud"
local DISPLAY_MODE_BUTTON = "button"
local FISHING_TOYS = {
    { key = "toy", name = "Tuskarr Dinghy", itemID = 198428, spellID = 383268, icon = 236574, waterOnly = true, auraManaged = true },
    { key = "toy", name = "Anglers Fishing Raft", itemID = 85500, spellID = 124036, icon = 774121, waterOnly = true, auraManaged = true, requiredFishingSkill = "pandaria" },
    { key = "toy", name = "Gnarlwood Waveboard", itemID = 166461, spellID = 288758, icon = 133798, waterOnly = true, auraManaged = true },
    { key = "toy", name = "Personal Fishing Barge", itemID = 235801, spellID = 1218420, icon = 2341435, waterOnly = true, auraManaged = true },
    { key = "oversized", name = "Reusable Oversized Bobber", itemID = 202207, spellID = OVERSIZED_BOBBER_SPELL_ID, icon = 236576, auraManaged = true },
    { key = "bobber", name = "Crate of Bobbers: Can of Worms", itemID = 142528, spellID = 231291, icon = 236197, auraManaged = true },
    { key = "bobber", name = "Crate of Bobbers: Carved Wooden Helm", itemID = 147307, spellID = 240803, icon = 463008, auraManaged = true },
    { key = "bobber", name = "Crate of Bobbers: Cat Head", itemID = 142529, spellID = 231319, icon = 454045, auraManaged = true },
    { key = "bobber", name = "Crate of Bobbers: Demon Noggin", itemID = 147312, spellID = 240801, icon = 236292, auraManaged = true },
    { key = "bobber", name = "Crate of Bobbers: Enchanted Bobber", itemID = 147308, spellID = 240800, icon = 236449, auraManaged = true },
    { key = "bobber", name = "Crate of Bobbers: Face of the Forest", itemID = 147309, spellID = 240806, icon = 236157, auraManaged = true },
    { key = "bobber", name = "Crate of Bobbers: Floating Totem", itemID = 147310, spellID = 240802, icon = 310733, auraManaged = true },
    { key = "bobber", name = "Crate of Bobbers: Murloc Head", itemID = 142532, spellID = 231349, icon = 134169, auraManaged = true },
    { key = "bobber", name = "Crate of Bobbers: Replica Gondola", itemID = 147311, spellID = 240804, icon = 517162, auraManaged = true },
    { key = "bobber", name = "Crate of Bobbers: Squeaky Duck", itemID = 142531, spellID = 231341, icon = 1369786, auraManaged = true },
    { key = "bobber", name = "Crate of Bobbers: Tugboat", itemID = 142530, spellID = 231338, icon = 1126431, auraManaged = true },
    { key = "bobber", name = "Crate of Bobbers: Wooden Pepe", itemID = 143662, spellID = 232613, icon = 1044996, auraManaged = true },
    { key = "bobber", name = "Bat Visage Bobber", itemID = 180993, spellID = 335484, icon = 132182, auraManaged = true },
    { key = "bobber", name = "Limited Edition Rocket Bobber", itemID = 237345, spellID = 1222880, icon = 6383563, auraManaged = true },
    { key = "bobber", name = "Artisan Beverage Goblet Bobber", itemID = 237346, spellID = 1222884, icon = 6383561, auraManaged = true },
    { key = "bobber", name = "Organically-Sourced Wellington Bobber", itemID = 237347, spellID = 1222888, icon = 6383562, auraManaged = true },
}
local POOL_TOOLTIP_PATTERNS = {
    "pool",
    "school",
    "shoal",
    "swarm",
    "frenzy",
    "wreckage",
    "debris",
    "fishing hole",
}
local BOBBER_TOOLTIP_TEXT = {
    ["Fishing Bobber"] = true,
}
local BOBBER_AURA_SPELL_IDS = {
    [231291] = true,
    [240803] = true,
    [231319] = true,
    [240801] = true,
    [240800] = true,
    [240806] = true,
    [240802] = true,
    [231349] = true,
    [240804] = true,
    [231341] = true,
    [231338] = true,
    [232613] = true,
    [335484] = true,
    [1222880] = true,
    [1222884] = true,
    [1222888] = true,
}
local GetGearSetID
local ApplyTempCVar
local RestoreCVar
local fishingSpellName
local pendingMacroUpdate = false
local activeAction
local suppressVisualRightClick = false
local actionSlots = {}
local actionChoices = { lure = {}, ward = {}, oversized = {}, bobber = {}, toy = {} }
local pendingRandomChoices = {}
local pickerSettings = {}
local cachedCVars = {}
local buttonPoint
local hudPoint
local visualHover = false
local castButton
local optionsButton
local actionHUD
local controlFrame
local PersistOneKeySettings
local QueueFishingBindingUpdate
local ApplyResolvedAction
local RefreshFishingControls
local SetActionHUD
local ResolveNextAction
local SuppressNextDoubleRightMouseUp
local Helpers = { gearEquipEnabled = false }

local function GetTooltipTitleText()
    if not GameTooltip or not GameTooltip:IsVisible() then
        return nil
    end
    local line = _G["GameTooltipTextLeft1"]
    local text = line and line:GetText()
    if text and text ~= "" then
        return text
    end
end

local function TooltipBelongsToFishingUI()
    if not MouseIsOver then
        return false
    end

    local frames = { castButton, optionsButton, actionHUD, controlFrame, AvidAnglerMainFrame }
    for _, frame in ipairs(frames) do
        if frame and MouseIsOver(frame) then
            return true
        end
    end
    return false
end

local function LooksLikePoolTooltip(text)
    if not text or BOBBER_TOOLTIP_TEXT[text] or TooltipBelongsToFishingUI() then
        return false
    end
    if text:find("Avid Angler", 1, true) then
        return false
    end
    local poolCatalog = AvidAngler.Data and AvidAngler.Data.PoolCatalog
    if poolCatalog and poolCatalog:IsPool(nil, text) then
        return true
    end
    if AvidAngler.Modules.Scoring and AvidAngler.Modules.Scoring.GetKnownPoolTooltip then
        local isKnownPool = AvidAngler.Modules.Scoring:GetKnownPoolTooltip(text)
        if isKnownPool then
            return true
        end
    end
    local lowered = text:lower()
    for _, pattern in ipairs(POOL_TOOLTIP_PATTERNS) do
        if lowered:find(pattern, 1, true) then
            return true
        end
    end
    return false
end

local function CaptureFishingSourceContext()
    local tooltipText = GetTooltipTitleText()
    if LooksLikePoolTooltip(tooltipText) then
        AvidAngler.Session.catchSource = "pool"
        AvidAngler.Session.poolName = tooltipText
        AvidAngler.Session.defaultCatchSource = nil
    else
        AvidAngler.Session.catchSource = "unknown"
        AvidAngler.Session.poolName = nil
        AvidAngler.Session.defaultCatchSource = "open-water"
    end
end

-- Both templates are needed on one frame: SecureActionButtonTemplate for
-- the protected macro click, BackdropTemplate so the button can carry the
-- shared theme's backdrop styling.
castButton = CreateFrame("Button", "AvidAnglerCastButton", UIParent, "SecureActionButtonTemplate, BackdropTemplate")
castButton:SetAttribute("type", "macro")
castButton:RegisterForClicks("AnyDown", "AnyUp")
castButton:SetSize(DEFAULT_BUTTON_SIZE, 26)
castButton:SetPoint("CENTER", UIParent, "CENTER", 0, -220)
castButton:SetMovable(true)
castButton:SetClampedToScreen(true)
castButton:EnableMouse(true)
castButton:RegisterForDrag("LeftButton")
castButton:Hide()

local Theme = AvidAngler.UI.Theme
castButton:SetBackdrop((Theme:Backdrop("panelRaised", "accentDim")))
castButton:SetBackdropColor(unpack(Theme.color.panelRaised))
castButton:SetBackdropBorderColor(unpack(Theme.color.accentDim))

local label = castButton:CreateFontString(nil, "ARTWORK")
label:SetFontObject(Theme.font.body)
label:SetPoint("CENTER")
label:SetText(AvidAngler.L["CAST_BUTTON_LABEL"])

local buttonIcon = castButton:CreateTexture(nil, "ARTWORK")
buttonIcon:SetPoint("TOPLEFT", 6, -6)
buttonIcon:SetPoint("BOTTOMRIGHT", -6, 6)
buttonIcon:SetTexture("Interface\\Icons\\UI_Profession_Fishing")
buttonIcon:Hide()

local castCloseButton
castButton:SetScript("OnEnter", function(self)
    visualHover = true
    castCloseButton:Show()
    self:SetBackdropBorderColor(unpack(Theme.color.accent))
    Casting:ShowVisualTooltip(self)
end)
castButton:SetScript("OnLeave", function(self)
    visualHover = false
    C_Timer.After(0.12, function()
        if not visualHover then
            castCloseButton:Hide()
            GameTooltip:Hide()
        end
    end)
    self:SetBackdropBorderColor(unpack(Theme.color.accentDim))
end)
castButton:SetScript("PreClick", function(self, button)
    suppressVisualRightClick = button == "RightButton" and self:IsMouseOver()
    if suppressVisualRightClick then
        self:SetAttribute("macrotext", "")
    elseif activeAction and activeAction.kind == "cast" and Helpers.CapturePreviousGearSet then
        Helpers.CapturePreviousGearSet()
    end
end)
castButton:SetScript("OnMouseUp", function(self, button)
    if button == "RightButton" and self:IsMouseOver() then
        SuppressNextDoubleRightMouseUp()
        Casting:SetSleeping(not Casting:IsSleeping())
    end
end)
castButton:SetScript("OnDragStart", function(self)
    self:StartMoving()
end)
castButton:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, relativePoint, x, y = self:GetPoint(1)
    buttonPoint = { point = point, relativePoint = relativePoint, x = x, y = y }
    PersistOneKeySettings()
end)
castButton:SetScript("PostClick", function()
    if suppressVisualRightClick then
        suppressVisualRightClick = false
        ApplyResolvedAction()
        return
    end
    if activeAction and activeAction.kind == "picker" and activeAction.pickerKey then
        local picker = pickerSettings[activeAction.pickerKey]
        if picker then
            if not (activeAction.choice and activeAction.choice.waterOnly and activeAction.choice.auraManaged) then
                pendingRandomChoices[activeAction.pickerKey] = nil
                picker.lastUsed = time()
            end
            PersistOneKeySettings()
            C_Timer.After(0.1, QueueFishingBindingUpdate)
        end
    elseif activeAction and activeAction.kind == "slot" and activeAction.slotIndex then
        local slot = actionSlots[activeAction.slotIndex]
        if slot then
            slot.lastUsed = time()
            PersistOneKeySettings()
            C_Timer.After(0.1, QueueFishingBindingUpdate)
        end
    end
end)

optionsButton = Theme:CreateButton(UIParent, L["CONTROL_PANEL_OPEN"])
optionsButton:SetPoint("LEFT", castButton, "RIGHT", Theme.layout.gutter, 0)
optionsButton:Hide()

castCloseButton = Theme:CreateCloseButton(UIParent)
castCloseButton:SetPoint("TOPRIGHT", castButton, "TOPRIGHT", 10, 10)
castCloseButton:SetSize(32, 32)
castCloseButton:SetScale(1.25)
castCloseButton:Hide()
castCloseButton:SetScript("OnEnter", function()
    visualHover = true
    castCloseButton:Show()
end)
castCloseButton:SetScript("OnLeave", function()
    visualHover = false
    C_Timer.After(0.12, function()
        if not visualHover then
            castCloseButton:Hide()
            GameTooltip:Hide()
        end
    end)
end)

actionHUD = CreateFrame("Frame", "AvidAnglerActionHUD", UIParent, "BackdropTemplate")
actionHUD:SetSize(280, 64)
actionHUD:SetPoint("CENTER", UIParent, "CENTER", 0, -160)
actionHUD:SetFrameStrata("MEDIUM")
actionHUD:SetBackdrop((Theme:Backdrop("panelRaised", "accentDim")))
actionHUD:SetBackdropColor(unpack(Theme.color.panelRaised))
actionHUD:SetBackdropBorderColor(unpack(Theme.color.accentDim))
actionHUD:SetMovable(true)
actionHUD:SetClampedToScreen(true)
actionHUD:EnableMouse(true)
actionHUD:RegisterForDrag("LeftButton")
actionHUD:SetScript("OnDragStart", function(self) self:StartMoving() end)
actionHUD:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, relativePoint, x, y = self:GetPoint(1)
    hudPoint = { point = point, relativePoint = relativePoint, x = x, y = y }
    PersistOneKeySettings()
end)
local actionHUDCloseButton
actionHUD:SetScript("OnEnter", function(self)
    visualHover = true
    actionHUDCloseButton:Show()
    Casting:ShowVisualTooltip(self)
end)
actionHUD:SetScript("OnLeave", function()
    visualHover = false
    C_Timer.After(0.12, function()
        if not visualHover then
            actionHUDCloseButton:Hide()
            GameTooltip:Hide()
        end
    end)
end)
actionHUD:SetScript("OnMouseUp", function(_, button)
    if button == "RightButton" then
        SuppressNextDoubleRightMouseUp()
        Casting:SetSleeping(not Casting:IsSleeping())
    end
end)
actionHUD:Hide()

actionHUDCloseButton = Theme:CreateCloseButton(actionHUD)
actionHUDCloseButton:SetPoint("TOPRIGHT", -4, -4)
actionHUDCloseButton:SetSize(24, 24)
actionHUDCloseButton:SetScale(1.12)
actionHUDCloseButton:Hide()
actionHUDCloseButton:SetScript("OnEnter", function()
    visualHover = true
    actionHUDCloseButton:Show()
end)
actionHUDCloseButton:SetScript("OnLeave", function()
    visualHover = false
    C_Timer.After(0.12, function()
        if not visualHover then
            actionHUDCloseButton:Hide()
            GameTooltip:Hide()
        end
    end)
end)

local actionIcon = actionHUD:CreateTexture(nil, "ARTWORK")
actionIcon:SetSize(42, 42)
actionIcon:SetPoint("LEFT", 10, 0)
actionIcon:SetTexture("Interface\\Icons\\UI_Profession_Fishing")

local actionTitle = actionHUD:CreateFontString(nil, "ARTWORK")
actionTitle:SetFontObject(Theme.font.title)
actionTitle:SetPoint("TOPLEFT", actionIcon, "TOPRIGHT", Theme.layout.gutter, -2)
actionTitle:SetPoint("RIGHT", -10, 0)
actionTitle:SetJustifyH("LEFT")
actionTitle:SetText(L["ACTION_READY"])

local actionDetail = actionHUD:CreateFontString(nil, "ARTWORK")
actionDetail:SetFontObject(Theme.font.small)
actionDetail:SetPoint("TOPLEFT", actionTitle, "BOTTOMLEFT", 0, -6)
actionDetail:SetPoint("RIGHT", -10, 0)
actionDetail:SetJustifyH("LEFT")
actionDetail:SetText("")

-- Sets the button's macro text once the Fishing spell's localized name is
-- available. Spell name data can load asynchronously on first reference,
-- so this is retried on SPELL_TEXT_UPDATE if the first attempt is empty.
-- Routed through AvidAngler:SafeCall since spell data reads are exactly
-- the kind of Blizzard API call that should fail closed rather than error.
local function BuildFishingMacro()
    if InCombatLockdown() then
        pendingMacroUpdate = true
        return nil
    end

    local name = AvidAngler:SafeCall(C_Spell.GetSpellName, nil, FISHING_SPELL_ID)
    if not name or name == "" then
        return nil
    end
    fishingSpellName = name

    local lines = {}
    if Helpers.gearEquipEnabled and GetGearSetID and GetGearSetID() then
        lines[#lines + 1] = "/equipset " .. EQUIPMENT_SET_NAME
    end
    lines[#lines + 1] = "/cast " .. name
    local macroText = table.concat(lines, "\n")
    return Helpers.PrefixDismountMacro and Helpers.PrefixDismountMacro(macroText) or macroText
end

local function ApplyMacroText()
    local macroText = BuildFishingMacro()
    if not macroText then
        return false
    end
    castButton:SetAttribute("macrotext", macroText)
    pendingMacroUpdate = false
    return true
end

local loadFrame = CreateFrame("Frame")
loadFrame:RegisterEvent("SPELL_TEXT_UPDATE")
loadFrame:SetScript("OnEvent", function()
    if ApplyResolvedAction() then
        loadFrame:UnregisterEvent("SPELL_TEXT_UPDATE")
    end
end)

if not ApplyMacroText() then
    AvidAngler:SafeCall(C_Spell.RequestLoadSpellData, nil, FISHING_SPELL_ID)
end

function Casting:GetCastButton()
    return castButton
end

local bindingFrame = CreateFrame("Frame")
local oneKeyEnabled = false
local oneKey = DEFAULT_ONE_KEY
local doubleRightEnabled = false
local autoLootEnabled = false
local audioFocusEnabled = false
local previousGearSetID
local dismountWithKeyEnabled = false
local releaseWhenSwimmingEnabled = true
local disableSoftInteractEnabled = false
local disableSoftIconEnabled = false
local precastMacroEnabled = false
local precastMacroText = ""
local doubleRightWatching = false
local doubleRightHeld = false
local doubleRightIgnoreNextMouseUp = false
local doubleRightIgnoreVisualMouseUp = false
local isFishing = false
local pendingBindingUpdate = false
local moduleEnabled = true
local inputMode = INPUT_MODE_OFF
local displayMode = DISPLAY_MODE_HUD
local wakeDisplayMode = DISPLAY_MODE_HUD
local controlsHidden = false
local combatVisualHidden = false
local contentVisualHidden = false
local sleeping = false
local playerInWater = false
local pendingWaterRefresh = false
local lastWaterStateUpdate = 0
local buttonSize = DEFAULT_BUTTON_SIZE
local DEFAULT_AUDIO_FOCUS_SETTINGS = {
    master = 100,
    music = 0,
    sfx = 100,
    ambience = 0,
    dialog = 0,
}
local audioFocusSettings = {
    master = DEFAULT_AUDIO_FOCUS_SETTINGS.master,
    music = DEFAULT_AUDIO_FOCUS_SETTINGS.music,
    sfx = DEFAULT_AUDIO_FOCUS_SETTINGS.sfx,
    ambience = DEFAULT_AUDIO_FOCUS_SETTINGS.ambience,
    dialog = DEFAULT_AUDIO_FOCUS_SETTINGS.dialog,
}

SuppressNextDoubleRightMouseUp = function()
    doubleRightIgnoreVisualMouseUp = true
    C_Timer.After(0.08, function()
        doubleRightIgnoreVisualMouseUp = false
    end)
end

local function NormalizeKey(value)
    value = (value or ""):match("^%s*(.-)%s*$"):upper()
    value = value:gsub("%s+", "")
    if value == "" then
        return nil
    end
    return value
end

local function ClampPercent(value, fallback)
    value = tonumber(value)
    if not value then
        return fallback
    end
    return math.max(0, math.min(100, math.floor(value + 0.5)))
end

local function CopyAudioFocusSettings(source)
    source = source or {}
    return {
        master = ClampPercent(source.master, DEFAULT_AUDIO_FOCUS_SETTINGS.master),
        music = ClampPercent(source.music, DEFAULT_AUDIO_FOCUS_SETTINGS.music),
        sfx = ClampPercent(source.sfx, DEFAULT_AUDIO_FOCUS_SETTINGS.sfx),
        ambience = ClampPercent(source.ambience, DEFAULT_AUDIO_FOCUS_SETTINGS.ambience),
        dialog = ClampPercent(source.dialog, DEFAULT_AUDIO_FOCUS_SETTINGS.dialog),
    }
end

Helpers.PrefixDismountMacro = function(macroText)
    if not dismountWithKeyEnabled or not macroText or macroText == "" then
        return macroText
    end
    return "/dismount [mounted]\n" .. macroText
end

local function ReadPlayerWaterState()
    if AvidAngler.IsRuntimeDisabled and AvidAngler:IsRuntimeDisabled() then
        return false
    end
    if IsSubmerged and IsSubmerged() then
        return true
    end
    return IsSwimming and IsSwimming() and true or false
end

local function RefreshPlayerWaterState(queueUpdate)
    local nextInWater = ReadPlayerWaterState()
    if playerInWater ~= nextInWater then
        playerInWater = nextInWater
        lastWaterStateUpdate = GetTime and GetTime() or time()
        if queueUpdate then
            QueueFishingBindingUpdate()
        end
    else
        lastWaterStateUpdate = GetTime and GetTime() or time()
    end
end

local function QueuePlayerWaterRefresh()
    if pendingWaterRefresh then
        return
    end

    pendingWaterRefresh = true
    C_Timer.After(0.25, function()
        pendingWaterRefresh = false
        RefreshPlayerWaterState(true)
    end)
end

local function IsPlayerInWater()
    if AvidAngler.IsRuntimeDisabled and AvidAngler:IsRuntimeDisabled() then
        playerInWater = false
        return false
    end
    if ReadPlayerWaterState() then
        playerInWater = true
        lastWaterStateUpdate = GetTime and GetTime() or time()
        return true
    end
    if playerInWater and ((GetTime and GetTime() or time()) - lastWaterStateUpdate) <= 1.5 then
        return true
    end
    playerInWater = false
    return false
end

local function ApplyButtonSize()
    buttonSize = math.max(52, math.min(140, tonumber(buttonSize) or DEFAULT_BUTTON_SIZE))
    castButton:SetSize(buttonSize, buttonSize)
    optionsButton:ClearAllPoints()
    optionsButton:SetPoint("LEFT", castButton, "RIGHT", Theme.layout.gutter, 0)
    castCloseButton:ClearAllPoints()
    castCloseButton:SetPoint("TOPRIGHT", castButton, "TOPRIGHT", 10, 10)
end

local function ApplySavedPoint(frame, pointInfo, fallbackPoint, fallbackX, fallbackY)
    frame:ClearAllPoints()
    if pointInfo and pointInfo.point then
        frame:SetPoint(pointInfo.point, UIParent, pointInfo.relativePoint or pointInfo.point, pointInfo.x or 0, pointInfo.y or 0)
    else
        frame:SetPoint(fallbackPoint or "CENTER", UIParent, fallbackPoint or "CENTER", fallbackX or 0, fallbackY or 0)
    end
end

local function HideVisualForCombat()
    visualHover = false
    if castCloseButton then
        castCloseButton:Hide()
    end
    if actionHUDCloseButton then
        actionHUDCloseButton:Hide()
    end
    if actionHUD then
        actionHUD:Hide()
    end
    if buttonIcon then
        buttonIcon:Hide()
    end
    if label then
        label:Hide()
    end
    if castButton then
        castButton:SetAlpha(0)
    end
    GameTooltip:Hide()
end

RefreshFishingControls = function()
    if combatVisualHidden and InCombatLockdown() then
        HideVisualForCombat()
        return
    end

    ApplyButtonSize()
    local showControls = moduleEnabled and not controlsHidden and not combatVisualHidden and not contentVisualHidden
    local showButton = showControls and displayMode == DISPLAY_MODE_BUTTON
    local showHUD = showControls and displayMode == DISPLAY_MODE_HUD

    ApplySavedPoint(castButton, buttonPoint, "CENTER", 0, -220)
    ApplySavedPoint(actionHUD, hudPoint, "CENTER", 0, -160)
    castButton:SetShown(moduleEnabled and not contentVisualHidden)
    castButton:SetAlpha(showButton and 1 or 0)
    castButton:EnableMouse(showButton)
    label:SetShown(false)
    buttonIcon:SetShown(showButton)
    optionsButton:Hide()
    castCloseButton:SetShown(showButton and visualHover)
    actionHUD:SetShown(showHUD)
    actionHUDCloseButton:SetShown(showHUD and visualHover)

    local desaturated = sleeping and true or false
    actionIcon:SetDesaturated(desaturated)
    buttonIcon:SetDesaturated(desaturated)
    if not InCombatLockdown() and (desaturated or not showControls) then
        castButton:SetAttribute("macrotext", "")
    end
    if desaturated then
        activeAction = ResolveNextAction()
        SetActionHUD(activeAction)
        label:SetText(L["ACTION_SLEEPING"])
    else
        ApplyResolvedAction()
    end
end

local function GetCastingSettings()
    if not AvidAngler.DB then
        return nil
    end
    AvidAngler.DB.settings.casting = AvidAngler.DB.settings.casting or {}
    return AvidAngler.DB.settings.casting
end

local function NormalizeMacroText(value)
    local text = (value or ""):match("^%s*(.-)%s*$")
    text = text:sub(1, MAX_PRECAST_MACRO_LENGTH)
    if text ~= "" and text:sub(1, 1) ~= "/" then
        return nil
    end
    return text
end

local function GetActionSlotKind(index)
    return index <= ACTION_TOY_SLOT_COUNT and "toy" or "extra"
end

local function GetActionSlotDefaultLabel(index)
    if GetActionSlotKind(index) == "toy" then
        return L["ACTION_SLOT_TOY_LABEL"]:format(index)
    end
    return L["ACTION_SLOT_EXTRA_LABEL"]:format(index - ACTION_TOY_SLOT_COUNT)
end

local function BuildActionSlotMacro(slot)
    if not slot then
        return ""
    end
    if slot.kind == "toy" and slot.itemID and slot.name and slot.name ~= "" then
        return Helpers.PrefixDismountMacro("/cast " .. slot.name)
    end
    if slot.kind == "item" and slot.itemID then
        return Helpers.PrefixDismountMacro("/use item:" .. tostring(slot.itemID))
    end
    return Helpers.PrefixDismountMacro(NormalizeMacroText(slot.text or "") or "")
end

local function SetActionSlotPayload(slot, payload)
    slot.kind = payload.kind
    slot.itemID = tonumber(payload.itemID) or nil
    slot.name = payload.name or ""
    slot.icon = payload.icon
    slot.text = NormalizeMacroText(payload.text or BuildActionSlotMacro(slot)) or ""
end

local function EnsureActionSlots(settings)
    settings.actionSlots = settings.actionSlots or {}
    for index = 1, ACTION_SLOT_COUNT do
        local slot = settings.actionSlots[index] or {}
        local slotKind = GetActionSlotKind(index)
        slot.enabled = slot.enabled and true or false
        slot.kind = slot.kind or (slot.itemID and slotKind) or "macro"
        slot.itemID = tonumber(slot.itemID) or nil
        slot.name = slot.name or ""
        slot.icon = slot.icon
        slot.text = NormalizeMacroText(slot.text or "") or ""
        slot.delay = tonumber(slot.delay) or DEFAULT_ACTION_SLOT_DELAY
        slot.lastUsed = tonumber(slot.lastUsed) or 0
        settings.actionSlots[index] = slot
    end

    if settings.precastMacroText and settings.precastMacroText ~= "" and settings.actionSlots[1].text == "" then
        settings.actionSlots[1].text = NormalizeMacroText(settings.precastMacroText) or ""
        settings.actionSlots[1].enabled = settings.precastMacroEnabled and true or false
    end

    return settings.actionSlots
end

local function EnsurePickerSettings(settings)
    settings.pickers = settings.pickers or {}
    local oldLure = settings.pickers.lure
    local catalog = AvidAngler.Data and AvidAngler.Data.LureCatalog
    if oldLure and catalog and catalog:GetPickerKey(oldLure.itemID) == "ward" then
        if not settings.pickers.ward or not settings.pickers.ward.manualChoice then
            settings.pickers.ward = oldLure
        end
        settings.pickers.lure = {}
    end
    for _, key in ipairs(PICKER_KEYS) do
        local picker = settings.pickers[key] or {}
        picker.enabled = picker.enabled and true or false
        picker.source = picker.source or nil
        picker.itemID = tonumber(picker.itemID) or nil
        picker.manualChoice = picker.manualChoice and true or false
        picker.delay = tonumber(picker.delay) or DEFAULT_PICKER_DELAY
        picker.lastUsed = tonumber(picker.lastUsed) or 0
        settings.pickers[key] = picker
    end
    return settings.pickers
end

local function Lower(value)
    return tostring(value or ""):lower()
end

local function GetItemName(itemID, fallback)
    return AvidAngler:SafeCall(C_Item.GetItemNameByID, nil, itemID)
        or AvidAngler:SafeCall(C_Item.GetItemName, nil, itemID)
        or fallback
        or ("item:" .. tostring(itemID))
end

local function GetItemSpell(itemID)
    if not C_Item or type(C_Item.GetItemSpell) ~= "function" then
        return nil, nil
    end
    local ok, spellName, spellID = pcall(C_Item.GetItemSpell, itemID)
    if not ok then
        return nil, nil
    end
    return AvidAngler:SafeValue(spellName, nil), AvidAngler:SafeValue(spellID, nil)
end

local function GetToyInfo(itemID)
    if not C_ToyBox or type(C_ToyBox.GetToyInfo) ~= "function" then
        return nil, nil, nil
    end
    local ok, toyItemID, toyName, icon = pcall(C_ToyBox.GetToyInfo, itemID)
    if not ok then
        return nil, nil, nil
    end
    return AvidAngler:SafeValue(toyItemID, nil), AvidAngler:SafeValue(toyName, nil), AvidAngler:SafeValue(icon, nil)
end

local function GetCooldownRemaining(startTime, duration)
    startTime = AvidAngler:SafeNumber(startTime, 0) or 0
    duration = AvidAngler:SafeNumber(duration, 0) or 0
    if startTime <= 0 or duration <= 0 then
        return 0
    end
    return math.max(0, math.ceil((startTime + duration) - GetTime()))
end

local function GetItemCooldownRemaining(itemID)
    local itemRemaining = 0
    if C_Item and type(C_Item.GetItemCooldown) == "function" then
        local ok, startTime, duration = pcall(C_Item.GetItemCooldown, itemID)
        if ok then
            itemRemaining = GetCooldownRemaining(startTime, duration)
        end
    end

    if not C_Container or type(C_Container.GetItemCooldown) ~= "function" then
        return itemRemaining
    end
    local ok, startTime, duration = pcall(C_Container.GetItemCooldown, itemID)
    if not ok then
        return itemRemaining
    end
    return math.max(itemRemaining, GetCooldownRemaining(startTime, duration))
end

local function GetSpellCooldownRemaining(spellID)
    if not spellID then
        return 0
    end

    if C_Spell and type(C_Spell.GetSpellCooldown) == "function" then
        local ok, cooldownInfo = pcall(C_Spell.GetSpellCooldown, spellID)
        if ok and type(cooldownInfo) == "table" then
            return GetCooldownRemaining(cooldownInfo.startTime, cooldownInfo.duration)
        end
    end

    if type(GetSpellCooldown) == "function" then
        local ok, startTime, duration = pcall(GetSpellCooldown, spellID)
        if ok then
            return GetCooldownRemaining(startTime, duration)
        end
    end
    return 0
end

local function GetToyCooldownRemaining(itemID)
    if C_ToyBox and type(C_ToyBox.GetToyCooldown) == "function" then
        local ok, startTime, duration = pcall(C_ToyBox.GetToyCooldown, itemID)
        if ok then
            if type(startTime) == "table" then
                return GetCooldownRemaining(startTime.startTime, startTime.duration)
            end
            return GetCooldownRemaining(startTime, duration)
        end
    end
    return 0
end

local function GetLureCatalogEntry(itemID)
    local catalog = AvidAngler.Data and AvidAngler.Data.LureCatalog
    return catalog and catalog:Get(itemID) or nil
end

local function HasSavedFishingSkill(expansionKey)
    if type(expansionKey) ~= "string" or not AvidAngler.DataLayer or not AvidAngler.DataLayer.GetCharacterFishingSkillSnapshot then
        return false
    end

    local snapshot = AvidAngler.DataLayer:GetCharacterFishingSkillSnapshot()
    local expansions = type(snapshot) == "table" and snapshot.expansions or nil
    return expansions and expansions[expansionKey] == true or false
end

local function GetChoiceCooldownRemaining(choice)
    if not choice then
        return 0
    end

    local remaining = GetItemCooldownRemaining(choice.itemID)
    if choice.source == "toybox" then
        remaining = math.max(remaining, GetToyCooldownRemaining(choice.itemID), GetSpellCooldownRemaining(choice.spellID))
    end
    return remaining
end

local function CheckChoiceCriteria(choice)
    if not choice or choice.source ~= "toybox" then
        return true
    end

    local hasRequiredFishingSkill = choice.requiredFishingSkill and HasSavedFishingSkill(choice.requiredFishingSkill)
    if C_ToyBox and type(C_ToyBox.IsToyUsable) == "function" then
        local usable = AvidAngler:SafeCall(C_ToyBox.IsToyUsable, nil, choice.itemID)
        if usable == false and not hasRequiredFishingSkill then
            return false
        end
    end

    if C_PlayerInfo and type(C_PlayerInfo.CanUseItem) == "function" then
        local usable = AvidAngler:SafeCall(C_PlayerInfo.CanUseItem, nil, choice.itemID)
        if usable == false and not hasRequiredFishingSkill then
            return false
        end
    end

    return true
end

local function AddChoice(key, source, itemID, name, icon, spellID, options)
    if not key or not itemID then
        return
    end

    actionChoices[key] = actionChoices[key] or {}
    for _, choice in ipairs(actionChoices[key]) do
        if choice.source == source and choice.itemID == itemID then
            return
        end
    end

    actionChoices[key][#actionChoices[key] + 1] = {
        key = key,
        source = source,
        itemID = itemID,
        spellID = spellID,
        name = name or ("item:" .. itemID),
        icon = icon or "Interface\\Icons\\INV_Misc_QuestionMark",
        random = options and options.random or false,
        waterOnly = options and options.waterOnly or false,
        auraManaged = options and options.auraManaged or false,
        buffSpellIDs = options and options.buffSpellIDs or nil,
        poleEnhancement = options and options.poleEnhancement or false,
        requiredFishingSkill = options and options.requiredFishingSkill or nil,
    }
end

local function CategorizeBagItem(itemID, name, spellName)
    if EXCLUDED_LURE_ITEM_IDS[itemID] then
        return nil
    end

    if GetLureCatalogEntry(itemID) then
        return AvidAngler.Data.LureCatalog:GetPickerKey(itemID)
    end

    -- Unknown items need a readable class before name-based discovery. A
    -- recipe can be usable and mention a lure without being that lure.
    local itemClass
    if C_Item and type(C_Item.GetItemInfoInstant) == "function" then
        local ok, _, _, _, _, _, classID = pcall(C_Item.GetItemInfoInstant, itemID)
        if ok then
            itemClass = AvidAngler:SafeNumber(classID, nil)
        end
    end
    local recipeClass = Enum and Enum.ItemClass and Enum.ItemClass.Recipe or 9
    if not itemClass or itemClass == recipeClass then
        return nil
    end

    local itemText = Lower(name)
    local spellText = Lower(spellName)
    if itemText:find("bobber", 1, true) or spellText:find("bobber", 1, true) then
        return "bobber"
    end
    if itemText:find("lure", 1, true)
        or itemText:find("bait", 1, true)
        or spellText:find("fishing", 1, true)
        or spellText:find("lure", 1, true)
        or spellText:find("bait", 1, true) then
        return "lure"
    end
end

local function ScanBagChoices()
    if not C_Container then
        return
    end

    for bag = 0, NUM_BAG_SLOTS do
        local slots = AvidAngler:SafeCall(C_Container.GetContainerNumSlots, 0, bag) or 0
        for slot = 1, slots do
            local info = AvidAngler:SafeCall(C_Container.GetContainerItemInfo, nil, bag, slot)
            local itemID = info and info.itemID
            if itemID then
                local spellName, spellID = GetItemSpell(itemID)
                local usable = AvidAngler:SafeCall(C_Item.IsUsableItem, false, itemID)
                local name = (info.hyperlink and AvidAngler:SafeCall(C_Item.GetItemInfo, nil, info.hyperlink)) or GetItemName(itemID)
                local key = usable and CategorizeBagItem(itemID, name, spellName)
                if key then
                    local lureEntry = (key == "lure" or key == "ward") and GetLureCatalogEntry(itemID) or nil
                    AddChoice(key, "bag", itemID, name, info.iconFileID, spellID, {
                        auraManaged = lureEntry and lureEntry.auraManaged or false,
                        buffSpellIDs = lureEntry and lureEntry.buffSpellIDs or nil,
                        poleEnhancement = lureEntry and lureEntry.poleEnhancement or false,
                    })
                end
            end
        end
    end
end

local function ScanToyChoices()
    for _, toy in ipairs(FISHING_TOYS) do
        if PlayerHasToy and PlayerHasToy(toy.itemID) then
            local itemID, toyName, icon = GetToyInfo(toy.itemID)
            local choice = {
                source = "toybox",
                itemID = itemID or toy.itemID,
                requiredFishingSkill = toy.requiredFishingSkill,
            }
            if CheckChoiceCriteria(choice) then
                AddChoice(toy.key, "toybox", choice.itemID, toyName or GetItemName(toy.itemID, toy.name), icon or toy.icon, toy.spellID, {
                    auraManaged = toy.auraManaged,
                    waterOnly = toy.waterOnly,
                    requiredFishingSkill = toy.requiredFishingSkill,
                })
            end
        end
    end
end

local function AddRandomChoice(key)
    AddChoice(key, "random", RANDOM_ITEM_ID, L["ACTION_PICKER_RANDOM"], "Interface\\Icons\\INV_Misc_Dice_01", nil, {
        random = true,
    })
end

local function FindChoice(key, source, itemID)
    if not source or not itemID then
        return nil
    end
    for index, choice in ipairs(actionChoices[key] or {}) do
        if choice.source == source and choice.itemID == itemID then
            return choice, index
        end
    end
end

local function SelectFirstChoiceIfNeeded(key)
    local picker = pickerSettings[key]
    if not picker then
        return
    end
    local choice = FindChoice(key, picker.source, picker.itemID)
    if (key == "lure" or key == "ward") then
        if not picker.manualChoice or not choice then
            picker.source = nil
            picker.itemID = nil
            picker.manualChoice = false
        end
    elseif not choice and actionChoices[key] and actionChoices[key][1] then
        picker.source = actionChoices[key][1].source
        picker.itemID = actionChoices[key][1].itemID
    end
end

local function RefreshActionChoices()
    actionChoices = { lure = {}, ward = {}, oversized = {}, bobber = {}, toy = {} }
    pendingRandomChoices = {}
    ScanBagChoices()
    ScanToyChoices()
    if #(actionChoices.bobber or {}) > 1 then
        AddRandomChoice("bobber")
    end
    if #(actionChoices.toy or {}) > 1 then
        AddRandomChoice("toy")
    end
    for _, key in ipairs(PICKER_KEYS) do
        table.sort(actionChoices[key], function(a, b)
            if a.random ~= b.random then
                return a.random
            end
            if a.source ~= b.source then
                return a.source < b.source
            end
            return a.name < b.name
        end)
        SelectFirstChoiceIfNeeded(key)
    end
end

local function GetPickerRemaining(picker)
    if not picker or not picker.lastUsed or picker.lastUsed <= 0 then
        return 0
    end
    return math.max(0, (picker.lastUsed + (tonumber(picker.delay) or DEFAULT_PICKER_DELAY)) - time())
end

local function HasPlayerAura(spellID)
    if not spellID or not C_UnitAuras or type(C_UnitAuras.GetPlayerAuraBySpellID) ~= "function" then
        return false
    end
    return AvidAngler:SafeCall(C_UnitAuras.GetPlayerAuraBySpellID, nil, spellID) ~= nil
end

local function HasAnyPlayerAura(spellIDs)
    if type(spellIDs) ~= "table" then
        return false
    end
    for _, spellID in ipairs(spellIDs) do
        if HasPlayerAura(spellID) then
            return true
        end
    end
    return false
end

local function HasMainHandTemporaryEnhancement()
    if type(GetWeaponEnchantInfo) ~= "function" then
        return false
    end
    local ok, hasMainHandEnchant = pcall(GetWeaponEnchantInfo)
    return ok and hasMainHandEnchant and true or false
end

local function ReadAuraByIndex(index)
    if C_UnitAuras and type(C_UnitAuras.GetAuraDataByIndex) == "function" then
        local aura = AvidAngler:SafeCall(C_UnitAuras.GetAuraDataByIndex, nil, "player", index, "HELPFUL")
        if aura then
            return aura
        end
    end
    if C_UnitAuras and type(C_UnitAuras.GetBuffDataByIndex) == "function" then
        local aura = AvidAngler:SafeCall(C_UnitAuras.GetBuffDataByIndex, nil, "player", index)
        if aura then
            return aura
        end
    end
    if type(UnitAura) == "function" then
        local ok, name, icon, count, debuffType, duration, expirationTime, source, isStealable, nameplateShowPersonal, spellID =
            pcall(UnitAura, "player", index, "HELPFUL")
        if ok and name then
            return {
                name = AvidAngler:SafeString(name, nil),
                spellID = AvidAngler:SafeNumber(spellID, nil),
            }
        end
    end
end

local function GetKnownPickerAuraActive(key)
    local catalog = AvidAngler.Data and AvidAngler.Data.LureCatalog
    if not catalog then
        return false
    end

    for index = 1, 40 do
        local aura = ReadAuraByIndex(index)
        if not aura then
            break
        end

        local auraName = AvidAngler:SafeString(aura.name, nil)
        local auraSpellID = AvidAngler:SafeNumber(aura.spellId or aura.spellID, nil)
        if catalog:IsPickerBuff(key, auraSpellID, auraName) then
            return true, auraName
        end
    end
    return false
end

local function HasKnownPickerAuraActive(key)
    local active = GetKnownPickerAuraActive(key)
    return active and true or false
end

local IsAnyChoiceAuraActive

local function IsKnownBobberAuraActive()
    if IsAnyChoiceAuraActive and IsAnyChoiceAuraActive("bobber", true) then
        return true
    end
    for index = 1, 40 do
        local aura = ReadAuraByIndex(index)
        if not aura then
            break
        end

        local auraSpellID = AvidAngler:SafeNumber(aura.spellId or aura.spellID, nil)
        if auraSpellID and BOBBER_AURA_SPELL_IDS[auraSpellID] and auraSpellID ~= OVERSIZED_BOBBER_SPELL_ID then
            return true
        end

        local auraName = Lower(AvidAngler:SafeString(aura.name, nil))
        if auraName:find("bobber", 1, true) and not auraName:find("oversized", 1, true) then
            return true
        end
    end
    return false
end

local function IsChoiceAuraActive(choice)
    if not choice or not choice.auraManaged then
        return false
    end
    if (choice.key == "lure" or choice.key == "ward") then
        return HasKnownPickerAuraActive(choice.key)
            or HasAnyPlayerAura(choice.buffSpellIDs)
            or (choice.poleEnhancement and HasMainHandTemporaryEnhancement())
    end
    if choice.key == "bobber" and IsKnownBobberAuraActive() then
        return true
    end
    if choice.key == "toy" and choice.waterOnly and IsAnyChoiceAuraActive and IsAnyChoiceAuraActive("toy", true) then
        return true
    end
    return HasPlayerAura(choice.spellID)
end

IsAnyChoiceAuraActive = function(key, exactOnly)
    for _, choice in ipairs(actionChoices[key] or {}) do
        if choice.auraManaged and HasPlayerAura(choice.spellID) then
            return true
        end
    end
    if key == "bobber" and not exactOnly then
        return IsKnownBobberAuraActive()
    end
    return false
end

local function IsPickerDelayed(picker, choice, key)
    if choice and choice.auraManaged and not IsChoiceAuraActive(choice) then
        return false
    end
    if choice and choice.random and (key == "bobber" or key == "oversized") and not IsAnyChoiceAuraActive(key) then
        return false
    end
    return GetPickerRemaining(picker) > 0
end

local function GetChoiceMacro(choice)
    if not choice then
        return nil
    end
    if choice.source == "toybox" then
        return Helpers.PrefixDismountMacro("/cast " .. choice.name)
    end
    return Helpers.PrefixDismountMacro("/use item:" .. tostring(choice.itemID))
end

local function IsChoiceUsable(choice)
    if not choice or choice.random then
        return false
    end
    if choice.waterOnly and not IsPlayerInWater() then
        return false
    end
    if IsChoiceAuraActive(choice) then
        return false
    end
    if not CheckChoiceCriteria(choice) then
        return false
    end
    return GetChoiceCooldownRemaining(choice) == 0
end

local function GetPickerStatusText(statusKey, remaining)
    if statusKey == "cooldown" then
        return L["ACTION_PICKER_STATUS_COOLDOWN"]:format(math.max(1, math.ceil(remaining or 0)))
    end
    return L["ACTION_PICKER_STATUS_" .. string.upper(statusKey or "blocked")] or L["ACTION_PICKER_STATUS_BLOCKED"]
end

local function GetRandomChoiceStatus(key, picker)
    if key == "bobber" and IsAnyChoiceAuraActive(key) then
        return "active", 0
    end
    if key == "toy" and IsAnyChoiceAuraActive(key) then
        return "active", 0
    end

    local realChoices = 0
    local sawWaterOnly = false
    local sawCriteriaBlocked = false
    local shortestCooldown
    for _, choice in ipairs(actionChoices[key] or {}) do
        if not choice.random then
            realChoices = realChoices + 1
            if IsChoiceUsable(choice) then
                return "ready", 0
            end
            if choice.waterOnly and not IsPlayerInWater() then
                sawWaterOnly = true
            elseif not CheckChoiceCriteria(choice) then
                sawCriteriaBlocked = true
            elseif not IsChoiceAuraActive(choice) then
                local remaining = GetChoiceCooldownRemaining(choice)
                if remaining > 0 and (not shortestCooldown or remaining < shortestCooldown) then
                    shortestCooldown = remaining
                end
            end
        end
    end

    local pickerRemaining = GetPickerRemaining(picker)
    if pickerRemaining > 0 and not (key == "bobber" and not IsAnyChoiceAuraActive(key)) then
        shortestCooldown = shortestCooldown and math.max(shortestCooldown, pickerRemaining) or pickerRemaining
    end

    if realChoices == 0 then
        return "empty", 0
    end
    if shortestCooldown then
        return "cooldown", shortestCooldown
    end
    if sawWaterOnly then
        return "water", 0
    end
    if sawCriteriaBlocked then
        return "criteria", 0
    end
    return "blocked", 0
end

local function GetFixedChoiceStatus(key, picker, choice)
    if not choice then
        return "empty", 0
    end
    if IsChoiceAuraActive(choice) then
        return "active", 0
    end
    if choice.waterOnly and not IsPlayerInWater() then
        return "water", 0
    end
    if not CheckChoiceCriteria(choice) then
        return "criteria", 0
    end

    local itemRemaining = GetChoiceCooldownRemaining(choice)
    if itemRemaining > 0 then
        return "cooldown", itemRemaining
    end

    if IsPickerDelayed(picker, choice, key) then
        return "cooldown", GetPickerRemaining(picker)
    end
    return "ready", 0
end

local function PickRandomChoice(key)
    local pending = pendingRandomChoices[key]
    if pending and IsChoiceUsable(pending) then
        return pending
    end

    local candidates = {}
    for _, choice in ipairs(actionChoices[key] or {}) do
        if IsChoiceUsable(choice) then
            candidates[#candidates + 1] = choice
        end
    end
    if #candidates == 0 then
        pendingRandomChoices[key] = nil
        return nil
    end
    pendingRandomChoices[key] = candidates[math.random(#candidates)]
    return pendingRandomChoices[key]
end

local function CountRealChoices(key)
    local count = 0
    for _, choice in ipairs(actionChoices[key] or {}) do
        if not choice.random then
            count = count + 1
        end
    end
    return count
end

local function HasWaterOnlyToyConfigured()
    local picker = pickerSettings.toy
    if not picker or not picker.enabled then
        return false
    end

    local choice = FindChoice("toy", picker.source, picker.itemID)
    if choice and choice.random then
        for _, toyChoice in ipairs(actionChoices.toy or {}) do
            if not toyChoice.random and toyChoice.waterOnly then
                return true
            end
        end
        return false
    end
    return choice and choice.waterOnly or false
end

local function GetPickerOrder()
    if IsPlayerInWater() then
        return WATER_PICKER_KEYS
    end
    return PICKER_KEYS
end

local function FindReadyPickerAction()
    for _, key in ipairs(GetPickerOrder()) do
        local picker = pickerSettings[key]
        local choice = picker and FindChoice(key, picker.source, picker.itemID)
        if (key == "lure" or key == "ward") and picker and not picker.manualChoice then
            choice = nil
        end
        if picker and picker.enabled and choice and not IsPickerDelayed(picker, choice, key) then
            if choice.random then
                choice = PickRandomChoice(key)
            end
            if IsChoiceUsable(choice) then
                return key, picker, choice
            end
        end
    end
end

PersistOneKeySettings = function()
    local settings = GetCastingSettings()
    if not settings then
        return
    end
    settings.oneKeyEnabled = oneKeyEnabled
    settings.oneKey = oneKey
    settings.doubleRightEnabled = doubleRightEnabled
    settings.inputMode = inputMode
    settings.autoLootEnabled = autoLootEnabled
    settings.audioFocusEnabled = audioFocusEnabled
    settings.gearEquipEnabled = Helpers.gearEquipEnabled
    settings.dismountWithKeyEnabled = dismountWithKeyEnabled
    settings.releaseWhenSwimmingEnabled = releaseWhenSwimmingEnabled
    settings.disableSoftInteractEnabled = disableSoftInteractEnabled
    settings.disableSoftIconEnabled = disableSoftIconEnabled
    settings.audioFocusSettings = CopyAudioFocusSettings(audioFocusSettings)
    settings.displayMode = displayMode
    settings.wakeDisplayMode = wakeDisplayMode
    settings.controlsHidden = controlsHidden
    settings.sleeping = sleeping
    settings.buttonSize = buttonSize
    settings.buttonSizeDefaultVersion = BUTTON_SIZE_DEFAULT_VERSION
    settings.buttonPoint = buttonPoint
    settings.hudPoint = hudPoint
    settings.precastMacroEnabled = precastMacroEnabled
    settings.precastMacroText = precastMacroText
    settings.actionSlots = settings.actionSlots or {}
    for index = 1, ACTION_SLOT_COUNT do
        local slot = actionSlots[index] or {}
        settings.actionSlots[index] = {
            enabled = slot.enabled and true or false,
            kind = slot.kind,
            itemID = slot.itemID,
            name = slot.name,
            icon = slot.icon,
            text = slot.text or "",
            delay = tonumber(slot.delay) or DEFAULT_ACTION_SLOT_DELAY,
            lastUsed = tonumber(slot.lastUsed) or 0,
        }
    end
    settings.pickers = settings.pickers or {}
    for _, key in ipairs(PICKER_KEYS) do
        local picker = pickerSettings[key] or {}
        settings.pickers[key] = {
            enabled = picker.enabled and true or false,
            source = picker.source,
            itemID = picker.itemID,
            manualChoice = picker.manualChoice and true or false,
            delay = tonumber(picker.delay) or DEFAULT_PICKER_DELAY,
            lastUsed = tonumber(picker.lastUsed) or 0,
        }
    end
end

local function ClearFishingBindings()
    if InCombatLockdown() then
        return
    end
    ClearOverrideBindings(bindingFrame)
end

local function GetSlotRemaining(slot)
    if not slot or not slot.lastUsed or slot.lastUsed <= 0 then
        return 0
    end
    return math.max(0, (slot.lastUsed + (tonumber(slot.delay) or DEFAULT_ACTION_SLOT_DELAY)) - time())
end

local function FindReadyActionSlot()
    for index = 1, ACTION_SLOT_COUNT do
        local slot = actionSlots[index]
        if slot and slot.enabled and BuildActionSlotMacro(slot) ~= "" and GetSlotRemaining(slot) <= 0 then
            return index, slot
        end
    end
end

SetActionHUD = function(action)
    if not action then
        return
    end
    actionTitle:SetText(action.label)
    actionDetail:SetText(action.detail or "")
    actionIcon:SetTexture(action.icon or "Interface\\Icons\\UI_Profession_Fishing")
    actionIcon:SetDesaturated(action.reason == "sleeping")
    buttonIcon:SetTexture(action.icon or "Interface\\Icons\\UI_Profession_Fishing")
    buttonIcon:SetDesaturated(action.reason == "sleeping")
    actionHUD:SetBackdropBorderColor(unpack(action.borderColor or Theme.color.accentDim))
    label:SetText(action.buttonLabel or L["CAST_BUTTON_LABEL"])
end

ResolveNextAction = function()
    if AvidAngler.IsRuntimeDisabled and AvidAngler:IsRuntimeDisabled() then
        return {
            kind = "clear",
            reason = "protected",
            label = L["ACTION_PROTECTED_CONTENT"],
            detail = L["ACTION_DETAIL_PROTECTED_CONTENT"],
            icon = "Interface\\Icons\\Ability_Warrior_ShieldWall",
            borderColor = Theme.color.warning,
        }
    end

    if sleeping then
        return {
            kind = "clear",
            reason = "sleeping",
            label = L["ACTION_SLEEPING"],
            detail = L["ACTION_DETAIL_SLEEPING"],
            icon = "Interface\\Icons\\UI_Profession_Fishing",
            borderColor = Theme.color.border,
        }
    end

    if InCombatLockdown() then
        return {
            kind = "clear",
            label = L["ACTION_COMBAT"],
            detail = L["ACTION_DETAIL_COMBAT"],
            icon = "Interface\\Icons\\Ability_Warrior_ShieldWall",
            borderColor = Theme.color.warning,
        }
    end

    if UnitIsDeadOrGhost("player") then
        return {
            kind = "clear",
            label = L["ACTION_DEAD"],
            detail = L["ACTION_DETAIL_DEAD"],
            icon = "Interface\\Icons\\Spell_Shadow_SoulGem",
            borderColor = Theme.color.danger,
        }
    end

    if isFishing then
        return {
            kind = "reel",
            label = L["ACTION_REEL"],
            detail = L["ACTION_DETAIL_REEL"],
            icon = "Interface\\Icons\\misc_arrowlup",
            borderColor = Theme.color.accent,
        }
    end

    local pickerKey, picker, choice = FindReadyPickerAction()
    if choice then
        return {
            kind = "picker",
            pickerKey = pickerKey,
            choice = choice,
            macroText = GetChoiceMacro(choice),
            label = L["ACTION_PICKER_" .. pickerKey:upper()],
            detail = choice.name,
            icon = choice.icon,
            buttonLabel = L["ACTION_PICKER_BUTTON_" .. pickerKey:upper()],
            borderColor = Theme.color.warning,
        }
    end

    if IsPlayerInWater() and HasWaterOnlyToyConfigured() then
        return {
            kind = "clear",
            reason = "water",
            label = L["ACTION_WATER"],
            detail = L["ACTION_DETAIL_WATER"],
            icon = "Interface\\Icons\\UI_Profession_Fishing",
            borderColor = Theme.color.border,
        }
    end

    local slotIndex, slot = FindReadyActionSlot()
    if slot then
        local slotMacro = BuildActionSlotMacro(slot)
        return {
            kind = "slot",
            slotIndex = slotIndex,
            macroText = slotMacro,
            label = GetActionSlotDefaultLabel(slotIndex),
            detail = slot.name ~= "" and slot.name or slotMacro,
            icon = slot.icon or "Interface\\Icons\\INV_Misc_Gear_01",
            buttonLabel = L["ACTION_SLOT_BUTTON"]:format(slotIndex),
            borderColor = Theme.color.warning,
        }
    end

    local macroText = BuildFishingMacro()
    if not macroText then
        return {
            kind = "clear",
            reason = "spellLoading",
            label = L["ACTION_LOADING"],
            detail = L["ACTION_DETAIL_SPELL_LOADING"],
            icon = "Interface\\Icons\\UI_Profession_Fishing",
            borderColor = Theme.color.warning,
        }
    end
    return {
        kind = "cast",
        macroText = macroText,
        label = L["ACTION_CAST"],
        detail = Helpers.gearEquipEnabled and GetGearSetID and GetGearSetID() and L["ACTION_DETAIL_CAST_GEAR"] or L["ACTION_DETAIL_CAST"],
        icon = "Interface\\Icons\\UI_Profession_Fishing",
        buttonLabel = L["CAST_BUTTON_LABEL"],
        borderColor = Theme.color.accentDim,
    }
end

ApplyResolvedAction = function()
    if InCombatLockdown() or (AvidAngler.IsRuntimeDisabled and AvidAngler:IsRuntimeDisabled()) then
        activeAction = ResolveNextAction()
        SetActionHUD(activeAction)
        return false
    end

    activeAction = ResolveNextAction()
    SetActionHUD(activeAction)
    if activeAction.reason == "spellLoading" then
        return false
    end
    if activeAction.macroText then
        castButton:SetAttribute("macrotext", activeAction.macroText)
    end
    return true
end

local function SetFishingActionBinding(key, mouseButton)
    if not key then
        return
    end

    if activeAction and activeAction.kind == "reel" then
        SetOverrideBinding(bindingFrame, true, key, "INTERACTTARGET")
    else
        SetOverrideBindingClick(bindingFrame, true, key, "AvidAnglerCastButton", mouseButton or "LeftButton")
    end
end

local function ApplyFishingBindings()
    pendingBindingUpdate = false

    if InCombatLockdown() then
        pendingBindingUpdate = true
        return
    end
    if AvidAngler.IsRuntimeDisabled and AvidAngler:IsRuntimeDisabled() then
        ClearOverrideBindings(bindingFrame)
        return
    end

    ClearOverrideBindings(bindingFrame)
    if not moduleEnabled or sleeping then
        return
    end
    if UnitIsDeadOrGhost("player") then
        return
    end

    ApplyResolvedAction()
    if activeAction and activeAction.kind == "clear" then
        return
    end
    if releaseWhenSwimmingEnabled and IsPlayerInWater() and not (activeAction and activeAction.choice and activeAction.choice.waterOnly) then
        return
    end

    if inputMode == INPUT_MODE_ONE_KEY and oneKeyEnabled and not IsKeyDown(oneKey) then
        SetFishingActionBinding(oneKey, "LeftButton")
    end

    if inputMode == INPUT_MODE_DOUBLE_RIGHT and doubleRightEnabled and doubleRightWatching then
        SetFishingActionBinding("BUTTON2", "RightButton")
    end
end

QueueFishingBindingUpdate = function()
    if InCombatLockdown() then
        pendingBindingUpdate = true
        return
    end
    ApplyFishingBindings()
end

local function IsFishingSpell(spellID)
    if spellID == FISHING_SPELL_ID then
        return true
    end

    local name = spellID and AvidAngler:SafeCall(C_Spell.GetSpellName, nil, spellID)
    return name and fishingSpellName and name == fishingSpellName
end

local function LoadOneKeySettings()
    local settings = GetCastingSettings()
    if not settings then
        return
    end
    oneKeyEnabled = settings.oneKeyEnabled and true or false
    oneKey = NormalizeKey(settings.oneKey) or DEFAULT_ONE_KEY
    doubleRightEnabled = settings.doubleRightEnabled and true or false
    inputMode = settings.inputMode or (doubleRightEnabled and INPUT_MODE_DOUBLE_RIGHT) or (oneKeyEnabled and INPUT_MODE_ONE_KEY) or INPUT_MODE_OFF
    if inputMode == INPUT_MODE_ONE_KEY then
        oneKeyEnabled = true
        doubleRightEnabled = false
    elseif inputMode == INPUT_MODE_DOUBLE_RIGHT then
        oneKeyEnabled = false
        doubleRightEnabled = true
    else
        oneKeyEnabled = false
        doubleRightEnabled = false
        inputMode = INPUT_MODE_OFF
    end
    autoLootEnabled = settings.autoLootEnabled and true or false
    audioFocusEnabled = settings.audioFocusEnabled and true or false
    Helpers.gearEquipEnabled = settings.gearEquipEnabled and true or false
    dismountWithKeyEnabled = settings.dismountWithKeyEnabled and true or false
    releaseWhenSwimmingEnabled = settings.releaseWhenSwimmingEnabled ~= false
    disableSoftInteractEnabled = settings.disableSoftInteractEnabled and true or false
    disableSoftIconEnabled = settings.disableSoftIconEnabled and true or false
    audioFocusSettings = CopyAudioFocusSettings(settings.audioFocusSettings)
    displayMode = settings.displayMode == DISPLAY_MODE_BUTTON and DISPLAY_MODE_BUTTON or DISPLAY_MODE_HUD
    wakeDisplayMode = settings.wakeDisplayMode == DISPLAY_MODE_BUTTON and DISPLAY_MODE_BUTTON or DISPLAY_MODE_HUD
    controlsHidden = settings.controlsHidden and true or false
    sleeping = settings.sleeping and true or false
    if sleeping then
        displayMode = DISPLAY_MODE_BUTTON
    else
        wakeDisplayMode = displayMode
    end
    local savedButtonSize = tonumber(settings.buttonSize)
    if settings.buttonSizeDefaultVersion ~= BUTTON_SIZE_DEFAULT_VERSION and (not savedButtonSize or savedButtonSize == 72) then
        savedButtonSize = DEFAULT_BUTTON_SIZE
    end
    buttonSize = savedButtonSize or DEFAULT_BUTTON_SIZE
    buttonPoint = settings.buttonPoint
    hudPoint = settings.hudPoint
    if autoLootEnabled then
        ApplyTempCVar("autoLootDefault", "1")
    end
    if disableSoftIconEnabled then
        Helpers.ApplySoftIconSetting()
    end
    precastMacroEnabled = settings.precastMacroEnabled and true or false
    precastMacroText = (settings.precastMacroText or ""):sub(1, MAX_PRECAST_MACRO_LENGTH)
    actionSlots = EnsureActionSlots(settings)
    pickerSettings = EnsurePickerSettings(settings)
    RefreshActionChoices()
    ApplyResolvedAction()
    RefreshFishingControls()
    QueueFishingBindingUpdate()
end

function Casting:IsOneKeyEnabled()
    return oneKeyEnabled
end

function Casting:GetInputMode()
    return inputMode
end

function Casting:GetOneKey()
    return oneKey
end

function Casting:IsFishing()
    return isFishing
end

function Casting:GetStatus()
    if InCombatLockdown() then
        return L["MAIN_STATUS_COMBAT"]
    elseif UnitIsDeadOrGhost("player") then
        return L["MAIN_STATUS_DEAD"]
    elseif isFishing then
        return L["MAIN_STATUS_FISHING"]
    end
    return L["MAIN_STATUS_READY"]
end

function Casting:ShowVisualTooltip(owner)
    if not owner then
        return
    end

    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:SetText(L["ACTION_VISUAL_TOOLTIP_TITLE"])
    if activeAction then
        GameTooltip:AddLine(activeAction.label or "", 1, 1, 1)
        if activeAction.detail and activeAction.detail ~= "" then
            GameTooltip:AddLine(activeAction.detail, 0.8, 0.8, 0.8, true)
        end
    end

    if not sleeping then
        GameTooltip:AddLine(L["ACTION_VISUAL_TOOLTIP_AWAKE"], 0.8, 0.8, 0.8, true)
    end

    GameTooltip:AddLine(L["ACTION_VISUAL_TOOLTIP_SLEEP"], 0.9, 0.82, 0.2, true)
    GameTooltip:AddLine(L["ACTION_VISUAL_TOOLTIP_CLOSE"], 0.8, 0.8, 0.8, true)
    GameTooltip:Show()
end

function Casting:SetOneKeyEnabled(enabled)
    oneKeyEnabled = enabled and true or false
    if oneKeyEnabled then
        inputMode = INPUT_MODE_ONE_KEY
        doubleRightEnabled = false
        doubleRightWatching = false
    elseif inputMode == INPUT_MODE_ONE_KEY then
        inputMode = INPUT_MODE_OFF
    end
    PersistOneKeySettings()
    QueueFishingBindingUpdate()
    if InCombatLockdown() then
        AvidAngler:Print(AvidAngler.L["ONE_KEY_COMBAT"])
    end
    AvidAngler:Print((oneKeyEnabled and AvidAngler.L["ONE_KEY_ENABLED"] or AvidAngler.L["ONE_KEY_DISABLED"]):format(oneKey))
end

function Casting:SetOneKey(key)
    local normalized = NormalizeKey(key)
    if not normalized then
        AvidAngler:Print(AvidAngler.L["ONE_KEY_USAGE"])
        return
    end
    oneKey = normalized
    PersistOneKeySettings()
    QueueFishingBindingUpdate()
    if InCombatLockdown() then
        AvidAngler:Print(AvidAngler.L["ONE_KEY_COMBAT"])
    end
    AvidAngler:Print(AvidAngler.L["ONE_KEY_KEY_SET"]:format(oneKey))
end

function Casting:IsDoubleRightEnabled()
    return doubleRightEnabled
end

function Casting:SetInputMode(mode)
    if mode == INPUT_MODE_ONE_KEY then
        self:SetOneKeyEnabled(true)
    elseif mode == INPUT_MODE_DOUBLE_RIGHT then
        self:SetDoubleRightEnabled(true)
    else
        oneKeyEnabled = false
        doubleRightEnabled = false
        inputMode = INPUT_MODE_OFF
        doubleRightWatching = false
        doubleRightHeld = false
        doubleRightIgnoreNextMouseUp = false
        PersistOneKeySettings()
        QueueFishingBindingUpdate()
        AvidAngler:Print(L["ACTION_INPUT_OFF"])
    end
end

function Casting:GetDisplayMode()
    return displayMode
end

function Casting:GetButtonSize()
    return buttonSize
end

function Casting:AreControlsHidden()
    return controlsHidden
end

function Casting:IsSleeping()
    return sleeping
end

function Casting:IsAutoLootEnabled()
    return autoLootEnabled
end

function Casting:IsAutoLootEnabledExternally()
    return Helpers.IsGameAutoLootEnabled() and not autoLootEnabled and cachedCVars["autoLootDefault"] == nil
end

function Casting:IsAudioFocusEnabled()
    return audioFocusEnabled
end

function Casting:IsGearEquipEnabled()
    return Helpers.gearEquipEnabled and self:HasGearSet()
end

function Casting:GetGeneralOption(key)
    if key == "dismountWithKey" then
        return dismountWithKeyEnabled
    elseif key == "releaseWhenSwimming" then
        return releaseWhenSwimmingEnabled
    elseif key == "disableSoftInteract" then
        return disableSoftInteractEnabled
    elseif key == "disableSoftIcon" then
        return disableSoftIconEnabled
    end
    return false
end

function Casting:GetAudioFocusSettings()
    return CopyAudioFocusSettings(audioFocusSettings)
end

function Casting:IsPrecastMacroEnabled()
    return precastMacroEnabled
end

function Casting:GetPrecastMacroText()
    return precastMacroText
end

function Casting:GetCurrentAction()
    return activeAction
end

local function QueueStatus(statusKey, statusRemaining)
    return {
        statusKey = statusKey,
        statusText = GetPickerStatusText(statusKey, statusRemaining or 0),
    }
end

local function GetSlotQueueStatus()
    local anyEnabled = false
    local anyEmpty = false
    local shortestCooldown
    for index = 1, ACTION_SLOT_COUNT do
        local slot = actionSlots[index]
        if slot and slot.enabled then
            anyEnabled = true
            if BuildActionSlotMacro(slot) == "" then
                anyEmpty = true
            else
                local remaining = GetSlotRemaining(slot)
                if remaining <= 0 then
                    return QueueStatus("ready", 0)
                elseif not shortestCooldown or remaining < shortestCooldown then
                    shortestCooldown = remaining
                end
            end
        end
    end
    if shortestCooldown then
        return QueueStatus("cooldown", shortestCooldown)
    end
    if anyEmpty then
        return QueueStatus("empty", 0)
    end
    if not anyEnabled then
        return QueueStatus("disabled", 0)
    end
    return QueueStatus("blocked", 0)
end

function Casting:GetResolverQueue()
    local queue = {}
    local currentKind = activeAction and activeAction.kind
    local currentPicker = activeAction and activeAction.pickerKey

    for _, key in ipairs(GetPickerOrder()) do
        local state = self:GetPickerChoice(key)
        queue[#queue + 1] = {
            key = key,
            label = L["ACTION_PICKER_" .. key:upper()],
            detail = state.choice and state.choice.name
                or state.activeName
                or ((key == "lure" or key == "ward") and state.count > 0 and L["ACTION_PICKER_NONE_SELECTED"])
                or L["ACTION_PICKER_EMPTY"],
            statusKey = currentKind == "picker" and currentPicker == key and "next" or state.statusKey,
            statusText = currentKind == "picker" and currentPicker == key and L["ACTION_RESOLVER_NEXT"] or state.statusText,
        }
    end

    local slotStatus = GetSlotQueueStatus()
    queue[#queue + 1] = {
        key = "slots",
        label = L["ACTION_RESOLVER_SLOTS"],
        detail = L["ACTION_RESOLVER_SLOT_DETAIL"],
        statusKey = currentKind == "slot" and "next" or slotStatus.statusKey,
        statusText = currentKind == "slot" and L["ACTION_RESOLVER_NEXT"] or slotStatus.statusText,
    }

    local castStatus = QueueStatus("ready", 0)
    if InCombatLockdown() then
        castStatus = QueueStatus("blocked", 0)
    elseif UnitIsDeadOrGhost("player") then
        castStatus = QueueStatus("blocked", 0)
    elseif isFishing then
        castStatus = { statusKey = "next", statusText = L["ACTION_REEL"] }
    elseif activeAction and activeAction.reason == "water" then
        castStatus = QueueStatus("water", 0)
    elseif activeAction and activeAction.reason == "spellLoading" then
        castStatus = QueueStatus("blocked", 0)
    elseif currentKind == "cast" then
        castStatus = { statusKey = "next", statusText = L["ACTION_RESOLVER_NEXT"] }
    end
    queue[#queue + 1] = {
        key = "cast",
        label = L["ACTION_CAST"],
        detail = fishingSpellName or L["ACTION_DETAIL_SPELL_LOADING"],
        statusKey = castStatus.statusKey,
        statusText = castStatus.statusText,
    }

    return queue
end

function Casting:GetActionSlots()
    return actionSlots
end

function Casting:GetActionSlot(index)
    return actionSlots[index]
end

function Casting:GetActionSlotLabel(index)
    return GetActionSlotDefaultLabel(index)
end

function Casting:GetActionSlotRemaining(index)
    return GetSlotRemaining(actionSlots[index])
end

function Casting:GetPickerChoice(key)
    local picker = pickerSettings[key]
    local choice, index = picker and FindChoice(key, picker.source, picker.itemID)
    local choices = actionChoices[key] or {}
    if (key == "lure" or key == "ward") and picker and not picker.manualChoice then
        choice = nil
        index = nil
    end
    local knownBuffActive, activeBuffName
    if (key == "lure" or key == "ward") then
        knownBuffActive, activeBuffName = GetKnownPickerAuraActive(key)
    end
    local remaining = GetPickerRemaining(picker)
    if choice and choice.auraManaged and not IsChoiceAuraActive(choice) then
        remaining = 0
    elseif choice and choice.random and key == "bobber" and not IsAnyChoiceAuraActive(key) then
        remaining = 0
    end
    local statusKey = "disabled"
    local statusRemaining = 0
    if picker and picker.enabled then
        if (key == "lure" or key == "ward") and knownBuffActive then
            statusKey, statusRemaining = "active", 0
        elseif (key == "lure" or key == "ward") and #choices > 0 and not choice then
            statusKey, statusRemaining = "none", 0
        elseif choice and choice.random then
            statusKey, statusRemaining = GetRandomChoiceStatus(key, picker)
        else
            statusKey, statusRemaining = GetFixedChoiceStatus(key, picker, choice)
        end
    elseif not choice then
        statusKey = "empty"
    end
    return {
        key = key,
        enabled = picker and picker.enabled or false,
        delay = picker and picker.delay or DEFAULT_PICKER_DELAY,
        remaining = remaining,
        statusKey = statusKey,
        statusRemaining = statusRemaining,
        statusText = GetPickerStatusText(statusKey, statusRemaining),
        count = #choices,
        index = index or 0,
        choice = choice,
        hasManualChoice = picker and picker.manualChoice or false,
        activeName = activeBuffName and L["ACTION_PICKER_ACTIVE_CHOICE"]:format(activeBuffName) or nil,
    }
end

function Casting:GetPickerChoices(key)
    return actionChoices[key] or {}
end

function Casting:SetPickerEnabled(key, enabled)
    local picker = pickerSettings[key]
    if not picker then
        return
    end
    pendingRandomChoices[key] = nil
    if key ~= "lure" and key ~= "ward" then
        SelectFirstChoiceIfNeeded(key)
    end
    picker.enabled = enabled and true or false
    PersistOneKeySettings()
    QueueFishingBindingUpdate()
end

function Casting:SelectPickerChoiceByIndex(key, index)
    local picker = pickerSettings[key]
    local choices = actionChoices[key] or {}
    index = tonumber(index)
    if not picker or not index or not choices[index] then
        return
    end

    local choice = choices[index]
    pendingRandomChoices[key] = nil
    picker.source = choice.source
    picker.itemID = choice.itemID
    picker.manualChoice = (key == "lure" or key == "ward") and true or picker.manualChoice
    picker.enabled = true
    PersistOneKeySettings()
    QueueFishingBindingUpdate()
end

function Casting:SelectPickerChoice(key, step)
    local picker = pickerSettings[key]
    local choices = actionChoices[key] or {}
    if not picker then
        return
    end
    if (key == "lure" or key == "ward") then
        local _, currentIndex = FindChoice(key, picker.source, picker.itemID)
        currentIndex = picker.manualChoice and currentIndex or 0
        local choiceCount = #choices
        if choiceCount == 0 then
            picker.source = nil
            picker.itemID = nil
            picker.manualChoice = false
            PersistOneKeySettings()
            QueueFishingBindingUpdate()
            return
        end
        local nextIndex = ((picker.manualChoice and currentIndex or 0) + step) % (choiceCount + 1)
        pendingRandomChoices[key] = nil
        if nextIndex == 0 then
            picker.source = nil
            picker.itemID = nil
            picker.manualChoice = false
        else
            picker.source = choices[nextIndex].source
            picker.itemID = choices[nextIndex].itemID
            picker.manualChoice = true
        end
        PersistOneKeySettings()
        QueueFishingBindingUpdate()
        return
    end
    if #choices == 0 then
        return
    end
    local _, currentIndex = FindChoice(key, picker.source, picker.itemID)
    currentIndex = currentIndex or 1
    local nextIndex = ((currentIndex - 1 + step) % #choices) + 1
    pendingRandomChoices[key] = nil
    picker.source = choices[nextIndex].source
    picker.itemID = choices[nextIndex].itemID
    PersistOneKeySettings()
    QueueFishingBindingUpdate()
end

function Casting:SetPickerDelay(key, delay)
    local picker = pickerSettings[key]
    if not picker then
        return
    end
    picker.delay = math.max(0, tonumber(delay) or DEFAULT_PICKER_DELAY)
    PersistOneKeySettings()
    QueueFishingBindingUpdate()
end

function Casting:RefreshActionChoices()
    RefreshActionChoices()
    PersistOneKeySettings()
    QueueFishingBindingUpdate()
    AvidAngler:Print(L["ACTION_CHOICES_REFRESHED"]:format(
        CountRealChoices("lure"),
        CountRealChoices("oversized"),
        CountRealChoices("bobber"),
        CountRealChoices("toy"),
        CountRealChoices("ward")
    ))
end

function Casting:SetActionSlotEnabled(index, enabled)
    local slot = actionSlots[index]
    if not slot then
        return
    end
    slot.enabled = enabled and true or false
    if index == 1 then
        precastMacroEnabled = slot.enabled
    end
    PersistOneKeySettings()
    QueueFishingBindingUpdate()
end

function Casting:SetActionSlotText(index, text)
    local slot = actionSlots[index]
    if not slot then
        return
    end

    local nextText = NormalizeMacroText(text)
    if not nextText then
        AvidAngler:Print(L["PRECAST_MACRO_INVALID"])
        return
    end

    slot.text = nextText
    precastMacroText = actionSlots[1] and actionSlots[1].text or ""
    precastMacroEnabled = actionSlots[1] and actionSlots[1].enabled or false
    PersistOneKeySettings()
    QueueFishingBindingUpdate()
    AvidAngler:Print(L["ACTION_SLOT_SAVED"]:format(index))
end

function Casting:ClearActionSlot(index)
    local slot = actionSlots[index]
    if not slot then
        return
    end
    slot.enabled = false
    slot.kind = nil
    slot.itemID = nil
    slot.name = ""
    slot.icon = nil
    slot.text = ""
    slot.lastUsed = 0
    if index == 1 then
        precastMacroText = ""
        precastMacroEnabled = false
    end
    PersistOneKeySettings()
    QueueFishingBindingUpdate()
end

function Casting:SetActionSlotToy(index, itemID)
    local slot = actionSlots[index]
    itemID = tonumber(itemID)
    if not slot or not itemID or GetActionSlotKind(index) ~= "toy" then
        return false
    end
    if PlayerHasToy and not PlayerHasToy(itemID) then
        AvidAngler:Print(L["ACTION_SLOT_TOY_NOT_OWNED"])
        return false
    end
    local toyItemID, toyName, icon = GetToyInfo(itemID)
    if not toyName or toyName == "" then
        AvidAngler:Print(L["ACTION_SLOT_DROP_INVALID"])
        return false
    end
    SetActionSlotPayload(slot, {
        kind = "toy",
        itemID = toyItemID or itemID,
        name = toyName,
        icon = icon,
    })
    PersistOneKeySettings()
    QueueFishingBindingUpdate()
    AvidAngler:Print(L["ACTION_SLOT_SAVED"]:format(index))
    return true
end

function Casting:SetActionSlotItem(index, itemID)
    local slot = actionSlots[index]
    itemID = tonumber(itemID)
    if not slot or not itemID or GetActionSlotKind(index) ~= "extra" then
        return false
    end
    local spellName, spellID = GetItemSpell(itemID)
    if not spellName or not spellID then
        AvidAngler:Print(L["ACTION_SLOT_ITEM_NO_SPELL"])
        return false
    end
    SetActionSlotPayload(slot, {
        kind = "item",
        itemID = itemID,
        name = GetItemName(itemID, spellName),
        icon = AvidAngler:SafeCall(C_Item.GetItemIconByID, nil, itemID),
    })
    PersistOneKeySettings()
    QueueFishingBindingUpdate()
    AvidAngler:Print(L["ACTION_SLOT_SAVED"]:format(index))
    return true
end

function Casting:SetActionSlotMacro(index, macroIndex)
    local slot = actionSlots[index]
    macroIndex = tonumber(macroIndex)
    if not slot or not macroIndex or GetActionSlotKind(index) ~= "extra" then
        return false
    end
    local name, icon, body = GetMacroInfo(macroIndex)
    local nextText = NormalizeMacroText(body or "")
    if not nextText or nextText == "" then
        AvidAngler:Print(L["PRECAST_MACRO_INVALID"])
        return false
    end
    SetActionSlotPayload(slot, {
        kind = "macro",
        name = name,
        icon = icon,
        text = nextText,
    })
    PersistOneKeySettings()
    QueueFishingBindingUpdate()
    AvidAngler:Print(L["ACTION_SLOT_SAVED"]:format(index))
    return true
end

function Casting:SetActionSlotDelay(index, delay)
    local slot = actionSlots[index]
    if not slot then
        return
    end

    slot.delay = math.max(0, tonumber(delay) or DEFAULT_ACTION_SLOT_DELAY)
    PersistOneKeySettings()
    QueueFishingBindingUpdate()
    AvidAngler:Print(L["ACTION_SLOT_DELAY_SET"]:format(index, slot.delay))
end

function Casting:RefreshResolvedAction()
    QueueFishingBindingUpdate()
end

function Casting:SetDoubleRightEnabled(enabled)
    doubleRightEnabled = enabled and true or false
    if doubleRightEnabled then
        inputMode = INPUT_MODE_DOUBLE_RIGHT
        oneKeyEnabled = false
    else
        doubleRightWatching = false
        doubleRightHeld = false
        doubleRightIgnoreNextMouseUp = false
        if inputMode == INPUT_MODE_DOUBLE_RIGHT then
            inputMode = INPUT_MODE_OFF
        end
    end
    PersistOneKeySettings()
    QueueFishingBindingUpdate()
    AvidAngler:Print(doubleRightEnabled and L["DOUBLE_RIGHT_ENABLED"] or L["DOUBLE_RIGHT_DISABLED"])
end

function Casting:SetDisplayMode(mode)
    local nextMode = mode == DISPLAY_MODE_BUTTON and DISPLAY_MODE_BUTTON or DISPLAY_MODE_HUD
    wakeDisplayMode = nextMode
    displayMode = sleeping and DISPLAY_MODE_BUTTON or nextMode
    controlsHidden = false
    PersistOneKeySettings()
    RefreshFishingControls()
    QueueFishingBindingUpdate()
end

function Casting:SetButtonSize(size)
    buttonSize = math.max(52, math.min(140, tonumber(size) or DEFAULT_BUTTON_SIZE))
    PersistOneKeySettings()
    RefreshFishingControls()
end

function Casting:StepButtonSize(step)
    self:SetButtonSize(buttonSize + (tonumber(step) or 0))
end

function Casting:SetControlsHidden(hidden)
    controlsHidden = hidden and true or false
    PersistOneKeySettings()
    RefreshFishingControls()
end

function Casting:SetSleeping(enabled)
    if InCombatLockdown() then
        AvidAngler:Print(L["ACTION_SLEEP_COMBAT"])
        return
    end
    local nextSleeping = enabled and true or false
    if nextSleeping and not sleeping then
        wakeDisplayMode = displayMode
        displayMode = DISPLAY_MODE_BUTTON
        controlsHidden = false
    elseif not nextSleeping and sleeping then
        displayMode = wakeDisplayMode == DISPLAY_MODE_BUTTON and DISPLAY_MODE_BUTTON or DISPLAY_MODE_HUD
        controlsHidden = false
    end
    sleeping = nextSleeping
    if sleeping then
        ClearFishingBindings()
        Helpers.ReleaseAudioFocus()
    elseif isFishing then
        Helpers.ApplyAudioFocus()
    end
    PersistOneKeySettings()
    activeAction = ResolveNextAction()
    SetActionHUD(activeAction)
    RefreshFishingControls()
    QueueFishingBindingUpdate()
    if AvidAngler.UI and AvidAngler.UI.MainWindow and AvidAngler.UI.MainWindow.Refresh then
        AvidAngler.UI.MainWindow:Refresh("casting")
    end
    AvidAngler:Print(sleeping and L["ACTION_SLEEPING_NOW"] or L["ACTION_AWAKE_NOW"])
end

function Casting:SetAutoLootEnabled(enabled)
    autoLootEnabled = enabled and true or false
    PersistOneKeySettings()
    if autoLootEnabled then
        ApplyTempCVar("autoLootDefault", "1")
    else
        RestoreCVar("autoLootDefault")
    end
    AvidAngler:Print(autoLootEnabled and L["AUTO_LOOT_ENABLED"] or L["AUTO_LOOT_DISABLED"])
end

function Casting:SetAudioFocusEnabled(enabled)
    audioFocusEnabled = enabled and true or false
    PersistOneKeySettings()
    if audioFocusEnabled and isFishing then
        Helpers.ApplyAudioFocus()
    else
        Helpers.ReleaseAudioFocus()
    end
    AvidAngler:Print(audioFocusEnabled and L["AUDIO_FOCUS_ENABLED"] or L["AUDIO_FOCUS_DISABLED"])
end

function Casting:SetGearEquipEnabled(enabled)
    if enabled and not self:HasGearSet() then
        AvidAngler:Print(AvidAngler.L["GEAR_SET_NONE_SAVED"])
        return
    end
    Helpers.gearEquipEnabled = enabled and true or false
    if not Helpers.gearEquipEnabled then
        previousGearSetID = nil
    end
    PersistOneKeySettings()
    QueueFishingBindingUpdate()
    AvidAngler:Print(Helpers.gearEquipEnabled and L["GEAR_EQUIP_ENABLED"] or L["GEAR_EQUIP_DISABLED"])
end

function Casting:SetGeneralOption(key, enabled)
    if InCombatLockdown() then
        AvidAngler:Print(L["SETTINGS_GENERAL_COMBAT"])
        return
    end
    enabled = enabled and true or false
    if key == "dismountWithKey" then
        dismountWithKeyEnabled = enabled
        ApplyResolvedAction()
    elseif key == "releaseWhenSwimming" then
        releaseWhenSwimmingEnabled = enabled
        QueueFishingBindingUpdate()
    elseif key == "disableSoftInteract" then
        disableSoftInteractEnabled = enabled
        Helpers.ApplySoftInteractSetting()
    elseif key == "disableSoftIcon" then
        disableSoftIconEnabled = enabled
        Helpers.ApplySoftIconSetting()
    else
        return
    end
    PersistOneKeySettings()
end

function Casting:SetAudioFocusSettings(settings)
    audioFocusSettings = CopyAudioFocusSettings(settings)
    PersistOneKeySettings()
    if audioFocusEnabled and isFishing then
        Helpers.ReleaseAudioFocus()
        Helpers.ApplyAudioFocus()
    end
    AvidAngler:Print(L["AUDIO_FOCUS_SETTINGS_SAVED"])
end

function Casting:ResetAudioFocusSettings()
    self:SetAudioFocusSettings(DEFAULT_AUDIO_FOCUS_SETTINGS)
end

function Casting:ResetSettingsToDefaults()
    if InCombatLockdown() then
        AvidAngler:Print(L["SETTINGS_DEFAULTS_COMBAT"])
        return
    end

    local settings = GetCastingSettings()
    if settings then
        for key in pairs(settings) do
            settings[key] = nil
        end
    end

    RestoreCVar("autoLootDefault")
    Helpers.ReleaseAudioFocus()
    oneKeyEnabled = false
    oneKey = DEFAULT_ONE_KEY
    doubleRightEnabled = false
    autoLootEnabled = false
    audioFocusEnabled = false
    Helpers.gearEquipEnabled = false
    previousGearSetID = nil
    dismountWithKeyEnabled = false
    releaseWhenSwimmingEnabled = true
    disableSoftInteractEnabled = false
    disableSoftIconEnabled = false
    audioFocusSettings = CopyAudioFocusSettings(DEFAULT_AUDIO_FOCUS_SETTINGS)
    Helpers.ApplySoftInteractSetting()
    Helpers.ApplySoftIconSetting()
    precastMacroEnabled = false
    precastMacroText = ""
    doubleRightWatching = false
    doubleRightHeld = false
    doubleRightIgnoreNextMouseUp = false
    inputMode = INPUT_MODE_OFF
    displayMode = DISPLAY_MODE_HUD
    wakeDisplayMode = DISPLAY_MODE_HUD
    controlsHidden = false
    sleeping = false
    buttonSize = DEFAULT_BUTTON_SIZE
    buttonPoint = nil
    hudPoint = nil
    actionSlots = EnsureActionSlots(settings or {})
    pickerSettings = EnsurePickerSettings(settings or {})

    PersistOneKeySettings()
    RefreshActionChoices()
    activeAction = ResolveNextAction()
    SetActionHUD(activeAction)
    RefreshFishingControls()
    QueueFishingBindingUpdate()
    if AvidAngler.UI and AvidAngler.UI.MainWindow and AvidAngler.UI.MainWindow.Refresh then
        AvidAngler.UI.MainWindow:Refresh("casting")
    end
    AvidAngler:Print(L["SETTINGS_DEFAULTS_DONE"])
end

function Casting:SetPrecastMacroEnabled(enabled)
    precastMacroEnabled = enabled and true or false
    if actionSlots[1] then
        actionSlots[1].enabled = precastMacroEnabled
    end
    PersistOneKeySettings()
    QueueFishingBindingUpdate()
    if InCombatLockdown() then
        AvidAngler:Print(L["PRECAST_MACRO_COMBAT"])
    end
    AvidAngler:Print(precastMacroEnabled and L["PRECAST_MACRO_ENABLED"] or L["PRECAST_MACRO_DISABLED"])
end

function Casting:SetPrecastMacroText(text)
    local nextText = NormalizeMacroText(text)
    if not nextText then
        AvidAngler:Print(L["PRECAST_MACRO_INVALID"])
        return
    end

    precastMacroText = nextText
    if actionSlots[1] then
        actionSlots[1].text = nextText
    end
    PersistOneKeySettings()
    QueueFishingBindingUpdate()
    if InCombatLockdown() then
        AvidAngler:Print(L["PRECAST_MACRO_COMBAT"])
    else
        AvidAngler:Print(L["PRECAST_MACRO_SAVED"])
    end
end

local function MouseIsOverWorldOrNothing()
    if WorldFrame:IsMouseMotionFocus() then
        return true
    end

    local mouseFoci = GetMouseFoci and GetMouseFoci()
    return mouseFoci and mouseFoci[1] == nil
end

local function StopDoubleRightWatch()
    if not doubleRightWatching then
        return
    end
    doubleRightWatching = false
    QueueFishingBindingUpdate()
end

local function StopReleasedDoubleRightMouselook()
    if IsMouselooking() and not IsMouseButtonDown("RightButton") then
        MouselookStop()
    end
end

local function WatchDoubleRightClick()
    StopReleasedDoubleRightMouselook()

    if InCombatLockdown() or UnitIsDeadOrGhost("player") then
        return
    end
    if doubleRightIgnoreVisualMouseUp then
        doubleRightIgnoreVisualMouseUp = false
        return
    end
    if doubleRightIgnoreNextMouseUp then
        doubleRightIgnoreNextMouseUp = false
        return
    end

    if not doubleRightWatching then
        doubleRightWatching = true
        QueueFishingBindingUpdate()
        C_Timer.After(DOUBLE_RIGHT_WINDOW, StopDoubleRightWatch)
    else
        StopDoubleRightWatch()
    end
end

local function HandleDoubleRightDown()
    if doubleRightWatching and IsMouseButtonDown("RightButton") then
        MouselookStart()
    end

    doubleRightHeld = true
    C_Timer.After(0.2, function()
        if doubleRightHeld and not IsMouseButtonDown("RightButton") then
            doubleRightHeld = false
        elseif doubleRightHeld then
            doubleRightIgnoreNextMouseUp = true
        end
    end)
end

bindingFrame:RegisterEvent("GLOBAL_MOUSE_UP")
bindingFrame:RegisterEvent("GLOBAL_MOUSE_DOWN")

-- Temporarily raises the game's own soft-target-interact aim toward world
-- objects, improving how reliably the bobber becomes interactable. This is
-- a plain client CVar the player could set themselves; this only holds it
-- while Casting is enabled and restores whatever value the player already
-- had.
local CVAR_SOFT_TARGET_INTERACT = "SoftTargetInteract"

ApplyTempCVar = function(cvarName, value)
    if cachedCVars[cvarName] ~= nil then
        return
    end
    cachedCVars[cvarName] = C_CVar.GetCVar(cvarName)
    C_CVar.SetCVar(cvarName, value)
end

RestoreCVar = function(cvarName)
    local cached = cachedCVars[cvarName]
    if cached == nil then
        return
    end
    C_CVar.SetCVar(cvarName, cached)
    cachedCVars[cvarName] = nil
end

local AUDIO_FOCUS_ENABLE_CVARS = {
    Sound_EnableAllSound = "1",
    Sound_EnableMusic = "1",
    Sound_EnableAmbience = "1",
    Sound_EnableDialog = "1",
    Sound_EnableSFX = "1",
    Sound_EnableSoundWhenGameIsInBG = "1",
}

local AUDIO_FOCUS_VOLUME_KEYS = {
    Sound_MasterVolume = "master",
    Sound_MusicVolume = "music",
    Sound_SFXVolume = "sfx",
    Sound_AmbienceVolume = "ambience",
    Sound_DialogVolume = "dialog",
}

Helpers.ApplyAudioFocus = function()
    if not audioFocusEnabled or sleeping then
        return
    end
    for cvarName, value in pairs(AUDIO_FOCUS_ENABLE_CVARS) do
        ApplyTempCVar(cvarName, value)
    end
    for cvarName, settingKey in pairs(AUDIO_FOCUS_VOLUME_KEYS) do
        ApplyTempCVar(cvarName, tostring((audioFocusSettings[settingKey] or 0) / 100))
    end
end

Helpers.ReleaseAudioFocus = function()
    for cvarName in pairs(AUDIO_FOCUS_ENABLE_CVARS) do
        RestoreCVar(cvarName)
    end
    for cvarName in pairs(AUDIO_FOCUS_VOLUME_KEYS) do
        RestoreCVar(cvarName)
    end
end

Helpers.IsGameAutoLootEnabled = function()
    return C_CVar and C_CVar.GetCVar and C_CVar.GetCVar("autoLootDefault") == "1"
end

Helpers.ApplySoftInteractSetting = function()
    if disableSoftInteractEnabled or not moduleEnabled or (AvidAngler.IsRuntimeDisabled and AvidAngler:IsRuntimeDisabled()) then
        RestoreCVar(CVAR_SOFT_TARGET_INTERACT)
    else
        ApplyTempCVar(CVAR_SOFT_TARGET_INTERACT, "3")
    end
end

Helpers.ApplySoftIconSetting = function()
    if not C_CVar or not C_CVar.SetCVar then
        return
    end
    C_CVar.SetCVar("SoftTargetIconGameObject", disableSoftIconEnabled and "0" or "1")
end

function Casting:Enable()
    moduleEnabled = true
    if AvidAngler.IsRuntimeDisabled and AvidAngler:IsRuntimeDisabled() then
        isFishing = false
        contentVisualHidden = true
        ClearFishingBindings()
        RefreshFishingControls()
        return
    end

    Helpers.ApplySoftInteractSetting()
    if autoLootEnabled then
        ApplyTempCVar("autoLootDefault", "1")
    end
    if isFishing then
        Helpers.ApplyAudioFocus()
    end
    RefreshFishingControls()
    QueueFishingBindingUpdate()
end

function Casting:Disable()
    moduleEnabled = false
    doubleRightWatching = false
    doubleRightHeld = false
    doubleRightIgnoreNextMouseUp = false
    RefreshFishingControls()
    ClearFishingBindings()
    RestoreCVar(CVAR_SOFT_TARGET_INTERACT)
    RestoreCVar("autoLootDefault")
    Helpers.ReleaseAudioFocus()
end

controlFrame = CreateFrame("Frame", "AvidAnglerControlFrame", UIParent, "BackdropTemplate")
controlFrame:SetSize(390, 260)
controlFrame:SetPoint("CENTER", UIParent, "CENTER", 0, -60)
controlFrame:SetFrameStrata("DIALOG")
controlFrame:SetBackdrop((Theme:Backdrop("backdrop", "border")))
controlFrame:SetBackdropColor(unpack(Theme.color.backdrop))
controlFrame:SetBackdropBorderColor(unpack(Theme.color.border))
controlFrame:SetMovable(true)
controlFrame:SetClampedToScreen(true)
controlFrame:Hide()

local controlTitleBar = CreateFrame("Frame", nil, controlFrame)
controlTitleBar:SetPoint("TOPLEFT")
controlTitleBar:SetPoint("TOPRIGHT")
controlTitleBar:SetHeight(Theme.layout.headerHeight)
controlTitleBar:EnableMouse(true)
controlTitleBar:RegisterForDrag("LeftButton")
controlTitleBar:SetScript("OnDragStart", function() controlFrame:StartMoving() end)
controlTitleBar:SetScript("OnDragStop", function() controlFrame:StopMovingOrSizing() end)

local controlTitle = controlTitleBar:CreateFontString(nil, "ARTWORK")
controlTitle:SetFontObject(Theme.font.title)
controlTitle:SetPoint("LEFT", Theme.layout.padding, 5)
controlTitle:SetText(L["CONTROL_PANEL_TITLE"])

local controlSubtitle = controlTitleBar:CreateFontString(nil, "ARTWORK")
controlSubtitle:SetFontObject(Theme.font.small)
controlSubtitle:SetPoint("TOPLEFT", controlTitle, "BOTTOMLEFT", 0, -1)
controlSubtitle:SetText(L["CONTROL_PANEL_SUBTITLE"])

local controlClose = Theme:CreateCloseButton(controlTitleBar)
controlClose:SetPoint("RIGHT", -Theme.layout.gutter, 0)
controlClose:SetScript("OnClick", function() controlFrame:Hide() end)
tinsert(UISpecialFrames, "AvidAnglerControlFrame")

local oneKeyToggle = Theme:CreateButton(controlFrame, "")
oneKeyToggle:SetPoint("TOPLEFT", Theme.layout.padding, -56)
oneKeyToggle:SetWidth(150)

local doubleRightToggle = Theme:CreateButton(controlFrame, "")
doubleRightToggle:SetPoint("LEFT", oneKeyToggle, "RIGHT", Theme.layout.gutter, 0)
doubleRightToggle:SetWidth(160)

local autoLootToggle = Theme:CreateButton(controlFrame, "")
autoLootToggle:SetPoint("TOPLEFT", oneKeyToggle, "BOTTOMLEFT", 0, -10)
autoLootToggle:SetWidth(150)

local keyLabel = controlFrame:CreateFontString(nil, "ARTWORK")
keyLabel:SetFontObject(Theme.font.muted)
keyLabel:SetPoint("TOPLEFT", autoLootToggle, "BOTTOMLEFT", 0, -18)
keyLabel:SetText(L["KEY_LABEL"])

local keyBox = Theme:CreateEditBox(controlFrame, 140)
keyBox:SetPoint("LEFT", keyLabel, "RIGHT", Theme.layout.gutter, 0)
keyBox:SetScript("OnEnterPressed", function(self)
    Casting:SetOneKey(self:GetText())
    Casting:RefreshControlPanel()
    self:ClearFocus()
end)

local saveKeyButton = Theme:CreateButton(controlFrame, L["SAVE_KEY_LABEL"])
saveKeyButton:SetPoint("LEFT", keyBox, "RIGHT", Theme.layout.gutter, 0)
saveKeyButton:SetWidth(72)

local saveGearButton = Theme:CreateButton(controlFrame, L["GEAR_SAVE_LABEL"])
saveGearButton:SetPoint("TOPLEFT", keyLabel, "BOTTOMLEFT", 0, -24)
saveGearButton:SetWidth(100)

local equipGearButton = Theme:CreateButton(controlFrame, L["GEAR_EQUIP_LABEL"])
equipGearButton:SetPoint("LEFT", saveGearButton, "RIGHT", Theme.layout.gutter, 0)
equipGearButton:SetWidth(100)

local historyButton = Theme:CreateButton(controlFrame, L["HISTORY_BUTTON_LABEL"])
historyButton:SetPoint("LEFT", equipGearButton, "RIGHT", Theme.layout.gutter, 0)
historyButton:SetWidth(88)

local sessionButton = Theme:CreateButton(controlFrame, L["SESSION_BUTTON_LABEL"])
sessionButton:SetPoint("TOPLEFT", saveGearButton, "BOTTOMLEFT", 0, -12)
sessionButton:SetWidth(100)

local function SetToggleVisual(button, enabled, labelText)
    button.text:SetText((enabled and "[x] " or "[ ] ") .. labelText)
    if enabled then
        button:SetBackdropBorderColor(unpack(Theme.color.accent))
    else
        button:SetBackdropBorderColor(unpack(Theme.color.border))
    end
end

function Casting:RefreshControlPanel()
    SetToggleVisual(oneKeyToggle, oneKeyEnabled, L["ONE_KEY_TOGGLE_LABEL"])
    SetToggleVisual(doubleRightToggle, doubleRightEnabled, L["DOUBLE_RIGHT_TOGGLE_LABEL"])
    SetToggleVisual(autoLootToggle, autoLootEnabled, L["AUTO_LOOT_TOGGLE_LABEL"])
    saveGearButton.text:SetText(self:HasGearSet() and L["GEAR_VIEW_LABEL"] or L["GEAR_SAVE_LABEL"])
    SetToggleVisual(equipGearButton, self:IsGearEquipEnabled(), L["GEAR_EQUIP_LABEL"])
    if keyBox:GetText() ~= oneKey then
        keyBox:SetText(oneKey)
    end
end

function Casting:ToggleControlPanel()
    if controlFrame:IsShown() then
        controlFrame:Hide()
    else
        self:RefreshControlPanel()
        controlFrame:Show()
    end
end

optionsButton:SetScript("OnClick", function()
    if AvidAngler.UI.MainWindow then
        AvidAngler.UI.MainWindow:Toggle()
    else
        Casting:ToggleControlPanel()
    end
end)
castCloseButton:SetScript("OnClick", function()
    Casting:SetControlsHidden(true)
end)
actionHUDCloseButton:SetScript("OnClick", function()
    Casting:SetControlsHidden(true)
end)
oneKeyToggle:SetScript("OnClick", function()
    Casting:SetOneKeyEnabled(not oneKeyEnabled)
    Casting:RefreshControlPanel()
end)
doubleRightToggle:SetScript("OnClick", function()
    Casting:SetDoubleRightEnabled(not doubleRightEnabled)
    Casting:RefreshControlPanel()
end)
autoLootToggle:SetScript("OnClick", function()
    Casting:SetAutoLootEnabled(not autoLootEnabled)
    Casting:RefreshControlPanel()
end)
saveKeyButton:SetScript("OnClick", function()
    Casting:SetOneKey(keyBox:GetText())
    Casting:RefreshControlPanel()
end)
saveGearButton:SetScript("OnClick", function()
    if Casting:HasGearSet() then
        Casting:ViewGearSet()
    else
        Casting:SaveGearSet()
    end
    Casting:RefreshControlPanel()
end)
equipGearButton:SetScript("OnClick", function()
    Casting:SetGearEquipEnabled(not Helpers.gearEquipEnabled)
    Casting:RefreshControlPanel()
end)
historyButton:SetScript("OnClick", function()
    if AvidAngler.Modules.Tracking then
        AvidAngler.Modules.Tracking:Toggle()
    end
end)
sessionButton:SetScript("OnClick", function()
    if AvidAngler.Modules.Tracking then
        AvidAngler.Modules.Tracking:ShowSession()
    end
end)

bindingFrame:RegisterEvent("ADDON_LOADED")
bindingFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
bindingFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
bindingFrame:RegisterEvent("PLAYER_ALIVE")
bindingFrame:RegisterEvent("PLAYER_UNGHOST")
bindingFrame:RegisterEvent("PLAYER_DEAD")
bindingFrame:RegisterEvent("PLAYER_LOGOUT")
bindingFrame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
bindingFrame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP")
bindingFrame:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
bindingFrame:RegisterEvent("UNIT_SPELLCAST_FAILED")
bindingFrame:RegisterEvent("LOOT_READY")
bindingFrame:RegisterEvent("BAG_UPDATE_DELAYED")
bindingFrame:RegisterEvent("TOYS_UPDATED")
bindingFrame:RegisterEvent("NEW_TOY_ADDED")
bindingFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
bindingFrame:RegisterEvent("PLAYER_MOUNT_DISPLAY_CHANGED")
bindingFrame:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
bindingFrame:RegisterEvent("MOUNT_JOURNAL_USABILITY_CHANGED")
bindingFrame:RegisterUnitEvent("UNIT_AURA", "player")
EventRegistry:RegisterCallback(AvidAngler.FISHING_SKILL_CACHE_UPDATED_EVENT, function()
    if AvidAngler.IsRuntimeDisabled and AvidAngler:IsRuntimeDisabled() then
        return
    end
    RefreshActionChoices()
    QueueFishingBindingUpdate()
    Casting:RefreshControlPanel()
end)
EventRegistry:RegisterCallback(AvidAngler.CONTENT_SAFETY_CHANGED_EVENT, function()
    local disabled = AvidAngler.IsRuntimeDisabled and AvidAngler:IsRuntimeDisabled()
    contentVisualHidden = disabled and true or false
    if disabled then
        isFishing = false
        doubleRightWatching = false
        doubleRightHeld = false
        ClearFishingBindings()
        RestoreCVar(CVAR_SOFT_TARGET_INTERACT)
        RestoreCVar("autoLootDefault")
        Helpers.ReleaseAudioFocus()
        HideVisualForCombat()
    elseif moduleEnabled then
        Helpers.ApplySoftInteractSetting()
        if autoLootEnabled then
            ApplyTempCVar("autoLootDefault", "1")
        end
        RefreshPlayerWaterState(false)
        RefreshActionChoices()
        QueueFishingBindingUpdate()
    end
    RefreshFishingControls()
end)
bindingFrame:SetScript("OnEvent", function(_, event, ...)
    if AvidAngler.IsRuntimeDisabled and AvidAngler:IsRuntimeDisabled() and event ~= "ADDON_LOADED" and event ~= "PLAYER_REGEN_DISABLED" and event ~= "PLAYER_REGEN_ENABLED" and event ~= "PLAYER_LOGOUT" then
        isFishing = false
        doubleRightWatching = false
        doubleRightHeld = false
        ClearFishingBindings()
        Helpers.ReleaseAudioFocus()
        return
    end

    if event == "ADDON_LOADED" then
        local addonName = ...
        if addonName == ADDON_NAME then
            LoadOneKeySettings()
            RefreshPlayerWaterState(false)
            ApplyResolvedAction()
            Casting:RefreshControlPanel()
        end
    elseif event == "PLAYER_REGEN_DISABLED" then
        combatVisualHidden = true
        HideVisualForCombat()
        ClearFishingBindings()
    elseif event == "PLAYER_REGEN_ENABLED" then
        combatVisualHidden = false
        if pendingMacroUpdate then
            ApplyResolvedAction()
        end
        if pendingBindingUpdate then
            ApplyFishingBindings()
        else
            QueueFishingBindingUpdate()
        end
        RefreshFishingControls()
    elseif event == "PLAYER_DEAD" then
        isFishing = false
        ClearFishingBindings()
    elseif event == "PLAYER_ALIVE" or event == "PLAYER_UNGHOST" then
        QueueFishingBindingUpdate()
    elseif event == "PLAYER_LOGOUT" then
        ClearFishingBindings()
        RestoreCVar(CVAR_SOFT_TARGET_INTERACT)
        RestoreCVar("autoLootDefault")
        Helpers.ReleaseAudioFocus()
    elseif event == "UNIT_SPELLCAST_CHANNEL_START" then
        local unit, _, spellID = ...
        if unit == "player" and IsFishingSpell(spellID) then
            isFishing = true
            Helpers.ApplyAudioFocus()
            CaptureFishingSourceContext()
            if AvidAngler.DataLayer and AvidAngler.DataLayer.BuildFishingCastRecord and AvidAngler.DataLayer.RecordFishingCast then
                AvidAngler.DataLayer:RecordFishingCast(AvidAngler.DataLayer:BuildFishingCastRecord())
            end
            QueueFishingBindingUpdate()
        end
    elseif event == "UNIT_SPELLCAST_CHANNEL_STOP" or event == "UNIT_SPELLCAST_INTERRUPTED" or event == "UNIT_SPELLCAST_FAILED" then
        local unit, _, spellID = ...
        if unit == "player" and (not spellID or IsFishingSpell(spellID)) then
            isFishing = false
            Helpers.ReleaseAudioFocus()
            QueueFishingBindingUpdate()
        end
    elseif event == "LOOT_READY" then
        if IsFishingLoot() then
            isFishing = false
            Helpers.ReleaseAudioFocus()
            Helpers.RestorePreviousGearSet()
            QueueFishingBindingUpdate()
        end
    elseif event == "BAG_UPDATE_DELAYED" or event == "TOYS_UPDATED" or event == "NEW_TOY_ADDED" then
        RefreshActionChoices()
        QueueFishingBindingUpdate()
    elseif event == "PLAYER_ENTERING_WORLD" then
        RefreshPlayerWaterState(false)
        RefreshActionChoices()
        QueueFishingBindingUpdate()
    elseif event == "PLAYER_MOUNT_DISPLAY_CHANGED" or event == "UPDATE_SHAPESHIFT_FORM" or event == "MOUNT_JOURNAL_USABILITY_CHANGED" then
        RefreshPlayerWaterState(true)
        QueuePlayerWaterRefresh()
    elseif event == "UNIT_AURA" then
        QueueFishingBindingUpdate()
    elseif event == "GLOBAL_MOUSE_UP" then
        local button = ...
        if moduleEnabled and button == "RightButton" and doubleRightEnabled and MouseIsOverWorldOrNothing() then
            doubleRightHeld = false
            WatchDoubleRightClick()
        end
    elseif event == "GLOBAL_MOUSE_DOWN" then
        local button = ...
        if moduleEnabled and button == "RightButton" and doubleRightEnabled and MouseIsOverWorldOrNothing() then
            HandleDoubleRightDown()
        end
    end
end)

-- Fishing gear set: a single named C_EquipmentSet the player saves once
-- from their currently equipped items and re-equips on demand. These calls
-- are plain Lua, not secure actions; the same public entry points can later
-- support user-defined outfit names without adding another swap mechanism.
function GetGearSetID()
    return C_EquipmentSet.GetEquipmentSetID(EQUIPMENT_SET_NAME)
end

local function GetEquippedGearSetID()
    if not C_EquipmentSet or not C_EquipmentSet.GetEquipmentSetIDs or not C_EquipmentSet.GetEquipmentSetInfo then
        return nil
    end
    local avidSetID = GetGearSetID()
    local setIDs = C_EquipmentSet.GetEquipmentSetIDs()
    for i = 1, #setIDs do
        local setID = setIDs[i]
        local _, _, _, isEquipped = C_EquipmentSet.GetEquipmentSetInfo(setID)
        if isEquipped and setID ~= avidSetID then
            return setID
        end
    end
    return nil
end

Helpers.CapturePreviousGearSet = function()
    if not Helpers.gearEquipEnabled or previousGearSetID then
        return
    end
    previousGearSetID = GetEquippedGearSetID()
end

Helpers.RestorePreviousGearSet = function()
    if not previousGearSetID then
        return
    end
    if InCombatLockdown() or UnitIsDeadOrGhost("player") then
        return
    end
    local setID = previousGearSetID
    previousGearSetID = nil
    C_EquipmentSet.UseEquipmentSet(setID)
end

function Casting:HasGearSet()
    return GetGearSetID() ~= nil
end

function Casting:GetGearSetName()
    return EQUIPMENT_SET_NAME
end

function Casting:HasReturnGearSet()
    if not C_EquipmentSet or not C_EquipmentSet.GetEquipmentSetIDs then
        return false
    end
    local avidSetID = GetGearSetID()
    local setIDs = C_EquipmentSet.GetEquipmentSetIDs()
    for i = 1, #setIDs do
        if setIDs[i] ~= avidSetID then
            return true
        end
    end
    return false
end

function Casting:SaveGearSet()
    if InCombatLockdown() then
        AvidAngler:Print(AvidAngler.L["GEAR_SET_IN_COMBAT"])
        return
    end

    local setID = GetGearSetID()
    if setID then
        C_EquipmentSet.SaveEquipmentSet(setID)
    else
        C_EquipmentSet.CreateEquipmentSet(EQUIPMENT_SET_NAME)
    end
    QueueFishingBindingUpdate()
    AvidAngler:Print(AvidAngler.L["GEAR_SET_SAVED"])
end

function Casting:SaveGearSetWithDefault()
    if InCombatLockdown() then
        AvidAngler:Print(AvidAngler.L["GEAR_SET_IN_COMBAT"])
        return
    end

    if not C_EquipmentSet.GetEquipmentSetID(DEFAULT_EQUIPMENT_SET_NAME) then
        C_EquipmentSet.CreateEquipmentSet(DEFAULT_EQUIPMENT_SET_NAME)
    end
    self:SaveGearSet()
end

function Casting:ViewGearSet()
    local setID = GetGearSetID()
    if not setID then
        self:SaveGearSet()
        return
    end
    if not InCombatLockdown() and not UnitIsDeadOrGhost("player") then
        C_EquipmentSet.UseEquipmentSet(setID)
    end
    if ToggleCharacter then
        ToggleCharacter("PaperDollFrame")
    elseif CharacterFrame then
        CharacterFrame:Show()
    end
end

function Casting:EquipGearSet()
    if InCombatLockdown() then
        AvidAngler:Print(AvidAngler.L["GEAR_SET_IN_COMBAT"])
        return
    end
    if UnitIsDeadOrGhost("player") then
        AvidAngler:Print(AvidAngler.L["GEAR_SET_DEAD"])
        return
    end

    local setID = GetGearSetID()
    if not setID then
        AvidAngler:Print(AvidAngler.L["GEAR_SET_NONE_SAVED"])
        return
    end

    C_EquipmentSet.UseEquipmentSet(setID)
    AvidAngler:Print(AvidAngler.L["GEAR_SET_EQUIPPING"])
end

SLASH_AVIDANGLERGEAR1 = "/aagear"
SlashCmdList["AVIDANGLERGEAR"] = function(msg)
    local arg = (msg or ""):match("^%s*(.-)%s*$"):lower()
    if arg == "save" then
        Casting:SaveGearSet()
    elseif arg == "equip" then
        Casting:EquipGearSet()
    else
        AvidAngler:Print(AvidAngler.L["GEAR_SET_USAGE"])
    end
end

SLASH_AVIDANGLERONEKEY1 = "/aaone"
SlashCmdList["AVIDANGLERONEKEY"] = function(msg)
    local command, rest = (msg or ""):match("^%s*(%S*)%s*(.-)%s*$")
    command = (command or ""):lower()

    if command == "on" then
        Casting:SetOneKeyEnabled(true)
    elseif command == "off" then
        Casting:SetOneKeyEnabled(false)
    elseif command == "key" then
        Casting:SetOneKey(rest)
    elseif command == "status" or command == "" then
        if oneKeyEnabled then
            AvidAngler:Print(AvidAngler.L["ONE_KEY_STATUS_ENABLED"]:format(oneKey))
        else
            AvidAngler:Print(AvidAngler.L["ONE_KEY_STATUS_DISABLED"])
        end
    else
        AvidAngler:Print(AvidAngler.L["ONE_KEY_USAGE"])
    end
end

SLASH_AVIDANGLER1 = "/avidangler"
SLASH_AVIDANGLER2 = "/aa"
SlashCmdList["AVIDANGLER"] = function()
    if AvidAngler.UI.MainWindow then
        AvidAngler.UI.MainWindow:Toggle()
    else
        Casting:ToggleControlPanel()
    end
end

SLASH_AVIDANGLERPRECAST1 = "/aaprecast"
SlashCmdList["AVIDANGLERPRECAST"] = function(msg)
    local command, rest = (msg or ""):match("^%s*(%S*)%s*(.-)%s*$")
    command = (command or ""):lower()

    if command == "on" then
        Casting:SetPrecastMacroEnabled(true)
    elseif command == "off" then
        Casting:SetPrecastMacroEnabled(false)
    elseif command == "text" then
        Casting:SetPrecastMacroText(rest)
    elseif command == "status" or command == "" then
        AvidAngler:Print(L["PRECAST_MACRO_STATUS"]:format(precastMacroEnabled and L["MODULE_ENABLED"] or L["MODULE_DISABLED"], precastMacroText ~= "" and precastMacroText or L["PRECAST_MACRO_EMPTY"]))
    else
        AvidAngler:Print(L["PRECAST_MACRO_USAGE"])
    end
end

-- Default-on until persisted module settings exist.
Casting:Enable()
