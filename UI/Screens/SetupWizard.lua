-- Avid Angler
-- First-run setup wizard.

local ADDON_NAME, AvidAngler = ...

AvidAngler.UI = AvidAngler.UI or {}
local SetupWizard = {}
AvidAngler.UI.SetupWizard = SetupWizard

local Theme = AvidAngler.UI.Theme
local L = AvidAngler.L

local pages = {
    {
        titleKey = "SETUP_WIZARD_WELCOME_TITLE",
        bodyKey = "SETUP_WIZARD_WELCOME_BODY",
        mode = "modules",
        options = {
            { key = "casting", labelKey = "MAIN_TAB_CASTING", bodyKey = "SETUP_WIZARD_MODULE_CASTING_BODY" },
            { key = "tracking", labelKey = "MAIN_TAB_TRACKING", bodyKey = "SETUP_WIZARD_MODULE_TRACKING_BODY" },
            { key = "scoring", labelKey = "MAIN_TAB_SCORING", bodyKey = "SETUP_WIZARD_MODULE_SCORING_BODY" },
        },
    },
    {
        titleKey = "SETUP_WIZARD_INPUT_TITLE",
        bodyKey = "SETUP_WIZARD_INPUT_BODY",
        mode = "input",
        options = {
            { key = "oneKey", labelKey = "ONE_KEY_TOGGLE_LABEL", bodyKey = "SETUP_WIZARD_ONE_KEY_BODY" },
            { key = "doubleRight", labelKey = "DOUBLE_RIGHT_TOGGLE_LABEL", bodyKey = "SETUP_WIZARD_DOUBLE_RIGHT_BODY" },
            { key = "off", labelKey = "SETUP_WIZARD_INPUT_OFF_LABEL", bodyKey = "SETUP_WIZARD_INPUT_OFF_BODY" },
        },
    },
    {
        titleKey = "SETUP_WIZARD_HELPERS_TITLE",
        bodyKey = "SETUP_WIZARD_HELPERS_BODY",
        mode = "helpers",
        options = {
            { key = "autoLoot", labelKey = "AUTO_LOOT_TOGGLE_LABEL", bodyKey = "SETUP_WIZARD_AUTO_LOOT_BODY" },
            { key = "softInteract", labelKey = "SETUP_WIZARD_SOFT_INTERACT_LABEL", bodyKey = "SETUP_WIZARD_SOFT_INTERACT_BODY" },
            { key = "hideSoftIcon", labelKey = "GENERAL_OPTION_DISABLE_SOFT_ICON", bodyKey = "SETUP_WIZARD_SOFT_ICON_BODY" },
        },
    },
    {
        titleKey = "SETUP_WIZARD_COMFORT_TITLE",
        bodyKey = "SETUP_WIZARD_COMFORT_BODY",
        mode = "comfort",
        options = {
            { key = "dismount", labelKey = "GENERAL_OPTION_DISMOUNT_WITH_KEY", bodyKey = "SETUP_WIZARD_DISMOUNT_BODY" },
            { key = "releaseSwimming", labelKey = "GENERAL_OPTION_RELEASE_WHEN_SWIMMING", bodyKey = "SETUP_WIZARD_RELEASE_SWIMMING_BODY" },
            { key = "audioFocus", labelKey = "AUDIO_FOCUS_TOGGLE_LABEL", bodyKey = "SETUP_WIZARD_AUDIO_FOCUS_BODY" },
        },
    },
    {
        titleKey = "SETUP_WIZARD_GEAR_TITLE",
        bodyKey = "SETUP_WIZARD_GEAR_BODY",
        mode = "gear",
        options = {
            { key = "saveGear", labelKey = "GEAR_SAVE_LABEL", bodyKey = "SETUP_WIZARD_GEAR_SAVE_BODY", action = "saveGear" },
            { key = "gearEquip", labelKey = "GEAR_EQUIP_LABEL", bodyKey = "SETUP_WIZARD_GEAR_EQUIP_BODY" },
        },
    },
    {
        titleKey = "SETUP_WIZARD_DISPLAY_TITLE",
        bodyKey = "SETUP_WIZARD_DISPLAY_BODY",
        mode = "display",
        options = {
            { key = "hud", labelKey = "ACTION_DISPLAY_HUD", bodyKey = "SETUP_WIZARD_HUD_BODY" },
            { key = "button", labelKey = "ACTION_DISPLAY_BUTTON", bodyKey = "SETUP_WIZARD_BUTTON_BODY" },
        },
    },
    {
        titleKey = "SETUP_WIZARD_TRACKING_TITLE",
        bodyKey = "SETUP_WIZARD_TRACKING_BODY",
        mode = "tracking",
        options = {
            { key = "keepWatch", labelKey = "SETUP_WIZARD_KEEP_WATCH_LABEL", bodyKey = "SETUP_WIZARD_KEEP_WATCH_BODY" },
            { key = "hideTrophy", labelKey = "SCORING_HIDE_TROPHY", bodyKey = "SETUP_WIZARD_HIDE_TROPHY_BODY" },
        },
    },
    {
        titleKey = "SETUP_WIZARD_FINISH_TITLE",
        bodyKey = "SETUP_WIZARD_FINISH_BODY",
        options = {
            { key = "settings", labelKey = "SETUP_WIZARD_SETTINGS_LABEL", bodyKey = "SETUP_WIZARD_SETTINGS_BODY" },
            { key = "fish", labelKey = "SETUP_WIZARD_FISH_LABEL", bodyKey = "SETUP_WIZARD_FISH_BODY" },
        },
    },
}

