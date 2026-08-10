local QBCore = exports['qb-core']:GetCoreObject()

local uiOpen = false
local lotBlip = nil

local function notify(msg, nType)
    QBCore.Functions.Notify(msg, nType or 'primary')
end

local function closeUi()
    if not uiOpen then return end
    uiOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

local function openUi(payload)
    uiOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage(payload)
end

local function inLotZone(coords)
    local c = Config.LotZone.center
    local dx = coords.x - c.x
    local dy = coords.y - c.y
    return (dx * dx + dy * dy) <= (Config.LotZone.radius * Config.LotZone.radius)
end

local function getVehicleInLot()
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    if not veh or veh == 0 then
        veh = QBCore.Functions.GetClosestVehicle()
    end
    if not veh or veh == 0 or not DoesEntityExist(veh) then return nil end

    local coords = GetEntityCoords(veh)
    if not inLotZone(coords) then return nil end
    if GetPedInVehicleSeat(veh, -1) ~= ped then return nil end
    return veh
end

local function requestListVehicle(price)
    local veh = getVehicleInLot()
    if not veh then
        notify('Įvažiuok į aikštelę savo mašina (vairuotojo vieta)', 'error')
        return
    end

    local plate = QBCore.Functions.GetPlate(veh)
    if not plate or plate == '' then
        notify('Nerasta numerių lentelė', 'error')
        return
    end

    local props = QBCore.Functions.GetVehicleProperties(veh)
    local netId = NetworkGetNetworkIdFromEntity(veh)

    QBCore.Functions.TriggerCallback('mrp_usedcars:server:listVehicle', function(result)
        if not result or not result.ok then
            notify((result and result.message) or 'Listuoti nepavyko', 'error')
            return
        end
        notify(result.message or 'Mašina pastatyta parduoti', 'success')
        if DoesEntityExist(veh) then
            SetEntityAsMissionEntity(veh, true, true)
            DeleteVehicle(veh)
        end
        closeUi()
    end, {
        plate = plate,
        price = price,
        props = props,
        netId = netId,
    })
end

local function openListPrompt()
    openUi({
        action = 'open',
        mode = 'list',
        minPrice = Config.MinPrice,
        maxPrice = Config.MaxPrice,
        feePercent = math.floor(Config.FeePercent * 100 + 0.5),
    })
end

local function openMyListings()
    QBCore.Functions.TriggerCallback('mrp_usedcars:server:getMyListings', function(list)
        openUi({
            action = 'open',
            mode = 'mine',
            listings = list or {},
            feePercent = math.floor(Config.FeePercent * 100 + 0.5),
            returnGarage = Config.ReturnGarage,
        })
    end)
end

OpenInspectUi = function(listing)
    if not listing then return end
    openUi({
        action = 'open',
        mode = 'inspect',
        listing = listing,
        feePercent = math.floor(Config.FeePercent * 100 + 0.5),
        isOwner = listing.sellerCitizenId == QBCore.Functions.GetPlayerData().citizenid,
    })
end

RegisterNUICallback('close', function(_, cb)
    closeUi()
    cb('ok')
end)

RegisterNUICallback('listVehicle', function(data, cb)
    local price = tonumber(data and data.price)
    if not price then
        notify('Įvesk kainą', 'error')
        cb('ok')
        return
    end
    requestListVehicle(price)
    cb('ok')
end)

RegisterNUICallback('cancelListing', function(data, cb)
    local id = tonumber(data and data.id)
    if not id then
        cb('ok')
        return
    end
    QBCore.Functions.TriggerCallback('mrp_usedcars:server:cancelListing', function(result)
        if not result or not result.ok then
            notify((result and result.message) or 'Atšaukti nepavyko', 'error')
        else
            notify(result.message or 'Skelbimas atšauktas', 'success')
            openMyListings()
        end
    end, id)
    cb('ok')
end)

RegisterNUICallback('buyListing', function(data, cb)
    local id = tonumber(data and data.id)
    if not id then
        cb('ok')
        return
    end
    QBCore.Functions.TriggerCallback('mrp_usedcars:server:buyListing', function(result)
        closeUi()
        if not result or not result.ok then
            notify((result and result.message) or 'Pirkimas nepavyko', 'error')
            return
        end
        notify(result.message or 'Pirkimas sėkmingas', 'success')
        TriggerEvent('mrp_usedcars:client:spawnPurchased', result)
    end, id)
    cb('ok')
end)

