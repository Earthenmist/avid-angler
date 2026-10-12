-- Avid Angler
-- Resolve translated guide references through the client's game-content names.
local _, AvidAngler = ...
local names = {}

local function ReadName(kind, id)
    local ok, value
    if kind == "item" and C_Item and type(C_Item.GetItemInfo) == "function" then
        ok, value = pcall(C_Item.GetItemInfo, id)
    elseif kind == "achievement" and type(GetAchievementInfo) == "function" then
        local ignored
        ok, ignored, value = pcall(GetAchievementInfo, id)
    elseif kind == "map" and C_Map and type(C_Map.GetMapInfo) == "function" then
        ok, value = pcall(C_Map.GetMapInfo, id)
        if not ok or AvidAngler:IsSecretValue(value) or type(value) ~= "table" then return nil end
        value = value.name
    elseif kind == "criterion" and type(GetAchievementNumCriteria) == "function"
        and type(GetAchievementCriteriaInfo) == "function" then
        local owner = AvidAngler.Data.GuideReferenceOwners and AvidAngler.Data.GuideReferenceOwners[id]
        if not owner then return nil end
        local count
        ok, count = pcall(GetAchievementNumCriteria, owner)
        if not ok or AvidAngler:IsSecretValue(count) or type(count) ~= "number" then return nil end
        for index = 1, count do
            local result = { pcall(GetAchievementCriteriaInfo, owner, index) }
            if not result[1] or AvidAngler:IsSecretValue(result[2]) or AvidAngler:IsSecretValue(result[11]) then return nil end
            if result[11] == id then
                value = result[2]
                break
            end
        end
    end
    if not ok or AvidAngler:IsSecretValue(value) then return nil end
    return type(value) == "string" and value ~= "" and value or nil
end

function AvidAngler:ResolveGuideText(text)
    if self:IsSecretValue(text) or type(text) ~= "string" then return "" end
    local references = self.Data and self.Data.GuideReferences or {}
    local locale = self:GetActiveLocale()
    names[locale] = names[locale] or {}
    local cache = names[locale]
    local paused = self:IsRuntimeDisabled() or InCombatLockdown()
    return (text:gsub("{([a-z]+):(%d+)}", function(kind, digits)
        local token = kind .. ":" .. digits
        local fallback = references[token]
        if not fallback then return "{" .. token .. "}" end
        if not cache[token] and not paused then
            cache[token] = ReadName(kind, tonumber(digits))
        end
        return cache[token] or fallback
    end))
end