local state = {
    page = 1,
    inputMode = "oneKey",
    autoLoot = true,
    softInteract = true,
    hideSoftIcon = false,
    dismount = false,
    releaseSwimming = true,
    audioFocus = false,
    gearEquip = false,
    displayMode = "hud",
    keepWatch = true,
    hideTrophy = false,
    modules = {
        casting = true,
        tracking = true,
        scoring = true,
    },
}

local function NewLabel(parent, text, font, point, relativeTo, relativePoint, x, y)
    local label = parent:CreateFontString(nil, "ARTWORK")
    label:SetFontObject(font or Theme.font.body)
    label:SetPoint(point, relativeTo or parent, relativePoint or point, x or 0, y or 0)
    label:SetJustifyH("LEFT")
    label:SetText(text or "")
    return label
end

local function GetCasting()
    return AvidAngler.Modules and AvidAngler.Modules.Casting
end

local function GetScoring()
    return AvidAngler.Modules and AvidAngler.Modules.Scoring
end

local function RefreshGearState()
    local casting = GetCasting()
    if casting and casting.IsGearEquipEnabled then
        state.gearEquip = casting:IsGearEquipEnabled()
    elseif casting and casting.HasGearSet then
        state.gearEquip = state.gearEquip and casting:HasGearSet() or false
    end
end

local function ApplyDefaults()
    local casting = GetCasting()
    if casting and casting.ResetSettingsToDefaults then
        casting:ResetSettingsToDefaults()
    end
    if AvidAngler.SetModuleEnabled then
        AvidAngler:SetModuleEnabled("casting", true)
        AvidAngler:SetModuleEnabled("tracking", true)
        AvidAngler:SetModuleEnabled("scoring", true)
    end
    local scoring = GetScoring()
    if scoring then
        if scoring.SetKeepScoreWatchOpen then
            scoring:SetKeepScoreWatchOpen(true)
        end
        if scoring.SetHideTrophy then
            scoring:SetHideTrophy(false, true)
        end
    end
end

local function ApplySelections()
    ApplyDefaults()

    local casting = GetCasting()
    if casting then
        if casting.SetInputMode then
            casting:SetInputMode(state.inputMode)
        end
        if casting.SetAutoLootEnabled then
            casting:SetAutoLootEnabled(state.autoLoot)
        end
        if casting.SetAudioFocusEnabled then
            casting:SetAudioFocusEnabled(state.audioFocus)
        end
        if casting.SetGeneralOption then
            casting:SetGeneralOption("disableSoftInteract", not state.softInteract)
            casting:SetGeneralOption("disableSoftIcon", state.hideSoftIcon)
            casting:SetGeneralOption("dismountWithKey", state.dismount)
            casting:SetGeneralOption("releaseWhenSwimming", state.releaseSwimming)
        end
        if casting.SetDisplayMode then
            casting:SetDisplayMode(state.displayMode)
        end
        if state.gearEquip and casting.SetGearEquipEnabled then
            casting:SetGearEquipEnabled(true)
        end
    end

    local scoring = GetScoring()
    if scoring then
        if scoring.SetKeepScoreWatchOpen then
            scoring:SetKeepScoreWatchOpen(state.keepWatch)
        end
        if scoring.SetHideTrophy then
            scoring:SetHideTrophy(state.hideTrophy, true)
        end
    end

    if AvidAngler.SetModuleEnabled then
        AvidAngler:SetModuleEnabled("casting", state.modules.casting)
        AvidAngler:SetModuleEnabled("tracking", state.modules.tracking)
        AvidAngler:SetModuleEnabled("scoring", state.modules.scoring)
    end
