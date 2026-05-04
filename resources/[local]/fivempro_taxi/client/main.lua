local QBCore = exports['qb-core']:GetCoreObject()

local meterState = {
    active = false,
    fare = 0,
    distanceKm = 0.0,
    waitingMin = 0.0,
    passengers = 0,
}

local function isTaxiJob()
    local P = QBCore.Functions.GetPlayerData()
    return P and P.job and P.job.name == Config.JobName
end

local function isTaxiOnDuty()
    local P = QBCore.Functions.GetPlayerData()
    return P and P.job and P.job.name == Config.JobName and P.job.onduty
end

local function isInAllowedTaxiVehicle()
    local ped = PlayerPedId()
    if not IsPedInAnyVehicle(ped, false) then return false end
    local veh = GetVehiclePedIsIn(ped, false)
    if veh == 0 or GetPedInVehicleSeat(veh, -1) ~= ped then return false end
    local model = string.lower(tostring(GetDisplayNameFromVehicleModel(GetEntityModel(veh)) or ''))
    return Config.AllowedTaxiModels and Config.AllowedTaxiModels[model] == true
end

RegisterNetEvent('fivempro_taxi:client:toggleDuty', function()
    local P = QBCore.Functions.GetPlayerData()
    if not P or not P.job or P.job.name ~= Config.JobName then return end
    TriggerServerEvent('QBCore:ToggleDuty')
end)

RegisterNetEvent('fivempro_taxi:client:openGarageFleet', function()
    if not isTaxiOnDuty() then
        return QBCore.Functions.Notify('Tik taksi tarnyboje.', 'error')
    end
    TriggerEvent('fivempro_garages:client:openGarage', { garageId = 'taxi_ls' })
end)

RegisterNetEvent('fivempro_taxi:client:openDealershipFleet', function()
    if not isTaxiOnDuty() then
        return QBCore.Functions.Notify('Tik taksi tarnyboje.', 'error')
    end
    TriggerEvent('fivempro_dealership:client:openTaxiDealership', 'taxi_ls')
end)

RegisterNetEvent('fivempro_taxi:client:openStash', function()
    if not isTaxiOnDuty() then
        return QBCore.Functions.Notify('Tik taksi tarnyboje.', 'error')
    end
    TriggerServerEvent('fivempro_taxi:server:openStash')
end)

local function applyOutfitTable(ped, tbl)
    if not ped or not tbl then return end
    for comp, val in pairs(tbl) do
        local c = tonumber(comp)
        if c ~= nil then
            local draw, tex = 0, 0
            if type(val) == 'table' then
                draw = tonumber(val[1]) or 0
                tex = tonumber(val[2]) or 0
            else
                draw = tonumber(val) or 0
            end
            SetPedComponentVariation(ped, c, draw, tex, 0)
        end
    end
end

RegisterNetEvent('fivempro_taxi:client:openLocker', function()
    if not isTaxiOnDuty() then
        return QBCore.Functions.Notify('Rūbinė – tik taksi tarnyboje.', 'error')
    end
    if GetResourceState('qb-menu') ~= 'started' then
        return QBCore.Functions.Notify('Reikia qb-menu.', 'error')
    end
    local P = QBCore.Functions.GetPlayerData()
    local grade = (P.job and P.job.grade and P.job.grade.level) or 0
    local menu = { { header = 'Taksi darbo apranga', isMenuHeader = true } }
    for idx, outfit in ipairs(Config.DutyOutfits or {}) do
        if grade >= (tonumber(outfit.minGrade) or 0) then
            menu[#menu + 1] = {
                header = outfit.label,
                params = { event = 'fivempro_taxi:client:applyOutfit', args = { index = idx } },
            }
        end
    end
    if #menu < 2 then
        return QBCore.Functions.Notify('Nėra aprangų.', 'error')
    end
    TriggerEvent('qb-menu:client:openMenu', menu, false, true)
end)

