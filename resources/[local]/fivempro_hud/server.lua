local QBCore = exports['qb-core']:GetCoreObject()

local function playerNearVehicle(src, netId, maxDist)
    netId = tonumber(netId)
    if not netId or netId < 1 then return false end
    local veh = NetworkGetEntityFromNetworkId(netId)
    if not veh or veh == 0 then return false end
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end
    return #(GetEntityCoords(ped) - GetEntityCoords(veh)) <= (maxDist or 12.0)
end

--- Sinchronizuoja užraktą visiems klientams (M meniu / išorinis lock).
RegisterNetEvent('fivempro_hud:server:setVehicleLock', function(netId, locked)
    local src = source
    if not playerNearVehicle(src, netId, 12.0) then return end
    TriggerClientEvent('fivempro_hud:client:syncVehicleLock', -1, netId, locked == true)
end)

--- Durų būsena (atidaryta/uždaryta) – sinchronizacija visiems žaidėjams.
RegisterNetEvent('fivempro_hud:server:setVehicleDoor', function(netId, doorIndex, open)
    local src = source
    doorIndex = tonumber(doorIndex)
    if doorIndex == nil or doorIndex < 0 or doorIndex > 5 then return end
    if not playerNearVehicle(src, netId, 10.0) then return end
    TriggerClientEvent('fivempro_hud:client:syncVehicleDoor', -1, netId, doorIndex, open == true)
end)