end

local function LoadCurrentSelections()
    if AvidAngler.IsModuleEnabled then
        state.modules.casting = AvidAngler:IsModuleEnabled("casting")
        state.modules.tracking = AvidAngler:IsModuleEnabled("tracking")
        state.modules.scoring = AvidAngler:IsModuleEnabled("scoring")
    end

    local casting = GetCasting()
    if casting then
        if casting.GetInputMode then
            state.inputMode = casting:GetInputMode() or "off"
        end
        if casting.GetOneKey then
            state.oneKey = casting:GetOneKey()
        end
        if casting.IsAutoLootEnabled then
            state.autoLoot = casting:IsAutoLootEnabled()
        end
        if casting.IsAudioFocusEnabled then
            state.audioFocus = casting:IsAudioFocusEnabled()
        end
        if casting.GetGeneralOption then
            state.softInteract = not casting:GetGeneralOption("disableSoftInteract")
            state.hideSoftIcon = casting:GetGeneralOption("disableSoftIcon")
            state.dismount = casting:GetGeneralOption("dismountWithKey")
            state.releaseSwimming = casting:GetGeneralOption("releaseWhenSwimming")
        end
        if casting.GetDisplayMode then
            state.displayMode = casting:GetDisplayMode() or "hud"
        end
        if casting.IsGearEquipEnabled then
            state.gearEquip = casting:IsGearEquipEnabled()
        end
    end

    local scoring = GetScoring()
    if scoring then
        if scoring.IsKeepingScoreWatchOpen then
            state.keepWatch = scoring:IsKeepingScoreWatchOpen()
        end
        if scoring.IsHidingTrophy then
            state.hideTrophy = scoring:IsHidingTrophy()
        end
    end
end

