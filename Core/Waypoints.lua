-- Avid Angler
-- Player-requested waypoints using explicit map IDs and percentage coordinates.
local _, AvidAngler = ...

function AvidAngler:SetWaypoint(location, title)
    if self:IsRuntimeDisabled() or InCombatLockdown() then return false, "ACH_ACTION_PAUSED" end
    if type(location) ~= "table" then return false, "ACH_WAYPOINT_FAILED" end
    local mapID, x, y = location.mapID, location.x, location.y
    for _, value in pairs({ mapID, x, y, title }) do
        if self:IsSecretValue(value) then return false, "ACH_WAYPOINT_FAILED" end
    end
    if type(mapID) ~= "number" or mapID <= 0 or mapID ~= math.floor(mapID)
        or type(x) ~= "number" or not (x >= 0 and x <= 100)
        or type(y) ~= "number" or not (y >= 0 and y <= 100)
        or type(title) ~= "string" then return false, "ACH_WAYPOINT_FAILED" end
    x, y = x / 100, y / 100
    if TomTom and type(TomTom.AddWaypoint) == "function" then
        local ok, uid = pcall(TomTom.AddWaypoint, TomTom, mapID, x, y,
            { title = title, source = "Avid Angler", persistent = false, minimap = true, world = true, crazy = true })
        if ok and not self:IsSecretValue(uid) and uid then return true, "ACH_WAYPOINT_TOMTOM_SET" end
    end
    if not C_Map or type(C_Map.SetUserWaypoint) ~= "function"
        or not UiMapPoint or type(UiMapPoint.CreateFromCoordinates) ~= "function" then
        return false, "ACH_WAYPOINT_FAILED"
    end
    if self:SafeCall(C_Map.CanSetUserWaypointOnMap, nil, mapID) ~= true then
        return false, "ACH_WAYPOINT_UNSUPPORTED"
    end
    local ok, point = pcall(UiMapPoint.CreateFromCoordinates, mapID, x, y)
    if not ok or self:IsSecretValue(point) or not point then return false, "ACH_WAYPOINT_FAILED" end
    ok = pcall(C_Map.SetUserWaypoint, point)
    if not ok then return false, "ACH_WAYPOINT_FAILED" end
    if C_SuperTrack and type(C_SuperTrack.SetSuperTrackedUserWaypoint) == "function" then
        pcall(C_SuperTrack.SetSuperTrackedUserWaypoint, true)
    end
    return true, "ACH_WAYPOINT_BLIZZARD_SET"
end
