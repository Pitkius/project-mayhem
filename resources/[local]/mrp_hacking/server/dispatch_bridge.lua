--- Saugus PD alert per mrp_dispatch (export arba event fallback).
--- Fix: "No such export CreateDispatchCall" kai resursas started, bet export dar nepasiekiamas.

local function normalizeCoords(coords)
    if not coords then return nil end
    local x = coords.x or coords[1]
    local y = coords.y or coords[2]
    local z = coords.z or coords[3]
    if not x or not y or not z then return nil end
    return { x = x + 0.0, y = y + 0.0, z = z + 0.0 }
end

--- @return boolean
function MRP_DispatchAlert(service, callType, coords, text, createdBy)
    service = service or 'police'
    callType = callType or 'robbery'
    text = text or 'Apiplėšimas'
    local c = normalizeCoords(coords)
    if not c then return false end

    if GetResourceState('mrp_dispatch') ~= 'started' then
        return false
    end

    local ok = pcall(function()
        exports['mrp_dispatch']:CreateDispatchCall(service, callType, c, text, createdBy)
    end)
    if ok then return true end

    --- Fallback jei export neegzistuoja (senas build / load race)
    TriggerEvent('mrp_dispatch:internal:createCall', service, callType, c, text, createdBy)
    return true
end

exports('DispatchAlert', MRP_DispatchAlert)
