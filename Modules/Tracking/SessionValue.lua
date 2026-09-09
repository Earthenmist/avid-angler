-- Avid Angler
-- Session valuation consumes recorded catches; it never observes loot or scans auctions.
local _, AvidAngler = ...
local Value = {}
AvidAngler.Modules.Tracking.SessionValue = Value
local entries, order, started, cursor = {}, {}, time(), 1
local lastRefresh = nil
local hourlyRate, lastHourlyRefresh = nil, nil
local HOURLY_REFRESH_SECONDS = 30

local function ReadableNumber(value)
    if AvidAngler:IsSecretValue(value) then return nil end
    if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then return nil end
    return value
end

local function Paused()
    return (InCombatLockdown and InCombatLockdown())
        or (AvidAngler.IsRuntimeDisabled and AvidAngler:IsRuntimeDisabled())
end

local function MarketPrice(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, price = pcall(fn, ...)
    if ok and AvidAngler:IsSecretValue(price) then return nil, true end
    price = ok and ReadableNumber(price) or nil
    if price and price > 0 then return math.floor(price) end
end

function Value:ResolvePrice(itemID)
    if Paused() then return nil end
    itemID = ReadableNumber(itemID)
    if not itemID or itemID <= 0 or itemID % 1 ~= 0 then return nil end
    -- Item metadata must be readable before deciding whether auction prices apply.
    local getInfo = C_Item and C_Item.GetItemInfo
    if not getInfo then return nil end
    local info = { pcall(getInfo, itemID) }
    if not info[1] or AvidAngler:IsSecretValue(info[2]) or not info[2] then return nil end
    local vendor = ReadableNumber(info[12])
    local binding = ReadableNumber(info[15])
    if binding == nil then return nil end
    -- Only unbound and bind-on-equip/use items receive auction estimates.
    if binding == 0 or binding == 2 or binding == 3 then
        local api = Auctionator and Auctionator.API and Auctionator.API.v1
        local price, unreadable = MarketPrice(api and api.GetAuctionPriceByItemID, "AvidAngler", itemID)
        if unreadable then return nil end
        if price then return price, "auctionator" end
        price, unreadable = MarketPrice(TSM_API and TSM_API.GetCustomPriceValue, "dbmarket", "i:" .. itemID)
        if unreadable then return nil end
        if price then return price, "tsm" end
    end
    if vendor and vendor >= 0 then return math.floor(vendor), "vendor" end
end

function Value:Reset()
    entries, order, started, cursor = {}, {}, time(), 1
    lastRefresh = nil
    hourlyRate, lastHourlyRefresh = nil, nil
end

function Value:RecordCatch(record)
    if Paused() or type(record) ~= "table" then return end
    local itemID = ReadableNumber(record.itemID)
    local quantity = ReadableNumber(record.quantity)
    if not itemID or itemID <= 0 or itemID % 1 ~= 0 or not quantity or quantity <= 0 or quantity % 1 ~= 0 then return end
    if not entries[itemID] then
        entries[itemID] = { quantity = 0 }
        order[#order + 1] = itemID
    end
    entries[itemID].quantity = entries[itemID].quantity + quantity
end

function Value:GetSummary()
    local now = time()
    -- Bound third-party API work, including when a large session is first displayed.
    if not Paused() and lastRefresh ~= now then
        lastRefresh = now
        local checked, queried = 0, 0
        while checked < #order and queried < 8 do
            if cursor > #order then cursor = 1 end
            local itemID = order[cursor]
            local entry = entries[itemID]
            cursor, checked = cursor + 1, checked + 1
            if not entry.checkedAt or now - entry.checkedAt >= (entry.price and 30 or 5) then
                local price, source = self:ResolvePrice(itemID)
                -- Keep the last readable valuation through temporary data/API failures.
                if price ~= nil then entry.price, entry.source = price, source end
                entry.checkedAt = now
                queried = queried + 1
            end
        end
    end
    local summary = { value = 0, unknown = 0, sources = {}, elapsed = math.max(0, now - started) }
    for _, itemID in ipairs(order) do
        local entry = entries[itemID]
        if entry.price ~= nil then
            summary.value = summary.value + entry.price * entry.quantity
            summary.sources[entry.source] = true
        else
            summary.unknown = summary.unknown + entry.quantity
        end
    end
    -- Hold the displayed rate between samples so elapsed time does not make it tick every second.
    if not Paused() and summary.elapsed >= 60
        and (not lastHourlyRefresh or now - lastHourlyRefresh >= HOURLY_REFRESH_SECONDS) then
        hourlyRate = summary.value * 3600 / summary.elapsed
        lastHourlyRefresh = now
    end
    summary.perHour = hourlyRate
    return summary
end

function Value:GetDisplayText()
    local summary = self:GetSummary()
    local L = AvidAngler.L
    local function Money(copper) return GetCoinTextureString(math.floor(copper)) end
    local sources = {}
    for _, source in ipairs({ "auctionator", "tsm", "vendor" }) do
        if summary.sources[source] then sources[#sources + 1] = L["SESSION_VALUE_SOURCE_" .. source:upper()] end
    end
    return L["SESSION_VALUE_TOTAL"]:format(Money(summary.value), summary.perHour and Money(summary.perHour) or "-"),
        L["SESSION_VALUE_SOURCES"]:format(#sources > 0 and table.concat(sources, ", ") or "-", summary.unknown)
end
