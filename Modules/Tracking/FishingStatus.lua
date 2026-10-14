-- Avid Angler
-- Readable fishing skill and equipped-pole progress for the main window.
local _, AvidAngler = ...
local Status = {}
AvidAngler.Modules.FishingStatus = Status
local POLE_ID = 244790
local FISHING_TOOL_SLOT = 28

local function CanRead()
    return not InCombatLockdown()
        and not (AvidAngler.IsRuntimeDisabled and AvidAngler:IsRuntimeDisabled())
end

local function Number(value)
    if AvidAngler:IsSecretValue(value) or type(value) ~= "number" then return nil end
    if value < 0 or value ~= value or value == math.huge then return nil end
    return value
end

function Status:GetSkill(expansionKey)
    local data = AvidAngler.DataLayer
    local snapshot = data:GetCharacterFishingSkillSnapshot()
    local cached = snapshot and snapshot.levels and snapshot.levels[expansionKey]
    if CanRead() then
        local ids = AvidAngler.Data.TrainerCatalog:GetProfessionIDs(expansionKey)
        local candidates = {}
        for _, id in ipairs(ids) do
            local info = AvidAngler:SafeCall(C_TradeSkillUI and C_TradeSkillUI.GetProfessionInfoBySkillLineID, nil, id)
            if not AvidAngler:IsSecretValue(info) and info ~= nil then candidates[#candidates + 1] = info end
        end
        local journal = AvidAngler:SafeCall(C_TradeSkillUI and C_TradeSkillUI.GetChildProfessionInfos, nil)
        if not AvidAngler:IsSecretValue(journal) and type(journal) == "table" then
            for _, info in ipairs(journal) do candidates[#candidates + 1] = info end
        end
        for _, info in ipairs(candidates) do
            if not AvidAngler:IsSecretValue(info) and type(info) == "table" then
                for _, id in ipairs(ids) do
                    if Number(info.professionID) == id then
                        local rank, maximum, bonus = Number(info.skillLevel), Number(info.maxSkillLevel), Number(info.skillModifier)
                        if rank and rank > 0 and maximum and maximum >= rank then
                            local level = { rank = rank, maximum = maximum, bonus = bonus }
                            data:SaveCharacterFishingLevel(expansionKey, level)
                            return level, false
                        end
                    end
                end
            end
        end
    end
    return cached, cached ~= nil
end

local venomNames = {
    enUS = "Venom", enGB = "Venom", deDE = "Toxin", frFR = "venin",
    esES = "veneno", esMX = "veneno", itIT = "veleno", ptBR = "Peçonha",
    ruRU = "яд", koKR = "맹독", zhCN = "毒液", zhTW = "毒液",
}

local function PlainText(value)
    if AvidAngler:IsSecretValue(value) or type(value) ~= "string" then return nil end
    return value:gsub("|cn[%w_]+:", ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
        :gsub("|T.-|t", ""):gsub("|A.-|a", ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function Count(value)
    if not value then return nil end
    local digits = value:gsub("[,%.'%s]", ""):gsub("\194\160", ""):gsub("\226\128\175", ""):gsub("^%+", "")
    if not digits:match("^%d+$") then return nil end
    return Number(tonumber(digits))
end

function Status:ReadVenom(tooltip, locale)
    if AvidAngler:IsSecretValue(tooltip) or type(tooltip) ~= "table" then return nil end
    if AvidAngler:IsSecretValue(tooltip.lines) or type(tooltip.lines) ~= "table" then return nil end
    -- The numeric counter has no published currency/stat ID. A tooltip entry
    -- can contain both the equipment description and the formatted counter.
    local label = (venomNames[locale] or venomNames.enUS):lower()
    for _, line in ipairs(tooltip.lines) do
        if not AvidAngler:IsSecretValue(line) and type(line) == "table" then
            local text = PlainText(line.leftText)
            if text then
                text = text:lower():gsub("Яд", "яд"):gsub("：", ":"):gsub("|n", "\n")
                for segment in text:gmatch("[^\r\n]+") do
                    segment = segment:gsub("^%s+", ""):gsub("%s+$", "")
                    local before = segment:match("^%+?%s*(.-)%s*" .. label .. "$")
                    local after = segment:match("^" .. label .. "%s*:?%s*(.-)$")
                    local value = Count(before) or Count(after)
                    if value ~= nil then return value end
                    if segment == label or segment == label .. ":" then
                        value = Count(PlainText(line.rightText))
                        if value ~= nil then return value end
                    end
                end
                -- A signed counter may follow prose in the same text entry,
                -- with no newline. Require the explicit plus and adjacent
                -- localized label, rather than taking the first number.
                local embedded = text:match("%+%s*(%d[%d,%.'%s\194\160\226\128\175]*)%s*" .. label .. "%f[%z%s%p]")
                local value = Count(embedded)
                if value ~= nil then return value end
            end
        end
    end
end

function Status:GetVenom(expansionKey)
    if expansionKey ~= "midnight" then return nil, false end
    if not CanRead() then return nil, nil end
    -- The profession journal's fishing-tool slot, independent of held weapons.
    local itemID = AvidAngler:SafeCall(GetInventoryItemID, nil, "player", FISHING_TOOL_SLOT)
    if Number(itemID) == POLE_ID then
        local tooltip = AvidAngler:SafeCall(C_TooltipInfo and C_TooltipInfo.GetInventoryItem, nil, "player", FISHING_TOOL_SLOT)
        return self:ReadVenom(tooltip, GetLocale()), true
    end
    return nil, false
end