RegisterNetEvent('fivempro_taxi:client:applyOutfit', function(data)
    if not isTaxiOnDuty() then return end
    local idx = tonumber(data and data.index)
    local outfit = idx and Config.DutyOutfits and Config.DutyOutfits[idx]
    if not outfit then return end
    local ped = PlayerPedId()
    local male = GetEntityModel(ped) == `mp_m_freemode_01`
    local tbl = male and outfit.male or outfit.female
    if not tbl then return end
    applyOutfitTable(ped, tbl)
    QBCore.Functions.Notify(outfit.label or 'Apranga uždėta.', 'success')
end)

RegisterNetEvent('fivempro_taxi:client:openMeterMenu', function()
    if not isTaxiOnDuty() then
        return QBCore.Functions.Notify('Taxometras tik tarnyboje.', 'error')
    end
    if not isInAllowedTaxiVehicle() then
        return QBCore.Functions.Notify('Sėsk prie taksi vairo.', 'error')
    end
    if GetResourceState('qb-menu') ~= 'started' then
        return QBCore.Functions.Notify('Reikia qb-menu.', 'error')
    end
    local menu = {
        { header = 'Taxometras', isMenuHeader = true },
        { header = 'Pradėti važiavimą', txt = 'Sąžininga serverio skaičiuojama kaina', params = { event = 'fivempro_taxi:client:meterStart' } },
        { header = 'Užbaigti važiavimą', txt = 'Paskaičiuoti galutinę sumą ir nuskaičiuoti', params = { event = 'fivempro_taxi:client:meterStop' } },
    }
    TriggerEvent('qb-menu:client:openMenu', menu, false, true)
end)

RegisterNetEvent('fivempro_taxi:client:meterStart', function()
    if not isInAllowedTaxiVehicle() then
        return QBCore.Functions.Notify('Sėsk prie taksi vairo.', 'error')
    end
    TriggerServerEvent('fivempro_taxi:server:meterStart')
end)

RegisterNetEvent('fivempro_taxi:client:meterStop', function()
    TriggerServerEvent('fivempro_taxi:server:meterStop')
end)

RegisterNetEvent('fivempro_taxi:client:meterState', function(data)
    meterState.active = data and data.active or false
    meterState.fare = math.floor(tonumber(data and data.fare) or 0)
    meterState.distanceKm = tonumber(data and data.distanceKm) or 0.0
    meterState.waitingMin = tonumber(data and data.waitingMin) or 0.0
    meterState.passengers = tonumber(data and data.passengers) or 0
end)

CreateThread(function()
    while true do
        if meterState.active and isTaxiOnDuty() then
            local txt = ('Taxometras | Kaina: €%s | Atstumas: %.2f km | Laukimas: %.1f min | Keleiviai: %s'):format(
                meterState.fare,
                meterState.distanceKm,
                meterState.waitingMin,
                meterState.passengers
            )
            SetTextFont(4)
            SetTextScale(0.33, 0.33)
            SetTextColour(255, 215, 0, 220)
            SetTextOutline()
            SetTextCentre(true)
            BeginTextCommandDisplayText('STRING')
            AddTextComponentSubstringPlayerName(txt)
            EndTextCommandDisplayText(0.5, 0.92)
            Wait(0)
        else
            Wait(300)
        end
    end
end)

RegisterCommand('taxi', function()
    TriggerEvent('fivempro_taxi:client:openMeterMenu')
end, false)

