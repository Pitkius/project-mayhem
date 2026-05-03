local QBCore = exports['qb-core']:GetCoreObject()

local function isMechanicJob()
    local P = QBCore.Functions.GetPlayerData()
    return P and P.job and P.job.name == Config.JobName
end

local function isMechanicOnDuty()
    local P = QBCore.Functions.GetPlayerData()
    return P and P.job and P.job.name == Config.JobName and P.job.onduty
end

RegisterNetEvent('fivempro_mechanic:client:toggleDuty', function()
    local P = QBCore.Functions.GetPlayerData()
    if not P or not P.job or P.job.name ~= Config.JobName then return end
    TriggerServerEvent('QBCore:ToggleDuty')
end)

RegisterNetEvent('fivempro_mechanic:client:openGarageFleet', function()
    if not isMechanicOnDuty() then
        return QBCore.Functions.Notify('Tik mechanikams tarnyboje.', 'error')
    end
    TriggerEvent('fivempro_garages:client:openGarage', { garageId = 'mech_ls' })
end)

RegisterNetEvent('fivempro_mechanic:client:openDealershipFleet', function()
    if not isMechanicOnDuty() then
        return QBCore.Functions.Notify('Tik mechanikams tarnyboje.', 'error')
    end
    TriggerEvent('fivempro_dealership:client:openMechanicDealership', 'mech_ls')
end)

