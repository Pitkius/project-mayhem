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

RegisterNetEvent('mrp_ambulance:client:toggleDuty', function()
    local P = QBCore.Functions.GetPlayerData()
    if not P or not P.job or P.job.name ~= Config.JobName then return end
    TriggerServerEvent('QBCore:ToggleDuty')
end)

RegisterNetEvent('mrp_ambulance:client:openGarageFleet', function(data)
    if not isEmsOnDuty() then
        return QBCore.Functions.Notify('Tik EMS tarnyboje.', 'error')
    end
    local stationId = type(data) == 'table' and data.stationId or nil
    local st = getStationById(stationId)
    local gid = st and st.emsGarageId or 'ems_ls'
    TriggerEvent('mrp_garages:client:openGarage', { garageId = gid })
end)

RegisterNetEvent('mrp_ambulance:client:openDealershipFleet', function(data)
    if not isEmsOnDuty() then
        return QBCore.Functions.Notify('Tik EMS tarnyboje.', 'error')
    end
    local stationId = type(data) == 'table' and data.stationId or nil
    local st = getStationById(stationId)
    local sid = st and st.id or 'ems_ls'
    TriggerEvent('mrp_dealership:client:openEmsDealership', sid)
end)

RegisterNetEvent('mrp_ambulance:client:openStash', function(data)
    if not isEmsOnDuty() then
        return QBCore.Functions.Notify('Tik EMS tarnyboje.', 'error')
    end
    local stationId = type(data) == 'table' and data.stationId or nil
    TriggerServerEvent('mrp_ambulance:server:openStash', stationId)
end)

RegisterCommand('emsmdt', function()
    if not isEmsOnDuty() then
        return QBCore.Functions.Notify('Tik EMS tarnyboje.', 'error')
    end
    if GetResourceState('mrp_service_mdt') == 'started' then
        exports['mrp_service_mdt']:OpenMdt('ems')
    else
        ExecuteCommand('servicemdt')
    end
end, false)

RegisterCommand('emscall', function(_, args)
    if not isEmsOnDuty() then
        return QBCore.Functions.Notify('Tik EMS tarnyboje.', 'error')
    end
    local callType = tostring(args and args[1] or 'civilian_help')
    local text = table.concat(args or {}, ' ', 2)
    TriggerServerEvent('mrp_dispatch:server:createServiceCall', 'ems', callType, text ~= '' and text or 'EMS vidinis iškvietimas')
    QBCore.Functions.Notify('EMS iškvietimas sukurtas MDT sistemoje.', 'success')
end, false)

local function applyDutyComponent(ped, compId, val)
    if not ped or compId == nil or val == nil then return end
    local draw, tex, collection = 0, 0, nil
    if type(val) == 'table' then
        draw = tonumber(val.draw or val[1]) or 0
        tex = tonumber(val.tex or val[2]) or 0
        collection = val.collection
    else
        draw = tonumber(val) or 0
    end
    if collection and collection ~= '' then
        SetPedCollectionComponentVariation(ped, compId, collection, draw, tex, 0)
    else
        SetPedComponentVariation(ped, compId, draw, tex, 0)
    end
end

local function applyDutyProp(ped, propSlot, val)
    if not ped or propSlot == nil or val == nil then return end
    local draw, tex, collection = 0, 0, nil
    if type(val) == 'table' then
        draw = tonumber(val.draw or val[1]) or 0
        tex = tonumber(val.tex or val[2]) or 0
        collection = val.collection
    else
        draw = tonumber(val) or 0
    end
    if collection and collection ~= '' then
        SetPedCollectionPropIndex(ped, propSlot, collection, draw, tex, true)
    else
        SetPedPropIndex(ped, propSlot, draw, tex, true)
    end
end

local function applyOutfitTable(ped, tbl)
    if not ped or not tbl then return end
    local comps = tbl.components or tbl
    if type(comps) == 'table' then
        for comp, val in pairs(comps) do
            local c = tonumber(comp)
            if c ~= nil then applyDutyComponent(ped, c, val) end
        end
    end
    local props = tbl.props
    if type(props) == 'table' then
        for slot, val in pairs(props) do
            local p = tonumber(slot)
            if p ~= nil then applyDutyProp(ped, p, val) end
        end
    end
end

local function clearDutyVest(ped)
    if not ped then return end
    SetPedComponentVariation(ped, 9, 0, 0, 0)
end

local function getOutfitGenderKey(ped)
    if GetResourceState('mrp_duty_locker') == 'started' then
        return exports['mrp_duty_locker']:GetGenderKey(ped)
    end
    return GetEntityModel(ped) == `mp_m_freemode_01` and 'male' or 'female'
end

local function inferOutfitCategory(outfit, genderKey)
    if GetResourceState('mrp_duty_locker') == 'started' then
        return exports['mrp_duty_locker']:InferCategory(outfit, genderKey)
    end
    return outfit.category or 'uniform_top'
end

local function buildEmsDutyLockerItems(grade, genderKey)
    local items = {}
    for idx, outfit in ipairs(Config.DutyOutfits or {}) do
        if not outfit[genderKey] then goto continue_outfit end
        if grade < (tonumber(outfit.minGrade) or 0) then goto continue_outfit end
        items[#items + 1] = {
            id = tostring(idx),
            category = inferOutfitCategory(outfit, genderKey),
            label = outfit.label,
            description = outfit.description or '',
        }
        ::continue_outfit::
    end
    return items
end