function SetupWizard:Initialize()
    if self.frame then
        return
    end

    local frame = Theme:CreatePanel(UIParent, "backdrop", "border")
    frame:SetSize(760, 520)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetFrameLevel(500)
    frame:SetToplevel(true)
    frame:EnableMouse(true)
    frame:EnableKeyboard(true)
    frame:SetPropagateKeyboardInput(true)
    frame:Hide()
    frame:SetScript("OnKeyDown", function(_, key)
        if key == "ESCAPE" then
            SetupWizard:Hide()
        end
    end)
    self.frame = frame

    self.logo = frame:CreateTexture(nil, "ARTWORK")
    self.logo:SetTexture("Interface\\AddOns\\AvidAngler\\Media\\AvidAngler-logo-soft.png")
    self.logo:SetSize(86, 86)
    self.logo:SetPoint("TOPLEFT", 24, -22)

    self.heading = NewLabel(frame, "", Theme.font.title, "TOPLEFT", self.logo, "TOPRIGHT", 18, -4)
    self.heading:SetWidth(580)

    self.progress = NewLabel(frame, "", Theme.font.small, "TOPRIGHT", frame, "TOPRIGHT", -28, -30)
    self.progress:SetJustifyH("RIGHT")

    self.body = NewLabel(frame, "", Theme.font.muted, "TOPLEFT", self.heading, "BOTTOMLEFT", 0, -14)
    self.body:SetWidth(590)
    self.body:SetJustifyH("LEFT")

    self.optionRows = {}
    for i = 1, 4 do
        local row = Theme:CreatePanel(frame, "panel", "border")
        row:SetSize(684, 64)
        row:SetPoint("TOPLEFT", frame, "TOPLEFT", 38, -150 - ((i - 1) * 74))
        row:EnableMouse(true)

        row.check = Theme:CreateCheckbox(row, "")
        row.check:SetPoint("TOPLEFT", row, "TOPLEFT", 12, -12)

        row.title = NewLabel(row, "", Theme.font.heading, "LEFT", row.check, "RIGHT", 10, 0)
        row.title:SetWidth(610)
        row.detail = NewLabel(row, "", Theme.font.muted, "TOPLEFT", row.title, "BOTTOMLEFT", 0, -4)
        row.detail:SetWidth(610)

        row:SetScript("OnMouseUp", function()
            SetupWizard:HandleOptionClick(row.option)
        end)
        row.check:SetScript("OnClick", function()
            SetupWizard:HandleOptionClick(row.option)
        end)

        row.hudPreview = Theme:CreatePanel(row, "panelRaised", "accent")
        row.hudPreview:SetSize(176, 42)
        row.hudPreview:SetPoint("RIGHT", row, "RIGHT", -12, 0)
        row.hudPreview.icon = row.hudPreview:CreateTexture(nil, "ARTWORK")
        row.hudPreview.icon:SetTexture("Interface\\Icons\\UI_Profession_Fishing")
        row.hudPreview.icon:SetSize(28, 28)
        row.hudPreview.icon:SetPoint("LEFT", row.hudPreview, "LEFT", 8, 0)
        row.hudPreview.title = NewLabel(row.hudPreview, L["ACTION_CAST"], Theme.font.heading, "TOPLEFT", row.hudPreview.icon, "TOPRIGHT", 8, -1)
        row.hudPreview.detail = NewLabel(row.hudPreview, L["ACTION_DETAIL_CAST"], Theme.font.small, "TOPLEFT", row.hudPreview.title, "BOTTOMLEFT", 0, -3)
        row.hudPreview.detail:SetTextColor(unpack(Theme.color.textSecondary))
        row.hudPreview:Hide()

        row.buttonPreview = Theme:CreatePanel(row, "panelRaised", "accent")
        row.buttonPreview:SetSize(42, 42)
        row.buttonPreview:SetPoint("RIGHT", row, "RIGHT", -42, 0)
        row.buttonPreview.icon = row.buttonPreview:CreateTexture(nil, "ARTWORK")
        row.buttonPreview.icon:SetTexture("Interface\\Icons\\UI_Profession_Fishing")
        row.buttonPreview.icon:SetPoint("TOPLEFT", 6, -6)
        row.buttonPreview.icon:SetPoint("BOTTOMRIGHT", -6, 6)
        row.buttonPreview:Hide()

        row:Hide()
        self.optionRows[i] = row
    end

    self.keyLabel = NewLabel(frame, L["KEY_LABEL"], Theme.font.body, "BOTTOMLEFT", frame, "BOTTOMLEFT", 42, 86)
    self.keyBox = Theme:CreateButton(frame, L["KEY_BINDINGS_OPEN"])
    self.keyBox:SetWidth(190)
    self.keyBox:SetScript("OnClick", AvidAngler.UI.OpenFishingKeybindings)
    self.keyBox:SetPoint("LEFT", self.keyLabel, "RIGHT", 8, 0)
    self.keyLabel:Hide()
    self.keyBox:Hide()

    self.skipButton = Theme:CreateButton(frame, L["SETUP_WIZARD_SKIP"])
    self.skipButton:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 24, 22)
    self.skipButton:SetWidth(126)
    self.skipButton:SetScript("OnClick", function()
        ApplyDefaults()
        AvidAngler:SetSetupWizardComplete(true)
        SetupWizard:Hide()
        AvidAngler:Print(L["SETUP_WIZARD_SKIPPED"])
    end)

    self.backButton = Theme:CreateButton(frame, L["CATCH_HISTORY_PREV"])
    self.backButton:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -250, 22)
    self.backButton:SetWidth(94)
    self.backButton:SetScript("OnClick", function()
        state.page = math.max(1, state.page - 1)
        SetupWizard:Refresh()
    end)

    self.nextButton = Theme:CreateButton(frame, L["CATCH_HISTORY_NEXT"])
    self.nextButton:SetPoint("LEFT", self.backButton, "RIGHT", 8, 0)
    self.nextButton:SetWidth(94)
    self.nextButton:SetScript("OnClick", function()
        if state.page < #pages then
            state.page = state.page + 1
            SetupWizard:Refresh()
        else
            SetupWizard:Finish()
        end
    end)

    self.closeButton = Theme:CreateCloseButton(frame)
    self.closeButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -8, -8)
    self.closeButton:SetScript("OnClick", function()
        SetupWizard:Hide()
    end)

    self.gearSaveConfirmPanel = Theme:CreatePanel(frame, "panelRaised", "border")
    self.gearSaveConfirmPanel:SetSize(420, 128)
    self.gearSaveConfirmPanel:SetPoint("TOP", frame, "TOP", 0, -176)
    self.gearSaveConfirmPanel:SetFrameStrata("DIALOG")
    self.gearSaveConfirmPanel:SetFrameLevel(frame:GetFrameLevel() + 50)
    self.gearSaveConfirmPanel:SetToplevel(true)
    self.gearSaveConfirmPanel:EnableMouse(true)
    self.gearSaveConfirmPanel:EnableKeyboard(true)
    self.gearSaveConfirmPanel:SetPropagateKeyboardInput(true)
    self.gearSaveConfirmPanel:SetScript("OnKeyDown", function(confirmFrame, key)
        if key == "ESCAPE" then
            confirmFrame:Hide()
        end
    end)
    self.gearSaveConfirmPanel:Hide()

    self.gearSaveConfirmTitle = NewLabel(self.gearSaveConfirmPanel, L["GEAR_SAVE_CONFIRM_TITLE"], Theme.font.heading, "TOP", self.gearSaveConfirmPanel, "TOP", 0, -14)
    self.gearSaveConfirmTitle:SetWidth(392)
    self.gearSaveConfirmTitle:SetJustifyH("CENTER")

    self.gearSaveConfirmText = NewLabel(self.gearSaveConfirmPanel, L["GEAR_SAVE_CONFIRM_BODY"], Theme.font.muted, "TOP", self.gearSaveConfirmTitle, "BOTTOM", 0, -8)
    self.gearSaveConfirmText:SetWidth(392)
    self.gearSaveConfirmText:SetJustifyH("CENTER")

    self.gearSaveConfirmYes = Theme:CreateButton(self.gearSaveConfirmPanel, YES)
    self.gearSaveConfirmYes:SetPoint("BOTTOMLEFT", self.gearSaveConfirmPanel, "BOTTOMLEFT", 74, 16)
    self.gearSaveConfirmYes:SetWidth(128)
    self.gearSaveConfirmYes:SetFrameLevel(self.gearSaveConfirmPanel:GetFrameLevel() + 10)
    self.gearSaveConfirmYes:RegisterForClicks("LeftButtonUp")
    self.gearSaveConfirmYes:SetScript("OnClick", function()
        local casting = GetCasting()
        if casting and casting.SaveGearSetWithDefault then
            casting:SaveGearSetWithDefault()
            state.gearEquip = true
            RefreshGearState()
        end
        self.gearSaveConfirmPanel:Hide()
        self:Refresh()
    end)

    self.gearSaveConfirmNo = Theme:CreateButton(self.gearSaveConfirmPanel, NO)
    self.gearSaveConfirmNo:SetPoint("LEFT", self.gearSaveConfirmYes, "RIGHT", Theme.layout.gutter, 0)
    self.gearSaveConfirmNo:SetWidth(128)
    self.gearSaveConfirmNo:SetFrameLevel(self.gearSaveConfirmPanel:GetFrameLevel() + 10)
    self.gearSaveConfirmNo:RegisterForClicks("LeftButtonUp")
    self.gearSaveConfirmNo:SetScript("OnClick", function()
        self.gearSaveConfirmPanel:Hide()
    end)
