-- Avid Angler
-- Optional reminders based on readable fishing-tool Venom counts.
local _, AvidAngler = ...
local Alert = {}
AvidAngler.Modules.VenomAlert = Alert

function Alert:SetThreshold(text)
    local trimmed = tostring(text or ""):match("^%s*(.-)%s*$")
    if trimmed ~= "" and not trimmed:match("^%d+$") then return false end
    local value = trimmed == "" and 0 or tonumber(trimmed)
    if not value or value > 2147483647 then return false end
    local settings = AvidAngler.DataLayer:GetVenomAlertSettings()
    if not settings then return false end
    if settings.threshold ~= value then
        settings.threshold, settings.nextAt = value, nil
        self:Hide()
    end
    return true
end

function Alert:Hide()
    if self.toast then self.toast:Hide() end
end

function Alert:Dismiss()
    local settings = AvidAngler.DataLayer:GetVenomAlertSettings()
    if settings and settings.threshold and settings.threshold > 0 and self.current then
        settings.nextAt = self.current + math.ceil(settings.threshold * 0.25)
    end
    self:Hide()
end

function Alert:Show(value)
    local Theme, L = AvidAngler.UI.Theme, AvidAngler.L
    if not self.toast then
        local toast = Theme:CreatePanel(UIParent, "panelRaised", "accent")
        toast:SetSize(440, 64)
        toast:SetPoint("TOP", UIParent, "TOP", 0, -150)
        toast:SetFrameStrata("DIALOG")
        toast:EnableMouse(true)
        local icon = toast:CreateTexture(nil, "ARTWORK")
        icon:SetSize(40, 40)
        icon:SetPoint("TOPLEFT", 12, -12)
        icon:SetTexture(C_Item.GetItemIconByID(244790))
        toast.title = toast:CreateFontString(nil, "ARTWORK")
        toast.title:SetFontObject(Theme.font.title)
        toast.title:SetPoint("TOPLEFT", 64, -12)
        toast.title:SetWidth(330)
        toast.title:SetJustifyH("LEFT")
        toast.body = toast:CreateFontString(nil, "ARTWORK")
        toast.body:SetFontObject(Theme.font.body)
        toast.body:SetPoint("TOPLEFT", toast.title, "BOTTOMLEFT", 0, -6)
        toast.body:SetWidth(364)
        toast.body:SetJustifyH("LEFT")
        local close = Theme:CreateCloseButton(toast)
        close:SetPoint("TOPRIGHT", -4, -4)
        close:SetScript("OnClick", function() self:Dismiss() end)
        self.toast = toast
    end
    self.toast.title:SetText(L["VENOM_ALERT_TITLE"])
    local pole = AvidAngler:SafeCall(C_Item and C_Item.GetItemNameByID, nil, 244790)
    if AvidAngler:IsSecretValue(pole) or type(pole) ~= "string" then pole = "The Coiled Huntress" end
    local locale = AvidAngler:GetActiveLocale()
    if locale == "enUS" or locale == "enGB" then pole = pole:gsub("^The ", "") end
    local currency = AvidAngler:SafeCall(C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo, nil, 3546)
    local filament
    if not AvidAngler:IsSecretValue(currency) and type(currency) == "table" then filament = currency.name end
    if AvidAngler:IsSecretValue(filament) or type(filament) ~= "string" then filament = "Coiled Filament" end
    self.toast.body:SetText(L["VENOM_ALERT_BODY"]:format(pole, value, filament))
    self.toast:SetHeight(math.max(64, 30 + self.toast.title:GetStringHeight() + self.toast.body:GetStringHeight()))
    self.toast:Show()
end

function Alert:Update()
    local settings = AvidAngler.DataLayer:GetVenomAlertSettings()
    local threshold = settings and settings.threshold
    if not threshold or threshold <= 0 or not AvidAngler:IsModuleEnabled("tracking")
        or InCombatLockdown() or AvidAngler:IsRuntimeDisabled() then
        self:Hide()
        return
    end
    local value, equipped = AvidAngler.Modules.FishingStatus:GetVenom("midnight")
    if equipped ~= true or value == nil then self:Hide(); return end
    self.current = value
    if value < threshold then
        settings.nextAt = nil
        self:Hide()
    elseif value >= (settings.nextAt or threshold) then
        self:Show(value)
    else
        self:Hide()
    end
end

local frame, elapsedTotal = CreateFrame("Frame"), 0
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("PLAYER_REGEN_DISABLED")
frame:SetScript("OnEvent", function(_, event, initialLogin, reloading)
    if event == "PLAYER_REGEN_DISABLED" then Alert:Hide(); return end
    if initialLogin and not reloading then
        local settings = AvidAngler.DataLayer:GetVenomAlertSettings()
        if settings then settings.nextAt = nil end
    end
end)
frame:SetScript("OnUpdate", function(_, elapsed)
    elapsedTotal = elapsedTotal + elapsed
    if elapsedTotal < 1 then return end
    elapsedTotal = 0
    Alert:Update()
end)
