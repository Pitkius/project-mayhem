local spawnedPeds = {}

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
    local ped = CreatePed(0, hash, coords.x, coords.y, coords.z - 1.0, coords.w, false, false)
    SetModelAsNoLongerNeeded(hash)
    setupPed(ped)
    spawnedPeds[#spawnedPeds + 1] = ped
    return ped
end

CreateThread(function()
    while GetResourceState('qb-target') ~= 'started' do
        Wait(200)
    end

    for i = 1, #Config.BarberPeds do
        local ped = spawnShopPed(Config.BarberPeds[i].model, Config.BarberPeds[i].coords)
        if ped then
            exports['qb-target']:AddTargetEntity(ped, {
                options = {
                    {
                        type = 'client',
                        event = 'qb-clothing:client:openBarberOnly',
                        icon = 'fas fa-scissors',
                        label = 'Kirpykla (tik plaukai)',
                    }
                },
                distance = 2.0
            })
        end
    end

    for i = 1, #Config.ClothingPeds do
        local ped = spawnShopPed(Config.ClothingPeds[i].model, Config.ClothingPeds[i].coords)
        if ped then
            exports['qb-target']:AddTargetEntity(ped, {
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
        local ped = spawnShopPed(Config.FoodPeds[i].model, Config.FoodPeds[i].coords)
        if ped then
            exports['qb-target']:AddTargetEntity(ped, {
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
end)
