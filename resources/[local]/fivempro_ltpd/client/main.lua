local QBCore = exports['qb-core']:GetCoreObject()
local mdtOpen = false

local function isPdJobName(name)
    return name == Config.JobName
end

local function isPdOnDutyClient()
    local P = QBCore.Functions.GetPlayerData()
    return P and P.job and isPdJobName(P.job.name) and P.job.onduty
end

local function closeMdt()
    if not mdtOpen then return end
    mdtOpen = false
    TriggerEvent('fivempro_ltpd:client:surveillanceStopAll')
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

RegisterNetEvent('fivempro_ltpd:client:forceCloseMdt', function()
    closeMdt()
end)

RegisterNetEvent('fivempro_ltpd:client:cuffedState', function(state)
    LocalPlayer.state:set('ltpdCuffed', state, true)
    local ped = PlayerPedId()
    if state then
        RequestAnimDict('mp_arresting')
        while not HasAnimDictLoaded('mp_arresting') do Wait(10) end
        TaskPlayAnim(ped, 'mp_arresting', 'idle', 8.0, -8.0, -1, 49, 0, false, false, false)
    else
        ClearPedTasks(ped)
    end
end)

CreateThread(function()
    while true do
        if LocalPlayer.state.ltpdCuffed then
            DisableControlAction(0, 24, true)
            DisableControlAction(0, 25, true)
            DisableControlAction(0, 21, true)
            DisableControlAction(0, 22, true)
            Wait(0)
        else
            Wait(300)
        end
    end
end)

--- NUI fetch veikia tik kai hasFocus=true (FiveM). Be cursor žaidėjas gali naudoti CCTV valdymus.
local function setMdtNuiFocus(cursor)
    if not mdtOpen then
        SetNuiFocus(false, false)
        return
    end
    SetNuiFocus(true, cursor == true)
end

local function openMdt()
    QBCore.Functions.TriggerCallback('fivempro_ltpd:server:canOpenMdt', function(can)
        if not can then
            return QBCore.Functions.Notify('MDT prieinamas tik policijai tarnybos metu.', 'error')
        end
        QBCore.Functions.TriggerCallback('fivempro_ltpd:server:mdtContext', function(ctx)
            if not ctx then return end
            mdtOpen = true
            setMdtNuiFocus(true)
            SendNUIMessage({ action = 'open', data = ctx })
        end)
    end)
end

RegisterCommand('mdt', function()
    local Player = QBCore.Functions.GetPlayerData()
    if not Player or not isPdJobName(Player.job.name) or not Player.job.onduty then
        return QBCore.Functions.Notify('Tu ne policininkas arba ne tarnyboje.', 'error')
    end
    openMdt()
end, false)

RegisterNetEvent('fivempro_ltpd:client:mdtCctvFocus', function(restoreMdt)
    if not mdtOpen then
        SetNuiFocus(false, false)
        return
    end
    if restoreMdt then
        setMdtNuiFocus(true)
    else
        setMdtNuiFocus(false)
    end
end)

RegisterNUICallback('mdtPing', function(_, cb)
    cb({ ok = true, mdtOpen = mdtOpen == true })
end)

RegisterNUICallback('close', function(_, cb)
    closeMdt()
    cb({ ok = true })
end)

RegisterNUICallback('mdtSetDocked', function(data, cb)
    local docked = data and data.docked == true
    if mdtOpen then
        setMdtNuiFocus(not docked)
    end
    cb({ ok = true })
end)

RegisterNUICallback('searchPerson', function(data, cb)
    QBCore.Functions.TriggerCallback('fivempro_ltpd:server:searchPerson', function(result)
        cb(result or { ok = false })
    end, data and data.query)
end)

RegisterNUICallback('searchVehicle', function(data, cb)
    QBCore.Functions.TriggerCallback('fivempro_ltpd:server:searchVehicle', function(result)
        cb(result or { ok = false })
    end, data and data.plate)
end)

RegisterNUICallback('issueFine', function(data, cb)
    QBCore.Functions.TriggerCallback('fivempro_ltpd:server:issueFine', function(result)
        cb(result or { ok = false })
    end, data)
end)

RegisterNUICallback('setWanted', function(data, cb)
    QBCore.Functions.TriggerCallback('fivempro_ltpd:server:setWanted', function(result)
        cb(result or { ok = false })
    end, data)
end)

