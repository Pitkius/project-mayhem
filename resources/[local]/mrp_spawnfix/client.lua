local QBCore = exports['qb-core']:GetCoreObject()
local loginRequested = false

local function shutdownLoadingScreens()
    if GetResourceState('mrp_loadscreen') == 'started' then
        TriggerEvent('mrp_loadscreen:client:close')
        pcall(function()
            exports['mrp_loadscreen']:CloseLoadscreen()
        end)
    else
        ShutdownLoadingScreen()
        ShutdownLoadingScreenNui()
    end
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

local function ensurePedUnstuck(ped)
    if not ped or ped == 0 then
        ped = PlayerPedId()
    end
    FreezeEntityPosition(ped, false)
    SetEntityCollision(ped, true, true)
    SetPlayerInvincible(PlayerId(), false)
    ClearPedTasksImmediately(ped)
    return ped
end

local function loadCollisionAround(x, y, z, ped)
    RequestCollisionAtCoord(x, y, z)
    NewLoadSceneStart(x, y, z, x, y, z, 50.0, 0)
    local deadline = GetGameTimer() + 2500
    while IsNetworkLoadingScene() and GetGameTimer() < deadline do
        Wait(0)
    end
    NewLoadSceneStop()

    deadline = GetGameTimer() + 3000
    while not HasCollisionLoadedAroundEntity(ped) and GetGameTimer() < deadline do
        RequestCollisionAtCoord(x, y, z)
        Wait(0)
    end
end

local function findGroundZ(x, y, zHint)
    local hint = zHint or 50.0
    local found, groundZ = GetGroundZFor_3dCoord(x, y, hint + 50.0, false)
    if found then
        return groundZ + 0.08
    end

    for z = 950.0, 0.0, -25.0 do
        found, groundZ = GetGroundZFor_3dCoord(x, y, z, false)
        if found then
            return groundZ + 0.08
        end
    end

    return hint
end

local function safePlacePed(spawn)
    local ped = PlayerPedId()
    local x, y, z, h = spawn.x + 0.0, spawn.y + 0.0, spawn.z + 0.0, spawn.w or 0.0

    loadCollisionAround(x, y, z, ped)
    z = findGroundZ(x, y, z)

    ensurePedUnstuck(ped)
    NetworkResurrectLocalPlayer(x, y, z, h, true, false)
    ped = PlayerPedId()
    SetEntityCoordsNoOffset(ped, x, y, z, false, false, false)
    SetEntityHeading(ped, h)
    ensurePedUnstuck(ped)

    return ped
end

local function applySavedVitals()
    local playerData = QBCore.Functions.GetPlayerData()
    if not playerData or not playerData.metadata then return end

    local metadata = playerData.metadata
    if metadata.isdead or metadata.inlaststand then
        return
    end

    local ped = ensurePedUnstuck(PlayerPedId())
    local savedHealth = tonumber(metadata.health)
    if savedHealth and savedHealth > 0 then
        if IsEntityDead(ped) or IsPedDeadOrDying(ped, true) then
            local coords = GetEntityCoords(ped)
            local heading = GetEntityHeading(ped)
            local gz = findGroundZ(coords.x, coords.y, coords.z)
            NetworkResurrectLocalPlayer(coords.x, coords.y, gz, heading, true, false)
            ped = ensurePedUnstuck(PlayerPedId())
            ClearPedBloodDamage(ped)
        end
        SetEntityHealth(ped, math.max(101, math.min(savedHealth, 200)))
    end

    SetPedArmour(ped, math.max(0, math.min(tonumber(metadata.armor) or 0, 100)))
    ensurePedUnstuck(ped)
    TriggerEvent('hud:client:UpdateNeeds')
end

local function requestLogin()
    if loginRequested then return end
    loginRequested = true
    DoScreenFadeOut(0)
    TriggerServerEvent('mrp_spawnfix:server:requestLogin')
end

RegisterNetEvent('mrp_spawnfix:client:beginLogin', function()
    loginRequested = false
    if GetResourceState('mrp_charcreator') == 'started' then
        TriggerServerEvent('mrp_charcreator:server:sessionStart')
    else
        requestLogin()
    end
end)

RegisterNetEvent('mrp_spawnfix:client:spawn', function()
    local playerData = QBCore.Functions.GetPlayerData()
    local spawn = resolveSpawnCoords(playerData.position)

    DoScreenFadeOut(500)
    Wait(400)

    local ped = safePlacePed(spawn)
    SetEntityVisible(ped, true, false)

    if GetResourceState('qb-houses') == 'started' then
        TriggerServerEvent('qb-houses:server:SetInsideMeta', 0, false)
    end
    if GetResourceState('qb-apartments') == 'started' then
        TriggerServerEvent('qb-apartments:server:SetInsideMeta', 0, 0, false)
    end

    TriggerEvent('QBCore:Client:OnPlayerLoaded')

    Wait(600)
    applySavedVitals()
    ensurePedUnstuck(PlayerPedId())

    TriggerEvent('qb-weathersync:client:EnableSync')
    DoScreenFadeIn(500)
    Wait(600)
    shutdownLoadingScreens()
end)

CreateThread(function()
    while not NetworkIsSessionStarted() do
        Wait(0)
    end
    if GetResourceState('mrp_charcreator') == 'started' then
        loginRequested = true
        TriggerServerEvent('mrp_charcreator:server:sessionStart')
    else
        requestLogin()
    end
end)

--- Klientas praneša ar saugu išsaugoti poziciją (GetEntityHeightAboveGround tik kliente)
CreateThread(function()
    local lastSync = 0
    while true do
        Wait(1000)
        if not LocalPlayer.state.isLoggedIn then
            if LocalPlayer.state.spawnfixSkipSave then
                LocalPlayer.state:set('spawnfixSkipSave', false, true)
            end
            goto continue
        end

        local ped = PlayerPedId()
        local hp = GetEntityHealth(ped)
        local height = GetEntityHeightAboveGround(ped)
        local inAir = height > 2.0 or IsPedFalling(ped) or IsPedRagdoll(ped)
        local movingFast = false
        local vel = GetEntityVelocity(ped)
        if vel then
            local speed = math.sqrt((vel.x * vel.x) + (vel.y * vel.y) + (vel.z * vel.z))
            movingFast = speed > 4.0
        end
        LocalPlayer.state:set('spawnfixSkipSave', inAir or movingFast, true)

        local interval = (hp < 200 or inAir or height > 1.25) and 8000 or 45000
        local now = GetGameTimer()
        if now - lastSync >= interval then
            lastSync = now
            TriggerServerEvent('mrp_spawnfix:server:syncVitals')
        end
        ::continue::
    end
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    Wait(2000)
    applySavedVitals()
    ensurePedUnstuck(PlayerPedId())
end)

RegisterCommand('fixstuck', function()
    local ped = PlayerPedId()
    local c = GetEntityCoords(ped)
    local h = GetEntityHeading(ped)
    safePlacePed(vector4(c.x, c.y, c.z, h))
    applySavedVitals()
    QBCore.Functions.Notify('Pozicija atstatyta.', 'success')
end, false)
