-- Avid Angler
-- Native keybinding label and Settings navigation.
local _, AvidAngler = ...
_G["BINDING_NAME_CLICK AvidAnglerFishingBindingButton:LeftButton"] = AvidAngler.L["KEY_BINDINGS_FISHING"]

local returnMain, returnWizard
local navigationToken = 0
EventRegistry:RegisterCallback("SettingsPanel.OnHide", function()
    local main, wizard = returnMain, returnWizard
    returnMain, returnWizard = nil, nil
    if not main and not wizard then return end
    local token = navigationToken
    C_Timer.After(0, function()
        if token ~= navigationToken or InCombatLockdown() or AvidAngler:IsRuntimeDisabled() then return end
        if SettingsPanel and SettingsPanel:IsShown() then return end
        if main then main:Show() end
        if wizard and wizard.frame then
            wizard:Refresh()
            wizard.frame:Show()
        end
    end)
end)

function AvidAngler.UI.OpenFishingKeybindings()
    if InCombatLockdown() or AvidAngler:IsRuntimeDisabled() then
        AvidAngler:Print(AvidAngler.L["ONE_KEY_COMBAT"])
        return
    end
    if C_AddOns and C_AddOns.LoadAddOn then C_AddOns.LoadAddOn("Blizzard_Settings") end
    if Settings and Settings.OpenToCategory and Settings.KEYBINDINGS_CATEGORY_ID then
        local main, wizard = AvidAngler.UI.MainWindow, AvidAngler.UI.SetupWizard
        navigationToken = navigationToken + 1
        returnMain = main and main.IsShown and main:IsShown() and main or nil
        returnWizard = wizard and wizard.frame and wizard.frame:IsShown() and wizard or nil
        Settings.OpenToCategory(Settings.KEYBINDINGS_CATEGORY_ID)
        if wizard then wizard:Hide() end
        if main then main:Hide() end
    end
end
