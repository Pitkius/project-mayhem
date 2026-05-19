local QBCore = exports['qb-core']:GetCoreObject()

--- Sinchronizuoja užraktą visiems klientams (M meniu / išorinis lock).
RegisterNetEvent('fivempro_hud:server:setVehicleLock', function(netId, locked)
    local src = source
    netId = tonumber(netId)
    if not netId or netId < 1 then return end

    local veh = NetworkGetEntityFromNetworkId(netId)
    if not veh or veh == 0 then return end

    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return end

    local pc = GetEntityCoords(ped)
    local vc = GetEntityCoords(veh)
    if #(pc - vc) > 12.0 then return end

    TriggerClientEvent('fivempro_hud:client:syncVehicleLock', -1, netId, locked == true)
end)
