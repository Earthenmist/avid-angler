-- Avid Angler
-- Midnight-safe value helpers for Blizzard API results.
--
-- Every read of Blizzard-sourced data that could plausibly be gated —
-- achievement/criteria data, spell descriptions, or any API call wrapped
-- for safety rather than assumed reliable — should route through these
-- helpers rather than being trusted directly.

local _, AvidAngler = ...

function AvidAngler:IsSecretValue(value)
    return issecretvalue and issecretvalue(value) and true or false
end

function AvidAngler:CanAccessValue(value)
    if not self:IsSecretValue(value) then return true end
    if not canaccessvalue then return false end

    local ok, accessible = pcall(canaccessvalue, value)
    return ok and accessible and true or false
end

function AvidAngler:SafeValue(value, fallback)
    if self:IsSecretValue(value) and not self:CanAccessValue(value) then
        return fallback
    end
    return value
end

function AvidAngler:ScrubSecretValues(...)
    local values = { ... }
    for index = 1, select("#", ...) do
        values[index] = self:SafeValue(values[index], nil)
    end
    return unpack(values, 1, select("#", ...))
end

function AvidAngler:SafeString(value, fallback)
    value = self:SafeValue(value, nil)
    if type(value) == "string" then return value end
    if type(value) == "number" or type(value) == "boolean" then return tostring(value) end
    return fallback or ""
end

function AvidAngler:SafeNumber(value, fallback)
    value = self:SafeValue(value, nil)
    if type(value) == "number" then return value end
    if type(value) == "string" then return tonumber(value) or fallback end
    return fallback
end

-- Calls fn with the given arguments and returns its first result, or
-- fallback if the call errors or the result is an inaccessible secret
-- value. Use this around any Blizzard API read whose failure mode should
-- be "skip this update" rather than a Lua error.
function AvidAngler:SafeCall(fn, fallback, ...)
    if type(fn) ~= "function" then return fallback end

    local ok, result = pcall(fn, ...)
    if not ok then return fallback end
    return self:SafeValue(result, fallback)
end