RegisterNUICallback('addArrest', function(data, cb)
    QBCore.Functions.TriggerCallback('fivempro_ltpd:server:addArrestNote', function(result)
        cb(result or { ok = false })
    end, data and data.citizenid, data and data.notes, data and data.reason, data and data.sentence)
end)

RegisterNUICallback('getArrestHistory', function(data, cb)
    QBCore.Functions.TriggerCallback('fivempro_ltpd:server:getArrestHistory', function(result)
        cb(result or { ok = false, rows = {} })
    end, data and data.citizenid)
end)

local function isDispatchWritable()
    local P = QBCore.Functions.GetPlayerData()
    return P and P.job and isPdJobName(P.job.name) and P.job.onduty == true
end

RegisterNUICallback('dispatchSnapshot', function(_, cb)
    if GetResourceState('fivempro_dispatch') ~= 'started' then
        return cb({
            ok = true,
            readOnly = true,
            calls = {},
            crews = {},
            units = {},
            msg = 'fivempro_dispatch neįkeltas',
        })
    end
    local done = false
    local function reply(payload)
        if done then return end
        done = true
        cb(payload or { ok = false, calls = {}, crews = {}, units = {} })
    end
    SetTimeout(12000, function()
        reply({ ok = false, msg = 'Dispatch timeout', calls = {}, crews = {}, units = {} })
    end)
    QBCore.Functions.TriggerCallback('fivempro_dispatch:server:getMdtSnapshot', function(result)
        reply(result or { ok = false, calls = {}, crews = {}, units = {} })
    end, 'police')
end)

RegisterNUICallback('dispatchAction', function(data, cb)
    if not isDispatchWritable() then
        return cb({ ok = false, msg = 'Tik pamainoje galima valdyti dispatch.' })
    end
    if data and data.callId and data.action then
        TriggerServerEvent('fivempro_dispatch:server:updateCallStatus', data.callId, data.action)
    end
    cb({ ok = true })
end)

RegisterNUICallback('crewAction', function(data, cb)
    if not isDispatchWritable() then
        return cb({ ok = false, msg = 'Tik pamainoje galima valdyti ekipažus.' })
    end
    local action = tostring(data and data.action or '')
    if action == 'create' then
        TriggerServerEvent('fivempro_dispatch:server:createCrew', tostring(data.callsign or ''))
    elseif action == 'join' then
        TriggerServerEvent('fivempro_dispatch:server:joinCrew', tostring(data.crewId or ''))
    elseif action == 'addMember' then
        TriggerServerEvent('fivempro_dispatch:server:addToCrew', tostring(data.crewId or ''), tonumber(data.targetId))
    elseif action == 'delete' then
        TriggerServerEvent('fivempro_dispatch:server:deleteCrew', tostring(data.crewId or ''))
    elseif action == 'leave' then
        TriggerServerEvent('fivempro_dispatch:server:leaveCrew')
    elseif action == 'setCallsign' then
        TriggerServerEvent('fivempro_dispatch:server:setCallsign', tostring(data.callsign or ''))
    elseif action == 'panic' then
        TriggerServerEvent('fivempro_dispatch:server:panic')
    elseif action == 'panicOff' and data.callId then
        TriggerServerEvent('fivempro_dispatch:server:updateCallStatus', tostring(data.callId), 'panic_off')
    end
    cb({ ok = true })
end)

RegisterNUICallback('mdtSetRoute', function(data, cb)
    local x = tonumber(data and data.x)
    local y = tonumber(data and data.y)
    if x and y then
        SetNewWaypoint(x + 0.0, y + 0.0)
        QBCore.Functions.Notify('Maršrutas nustatytas GPS.', 'success')
    end
    cb({ ok = true })
end)

CreateThread(function()
    while true do
        if mdtOpen and (IsControlJustPressed(0, 199) or IsDisabledControlJustPressed(0, 199) or IsControlJustPressed(0, 200) or IsDisabledControlJustPressed(0, 200)) then
            closeMdt()
        end
        Wait(0)
    end
end)

RegisterNetEvent('fivempro_ltpd:client:openMdtAtStation', function()
    local Player = QBCore.Functions.GetPlayerData()
    if not Player or not isPdJobName(Player.job.name) or not Player.job.onduty then
        return QBCore.Functions.Notify('MDT – tik policijai tarnyboje.', 'error')
    end
    openMdt()
end)