RegisterNetEvent('mrp_usedcars:client:spawnPurchased', function(result)
    if not result or not result.model then return end
    local spawn = result.spawn or {
        x = Config.BuySpawn.x,
        y = Config.BuySpawn.y,
        z = Config.BuySpawn.z,
        w = Config.BuySpawn.w,
    }

    local model = result.model
    local hash = type(model) == 'number' and model or joaat(model)
    if not IsModelInCdimage(hash) then
        notify('Modelis nerastas', 'error')
        return
    end

    RequestModel(hash)
    local timeout = GetGameTimer() + 8000
    while not HasModelLoaded(hash) and GetGameTimer() < timeout do
        Wait(0)
    end
    if not HasModelLoaded(hash) then
        notify('Nepavyko užkrauti modelio', 'error')
        return
    end

    local veh = CreateVehicle(hash, spawn.x, spawn.y, spawn.z, spawn.w or 0.0, true, false)
    SetModelAsNoLongerNeeded(hash)
    if not veh or veh == 0 then
        notify('Spawn nepavyko — mašina garaže', 'primary')
        return
    end

    SetEntityAsMissionEntity(veh, true, true)
    SetVehicleNumberPlateText(veh, result.plate)
    SetVehicleOnGroundProperly(veh)
    SetVehicleEngineOn(veh, true, true, false)

    local mods = result.mods
    if type(mods) == 'string' and mods ~= '' then
        local ok, decoded = pcall(json.decode, mods)
        if ok then mods = decoded end
    end
    if type(mods) == 'table' then
        QBCore.Functions.SetVehicleProperties(veh, mods)
        SetVehicleNumberPlateText(veh, result.plate)
    end

    if GetResourceState('mrp_plates') == 'started' then
        pcall(function()
            exports['mrp_plates']:ApplyPlateStyle(veh)
        end)
    end

    TriggerEvent('vehiclekeys:client:SetOwner', result.plate)
    TaskWarpPedIntoVehicle(PlayerPedId(), veh, -1)
end)

CreateThread(function()
    if Config.Blip.enabled then
        lotBlip = AddBlipForCoord(Config.Booth.coords.x, Config.Booth.coords.y, Config.Booth.coords.z)
        SetBlipSprite(lotBlip, Config.Blip.sprite)
        SetBlipDisplay(lotBlip, 4)
        SetBlipScale(lotBlip, Config.Blip.scale)
        SetBlipColour(lotBlip, Config.Blip.color)
        SetBlipAsShortRange(lotBlip, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName(Config.Blip.label)
        EndTextCommandSetBlipName(lotBlip)
    end

    local booth = Config.Booth
    exports['qb-target']:AddBoxZone('mrp_usedcars_booth', booth.coords, booth.size.x, booth.size.y, {
        name = 'mrp_usedcars_booth',
        heading = booth.heading,
        debugPoly = false,
        minZ = booth.coords.z - 1.0,
        maxZ = booth.coords.z + 1.5,
    }, {
        options = {
            {
                icon = 'fas fa-tags',
                label = 'Listuoti mašiną',
                action = function()
                    openListPrompt()
                end,
            },
            {
                icon = 'fas fa-clipboard-list',
                label = 'Mano skelbimai',
                action = function()
                    openMyListings()
                end,
            },
        },
        distance = Config.TargetDistance,
    })

    exports['qb-target']:AddGlobalVehicle({
        options = {
            {
                icon = 'fas fa-dollar-sign',
                label = 'Parduoti aikštelėje',
                canInteract = function(entity)
                    if uiOpen then return false end
                    if not entity or entity == 0 or not DoesEntityExist(entity) then return false end
                    local ped = PlayerPedId()
                    if GetPedInVehicleSeat(entity, -1) ~= ped then return false end
                    return inLotZone(GetEntityCoords(entity))
                end,
                action = function()
                    openListPrompt()
                end,
            },
        },
        distance = Config.VehicleTargetDistance,
    })

    TriggerServerEvent('mrp_usedcars:server:requestSync')
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    closeUi()
    if lotBlip then RemoveBlip(lotBlip) end
    pcall(function()
        exports['qb-target']:RemoveZone('mrp_usedcars_booth')
    end)
end)
