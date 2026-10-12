-- Addon-owned method boundaries for local performance diagnostics.
local ADDON, AvidAngler = ...
local installed = false

function AvidAngler:InstallPerformanceHooks()
    if installed then return end
    installed = true
    local function hook(target, method, label)
        if target and type(target[method]) == "function" then
            target[method] = AvidAngler:MonitorWrap(label, target[method])
        end
    end
    hook(self.DataLayer, "RecordCatch", "core.catch")
    hook(self.DataLayer, "RecordFishingCast", "core.cast")
    hook(self, "ApplyContentSafety", "core.safety")
    hook(self.Modules.Tracking, "Refresh", "tracking.refresh")
    hook(self.Modules.Tracking.SessionValue, "GetSummary", "tracking.value")
    hook(self.Modules.Scoring, "Refresh", "scoring.refresh")
    hook(self.Modules.SupplyAlert, "Update", "alerts.supplies")
    hook(self.Modules.VenomAlert, "Update", "alerts.venom")
    hook(self.UI.MainWindow, "Refresh", "ui.refresh")
    hook(self.UI.MainWindow, "RefreshFishingStatus", "ui.fishingStatus")
    hook(self.UI.SettingsScreen, "RefreshCasting", "ui.settings")
    hook(self.UI.Achievements, "Refresh", "ui.achievements")
    hook(self.UI.ExpansionGuide, "Refresh", "ui.guide")
end

local startup = CreateFrame("Frame")
startup:RegisterEvent("ADDON_LOADED")
startup:SetScript("OnEvent", function(frame, _, name)
    if name ~= ADDON then return end
    frame:UnregisterAllEvents()
    AvidAngler.Recorder:OnEnable()
end)
