--- PD 3D markeriai ant žemės (MDT, garažas, rūbinė, sandėliai…)
local QBCore = exports['qb-core']:GetCoreObject()

local pdZones = {}
local lastInteractMs = 0
local markersReady = false

local COLORS = {
    garage = { 72, 160, 220, 200 },
    stash = { 255, 180, 72, 200 },
    locker = { 167, 139, 250, 210 },
    armory = { 239, 68, 68, 210 },
    supply = { 34, 197, 94, 200 },
    craft = { 251, 191, 36, 210 },
    mdt = { 96, 165, 250, 210 },
    duty = { 250, 204, 21, 200 },
}

local SCALES = {
    garage = { x = 2.6, y = 2.6, z = 0.28 },
    stash = nil, -- naudoja Config.PdStashMarkerScale
    locker = { x = 1.5, y = 1.5, z = 0.24 },
    armory = { x = 1.5, y = 1.5, z = 0.24 },
    supply = { x = 1.35, y = 1.35, z = 0.22 },
    craft = { x = 1.55, y = 1.55, z = 0.24 },
    mdt = { x = 1.45, y = 1.45, z = 0.24 },
    duty = { x = 1.5, y = 1.5, z = 0.24 },
}

local MARKER_TYPES = {
    garage = 36,
    stash = nil, -- naudoja Config.PdStashMarkerType
    locker = 27,
    armory = 27,
    supply = 27,
    craft = 27,
    mdt = 27,
    duty = 27,
}

local USE_RADIUS = {
    garage = 2.2,
    stash = 1.45,
    locker = 1.6,
    armory = 1.6,
    supply = 1.45,
    craft = 1.6,
    mdt = 1.45,
    duty = 1.6,
}

local function jobName()
    return Config.JobName or 'police'
end

local function isPdOnDuty()
    local P = QBCore.Functions.GetPlayerData()
    return P and P.job and P.job.name == jobName() and P.job.onduty
end

local function vec3From(c)
    if not c then return nil end
    return vector3(c.x + 0.0, c.y + 0.0, c.z + 0.0)
end

function RegisterPdGroundMarker(data)
    if not data or not data.coords then return end
    local pos = vec3From(data.coords)
    if not pos then return end
    local zOff = Config.PdMarkerZOffset or 0.02
    pdZones[#pdZones + 1] = {
        coords = vector3(pos.x, pos.y, pos.z + zOff),
        kind = data.kind or 'stash',
        label = data.label or 'PD',
        onPress = data.onPress,
        requireDuty = data.requireDuty ~= false,
        access = data.access,
    }
end

local function isPdJob()
    local P = QBCore.Functions.GetPlayerData()
    return P and P.job and P.job.name == jobName()
end

local function markerVisible(zone)
    if not isPdJob() then
        return false
    end
    if zone.access then
        return exports['fivempro_ltpd']:CanAccessPdPoint(zone.access)
    end
    return true
end

local function markerTypeFor(kind)
    if kind == 'stash' then
        return Config.PdStashMarkerType or 2
    end
    return MARKER_TYPES[kind] or 27
end

local function markerScaleFor(kind)
    if kind == 'stash' then
        return Config.PdStashMarkerScale or { x = 0.34, y = 0.34, z = 0.34 }
    end
    return SCALES[kind] or { x = 1.35, y = 1.35, z = 0.22 }
end

local function drawDistanceFor(kind)
    if kind == 'stash' then
        return Config.PdStashMarkerDrawDistance or 22.0
    end
    return Config.PdMarkerDrawDistance or 80.0
end

local function textDistanceFor(kind)
    if kind == 'stash' then
        return Config.PdMarkerTextDistance or 1.1
    end
    return USE_RADIUS[kind] or 1.5
end

exports('RegisterPdGroundMarker', RegisterPdGroundMarker)

local function clearPdMarkers()
    pdZones = {}
    markersReady = false
end

local function stationFeatureCoords(st, key)
    local feat = st[key]
    if type(feat) == 'table' and feat.coords then
        return vec3From(feat.coords)
    end
    if feat == true and st.coords then
        return vec3From(st.coords)
    end
    return nil
end

local function coordsNear(a, b, eps)
    if not a or not b then return false end
    return #(a - b) < (eps or 0.85)
end

