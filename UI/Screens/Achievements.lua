-- Avid Angler
-- Expansion achievement cards and completion guides.
local _, AvidAngler = ...
local Theme, L = AvidAngler.UI.Theme, AvidAngler.L
local Model = AvidAngler.Achievements
local Screen = { page = 1, cards = {} }
AvidAngler.UI.Achievements = Screen
local CARD_COLUMNS = 2
local CARD_HEIGHT = 124
local CARD_GAP = 8
local PAGE_SIZE = 8

local function Colored(text, color)
    return ("|cff%02x%02x%02x%s|r"):format(math.floor(color[1] * 255 + 0.5),
        math.floor(color[2] * 255 + 0.5), math.floor(color[3] * 255 + 0.5), text)
end

local function Label(parent, font)
    local text = parent:CreateFontString(nil, "ARTWORK")
    text:SetFontObject(font or Theme.font.body)
    text:SetJustifyH("LEFT")
    return text
end

local function Progress(snapshot)
    if not snapshot then return L["ACH_PROGRESS_UNAVAILABLE"] end
    if snapshot.completed then return L["ACH_COMPLETE"] end
    if snapshot.total then
        return (snapshot.checklist and L["ACH_CRITERIA_PROGRESS"] or L["ACH_PROGRESS"]):format(snapshot.current, snapshot.total)
    end
    return L["ACH_INCOMPLETE"]
end

