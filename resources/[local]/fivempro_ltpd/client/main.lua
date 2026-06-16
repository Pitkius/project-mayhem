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

local function nuiReply(cb, payload)
    cb(payload or { ok = false })
end

RegisterNUICallback('searchPerson', function(data, cb)
    QBCore.Functions.TriggerCallback('fivempro_ltpd:server:searchPerson', function(result)
        nuiReply(cb, result)
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

RegisterNUICallback('collectFingerprint', function(data, cb)
    QBCore.Functions.TriggerCallback('fivempro_ltpd:server:collectFingerprint', function(result)
        if result and result.message then
            QBCore.Functions.Notify(result.message, result.ok and 'success' or 'error')
        end
        cb(result or { ok = false })
    end, data and data.citizenid)
end)

local function openFingerprintJournal()
    if not isPdOnDutyClient() then
        return QBCore.Functions.Notify('Tik tarnybos metu.', 'error')
    end
    if GetResourceState('qb-menu') ~= 'started' then
        return QBCore.Functions.Notify('Reikia qb-menu.', 'error')
    end
    QBCore.Functions.TriggerCallback('fivempro_ltpd:server:getMyFingerprints', function(res)
        if not res or not res.ok then
            return QBCore.Functions.Notify((res and res.message) or 'Nepavyko užkrauti.', 'error')
        end
        local menu = {
            { header = 'Surinkti atspaudai', isMenuHeader = true },
        }
        local rows = res.rows or {}
        if #rows == 0 then
            menu[#menu + 1] = { header = 'Tuščia', txt = 'MDT → Asmuo → „Įrašyti atspaudus“', isMenuHeader = true }
        else
            for _, r in ipairs(rows) do
                menu[#menu + 1] = {
                    header = r.name or r.citizenid,
                    txt = ('ID: %s | Atspaudas: %s'):format(r.citizenid or '—', r.fingerprint or '—'),
                    isMenuHeader = true,
                }
            end
        end
        menu[#menu + 1] = {
            header = 'Uždaryti',
            params = {
                isAction = true,
                event = function()
                    exports['qb-menu']:closeMenu()
                end,
            },
        }
        exports['qb-menu']:openMenu(menu)
    end)
end

RegisterCommand('+ltpdFingerprintJournal', openFingerprintJournal, false)
RegisterCommand('-ltpdFingerprintJournal', function() end, false)
RegisterKeyMapping('+ltpdFingerprintJournal', 'LTPD: surinkti pirštų atspaudai', 'keyboard', Config.FingerprintJournalKey or 'F7')

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

RegisterNUICallback('getInterrogationHistory', function(data, cb)
    QBCore.Functions.TriggerCallback('fivempro_ltpd:server:getInterrogationHistory', function(result)
        cb(result or { ok = false, rows = {} })
    end, data and data.citizenid)
end)

local function isDispatchWritable()
    local P = QBCore.Functions.GetPlayerData()
    return P and P.job and isPdJobName(P.job.name) and P.job.onduty == true
end

--- Tiksli savo pozicija MDT žemėlapiui (kliento GetEntityCoords, ne serverio)
CreateThread(function()
    while true do
        if mdtOpen then
            local ped = PlayerPedId()
            local c = GetEntityCoords(ped)
            SendNUIMessage({
                action = 'mdtPlayerPos',
                selfSource = GetPlayerServerId(PlayerId()),
                x = c.x,
                y = c.y,
                z = c.z,
                heading = GetEntityHeading(ped),
            })
            Wait(250)
        else
            Wait(750)
        end
    end
end)

--- Gyvas GPS / dispatch atnaujinimas į MDT (iš fivempro_dispatch push kas ~1.5s)
RegisterNetEvent('fivempro_dispatch:client:update', function(payload)
    if not mdtOpen or not payload or payload.service ~= 'police' then return end
    SendNUIMessage({
        action = 'dispatchLive',
        data = {
            units = payload.units or {},
            calls = payload.calls or {},
            crews = payload.crews or {},
            selfSource = GetPlayerServerId(PlayerId()),
            ts = payload.ts,
        },
    })
end)

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
        if mdtOpen then
            if IsControlJustPressed(0, 199) or IsDisabledControlJustPressed(0, 199) or IsControlJustPressed(0, 200) or IsDisabledControlJustPressed(0, 200) then
                closeMdt()
            end
            Wait(0)
        else
            Wait(400)
        end
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
        local bc = st.blipCoords or st.coords
        if bc then
            local b = AddBlipForCoord(bc.x, bc.y, bc.z)
            SetBlipSprite(b, Config.BlipSprite or 60)
            SetBlipDisplay(b, 4)
            SetBlipScale(b, Config.BlipScale or 0.85)
            SetBlipColour(b, Config.BlipColour or 38)
            SetBlipAsShortRange(b, true)
            exports['fivempro_fonts']:SetBlipName(b, st.label or 'Policija')
        end
        if Config.ShowHelipadBlip and st.heliGarage and st.heliGarage.coords then
            local h = st.heliGarage.coords
            local bh = AddBlipForCoord(h.x, h.y, h.z)
            SetBlipSprite(bh, Config.HelipadBlipSprite or 43)
            SetBlipDisplay(bh, 4)
            SetBlipScale(bh, Config.HelipadBlipScale or 0.9)
            SetBlipColour(bh, Config.BlipColour or 38)
            SetBlipAsShortRange(bh, true)
            exports['fivempro_fonts']:SetBlipName(bh, (st.label or 'PD') .. ' – helipadas')
        end
    end
end)

local function openPdGarageMenu(stationId)
    if GetResourceState('qb-menu') ~= 'started' then
        return QBCore.Functions.Notify('Reikia qb-menu.', 'error')
    end
    local menu = {
        { header = 'PD transportas', isMenuHeader = true },
        {
            header = 'Garažas',
            params = { event = 'fivempro_ltpd:client:openPdGarage', args = { stationId = stationId } },
        },
        {
            header = 'Transporto pirkimas',
            params = { event = 'fivempro_ltpd:client:goPoliceDealership', args = { stationId = stationId } },
        },
    }
    TriggerEvent('qb-menu:client:openMenu', menu, false, true)
end

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
        SetPedCollectionComponentVariation(ped, compId, collection, draw, tex, 2)
    else
        SetPedComponentVariation(ped, compId, draw, tex, 2)
    end
end

local function syncDutyArmsWithTorso(ped, comps)
    if not ped or type(comps) ~= 'table' then return end
    local torso = comps[11]
    if type(torso) ~= 'table' or not torso.collection then return end
    if comps[3] then return end
    applyDutyComponent(ped, 3, {
        collection = torso.collection,
        draw = tonumber(torso.draw) or 0,
        tex = tonumber(torso.tex) or 0,
    })
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

local function applyDutyOutfitTable(ped, tbl)
    if not ped or not tbl then return end
    local comps = tbl.components or tbl
    if type(comps) == 'table' then
        local order = { 3, 8, 11, 4, 6, 7, 9, 10, 1, 2, 5 }
        for _, compId in ipairs(order) do
            local val = comps[compId]
            if val ~= nil then applyDutyComponent(ped, compId, val) end
        end
        for comp, val in pairs(comps) do
            local c = tonumber(comp)
            if c ~= nil then
                local listed = false
                for _, id in ipairs(order) do
                    if id == c then listed = true break end
                end
                if not listed then applyDutyComponent(ped, c, val) end
            end
        end
        syncDutyArmsWithTorso(ped, comps)
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

local DUTY_CATEGORY_HEADERS = {
    uniform_pants = 'Kelnės',
    uniform_top = 'Viršutiniai drabužiai',
    uniform = 'Uniformos',
    vest = 'Liemenės',
    belt = 'Diržai',
    hat = 'Kepurės',
}

local function getDutyOutfitGenderKey(ped)
    return GetEntityModel(ped) == `mp_m_freemode_01` and 'male' or 'female'
end

local function buildDutyOutfitCategoryMenu(category, grade, lockerMode)
    local ped = PlayerPedId()
    local genderKey = getDutyOutfitGenderKey(ped)
    local header = DUTY_CATEGORY_HEADERS[category] or 'Apranga'
    local division = exports['fivempro_ltpd']:GetPdDivision()
    local menu = {
        { header = header, isMenuHeader = true },
    }
    for idx, outfit in ipairs(Config.DutyOutfits or {}) do
        if outfit.category == category and outfit[genderKey] then
            if PdDivisions.outfitAllowed(outfit, lockerMode, grade, division) then
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
    end
    menu[#menu + 1] = {
        header = '← Atgal',
        params = {
            event = 'fivempro_ltpd:client:openDutyLockerMenu',
            args = { lockerMode = lockerMode or 'standard' },
        },
    }
    return menu
end

RegisterNetEvent('fivempro_ltpd:client:toggleDuty', function()
    local P = QBCore.Functions.GetPlayerData()
    if not P or not P.job or not isPdJobName(P.job.name) then
        return QBCore.Functions.Notify('Tik policijos darbuotojams.', 'error')
    end
    TriggerServerEvent('QBCore:ToggleDuty')
    SetTimeout(400, function()
        if SyncPdDivisionState then
            SyncPdDivisionState()
        end
    end)
end)

RegisterNetEvent('fivempro_ltpd:client:openDutyLockerMenu', function(data)
    if not isPdOnDutyClient() then
        return QBCore.Functions.Notify('Rūbinė – tik policijai tarnyboje.', 'error')
    end
    if GetResourceState('qb-menu') ~= 'started' then
        return QBCore.Functions.Notify('Reikia qb-menu.', 'error')
    end
    local lockerMode = (type(data) == 'table' and data.lockerMode) or 'standard'
    local title = lockerMode == 'aro' and 'ARO rūbinė' or 'Tarnybinė apranga'
    if lockerMode == 'aro' then
        local eff = exports['fivempro_ltpd']:GetPdEffectiveDivision()
        if eff ~= 'aro' then
            return QBCore.Functions.Notify('ARO rūbinė – tik ARO padaliniui (/pddept).', 'error')
        end
    end
    local P = QBCore.Functions.GetPlayerData()
    local grade = (P.job and P.job.grade and P.job.grade.level) or 0
    local chooseMin = tonumber((Config.DivisionRules or {}).chooseMinGrade) or 4
    local menu = {
        { header = title, isMenuHeader = true },
        {
            header = 'Kelnės',
            txt = 'Uniformos kelnės (atskirai nuo viršaus)',
            params = {
                event = 'fivempro_ltpd:client:openDutyLockerCategory',
                args = { category = 'uniform_pants', lockerMode = lockerMode },
            },
        },
        {
            header = 'Viršutiniai drabužiai',
            txt = 'Striukės, marškinėliai, rankos suderintos',
            params = {
                event = 'fivempro_ltpd:client:openDutyLockerCategory',
                args = { category = 'uniform_top', lockerMode = lockerMode },
            },
        },
        {
            header = 'Liemenės',
            txt = 'Balistinės liemenės – pilni šarvai',
            params = {
                event = 'fivempro_ltpd:client:openDutyLockerCategory',
                args = { category = 'vest', lockerMode = lockerMode },
            },
        },
        {
            header = 'Diržai',
            txt = 'Diržai ir kiti aksesuarai',
            params = {
                event = 'fivempro_ltpd:client:openDutyLockerCategory',
                args = { category = 'belt', lockerMode = lockerMode },
            },
        },
        {
            header = 'Kepurės',
            txt = 'Šalmai ir kepurės',
            params = {
                event = 'fivempro_ltpd:client:openDutyLockerCategory',
                args = { category = 'hat', lockerMode = lockerMode },
            },
        },
    }
    if lockerMode ~= 'aro' and grade >= chooseMin then
        menu[#menu + 1] = {
            header = 'Keisti padalinį',
            txt = 'Patruliai, kriminalistai, ARO, kelių policija…',
            params = { event = 'fivempro_ltpd:client:openChooseDivisionMenu' },
        }
    end
    if lockerMode ~= 'aro' then
        menu[#menu + 1] = {
            header = 'Baigti tarnybą',
            txt = 'Civilio apranga (pamainą baigti tik prie MRPD NPC)',
            params = { event = 'fivempro_ltpd:client:applyCivilianOutfit' },
        }
    end
    TriggerEvent('qb-menu:client:openMenu', menu, false, true)
end)

RegisterNetEvent('fivempro_ltpd:client:openDutyLockerCategory', function(data)
    if not isPdOnDutyClient() then return end
    if GetResourceState('qb-menu') ~= 'started' then return end
    local P = QBCore.Functions.GetPlayerData()
    local grade = (P.job and P.job.grade and P.job.grade.level) or 0
    local category = type(data) == 'table' and data.category or 'uniform'
    local lockerMode = type(data) == 'table' and data.lockerMode or 'standard'
    local menu = buildDutyOutfitCategoryMenu(category, grade, lockerMode)
    if #menu < 2 then
        return QBCore.Functions.Notify('Nėra prieinamų aprangų šiai kategorijai.', 'error')
    end
    TriggerEvent('qb-menu:client:openMenu', menu, false, true)
end)

RegisterNetEvent('fivempro_ltpd:client:applyDutyOutfit', function(data)
    if not isPdOnDutyClient() then return end
    local idx = tonumber(data and data.index)
    local outfit = idx and Config.DutyOutfits and Config.DutyOutfits[idx]
    if not outfit then return end
    local ped = PlayerPedId()
    local genderKey = getDutyOutfitGenderKey(ped)
    local tbl = outfit[genderKey]
    if not tbl then
        return QBCore.Functions.Notify('Ši apranga netinka tavo personažo modeliui.', 'error')
    end
    if outfit.category == 'uniform' then
        clearDutyVest(ped)
    end
    applyDutyOutfitTable(ped, tbl)
    if outfit.category == 'vest' then
        SetPedArmour(ped, 100)
    elseif outfit.category == 'uniform' then
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
    QBCore.Functions.Notify('Civilio apranga uždėta. Pamainą baigti — MRPD registratūros NPC.', 'success')
end)

RegisterNetEvent('fivempro_ltpd:client:markerGarage', function(stationId)
    if not isPdOnDutyClient() then
        return QBCore.Functions.Notify('Tik tarnyboje.', 'error')
    end
    openPdGarageMenu(stationId)
end)