local function applyEmsOutfitIndex(idx)
    if not isEmsOnDuty() then return end
    local outfit = Config.DutyOutfits and Config.DutyOutfits[idx]
    if not outfit then return end
    local ped = PlayerPedId()
    local genderKey = getOutfitGenderKey(ped)
    local tbl = outfit[genderKey]
    if not tbl then
        return QBCore.Functions.Notify('Ši apranga netinka tavo personažo modeliui.', 'error')
    end
    local category = inferOutfitCategory(outfit, genderKey)
    if category == 'uniform' or category == 'uniform_top' then
        clearDutyVest(ped)
    end
    if GetResourceState('mrp_duty_locker') == 'started' then
        exports['mrp_duty_locker']:ApplyCategory(ped, tbl, category)
    else
        applyOutfitTable(ped, tbl)
    end
    if category == 'vest' or (tonumber(outfit.armour) or 0) > 0 then
        SetPedArmour(ped, 100)
    elseif category == 'uniform' or category == 'uniform_top' then
        SetPedArmour(ped, 0)
    end
    QBCore.Functions.Notify(outfit.label or 'Apranga uždėta.', 'success')
end

local function resolveEmsLockerAnchor(stationId)
    local st = getStationById(stationId)
    if st and st.locker and st.locker.coords then
        return st.locker.coords
    end
    return GetEntityCoords(PlayerPedId())
end

RegisterNetEvent('mrp_ambulance:client:openLocker', function(data)
    if not isEmsOnDuty() then
        return QBCore.Functions.Notify('Rūbinė – tik EMS tarnyboje.', 'error')
    end
    if GetResourceState('mrp_duty_locker') ~= 'started' then
        return QBCore.Functions.Notify('Rūbinės UI neaktyvus (mrp_duty_locker).', 'error')
    end
    data = type(data) == 'table' and data or {}
    local P = QBCore.Functions.GetPlayerData()
    local grade = (P.job and P.job.grade and P.job.grade.level) or 0
    local ped = PlayerPedId()
    local genderKey = getOutfitGenderKey(ped)
    local stationId = data.stationId
    exports['mrp_duty_locker']:Open({
        title = 'EMS rūbinė',
        subtitle = 'Medicininė uniforma',
        anchor = data.anchor or resolveEmsLockerAnchor(stationId),
        radius = data.radius or 2.6,
        items = buildEmsDutyLockerItems(grade, genderKey),
        actions = {
            { id = 'civilian', label = 'Civilio apranga', danger = true },
        },
        onApply = function(itemId)
            if type(itemId) == 'string' and itemId:sub(1, 7) == 'remove:' then
                local cat = itemId:sub(8)
                local p = PlayerPedId()
                exports['mrp_duty_locker']:ClearCategory(p, cat)
                if cat == 'vest' then SetPedArmour(p, 0) end
                QBCore.Functions.Notify('Nuimta.', 'success')
                return
            end
            applyEmsOutfitIndex(tonumber(itemId))
        end,
        onAction = function(actionId)
            exports['mrp_duty_locker']:Close()
            if actionId == 'civilian' then
                TriggerEvent('mrp_ambulance:client:applyCivilianOutfit')
            end
        end,
    })
end)

RegisterNetEvent('mrp_ambulance:client:openLockerCategory', function(data)
    TriggerEvent('mrp_ambulance:client:openLocker', data)
end)

RegisterNetEvent('mrp_ambulance:client:applyCivilianOutfit', function()
    if not isEmsOnDuty() then return end
    local ped = PlayerPedId()
    local health = GetEntityHealth(ped)
    if GetResourceState('qb-clothing') == 'started' then
        exports['qb-clothing']:reloadSkin(health)
    else
        TriggerServerEvent('qb-clothes:loadPlayerSkin')
        TriggerServerEvent('qb-clothing:loadPlayerSkin')
    end
    SetPedArmour(ped, 0)
    QBCore.Functions.Notify('Civilio apranga uždėta. Duty lieka aktyvus.', 'success')
end)

RegisterNetEvent('mrp_ambulance:client:applyOutfit', function(data)
    local idx = tonumber(data and data.index)
    if not idx then return end
    applyEmsOutfitIndex(idx)
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
            exports['mrp_fonts']:SetBlipName(mark, st.label or bl.label)
        end
    end
end)

CreateThread(function()
    while GetResourceState('qb-target') ~= 'started' do
        Wait(300)
    end

    for _, st in ipairs(Config.Stations or {}) do
        local sid = st.id

        if st.management and st.management.coords then
            local mg = st.management.coords
            exports['qb-target']:AddBoxZone(('mrp_ems_mgmt_%s'):format(sid), mg, 1.95, 1.95, {
                name = ('mrp_ems_mgmt_%s'):format(sid),
                heading = st.management.heading or 0.0,
                debugPoly = false,
                minZ = mg.z - 1.25,
                maxZ = mg.z + 2.55,
            }, {
                options = {
                    {
                        type = 'client',
                        event = 'mrp_ambulance:client:bossOpenMenu',
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
            exports['qb-target']:AddBoxZone(('mrp_ems_duty_%s'):format(sid), st.coords, 1.85, 1.85, {
                name = ('mrp_ems_duty_%s'):format(sid),
                heading = st.heading or 0.0,
                debugPoly = false,
                minZ = st.coords.z - 1.15,
                maxZ = st.coords.z + 2.45,
            }, {
                options = {
                    {
                        type = 'client',
                        event = 'mrp_ambulance:client:toggleDuty',
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
        exports['qb-target']:AddBoxZone(('mrp_ems_bay_%s'):format(i), bay.coords, bay.length, bay.width, {
            name = ('mrp_ems_bay_%s'):format(i),
            heading = bay.heading,
            debugPoly = false,
            minZ = bay.coords.z - 1.35,
            maxZ = bay.coords.z + 3.5,
        }, {
            options = {
                {
                    type = 'client',
                    event = 'mrp_ambulance:client:outdoorBay',
                    icon = 'fas fa-user-injured',
                    label = ('Priėmimas / gydymas #%s'):format(i),
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