CreateThread(function()
    local b = Config.Base
    local bl = Config.Blip
    local mark = AddBlipForCoord(b.x, b.y, b.z)
    SetBlipSprite(mark, bl.sprite)
    SetBlipDisplay(mark, 4)
    SetBlipScale(mark, bl.scale)
    SetBlipColour(mark, bl.colour)
    SetBlipAsShortRange(mark, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(bl.label)
    EndTextCommandSetBlipName(mark)
end)

CreateThread(function()
    while GetResourceState('qb-target') ~= 'started' do
        Wait(300)
    end

    local gh = Config.GarageHub
    exports['qb-target']:AddBoxZone('fivempro_taxi_hub', gh.coords, 3.6, 3.6, {
        name = 'fivempro_taxi_hub',
        heading = gh.heading,
        debugPoly = false,
        minZ = gh.coords.z - 1.55,
        maxZ = gh.coords.z + 3.0,
    }, {
        options = {
            {
                type = 'client',
                event = 'fivempro_taxi:client:openGarageFleet',
                icon = 'fas fa-warehouse',
                label = 'Taksi garažas',
                canInteract = function() return isTaxiOnDuty() end,
            },
            {
                type = 'client',
                event = 'fivempro_taxi:client:openDealershipFleet',
                icon = 'fas fa-car-side',
                label = 'Taksi mašinų pirkimas',
                canInteract = function() return isTaxiOnDuty() end,
            },
        },
        distance = Config.TargetDistance + 1.0,
    })

    local st = Config.Stash
    exports['qb-target']:AddBoxZone('fivempro_taxi_stash', st.coords, 1.75, 1.75, {
        name = 'fivempro_taxi_stash',
        heading = st.heading or Config.Base.w,
        debugPoly = false,
        minZ = st.coords.z - 1.15,
        maxZ = st.coords.z + 2.35,
    }, {
        options = {
            {
                type = 'client',
                event = 'fivempro_taxi:client:openStash',
                icon = 'fas fa-box',
                label = 'Taksi sandėlis',
                canInteract = function() return isTaxiOnDuty() end,
            },
        },
        distance = Config.TargetDistance + 0.35,
    })

    local lk = Config.Locker
    exports['qb-target']:AddBoxZone('fivempro_taxi_locker', lk.coords, 1.65, 1.65, {
        name = 'fivempro_taxi_locker',
        heading = lk.heading,
        debugPoly = false,
        minZ = lk.coords.z - 1.15,
        maxZ = lk.coords.z + 2.35,
    }, {
        options = {
            {
                type = 'client',
                event = 'fivempro_taxi:client:openLocker',
                icon = 'fas fa-shirt',
                label = 'Rūbinė (darbo apranga)',
                canInteract = function() return isTaxiOnDuty() end,
            },
        },
        distance = Config.TargetDistance + 0.35,
    })

    local mg = Config.Management.coords
    exports['qb-target']:AddBoxZone('fivempro_taxi_mgmt', mg, 1.95, 1.95, {
        name = 'fivempro_taxi_mgmt',
        heading = Config.Management.heading,
        debugPoly = false,
        minZ = mg.z - 1.25,
        maxZ = mg.z + 2.55,
    }, {
        options = {
            {
                type = 'client',
                event = 'fivempro_taxi:client:bossOpenMenu',
                icon = 'fas fa-user-tie',
                label = 'Taksi vadovybė',
                canInteract = function()
                    local P = QBCore.Functions.GetPlayerData()
                    if not P or not P.job or P.job.name ~= Config.JobName or not P.job.onduty then return false end
                    if P.job.isboss then return true end
                    return (P.job.grade and P.job.grade.level or 0) >= (Config.Permissions.boss_menu or 2)
                end,
            },
        },
        distance = 3.4,
    })

    exports['qb-target']:AddBoxZone('fivempro_taxi_duty', vector3(Config.Base.x, Config.Base.y, Config.Base.z), 1.85, 1.85, {
        name = 'fivempro_taxi_duty',
        heading = Config.Base.w,
        debugPoly = false,
        minZ = Config.Base.z - 1.15,
        maxZ = Config.Base.z + 2.45,
    }, {
        options = {
            {
                type = 'client',
                event = 'fivempro_taxi:client:toggleDuty',
                icon = 'fas fa-id-badge',
                label = 'Tarnyba (įjungti / išjungti)',
                canInteract = function() return isTaxiJob() end,
            },
        },
        distance = Config.TargetDistance + 0.65,
    })
end)
