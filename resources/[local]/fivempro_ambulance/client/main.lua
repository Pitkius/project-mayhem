local QBCore = exports['qb-core']:GetCoreObject()

local function isEmsJob()
    local P = QBCore.Functions.GetPlayerData()
    return P and P.job and P.job.name == Config.JobName
end

local function isEmsOnDuty()
    local P = QBCore.Functions.GetPlayerData()
    return P and P.job and P.job.name == Config.JobName and P.job.onduty
end

local function getStationById(stationId)
    for _, st in ipairs(Config.Stations or {}) do
        if st.id == stationId then return st end
    end
    return Config.Stations and Config.Stations[1]
end

RegisterNetEvent('fivempro_ambulance:client:toggleDuty', function()
    local P = QBCore.Functions.GetPlayerData()
    if not P or not P.job or P.job.name ~= Config.JobName then return end
    TriggerServerEvent('QBCore:ToggleDuty')
end)

RegisterNetEvent('fivempro_ambulance:client:openGarageFleet', function(data)
    if not isEmsOnDuty() then
        return QBCore.Functions.Notify('Tik EMS tarnyboje.', 'error')
    end
    local stationId = type(data) == 'table' and data.stationId or nil
    local st = getStationById(stationId)
    local gid = st and st.emsGarageId or 'ems_ls'
    TriggerEvent('fivempro_garages:client:openGarage', { garageId = gid })
end)

RegisterNetEvent('fivempro_ambulance:client:openDealershipFleet', function(data)
    if not isEmsOnDuty() then
        return QBCore.Functions.Notify('Tik EMS tarnyboje.', 'error')
    end
    local stationId = type(data) == 'table' and data.stationId or nil
    local st = getStationById(stationId)
    local sid = st and st.id or 'ems_ls'
    TriggerEvent('fivempro_dealership:client:openEmsDealership', sid)
end)

RegisterNetEvent('fivempro_ambulance:client:openStash', function(data)
    if not isEmsOnDuty() then
        return QBCore.Functions.Notify('Tik EMS tarnyboje.', 'error')
    end
    local stationId = type(data) == 'table' and data.stationId or nil
    TriggerServerEvent('fivempro_ambulance:server:openStash', stationId)
end)

RegisterCommand('emsmdt', function()
    if not isEmsOnDuty() then
        return QBCore.Functions.Notify('Tik EMS tarnyboje.', 'error')
    end
    ExecuteCommand('servicemdt')
end, false)

RegisterCommand('emscall', function(_, args)
    if not isEmsOnDuty() then
        return QBCore.Functions.Notify('Tik EMS tarnyboje.', 'error')
    end
    local callType = tostring(args and args[1] or 'civilian_help')
    local text = table.concat(args or {}, ' ', 2)
    TriggerServerEvent('fivempro_dispatch:server:createServiceCall', 'ems', callType, text ~= '' and text or 'EMS vidinis iškvietimas')
    QBCore.Functions.Notify('EMS iškvietimas sukurtas MDT sistemoje.', 'success')
end, false)

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

RegisterNetEvent('fivempro_ambulance:client:openLocker', function(_data)
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
    local bl = Config.Blip
    for _, st in ipairs(Config.Stations or {}) do
        if st.blip and st.coords then
            local mark = AddBlipForCoord(st.coords.x, st.coords.y, st.coords.z)
            SetBlipSprite(mark, bl.sprite)
            SetBlipDisplay(mark, 4)
            SetBlipScale(mark, bl.scale)
            SetBlipColour(mark, bl.colour)
            SetBlipAsShortRange(mark, true)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentSubstringPlayerName(st.label or bl.label)
            EndTextCommandSetBlipName(mark)
        end
    end
end)

CreateThread(function()
    while GetResourceState('qb-target') ~= 'started' do
        Wait(300)
    end

    for _, st in ipairs(Config.Stations or {}) do
        local sid = st.id

        if st.locker and st.locker.coords then
            local lk = st.locker
            exports['qb-target']:AddBoxZone(('fivempro_ems_locker_%s'):format(sid), lk.coords, 1.65, 1.65, {
                name = ('fivempro_ems_locker_%s'):format(sid),
                heading = lk.heading or 0.0,
                debugPoly = false,
                minZ = lk.coords.z - 1.15,
                maxZ = lk.coords.z + 2.35,
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
                distance = Config.TargetDistance + 0.35,
            })
        end

        if st.management and st.management.coords then
            local mg = st.management.coords
            exports['qb-target']:AddBoxZone(('fivempro_ems_mgmt_%s'):format(sid), mg, 1.95, 1.95, {
                name = ('fivempro_ems_mgmt_%s'):format(sid),
                heading = st.management.heading or 0.0,
                debugPoly = false,
                minZ = mg.z - 1.25,
                maxZ = mg.z + 2.55,
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
                distance = 3.4,
            })
        end

        if st.coords then
            exports['qb-target']:AddBoxZone(('fivempro_ems_duty_%s'):format(sid), st.coords, 1.85, 1.85, {
                name = ('fivempro_ems_duty_%s'):format(sid),
                heading = st.heading or 0.0,
                debugPoly = false,
                minZ = st.coords.z - 1.15,
                maxZ = st.coords.z + 2.45,
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
                distance = Config.TargetDistance + 0.65,
            })
        end
    end

    for i, bay in ipairs(Config.RepairBays or {}) do
        exports['qb-target']:AddBoxZone(('fivempro_ems_bay_%s'):format(i), bay.coords, bay.length, bay.width, {
            name = ('fivempro_ems_bay_%s'):format(i),
            heading = bay.heading,
            debugPoly = false,
            minZ = bay.coords.z - 1.35,
            maxZ = bay.coords.z + 3.5,
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
            distance = 16.0,
        })
    end
end)
