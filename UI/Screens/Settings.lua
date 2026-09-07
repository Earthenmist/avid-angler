-- Avid Angler
-- Settings screen panels and controls.

local _, AvidAngler = ...

AvidAngler.UI = AvidAngler.UI or {}
local SettingsScreen = {}
AvidAngler.UI.SettingsScreen = SettingsScreen

local Theme = AvidAngler.UI.Theme
local L = AvidAngler.L

local function NewLabel(parent, text, font, point, relativeTo, relativePoint, x, y)
    local label = parent:CreateFontString(nil, "ARTWORK")
    label:SetFontObject(font or Theme.font.body)
    label:SetPoint(point, relativeTo or parent, relativePoint or point, x or 0, y or 0)
    label:SetJustifyH("LEFT")
    label:SetText(text or "")
    return label
end

local function SetButtonSelected(button, selected)
    if button.SetSelected then
        button:SetSelected(selected)
        return
    end
    if selected then
        button:SetBackdropBorderColor(unpack(Theme.color.accent))
        button.text:SetFontObject(Theme.font.heading)
    else
        button:SetBackdropBorderColor(unpack(Theme.color.accentDim))
        button.text:SetFontObject(Theme.font.body)
    end
end

local function StatusColor(statusKey)
    if statusKey == "next" or statusKey == "ready" then
        return Theme.color.accent
    elseif statusKey == "active" then
        return Theme.color.success
    elseif statusKey == "cooldown" or statusKey == "water" or statusKey == "criteria" then
        return Theme.color.warning
    elseif statusKey == "empty" or statusKey == "disabled" or statusKey == "none" then
        return Theme.color.textSecondary
    end
    return Theme.color.danger
end

local function IsModuleEnabled(key)
    return AvidAngler.IsModuleEnabled and AvidAngler:IsModuleEnabled(key)
end

local function ToggleLabel(enabled, label)
    return (enabled and "[x] " or "[ ] ") .. label
end

local function SetPanelDisabledVisual(panel, disabled)
    if panel then
        panel:SetAlpha(disabled and 0.45 or 1)
    end
end

local function AttachTooltip(owner, title, body)
    owner.tooltipTitle = title
    owner.tooltipBody = body
    owner:HookScript("OnEnter", function(frame)
        GameTooltip:SetOwner(frame, "ANCHOR_RIGHT")
        local tooltipTitle = type(frame.tooltipTitle) == "function" and frame.tooltipTitle() or frame.tooltipTitle
        local tooltipBody = type(frame.tooltipBody) == "function" and frame.tooltipBody() or frame.tooltipBody
        GameTooltip:SetText(tooltipTitle or "")
        if tooltipBody and tooltipBody ~= "" then
            GameTooltip:AddLine(tooltipBody, 0.8, 0.8, 0.8, true)
        end
        GameTooltip:Show()
    end)
    owner:HookScript("OnLeave", function()
        GameTooltip:Hide()
    end)
end

local function AttachDynamicTooltip(owner, title, bodyProvider)
    owner.tooltipTitle = title
    owner.tooltipBodyProvider = bodyProvider
    owner:HookScript("OnEnter", function(frame)
        GameTooltip:SetOwner(frame, "ANCHOR_RIGHT")
        local tooltipTitle = type(frame.tooltipTitle) == "function" and frame.tooltipTitle() or frame.tooltipTitle
        GameTooltip:SetText(tooltipTitle or "")
        local body = frame.tooltipBodyProvider and frame.tooltipBodyProvider() or nil
        if body and body ~= "" then
            GameTooltip:AddLine(body, 0.8, 0.8, 0.8, true)
        end
        GameTooltip:Show()
    end)
    owner:HookScript("OnLeave", function()
        GameTooltip:Hide()
    end)
end

function SettingsScreen:Initialize(content, owner)
    if self.initialized then
        return self.panels
    end
    self.owner = owner
    self.panels = {}
    self:CreateCastingPanel(content)
    self:WireScripts()
    self.initialized = true
    return self.panels
end

function SettingsScreen:NewPanel(content, key)
    local panel = CreateFrame("Frame", nil, content)
    panel:SetAllPoints()
    panel:Hide()
    self.panels[key] = panel
    return panel
end

function SettingsScreen:SetSection(section)
    if self.owner and self.owner.SelectTab then
        self.owner:SelectTab("settings")
    end
end

function SettingsScreen:GetActivePanelKey()
    return "casting"
end

