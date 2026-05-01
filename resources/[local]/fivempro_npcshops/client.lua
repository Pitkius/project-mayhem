local spawnedPeds = {}
local spawnedBlips = {}
local pendingTargets = {}
local barberPedByIndex = {}
local inBarberFlow = false

local function loadModel(model)
    local hash = type(model) == 'string' and joaat(model) or model
    if not IsModelInCdimage(hash) then return nil end
    RequestModel(hash)
    while not HasModelLoaded(hash) do
        Wait(0)
    end
    return hash
end

local function setupPed(ped)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    FreezeEntityPosition(ped, true)
end

local function spawnShopPed(model, coords)
    local hash = loadModel(model)
    if not hash then return nil end
    local spawnZ = coords.z + 1.0
    local ped = CreatePed(0, hash, coords.x, coords.y, spawnZ, coords.w, false, false)
    RequestCollisionAtCoord(coords.x, coords.y, spawnZ)
    local timeout = GetGameTimer() + 2000
    while not HasCollisionLoadedAroundEntity(ped) and GetGameTimer() < timeout do
        Wait(0)
    end

    local placedOnGround = false
    if type(PlaceEntityOnGroundProperly) == 'function' then
        placedOnGround = PlaceEntityOnGroundProperly(ped) or false
    end
    local targetZ = coords.z + 0.05
    local groundFound, groundZ = GetGroundZFor_3dCoord(coords.x, coords.y, coords.z + 10.0, false)
    if groundFound then
        targetZ = groundZ + 0.05
    else
        for testZ = coords.z + 30.0, coords.z - 20.0, -2.0 do
            local found, zAtPoint = GetGroundZFor_3dCoord(coords.x, coords.y, testZ, false)
            if found then
                targetZ = zAtPoint + 0.05
                groundFound = true
                break
            end
        end
    end

    local pedCoords = GetEntityCoords(ped)
    if (not placedOnGround) or (not groundFound) or math.abs(pedCoords.z - targetZ) > 1.5 then
        SetEntityCoordsNoOffset(ped, coords.x, coords.y, targetZ, false, false, false)
    end
    SetEntityHeading(ped, coords.w)
    SetModelAsNoLongerNeeded(hash)
    setupPed(ped)
    spawnedPeds[#spawnedPeds + 1] = ped
    return ped
end

local function queueTarget(ped, data)
    if not ped or not DoesEntityExist(ped) then return end
    pendingTargets[#pendingTargets + 1] = { ped = ped, data = data }
end

local function loadAnimDict(dict)
    RequestAnimDict(dict)
    while not HasAnimDictLoaded(dict) do
        Wait(0)
    end
end

RegisterNetEvent('fivempro_npcshops:client:openBarberWithAnim', function(data)
    local idx = data and tonumber(data.shopIndex)
    local cfg = idx and Config.BarberPeds[idx] or nil
    if not cfg then
        return TriggerEvent('qb-clothing:client:openBarberOnly')
    end

    local ped = PlayerPedId()
    local chair = cfg.chair or cfg.coords
    inBarberFlow = true

    ClearPedTasksImmediately(ped)
    SetEntityCoordsNoOffset(ped, chair.x, chair.y, chair.z, false, false, false)
    SetEntityHeading(ped, chair.w)
    TaskStartScenarioAtPosition(ped, 'PROP_HUMAN_SEAT_CHAIR_MP_PLAYER', chair.x, chair.y, chair.z - 1.0, chair.w, 0, true, true)

    local barberPed = barberPedByIndex[idx]
    if barberPed and DoesEntityExist(barberPed) then
        loadAnimDict('misshair_shop@hair_dressers')
        TaskPlayAnim(barberPed, 'misshair_shop@hair_dressers', 'keeper_hair_cut_a', 8.0, -8.0, 3000, 1, 0.0, false, false, false)
    end

    Wait(1100)
    TriggerEvent('qb-clothing:client:openBarberOnly')
end)

AddEventHandler('qb-clothing:client:onMenuClose', function()
    if inBarberFlow then
        inBarberFlow = false
        ClearPedTasks(PlayerPedId())
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
        end
        Wait(500)
    end
end)

CreateThread(function()
    for i = 1, #Config.BarberPeds do
        local barberCoords = Config.BarberPeds[i].coords
        local barberBlip = AddBlipForCoord(barberCoords.x, barberCoords.y, barberCoords.z)
        SetBlipSprite(barberBlip, 71)
        SetBlipDisplay(barberBlip, 4)
        SetBlipScale(barberBlip, 0.75)
        SetBlipColour(barberBlip, 0)
        SetBlipAsShortRange(barberBlip, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString('Kirpykla')
        EndTextCommandSetBlipName(barberBlip)
        spawnedBlips[#spawnedBlips + 1] = barberBlip

        local ped = spawnShopPed(Config.BarberPeds[i].model, Config.BarberPeds[i].coords)
        if ped then
            barberPedByIndex[i] = ped
            queueTarget(ped, {
                options = {
                    {
                        type = 'client',
                        event = 'fivempro_npcshops:client:openBarberWithAnim',
                        icon = 'fas fa-scissors',
                        label = 'Kirpykla (tik plaukai)',
                        shopIndex = i,
                    }
                },
                distance = 2.0
            })
        end
    end

    for i = 1, #Config.ClothingPeds do
        local clothingCoords = Config.ClothingPeds[i].coords
        local clothingBlip = AddBlipForCoord(clothingCoords.x, clothingCoords.y, clothingCoords.z)
        SetBlipSprite(clothingBlip, 366)
        SetBlipDisplay(clothingBlip, 4)
        SetBlipScale(clothingBlip, 0.75)
        SetBlipColour(clothingBlip, 47)
        SetBlipAsShortRange(clothingBlip, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString('Rubu Parduotuve')
        EndTextCommandSetBlipName(clothingBlip)
        spawnedBlips[#spawnedBlips + 1] = clothingBlip

        local ped = spawnShopPed(Config.ClothingPeds[i].model, Config.ClothingPeds[i].coords)
        if ped then
            queueTarget(ped, {
                options = {
                    {
                        type = 'client',
                        event = 'qb-clothing:client:openClothingOnly',
                        icon = 'fas fa-shirt',
                        label = 'Rubu Parduotuve',
                    }
                },
                distance = 2.0
            })
        end
    end

    for i = 1, #Config.FoodPeds do
        local blip = AddBlipForCoord(Config.FoodPeds[i].coords.x, Config.FoodPeds[i].coords.y, Config.FoodPeds[i].coords.z)
        SetBlipSprite(blip, 52) -- shopping cart
        SetBlipDisplay(blip, 4)
        SetBlipScale(blip, 0.75)
        SetBlipColour(blip, 2)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString('Maisto Parduotuve')
        EndTextCommandSetBlipName(blip)
        spawnedBlips[#spawnedBlips + 1] = blip

        local ped = spawnShopPed(Config.FoodPeds[i].model, Config.FoodPeds[i].coords)
        if ped then
            queueTarget(ped, {
                options = {
                    {
                        type = 'server',
                        event = 'fivempro_npcshops:server:openFoodShop',
                        icon = 'fas fa-burger',
                        label = 'Nusipirkti maisto',
                    }
                },
                distance = 2.0
            })
        end
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    for i = 1, #spawnedPeds do
        if DoesEntityExist(spawnedPeds[i]) then
            DeletePed(spawnedPeds[i])
        end
    end
    for i = 1, #spawnedBlips do
        if DoesBlipExist(spawnedBlips[i]) then
            RemoveBlip(spawnedBlips[i])
        end
    end
end)