RegisterNetEvent('fivempro_ltpd:client:tryOpenArmory', function(data)
    if not isPdOnDutyClient() then
        return QBCore.Functions.Notify('Tik policijai tarnyboje.', 'error')
    end
    local stationId = data and data.stationId
    if not stationId then return end
    TriggerServerEvent('fivempro_ltpd:server:openArmory', stationId)
end)

--- PD asmeninis garažas (tas pats UI kaip fivempro_garages; mašinos perkamos PD salone)
RegisterNetEvent('fivempro_ltpd:client:openPdGarage', function(data)
    if not isPdOnDutyClient() then
        return QBCore.Functions.Notify('Tik policijai tarnyboje.', 'error')
    end
    local stationId = data and data.stationId
    if not stationId then return end
    local gid = nil
    for _, s in ipairs(Config.Stations or {}) do
        if s.id == stationId then
            gid = s.pdGarageId
            break
        end
    end
    if not gid then
        return QBCore.Functions.Notify('PD garažas nekonfigūruotas.', 'error')
    end
    TriggerEvent('fivempro_garages:client:openGarage', { garageId = gid })
end)

RegisterNetEvent('fivempro_ltpd:client:goPoliceDealership', function(data)
    if not isPdOnDutyClient() then
        return QBCore.Functions.Notify('Tik policijai tarnyboje.', 'error')
    end
    local stationId = data and data.stationId
    if not stationId then return end
    if GetResourceState('fivempro_dealership') ~= 'started' then
        return QBCore.Functions.Notify('fivempro_dealership neįjungtas.', 'error')
    end
    TriggerEvent('fivempro_dealership:client:openPoliceDealership', stationId)
end)

RegisterNetEvent('fivempro_ltpd:client:tryOpenStash', function(data)
    if not isPdOnDutyClient() then
        return QBCore.Functions.Notify('Tik policijai tarnyboje.', 'error')
    end
    local stationId = data and data.stationId
    local stashIndex = data and data.stashIndex
    if not stationId or stashIndex == nil then return end
    TriggerServerEvent('fivempro_ltpd:server:openPoliceStash', stationId, tonumber(stashIndex))
end)

RegisterNetEvent('fivempro_ltpd:client:requestSpawnFleet', function(args)
    if not isPdOnDutyClient() then return end
    local model = args and args.model
    local stationId = args and args.stationId
    if not model or not stationId then return end
    TriggerServerEvent('fivempro_ltpd:server:spawnFleet', stationId, model)
end)

RegisterNetEvent('fivempro_ltpd:client:openHeliGarageMenu', function(data)
    if not isPdOnDutyClient() then
        return QBCore.Functions.Notify('Tik policijai tarnyboje.', 'error')
    end
    local stationId = data and data.stationId
    if not stationId or not Config.FleetHelicopters or not next(Config.FleetHelicopters) then return end
    local stLabel = 'PD oro tarnyba'
    for _, s in ipairs(Config.Stations or {}) do
        if s.id == stationId then
            stLabel = (s.label or '') .. ' – sraigtasparniai'
            break
        end
    end
    local menu = {
        { header = stLabel, isMenuHeader = true },
    }
    for _, v in ipairs(Config.FleetHelicopters) do
        menu[#menu + 1] = {
            header = v.label,
            txt = v.model,
            params = {
                event = 'fivempro_ltpd:client:requestSpawnHeli',
                args = { stationId = stationId, model = v.model },
            },
        }
    end
    if GetResourceState('qb-menu') == 'started' then
        TriggerEvent('qb-menu:client:openMenu', menu, false, true)
    else
        QBCore.Functions.Notify('Reikia qb-menu.', 'error')
    end
end)

RegisterNetEvent('fivempro_ltpd:client:requestSpawnHeli', function(args)
    if not isPdOnDutyClient() then return end
    local model = args and args.model
    local stationId = args and args.stationId
    if not model or not stationId then return end
    TriggerServerEvent('fivempro_ltpd:server:spawnFleetHeli', stationId, model)
end)

RegisterNetEvent('fivempro_ltpd:client:fleetVehicleReady', function(plate)
    if not plate or plate == '' then return end
    TriggerEvent('vehiclekeys:client:SetOwner', plate)
end)