end

function SetupWizard:HandleOptionClick(option)
    if not option then
        return
    end
    if option.action == "saveGear" then
        local casting = GetCasting()
        if casting and casting.SaveGearSet then
            if casting.HasReturnGearSet and not casting:HasReturnGearSet() and casting.SaveGearSetWithDefault then
                if self.gearSaveConfirmPanel then
                    self.gearSaveConfirmPanel:Show()
                end
                return
            end
            casting:SaveGearSet()
            state.gearEquip = true
            RefreshGearState()
        end
        self:Refresh()
        return
    end

    local page = pages[state.page]
    if not page then
        return
    end

    if page.mode == "modules" then
        state.modules[option.key] = not state.modules[option.key]
    elseif page.mode == "input" then
        state.inputMode = option.key
    elseif page.mode == "helpers" or page.mode == "comfort" then
        state[option.key] = not state[option.key]
    elseif page.mode == "gear" then
        if option.key == "gearEquip" then
            state.gearEquip = not state.gearEquip
        end
    elseif page.mode == "display" then
        state.displayMode = option.key
    elseif page.mode == "tracking" then
        state[option.key] = not state[option.key]
    end
    self:Refresh()
end

function SetupWizard:GetOptionChecked(page, option)
    if not page or not option then
        return false
    end
    if page.mode == "modules" then
        return state.modules[option.key] and true or false
    elseif page.mode == "input" then
        return state.inputMode == option.key
    elseif page.mode == "helpers" or page.mode == "comfort" or page.mode == "tracking" then
        return state[option.key] and true or false
    elseif page.mode == "gear" then
        return option.key == "gearEquip" and state.gearEquip or option.action == "saveGear"
    elseif page.mode == "display" then
        return state.displayMode == option.key
    end
    return false
