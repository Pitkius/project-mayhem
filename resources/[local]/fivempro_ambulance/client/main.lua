local QBCore = exports['qb-core']:GetCoreObject()

local function isEmsJob()
    local P = QBCore.Functions.GetPlayerData()
    return P and P.job and P.job.name == Config.JobName
end

local function isEmsOnDuty()
    local P = QBCore.Functions.GetPlayerData()
    return P and P.job and P.job.name == Config.JobName and P.job.onduty
end

RegisterNetEvent('fivempro_ambulance:client:toggleDuty', function()
    local P = QBCore.Functions.GetPlayerData()
    if not P or not P.job or P.job.name ~= Config.JobName then return end
    TriggerServerEvent('QBCore:ToggleDuty')
end)

RegisterNetEvent('fivempro_ambulance:client:openGarageFleet', function()
    if not isEmsOnDuty() then
        return QBCore.Functions.Notify('Tik EMS tarnyboje.', 'error')
    end
    TriggerEvent('fivempro_garages:client:openGarage', { garageId = 'ems_ls' })
end)

RegisterNetEvent('fivempro_ambulance:client:openDealershipFleet', function()
    if not isEmsOnDuty() then
        return QBCore.Functions.Notify('Tik EMS tarnyboje.', 'error')
    end
    TriggerEvent('fivempro_dealership:client:openEmsDealership', 'ems_ls')
end)

RegisterNetEvent('fivempro_ambulance:client:openStash', function()
    if not isEmsOnDuty() then
        return QBCore.Functions.Notify('Tik EMS tarnyboje.', 'error')
    end
    TriggerServerEvent('fivempro_ambulance:server:openStash')
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

RegisterNetEvent('fivempro_ambulance:client:openLocker', function()
    if not isEmsOnDuty() then
        return QBCore.Functions.Notify('Rūbinė – tik EMS tarnyboje.', 'error')
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
                    event = 'fivempro_ambulance:client:applyOutfit',
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

RegisterNetEvent('fivempro_ambulance:client:applyOutfit', function(data)
    if not isEmsOnDuty() then return end
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

RegisterNetEvent('fivempro_ambulance:client:outdoorBay', function(data)
    if not isEmsOnDuty() then
        return QBCore.Functions.Notify('Tik EMS tarnyboje.', 'error')
    end
    local i = 1
    if type(data) == 'table' and data.bayIndex ~= nil then
        i = tonumber(data.bayIndex) or 1
    end
    QBCore.Functions.Notify(('Priėmimo zona #%s – prijunk su savo revive / hospital skriptu.'):format(i), 'primary', 6500)
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
    exports['qb-target']:AddBoxZone('fivempro_ems_hub', gh.coords, 2.8, 2.8, {
        name = 'fivempro_ems_hub',
        heading = gh.heading,
        debugPoly = false,
        minZ = gh.coords.z - 1.45,
        maxZ = gh.coords.z + 2.85,
    }, {
        options = {
            {
                type = 'client',
                event = 'fivempro_ambulance:client:openGarageFleet',
                icon = 'fas fa-warehouse',
                label = 'EMS garažas',
                canInteract = function()
                    return isEmsOnDuty()
                end,
            },
            {
                type = 'client',
                event = 'fivempro_ambulance:client:openDealershipFleet',
                icon = 'fas fa-truck-medical',
                label = 'EMS transporto pirkimas',
                canInteract = function()
                    return isEmsOnDuty()
                end,
            },
        },
        distance = Config.TargetDistance + 0.8,
    })

    local st = Config.Stash
    exports['qb-target']:AddBoxZone('fivempro_ems_stash', st.coords, 1.3, 1.3, {
        name = 'fivempro_ems_stash',
        heading = Config.Base.w,
        debugPoly = false,
        minZ = st.coords.z - 1.0,
        maxZ = st.coords.z + 2.0,
    }, {
        options = {
            {
                type = 'client',
                event = 'fivempro_ambulance:client:openStash',
                icon = 'fas fa-kit-medical',
                label = 'EMS sandėlis',
                canInteract = function()
                    return isEmsOnDuty()
                end,
            },
        },
        distance = Config.TargetDistance,
    })

    local lk = Config.Locker
    exports['qb-target']:AddBoxZone('fivempro_ems_locker', lk.coords, 1.25, 1.25, {
        name = 'fivempro_ems_locker',
        heading = lk.heading,
        debugPoly = false,
        minZ = lk.coords.z - 1.0,
        maxZ = lk.coords.z + 2.1,
    }, {
        options = {
            {
                type = 'client',
                event = 'fivempro_ambulance:client:openLocker',
                icon = 'fas fa-shirt',
                label = 'Rūbinė (darbo apranga)',
                canInteract = function()
                    return isEmsOnDuty()
                end,
            },
        },
        distance = Config.TargetDistance,
    })

    local mg = Config.Management.coords
    exports['qb-target']:AddBoxZone('fivempro_ems_mgmt', mg, 1.5, 1.5, {
        name = 'fivempro_ems_mgmt',
        heading = Config.Management.heading,
        debugPoly = false,
        minZ = mg.z - 1.1,
        maxZ = mg.z + 2.2,
    }, {
        options = {
            {
                type = 'client',
                event = 'fivempro_ambulance:client:bossOpenMenu',
                icon = 'fas fa-user-tie',
                label = 'EMS vadovybė',
                canInteract = function()
                    local P = QBCore.Functions.GetPlayerData()
                    if not P or not P.job or P.job.name ~= Config.JobName or not P.job.onduty then return false end
                    if P.job.isboss then return true end
                    return (P.job.grade and P.job.grade.level or 0) >= (Config.Permissions.boss_menu or 4)
                end,
            },
        },
        distance = 3.0,
    })

    exports['qb-target']:AddBoxZone('fivempro_ems_duty', vector3(Config.Base.x, Config.Base.y, Config.Base.z), 1.4, 1.4, {
        name = 'fivempro_ems_duty',
        heading = Config.Base.w,
        debugPoly = false,
        minZ = Config.Base.z - 1.0,
        maxZ = Config.Base.z + 2.2,
    }, {
        options = {
            {
                type = 'client',
                event = 'fivempro_ambulance:client:toggleDuty',
                icon = 'fas fa-id-badge',
                label = 'Tarnyba (įjungti / išjungti)',
                canInteract = function()
                    return isEmsJob()
                end,
            },
        },
        distance = Config.TargetDistance + 0.5,
    })

    for i, bay in ipairs(Config.RepairBays or {}) do
        exports['qb-target']:AddBoxZone(('fivempro_ems_bay_%s'):format(i), bay.coords, bay.length, bay.width, {
            name = ('fivempro_ems_bay_%s'):format(i),
            heading = bay.heading,
            debugPoly = false,
            minZ = bay.coords.z - 1.2,
            maxZ = bay.coords.z + 3.2,
        }, {
            options = {
                {
                    type = 'client',
                    event = 'fivempro_ambulance:client:outdoorBay',
                    icon = 'fas fa-user-injured',
                    label = ('Priėmimo vieta #%s'):format(i),
                    bayIndex = i,
                    canInteract = function()
                        return isEmsOnDuty()
                    end,
                },
            },
            distance = 14.0,
        })
    end
end)