CreateThread(function()
    if not Config.ShowStationBlips then return end
    for _, st in ipairs(Config.Stations or {}) do
        if st.coords then
            local b = AddBlipForCoord(st.coords.x, st.coords.y, st.coords.z)
            SetBlipSprite(b, Config.BlipSprite or 60)
            SetBlipDisplay(b, 4)
            SetBlipScale(b, Config.BlipScale or 0.85)
            SetBlipColour(b, Config.BlipColour or 38)
            SetBlipAsShortRange(b, true)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentSubstringPlayerName(st.label or 'Policija')
            EndTextCommandSetBlipName(b)
        end
        if Config.ShowHelipadBlip and st.heliGarage and st.heliGarage.coords then
            local h = st.heliGarage.coords
            local bh = AddBlipForCoord(h.x, h.y, h.z)
            SetBlipSprite(bh, Config.HelipadBlipSprite or 43)
            SetBlipDisplay(bh, 4)
            SetBlipScale(bh, Config.HelipadBlipScale or 0.9)
            SetBlipColour(bh, Config.BlipColour or 38)
            SetBlipAsShortRange(bh, true)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentSubstringPlayerName((st.label or 'PD') .. ' – helipadas')
            EndTextCommandSetBlipName(bh)
        end
    end
end)

CreateThread(function()
    while GetResourceState('qb-target') ~= 'started' do
        Wait(300)
    end
    local function canInteractBoss()
        local P = QBCore.Functions.GetPlayerData()
        if not P or not P.job or not isPdJobName(P.job.name) or not P.job.onduty then
            return false
        end
        if P.job.isboss then return true end
        return (P.job.grade and P.job.grade.level or 0) >= (Config.Permissions.boss_menu or 7)
    end
    for _, st in ipairs(Config.Stations or {}) do
        if st.mdt then
            local mc = st.coords
            exports['qb-target']:AddBoxZone(('ltpd_mdt_%s'):format(st.id), mc, 1.35, 1.35, {
                name = ('ltpd_mdt_%s'):format(st.id),
                heading = st.heading or 0.0,
                debugPoly = false,
                minZ = mc.z - 1.15,
                maxZ = mc.z + 2.45,
            }, {
                options = {
                    {
                        type = 'client',
                        event = 'fivempro_ltpd:client:openMdtAtStation',
                        icon = 'fas fa-tablet-screen-button',
                        label = 'MDT planšetė',
                        canInteract = function()
                            return isPdOnDutyClient()
                        end,
                    },
                },
                distance = Config.TargetDistance + 0.4,
            })
        end
        if st.management and st.management.coords then
            local mg = st.management.coords
            local mh = st.management.heading or st.heading or 0.0
            exports['qb-target']:AddBoxZone(('ltpd_mgmt_%s'):format(st.id), mg, 1.95, 1.95, {
                name = ('ltpd_mgmt_%s'):format(st.id),
                heading = mh,
                debugPoly = false,
                minZ = mg.z - 1.2,
                maxZ = mg.z + 2.45,
            }, {
                options = {
                    {
                        type = 'client',
                        event = 'fivempro_ltpd:client:bossOpenMenu',
                        icon = 'fas fa-user-tie',
                        label = 'PD vadovybė (įdarb./rangai/tarnyba)',
                        canInteract = canInteractBoss,
                    },
                },
                distance = 3.2,
            })
        end
        if st.heliGarage and st.heliGarage.coords then
            exports['qb-target']:AddCircleZone(('ltpd_heli_%s'):format(st.id), st.heliGarage.coords, 1.45, {
                name = ('ltpd_heli_%s'):format(st.id),
                debugPoly = false,
                useZ = true,
            }, {
                options = {
                    {
                        type = 'client',
                        event = 'fivempro_ltpd:client:openHeliGarageMenu',
                        icon = 'fas fa-helicopter',
                        label = 'PD sraigtasparniai (helipadas)',
                        stationId = st.id,
                        canInteract = function()
                            return isPdOnDutyClient()
                        end,
                    },
                },
                distance = Config.TargetDistance + 2.0,
            })
        end
    end
end)

local function applyDutyOutfitTable(ped, tbl)
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

RegisterNetEvent('fivempro_ltpd:client:toggleDuty', function()
    local P = QBCore.Functions.GetPlayerData()
    if not P or not P.job or not isPdJobName(P.job.name) then
        return QBCore.Functions.Notify('Tik policijos darbuotojams.', 'error')
    end
    TriggerServerEvent('QBCore:ToggleDuty')
end)

