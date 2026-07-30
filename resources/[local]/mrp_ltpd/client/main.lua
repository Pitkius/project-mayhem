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
    TriggerEvent('mrp_ltpd:client:surveillanceStopAll')
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
    QBCore.Functions.TriggerCallback('mrp_ltpd:server:mdtSessionClose', function() end)
end

RegisterNetEvent('mrp_ltpd:client:forceCloseMdt', function()
    closeMdt()
end)

RegisterNetEvent('mrp_ltpd:client:cuffedState', function(state)
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
    QBCore.Functions.TriggerCallback('mrp_ltpd:server:canOpenMdt', function(can)
        if not can then
            return QBCore.Functions.Notify('MDT prieinamas tik policijai tarnybos metu.', 'error')
        end
        QBCore.Functions.TriggerCallback('mrp_ltpd:server:mdtContext', function(ctx)
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

RegisterNetEvent('mrp_ltpd:client:mdtCctvFocus', function(restoreMdt)
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

RegisterNUICallback('mdtTelemetry', function(data, cb)
    QBCore.Functions.TriggerCallback('mrp_ltpd:server:mdtTelemetry', function(result)
        cb(result or { ok = true })
    end, data)
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
    QBCore.Functions.TriggerCallback('mrp_ltpd:server:searchPerson', function(result)
        nuiReply(cb, result)
    end, data and data.query)
end)

RegisterNUICallback('searchVehicle', function(data, cb)
    QBCore.Functions.TriggerCallback('mrp_ltpd:server:searchVehicle', function(result)
        cb(result or { ok = false })
    end, data and data.plate)
end)

RegisterNUICallback('issueFine', function(data, cb)
    QBCore.Functions.TriggerCallback('mrp_ltpd:server:issueFine', function(result)
        cb(result or { ok = false })
    end, data)
end)

RegisterNUICallback('setWanted', function(data, cb)
    QBCore.Functions.TriggerCallback('mrp_ltpd:server:setWanted', function(result)
        cb(result or { ok = false })
    end, data)
end)

RegisterNUICallback('collectFingerprint', function(data, cb)
    QBCore.Functions.TriggerCallback('mrp_ltpd:server:collectFingerprint', function(result)
        if result and result.message then
            QBCore.Functions.Notify(result.message, result.ok and 'success' or 'error')
        end
        cb(result or { ok = false })
    end, data and data.citizenid)
end)

RegisterNUICallback('issueWeaponLicense', function(data, cb)
    QBCore.Functions.TriggerCallback('mrp_ltpd:server:issueWeaponLicense', function(result)
        if result and result.message then
            QBCore.Functions.Notify(result.message, result.ok and 'success' or 'error')
        end
        cb(result or { ok = false })
    end, data and data.citizenid)
end)

RegisterNUICallback('revokeWeaponLicense', function(data, cb)
    QBCore.Functions.TriggerCallback('mrp_ltpd:server:revokeWeaponLicense', function(result)
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
    QBCore.Functions.TriggerCallback('mrp_ltpd:server:getMyFingerprints', function(res)
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
    QBCore.Functions.TriggerCallback('mrp_ltpd:server:addArrestNote', function(result)
        cb(result or { ok = false })
    end, data and data.citizenid, data and data.notes, data and data.reason, data and data.sentence)
end)

RegisterNUICallback('getArrestHistory', function(data, cb)
    QBCore.Functions.TriggerCallback('mrp_ltpd:server:getArrestHistory', function(result)
        cb(result or { ok = false, rows = {} })
    end, data and data.citizenid)
end)

RegisterNUICallback('getInterrogationHistory', function(data, cb)
    QBCore.Functions.TriggerCallback('mrp_ltpd:server:getInterrogationHistory', function(result)
        cb(result or { ok = false, rows = {} })
    end, data and data.citizenid)
end)

--[[
  Phase 3 „Bylos" skirtukas. Klientas nieko nesprendžia — kiekvieną užklausą
  autorizuoja ir validuoja serveris (server/mdt_incidents.lua).
]]
local INCIDENT_ENDPOINTS = {
    incidentMeta = 'mrp_ltpd:server:incidentMeta',
    incidentList = 'mrp_ltpd:server:incidentList',
    incidentGet = 'mrp_ltpd:server:incidentGet',
    incidentCreate = 'mrp_ltpd:server:incidentCreate',
    incidentTransition = 'mrp_ltpd:server:incidentTransition',
    incidentUpdateCase = 'mrp_ltpd:server:incidentUpdateCase',
    incidentSaveReport = 'mrp_ltpd:server:incidentSaveReport',
    incidentNearby = 'mrp_ltpd:server:incidentNearby',
    incidentAttachParty = 'mrp_ltpd:server:incidentAttachParty',
    incidentDetachParty = 'mrp_ltpd:server:incidentDetachParty',
    incidentAttachVehicle = 'mrp_ltpd:server:incidentAttachVehicle',
    incidentDetachVehicle = 'mrp_ltpd:server:incidentDetachVehicle',
    incidentAttachOfficer = 'mrp_ltpd:server:incidentAttachOfficer',
    incidentAddForce = 'mrp_ltpd:server:incidentAddForce',
    incidentAddTool = 'mrp_ltpd:server:incidentAddTool',
    incidentAddSeized = 'mrp_ltpd:server:incidentAddSeized',
    incidentAddEvidence = 'mrp_ltpd:server:incidentAddEvidence',
    incidentSealEvidence = 'mrp_ltpd:server:incidentSealEvidence',
    incidentAddRef = 'mrp_ltpd:server:incidentAddRef',
    incidentIssueFine = 'mrp_ltpd:server:incidentIssueFine',
    incidentAddArrest = 'mrp_ltpd:server:incidentAddArrest',
}

for endpoint, serverCallback in pairs(INCIDENT_ENDPOINTS) do
    RegisterNUICallback(endpoint, function(data, cb)
        QBCore.Functions.TriggerCallback(serverCallback, function(result)
            cb(result or { ok = false, message = 'Nėra atsakymo iš serverio.' })
        end, data)
    end)
end

local function isDispatchWritable()
    local P = QBCore.Functions.GetPlayerData()
    return P and P.job and isPdJobName(P.job.name) and P.job.onduty == true
end

--- Tiksli savo pozicija MDT žemėlapiui (kliento GetEntityCoords, ne serverio)
CreateThread(function()
    local lastPos = nil
    while true do
        if mdtOpen then
            local perf = Config.MdtPerformance or {}
            local interval = math.max(200, tonumber(perf.PlayerPosIntervalMs) or 750)
            local minMove = tonumber(perf.PlayerPosMinMoveM) or 2.5
            local minMoveSq = minMove * minMove

            local ped = PlayerPedId()
            local c = GetEntityCoords(ped)
            local send = not lastPos
            if lastPos then
                local dx = c.x - lastPos.x
                local dy = c.y - lastPos.y
                local dz = c.z - lastPos.z
                if (dx * dx + dy * dy + dz * dz) >= minMoveSq then
                    send = true
                end
            end
            if send then
                lastPos = c
                SendNUIMessage({
                    action = 'mdtPlayerPos',
                    selfSource = GetPlayerServerId(PlayerId()),
                    x = c.x,
                    y = c.y,
                    z = c.z,
                    heading = GetEntityHeading(ped),
                })
            end
            Wait(interval)
        else
            lastPos = nil
            Wait(500)
        end
    end
end)

--- Gyvas GPS / dispatch atnaujinimas į MDT (mrp_dispatch push — fallback poll lėtesnis Phase 7)
RegisterNetEvent('mrp_dispatch:client:update', function(payload)
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
    if GetResourceState('mrp_dispatch') ~= 'started' then
        return cb({
            ok = true,
            readOnly = true,
            calls = {},
            crews = {},
            units = {},
            msg = 'mrp_dispatch neįkeltas',
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
    QBCore.Functions.TriggerCallback('mrp_dispatch:server:getMdtSnapshot', function(result)
        reply(result or { ok = false, calls = {}, crews = {}, units = {} })
    end, 'police')
end)

RegisterNUICallback('dispatchAction', function(data, cb)
    if not isDispatchWritable() then
        return cb({ ok = false, msg = 'Tik pamainoje galima valdyti dispatch.' })
    end
    if data and data.callId and data.action then
        TriggerServerEvent('mrp_dispatch:server:updateCallStatus', data.callId, data.action)
    end
    cb({ ok = true })
end)

RegisterNUICallback('crewAction', function(data, cb)
    if not isDispatchWritable() then
        return cb({ ok = false, msg = 'Tik pamainoje galima valdyti ekipažus.' })
    end
    local action = tostring(data and data.action or '')
    if action == 'create' then
        TriggerServerEvent('mrp_dispatch:server:createCrew', tostring(data.callsign or ''))
    elseif action == 'join' then
        TriggerServerEvent('mrp_dispatch:server:joinCrew', tostring(data.crewId or ''))
    elseif action == 'addMember' then
        TriggerServerEvent('mrp_dispatch:server:addToCrew', tostring(data.crewId or ''), tonumber(data.targetId))
    elseif action == 'delete' then
        TriggerServerEvent('mrp_dispatch:server:deleteCrew', tostring(data.crewId or ''))
    elseif action == 'leave' then
        TriggerServerEvent('mrp_dispatch:server:leaveCrew')
    elseif action == 'setCallsign' then
        TriggerServerEvent('mrp_dispatch:server:setCallsign', tostring(data.callsign or ''))
    elseif action == 'panic' then
        TriggerServerEvent('mrp_dispatch:server:panic')
    elseif action == 'panicOff' and data.callId then
        TriggerServerEvent('mrp_dispatch:server:updateCallStatus', tostring(data.callId), 'panic_off')
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

RegisterNetEvent('mrp_ltpd:client:openMdtAtStation', function()
    local Player = QBCore.Functions.GetPlayerData()
    if not Player or not isPdJobName(Player.job.name) or not Player.job.onduty then
        return QBCore.Functions.Notify('MDT – tik policijai tarnyboje.', 'error')
    end
    openMdt()
end)

RegisterNetEvent('mrp_ltpd:client:tryOpenArmory', function(data)
    if not isPdOnDutyClient() then
        return QBCore.Functions.Notify('Tik policijai tarnyboje.', 'error')
    end
    local stationId = data and data.stationId
    if not stationId then return end
    TriggerServerEvent('mrp_ltpd:server:openArmory', stationId)
end)

--- PD asmeninis garažas (tas pats UI kaip mrp_garages; mašinos perkamos PD salone)
RegisterNetEvent('mrp_ltpd:client:openPdGarage', function(data)
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
    TriggerEvent('mrp_garages:client:openGarage', { garageId = gid })
end)

RegisterNetEvent('mrp_ltpd:client:goPoliceDealership', function(data)
    if not isPdOnDutyClient() then
        return QBCore.Functions.Notify('Tik policijai tarnyboje.', 'error')
    end
    local stationId = data and data.stationId
    if not stationId then return end
    if GetResourceState('mrp_dealership') ~= 'started' then
        return QBCore.Functions.Notify('mrp_dealership neįjungtas.', 'error')
    end
    TriggerEvent('mrp_dealership:client:openPoliceDealership', stationId)
end)

RegisterNetEvent('mrp_ltpd:client:tryOpenStash', function(data)
    if not isPdOnDutyClient() then
        return QBCore.Functions.Notify('Tik policijai tarnyboje.', 'error')
    end
    local stationId = data and data.stationId
    local stashIndex = data and data.stashIndex
    if not stationId or stashIndex == nil then return end
    TriggerServerEvent('mrp_ltpd:server:openPoliceStash', stationId, tonumber(stashIndex))
end)

RegisterNetEvent('mrp_ltpd:client:requestSpawnFleet', function(args)
    if not isPdOnDutyClient() then return end
    local model = args and args.model
    local stationId = args and args.stationId
    if not model or not stationId then return end
    TriggerServerEvent('mrp_ltpd:server:spawnFleet', stationId, model)
end)

RegisterNetEvent('mrp_ltpd:client:openHeliGarageMenu', function(data)
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
                event = 'mrp_ltpd:client:requestSpawnHeli',
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

RegisterNetEvent('mrp_ltpd:client:requestSpawnHeli', function(args)
    if not isPdOnDutyClient() then return end
    local model = args and args.model
    local stationId = args and args.stationId
    if not model or not stationId then return end
    TriggerServerEvent('mrp_ltpd:server:spawnFleetHeli', stationId, model)
end)

RegisterNetEvent('mrp_ltpd:client:fleetVehicleReady', function(plate)
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
            exports['mrp_fonts']:SetBlipName(b, st.label or 'Policija')
        end
        if Config.ShowHelipadBlip and st.heliGarage and st.heliGarage.coords then
            local h = st.heliGarage.coords
            local bh = AddBlipForCoord(h.x, h.y, h.z)
            SetBlipSprite(bh, Config.HelipadBlipSprite or 43)
            SetBlipDisplay(bh, 4)
            SetBlipScale(bh, Config.HelipadBlipScale or 0.9)
            SetBlipColour(bh, Config.BlipColour or 38)
            SetBlipAsShortRange(bh, true)
            exports['mrp_fonts']:SetBlipName(bh, (st.label or 'PD') .. ' – helipadas')
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
            params = { event = 'mrp_ltpd:client:openPdGarage', args = { stationId = stationId } },
        },
        {
            header = 'Transporto pirkimas',
            params = { event = 'mrp_ltpd:client:goPoliceDealership', args = { stationId = stationId } },
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

local function getDutyOutfitGenderKey(ped)
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

local function buildPdDutyLockerItems(grade, lockerMode, genderKey)
    local division = exports['mrp_ltpd']:GetPdDivision()
    local P = QBCore.Functions.GetPlayerData()
    local isBoss = P and P.job and P.job.isboss == true
    local items = {}
    for idx, outfit in ipairs(Config.DutyOutfits or {}) do
        if not outfit[genderKey] then goto continue_outfit end
        if not PdDivisions.outfitAllowed(outfit, lockerMode, grade, division, isBoss) then goto continue_outfit end
        local cat = inferOutfitCategory(outfit, genderKey)
        items[#items + 1] = {
            id = tostring(idx),
            category = cat,
            label = outfit.label,
            description = outfit.description or '',
        }
        ::continue_outfit::
    end
    return items
end

local function applyPdDutyOutfitIndex(idx)
    if not isPdOnDutyClient() then return end
    local outfit = Config.DutyOutfits and Config.DutyOutfits[idx]
    if not outfit then return end
    local ped = PlayerPedId()
    local genderKey = getDutyOutfitGenderKey(ped)
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
        applyDutyOutfitTable(ped, tbl)
    end
    if category == 'vest' or (tonumber(outfit.armour) or 0) > 0 then
        SetPedArmour(ped, 100)
    elseif category == 'uniform' or category == 'uniform_top' then
        SetPedArmour(ped, 0)
    end
    QBCore.Functions.Notify(outfit.label or 'Apranga uždėta.', 'success')
end

RegisterNetEvent('mrp_ltpd:client:toggleDuty', function()
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

RegisterNetEvent('mrp_ltpd:client:openDutyLockerMenu', function(data)
    if not isPdOnDutyClient() then
        return QBCore.Functions.Notify('Rūbinė – tik policijai tarnyboje.', 'error')
    end
    if GetResourceState('mrp_duty_locker') ~= 'started' then
        return QBCore.Functions.Notify('Rūbinės UI neaktyvus (mrp_duty_locker).', 'error')
    end
    data = type(data) == 'table' and data or {}
    local lockerMode = data.lockerMode or 'standard'
    local title = (lockerMode == 'aro' or lockerMode == 'sor' or lockerMode == 'aras') and 'ARAS rūbinė' or 'Tarnybinė apranga'
    if lockerMode == 'aro' or lockerMode == 'sor' or lockerMode == 'aras' then
        local eff = exports['mrp_ltpd']:GetPdEffectiveDivision()
        if eff ~= 'aras' and eff ~= 'sor' and eff ~= 'aro' then
            return QBCore.Functions.Notify('ARAS rūbinė – tik ARAS padaliniui (/pddept).', 'error')
        end
    end
    local P = QBCore.Functions.GetPlayerData()
    local grade = (P.job and P.job.grade and P.job.grade.level) or 0
    local chooseMin = tonumber((Config.DivisionRules or {}).chooseMinGrade) or 4
    local ped = PlayerPedId()
    local genderKey = getDutyOutfitGenderKey(ped)
    local actions = {}
    if lockerMode ~= 'aro' and lockerMode ~= 'sor' and lockerMode ~= 'aras' and grade >= chooseMin then
        local rankLabel = exports['mrp_ltpd']:GetPdDivisionRankLabel()
        actions[#actions + 1] = {
            id = 'division',
            label = rankLabel and ('Keisti padalinį (' .. rankLabel .. ')') or 'Keisti padalinį',
        }
    end
    if lockerMode ~= 'aro' and lockerMode ~= 'sor' and lockerMode ~= 'aras' then
        actions[#actions + 1] = { id = 'civilian', label = 'Civilio apranga', danger = true }
    end
    exports['mrp_duty_locker']:Open({
        title = title,
        subtitle = lockerMode == 'standard' and 'PD uniformos' or 'ARAS rinkinys',
        anchor = data.anchor,
        radius = data.radius or 2.6,
        items = buildPdDutyLockerItems(grade, lockerMode, genderKey),
        actions = actions,
        onApply = function(itemId)
            if type(itemId) == 'string' and itemId:sub(1, 7) == 'remove:' then
                local cat = itemId:sub(8)
                local p = PlayerPedId()
                exports['mrp_duty_locker']:ClearCategory(p, cat)
                if cat == 'vest' then SetPedArmour(p, 0) end
                QBCore.Functions.Notify('Nuimta.', 'success')
                return
            end
            applyPdDutyOutfitIndex(tonumber(itemId))
        end,
        onAction = function(actionId)
            exports['mrp_duty_locker']:Close()
            if actionId == 'civilian' then
                TriggerEvent('mrp_ltpd:client:applyCivilianOutfit')
            elseif actionId == 'division' then
                TriggerEvent('mrp_ltpd:client:openChooseDivisionMenu')
            end
        end,
    })
end)

RegisterNetEvent('mrp_ltpd:client:openDutyLockerCategory', function(data)
    TriggerEvent('mrp_ltpd:client:openDutyLockerMenu', data)
end)

RegisterNetEvent('mrp_ltpd:client:applyDutyOutfit', function(data)
    local idx = tonumber(data and data.index)
    if not idx then return end
    applyPdDutyOutfitIndex(idx)
end)

RegisterNetEvent('mrp_ltpd:client:applyCivilianOutfit', function()
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
    QBCore.Functions.Notify('Civilio apranga uždėta. Pamainą baigti — prie pamainos NPC (rūbinės zona).', 'success')
end)

RegisterNetEvent('mrp_ltpd:client:markerGarage', function(stationId)
    if not isPdOnDutyClient() then
        return QBCore.Functions.Notify('Tik tarnyboje.', 'error')
    end
    openPdGarageMenu(stationId)
end)
