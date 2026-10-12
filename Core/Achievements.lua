-- Avid Angler
-- Readable achievement snapshots and player-requested Blizzard actions.
local _, AvidAngler = ...
local Achievements = { cache = {}, completionCache = {}, completionFresh = {}, completionNames = {}, chains = {} }
AvidAngler.Achievements = Achievements

function Achievements:IsPaused()
    return AvidAngler:IsRuntimeDisabled() or InCombatLockdown()
end

-- Reject the whole payload when any return is secret. Preserve the previous snapshot.
local function Read(fn, ...)
    if type(fn) ~= "function" then return nil end
    local result = { pcall(fn, ...) }
    if not result[1] then return nil end
    for _, value in pairs(result) do
        if AvidAngler:IsSecretValue(value) then return nil end
    end
    return result
end

function Achievements:GetSnapshot(entry)
    local previous = self.cache[entry.id]
    if self:IsPaused() then return previous end
    local info = Read(GetAchievementInfo, entry.id)
    if not info or type(info[2]) ~= "number" or type(info[3]) ~= "string" then return previous end
    local snapshot = {
        id = entry.id, name = info[3], completed = info[5] == true,
        description = info[9], icon = info[11], reward = info[12], guild = info[13] == true,
        criteria = {},
    }
    local count = Read(GetAchievementNumCriteria, entry.id)
    if not count or type(count[2]) ~= "number" then return previous end
    local done = 0
    for index = 1, count[2] do
        local criterion = Read(GetAchievementCriteriaInfo, entry.id, index)
        if not criterion or type(criterion[2]) ~= "string" then return previous end
        local row = { name = criterion[2], completed = criterion[4] == true,
            quantity = criterion[5], required = criterion[6] }
        snapshot.criteria[#snapshot.criteria + 1] = row
        if row.completed then done = done + 1 end
    end
    if #snapshot.criteria == 1 then
        local row = snapshot.criteria[1]
        if type(row.quantity) == "number" and type(row.required) == "number" and row.required > 0 then
            snapshot.current = math.max(0, math.min(row.quantity, row.required))
            snapshot.total = row.required
        end
    elseif #snapshot.criteria > 1 then
        snapshot.current, snapshot.total = done, #snapshot.criteria
        snapshot.checklist = true
    end
    if snapshot.completed and snapshot.total and not snapshot.checklist then snapshot.current = snapshot.total end
    self.cache[entry.id] = snapshot
    return snapshot
end

function Achievements:GetHideCompleted()
    local settings = AvidAngler.DB and AvidAngler.DB.settings
    return settings and settings.achievements and settings.achievements.hideCompleted == true or false
end

function Achievements:SetHideCompleted(hidden)
    local db = AvidAngler.DB
    if not db then return end
    db.settings = db.settings or {}
    db.settings.achievements = db.settings.achievements or {}
    db.settings.achievements.hideCompleted = hidden and true or false
end

function Achievements:InvalidateCompletions()
    self.completionFresh = {}
end

function Achievements:GetHideAbyssAnglers()
    local settings = AvidAngler.DB and AvidAngler.DB.settings
    return not (settings and settings.achievements and settings.achievements.hideAbyssAnglers == false)
end

function Achievements:SetHideAbyssAnglers(hidden)
    local db = AvidAngler.DB
    if not db then return end
    db.settings = db.settings or {}
    db.settings.achievements = db.settings.achievements or {}
    db.settings.achievements.hideAbyssAnglers = hidden and true or false
end

function Achievements:IsCompleted(entry)
    if self:IsPaused() or self.completionFresh[entry.id] then
        return self.completionCache[entry.id]
    end
    local info = Read(GetAchievementInfo, entry.id)
    if info and type(info[2]) == "number" and type(info[5]) == "boolean" then
        self.completionCache[entry.id] = info[5]
        self.completionNames[entry.id] = info[3]
        self.completionFresh[entry.id] = true
    end
    return self.completionCache[entry.id]
end

-- Only collapse chains whose complete linkage is readable and acyclic.
function Achievements:GetChain(entry)
    if self.chains[entry.id] then return self.chains[entry.id] end
    if self:IsPaused() then return nil end
    local function Link(fn, id)
        local result = Read(fn, id)
        if not result then return nil, false end
        local target = result[2]
        if target == nil then return nil, true end
        if type(target) ~= "number" or target <= 0 or target ~= math.floor(target) then return nil, false end
        return target, true
    end
    local root, visited, foundRoot = entry.id, {}, false
    for _ = 1, 64 do
        if visited[root] then return nil end
        visited[root] = true
        local previous, readable = Link(GetPreviousAchievement, root)
        if not readable then return nil end
        if not previous then foundRoot = true; break end
        root = previous
    end
    if not foundRoot then return nil end
    local ids, seen, current = {}, {}, root
    for _ = 1, 64 do
        if seen[current] then return nil end
        seen[current] = true
        ids[#ids + 1] = current
        local nextID, readable = Link(GetNextAchievement, current)
        if not readable then return nil end
        if not nextID then
            if not seen[entry.id] then return nil end
            for _, id in ipairs(ids) do self.chains[id] = ids end
            return ids
        end
        local previous, backReadable = Link(GetPreviousAchievement, nextID)
        if not backReadable or previous ~= current then return nil end
        current = nextID
    end
    return nil
end

function Achievements:GetChainSteps(entry)
    local steps = {}
    local currentFound = false
    for _, id in ipairs(entry.chain or {}) do
        local completed = self:IsCompleted({ id = id })
        local status = completed == true and "ACH_COMPLETE" or "ACH_CHAIN_UPCOMING"
        if completed == nil then
            status = "ACH_PROGRESS_UNAVAILABLE"
        elseif not completed and not currentFound then
            status = "ACH_CHAIN_CURRENT"
        end
        if completed ~= true then currentFound = true end
        steps[#steps + 1] = { id = id, name = self.completionNames[id] or AvidAngler.L["ACH_ID_FALLBACK"]:format(id), status = status }
    end
    return steps
end

function Achievements:GetEntries(expansion, includeHistorical, hideCompleted, hideAbyssAnglers)
    local rows, candidates, eligible = {}, {}, {}
    local faction = AvidAngler:SafeCall(UnitFactionGroup, nil, "player")
    for _, entry in ipairs(AvidAngler.Data.AchievementCatalog) do
        if entry.expansion == expansion and (includeHistorical or not entry.historical)
            and (entry.faction == "Both" or entry.faction == faction) then
            if not (expansion == "midnight" and hideAbyssAnglers and entry.abyssAnglers) then
                candidates[#candidates + 1] = entry
                eligible[entry.id] = entry
            end
        end
    end
    local emitted = {}
    for _, entry in ipairs(candidates) do
        if not emitted[entry.id] then
            local chain = self:GetChain(entry)
            local selected, selectedIndex
            if chain and #chain > 1 then
                for index, id in ipairs(chain) do
                    if eligible[id] then
                        emitted[id] = true
                        if not selected or self:IsCompleted(selected) == true then
                            selected, selectedIndex = eligible[id], index
                        end
                    end
                end
            end
            selected = selected or entry
            if not hideCompleted or self:IsCompleted(selected) ~= true then
                if chain and #chain > 1 then
                    local row = {}
                    for key, value in pairs(selected) do row[key] = value end
                    row.chain, row.chainIndex = chain, selectedIndex
                    rows[#rows + 1] = row
                else
                    rows[#rows + 1] = selected
                end
            end
        end
    end
    return rows
end

function Achievements:IsTracked(id)
    if self:IsPaused() then return nil end
    local kind = Enum and Enum.ContentTrackingType and Enum.ContentTrackingType.Achievement
    local state = kind and C_ContentTracking and Read(C_ContentTracking.IsTracking, kind, id)
    return state and state[2]
end

function Achievements:ToggleTracking(entry)
    if self:IsPaused() then return false, "ACH_ACTION_PAUSED" end
    local tracked = self:IsTracked(entry.id)
    local kind = Enum and Enum.ContentTrackingType and Enum.ContentTrackingType.Achievement
    if tracked == nil or not kind or not C_ContentTracking then return false, "ACH_ACTION_UNAVAILABLE" end
    if tracked then
        local stopType = Enum.ContentTrackingStopType and Enum.ContentTrackingStopType.Manual
        if not stopType then return false, "ACH_ACTION_UNAVAILABLE" end
        local result = Read(C_ContentTracking.StopTracking, kind, entry.id, stopType)
        return result ~= nil, result == nil and "ACH_ACTION_UNAVAILABLE" or nil
    end
    local snapshot = self:GetSnapshot(entry)
    if not snapshot then return false, "ACH_ACTION_UNAVAILABLE" end
    if snapshot.completed then return false, "ACH_ALREADY_COMPLETE" end
    local result = Read(C_ContentTracking.StartTracking, kind, entry.id)
    if not result then return false, "ACH_ACTION_UNAVAILABLE" end
    if result[2] ~= nil then
        if ContentTrackingUtil and ContentTrackingUtil.DisplayTrackingError then
            ContentTrackingUtil.DisplayTrackingError(result[2])
        end
        return false, "ACH_TRACK_FAILED"
    end
    return true
end

function Achievements:OpenBlizzard(entry)
    if self:IsPaused() then return false, "ACH_ACTION_PAUSED" end
    local snapshot = self:GetSnapshot(entry)
    if not snapshot then return false, "ACH_ACTION_UNAVAILABLE" end
    if not AchievementFrame then
        local result = C_AddOns and Read(C_AddOns.LoadAddOn, "Blizzard_AchievementUI")
        if not result or not result[2] then return false, "ACH_ACTION_UNAVAILABLE" end
    end
    if not AchievementFrame or not AchievementFrame_SelectAchievement then return false, "ACH_ACTION_UNAVAILABLE" end
    local ok = pcall(function()
        if AchievementFrameComparison then AchievementFrameComparison:Hide() end
        AchievementFrameTab_OnClick = AchievementFrameBaseTab_OnClick
        AchievementFrame_SetTabs()
        ShowUIPanel(AchievementFrame)
        AchievementFrameTab_OnClick(snapshot.guild and 2 or 1)
        AchievementFrame_SelectAchievement(entry.id, true)
    end)
    return ok, not ok and "ACH_ACTION_UNAVAILABLE" or nil
end