local function ShowTooltip(card)
    if not card.entry then return end
    GameTooltip:SetOwner(card, "ANCHOR_RIGHT")
    GameTooltip:AddLine(card.snapshot and card.snapshot.name or card.entry.name, unpack(Theme.color.textPrimary))
    GameTooltip:AddLine(card.snapshot and card.snapshot.description or card.entry.description, 0.8, 0.8, 0.8, true)
    GameTooltip:AddLine(" ")
    if card.entry.chain then
        GameTooltip:AddLine(L["ACH_CHAIN_STEP"]:format(card.entry.chainIndex, #card.entry.chain), unpack(Theme.color.accent))
        GameTooltip:AddLine(L["ACH_CHAIN_TOOLTIP"], 0.8, 0.8, 0.8, true)
    end
    GameTooltip:AddLine(L["ACH_CLICK_GUIDE"], unpack(Theme.color.accent))
    GameTooltip:AddLine(L["ACH_CLICK_BLIZZARD"], unpack(Theme.color.textPrimary))
    GameTooltip:AddLine(Model:IsTracked(card.entry.id) and L["ACH_CLICK_UNTRACK"] or L["ACH_CLICK_TRACK"], unpack(Theme.color.textPrimary))
    if card.entry.historical then GameTooltip:AddLine(L["ACH_HISTORICAL_NOTE"], 1, 0.7, 0.3, true) end
    if Model:IsPaused() then GameTooltip:AddLine(L["ACH_ACTION_PAUSED"], 1, 0.7, 0.3, true) end
    GameTooltip:Show()
end

function Screen:HandleClick(entry, button)
    if button == "LeftButton" then
        self:ShowGuide(entry)
        return
    end
    local ok, reason
    if IsShiftKeyDown() then
        ok, reason = Model:ToggleTracking(entry)
        self.dirty = true
    else
        ok, reason = Model:OpenBlizzard(entry)
        if ok and AvidAngler.UI.MainWindow then
            AvidAngler.UI.MainWindow:Hide()
        end
    end
    if not ok and reason then
        self.message:SetText(L[reason])
    else
        self.message:SetText("")
    end
end

function Screen:CreateGuide()
    local dialog = Theme:CreatePanel(self.panel, "backdrop", "accent")
    dialog:SetSize(620, 540)
    dialog:SetPoint("CENTER", UIParent, "CENTER")
    dialog:SetFrameStrata("FULLSCREEN_DIALOG")
    dialog:SetClampedToScreen(true)
    dialog:EnableMouse(true)
    dialog:SetMovable(true)
    dialog:RegisterForDrag("LeftButton")
    dialog:SetScript("OnDragStart", function() dialog:StartMoving() end)
    dialog:SetScript("OnDragStop", function() dialog:StopMovingOrSizing() end)
    _G.AvidAnglerAchievementGuide = dialog
    tinsert(UISpecialFrames, "AvidAnglerAchievementGuide")
    local close = Theme:CreateCloseButton(dialog)
    close:SetPoint("TOPRIGHT", -10, -10)
    close:SetScript("OnClick", function() dialog:Hide() end)
    dialog.title = Label(dialog, Theme.font.title)
    dialog.title:SetPoint("TOPLEFT", 18, -18)
    dialog.title:SetPoint("RIGHT", -42, 0)
    dialog.title:SetHeight(38)
    dialog.scroll = CreateFrame("ScrollFrame", nil, dialog)
    dialog.scroll:SetPoint("TOPLEFT", 18, -64)
    dialog.scroll:SetPoint("BOTTOMRIGHT", -36, 20)
    dialog.body = CreateFrame("Frame", nil, dialog.scroll)
    dialog.body:SetSize(560, 1)
    dialog.scroll:SetScrollChild(dialog.body)
    dialog.text = Label(dialog.body)
    dialog.text:SetPoint("TOPLEFT")
    dialog.text:SetWidth(560)
    dialog.text:SetSpacing(5)
    dialog.waypointButtons = {}
    dialog.waypointStatus = Label(dialog.body, Theme.font.small)
    dialog.waypointStatus:SetWidth(560)
    dialog.scrollTrack = Theme:CreatePanel(dialog, "panel", "border")
    dialog.scrollTrack:SetPoint("TOPLEFT", dialog.scroll, "TOPRIGHT", 8, 0)
    dialog.scrollTrack:SetPoint("BOTTOMLEFT", dialog.scroll, "BOTTOMRIGHT", 8, 0)
    dialog.scrollTrack:SetWidth(12)
    dialog.scrollBar = CreateFrame("Slider", nil, dialog.scrollTrack)
    dialog.scrollBar:SetPoint("TOPLEFT", 1, -1)
    dialog.scrollBar:SetPoint("BOTTOMRIGHT", -1, 1)
    dialog.scrollBar:SetOrientation("VERTICAL")
    dialog.scrollBar:SetMinMaxValues(0, 0)
    dialog.scrollBar:SetValue(0)
    dialog.scrollBar:SetValueStep(1)
    dialog.scrollThumb = dialog.scrollBar:CreateTexture(nil, "ARTWORK")
    dialog.scrollThumb:SetColorTexture(unpack(Theme.color.accent))
    dialog.scrollThumb:SetSize(10, 40)
    dialog.scrollBar:SetThumbTexture(dialog.scrollThumb)
    dialog.scrollBar:SetScript("OnValueChanged", function(_, value)
        dialog.scroll:SetVerticalScroll(value)
    end)
    local function ScrollWheel(_, delta)
        local value = dialog.scrollBar:GetValue() - delta * 40
        dialog.scrollBar:SetValue(math.max(0, math.min(dialog.scrollRange or 0, value)))
    end
    dialog.scroll:EnableMouseWheel(true)
    dialog.scroll:SetScript("OnMouseWheel", ScrollWheel)
    dialog.scrollBar:EnableMouseWheel(true)
    dialog.scrollBar:SetScript("OnMouseWheel", ScrollWheel)
    function dialog:UpdateScrollBounds()
        local viewport = math.max(1, self.scroll:GetHeight())
        local contentHeight = math.max(viewport, self.body:GetHeight())
        self.scrollRange = contentHeight - viewport
        self.scrollBar:SetMinMaxValues(0, self.scrollRange)
        local value = math.min(self.scrollRange, self.scrollBar:GetValue())
        self.scrollBar:SetValue(value)
        self.scroll:SetVerticalScroll(value)
        local trackHeight = math.max(1, viewport - 2)
        self.scrollThumb:SetHeight(math.min(trackHeight, math.max(28, trackHeight * viewport / contentHeight)))
        self.scrollTrack:SetShown(self.scrollRange > 0)
    end
    dialog.scroll:SetScript("OnSizeChanged", function() dialog:UpdateScrollBounds() end)
    dialog:Hide()
    self.guide = dialog
end

function Screen:RefreshGuide()
    local dialog = self.guide
    local entry = dialog and dialog.entry
    if not entry then return end
    local snapshot = Model:GetSnapshot(entry)
    dialog.title:SetText(snapshot and snapshot.name or entry.name)
    local lines = {}
    local function Section(title, text)
        if not text or text == "" then return end
        lines[#lines + 1] = Colored(title, Theme.color.accent)
        lines[#lines + 1] = text
        lines[#lines + 1] = ""
    end
    Section(L["ACH_REQUIREMENT"], snapshot and snapshot.description or entry.description)
    local guidance = L[entry.guideKey or ("ACH_GUIDE_" .. entry.id)]
    if entry.guideExtraKey then
        guidance = (guidance or "") .. "\n\n" .. L[entry.guideExtraKey]
    end
    Section(L["ACH_HOW_TO"], AvidAngler:ResolveGuideText(guidance))
    Section(L["ACH_WHERE"], AvidAngler:ResolveGuideText(L["ACH_LOCATION_" .. entry.id]))
    if entry.historical then Section(L["ACH_AVAILABILITY"], L["ACH_HISTORICAL_NOTE"]) end
    Section(L["ACH_YOUR_PROGRESS"], Progress(snapshot))
    if entry.chain then
        local steps = {}
        for _, step in ipairs(Model:GetChainSteps(entry)) do
            local color = step.status == "ACH_COMPLETE" and Theme.color.success
                or step.status == "ACH_CHAIN_CURRENT" and Theme.color.accent or Theme.color.textSecondary
            steps[#steps + 1] = Colored(L["ACH_CHAIN_ROW"]:format(step.name, L[step.status]), color)
        end
        Section(L["ACH_CHAIN_TITLE"], table.concat(steps, "\n"))
    end
    if snapshot and #snapshot.criteria > 0 then
        lines[#lines + 1] = Colored(L["ACH_CRITERIA"], Theme.color.accent)
        for _, row in ipairs(snapshot.criteria) do
            local status = row.completed and L["ACH_CRITERION_DONE"] or L["ACH_CRITERION_PENDING"]
            local text = status .. " " .. row.name
            if type(row.quantity) == "number" and type(row.required) == "number" and row.required > 1 then
                text = text .. "  " .. L["ACH_PROGRESS"]:format(row.quantity, row.required)
            end
            lines[#lines + 1] = Colored(text, row.completed and Theme.color.success or Theme.color.textPrimary)
        end
        lines[#lines + 1] = ""
    end
    if snapshot then Section(L["ACH_REWARD"], snapshot.reward) end
    if Model:IsPaused() then Section(L["ACH_YOUR_PROGRESS"], L["ACH_ACTION_PAUSED"]) end
    local locations = entry.waypoints or {}
    for _, button in ipairs(dialog.waypointButtons) do button:Hide() end
    for index, location in ipairs(locations) do
        local button = dialog.waypointButtons[index]
        if not button then
            button = Theme:CreateButton(dialog.body, "")
            button:SetWidth(560)
            button:SetScript("OnClick", function()
                local label = AvidAngler:ResolveGuideText(L[button.location.labelKey])
                local ok, reason = AvidAngler:SetWaypoint(button.location, label)
                dialog.waypointStatus:SetText(L[reason])
                dialog.waypointStatus:SetTextColor(unpack(ok and Theme.color.success or Theme.color.warning))
            end)
            button:SetScript("OnEnter", function()
                GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
                GameTooltip:AddLine(L["ACH_WAYPOINT_TOOLTIP"], 0.8, 0.8, 0.8, true)
                GameTooltip:Show()
            end)
            button:SetScript("OnLeave", function() GameTooltip:Hide() end)
            dialog.waypointButtons[index] = button
        end
        button.location = location
        button:ClearAllPoints()
        button:SetPoint("TOPLEFT", 0, -(index - 1) * 32)
        button.text:SetText(L["ACH_WAYPOINT_BUTTON"]:format(AvidAngler:ResolveGuideText(L[location.labelKey]), location.x, location.y))
        button:Show()
    end
    local waypointHeight = #locations > 0 and (#locations * 32 + 22) or 0
    dialog.waypointStatus:ClearAllPoints()
    dialog.waypointStatus:SetPoint("TOPLEFT", 0, -#locations * 32)
    dialog.waypointStatus:SetShown(#locations > 0)
    dialog.text:ClearAllPoints()
    dialog.text:SetPoint("TOPLEFT", 0, -waypointHeight)
    dialog.text:SetText(table.concat(lines, "\n"))
    dialog.body:SetHeight(math.max(dialog.scroll:GetHeight(), waypointHeight + dialog.text:GetStringHeight() + 12))
    dialog:UpdateScrollBounds()
end

function Screen:ShowGuide(entry)
    if not self.guide then self:CreateGuide() end
    self.guide.entry = entry
    self.guide.waypointStatus:SetText("")
    self.guide:Show()
    self:RefreshGuide()
    self.guide.scrollBar:SetValue(0)
    self.guide.scroll:SetVerticalScroll(0)
    GameTooltip:Hide()
end

function Screen:Refresh()
    if not self.panel:IsShown() then return end
    local hideCompleted = Model:GetHideCompleted()
    local rows = Model:GetEntries(self.expansion, self.includeHistorical, hideCompleted, Model:GetHideAbyssAnglers())
    self.abyss:SetShown(self.expansion == "midnight")
    self.abyss.text:SetText(Model:GetHideAbyssAnglers() and L["ACH_SHOW_ABYSS"] or L["ACH_HIDE_ABYSS"])
    self.heading:SetPoint("RIGHT", self.expansion == "midnight" and -544 or -352, 0)
    self.completed.text:SetText(hideCompleted and L["ACH_SHOW_COMPLETED"] or L["ACH_HIDE_COMPLETED"])
    local maxPage = math.max(1, math.ceil(#rows / PAGE_SIZE))
    self.page = math.max(1, math.min(self.page, maxPage))
    self.heading:SetText(L["ACH_TITLE"]:format(self.expansionName or ""))
    self.pageText:SetText(L["ACH_PAGE"]:format(self.page, maxPage, #rows))
    self.previous:SetEnabled(self.page > 1)
    self.next:SetEnabled(self.page < maxPage)
    self.empty:SetShown(#rows == 0)
    self.history.text:SetText(self.includeHistorical and L["ACH_HIDE_HISTORICAL"] or L["ACH_SHOW_HISTORICAL"])
    for index, card in ipairs(self.cards) do
        local entry = rows[(self.page - 1) * PAGE_SIZE + index]
        card.entry = entry
        card:SetShown(entry ~= nil)
        if entry then
            local snapshot = Model:GetSnapshot(entry)
            card.snapshot = snapshot
            card.icon:SetTexture(snapshot and snapshot.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
            card.title:SetText(snapshot and snapshot.name or entry.name)
            card.description:SetText(snapshot and snapshot.description or entry.description)
            card.progressText:SetText(Progress(snapshot))
            card.progressText:SetTextColor(unpack(snapshot and snapshot.completed and Theme.color.success or Theme.color.textSecondary))
            local tracked = Model:IsTracked(entry.id) and L["ACH_TRACKED"] or ""
            local step = entry.chain and L["ACH_CHAIN_STEP"]:format(entry.chainIndex, #entry.chain) or ""
            card.tracked:SetText(step ~= "" and (tracked ~= "" and step .. " · " .. tracked or step) or tracked)
            local hasProgress = snapshot and (snapshot.total or snapshot.completed)
            card.barBackground:SetShown(hasProgress and true or false)
            if hasProgress then
                card.bar:SetMinMaxValues(0, snapshot.total or 1)
                card.bar:SetValue(snapshot.completed and (snapshot.total or 1) or snapshot.current)
                card.bar:SetStatusBarColor(unpack(snapshot.completed and Theme.color.success or Theme.color.accent))
            end
        end
    end
    if self.guide and self.guide:IsShown() then self:RefreshGuide() end
end

function Screen:SetExpansion(expansion, name)
    if self.expansion ~= expansion then
        self.page = 1
        self.message:SetText("")
        if self.guide then self.guide:Hide() end
    end
    self.expansion, self.expansionName = expansion, name
    self.dirty = true
end

function Screen:Create(parent, anchor)
    local panel = CreateFrame("Frame", nil, parent)
    panel:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -16)
    panel:SetPoint("BOTTOMRIGHT")
    panel:Hide()
    self.panel = panel
    self.heading = Label(panel, Theme.font.title)
    self.heading:SetPoint("TOPLEFT", 0, -2)
    self.heading:SetPoint("RIGHT", -352, 0)
    self.history = Theme:CreateButton(panel, L["ACH_SHOW_HISTORICAL"])
    self.history:SetPoint("TOPRIGHT", 0, 0)
    self.history:SetWidth(164)
    self.history:SetScript("OnEnter", function()
        GameTooltip:SetOwner(self.history, "ANCHOR_RIGHT")
        GameTooltip:AddLine(L["ACH_SHOW_HISTORICAL"], unpack(Theme.color.textPrimary))
        GameTooltip:AddLine(L["ACH_HISTORICAL_TOOLTIP"], 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    self.history:SetScript("OnLeave", function() GameTooltip:Hide() end)
    self.history:SetScript("OnClick", function()
        self.includeHistorical = not self.includeHistorical
        self.page = 1
        self:Refresh()
    end)
    self.completed = Theme:CreateButton(panel, L["ACH_HIDE_COMPLETED"])
    self.completed:SetPoint("RIGHT", self.history, "LEFT", -8, 0)
    self.completed:SetWidth(164)
    self.completed:SetScript("OnClick", function()
        Model:SetHideCompleted(not Model:GetHideCompleted())
        self.page = 1
        self:Refresh()
    end)
    self.completed:SetScript("OnEnter", function()
        GameTooltip:SetOwner(self.completed, "ANCHOR_RIGHT")
        GameTooltip:AddLine(L["ACH_HIDE_COMPLETED"], unpack(Theme.color.textPrimary))
        GameTooltip:AddLine(L["ACH_COMPLETED_TOOLTIP"], 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    self.completed:SetScript("OnLeave", function() GameTooltip:Hide() end)
    self.abyss = Theme:CreateButton(panel, L["ACH_HIDE_ABYSS"])
    self.abyss:SetPoint("RIGHT", self.completed, "LEFT", -8, 0)
    self.abyss:SetWidth(184)
    self.abyss:Hide()
    self.abyss:SetScript("OnClick", function()
        Model:SetHideAbyssAnglers(not Model:GetHideAbyssAnglers())
        self.page = 1
        if self.guide and self.guide.entry and self.guide.entry.abyssAnglers then self.guide:Hide() end
        self:Refresh()
    end)
    self.abyss:SetScript("OnEnter", function()
        GameTooltip:SetOwner(self.abyss, "ANCHOR_RIGHT")
        GameTooltip:AddLine(L["ACH_HIDE_ABYSS"], unpack(Theme.color.textPrimary))
        GameTooltip:AddLine(L["ACH_ABYSS_TOOLTIP"], 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    self.abyss:SetScript("OnLeave", function() GameTooltip:Hide() end)
    self.empty = Label(panel, Theme.font.muted)
    self.empty:SetPoint("TOPLEFT", 12, -52)
    self.empty:SetPoint("RIGHT", -12, 0)
    self.empty:SetText(L["ACH_FILTER_EMPTY"])
    self.empty:Hide()
    for index = 1, PAGE_SIZE do
        local card = Theme:CreatePanel(panel, "panel", "border")
        card:SetHeight(CARD_HEIGHT)
        card.icon = card:CreateTexture(nil, "ARTWORK")
        card.icon:SetPoint("TOPLEFT", 12, -12)
        card.icon:SetSize(38, 38)
        card.progressText = Label(card, Theme.font.small)
        card.progressText:SetPoint("BOTTOMRIGHT", -12, 30)
        card.progressText:SetWidth(180)
        card.progressText:SetJustifyH("RIGHT")
        card.title = Label(card, Theme.font.heading)
        card.title:SetPoint("TOPLEFT", card.icon, "TOPRIGHT", 12, 0)
        card.title:SetPoint("RIGHT", -12, 0)
        card.title:SetHeight(28)
        card.title:SetJustifyV("TOP")
        card.description = Label(card, Theme.font.muted)
        card.description:SetPoint("TOPLEFT", card.title, "BOTTOMLEFT", 0, -6)
        card.description:SetPoint("RIGHT", -12, 0)
        card.description:SetHeight(30)
        card.description:SetJustifyV("TOP")
        card.tracked = Label(card, Theme.font.small)
        card.tracked:SetPoint("BOTTOMLEFT", 62, 30)
        card.tracked:SetWidth(240)
        card.barBackground = Theme:CreatePanel(card, "backdrop", "border")
        card.barBackground:SetPoint("BOTTOMLEFT", 62, 12)
        card.barBackground:SetPoint("BOTTOMRIGHT", -12, 12)
        card.barBackground:SetHeight(12)
        card.bar = CreateFrame("StatusBar", nil, card.barBackground)
        card.bar:SetPoint("TOPLEFT", 1, -1)
        card.bar:SetPoint("BOTTOMRIGHT", -1, 1)
        card.bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
        local hit = CreateFrame("Button", nil, card)
        hit:SetAllPoints()
        hit:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        hit:SetScript("OnClick", function(_, button) if card.entry then self:HandleClick(card.entry, button) end end)
        hit:SetScript("OnEnter", function()
            card:SetBackdropColor(unpack(Theme.color.panelRaised))
            card:SetBackdropBorderColor(unpack(Theme.color.accentDim))
            ShowTooltip(card)
        end)
        hit:SetScript("OnLeave", function()
            card:SetBackdropColor(unpack(Theme.color.panel))
            card:SetBackdropBorderColor(unpack(Theme.color.border))
            GameTooltip:Hide()
        end)
        self.cards[index] = card
    end
    local function LayoutCards()
        local width = math.max(1, (panel:GetWidth() - CARD_GAP) / CARD_COLUMNS)
        for index, card in ipairs(self.cards) do
            local column = (index - 1) % CARD_COLUMNS
            local row = math.floor((index - 1) / CARD_COLUMNS)
            card:ClearAllPoints()
            card:SetPoint("TOPLEFT", column * (width + CARD_GAP), -40 - row * (CARD_HEIGHT + CARD_GAP))
            card:SetWidth(width)
        end
    end
    panel:SetScript("OnSizeChanged", LayoutCards)
    LayoutCards()
    self.previous = Theme:CreateButton(panel, L["CATCH_HISTORY_PREV"])
    self.previous:SetPoint("BOTTOMLEFT")
    self.previous:SetWidth(78)
    self.next = Theme:CreateButton(panel, L["CATCH_HISTORY_NEXT"])
    self.next:SetPoint("LEFT", self.previous, "RIGHT", 8, 0)
    self.next:SetWidth(78)
    self.pageText = Label(panel, Theme.font.muted)
    self.pageText:SetPoint("LEFT", self.next, "RIGHT", 12, 0)
    self.message = Label(panel, Theme.font.small)
    self.message:SetPoint("BOTTOMLEFT", self.previous, "TOPLEFT", 0, 8)
    self.message:SetPoint("RIGHT")
    self.message:SetTextColor(unpack(Theme.color.warning))
    self.previous:SetScript("OnClick", function() self.page = self.page - 1; self:Refresh() end)
    self.next:SetScript("OnClick", function() self.page = self.page + 1; self:Refresh() end)
    local events = { "ACHIEVEMENT_EARNED", "CRITERIA_UPDATE", "CONTENT_TRACKING_UPDATE", "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED", "GET_ITEM_INFO_RECEIVED" }
    panel:SetScript("OnShow", function()
        Model:InvalidateCompletions()
        for _, event in ipairs(events) do panel:RegisterEvent(event) end
        self.dirty = true
    end)
    panel:SetScript("OnHide", function()
        panel:UnregisterAllEvents()
        GameTooltip:Hide()
        if self.guide then self.guide:Hide() end
    end)
    panel:SetScript("OnEvent", function(_, event)
        if event == "GET_ITEM_INFO_RECEIVED" and (not self.guide or not self.guide:IsShown()) then return end
        if event == "ACHIEVEMENT_EARNED" or event == "PLAYER_REGEN_ENABLED" then
            Model:InvalidateCompletions()
        end
        self.dirty = true
    end)
    local elapsedSinceRefresh = 0
    panel:SetScript("OnUpdate", function(_, elapsed)
        elapsedSinceRefresh = elapsedSinceRefresh + elapsed
        if self.dirty and elapsedSinceRefresh >= 0.25 then
            self.dirty = false
            elapsedSinceRefresh = 0
            self:Refresh()
        end
    end)
    return panel
end
