-- Avid Angler
-- Safe capture and display helpers for catch-location detail.

local _, AvidAngler = ...

local Location = {}
AvidAngler.Location = Location

local function NormalizeName(name)
    if type(name) ~= "string" then
        return nil
    end

    local normalized = name:match("^%s*(.-)%s*$")
    if normalized == "" then
        return nil
    end
    return normalized
end

function Location:GetCurrentSubzoneName()
    if (InCombatLockdown and InCombatLockdown())
        or (AvidAngler.IsRuntimeDisabled and AvidAngler:IsRuntimeDisabled()) then
        return nil
    end

    if not AvidAngler.SafeCall then
        return nil
    end
    return NormalizeName(AvidAngler:SafeCall(GetSubZoneText, nil))
end

function Location:FormatCatchLocation(zoneName, subzoneName)
    zoneName = NormalizeName(zoneName)
    subzoneName = NormalizeName(subzoneName)

    if not zoneName then
        return subzoneName or ""
    end
    if not subzoneName or subzoneName:lower() == zoneName:lower() then
        return zoneName
    end

    local formatString = AvidAngler.L and AvidAngler.L["CATCH_HISTORY_LOCATION_FORMAT"] or "%s - %s"
    return formatString:format(zoneName, subzoneName)
end