RegisterNetEvent('fivempro_mechanic:client:openStash', function()
    if not isMechanicOnDuty() then
        return QBCore.Functions.Notify('Tik mechanikams tarnyboje.', 'error')
    end
    TriggerServerEvent('fivempro_mechanic:server:openStash')
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

RegisterNetEvent('fivempro_mechanic:client:openLocker', function()
    if not isMechanicOnDuty() then
        return QBCore.Functions.Notify('Rūbinė – tik mechanikams tarnyboje.', 'error')
    end
    if GetResourceState('qb-menu') ~= 'started' then
        return QBCore.Functions.Notify('Reikia qb-menu.', 'error')
    end
    local P = QBCore.Functions.GetPlayerData()
    local grade = (P.job and P.job.grade and P.job.grade.level) or 0
    local menu = { { header = 'Darbo apranga', isMenuHeader = true } }
    for idx, outfit in ipairs(Config.DutyOutfits or {}) do
        if grade >= (tonumber(outfit.minGrade) or 0) then
            menu[#menu + 1] = {
                header = outfit.label,
                params = {
                    event = 'fivempro_mechanic:client:applyOutfit',
                    args = { index = idx },
                },
            }
        end
    end
    if #menu < 2 then
        return QBCore.Functions.Notify('Nėra aprangų.', 'error')
    end
    TriggerEvent('qb-menu:client:openMenu', menu, false, true)
end)

RegisterNetEvent('fivempro_mechanic:client:applyOutfit', function(data)
    if not isMechanicOnDuty() then return end
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

RegisterNetEvent('fivempro_mechanic:client:quickRepairHere', function()
    if not isMechanicOnDuty() then
        return QBCore.Functions.Notify('Tik mechanikams tarnyboje.', 'error')
    end
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    if veh == 0 then
        return QBCore.Functions.Notify('Įsėk į vairuotojo vietą.', 'error')
    end
    if GetPedInVehicleSeat(veh, -1) ~= ped then
        return QBCore.Functions.Notify('Turi būti vairuotojas.', 'error')
    end
    SetVehicleEngineHealth(veh, 1000.0)
    SetVehicleBodyHealth(veh, 1000.0)
    SetVehiclePetrolTankHealth(veh, 1000.0)
    SetVehicleFixed(veh)
    SetVehicleDeformationFixed(veh)
    QBCore.Functions.Notify('Transportas apžiūrėtas (lokali apžiūra).', 'success')
end)

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
    exports['qb-target']:AddBoxZone('fivempro_mech_hub', gh.coords, 3.6, 3.6, {
        name = 'fivempro_mech_hub',
        heading = gh.heading,
        debugPoly = false,
        minZ = gh.coords.z - 1.55,
        maxZ = gh.coords.z + 3.0,
    }, {
        options = {
            {
                type = 'client',
                event = 'fivempro_mechanic:client:openGarageFleet',
                icon = 'fas fa-warehouse',
                label = 'Mechanikų garažas',
                canInteract = function()
                    return isMechanicOnDuty()
                end,
            },
            {
                type = 'client',
                event = 'fivempro_mechanic:client:openDealershipFleet',
                icon = 'fas fa-truck-pickup',
                label = 'Tarnybinio transporto pirkimas',
                canInteract = function()
                    return isMechanicOnDuty()
                end,
            },
        },
        distance = Config.TargetDistance + 1.0,
    })

    local st = Config.Stash
    exports['qb-target']:AddBoxZone('fivempro_mech_stash', st.coords, 1.75, 1.75, {
        name = 'fivempro_mech_stash',
        heading = st.heading or Config.Base.w,
        debugPoly = false,
        minZ = st.coords.z - 1.15,
        maxZ = st.coords.z + 2.35,
    }, {
        options = {
            {
                type = 'client',
                event = 'fivempro_mechanic:client:openStash',
                icon = 'fas fa-box',
                label = 'Mechanikų sandėlis',
                canInteract = function()
                    return isMechanicOnDuty()
                end,
            },
        },
        distance = Config.TargetDistance + 0.35,
    })

    local lk = Config.Locker
    exports['qb-target']:AddBoxZone('fivempro_mech_locker', lk.coords, 1.65, 1.65, {
        name = 'fivempro_mech_locker',
        heading = lk.heading,
        debugPoly = false,
        minZ = lk.coords.z - 1.15,
        maxZ = lk.coords.z + 2.35,
    }, {
        options = {
            {
                type = 'client',
                event = 'fivempro_mechanic:client:openLocker',
                icon = 'fas fa-shirt',
                label = 'Rūbinė (darbo apranga)',
                canInteract = function()
                    return isMechanicOnDuty()
                end,
            },
        },
        distance = Config.TargetDistance + 0.35,
    })

    local mg = Config.Management.coords
    exports['qb-target']:AddBoxZone('fivempro_mech_mgmt', mg, 1.95, 1.95, {
        name = 'fivempro_mech_mgmt',
        heading = Config.Management.heading,
        debugPoly = false,
        minZ = mg.z - 1.25,
        maxZ = mg.z + 2.55,
    }, {
        options = {
            {
                type = 'client',
                event = 'fivempro_mechanic:client:bossOpenMenu',
                icon = 'fas fa-user-tie',
                label = 'Vadovybė (įdarb./rangai)',
                canInteract = function()
                    local P = QBCore.Functions.GetPlayerData()
                    if not P or not P.job or P.job.name ~= Config.JobName or not P.job.onduty then return false end
                    if P.job.isboss then return true end
                    return (P.job.grade and P.job.grade.level or 0) >= (Config.Permissions.boss_menu or 4)
                end,
            },
        },
        distance = 3.4,
    })

    exports['qb-target']:AddBoxZone('fivempro_mech_duty', vector3(Config.Base.x, Config.Base.y, Config.Base.z), 1.85, 1.85, {
        name = 'fivempro_mech_duty',
        heading = Config.Base.w,
        debugPoly = false,
        minZ = Config.Base.z - 1.15,
        maxZ = Config.Base.z + 2.45,
    }, {
        options = {
            {
                type = 'client',
                event = 'fivempro_mechanic:client:toggleDuty',
                icon = 'fas fa-id-badge',
                label = 'Tarnyba (įjungti / išjungti)',
                canInteract = function()
                    return isMechanicJob()
                end,
            },
        },
        distance = Config.TargetDistance + 0.65,
    })

    for i, bay in ipairs(Config.RepairBays or {}) do
        exports['qb-target']:AddBoxZone(('fivempro_mech_bay_%s'):format(i), bay.coords, bay.length, bay.width, {
            name = ('fivempro_mech_bay_%s'):format(i),
            heading = bay.heading,
            debugPoly = false,
            minZ = bay.coords.z - 1.35,
            maxZ = bay.coords.z + 3.5,
        }, {
            options = {
                {
                    type = 'client',
                    event = 'fivempro_mechanic:client:quickRepairHere',
                    icon = 'fas fa-wrench',
                    label = ('Remonto vieta #%s – apžiūra'):format(i),
                    canInteract = function()
                        return isMechanicOnDuty()
                    end,
                },
            },
            distance = 14.0,
        })
    end
end)