RegisterNetEvent('fivempro_ltpd:client:openDutyLockerMenu', function()
    if not isPdOnDutyClient() then
        return QBCore.Functions.Notify('Rūbinė – tik policijai tarnyboje.', 'error')
    end
    if GetResourceState('qb-menu') ~= 'started' then
        return QBCore.Functions.Notify('Reikia qb-menu.', 'error')
    end
    local P = QBCore.Functions.GetPlayerData()
    local grade = (P.job and P.job.grade and P.job.grade.level) or 0
    local menu = {
        { header = 'Tarnybinė apranga', isMenuHeader = true },
    }
    for idx, outfit in ipairs(Config.DutyOutfits or {}) do
        if grade >= (tonumber(outfit.minGrade) or 0) then
            menu[#menu + 1] = {
                header = outfit.label,
                txt = outfit.description or '',
                params = {
                    event = 'fivempro_ltpd:client:applyDutyOutfit',
                    args = { index = idx },
                },
            }
        end
    end
    menu[#menu + 1] = {
        header = 'Baigti tarnybą',
        txt = 'Uždeda tavo išsaugotą civilio aprangą (duty lieka aktyvus — baigti pamainą tik prie tarnybos NPC)',
        params = {
            event = 'fivempro_ltpd:client:applyCivilianOutfit',
        },
    }
    if #menu < 2 then
        return QBCore.Functions.Notify('Nėra prieinamų aprangų.', 'error')
    end
    TriggerEvent('qb-menu:client:openMenu', menu, false, true)
end)

RegisterNetEvent('fivempro_ltpd:client:applyDutyOutfit', function(data)
    if not isPdOnDutyClient() then return end
    local idx = tonumber(data and data.index)
    local outfit = idx and Config.DutyOutfits and Config.DutyOutfits[idx]
    if not outfit then return end
    local ped = PlayerPedId()
    local male = GetEntityModel(ped) == `mp_m_freemode_01`
    local tbl = male and outfit.male or outfit.female
    if not tbl then return end
    applyDutyOutfitTable(ped, tbl)
    local arm = tonumber(outfit.armour)
    if arm and arm > 0 then
        SetPedArmour(ped, math.min(100, arm))
    else
        SetPedArmour(ped, 0)
    end
    QBCore.Functions.Notify(outfit.label or 'Apranga uždėta.', 'success')
end)

RegisterNetEvent('fivempro_ltpd:client:applyCivilianOutfit', function()
    if not isPdOnDutyClient() then return end
    local ped = PlayerPedId()
    local health = GetEntityHealth(ped)
    if GetResourceState('qb-clothing') == 'started' then
        exports['qb-clothing']:reloadSkin(health)
    else
        TriggerServerEvent('qb-clothes:loadPlayerSkin')
        TriggerServerEvent('qb-clothing:loadPlayerSkin')
    end
    SetPedArmour(PlayerPedId(), 0)
    QBCore.Functions.Notify('Civilio apranga uždėta. Duty lieka aktyvus — pamainą baigti prie tarnybos NPC.', 'success')
end)

--- Ginklinė + papildomi sandėliai — 3D markeriai
CreateThread(function()
    while GetResourceState('fivempro_npcshops') ~= 'started' do
        Wait(200)
    end
    local addMarker = exports['fivempro_npcshops'].AddJobGroundMarker
    for _, st in ipairs(Config.Stations or {}) do
        if st.armory and st.armory.coords then
            local stationId = st.id
            addMarker({
                coords = st.armory.coords,
                kind = 'armory',
                label = st.armory.label or 'Ginklinė',
                scale = { x = 0.52, y = 0.52, z = 0.52 },
                canUse = isPdOnDutyClient,
                onPress = function()
                    TriggerEvent('fivempro_ltpd:client:tryOpenArmory', { stationId = stationId })
                end,
            })
        end
        for stashIdx, stash in ipairs(st.stashes or {}) do
            if stashIdx > 1 and stash.coords then
                local stationId = st.id
                local index = stashIdx
                addMarker({
                    coords = stash.coords,
                    kind = 'stash',
                    label = stash.label or ('Sandėlis #' .. tostring(stashIdx)),
                    scale = { x = 0.32, y = 0.32, z = 0.32 },
                    canUse = isPdOnDutyClient,
                    onPress = function()
                        TriggerEvent('fivempro_ltpd:client:tryOpenStash', { stationId = stationId, stashIndex = index })
                    end,
                })
            end
        end
    end
end)