function SettingsScreen:CreateCastingPanel(content)
    local panel = self:NewPanel(content, "casting")
    self.castingPanel = panel

    self.settingsHeading = NewLabel(panel, L["MAIN_TAB_SETTINGS"], Theme.font.title, "TOPLEFT", panel, "TOPLEFT", 0, -2)

    self.inputPanel = Theme:CreatePanel(panel, "panel", "border")
    self.inputPanel:SetSize(560, 176)
    self.inputPanel:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -58)

    self.generalTitle = NewLabel(self.inputPanel, L["GENERAL_SETTINGS_TITLE"], Theme.font.heading, "TOPLEFT", self.inputPanel, "TOPLEFT", 12, -10)

    self.autoLootButton = Theme:CreateButton(self.inputPanel, "")
    self.autoLootButton:SetPoint("TOPLEFT", self.generalTitle, "BOTTOMLEFT", 0, -10)
    self.autoLootButton:SetWidth(170)
    AttachDynamicTooltip(self.autoLootButton, L["AUTO_LOOT_TOGGLE_LABEL"], function()
        return self.autoLootExternallyEnabled and L["AUTO_LOOT_ALREADY_ENABLED_TOOLTIP"] or L["AUTO_LOOT_TOGGLE_TOOLTIP"]
    end)

    self.generalOptionButtons = {}
    local softIconButton = Theme:CreateButton(self.inputPanel, "")
    softIconButton:SetPoint("LEFT", self.autoLootButton, "RIGHT", Theme.layout.gutter, 0)
    softIconButton:SetWidth(170)
    softIconButton.optionKey = "disableSoftIcon"
    softIconButton.optionLabel = L["GENERAL_OPTION_DISABLE_SOFT_ICON"]
    AttachTooltip(softIconButton, L["GENERAL_OPTION_DISABLE_SOFT_ICON"], L["GENERAL_OPTION_DISABLE_SOFT_ICON_TOOLTIP"])
    self.generalOptionButtons[#self.generalOptionButtons + 1] = softIconButton

    local generalOptions = {
        { key = "disableSoftInteract", label = L["GENERAL_OPTION_DISABLE_SOFT_INTERACT"], tooltip = L["GENERAL_OPTION_DISABLE_SOFT_INTERACT_TOOLTIP"], x = 12, y = -78, width = 170 },
        { key = "dismountWithKey", label = L["GENERAL_OPTION_DISMOUNT_WITH_KEY"], tooltip = L["GENERAL_OPTION_DISMOUNT_WITH_KEY_TOOLTIP"], x = 190, y = -78, width = 150 },
        { key = "releaseWhenSwimming", label = L["GENERAL_OPTION_RELEASE_WHEN_SWIMMING"], tooltip = L["GENERAL_OPTION_RELEASE_WHEN_SWIMMING_TOOLTIP"], x = 348, y = -78, width = 190 },
    }
    for i = 1, #generalOptions do
        local option = generalOptions[i]
        local button = Theme:CreateButton(self.inputPanel, "")
        button:SetPoint("TOPLEFT", self.inputPanel, "TOPLEFT", option.x, option.y)
        button:SetWidth(option.width)
        button.optionKey = option.key
        button.optionLabel = option.label
        AttachTooltip(button, option.label, option.tooltip)
        self.generalOptionButtons[#self.generalOptionButtons + 1] = button
    end

    self.audioFocusButton = Theme:CreateButton(self.inputPanel, "")
    self.audioFocusButton:SetPoint("TOPLEFT", self.inputPanel, "TOPLEFT", 12, -116)
    self.audioFocusButton:SetWidth(170)
    AttachTooltip(self.audioFocusButton, L["AUDIO_FOCUS_TOGGLE_LABEL"], L["AUDIO_FOCUS_TOGGLE_TOOLTIP"])

    self.audioFocusConfigButton = Theme:CreateButton(self.inputPanel, "")
    self.audioFocusConfigButton:SetPoint("LEFT", self.audioFocusButton, "RIGHT", Theme.layout.gutter, 0)
    self.audioFocusConfigButton:SetSize(26, 26)
    self.audioFocusConfigButton.icon = self.audioFocusConfigButton:CreateTexture(nil, "ARTWORK")
    self.audioFocusConfigButton.icon:SetTexture("Interface\\Buttons\\UI-OptionsButton")
    self.audioFocusConfigButton.icon:SetPoint("CENTER")
    self.audioFocusConfigButton.icon:SetSize(18, 18)
    AttachTooltip(self.audioFocusConfigButton, L["AUDIO_FOCUS_SETTINGS"], L["AUDIO_FOCUS_SETTINGS_TOOLTIP"])

    self.generalBody = NewLabel(self.inputPanel, L["GENERAL_SETTINGS_BODY"], Theme.font.muted, "TOPLEFT", self.audioFocusConfigButton, "TOPRIGHT", Theme.layout.gutter, 0)
    self.generalBody:SetWidth(150)
    self.generalBody:SetJustifyH("LEFT")

    self.inputPreviewPanel = Theme:CreatePanel(panel, "panel", "border")
    self.inputPreviewPanel:SetSize(450, 176)
    self.inputPreviewPanel:SetPoint("TOPLEFT", self.inputPanel, "TOPRIGHT", 6, 0)

    self.inputPreviewTitle = NewLabel(self.inputPreviewPanel, L["ACTION_INPUT_TITLE"], Theme.font.heading, "TOPLEFT", self.inputPreviewPanel, "TOPLEFT", 12, -10)
    self.inputPreviewBody = NewLabel(self.inputPreviewPanel, L["ACTION_INPUT_BODY"], Theme.font.muted, "TOPLEFT", self.inputPreviewTitle, "BOTTOMLEFT", 0, -8)
    self.inputPreviewBody:SetWidth(400)
    self.inputPreviewBody:SetJustifyH("LEFT")

    self.oneKeyButton = Theme:CreateButton(self.inputPreviewPanel, "")
    self.oneKeyButton:SetPoint("TOPLEFT", self.inputPreviewBody, "BOTTOMLEFT", 0, -14)
    self.oneKeyButton:SetWidth(170)
    AttachTooltip(self.oneKeyButton, L["ONE_KEY_TOGGLE_LABEL"], L["ONE_KEY_TOGGLE_TOOLTIP"])
    self.doubleButton = Theme:CreateButton(self.inputPreviewPanel, "")
    self.doubleButton:SetPoint("LEFT", self.oneKeyButton, "RIGHT", Theme.layout.gutter, 0)
    self.doubleButton:SetWidth(180)
    AttachTooltip(self.doubleButton, L["DOUBLE_RIGHT_TOGGLE_LABEL"], L["DOUBLE_RIGHT_TOGGLE_TOOLTIP"])

    self.keyLabel = NewLabel(self.inputPreviewPanel, L["KEY_LABEL"], Theme.font.muted, "TOPLEFT", self.oneKeyButton, "BOTTOMLEFT", 0, -22)
    self.keyBox = Theme:CreateEditBox(self.inputPreviewPanel, 160)
    self.keyBox:SetPoint("LEFT", self.keyLabel, "RIGHT", Theme.layout.gutter, 0)
    AttachTooltip(self.keyBox, L["KEY_LABEL"], L["ONE_KEY_BINDING_TOOLTIP"])
    self.keySaveButton = Theme:CreateButton(self.inputPreviewPanel, L["SAVE_KEY_LABEL"])
    self.keySaveButton:SetPoint("LEFT", self.keyBox, "RIGHT", Theme.layout.gutter, 0)
    self.keySaveButton:SetWidth(72)
    AttachTooltip(self.keySaveButton, L["SAVE_KEY_LABEL"], L["SAVE_KEY_TOOLTIP"])

    self:CreatePickerPanel()
    self:CreateActionSlotsPanel()
    self:CreateDisplayPanel()
    self:CreateResolverPanel()
    self:CreateAudioFocusConfigPanel()

    panel:SetScript("OnShow", function()
        self:Refresh()
    end)
    panel:SetScript("OnHide", function()
        if self.defaultsConfirmPanel then
            self.defaultsConfirmPanel:Hide()
        end
        if self.moduleFlyout then
            self.moduleFlyout:Hide()
        end
        if self.audioFocusConfigPanel then
            self.audioFocusConfigPanel:Hide()
        end
    end)
    panel:SetScript("OnUpdate", function(frame, elapsed)
        frame.refreshElapsed = (frame.refreshElapsed or 0) + elapsed
        if frame.refreshElapsed < 0.25 then
            return
        end
        frame.refreshElapsed = 0
        self:RefreshCasting()
    end)
end

function SettingsScreen:CreateAudioFocusConfigPanel()
    local panel = self.castingPanel
    self.audioFocusConfigPanel = Theme:CreatePanel(panel, "panelRaised", "border")
    self.audioFocusConfigPanel:SetSize(320, 248)
    self.audioFocusConfigPanel:SetPoint("TOPLEFT", self.audioFocusConfigButton, "TOPRIGHT", 8, 0)
    self.audioFocusConfigPanel:SetFrameStrata("DIALOG")
    self.audioFocusConfigPanel:SetFrameLevel(panel:GetFrameLevel() + 60)
    self.audioFocusConfigPanel:SetToplevel(true)
    self.audioFocusConfigPanel:EnableMouse(true)
    self.audioFocusConfigPanel:Hide()

    self.audioFocusConfigTitle = NewLabel(self.audioFocusConfigPanel, L["AUDIO_FOCUS_SETTINGS"], Theme.font.heading, "TOPLEFT", self.audioFocusConfigPanel, "TOPLEFT", 12, -12)

    self.audioFocusFields = {}
    local fields = {
        { key = "master", label = L["AUDIO_FOCUS_MASTER_VOLUME"] },
        { key = "music", label = L["AUDIO_FOCUS_MUSIC_VOLUME"] },
        { key = "sfx", label = L["AUDIO_FOCUS_EFFECTS_VOLUME"] },
        { key = "ambience", label = L["AUDIO_FOCUS_AMBIENCE_VOLUME"] },
        { key = "dialog", label = L["AUDIO_FOCUS_DIALOG_VOLUME"] },
    }
    for i = 1, #fields do
        local field = fields[i]
        local label = NewLabel(self.audioFocusConfigPanel, field.label, Theme.font.body, "TOPLEFT", self.audioFocusConfigPanel, "TOPLEFT", 12, -42 - ((i - 1) * 30))
        label:SetWidth(174)
        local box = Theme:CreateEditBox(self.audioFocusConfigPanel, 54)
        box:SetPoint("LEFT", label, "RIGHT", Theme.layout.gutter, 0)
        box:SetNumeric(true)
        AttachTooltip(box, field.label, L["AUDIO_FOCUS_PERCENT_TOOLTIP"])
        local percent = NewLabel(self.audioFocusConfigPanel, "%", Theme.font.muted, "LEFT", box, "RIGHT", 4, 0)
        self.audioFocusFields[field.key] = { label = label, box = box, percent = percent }
    end

    self.audioFocusDefaultsButton = Theme:CreateButton(self.audioFocusConfigPanel, L["AUDIO_FOCUS_DEFAULTS"])
    self.audioFocusDefaultsButton:SetPoint("BOTTOMLEFT", self.audioFocusConfigPanel, "BOTTOMLEFT", 12, 12)
    self.audioFocusDefaultsButton:SetWidth(126)
    AttachTooltip(self.audioFocusDefaultsButton, L["AUDIO_FOCUS_DEFAULTS"], L["AUDIO_FOCUS_DEFAULTS_TOOLTIP"])

    self.audioFocusSaveButton = Theme:CreateButton(self.audioFocusConfigPanel, L["SAVE_KEY_LABEL"])
    self.audioFocusSaveButton:SetPoint("LEFT", self.audioFocusDefaultsButton, "RIGHT", Theme.layout.gutter, 0)
    self.audioFocusSaveButton:SetWidth(80)
    AttachTooltip(self.audioFocusSaveButton, L["SAVE_KEY_LABEL"], L["AUDIO_FOCUS_SAVE_TOOLTIP"])

    self.audioFocusCloseButton = Theme:CreateCloseButton(self.audioFocusConfigPanel, 20)
    self.audioFocusCloseButton:SetPoint("TOPRIGHT", self.audioFocusConfigPanel, "TOPRIGHT", -6, -6)
end

function SettingsScreen:CreatePickerPanel()
    local panel = self.castingPanel
    local pickerPanel = Theme:CreatePanel(panel, "panel", "border")
    pickerPanel:SetSize(560, 176)
    pickerPanel:SetPoint("TOPLEFT", self.inputPanel, "BOTTOMLEFT", 0, -4)
    self.pickerPanel = pickerPanel

    local contentLeft = 24
    self.pickerRefreshButton = Theme:CreateButton(pickerPanel, L["ACTION_PICKERS_REFRESH"])
    self.pickerRefreshButton:SetPoint("TOPLEFT", pickerPanel, "TOPLEFT", contentLeft, -8)
    self.pickerRefreshButton:SetWidth(130)
    AttachTooltip(self.pickerRefreshButton, L["ACTION_PICKERS_REFRESH"], L["ACTION_PICKERS_REFRESH_TOOLTIP"])
    self.pickerTitle = NewLabel(pickerPanel, L["ACTION_PICKERS_TITLE"], Theme.font.heading, "LEFT", self.pickerRefreshButton, "RIGHT", Theme.layout.gutter, 0)

    self.pickerRows = {}
    local rows = {
        { key = "oversized", label = L["ACTION_PICKER_OVERSIZED"] },
        { key = "bobber", label = L["ACTION_PICKER_BOBBER"] },
        { key = "lure", label = L["ACTION_PICKER_LURE"] },
        { key = "ward", label = L["ACTION_PICKER_WARD"] },
        { key = "toy", label = L["ACTION_PICKER_TOY"] },
    }
    local tooltips = {
        oversized = L["ACTION_PICKER_TOOLTIP_OVERSIZED"],
        bobber = L["ACTION_PICKER_TOOLTIP_BOBBER"],
        lure = L["ACTION_PICKER_TOOLTIP_LURE"],
        ward = L["ACTION_PICKER_TOOLTIP_WARD"],
        toy = L["ACTION_PICKER_TOOLTIP_TOY"],
    }
    local function AttachTooltip(owner, row)
        owner:HookScript("OnEnter", function(frame)
            GameTooltip:SetOwner(frame, "ANCHOR_RIGHT")
            GameTooltip:SetText(row.label)
            GameTooltip:AddLine(tooltips[row.key] or "", 0.8, 0.8, 0.8, true)
            GameTooltip:Show()
        end)
        owner:HookScript("OnLeave", function()
            GameTooltip:Hide()
        end)
    end

    for i = 1, #rows do
        local config = rows[i]
        local row = CreateFrame("Frame", nil, pickerPanel)
        row:SetHeight(24)
        row:SetPoint("TOPLEFT", pickerPanel, "TOPLEFT", contentLeft, -36 - ((i - 1) * 27))
        row:SetPoint("RIGHT", -12, 0)
        row.key = config.key
        row.label = config.label

        row.toggle = Theme:CreateButton(row, "")
        row.toggle:SetPoint("LEFT")
        row.toggle:SetWidth(130)

        row.name = row:CreateFontString(nil, "ARTWORK")
        row.name:SetFontObject(Theme.font.body)
        row.name:SetPoint("LEFT", row.toggle, "RIGHT", Theme.layout.gutter, 0)
        row.name:SetWidth(184)
        row.name:SetJustifyH("LEFT")
        row.name:SetText(L["ACTION_PICKER_EMPTY"])

        row.status = row:CreateFontString(nil, "ARTWORK")
        row.status:SetFontObject(Theme.font.small)
        row.status:SetPoint("LEFT", row.name, "RIGHT", Theme.layout.gutter, 0)
        row.status:SetWidth(70)
        row.status:SetJustifyH("RIGHT")

        row.dropdown = Theme:CreateButton(row, L["ACTION_PICKER_SELECT"])
        row.dropdown:SetPoint("LEFT", row.status, "RIGHT", Theme.layout.gutter, 0)
        row.dropdown:SetWidth(112)
        row.dropdown:SetShown(config.key ~= "oversized")

        AttachTooltip(row.toggle, row)
        AttachTooltip(row.dropdown, row)
        self.pickerRows[#self.pickerRows + 1] = row
    end

    self.pickerDropdown = Theme:CreatePanel(panel, "panelRaised", "accent")
    self.pickerDropdown:SetFrameLevel(panel:GetFrameLevel() + 20)
    self.pickerDropdown:SetSize(220, 24)
    self.pickerDropdown:Hide()
    self.pickerDropdownRows = {}
    for i = 1, 12 do
        local option = Theme:CreateButton(self.pickerDropdown, "")
        option:SetHeight(24)
        option:SetPoint("TOPLEFT", 4, -4 - ((i - 1) * 24))
        option:SetPoint("RIGHT", -4, 0)
        option.text:ClearAllPoints()
        option.text:SetPoint("LEFT", 8, 0)
        option.text:SetPoint("RIGHT", -8, 0)
        option.text:SetJustifyH("LEFT")
        option:Hide()
        self.pickerDropdownRows[i] = option
    end
end

function SettingsScreen:CreateDisplayPanel()
    local panel = self.castingPanel
    self.displayPanel = Theme:CreatePanel(panel, "panel", "border")
    self.displayPanel:SetSize(450, 176)
    self.displayPanel:SetPoint("TOPLEFT", self.pickerPanel, "TOPRIGHT", 6, 0)

    self.displayTitle = NewLabel(self.displayPanel, L["ACTION_DISPLAY_TITLE"], Theme.font.heading, "TOPLEFT", self.displayPanel, "TOPLEFT", 12, -10)
    self.displayHudButton = Theme:CreateButton(self.displayPanel, L["ACTION_DISPLAY_HUD"])
    self.displayHudButton:SetPoint("TOPLEFT", self.displayTitle, "BOTTOMLEFT", 0, -8)
    self.displayHudButton:SetWidth(88)
    AttachTooltip(self.displayHudButton, L["ACTION_DISPLAY_HUD"], L["ACTION_DISPLAY_HUD_TOOLTIP"])
    self.displayButtonOnlyButton = Theme:CreateButton(self.displayPanel, L["ACTION_DISPLAY_BUTTON"])
    self.displayButtonOnlyButton:SetPoint("TOPLEFT", self.displayHudButton, "BOTTOMLEFT", 0, -27)
    self.displayButtonOnlyButton:SetWidth(104)
    AttachTooltip(self.displayButtonOnlyButton, L["ACTION_DISPLAY_BUTTON"], L["ACTION_DISPLAY_BUTTON_TOOLTIP"])
    self.sleepButton = Theme:CreateButton(self.displayPanel, "")
    self.sleepButton:SetPoint("TOPLEFT", self.displayButtonOnlyButton, "BOTTOMLEFT", 0, -29)
    self.sleepButton:SetWidth(94)
    AttachTooltip(self.sleepButton, L["ACTION_SLEEP_TOGGLE"], L["ACTION_DISPLAY_SLEEP_TOOLTIP"])
    self.showControlsButton = Theme:CreateButton(self.displayPanel, L["ACTION_SHOW_CONTROLS"])
    self.showControlsButton:SetPoint("LEFT", self.sleepButton, "RIGHT", Theme.layout.gutter, 0)
    self.showControlsButton:SetWidth(112)
    AttachTooltip(self.showControlsButton, L["ACTION_SHOW_CONTROLS"], L["ACTION_SHOW_CONTROLS_TOOLTIP"])
    self.buttonSizeDown = Theme:CreateButton(self.displayPanel, "-")
    self.buttonSizeDown:SetPoint("LEFT", self.displayButtonOnlyButton, "RIGHT", Theme.layout.gutter, 0)
    self.buttonSizeDown:SetWidth(30)
    AttachTooltip(self.buttonSizeDown, L["ACTION_DISPLAY_SCALE"], L["ACTION_DISPLAY_SCALE_TOOLTIP"])
    self.buttonSizeValue = NewLabel(self.displayPanel, "", Theme.font.body, "LEFT", self.buttonSizeDown, "RIGHT", Theme.layout.gutter, 0)
    self.buttonSizeValue:SetWidth(38)
    self.buttonSizeTooltipFrame = CreateFrame("Frame", nil, self.displayPanel)
    self.buttonSizeTooltipFrame:SetPoint("TOPLEFT", self.buttonSizeValue, "TOPLEFT", -2, 4)
    self.buttonSizeTooltipFrame:SetPoint("BOTTOMRIGHT", self.buttonSizeValue, "BOTTOMRIGHT", 2, -4)
    self.buttonSizeTooltipFrame:EnableMouse(true)
    AttachTooltip(self.buttonSizeTooltipFrame, L["ACTION_DISPLAY_SCALE"], L["ACTION_DISPLAY_SCALE_TOOLTIP"])
    self.buttonSizeUp = Theme:CreateButton(self.displayPanel, "+")
    self.buttonSizeUp:SetPoint("LEFT", self.buttonSizeValue, "RIGHT", Theme.layout.gutter, 0)
    self.buttonSizeUp:SetWidth(30)
    AttachTooltip(self.buttonSizeUp, L["ACTION_DISPLAY_SCALE"], L["ACTION_DISPLAY_SCALE_TOOLTIP"])

    self.displayPreview = CreateFrame("Frame", nil, self.displayPanel)
    self.displayPreview:SetPoint("TOPRIGHT", self.displayPanel, "TOPRIGHT", -16, -12)
    self.displayPreview:SetSize(178, 104)
    AttachTooltip(self.displayPreview, L["ACTION_DISPLAY_PREVIEW"], L["ACTION_DISPLAY_PREVIEW_TOOLTIP"])

    self.displayPreview.hudLabel = NewLabel(self.displayPreview, L["ACTION_DISPLAY_HUD"], Theme.font.small, "TOPRIGHT", self.displayPreview, "TOPRIGHT", 0, 0)
    self.displayPreview.hudBox = Theme:CreatePanel(self.displayPreview, "panelRaised", "accent")
    self.displayPreview.hudBox:SetSize(170, 42)
    self.displayPreview.hudBox:SetPoint("TOPRIGHT", self.displayPreview.hudLabel, "BOTTOMRIGHT", 0, -4)
    self.displayPreview.hudIcon = self.displayPreview.hudBox:CreateTexture(nil, "ARTWORK")
    self.displayPreview.hudIcon:SetTexture("Interface\\Icons\\UI_Profession_Fishing")
    self.displayPreview.hudIcon:SetSize(28, 28)
    self.displayPreview.hudIcon:SetPoint("LEFT", self.displayPreview.hudBox, "LEFT", 8, 0)
    self.displayPreview.hudTitle = NewLabel(self.displayPreview.hudBox, L["ACTION_CAST"], Theme.font.heading, "TOPLEFT", self.displayPreview.hudIcon, "TOPRIGHT", 8, -1)
    self.displayPreview.hudDetail = NewLabel(self.displayPreview.hudBox, L["ACTION_DETAIL_CAST"], Theme.font.small, "TOPLEFT", self.displayPreview.hudTitle, "BOTTOMLEFT", 0, -3)
    self.displayPreview.hudDetail:SetTextColor(unpack(Theme.color.textSecondary))

    self.displayPreview.buttonLabel = NewLabel(self.displayPreview, L["ACTION_DISPLAY_BUTTON"], Theme.font.small, "TOPRIGHT", self.displayPreview.hudBox, "BOTTOMRIGHT", 0, -10)
    self.displayPreview.buttonBox = Theme:CreatePanel(self.displayPreview, "panelRaised", "accent")
    self.displayPreview.buttonBox:SetSize(36, 36)
    self.displayPreview.buttonBox:SetPoint("TOPRIGHT", self.displayPreview.buttonLabel, "BOTTOMRIGHT", 0, -4)
    self.displayPreview.buttonIcon = self.displayPreview.buttonBox:CreateTexture(nil, "ARTWORK")
    self.displayPreview.buttonIcon:SetTexture("Interface\\Icons\\UI_Profession_Fishing")
    self.displayPreview.buttonIcon:SetPoint("TOPLEFT", 5, -5)
    self.displayPreview.buttonIcon:SetPoint("BOTTOMRIGHT", -5, 5)
end

function SettingsScreen:CreateActionSlotsPanel()
    local panel = self.castingPanel
    self.actionSlotsPanel = Theme:CreatePanel(panel, "panel", "border")
    self.actionSlotsPanel:SetSize(560, 214)
    self.actionSlotsPanel:SetPoint("TOPLEFT", self.pickerPanel, "BOTTOMLEFT", 0, -16)
    self.actionSlotsPanel.extraToyTitle = NewLabel(self.actionSlotsPanel, L["ACTION_SLOT_TOYS_TITLE"], Theme.font.heading, "TOPLEFT", self.actionSlotsPanel, "TOPLEFT", 14, -12)
    self.actionSlotsPanel.extraActionTitle = NewLabel(self.actionSlotsPanel, L["ACTION_SLOT_EXTRAS_TITLE"], Theme.font.heading, "TOPLEFT", self.actionSlotsPanel, "TOPLEFT", 294, -12)

    self.actionSlotRows = {}
    local function CreateActionSlotRow(index, x, y)
        local row = CreateFrame("Frame", nil, self.actionSlotsPanel)
        row:SetSize(252, 42)
        row:SetPoint("TOPLEFT", self.actionSlotsPanel, "TOPLEFT", x, y)
        row.index = index
        row.slotKind = index <= 3 and "toy" or "extra"

        row.toggle = Theme:CreateButton(row, L["ACTION_SLOT_ENABLE"])
        row.toggle:SetPoint("TOPLEFT")
        row.toggle:SetWidth(66)
        AttachTooltip(row.toggle, L["ACTION_SLOT_ENABLE"], L["ACTION_SLOT_USE_TOOLTIP"])

        row.slotButton = Theme:CreateButton(row, L["ACTION_SLOT_EMPTY"])
        row.slotButton:SetPoint("LEFT", row.toggle, "RIGHT", Theme.layout.gutter, 0)
        row.slotButton:SetWidth(174)
        row.slotButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        row.slotButton:RegisterForDrag("LeftButton")
        AttachTooltip(row.slotButton,
            row.slotKind == "toy" and L["ACTION_SLOT_TOY_LABEL"]:format(index) or L["ACTION_SLOT_EXTRA_LABEL"]:format(index - 3),
            row.slotKind == "toy" and L["ACTION_SLOT_TOY_TOOLTIP"] or L["ACTION_SLOT_EXTRA_TOOLTIP"])

        row.slotButton.icon = row.slotButton:CreateTexture(nil, "ARTWORK")
        row.slotButton.icon:SetSize(20, 20)
        row.slotButton.icon:SetPoint("LEFT", 8, 0)
        row.slotButton.icon:Hide()

        row.slotButton.text:ClearAllPoints()
        row.slotButton.text:SetPoint("LEFT", row.slotButton.icon, "RIGHT", 6, 0)
        row.slotButton.text:SetPoint("RIGHT", -8, 0)
        row.slotButton.text:SetJustifyH("LEFT")

        self.actionSlotRows[index] = row
    end

    for i = 1, 3 do
        CreateActionSlotRow(i, 14, -38 - ((i - 1) * 46))
        CreateActionSlotRow(i + 3, 294, -38 - ((i - 1) * 46))
    end

    self.actionSlotsPanel.openToyBoxButton = Theme:CreateButton(self.actionSlotsPanel, L["ACTION_SLOT_OPEN_TOYBOX"])
    self.actionSlotsPanel.openToyBoxButton:SetPoint("BOTTOMLEFT", 14, 12)
    self.actionSlotsPanel.openToyBoxButton:SetWidth(120)
    AttachTooltip(self.actionSlotsPanel.openToyBoxButton, L["ACTION_SLOT_OPEN_TOYBOX"], L["ACTION_SLOT_TOYBOX_TOOLTIP"])
    self.actionSlotsPanel.openMacrosButton = Theme:CreateButton(self.actionSlotsPanel, L["ACTION_SLOT_OPEN_MACROS"])
    self.actionSlotsPanel.openMacrosButton:SetPoint("LEFT", self.actionSlotsPanel.openToyBoxButton, "RIGHT", Theme.layout.gutter, 0)
    self.actionSlotsPanel.openMacrosButton:SetWidth(92)
    AttachTooltip(self.actionSlotsPanel.openMacrosButton, L["ACTION_SLOT_OPEN_MACROS"], L["ACTION_SLOT_MACROS_TOOLTIP"])
    self.actionSlotsPanel.openBagsButton = Theme:CreateButton(self.actionSlotsPanel, L["ACTION_SLOT_OPEN_BAGS"])
    self.actionSlotsPanel.openBagsButton:SetPoint("LEFT", self.actionSlotsPanel.openMacrosButton, "RIGHT", Theme.layout.gutter, 0)
    self.actionSlotsPanel.openBagsButton:SetWidth(80)
    AttachTooltip(self.actionSlotsPanel.openBagsButton, L["ACTION_SLOT_OPEN_BAGS"], L["ACTION_SLOT_BAGS_TOOLTIP"])

    self.saveGearButton = Theme:CreateButton(self.actionSlotsPanel, L["GEAR_SAVE_LABEL"])
    self.saveGearButton:SetPoint("LEFT", self.actionSlotsPanel.openBagsButton, "RIGHT", Theme.layout.gutter, 0)
    self.saveGearButton:SetWidth(110)
    AttachDynamicTooltip(self.saveGearButton, function()
        return self.gearSetExists and L["GEAR_VIEW_LABEL"] or L["GEAR_SAVE_LABEL"]
    end, function()
        return self.gearSetExists and L["GEAR_VIEW_TOOLTIP"] or L["GEAR_SAVE_TOOLTIP"]
    end)
    self.equipGearButton = Theme:CreateButton(self.actionSlotsPanel, L["GEAR_EQUIP_LABEL"])
    self.equipGearButton:SetPoint("LEFT", self.saveGearButton, "RIGHT", Theme.layout.gutter, 0)
    self.equipGearButton:SetWidth(110)
    AttachTooltip(self.equipGearButton, L["GEAR_EQUIP_LABEL"], L["GEAR_EQUIP_TOOLTIP"])
end

function SettingsScreen:CreateResolverPanel()
    local panel = self.castingPanel
    self.resolverPanel = Theme:CreatePanel(panel, "panel", "border")
    self.resolverPanel:SetSize(450, 214)
    self.resolverPanel:SetPoint("TOPLEFT", self.actionSlotsPanel, "TOPRIGHT", 6, 0)

    self.resolverTitle = NewLabel(self.resolverPanel, L["ACTION_RESOLVER_TITLE"], Theme.font.heading, "TOPLEFT", self.resolverPanel, "TOPLEFT", 12, -10)
    self.resolverRows = {}
    for i = 1, 7 do
        local row = CreateFrame("Frame", nil, self.resolverPanel)
        row:SetHeight(17)
        row:SetPoint("TOPLEFT", self.resolverTitle, "BOTTOMLEFT", 0, -6 - ((i - 1) * 18))
        row:SetWidth(426)
        row.labelText = row:CreateFontString(nil, "ARTWORK")
        row.labelText:SetFontObject(Theme.font.small)
        row.labelText:SetPoint("LEFT")
        row.labelText:SetWidth(88)
        row.labelText:SetJustifyH("LEFT")
        row.detailText = row:CreateFontString(nil, "ARTWORK")
        row.detailText:SetFontObject(Theme.font.muted)
        row.detailText:SetPoint("LEFT", row.labelText, "RIGHT", Theme.layout.gutter, 0)
        row.detailText:SetWidth(260)
        row.detailText:SetJustifyH("LEFT")
        row.statusText = row:CreateFontString(nil, "ARTWORK")
        row.statusText:SetFontObject(Theme.font.small)
        row.statusText:SetPoint("RIGHT")
        row.statusText:SetWidth(56)
        row.statusText:SetJustifyH("RIGHT")
        row:Hide()
        self.resolverRows[i] = row
    end

    self.castingStatus = NewLabel(self.resolverPanel, "", Theme.font.title, "BOTTOMLEFT", self.resolverPanel, "BOTTOMLEFT", 12, 34)
    self.castingActionDetail = NewLabel(self.resolverPanel, "", Theme.font.muted, "TOPLEFT", self.castingStatus, "BOTTOMLEFT", 0, -6)
    self.castingActionDetail:SetPoint("RIGHT", self.resolverPanel, "RIGHT", -12, 0)

    self.defaultsButton = Theme:CreateButton(panel, L["SETTINGS_DEFAULTS"])
    self.defaultsButton:SetPoint("TOPRIGHT", self.resolverPanel, "BOTTOMRIGHT", 0, -22)
    self.defaultsButton:SetWidth(110)
    AttachTooltip(self.defaultsButton, L["SETTINGS_DEFAULTS"], L["SETTINGS_DEFAULTS_TOOLTIP"])

    self.disableModulesButton = Theme:CreateButton(panel, L["SETTINGS_DISABLE_MODULES"])
    self.disableModulesButton:SetPoint("RIGHT", self.defaultsButton, "LEFT", -Theme.layout.gutter, 0)
    self.disableModulesButton:SetWidth(150)
    AttachTooltip(self.disableModulesButton, L["SETTINGS_DISABLE_MODULES"], L["SETTINGS_DISABLE_MODULES_TOOLTIP"])

    self.setupWizardButton = Theme:CreateButton(panel, L["SETUP_WIZARD_REOPEN"])
    self.setupWizardButton:SetPoint("RIGHT", self.disableModulesButton, "LEFT", -Theme.layout.gutter, 0)
    self.setupWizardButton:SetWidth(128)
    AttachTooltip(self.setupWizardButton, L["SETUP_WIZARD_REOPEN"], L["SETUP_WIZARD_REOPEN_TOOLTIP"])

    self:CreateModuleFlyout(panel)

    self.defaultsConfirmPanel = Theme:CreatePanel(panel, "panelRaised", "border")
    self.defaultsConfirmPanel:SetSize(320, 92)
    self.defaultsConfirmPanel:SetPoint("TOP", panel, "TOP", 0, -28)
    self.defaultsConfirmPanel:SetFrameLevel(panel:GetFrameLevel() + 50)
    self.defaultsConfirmPanel:SetToplevel(true)
    self.defaultsConfirmPanel:EnableMouse(true)
    self.defaultsConfirmPanel:EnableKeyboard(true)
    self.defaultsConfirmPanel:SetPropagateKeyboardInput(true)
    self.defaultsConfirmPanel:SetScript("OnKeyDown", function(frame, key)
        if key == "ESCAPE" then
            frame:Hide()
        end
    end)
    self.defaultsConfirmPanel:Hide()

    self.defaultsConfirmText = NewLabel(self.defaultsConfirmPanel, L["SETTINGS_DEFAULTS_CONFIRM"], Theme.font.heading, "TOP", self.defaultsConfirmPanel, "TOP", 0, -16)
    self.defaultsConfirmText:SetWidth(300)
    self.defaultsConfirmText:SetJustifyH("CENTER")

    self.defaultsConfirmYes = Theme:CreateButton(self.defaultsConfirmPanel, YES)
    self.defaultsConfirmYes:SetPoint("BOTTOMLEFT", self.defaultsConfirmPanel, "BOTTOMLEFT", 34, 16)
    self.defaultsConfirmYes:SetWidth(118)
    self.defaultsConfirmYes:SetFrameLevel(self.defaultsConfirmPanel:GetFrameLevel() + 10)
    self.defaultsConfirmYes:RegisterForClicks("LeftButtonUp")

    self.defaultsConfirmNo = Theme:CreateButton(self.defaultsConfirmPanel, NO)
    self.defaultsConfirmNo:SetPoint("LEFT", self.defaultsConfirmYes, "RIGHT", Theme.layout.gutter, 0)
    self.defaultsConfirmNo:SetWidth(118)
    self.defaultsConfirmNo:SetFrameLevel(self.defaultsConfirmPanel:GetFrameLevel() + 10)
    self.defaultsConfirmNo:RegisterForClicks("LeftButtonUp")

    self.gearSaveConfirmPanel = Theme:CreatePanel(panel, "panelRaised", "border")
    self.gearSaveConfirmPanel:SetSize(420, 128)
    self.gearSaveConfirmPanel:SetPoint("TOP", panel, "TOP", 0, -28)
    self.gearSaveConfirmPanel:SetFrameStrata("DIALOG")
    self.gearSaveConfirmPanel:SetFrameLevel(panel:GetFrameLevel() + 50)
    self.gearSaveConfirmPanel:SetToplevel(true)
    self.gearSaveConfirmPanel:EnableMouse(true)
    self.gearSaveConfirmPanel:EnableKeyboard(true)
    self.gearSaveConfirmPanel:SetPropagateKeyboardInput(true)
    self.gearSaveConfirmPanel:SetScript("OnKeyDown", function(frame, key)
        if key == "ESCAPE" then
            frame:Hide()
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

    self.gearSaveConfirmNo = Theme:CreateButton(self.gearSaveConfirmPanel, NO)
    self.gearSaveConfirmNo:SetPoint("LEFT", self.gearSaveConfirmYes, "RIGHT", Theme.layout.gutter, 0)
    self.gearSaveConfirmNo:SetWidth(128)
    self.gearSaveConfirmNo:SetFrameLevel(self.gearSaveConfirmPanel:GetFrameLevel() + 10)
    self.gearSaveConfirmNo:RegisterForClicks("LeftButtonUp")
end

function SettingsScreen:CreateModuleFlyout(parent)
    self.moduleFlyoutRows = {}
    self.moduleFlyout = Theme:CreatePanel(parent, "panelRaised", "accent")
    self.moduleFlyout:SetFrameStrata("DIALOG")
    self.moduleFlyout:SetFrameLevel(parent:GetFrameLevel() + 40)
    self.moduleFlyout:SetPoint("BOTTOMRIGHT", self.disableModulesButton, "TOPRIGHT", 0, 4)
    self.moduleFlyout:SetSize(230, 144)
    self.moduleFlyout:EnableMouse(true)
    self.moduleFlyout:Hide()

    self.moduleFlyoutTitle = NewLabel(self.moduleFlyout, L["SETTINGS_DISABLE_MODULES"], Theme.font.heading, "TOPLEFT", self.moduleFlyout, "TOPLEFT", Theme.layout.gutter, -Theme.layout.gutter)

    local rows = {
        { key = "casting", label = L["MAIN_TAB_CASTING"] },
        { key = "tracking", label = L["MAIN_TAB_TRACKING"] },
        { key = "scoring", label = L["MAIN_TAB_SCORING"] },
    }
    for i = 1, #rows do
        local config = rows[i]
        local button = CreateFrame("CheckButton", nil, self.moduleFlyout, "InterfaceOptionsCheckButtonTemplate")
        button:SetSize(22, 22)
        button:SetPoint("TOPLEFT", self.moduleFlyoutTitle, "BOTTOMLEFT", 0, -12 - ((i - 1) * 28))
        button.moduleKey = config.key
        button.moduleLabel = config.label
        button.text = button:CreateFontString(nil, "ARTWORK")
        button.text:SetFontObject(Theme.font.body)
        button.text:SetPoint("LEFT", button, "RIGHT", 4, 0)
        button.text:SetText(config.label)
        AttachTooltip(button, config.label, L["SETTINGS_MODULE_TOGGLE_TOOLTIP"]:format(config.label))
        self.moduleFlyoutRows[#self.moduleFlyoutRows + 1] = button
    end
end

function SettingsScreen:OpenPickerDropdown(row)
    local casting = AvidAngler.Modules.Casting
    local choices = casting and casting.GetPickerChoices and casting:GetPickerChoices(row.key) or {}
    if not row.dropdown or row.key == "oversized" or #choices == 0 then
        self.pickerDropdown:Hide()
        return
    end
    self.pickerDropdown.activeRow = row
    self.pickerDropdown:ClearAllPoints()
    self.pickerDropdown:SetPoint("TOPRIGHT", row.dropdown, "BOTTOMRIGHT", 0, -4)
    self.pickerDropdown:SetHeight(8 + (math.min(#choices, #self.pickerDropdownRows) * 24))
    for i = 1, #self.pickerDropdownRows do
        local option = self.pickerDropdownRows[i]
        local choice = choices[i]
        if choice then
            option.text:SetText(choice.name)
            option:SetScript("OnClick", function()
                local currentCasting = AvidAngler.Modules.Casting
                if currentCasting and currentCasting.SelectPickerChoiceByIndex then
                    currentCasting:SelectPickerChoiceByIndex(row.key, i)
                    self.pickerDropdown:Hide()
                    if self.owner then
                        self.owner:Refresh()
                    end
                end
            end)
            option:Show()
        else
            option:SetScript("OnClick", nil)
            option:Hide()
        end
    end
    self.pickerDropdown:Show()
end

function SettingsScreen:RefreshCasting()
    local casting = AvidAngler.Modules.Casting
    local castingEnabled = casting and IsModuleEnabled("casting")
    SetPanelDisabledVisual(self.pickerPanel, not castingEnabled)
    SetPanelDisabledVisual(self.displayPanel, not castingEnabled)
    SetPanelDisabledVisual(self.actionSlotsPanel, not castingEnabled)
    SetPanelDisabledVisual(self.resolverPanel, not castingEnabled)
    if not castingEnabled and self.pickerDropdown then
        self.pickerDropdown:Hide()
    end
    self:RefreshModules()
    if castingEnabled then
        local currentAction = casting:GetCurrentAction()
        local inputMode = casting.GetInputMode and casting:GetInputMode() or nil
        local displayMode = casting.GetDisplayMode and casting:GetDisplayMode() or nil
        local oneKeySelected = inputMode == "oneKey" or (not inputMode and casting:IsOneKeyEnabled())
        local doubleSelected = inputMode == "doubleRight" or (not inputMode and casting:IsDoubleRightEnabled())
        local hudSelected = displayMode == "hud" or not displayMode
        local buttonSelected = displayMode == "button"
        local sleeping = casting.IsSleeping and casting:IsSleeping()
        local externalAutoLoot = casting.IsAutoLootEnabledExternally and casting:IsAutoLootEnabledExternally()
        self.autoLootExternallyEnabled = externalAutoLoot
        local gearSetExists = casting.HasGearSet and casting:HasGearSet()
        local gearEquipSelected = casting.IsGearEquipEnabled and casting:IsGearEquipEnabled()
        self.gearSetExists = gearSetExists
        self.castingStatus:SetText(currentAction and currentAction.label or casting:GetStatus())
        self.castingActionDetail:SetText(currentAction and currentAction.detail or "")
        self.oneKeyButton.text:SetText(ToggleLabel(oneKeySelected, L["ONE_KEY_TOGGLE_LABEL"]))
        self.doubleButton.text:SetText(ToggleLabel(doubleSelected, L["DOUBLE_RIGHT_TOGGLE_LABEL"]))
        self.autoLootButton.text:SetText(ToggleLabel(casting:IsAutoLootEnabled() or externalAutoLoot, L["AUTO_LOOT_TOGGLE_LABEL"]))
        self.audioFocusButton.text:SetText(ToggleLabel(casting.IsAudioFocusEnabled and casting:IsAudioFocusEnabled(), L["AUDIO_FOCUS_TOGGLE_LABEL"]))
        local audioFocusSelected = casting.IsAudioFocusEnabled and casting:IsAudioFocusEnabled()
        SetButtonSelected(self.oneKeyButton, oneKeySelected)
        SetButtonSelected(self.doubleButton, doubleSelected)
        SetButtonSelected(self.autoLootButton, casting:IsAutoLootEnabled() or externalAutoLoot)
        SetButtonSelected(self.audioFocusButton, audioFocusSelected)
        self.audioFocusConfigButton:SetShown(audioFocusSelected)
        if not audioFocusSelected and self.audioFocusConfigPanel then
            self.audioFocusConfigPanel:Hide()
        end
        if self.generalOptionButtons then
            for i = 1, #self.generalOptionButtons do
                local button = self.generalOptionButtons[i]
                local enabled = casting.GetGeneralOption and casting:GetGeneralOption(button.optionKey)
                button.text:SetText(ToggleLabel(enabled, button.optionLabel))
                SetButtonSelected(button, enabled)
            end
        end
        self:RefreshAudioFocusConfig()
        self.autoLootButton:SetAlpha(externalAutoLoot and 0.55 or 1)
        self.autoLootButton.text:SetTextColor(unpack(externalAutoLoot and Theme.color.textDisabled or Theme.color.textPrimary))
        SetButtonSelected(self.displayHudButton, hudSelected)
        SetButtonSelected(self.displayButtonOnlyButton, buttonSelected)
        self.sleepButton.text:SetText(ToggleLabel(sleeping, L["ACTION_SLEEP_TOGGLE"]))
        SetButtonSelected(self.sleepButton, sleeping)
        self.showControlsButton:SetEnabled(casting.AreControlsHidden and casting:AreControlsHidden())
        self.buttonSizeValue:SetText(casting.GetButtonSize and tostring(casting:GetButtonSize()) or "")
        self.saveGearButton.text:SetText(gearSetExists and L["GEAR_VIEW_LABEL"] or L["GEAR_SAVE_LABEL"])
        self.equipGearButton.text:SetText(ToggleLabel(gearEquipSelected, L["GEAR_EQUIP_LABEL"]))
        SetButtonSelected(self.saveGearButton, false)
        SetButtonSelected(self.equipGearButton, gearEquipSelected)
        if not self.keyBox:HasFocus() and self.keyBox:GetText() ~= casting:GetOneKey() then
            self.keyBox:SetText(casting:GetOneKey())
        end
        for i = 1, #self.pickerRows do
            local row = self.pickerRows[i]
            local state = casting:GetPickerChoice(row.key)
            row.toggle.text:SetText(ToggleLabel(state.enabled, row.label))
            if state.choice then
                row.name:SetText(state.choice.name)
            elseif state.activeName then
                row.name:SetText(state.activeName)
            elseif (row.key == "lure" or row.key == "ward") and state.count > 0 then
                row.name:SetText(L["ACTION_PICKER_NONE_SELECTED"])
            else
                row.name:SetText(L["ACTION_PICKER_EMPTY"])
            end
            row.status:SetText(state.statusText or "")
            row.status:SetTextColor(unpack(StatusColor(state.statusKey)))
            if row.dropdown then
                local hasChoices = (state.count or 0) > 0
                if hasChoices then
                    row.dropdown:Enable()
                    row.dropdown:SetAlpha(1)
                else
                    row.dropdown:Disable()
                    row.dropdown:SetAlpha(0.55)
                    if self.pickerDropdown.activeRow == row then
                        self.pickerDropdown:Hide()
                    end
                end
            end
        end
        for i = 1, #self.actionSlotRows do
            local row = self.actionSlotRows[i]
            local slot = casting:GetActionSlot(i)
            if slot then
                local remaining = casting:GetActionSlotRemaining(i)
                local suffix = remaining > 0 and L["ACTION_SLOT_COOLDOWN"]:format(remaining) or ""
                row.toggle.text:SetText(ToggleLabel(slot.enabled, L["ACTION_SLOT_ENABLE"] .. suffix))
                row.slotButton.text:SetText(slot.name ~= "" and slot.name or L["ACTION_SLOT_EMPTY"])
                if slot.icon then
                    row.slotButton.icon:SetTexture(slot.icon)
                    row.slotButton.icon:Show()
                else
                    row.slotButton.icon:Hide()
                end
            end
        end
        local queue = casting.GetResolverQueue and casting:GetResolverQueue() or {}
        for i = 1, #self.resolverRows do
            local row = self.resolverRows[i]
            local entry = queue[i]
            if entry then
                row.labelText:SetText(entry.label or "")
                row.detailText:SetText(entry.detail or "")
                row.statusText:SetText(entry.statusText or "")
                row.statusText:SetTextColor(unpack(StatusColor(entry.statusKey)))
                row:Show()
            else
                row:Hide()
            end
        end
    elseif casting then
        self.autoLootExternallyEnabled = false
        if self.audioFocusConfigButton then
            self.audioFocusConfigButton:Hide()
        end
        if self.audioFocusConfigPanel then
            self.audioFocusConfigPanel:Hide()
        end
        self.castingStatus:SetText(L["MODULE_DISABLED_VIEW"]:format(L["MAIN_TAB_CASTING"]))
        self.castingActionDetail:SetText("")
        for i = 1, #self.resolverRows do
            self.resolverRows[i]:Hide()
        end
    end
end

function SettingsScreen:RefreshModules()
    if not self.moduleFlyoutRows then
        return
    end
    for i = 1, #self.moduleFlyoutRows do
        local button = self.moduleFlyoutRows[i]
        local enabled = IsModuleEnabled(button.moduleKey)
        button:SetChecked(enabled)
        button.text:SetFontObject(enabled and Theme.font.heading or Theme.font.body)
    end
end

function SettingsScreen:RefreshAudioFocusConfig()
    local casting = AvidAngler.Modules.Casting
    if not casting or not casting.GetAudioFocusSettings or not self.audioFocusFields then
        return
    end
    local labels = {
        master = L["AUDIO_FOCUS_MASTER_VOLUME"],
        music = L["AUDIO_FOCUS_MUSIC_VOLUME"],
        sfx = L["AUDIO_FOCUS_EFFECTS_VOLUME"],
        ambience = L["AUDIO_FOCUS_AMBIENCE_VOLUME"],
        dialog = L["AUDIO_FOCUS_DIALOG_VOLUME"],
    }
    local settings = casting:GetAudioFocusSettings()
    for key, field in pairs(self.audioFocusFields) do
        field.label:SetText(labels[key] or "")
        local text = tostring(settings[key] or 0)
        if not field.box:HasFocus() and field.box:GetText() ~= text then
            field.box:SetText(text)
        end
    end
end

function SettingsScreen:ReadAudioFocusConfig()
    local settings = {}
    if not self.audioFocusFields then
        return settings
    end
    for key, field in pairs(self.audioFocusFields) do
        settings[key] = tonumber(field.box:GetText()) or 0
    end
    return settings
end

function SettingsScreen:RefreshLocaleText()
    if not self.castingPanel then
        return
    end

    self.settingsHeading:SetText(L["MAIN_TAB_SETTINGS"])
    self.generalTitle:SetText(L["GENERAL_SETTINGS_TITLE"])
    self.generalBody:SetText(L["GENERAL_SETTINGS_BODY"])
    self.inputPreviewTitle:SetText(L["ACTION_INPUT_TITLE"])
    self.inputPreviewBody:SetText(L["ACTION_INPUT_BODY"])
    self.oneKeyButton.tooltipTitle = L["ONE_KEY_TOGGLE_LABEL"]
    self.oneKeyButton.tooltipBody = L["ONE_KEY_TOGGLE_TOOLTIP"]
    self.doubleButton.tooltipTitle = L["DOUBLE_RIGHT_TOGGLE_LABEL"]
    self.doubleButton.tooltipBody = L["DOUBLE_RIGHT_TOGGLE_TOOLTIP"]
    self.keyLabel:SetText(L["KEY_LABEL"])
    self.keyBox.tooltipTitle = L["KEY_LABEL"]
    self.keyBox.tooltipBody = L["ONE_KEY_BINDING_TOOLTIP"]
    self.keySaveButton.tooltipTitle = L["SAVE_KEY_LABEL"]
    self.keySaveButton.tooltipBody = L["SAVE_KEY_TOOLTIP"]
    self.audioFocusConfigTitle:SetText(L["AUDIO_FOCUS_SETTINGS"])
    self.autoLootButton.tooltipTitle = L["AUTO_LOOT_TOGGLE_LABEL"]
    self.audioFocusButton.tooltipTitle = L["AUDIO_FOCUS_TOGGLE_LABEL"]
    self.audioFocusButton.tooltipBody = L["AUDIO_FOCUS_TOGGLE_TOOLTIP"]
    self.audioFocusConfigButton.tooltipTitle = L["AUDIO_FOCUS_SETTINGS"]
    self.audioFocusConfigButton.tooltipBody = L["AUDIO_FOCUS_SETTINGS_TOOLTIP"]
    self.audioFocusDefaultsButton.text:SetText(L["AUDIO_FOCUS_DEFAULTS"])
    self.audioFocusDefaultsButton.tooltipTitle = L["AUDIO_FOCUS_DEFAULTS"]
    self.audioFocusDefaultsButton.tooltipBody = L["AUDIO_FOCUS_DEFAULTS_TOOLTIP"]
    self.audioFocusSaveButton.text:SetText(L["SAVE_KEY_LABEL"])
    self.audioFocusSaveButton.tooltipTitle = L["SAVE_KEY_LABEL"]
    self.audioFocusSaveButton.tooltipBody = L["AUDIO_FOCUS_SAVE_TOOLTIP"]
    self.pickerRefreshButton.text:SetText(L["ACTION_PICKERS_REFRESH"])
    self.pickerRefreshButton.tooltipTitle = L["ACTION_PICKERS_REFRESH"]
    self.pickerRefreshButton.tooltipBody = L["ACTION_PICKERS_REFRESH_TOOLTIP"]
    self.pickerTitle:SetText(L["ACTION_PICKERS_TITLE"])
    self.displayTitle:SetText(L["ACTION_DISPLAY_TITLE"])
    self.displayHudButton.text:SetText(L["ACTION_DISPLAY_HUD"])
    self.displayHudButton.tooltipTitle = L["ACTION_DISPLAY_HUD"]
    self.displayHudButton.tooltipBody = L["ACTION_DISPLAY_HUD_TOOLTIP"]
    self.displayButtonOnlyButton.text:SetText(L["ACTION_DISPLAY_BUTTON"])
    self.displayButtonOnlyButton.tooltipTitle = L["ACTION_DISPLAY_BUTTON"]
    self.displayButtonOnlyButton.tooltipBody = L["ACTION_DISPLAY_BUTTON_TOOLTIP"]
    self.showControlsButton.text:SetText(L["ACTION_SHOW_CONTROLS"])
    self.showControlsButton.tooltipTitle = L["ACTION_SHOW_CONTROLS"]
    self.showControlsButton.tooltipBody = L["ACTION_SHOW_CONTROLS_TOOLTIP"]
    self.sleepButton.tooltipTitle = L["ACTION_SLEEP_TOGGLE"]
    self.sleepButton.tooltipBody = L["ACTION_DISPLAY_SLEEP_TOOLTIP"]
    self.buttonSizeDown.tooltipTitle = L["ACTION_DISPLAY_SCALE"]
    self.buttonSizeDown.tooltipBody = L["ACTION_DISPLAY_SCALE_TOOLTIP"]
    self.buttonSizeTooltipFrame.tooltipTitle = L["ACTION_DISPLAY_SCALE"]
    self.buttonSizeTooltipFrame.tooltipBody = L["ACTION_DISPLAY_SCALE_TOOLTIP"]
    self.buttonSizeUp.tooltipTitle = L["ACTION_DISPLAY_SCALE"]
    self.buttonSizeUp.tooltipBody = L["ACTION_DISPLAY_SCALE_TOOLTIP"]
    self.displayPreview.tooltipTitle = L["ACTION_DISPLAY_PREVIEW"]
    self.displayPreview.tooltipBody = L["ACTION_DISPLAY_PREVIEW_TOOLTIP"]
    self.displayPreview.hudLabel:SetText(L["ACTION_DISPLAY_HUD"])
    self.displayPreview.hudTitle:SetText(L["ACTION_CAST"])
    self.displayPreview.hudDetail:SetText(L["ACTION_DETAIL_CAST"])
    self.displayPreview.buttonLabel:SetText(L["ACTION_DISPLAY_BUTTON"])
    self.actionSlotsPanel.extraToyTitle:SetText(L["ACTION_SLOT_TOYS_TITLE"])
    self.actionSlotsPanel.extraActionTitle:SetText(L["ACTION_SLOT_EXTRAS_TITLE"])
    self.actionSlotsPanel.openToyBoxButton.text:SetText(L["ACTION_SLOT_OPEN_TOYBOX"])
    self.actionSlotsPanel.openToyBoxButton.tooltipTitle = L["ACTION_SLOT_OPEN_TOYBOX"]
    self.actionSlotsPanel.openToyBoxButton.tooltipBody = L["ACTION_SLOT_TOYBOX_TOOLTIP"]
    self.actionSlotsPanel.openMacrosButton.text:SetText(L["ACTION_SLOT_OPEN_MACROS"])
    self.actionSlotsPanel.openMacrosButton.tooltipTitle = L["ACTION_SLOT_OPEN_MACROS"]
    self.actionSlotsPanel.openMacrosButton.tooltipBody = L["ACTION_SLOT_MACROS_TOOLTIP"]
    self.actionSlotsPanel.openBagsButton.text:SetText(L["ACTION_SLOT_OPEN_BAGS"])
    self.actionSlotsPanel.openBagsButton.tooltipTitle = L["ACTION_SLOT_OPEN_BAGS"]
    self.actionSlotsPanel.openBagsButton.tooltipBody = L["ACTION_SLOT_BAGS_TOOLTIP"]
    self.equipGearButton.tooltipTitle = L["GEAR_EQUIP_LABEL"]
    self.equipGearButton.tooltipBody = L["GEAR_EQUIP_TOOLTIP"]
    for i = 1, #self.actionSlotRows do
        local row = self.actionSlotRows[i]
        row.toggle.tooltipTitle = L["ACTION_SLOT_ENABLE"]
        row.toggle.tooltipBody = L["ACTION_SLOT_USE_TOOLTIP"]
        row.slotButton.tooltipTitle = row.slotKind == "toy" and L["ACTION_SLOT_TOY_LABEL"]:format(i) or L["ACTION_SLOT_EXTRA_LABEL"]:format(i - 3)
        row.slotButton.tooltipBody = row.slotKind == "toy" and L["ACTION_SLOT_TOY_TOOLTIP"] or L["ACTION_SLOT_EXTRA_TOOLTIP"]
    end
    self.resolverTitle:SetText(L["ACTION_RESOLVER_TITLE"])
    self.defaultsButton.text:SetText(L["SETTINGS_DEFAULTS"])
    self.defaultsButton.tooltipTitle = L["SETTINGS_DEFAULTS"]
    self.defaultsButton.tooltipBody = L["SETTINGS_DEFAULTS_TOOLTIP"]
    self.disableModulesButton.text:SetText(L["SETTINGS_DISABLE_MODULES"])
    self.disableModulesButton.tooltipTitle = L["SETTINGS_DISABLE_MODULES"]
    self.disableModulesButton.tooltipBody = L["SETTINGS_DISABLE_MODULES_TOOLTIP"]
    self.setupWizardButton.text:SetText(L["SETUP_WIZARD_REOPEN"])
    self.setupWizardButton.tooltipTitle = L["SETUP_WIZARD_REOPEN"]
    self.setupWizardButton.tooltipBody = L["SETUP_WIZARD_REOPEN_TOOLTIP"]
    self.moduleFlyoutTitle:SetText(L["SETTINGS_DISABLE_MODULES"])
    self.generalOptionButtons[1].optionLabel = L["GENERAL_OPTION_DISABLE_SOFT_ICON"]
    self.generalOptionButtons[1].tooltipTitle = L["GENERAL_OPTION_DISABLE_SOFT_ICON"]
    self.generalOptionButtons[1].tooltipBody = L["GENERAL_OPTION_DISABLE_SOFT_ICON_TOOLTIP"]
    self.generalOptionButtons[2].optionLabel = L["GENERAL_OPTION_DISABLE_SOFT_INTERACT"]
    self.generalOptionButtons[2].tooltipTitle = L["GENERAL_OPTION_DISABLE_SOFT_INTERACT"]
    self.generalOptionButtons[2].tooltipBody = L["GENERAL_OPTION_DISABLE_SOFT_INTERACT_TOOLTIP"]
    self.generalOptionButtons[3].optionLabel = L["GENERAL_OPTION_DISMOUNT_WITH_KEY"]
    self.generalOptionButtons[3].tooltipTitle = L["GENERAL_OPTION_DISMOUNT_WITH_KEY"]
    self.generalOptionButtons[3].tooltipBody = L["GENERAL_OPTION_DISMOUNT_WITH_KEY_TOOLTIP"]
    self.generalOptionButtons[4].optionLabel = L["GENERAL_OPTION_RELEASE_WHEN_SWIMMING"]
    self.generalOptionButtons[4].tooltipTitle = L["GENERAL_OPTION_RELEASE_WHEN_SWIMMING"]
    self.generalOptionButtons[4].tooltipBody = L["GENERAL_OPTION_RELEASE_WHEN_SWIMMING_TOOLTIP"]

    local pickerLabels = {
        oversized = L["ACTION_PICKER_OVERSIZED"],
        bobber = L["ACTION_PICKER_BOBBER"],
        lure = L["ACTION_PICKER_LURE"],
        ward = L["ACTION_PICKER_WARD"],
        toy = L["ACTION_PICKER_TOY"],
    }
    for i = 1, #self.pickerRows do
        local row = self.pickerRows[i]
        row.label = pickerLabels[row.key] or row.label
        if row.dropdown then
            row.dropdown.text:SetText(L["ACTION_PICKER_SELECT"])
        end
    end
    for i = 1, #self.moduleFlyoutRows do
        local row = self.moduleFlyoutRows[i]
        if row.moduleKey == "casting" then
            row.moduleLabel = L["MAIN_TAB_CASTING"]
        elseif row.moduleKey == "tracking" then
            row.moduleLabel = L["MAIN_TAB_TRACKING"]
        elseif row.moduleKey == "scoring" then
            row.moduleLabel = L["MAIN_TAB_SCORING"]
        end
        row.text:SetText(row.moduleLabel)
        row.tooltipTitle = row.moduleLabel
        row.tooltipBody = L["SETTINGS_MODULE_TOGGLE_TOOLTIP"]:format(row.moduleLabel)
    end
end

function SettingsScreen:Refresh()
    self:RefreshLocaleText()
    self:RefreshCasting()
end

function SettingsScreen:OpenToyBox()
    if not CollectionsJournal and C_AddOns and C_AddOns.LoadAddOn then
        C_AddOns.LoadAddOn("Blizzard_Collections")
    end
    if not CollectionsJournal then
        return false
    end

    if ShowUIPanel then
        ShowUIPanel(CollectionsJournal)
    else
        CollectionsJournal:Show()
    end
    if CollectionsJournal_SetTab then
        CollectionsJournal_SetTab(CollectionsJournal, 3)
    end
    if CollectionsJournal.SetFrameStrata then
        CollectionsJournal:SetFrameStrata("DIALOG")
    end
    if CollectionsJournal.Raise then
        CollectionsJournal:Raise()
    end
    return true
end

function SettingsScreen:OpenToyBoxForSlot(index)
    if InCombatLockdown() then
        return
    end
    self.pendingToySlotIndex = index
    if not self:OpenToyBox() then
        return
    end
    if ToyBox and ToyBox.iconsFrame and not self.toyBoxHooked then
        local buttons = { ToyBox.iconsFrame:GetChildren() }
        for buttonIndex = 1, #buttons do
            local button = buttons[buttonIndex]
            if button and button.HookScript then
                button:HookScript("OnMouseUp", function(buttonFrame, mouseButton)
                    if mouseButton ~= "LeftButton" or not SettingsScreen.pendingToySlotIndex then
                        return
                    end
                    local itemID = buttonFrame.itemID
                    if itemID and AvidAngler.Modules.Casting and AvidAngler.Modules.Casting:SetActionSlotToy(SettingsScreen.pendingToySlotIndex, itemID) then
                        SettingsScreen.pendingToySlotIndex = nil
                        if SettingsScreen.owner then
                            SettingsScreen.owner:Refresh()
                        end
                    end
                end)
            end
        end
        self.toyBoxHooked = true
    end
end

function SettingsScreen:ExtractCursorItemID(cursorType, arg1, arg2)
    if cursorType ~= "item" then
        return nil
    end
    local itemID = tonumber(arg1)
    if itemID then
        return itemID
    end
    local link = type(arg2) == "string" and arg2 or type(arg1) == "string" and arg1 or nil
    return link and tonumber(link:match("item:(%d+)")) or nil
end

function SettingsScreen:ApplyCursorToActionSlot(index)
    if InCombatLockdown() then
        if ClearCursor then
            ClearCursor()
        end
        return
    end
    local cursorType, arg1, arg2 = GetCursorInfo()
    local casting = AvidAngler.Modules.Casting
    if not casting or not cursorType then
        return
    end
    local saved = false
    if cursorType == "macro" then
        saved = casting:SetActionSlotMacro(index, arg1)
    else
        local itemID = self:ExtractCursorItemID(cursorType, arg1, arg2)
        if itemID and index <= 3 then
            saved = casting:SetActionSlotToy(index, itemID)
        elseif itemID then
            saved = casting:SetActionSlotItem(index, itemID)
        end
    end
    if ClearCursor then
        ClearCursor()
    end
    if saved then
        if self.owner then
            self.owner:Refresh()
        end
    else
        AvidAngler:Print(L["ACTION_SLOT_DROP_INVALID"])
    end
end

function SettingsScreen:OpenMacroWindow()
    if ShowMacroFrame then
        ShowMacroFrame()
        return
    end
    if C_AddOns and C_AddOns.LoadAddOn then
        C_AddOns.LoadAddOn("Blizzard_MacroUI")
    end
    if ShowMacroFrame then
        ShowMacroFrame()
    end
end

function SettingsScreen:ToggleBags()
    if ToggleAllBags then
        ToggleAllBags()
    elseif OpenAllBags then
        OpenAllBags()
    end
end

function SettingsScreen:WireScripts()
    self.oneKeyButton:SetScript("OnClick", function()
        local casting = AvidAngler.Modules.Casting
        if casting then
            local selected = casting.GetInputMode and casting:GetInputMode() == "oneKey"
            if casting.SetInputMode then
                casting:SetInputMode(selected and "off" or "oneKey")
            else
                casting:SetOneKeyEnabled(not casting:IsOneKeyEnabled())
            end
            self.owner:Refresh()
        end
    end)
    self.doubleButton:SetScript("OnClick", function()
        local casting = AvidAngler.Modules.Casting
        if casting then
            local selected = casting.GetInputMode and casting:GetInputMode() == "doubleRight"
            if casting.SetInputMode then
                casting:SetInputMode(selected and "off" or "doubleRight")
            else
                casting:SetDoubleRightEnabled(not casting:IsDoubleRightEnabled())
            end
            self.owner:Refresh()
        end
    end)
    self.autoLootButton:SetScript("OnClick", function()
        local casting = AvidAngler.Modules.Casting
        if casting then
            if casting.IsAutoLootEnabledExternally and casting:IsAutoLootEnabledExternally() then
                self.owner:Refresh()
                return
            end
            casting:SetAutoLootEnabled(not casting:IsAutoLootEnabled())
            self.owner:Refresh()
        end
    end)
    self.audioFocusButton:SetScript("OnClick", function()
        local casting = AvidAngler.Modules.Casting
        if casting and casting.SetAudioFocusEnabled then
            casting:SetAudioFocusEnabled(not casting:IsAudioFocusEnabled())
            self.owner:Refresh()
        end
    end)
    self.audioFocusConfigButton:SetScript("OnClick", function()
        if self.audioFocusConfigPanel:IsShown() then
            self.audioFocusConfigPanel:Hide()
        else
            self:RefreshAudioFocusConfig()
            self.audioFocusConfigPanel:Show()
        end
    end)
    self.audioFocusCloseButton:SetScript("OnClick", function()
        self.audioFocusConfigPanel:Hide()
    end)
    self.audioFocusSaveButton:SetScript("OnClick", function()
        local casting = AvidAngler.Modules.Casting
        if casting and casting.SetAudioFocusSettings then
            casting:SetAudioFocusSettings(self:ReadAudioFocusConfig())
            self:RefreshAudioFocusConfig()
        end
    end)
    self.audioFocusDefaultsButton:SetScript("OnClick", function()
        local casting = AvidAngler.Modules.Casting
        if casting and casting.ResetAudioFocusSettings then
            casting:ResetAudioFocusSettings()
            self:RefreshAudioFocusConfig()
        end
    end)
    for i = 1, #self.generalOptionButtons do
        local button = self.generalOptionButtons[i]
        button:SetScript("OnClick", function(optionButton)
            local casting = AvidAngler.Modules.Casting
            if casting and casting.SetGeneralOption then
                casting:SetGeneralOption(optionButton.optionKey, not casting:GetGeneralOption(optionButton.optionKey))
                self.owner:Refresh()
            end
        end)
    end
    self.keySaveButton:SetScript("OnClick", function()
        if AvidAngler.Modules.Casting then
            AvidAngler.Modules.Casting:SetOneKey(self.keyBox:GetText())
            self.owner:Refresh()
        end
    end)
    self.keyBox:SetScript("OnEnterPressed", function(box)
        if AvidAngler.Modules.Casting then
            AvidAngler.Modules.Casting:SetOneKey(box:GetText())
            self.owner:Refresh()
        end
        box:ClearFocus()
    end)
    self.displayHudButton:SetScript("OnClick", function()
        if AvidAngler.Modules.Casting and AvidAngler.Modules.Casting.SetDisplayMode then
            AvidAngler.Modules.Casting:SetDisplayMode("hud")
            self.owner:Refresh()
        end
    end)
    self.displayButtonOnlyButton:SetScript("OnClick", function()
        if AvidAngler.Modules.Casting and AvidAngler.Modules.Casting.SetDisplayMode then
            AvidAngler.Modules.Casting:SetDisplayMode("button")
            self.owner:Refresh()
        end
    end)
    self.sleepButton:SetScript("OnClick", function()
        local casting = AvidAngler.Modules.Casting
        if casting and casting.SetSleeping then
            casting:SetSleeping(not casting:IsSleeping())
            self.owner:Refresh()
        end
    end)
    self.showControlsButton:SetScript("OnClick", function()
        if AvidAngler.Modules.Casting and AvidAngler.Modules.Casting.SetControlsHidden then
            AvidAngler.Modules.Casting:SetControlsHidden(false)
            self.owner:Refresh()
        end
    end)
    self.buttonSizeDown:SetScript("OnClick", function()
        if AvidAngler.Modules.Casting and AvidAngler.Modules.Casting.StepButtonSize then
            AvidAngler.Modules.Casting:StepButtonSize(-8)
            self.owner:Refresh()
        end
    end)
    self.buttonSizeUp:SetScript("OnClick", function()
        if AvidAngler.Modules.Casting and AvidAngler.Modules.Casting.StepButtonSize then
            AvidAngler.Modules.Casting:StepButtonSize(8)
            self.owner:Refresh()
        end
    end)
    local function HideDefaultsConfirm()
        self.defaultsConfirmPanel:Hide()
    end
    local function ShowDefaultsConfirm()
        self.defaultsConfirmPanel:SetFrameLevel(self.castingPanel:GetFrameLevel() + 50)
        self.defaultsConfirmYes:SetFrameLevel(self.defaultsConfirmPanel:GetFrameLevel() + 10)
        self.defaultsConfirmNo:SetFrameLevel(self.defaultsConfirmPanel:GetFrameLevel() + 10)
        if self.gearSaveConfirmPanel then
            self.gearSaveConfirmPanel:Hide()
        end
        if self.moduleFlyout then
            self.moduleFlyout:Hide()
        end
        self.defaultsConfirmPanel:Show()
    end
    self.defaultsButton:SetScript("OnClick", ShowDefaultsConfirm)
    self.defaultsConfirmYes:SetScript("OnClick", function()
        local casting = AvidAngler.Modules and AvidAngler.Modules.Casting
        if casting and casting.ResetSettingsToDefaults then
            casting:ResetSettingsToDefaults()
        end
        HideDefaultsConfirm()
    end)
    self.defaultsConfirmNo:SetScript("OnClick", HideDefaultsConfirm)
    local function HideGearSaveConfirm()
        self.gearSaveConfirmPanel:Hide()
    end
    local function ShowGearSaveConfirm()
        self.gearSaveConfirmPanel:SetFrameLevel(self.castingPanel:GetFrameLevel() + 50)
        self.gearSaveConfirmYes:SetFrameLevel(self.gearSaveConfirmPanel:GetFrameLevel() + 10)
        self.gearSaveConfirmNo:SetFrameLevel(self.gearSaveConfirmPanel:GetFrameLevel() + 10)
        if self.defaultsConfirmPanel then
            self.defaultsConfirmPanel:Hide()
        end
        if self.moduleFlyout then
            self.moduleFlyout:Hide()
        end
        self.gearSaveConfirmPanel:Show()
    end
    self.gearSaveConfirmYes:SetScript("OnClick", function()
        local casting = AvidAngler.Modules and AvidAngler.Modules.Casting
        if casting and casting.SaveGearSetWithDefault then
            casting:SaveGearSetWithDefault()
        end
        HideGearSaveConfirm()
        self.owner:Refresh()
    end)
    self.gearSaveConfirmNo:SetScript("OnClick", HideGearSaveConfirm)
    self.disableModulesButton:SetScript("OnClick", function()
        if self.defaultsConfirmPanel then
            self.defaultsConfirmPanel:Hide()
        end
        if self.gearSaveConfirmPanel then
            self.gearSaveConfirmPanel:Hide()
        end
        if self.moduleFlyout:IsShown() then
            self.moduleFlyout:Hide()
        else
            self:RefreshModules()
            self.moduleFlyout:Show()
        end
    end)
    self.setupWizardButton:SetScript("OnClick", function()
        if AvidAngler.UI and AvidAngler.UI.SetupWizard and AvidAngler.UI.SetupWizard.Show then
            AvidAngler.UI.SetupWizard:Show(true)
        end
    end)
    for i = 1, #self.moduleFlyoutRows do
        local button = self.moduleFlyoutRows[i]
        button:SetScript("OnClick", function()
            AvidAngler:SetModuleEnabled(button.moduleKey, button:GetChecked() and true or false)
            self:RefreshModules()
            if self.owner then
                self.owner:Refresh()
            end
        end)
    end
    self.pickerRefreshButton:SetScript("OnClick", function()
        if AvidAngler.Modules.Casting then
            AvidAngler.Modules.Casting:RefreshActionChoices()
            self.owner:Refresh()
        end
    end)
    for i = 1, #self.pickerRows do
        local row = self.pickerRows[i]
        row.toggle:SetScript("OnClick", function()
            local casting = AvidAngler.Modules.Casting
            local state = casting and casting:GetPickerChoice(row.key)
            if casting and state then
                casting:SetPickerEnabled(row.key, not state.enabled)
                self.owner:Refresh()
            end
        end)
        if row.dropdown then
            row.dropdown:SetScript("OnClick", function()
                if self.pickerDropdown.activeRow == row and self.pickerDropdown:IsShown() then
                    self.pickerDropdown:Hide()
                else
                    self:OpenPickerDropdown(row)
                end
            end)
        end
    end
    for i = 1, #self.actionSlotRows do
        local row = self.actionSlotRows[i]
        local index = i
        row.toggle:SetScript("OnClick", function()
            local casting = AvidAngler.Modules.Casting
            local slot = casting and casting:GetActionSlot(index)
            if casting and slot then
                casting:SetActionSlotEnabled(index, not slot.enabled)
                self.owner:Refresh()
            end
        end)
        row.slotButton:SetScript("OnReceiveDrag", function()
            self:ApplyCursorToActionSlot(index)
        end)
        row.slotButton:SetScript("OnDragStart", function()
            self:ApplyCursorToActionSlot(index)
        end)
        row.slotButton:SetScript("OnClick", function(_, mouseButton)
            if AvidAngler.Modules.Casting then
                if mouseButton == "RightButton" then
                    AvidAngler.Modules.Casting:ClearActionSlot(index)
                elseif GetCursorInfo() then
                    self:ApplyCursorToActionSlot(index)
                elseif index <= 3 then
                    self:OpenToyBoxForSlot(index)
                end
                self.owner:Refresh()
            end
        end)
    end
    self.actionSlotsPanel.openToyBoxButton:SetScript("OnClick", function()
        self.pendingToySlotIndex = nil
        self:OpenToyBox()
    end)
    self.actionSlotsPanel.openMacrosButton:SetScript("OnClick", function()
        self:OpenMacroWindow()
    end)
    self.actionSlotsPanel.openBagsButton:SetScript("OnClick", function()
        self:ToggleBags()
    end)
    self.saveGearButton:SetScript("OnClick", function()
        local casting = AvidAngler.Modules.Casting
        if casting then
            if casting.HasGearSet and casting:HasGearSet() and casting.ViewGearSet then
                casting:ViewGearSet()
            elseif casting.HasReturnGearSet and not casting:HasReturnGearSet() then
                ShowGearSaveConfirm()
                return
            else
                casting:SaveGearSet()
            end
            self.owner:Refresh()
        end
    end)
    self.equipGearButton:SetScript("OnClick", function()
        local casting = AvidAngler.Modules.Casting
        if casting and casting.SetGearEquipEnabled then
            casting:SetGearEquipEnabled(not casting:IsGearEquipEnabled())
            self.owner:Refresh()
        end
    end)
end
