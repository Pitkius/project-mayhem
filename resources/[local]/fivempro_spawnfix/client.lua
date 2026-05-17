local QBCore = exports['qb-core']:GetCoreObject()
local loginRequested = false

local function shutdownLoadingScreens()
    ShutdownLoadingScreen()
    ShutdownLoadingScreenNui()
end

local function resolveSpawnCoords(position)
    if not position then
        return Config.DefaultSpawn
    end
    local x = position.x or position[1] or Config.DefaultSpawn.x
    local y = position.y or position[2] or Config.DefaultSpawn.y
    local z = position.z or position[3] or Config.DefaultSpawn.z
    local w = position.w or position.a or position.h or Config.DefaultSpawn.w or 0.0
    return vector4(x, y, z, w)
end

local function applySavedVitals()
    local playerData = QBCore.Functions.GetPlayerData()
    if not playerData or not playerData.metadata then return end

    local metadata = playerData.metadata
    if metadata.isdead or metadata.inlaststand then
        return
    end

    local ped = PlayerPedId()
    local savedHealth = tonumber(metadata.health)
    if savedHealth and savedHealth > 0 then
        if IsEntityDead(ped) then
            local coords = GetEntityCoords(ped)
            local heading = GetEntityHeading(ped)
            NetworkResurrectLocalPlayer(coords.x, coords.y, coords.z + 0.2, heading, true, false)
            ClearPedBloodDamage(ped)
        end
        SetEntityHealth(ped, math.max(101, math.min(savedHealth, 200)))
    end

    SetPedArmour(ped, math.max(0, math.min(tonumber(metadata.armor) or 0, 100)))
    TriggerEvent('hud:client:UpdateNeeds')
end

local function requestLogin()
    if loginRequested then return end
    loginRequested = true
    shutdownLoadingScreens()
    DoScreenFadeOut(0)
    TriggerServerEvent('fivempro_spawnfix:server:requestLogin')
end

RegisterNetEvent('fivempro_spawnfix:client:beginLogin', function()
    loginRequested = false
    requestLogin()
end)

RegisterNetEvent('fivempro_spawnfix:client:spawn', function()
    local playerData = QBCore.Functions.GetPlayerData()
    local spawn = resolveSpawnCoords(playerData.position)
    local ped = PlayerPedId()

    DoScreenFadeOut(500)
    Wait(400)

    SetEntityCoords(ped, spawn.x, spawn.y, spawn.z, false, false, false, false)
    SetEntityHeading(ped, spawn.w)
    FreezeEntityPosition(ped, true)
    SetEntityVisible(ped, true)

    if GetResourceState('qb-houses') == 'started' then
        TriggerServerEvent('qb-houses:server:SetInsideMeta', 0, false)
    end
    if GetResourceState('qb-apartments') == 'started' then
        TriggerServerEvent('qb-apartments:server:SetInsideMeta', 0, 0, false)
    end

    TriggerEvent('QBCore:Client:OnPlayerLoaded')

    Wait(1500)
    FreezeEntityPosition(ped, false)
    applySavedVitals()
    TriggerEvent('qb-weathersync:client:EnableSync')
    DoScreenFadeIn(500)
end)

CreateThread(function()
    while not NetworkIsSessionStarted() do
        Wait(0)
    end
    requestLogin()
end)

CreateThread(function()
    while true do
        Wait(45000)
        if LocalPlayer.state.isLoggedIn then
            TriggerServerEvent('fivempro_spawnfix:server:syncVitals')
        end
    end
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    Wait(2000)
    applySavedVitals()
end)
