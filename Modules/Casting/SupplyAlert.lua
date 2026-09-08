-- Avid Angler
-- Reminders for selected fishing consumables that can no longer be reapplied.
local _, AvidAngler = ...
local Alert = { states = {}, toasts = {} }
AvidAngler.Modules.SupplyAlert = Alert

function Alert:Hide(key)
    if self.toasts[key] then self.toasts[key]:Hide() end
end

function Alert:Show(key, itemID)
    local Theme, L = AvidAngler.UI.Theme, AvidAngler.L
    local toast = self.toasts[key]
    if not toast then
        toast = Theme:CreatePanel(UIParent, "panelRaised", "accent")
        toast:SetSize(440, 80)
        toast:SetPoint("TOP", UIParent, "TOP", 0, key == "lure" and -280 or -400)
        toast:SetFrameStrata("DIALOG")
        toast:EnableMouse(true)
        toast.icon = toast:CreateTexture(nil, "ARTWORK")
        toast.icon:SetSize(40, 40)
        toast.icon:SetPoint("TOPLEFT", 12, -12)
        toast.title = toast:CreateFontString(nil, "ARTWORK")
        toast.title:SetFontObject(Theme.font.title)
        toast.title:SetPoint("TOPLEFT", 64, -12)
        toast.title:SetWidth(340)
        toast.title:SetJustifyH("LEFT")
        toast.body = toast:CreateFontString(nil, "ARTWORK")
        toast.body:SetFontObject(Theme.font.body)
        toast.body:SetPoint("TOPLEFT", toast.title, "BOTTOMLEFT", 0, -6)
        toast.body:SetWidth(364)
        toast.body:SetJustifyH("LEFT")
        local close = Theme:CreateCloseButton(toast)
        close:SetPoint("TOPRIGHT", -4, -4)
        close:SetScript("OnClick", function() self:Hide(key) end)
        self.toasts[key] = toast
    end
    local name = AvidAngler:SafeString(AvidAngler:SafeCall(C_Item.GetItemNameByID, nil, itemID), nil)
    toast.icon:SetTexture(C_Item.GetItemIconByID(itemID))
    toast.title:SetText(L[key == "lure" and "SUPPLY_ALERT_LURE" or "SUPPLY_ALERT_WARD"])
    toast.body:SetText(L["SUPPLY_ALERT_BODY"]:format(name or ("item:" .. itemID)))
    toast:SetHeight(math.max(80, 30 + toast.title:GetStringHeight() + toast.body:GetStringHeight()))
    toast:Show()
end

function Alert:Update(now)
    local casting = AvidAngler.Modules.Casting
    if not casting or InCombatLockdown() or AvidAngler:IsRuntimeDisabled() then
        self:Hide("lure"); self:Hide("ward"); self.lastFishing = nil
        return
    end
    if casting:IsFishing() then self.lastFishing = now end
    for _, key in ipairs({"lure", "ward"}) do
        local snapshot = casting:GetSupplyAlertState(key)
        local state = self.states[key]
        if snapshot == false then
            self.states[key] = nil
            self:Hide(key)
        elseif snapshot then
            if not state or state.itemID ~= snapshot.itemID then
                state = { itemID = snapshot.itemID }
                self.states[key] = state
                self:Hide(key)
            end
            if snapshot.count > 0 or snapshot.active then
                state.emptySince = nil
                state.warned = false
                self:Hide(key)
            elseif not state.warned and self.lastFishing and now - self.lastFishing <= 60 then
                state.emptySince = state.emptySince or now
                if now - state.emptySince >= 2 then
                    state.warned = true
                    self:Show(key, snapshot.itemID)
                end
            end
        else
            if state then state.emptySince = nil end
            self:Hide(key)
        end
    end
end

local frame, elapsedTotal = CreateFrame("Frame"), 0
frame:RegisterEvent("PLAYER_REGEN_DISABLED")
frame:SetScript("OnEvent", function() Alert:Hide("lure"); Alert:Hide("ward") end)
frame:SetScript("OnUpdate", function(_, elapsed)
    elapsedTotal = elapsedTotal + elapsed
    if elapsedTotal < 1 then return end
    elapsedTotal = 0
    Alert:Update(GetTime())
end)
