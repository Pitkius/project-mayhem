--- Klientas: blipai, qb-target ir scenario ant serverio spawnintų NPC
local QBCore = exports['qb-core']:GetCoreObject()

local spawnedBlips = {}
local configured = {}
local barberPedByIndex = {}
local pendingTargets = {}
local pendingJobTargets = {}

local function queueTarget(ped, data, jobQueue)
    if not ped or not DoesEntityExist(ped) then return end
    local q = jobQueue and pendingJobTargets or pendingTargets
    q[#q + 1] = { ped = ped, data = data }
end

local function createBlip(coords, blipCfg)
    if not coords or not blipCfg then return end
    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(blip, blipCfg.sprite or 52)
    SetBlipDisplay(blip, 4)
    SetBlipScale(blip, blipCfg.scale or 0.75)
    SetBlipColour(blip, blipCfg.color or 0)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(blipCfg.label or 'Parduotuvė')
    EndTextCommandSetBlipName(blip)
    spawnedBlips[#spawnedBlips + 1] = blip
end

local function loadAnimDict(dict)
    RequestAnimDict(dict)
    while not HasAnimDictLoaded(dict) do Wait(0) end
end

local function setupPedEntity(ent, meta)
    SetEntityInvincible(ent, true)
    SetBlockingOfNonTemporaryEvents(ent, true)
    FreezeEntityPosition(ent, true)
    if meta.scenario then
        TaskStartScenarioInPlace(ent, meta.scenario, 0, true)
    end
end

local function buildTargetOptions(meta)
    if meta.category == 'barber' then
        barberPedByIndex[meta.index] = nil
        return {
            options = {
                {
                    type = 'client',
                    event = 'fivempro_npcshops:client:openBarberWithAnim',
                    icon = 'fas fa-scissors',
                    label = 'Kirpykla (tik plaukai)',
                    shopIndex = meta.index,
                },
            },
            distance = 2.0,
        }, false
    elseif meta.category == 'clothing' then
        return {
            options = {
                {
                    type = 'client',
                    event = 'qb-clothing:client:openClothingOnly',
                    icon = 'fas fa-shirt',
                    label = 'Rūbų parduotuvė',
                },
            },
            distance = 2.0,
        }, false
    elseif meta.category == 'food' then
        return {
            options = {
                {
                    type = 'server',
                    event = 'fivempro_npcshops:server:openFoodShop',
                    icon = 'fas fa-basket-shopping',
                    label = '24/7 parduotuvė',
                },
            },
            distance = 2.0,
        }, false
    elseif meta.category == 'tattoo' then
        return {
            options = {
                {
                    type = 'client',
                    event = 'qb-clothing:client:openTattooOnly',
                    icon = 'fas fa-pen-nib',
                    label = 'Tatuiruotės',
                },
            },
            distance = 2.0,
        }, false
    elseif meta.category == 'pharmacy' then
        return {
            options = {
                {
                    type = 'server',
                    event = 'fivempro_npcshops:server:openPharmacyShop',
                    icon = 'fas fa-briefcase-medical',
                    label = 'Vaistinė',
                },
            },
            distance = 2.0,
        }, false
    elseif meta.category == 'job' then
        local icon = 'fas fa-user'
        if meta.role == 'supply' then icon = 'fas fa-box-open'
        elseif meta.role == 'garage' then icon = 'fas fa-car'
        elseif meta.role == 'locker' then icon = 'fas fa-shirt'
        elseif meta.role == 'stash' then icon = 'fas fa-warehouse'
        elseif meta.role == 'duty' then icon = 'fas fa-id-badge'
        end
        local captured = meta
        return {
            options = {
                {
                    icon = icon,
                    label = meta.label or 'Tarnyba',
                    action = function()
                        TriggerServerEvent('fivempro_npcshops:server:validateJobNpc', captured.job, captured.stationId, captured.role)
                    end,
                },
            },
            distance = Config.JobNpcReach or 3.5,
        }, true
    end
    return nil, false
end

local function configureShopPed(ent, meta, key)
    key = key or ent
    if configured[key] then return end
    configured[key] = true

    setupPedEntity(ent, meta)
    if meta.category == 'barber' then
        barberPedByIndex[meta.index] = ent
    end

    local targetData, isJob = buildTargetOptions(meta)
    if targetData then
        queueTarget(ent, targetData, isJob)
    end

    if meta.blip and meta.coords then
        createBlip(meta.coords, meta.blip)
    end
end

AddStateBagChangeHandler('npcShopMeta', nil, function(bagName, _, value)
    if not value then return end
    CreateThread(function()
        local ent = 0
        for _ = 1, 120 do
            ent = GetEntityFromStateBagName(bagName)
            if ent and ent ~= 0 and DoesEntityExist(ent) then break end
            Wait(100)
        end
        if ent == 0 or not DoesEntityExist(ent) then return end
        configureShopPed(ent, value, bagName)
    end)
end)

--- Jau egzistuojantys serverio NPC (state bag handler ne visada suveikia prisijungus vėliau)
CreateThread(function()
    Wait(5000)
    while GetResourceState('qb-target') ~= 'started' do Wait(250) end
    for _, ped in ipairs(GetGamePool('CPed')) do
        if DoesEntityExist(ped) and not IsPedAPlayer(ped) then
            local meta = Entity(ped).state.npcShopMeta
            if meta then
                configureShopPed(ped, meta, ped)
            end
        end
    end
end)

CreateThread(function()
    while true do
        if GetResourceState('qb-target') == 'started' then
            for i = #pendingTargets, 1, -1 do
                local entry = pendingTargets[i]
                if entry and DoesEntityExist(entry.ped) then
                    exports['qb-target']:AddTargetEntity(entry.ped, entry.data)
                end
                table.remove(pendingTargets, i)
            end
            for i = #pendingJobTargets, 1, -1 do
                local entry = pendingJobTargets[i]
                if entry and DoesEntityExist(entry.ped) then
                    exports['qb-target']:AddTargetEntity(entry.ped, entry.data)
                end
                table.remove(pendingJobTargets, i)
            end
        end
        Wait(500)
    end
end)

RegisterNetEvent('fivempro_npcshops:client:openBarberWithAnim', function(data)
    local idx = data and tonumber(data.shopIndex)
    local cfg = idx and Config.BarberPeds[idx] or nil
    local barberPed = idx and barberPedByIndex[idx] or nil
    if BarberSession and BarberSession.Start then
        return BarberSession.Start(cfg, barberPed)
    end
    TriggerEvent('qb-clothing:client:openBarberOnly')
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    for i = 1, #spawnedBlips do
        if DoesBlipExist(spawnedBlips[i]) then
            RemoveBlip(spawnedBlips[i])
        end
    end
end)
