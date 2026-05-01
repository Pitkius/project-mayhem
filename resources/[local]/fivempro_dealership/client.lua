local QBCore = exports['qb-core']:GetCoreObject()

local catalog = nil
local DEALERSHIP_BLIP_SPRITE = 326
local DEALERSHIP_BLIP_COLOR = 3
local DEALERSHIP_BLIP_SCALE = 0.85

local function fmtMoney(v)
    local n = tonumber(v) or 0
    local s = tostring(math.floor(n))
    local r = s
    while true do
        local k
        r, k = string.gsub(r, '^(-?%d+)(%d%d%d)', '%1,%2')
        if k == 0 then break end
    end
    return '$' .. r
end

local function getVehicleStats(model)
    local hash = joaat(model)
    local maxSpeedMps = GetVehicleModelEstimatedMaxSpeed(hash)
    local accel = GetVehicleModelAcceleration(hash)
    local braking = GetVehicleModelMaxBraking(hash)
    local traction = GetVehicleModelMaxTraction(hash)

    local maxKmh = (tonumber(maxSpeedMps) or 0.0) * 3.6
    local zeroToHundred = 27.777 / math.max(0.1, (tonumber(accel) or 0.1) * 7.5)

    return {
        maxKmh = maxKmh,
        zeroToHundred = zeroToHundred,
        braking = math.max(0.0, math.min(1.0, tonumber(braking) or 0.0)),
        traction = math.max(0.0, math.min(1.0, tonumber(traction) or 0.0)),
    }
end

local function openVehicleMenuForCategory(categoryKey, label)
    if not catalog or not catalog.vehicles then return end
    local entries = {
        {
            header = ('<- %s'):format(catalog.dealership.label),
            txt = 'Atgal i kategorijas',
            params = { event = 'fivempro_dealership:client:openMainMenu' }
        }
    }

    for _, veh in ipairs(catalog.vehicles) do
        if veh.category == categoryKey then
            local st = getVehicleStats(veh.model)
            entries[#entries + 1] = {
                header = ('%s %s'):format(veh.brand or '', veh.name or veh.model),
                txt = ('Kaina: %s | Max: %.0f km/h | 0-100: %.1f s'):format(
                    fmtMoney(veh.price),
                    st.maxKmh,
                    st.zeroToHundred
                ),
                params = {
                    event = 'fivempro_dealership:client:confirmBuy',
                    args = { model = veh.model, name = veh.name, brand = veh.brand, price = veh.price, category = veh.category }
                }
            }
        end
    end

    exports['qb-menu']:openMenu(entries)
end

RegisterNetEvent('fivempro_dealership:client:openMainMenu', function()
    if not catalog then return end
    local entries = {
        {
            header = catalog.dealership.label,
            isMenuHeader = true
        }
    }

    local categoryKeys = {}
    for k in pairs(catalog.categories or {}) do
        categoryKeys[#categoryKeys + 1] = k
    end
    table.sort(categoryKeys)

    for _, catKey in ipairs(categoryKeys) do
        entries[#entries + 1] = {
            header = catalog.categories[catKey],
            txt = 'Atidaryti kategorija',
            params = {
                event = 'fivempro_dealership:client:openCategory',
                args = { key = catKey, label = catalog.categories[catKey] }
            }
        }
    end

    entries[#entries + 1] = {
        header = 'Uzdaryti',
        params = { event = 'qb-menu:client:closeMenu' }
    }

    exports['qb-menu']:openMenu(entries)
end)

RegisterNetEvent('fivempro_dealership:client:openCategory', function(data)
    if not data or not data.key then return end
    openVehicleMenuForCategory(data.key, data.label)
end)

RegisterNetEvent('fivempro_dealership:client:confirmBuy', function(data)
    if not data or not data.model then return end

    local st = getVehicleStats(data.model)
    local confirmMenu = {
        {
            header = ('Pirkti %s %s?'):format(data.brand or '', data.name or data.model),
            txt = ('Kaina: %s | Max: %.0f km/h | 0-100: %.1f s'):format(fmtMoney(data.price), st.maxKmh, st.zeroToHundred),
            isMenuHeader = true
        },
        {
            header = 'Patvirtinti pirkima',
            txt = 'Nuskaiciuos is bank arba cash',
            params = {
                isServer = false,
                event = 'fivempro_dealership:client:buyVehicle',
                args = data
            }
        },
        {
            header = 'Atgal',
            params = {
                event = 'fivempro_dealership:client:openCategory',
                args = { key = data.category or '', label = '' }
            }
        }
    }
    exports['qb-menu']:openMenu(confirmMenu)
end)

RegisterNetEvent('fivempro_dealership:client:buyVehicle', function(data)
    if not data or not data.model then return end
    QBCore.Functions.TriggerCallback('fivempro_dealership:server:buyVehicle', function(result)
        if not result or not result.ok then
            return QBCore.Functions.Notify((result and result.message) or 'Pirkimas nepavyko', 'error')
        end

        local spawn = result.spawn or {}
        local model = joaat(result.model)
        RequestModel(model)
        while not HasModelLoaded(model) do Wait(0) end

        local veh = CreateVehicle(model, spawn.x or 0.0, spawn.y or 0.0, spawn.z or 0.0, spawn.w or 0.0, true, false)
        if veh and veh ~= 0 then
            SetVehicleNumberPlateText(veh, result.plate)
            SetVehicleEngineOn(veh, true, true, false)
            SetEntityAsMissionEntity(veh, true, true)
            TriggerEvent('vehiclekeys:client:SetOwner', result.plate)
            TaskWarpPedIntoVehicle(PlayerPedId(), veh, -1)
            QBCore.Functions.Notify(('Nupirkta! Numeriai: %s'):format(result.plate), 'success')
        else
            QBCore.Functions.Notify('Nupirkta, bet nepavyko spawninti auto. Ji irasyta i DB.', 'primary')
        end
    end, data.model)
end)

CreateThread(function()
    QBCore.Functions.TriggerCallback('fivempro_dealership:server:getCatalog', function(data)
        catalog = data
    end)
end)

CreateThread(function()
    while GetResourceState('qb-target') ~= 'started' do
        Wait(300)
    end

    local pos = Config.Dealership.office
    local blip = AddBlipForCoord(pos.x, pos.y, pos.z)
    SetBlipSprite(blip, DEALERSHIP_BLIP_SPRITE)
    SetBlipDisplay(blip, 4)
    SetBlipScale(blip, DEALERSHIP_BLIP_SCALE)
    SetBlipColour(blip, DEALERSHIP_BLIP_COLOR)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(Config.Dealership.label)
    EndTextCommandSetBlipName(blip)

    local size = Config.Dealership.targetSize
    exports['qb-target']:AddBoxZone('fivempro_dealership_office', pos, size.x, size.y, {
        name = 'fivempro_dealership_office',
        heading = Config.Dealership.officeHeading,
        debugPoly = false,
        minZ = pos.z - 0.8,
        maxZ = pos.z + 1.2,
    }, {
        options = {
            {
                type = 'client',
                event = 'fivempro_dealership:client:openMainMenu',
                icon = 'fas fa-car',
                label = 'Atidaryti autosalono meniu'
            }
        },
        distance = Config.Dealership.targetDistance
    })
end)

