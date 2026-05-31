local QBCore = exports['qb-core']:GetCoreObject()
local lastSpray = 0

local function getCurrentTurfId()
    local p = GetEntityCoords(PlayerPedId())
    return Config.FindTurfAt(p.x, p.y)
end

local function trySprayGraffiti()
    local cfg = Config.Graffiti or {}
    local now = GetGameTimer()
    if now - lastSpray < (cfg.cooldownSec or 120) * 1000 then
        return QBCore.Functions.Notify('Palauk prieš kitą graffiti.', 'error')
    end
    local turfId = getCurrentTurfId()
    if not turfId then
        return QBCore.Functions.Notify('Turi būti turf zonoje.', 'error')
    end
    lastSpray = now
    local ped = PlayerPedId()
    RequestAnimDict('switch@franklin@lamar_tagging_wall')
    while not HasAnimDictLoaded('switch@franklin@lamar_tagging_wall') do Wait(10) end
    TaskPlayAnim(ped, 'switch@franklin@lamar_tagging_wall', 'lamar_tagging_wall_loop_lamar', 8.0, -8.0, -1, 1, 0, false, false, false)
    GangRunProgressAsync('gang_graffiti', 'Žymi teritoriją...', cfg.durationMs or 4500, {
        disableMovement = true,
        disableCarMovement = true,
        disableCombat = true,
    }, true, function()
        ClearPedTasks(ped)
        TriggerServerEvent('fivempro_gangs:server:placeGraffiti', turfId)
    end, function()
        ClearPedTasks(ped)
    end)
end

RegisterNetEvent('fivempro_gangs:client:useSprayCan', function()
    trySprayGraffiti()
end)

RegisterNetEvent('fivempro_gangs:client:turfInfluenceUpdated', function()
    TriggerServerEvent('fivempro_gangs:server:requestTabletRefresh')
end)
