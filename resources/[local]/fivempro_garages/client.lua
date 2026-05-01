local QBCore = exports['qb-core']:GetCoreObject()
local GARAGE_SPRITE = 357
local GARAGE_COLOR = 3
local GARAGE_SCALE = 0.75

local function getVehicleDisplayName(model)
    local shared = QBCore.Shared.Vehicles[model]
    if shared and shared.name then
        return string.format('%s %s', shared.brand or '', shared.name)
    end
    return model
end

local function isSpawnClear(spawn)
    local vehicles = GetGamePool('CVehicle')
    local spawnPos = vector3(spawn.x, spawn.y, spawn.z)
    for i = 1, #vehicles do
        local veh = vehicles[i]
        if DoesEntityExist(veh) and #(GetEntityCoords(veh) - spawnPos) < 3.0 then
            return false
        end
    end
    return true
end

local function openGarageMenu(garage)
    QBCore.Functions.TriggerCallback('fivempro_garages:server:getPlayerVehicles', function(vehicles)
        local menu = {
            { header = garage.label, isMenuHeader = true }
        }

        for _, v in ipairs(vehicles or {}) do
            local status = (tonumber(v.state) == 1) and 'Garaze' or 'Lauke'
            menu[#menu + 1] = {
                header = getVehicleDisplayName(v.model),
                txt = string.format('%s | %s', v.plate, status),
                disabled = tonumber(v.state) ~= 1,
                params = {
                    event = 'fivempro_garages:client:spawnVehicle',
                    args = { garageId = garage.id, spawn = garage.spawn, plate = v.plate }
                }
            }
        end

        menu[#menu + 1] = { header = 'Uzdaryti', params = { event = 'qb-menu:client:closeMenu' } }
        exports['qb-menu']:openMenu(menu)
    end, garage.id)
end

RegisterNetEvent('fivempro_garages:client:openGarage', function(data)
    if not data or not data.garageId then return end
    for _, garage in ipairs(Config.Garages) do
        if garage.id == data.garageId then
            return openGarageMenu(garage)
        end
    end
end)

RegisterNetEvent('fivempro_garages:client:spawnVehicle', function(data)
    if not data or not data.plate or not data.spawn then return end
    if not isSpawnClear(data.spawn) then
        return QBCore.Functions.Notify('Spawn vieta uzimta', 'error')
    end

    QBCore.Functions.TriggerCallback('fivempro_garages:server:spawnVehicle', function(result)
        if not result or not result.ok then
            return QBCore.Functions.Notify((result and result.message) or 'Nepavyko istraukti masinos', 'error')
        end

        local modelHash = joaat(result.model)
        RequestModel(modelHash)
        while not HasModelLoaded(modelHash) do Wait(0) end

        local veh = CreateVehicle(modelHash, data.spawn.x, data.spawn.y, data.spawn.z, data.spawn.w, true, false)
        if not veh or veh == 0 then
            return QBCore.Functions.Notify('Nepavyko spawninti masinos', 'error')
        end

        SetVehicleNumberPlateText(veh, result.plate)
        SetEntityAsMissionEntity(veh, true, true)
        if result.mods and result.mods ~= '' then
            local mods = json.decode(result.mods)
            if mods and QBCore.Functions.SetVehicleProperties then
                QBCore.Functions.SetVehicleProperties(veh, mods)
            end
        end
        TriggerEvent('vehiclekeys:client:SetOwner', result.plate)
        TaskWarpPedIntoVehicle(PlayerPedId(), veh, -1)
        QBCore.Functions.Notify('Masina istraukta', 'success')
    end, data.plate, data.garageId)
end)

RegisterNetEvent('fivempro_garages:client:parkVehicle', function(data)
    local ped = PlayerPedId()
    if not IsPedInAnyVehicle(ped, false) then
        return QBCore.Functions.Notify('Tu nesi masinoje', 'error')
    end

    local veh = GetVehiclePedIsIn(ped, false)
    if GetPedInVehicleSeat(veh, -1) ~= ped then
        return QBCore.Functions.Notify('Tu turi buti vairuotojas', 'error')
    end

    local plate = QBCore.Functions.GetPlate(veh)
    local props = QBCore.Functions.GetVehicleProperties(veh)
    QBCore.Functions.TriggerCallback('fivempro_garages:server:parkVehicle', function(result)
        if not result or not result.ok then
            return QBCore.Functions.Notify((result and result.message) or 'Nepavyko pastatyti masinos', 'error')
        end

        DeleteVehicle(veh)
        QBCore.Functions.Notify('Masina pastatyta i garaza', 'success')
    end, plate, props, data.garageId)
end)

CreateThread(function()
    while GetResourceState('qb-target') ~= 'started' do
        Wait(300)
    end

    for _, garage in ipairs(Config.Garages) do
        local blip = AddBlipForCoord(garage.coords.x, garage.coords.y, garage.coords.z)
        SetBlipSprite(blip, GARAGE_SPRITE)
        SetBlipDisplay(blip, 4)
        SetBlipScale(blip, GARAGE_SCALE)
        SetBlipColour(blip, GARAGE_COLOR)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString(garage.label)
        EndTextCommandSetBlipName(blip)

        exports['qb-target']:AddBoxZone(('fivempro_garage_%s'):format(garage.id), garage.coords, 2.4, 2.4, {
            name = ('fivempro_garage_%s'):format(garage.id),
            heading = garage.heading,
            debugPoly = false,
            minZ = garage.coords.z - 1.0,
            maxZ = garage.coords.z + 2.0,
        }, {
            options = {
                {
                    type = 'client',
                    event = 'fivempro_garages:client:openGarage',
                    icon = 'fas fa-warehouse',
                    label = 'Atidaryti garaza',
                    garageId = garage.id
                },
                {
                    type = 'client',
                    event = 'fivempro_garages:client:parkVehicle',
                    icon = 'fas fa-square-parking',
                    label = 'Pastatyti masina',
                    garageId = garage.id
                },
            },
            distance = Config.TargetDistance
        })
    end
end)