end

function SetupWizard:Refresh()
    self:Initialize()
    local page = pages[state.page]
    if not page then
        return
    end

    self.heading:SetText(L[page.titleKey] or "")
    self.body:SetText(L[page.bodyKey] or "")
    self.progress:SetText(L["SETUP_WIZARD_PROGRESS"]:format(state.page, #pages))
    self.backButton:SetEnabled(state.page > 1)
    self.nextButton.text:SetText(state.page == #pages and L["SETUP_WIZARD_FINISH"] or L["CATCH_HISTORY_NEXT"])
    self.skipButton.text:SetText(L["SETUP_WIZARD_SKIP"])
    self.keyLabel:SetShown(page.mode == "input")
    self.keyBox:SetShown(page.mode == "input")
    if self.gearSaveConfirmPanel then
        self.gearSaveConfirmPanel:Hide()
    end

    for i = 1, #self.optionRows do
        local row = self.optionRows[i]
        local option = page.options and page.options[i]
        if option then
            row.option = option
            row.title:SetText(L[option.labelKey] or "")
            row.detail:SetText(L[option.bodyKey] or "")
            row.check.text:SetText("")
            row.check:SetShown(page.mode ~= nil and option.action == nil)
            row.check:SetChecked(self:GetOptionChecked(page, option))
            row:SetWidth(684)
            row.title:SetWidth(page.mode == "display" and 420 or 610)
            row.detail:SetWidth(page.mode == "display" and 420 or 610)
            row.hudPreview:SetShown(page.mode == "display" and option.key == "hud")
            row.buttonPreview:SetShown(page.mode == "display" and option.key == "button")
            row:Show()
        else
            row.option = nil
            row.hudPreview:Hide()
            row.buttonPreview:Hide()
            row:Hide()
        end
    end
end

function SetupWizard:Finish()
    ApplySelections()
    AvidAngler:SetSetupWizardComplete(true)
    self:Hide()
    AvidAngler:Print(L["SETUP_WIZARD_DONE"])
    if AvidAngler.UI and AvidAngler.UI.MainWindow and AvidAngler.UI.MainWindow.Show then
        AvidAngler.UI.MainWindow:Show()
    end
end

function SetupWizard:Show(force)
    if AvidAngler.IsRuntimeDisabled and AvidAngler:IsRuntimeDisabled() then
        return
    end
    local completed = AvidAngler.IsSetupWizardComplete and AvidAngler:IsSetupWizardComplete()
    if (not force) and completed then
        return
    end
    self:Initialize()
    if force or completed then
        LoadCurrentSelections()
    end
    state.page = 1
    self.keyBox.text:SetText(L["KEY_BINDINGS_OPEN"])
    self:Refresh()
    self.frame:Show()
end

function SetupWizard:Hide()
    if self.frame then
        self.frame:Hide()
    end
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:SetScript("OnEvent", function()
    C_Timer.After(1, function()
        if AvidAngler.IsSetupWizardComplete and not AvidAngler:IsSetupWizardComplete() then
            SetupWizard:Show()
        end
    end)
end)