local function openReceptionMenu()
    if GetResourceState('qb-menu') ~= 'started' then
        TriggerEvent('fivempro_ltpd:client:openMdtAtStation')
        return
    end
    exports['qb-menu']:openMenu({
        { header = 'PD registratūra', isMenuHeader = true },
        {
            header = 'MDT planšetė',
            txt = 'Atidaryti MDT',
            params = { event = 'fivempro_ltpd:client:openMdtAtStation' },
        },
        {
            header = 'Pamaina',
            txt = 'Pradėti arba baigti tarnybą',
            params = { event = 'fivempro_ltpd:client:toggleDuty' },
        },
        { header = 'Uždaryti', params = { event = 'qb-menu:client:closeMenu' } },
    })
end

local function registerAllPdMarkers()
    if Config.ShowPd3DMarkers == false then
        clearPdMarkers()
        return
    end

    clearPdMarkers()

    for _, st in ipairs(Config.Stations or {}) do
        local stationId = st.id
        local mdtPos = stationFeatureCoords(st, 'mdt')
        local dutyPos = stationFeatureCoords(st, 'duty')
        local mergedReception = mdtPos and dutyPos and coordsNear(mdtPos, dutyPos)

        if mergedReception then
            RegisterPdGroundMarker({
                coords = mdtPos,
                kind = 'duty',
                label = stationId == 'ls_main' and 'PD registratūra' or 'Registratūra (MDT / pamaina)',
                requireDuty = false,
                onPress = openReceptionMenu,
            })
        else
            if mdtPos then
                RegisterPdGroundMarker({
                    coords = mdtPos,
                    kind = 'mdt',
                    label = 'MDT planšetė',
                    onPress = function()
                        TriggerEvent('fivempro_ltpd:client:openMdtAtStation')
                    end,
                })
            end
            if dutyPos then
                RegisterPdGroundMarker({
                    coords = dutyPos,
                    kind = 'duty',
                    label = stationId == 'ls_main' and 'PD pamaina (registratūra)' or 'PD pamaina (pradėti / baigti)',
                    requireDuty = false,
                    onPress = function()
                        TriggerEvent('fivempro_ltpd:client:toggleDuty')
                    end,
                })
            end
        end

        if st.supply and st.supply.coords then
            RegisterPdGroundMarker({
                coords = st.supply.coords,
                kind = 'supply',
                label = st.supply.label or 'PD inventorius',
                onPress = function()
                    TriggerServerEvent('fivempro_npcshops:server:openJobSupply', jobName(), stationId)
                end,
            })
        end

        if st.garage and st.garage.coords then
            RegisterPdGroundMarker({
                coords = st.garage.coords,
                kind = 'garage',
                label = 'PD garažas / transportas',
                onPress = function()
                    TriggerEvent('fivempro_ltpd:client:markerGarage', stationId)
                end,
            })
        end

        if st.locker and st.locker.coords then
            RegisterPdGroundMarker({
                coords = st.locker.coords,
                kind = 'locker',
                label = st.locker.label or 'PD rūbinė',
                access = {
                    minGrade = st.locker.minGrade or 0,
                    divisions = st.locker.divisions,
                    excludeDivisions = st.locker.excludeDivisions,
                },
                onPress = function()
                    TriggerEvent('fivempro_ltpd:client:openDutyLockerMenu', { lockerMode = 'standard' })
                end,
            })
        end

        if st.locker2 and st.locker2.coords then
            RegisterPdGroundMarker({
                coords = st.locker2.coords,
                kind = 'locker',
                label = st.locker2.label or 'ARO rūbinė',
                access = {
                    minGrade = st.locker2.minGrade or 0,
                    divisions = st.locker2.divisions or { 'aro' },
                    excludeDivisions = st.locker2.excludeDivisions,
                },
                onPress = function()
                    TriggerEvent('fivempro_ltpd:client:openDutyLockerMenu', {
                        lockerMode = st.locker2.lockerMode or 'aro',
                    })
                end,
            })
        end

        if st.armory and st.armory.coords then
            RegisterPdGroundMarker({
                coords = st.armory.coords,
                kind = 'armory',
                label = st.armory.label or 'Ginklinė',
                access = {
                    minGrade = st.armory.minGrade or 0,
                    divisions = st.armory.divisions,
                    excludeDivisions = st.armory.excludeDivisions,
                },
                onPress = function()
                    TriggerEvent('fivempro_ltpd:client:tryOpenArmory', { stationId = stationId })
                end,
            })
        end

        for stashIdx, stash in ipairs(st.stashes or {}) do
            if stash.coords then
                local index = stashIdx
                RegisterPdGroundMarker({
                    coords = stash.coords,
                    kind = 'stash',
                    label = stash.label or ('Sandėlis #' .. tostring(stashIdx)),
                    access = {
                        minGrade = stash.minGrade or 0,
                        divisions = stash.divisions,
                        excludeDivisions = stash.excludeDivisions,
                    },
                    onPress = function()
                        TriggerEvent('fivempro_ltpd:client:tryOpenStash', { stationId = stationId, stashIndex = index })
                    end,
                })
            end
        end

        if st.heliGarage and st.heliGarage.coords then
            RegisterPdGroundMarker({
                coords = st.heliGarage.coords,
                kind = 'garage',
                label = 'PD sraigtasparniai (helipadas)',
                onPress = function()
                    TriggerEvent('fivempro_ltpd:client:openHeliGarageMenu', { stationId = stationId })
                end,
            })
        end

    end

    for _, st in ipairs((Config.PdWeaponCraft and Config.PdWeaponCraft.stations) or {}) do
        if st.coords then
            local craftKey = st.id
            RegisterPdGroundMarker({
                coords = st.coords,
                kind = 'craft',
                label = st.label or 'Policijos ginklų gamyba',
                requireDuty = true,
                access = {
                    minGrade = st.minGrade or 0,
                    divisions = st.divisions,
                },
                onPress = function()
                    TriggerEvent('fivempro_ltpd:client:openPdWeaponCraft', { stationKey = craftKey })
                end,
            })
        end
    end

    markersReady = true
    print(('[fivempro_ltpd] PD 3D markeriai: %d taškų'):format(#pdZones))
end

local function scheduleRegister()
    CreateThread(function()
        Wait(800)
        registerAllPdMarkers()
    end)
end

scheduleRegister()

AddEventHandler('onResourceStart', function(res)
    if res ~= GetCurrentResourceName() then return end
    scheduleRegister()
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    scheduleRegister()
end)

RegisterCommand('pdmarkers', function()
    local ped = PlayerPedId()
    local p = GetEntityCoords(ped)
    print(('[fivempro_ltpd] pdmarkers: registruota=%s skaicius=%d pozicija=%.1f,%.1f,%.1f'):format(
        tostring(markersReady), #pdZones, p.x, p.y, p.z))
    for i, z in ipairs(pdZones) do
        local d = #(p - z.coords)
        if d < 120.0 then
            print(('  #%d %s dist=%.1fm @ %.2f,%.2f,%.2f'):format(
                i, z.kind, d, z.coords.x, z.coords.y, z.coords.z))
        end
    end
end, false)

local function drawMarkerAt(pos, kind)
    local col = COLORS[kind] or COLORS.stash
    local sc = markerScaleFor(kind)
    local mType = markerTypeFor(kind)
    local zOff = 0.0
    if mType == 36 then
        zOff = 0.35
    elseif mType == 2 then
        zOff = 0.06
    end
    DrawMarker(
        mType,
        pos.x, pos.y, pos.z + zOff,
        0.0, 0.0, 0.0,
        0.0, 0.0, 0.0,
        sc.x, sc.y, sc.z,
        col[1], col[2], col[3], col[4],
        false, false, 2, mType == 36, nil, nil, false
    )
end

CreateThread(function()
    while true do
        local sleep = 500
        if Config.ShowPd3DMarkers ~= false and #pdZones > 0 and not IsPauseMenuActive() then
            local ped = PlayerPedId()
            local pcoords = GetEntityCoords(ped)
            for _, zone in ipairs(pdZones) do
                if not markerVisible(zone) then
                    goto continue_zone
                end
                local dist = #(pcoords - zone.coords)
                local drawDist = drawDistanceFor(zone.kind)
                if dist < drawDist then
                    sleep = 0
                    drawMarkerAt(zone.coords, zone.kind)
                    local useR = USE_RADIUS[zone.kind] or 1.5
                    local textR = textDistanceFor(zone.kind)
                    if dist < useR then
                        local canUse = true
                        if zone.requireDuty and not isPdOnDuty() then
                            canUse = false
                        end
                        if canUse and dist < textR then
                            QBCore.Functions.DrawText3D(
                                zone.coords.x, zone.coords.y, zone.coords.z + 0.55,
                                ('[E] %s'):format(zone.label)
                            )
                            if IsControlJustPressed(0, 38) and (GetGameTimer() - lastInteractMs) > 450 then
                                lastInteractMs = GetGameTimer()
                                if zone.onPress then zone.onPress() end
                            end
                        elseif zone.requireDuty and dist < textR then
                            QBCore.Functions.DrawText3D(
                                zone.coords.x, zone.coords.y, zone.coords.z + 0.55,
                                'Tik tarnyboje (policija)'
                            )
                        end
                    end
                end
                ::continue_zone::
            end
        end
        Wait(sleep)
    end
end)
