local QBCore = exports['qb-core']:GetCoreObject()

local function reviveOnJoinIfNeeded()
    local playerData = QBCore.Functions.GetPlayerData()
    local metadata = playerData.metadata or {}
    local isDead = metadata.isdead == true or metadata.inlaststand == true
    if isDead then
        return
    end

    local ped = PlayerPedId()
    if IsEntityDead(ped) or GetEntityHealth(ped) <= 101 then
        local coords = GetEntityCoords(ped)
        local heading = GetEntityHeading(ped)
        NetworkResurrectLocalPlayer(coords.x, coords.y, coords.z + 0.3, heading, true, false)
        ClearPedBloodDamage(ped)
        ClearPedTasksImmediately(ped)
    end

    SetEntityHealth(ped, 200)
    SetPedArmour(ped, tonumber(metadata.armor) or 0)
    TriggerServerEvent('fivempro:spawnfix:server:normalizeState')
end

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    Wait(1200)
    reviveOnJoinIfNeeded()
end)

RegisterNetEvent('qb-spawn:client:spawned', function()
    Wait(250)
    reviveOnJoinIfNeeded()
end)

AddEventHandler('playerSpawned', function()
    Wait(250)
    reviveOnJoinIfNeeded()
end)
