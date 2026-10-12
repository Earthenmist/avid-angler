-- Paged, copyable performance history. Built only on explicit export.
local _, AvidAngler = ...
local panel, output, pageLabel, pages, page
function AvidAngler.Recorder:ShowExport()
    local L=AvidAngler.L
    if not self:CanExport() then AvidAngler:Print(L["PERF_EXPORT_PERFORMANCE_HISTORY_OUTSIDE_COMBAT_AND"]); return end
    local Theme=AvidAngler.UI.Theme
    -- Formatting is explicit user work and excluded from monitoring.
    local wasActive=self:GetState()
    if wasActive then self:Stop() end
    local report=self:Report()
    pages={}; local chunk=""
    for line in (report.."\n"):gmatch("([^\n]*)\n") do
        if #chunk+#line>24000 then pages[#pages+1]=chunk; chunk="" end
        chunk=chunk..line.."\n"
    end
    pages[#pages+1]=chunk; page=1
    if not panel then
        panel=Theme:CreatePanel(UIParent,"panel","border")
        _G.AvidAnglerPerformanceReport=panel
        panel:SetSize(800,550); panel:SetPoint("CENTER"); panel:SetFrameStrata("DIALOG")
        panel:EnableMouse(true); panel:SetMovable(true); panel:RegisterForDrag("LeftButton")
        panel:SetScript("OnDragStart",panel.StartMoving); panel:SetScript("OnDragStop",panel.StopMovingOrSizing)
        table.insert(UISpecialFrames,"AvidAnglerPerformanceReport")
        local title=panel:CreateFontString(nil,"OVERLAY","GameFontNormalLarge")
        title:SetFontObject(Theme.font.heading)
        title:SetPoint("TOPLEFT",16,-16); title:SetText(L["PERF_PERFORMANCE_HISTORY_COPY_EACH_PAGE_WITH"])
        local scroll=CreateFrame("ScrollFrame",nil,panel,"UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT",16,-50); scroll:SetPoint("BOTTOMRIGHT",-36,62)
        output=CreateFrame("EditBox",nil,scroll)
        output:SetMultiLine(true); output:SetAutoFocus(false); output:SetFontObject("ChatFontNormal")
        output:SetWidth(735); output:SetMaxLetters(0)
        output:SetScript("OnEscapePressed",function() panel:Hide() end)
        output:SetScript("OnTextChanged",function(box) box:SetHeight(math.max(400,(box:GetNumLines() or 1)*16+20)) end)
        scroll:SetScrollChild(output)
        pageLabel=panel:CreateFontString(nil,"OVERLAY","GameFontHighlight")
        pageLabel:SetPoint("BOTTOM",0,24)
        local function refresh()
            output:SetText(pages[page]); scroll:SetVerticalScroll(0); output:SetCursorPosition(0)
            pageLabel:SetText(string.format(L["PERF_PAGE_D_OF_D"],page,#pages))
        end
        panel.refresh=refresh
        local function button(text,x,fn)
            local b=Theme:CreateButton(panel,text)
            b:SetSize(110,26); b:SetPoint("BOTTOMLEFT",x,16); b:SetScript("OnClick",fn)
        end
        button(L["PERF_PREVIOUS"],16,function() page=math.max(1,page-1); refresh() end)
        button(L["PERF_NEXT"],136,function() page=math.min(#pages,page+1); refresh() end)
        button(L["PERF_CLOSE"],670,function() panel:Hide() end)
    end
    panel.refresh(); panel:Show()
    if wasActive then AvidAngler:Print(L["PERF_EXPORT_STOPPED_RECORDING_TO_EXCLUDE_REPORT"]) end
end
