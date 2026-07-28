--- PD 3D markeriai ant žemės — registruojami iš Config.Stations (mrp_ltpd/config.lua).
--- Interakcijos: duty/garage/locker/craft [E] · stash/supply [F2] (be pilko DrawText3D)
--- Komanda debug: /pdmarkers
local QBCore = exports['qb-core']:GetCoreObject()

local pdZones = {}
local lastInteractMs = 0
local markersReady = false
local forceAccessRefresh = false

local COLORS = {
    garage = { 72, 160, 220, 200 },
    stash = { 255, 180, 72, 200 },
    locker = { 167, 139, 250, 210 },
    armory = { 34, 197, 94, 200 }, --- žalias — ARAS ginklų pirkimas
    supply = { 34, 197, 94, 200 },
    craft = { 251, 191, 36, 210 },
    duty = { 250, 204, 21, 200 },
}

local SCALES = {
    garage = { x = 2.6, y = 2.6, z = 0.28 },
    stash = nil, -- naudoja Config.PdStashMarkerScale
    locker = nil, -- Config.PdLockerMarkerScale
    armory = nil, -- Config.PdSupplyMarkerScale (žalias trikampis)
    supply = nil, -- Config.PdSupplyMarkerScale
    craft = { x = 1.55, y = 1.55, z = 0.24 },
    duty = { x = 1.5, y = 1.5, z = 0.24 },
}

local MARKER_TYPES = {
    garage = 36,
    stash = nil, -- naudoja Config.PdStashMarkerType
    locker = nil, -- Config.PdLockerMarkerType
    armory = nil, -- Config.PdSupplyMarkerType
    supply = nil, -- Config.PdSupplyMarkerType
    craft = 27,
    duty = 27,
}

local USE_RADIUS = {
    garage = 2.6,
    stash = 2.2,
    locker = 2.0,
    armory = 2.0,
    supply = 2.5,
    craft = 2.0,
    duty = 2.0,
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

local function markerVisible(zone, accessCache, zoneIndex)
    if accessCache[zoneIndex] ~= nil then
        return accessCache[zoneIndex]
    end
    if zone.access then
        return exports['mrp_ltpd']:CanAccessPdPoint(zone.access)
    end
    return true
end

local function markerTypeFor(kind)
    if kind == 'stash' then
        return Config.PdStashMarkerType or Config.PdTriangleMarkerType or 2
    end
    if kind == 'locker' then
        return Config.PdLockerMarkerType or Config.PdTriangleMarkerType or 21
    end
    if kind == 'supply' or kind == 'armory' then
        return Config.PdSupplyMarkerType or Config.PdTriangleMarkerType or 21
    end
    return MARKER_TYPES[kind] or 27
end

local function markerScaleFor(kind)
    if kind == 'stash' then
        return Config.PdStashMarkerScale or Config.PdTriangleMarkerScale or { x = 0.34, y = 0.34, z = 0.34 }
    end
    if kind == 'locker' then
        return Config.PdLockerMarkerScale or Config.PdTriangleMarkerScale or { x = 0.32, y = 0.32, z = 0.32 }
    end
    if kind == 'supply' or kind == 'armory' then
        return Config.PdSupplyMarkerScale or Config.PdTriangleMarkerScale or { x = 0.32, y = 0.32, z = 0.32 }
    end
    return SCALES[kind] or { x = 1.35, y = 1.35, z = 0.22 }
end

local function drawDistanceFor(kind)
    if kind == 'stash' then
        return Config.PdStashMarkerDrawDistance or 22.0
    end
    return Config.PdMarkerDrawDistance or 32.0
end

local function textDistanceFor(kind)
    return USE_RADIUS[kind] or Config.PdMarkerTextDistance or 2.2
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

local function registerAllPdMarkers()
    if Config.ShowPd3DMarkers == false then
        clearPdMarkers()
        return
    end

    clearPdMarkers()

    for _, st in ipairs(Config.Stations or {}) do
        local stationId = st.id
        local dutyPos = stationFeatureCoords(st, 'duty')

        if dutyPos then
            RegisterPdGroundMarker({
                coords = dutyPos,
                kind = 'duty',
                label = 'PD pamaina (pradėti / baigti)',
                requireDuty = false,
                onPress = function()
                    TriggerEvent('mrp_ltpd:client:toggleDuty')
                end,
            })
        end

        if st.supply and st.supply.coords then
            RegisterPdGroundMarker({
                coords = st.supply.coords,
                kind = 'supply',
                label = st.supply.label or 'PD inventorius',
                onPress = function()
                    TriggerServerEvent('mrp_npcshops:server:openJobSupply', jobName(), stationId)
                end,
            })
        end

        if st.garage and st.garage.coords then
            RegisterPdGroundMarker({
                coords = st.garage.coords,
                kind = 'garage',
                label = 'PD garažas / salonas',
                onPress = function()
                    TriggerEvent('mrp_ltpd:client:markerGarage', stationId)
                end,
            })
        end

        local function registerLockerMarker(lockerDef)
            if not lockerDef or not lockerDef.coords then return end
            RegisterPdGroundMarker({
                coords = lockerDef.coords,
                kind = 'locker',
                label = lockerDef.label or 'PD rūbinė',
                access = {
                    minGrade = lockerDef.minGrade or 0,
                    divisions = lockerDef.divisions,
                    excludeDivisions = lockerDef.excludeDivisions,
                    allowBossBypass = lockerDef.allowBossBypass,
                },
                onPress = function()
                    TriggerEvent('mrp_ltpd:client:openDutyLockerMenu', {
                        lockerMode = lockerDef.lockerMode or 'standard',
                        anchor = lockerDef.coords,
                    })
                end,
            })
        end

        for _, lockerDef in ipairs(st.lockers or {}) do
            registerLockerMarker(lockerDef)
        end

        if st.locker and st.locker.coords then
            registerLockerMarker(st.locker)
        end

        if st.locker2 and st.locker2.coords then
            registerLockerMarker({
                coords = st.locker2.coords,
                label = st.locker2.label or 'ARO rūbinė',
                minGrade = st.locker2.minGrade,
                divisions = st.locker2.divisions or { 'aras' },
                excludeDivisions = st.locker2.excludeDivisions,
                allowBossBypass = st.locker2.allowBossBypass,
                lockerMode = st.locker2.lockerMode or 'aro',
            })
        end

        --- Armory: ARAS ginklų pirkimas (openSupply) arba stash (jei stashId)
        if st.armory and st.armory.coords then
            local arm = st.armory
            RegisterPdGroundMarker({
                coords = arm.coords,
                kind = 'armory',
                label = arm.label or 'Ginklinė',
                access = {
                    minGrade = arm.minGrade or 0,
                    divisions = arm.divisions,
                    excludeDivisions = arm.excludeDivisions,
                    allowBossBypass = arm.allowBossBypass,
                },
                onPress = function()
                    if arm.openSupply or not arm.stashId then
                        TriggerServerEvent('mrp_npcshops:server:openJobSupply', jobName(), stationId)
                    else
                        TriggerEvent('mrp_ltpd:client:tryOpenArmory', { stationId = stationId })
                    end
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
                        allowBossBypass = stash.allowBossBypass,
                    },
                    onPress = function()
                        TriggerEvent('mrp_ltpd:client:tryOpenStash', { stationId = stationId, stashIndex = index })
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
                    TriggerEvent('mrp_ltpd:client:openHeliGarageMenu', { stationId = stationId })
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
                    TriggerEvent('mrp_ltpd:client:openPdWeaponCraft', { stationKey = craftKey })
                end,
            })
        end
    end

    markersReady = true
    print(('[mrp_ltpd] PD 3D markeriai: %d taškų'):format(#pdZones))
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

RegisterNetEvent('QBCore:Client:OnJobUpdate', function()
    forceAccessRefresh = true
end)

RegisterNetEvent('mrp_ltpd:client:syncDivision', function()
    forceAccessRefresh = true
end)

RegisterCommand('pdmarkers', function()
    local ped = PlayerPedId()
    local p = GetEntityCoords(ped)
    print(('[mrp_ltpd] pdmarkers: registruota=%s skaicius=%d pozicija=%.1f,%.1f,%.1f'):format(
        tostring(markersReady), #pdZones, p.x, p.y, p.z))
    for i, z in ipairs(pdZones) do
        local d = #(p - z.coords)
        if d < 120.0 then
            print(('  #%d %s dist=%.1fm @ %.2f,%.2f,%.2f'):format(
                i, z.kind, d, z.coords.x, z.coords.y, z.coords.z))
        end
    end
end, false)

--- Sandėliai + inventorius (supply/armory) — F2 = control 289 (mrp_npcshops)
local function isF2InventoryKind(kind)
    return kind == 'stash' or kind == 'supply' or kind == 'armory'
end

local function isStashOpenPressed()
    if GetResourceState('mrp_npcshops') == 'started' then
        return exports['mrp_npcshops']:IsStashOpenPressed()
    end
    EnableControlAction(0, 289, true)
    return IsControlJustPressed(0, 289) or IsDisabledControlJustPressed(0, 289)
end

local function enableStashOpenControl()
    if GetResourceState('mrp_npcshops') == 'started' then
        exports['mrp_npcshops']:EnableStashOpenControl()
    else
        EnableControlAction(0, 289, true)
    end
end

local function drawMarkerAt(pos, kind)
    local col = COLORS[kind] or COLORS.stash
    local sc = markerScaleFor(kind)
    local mType = markerTypeFor(kind)
    local zOff = 0.0
    if mType == 36 then
        zOff = 0.35
    elseif mType == 2 or mType == 21 then
        zOff = 0.06
    end
    DrawMarker(
        mType,
        pos.x, pos.y, pos.z + zOff,
        0.0, 0.0, 0.0,
        0.0, 0.0, 0.0,
        sc.x, sc.y, sc.z,
        col[1], col[2], col[3], col[4],
        false, false, 2, false, nil, nil, false
    )
end

CreateThread(function()
    local accessCache = {}
    local lastAccessRefresh = 0

    local function refreshAccessCache()
        local now = GetGameTimer()
        if not forceAccessRefresh and now - lastAccessRefresh < 2500 then return end
        forceAccessRefresh = false
        lastAccessRefresh = now
        accessCache = {}
        if not isPdJob() then return end
        for i, zone in ipairs(pdZones) do
            accessCache[i] = markerVisible(zone, accessCache, i)
        end
    end

    while true do
        local sleep = 1500

        if Config.ShowPd3DMarkers == false or #pdZones == 0 or IsPauseMenuActive() then
            Wait(sleep)
            goto continue
        end

        if not isPdJob() then
            Wait(sleep)
            goto continue
        end

        refreshAccessCache()

        local ped = PlayerPedId()
        local pcoords = GetEntityCoords(ped)
        local nearInteract = false
        local anyDrawn = false
        local maxDrawDist = Config.PdMarkerDrawDistance or 32.0
        local closestInteract = nil
        local closestInteractDist = nil

        if IsNuiFocused() then
            Wait(400)
            goto continue
        end

        for i, zone in ipairs(pdZones) do
            if accessCache[i] == false then
                goto continue_zone
            end

            local dist = #(pcoords - zone.coords)
            local drawDist = zone.kind == 'stash' and (Config.PdStashMarkerDrawDistance or 22.0) or maxDrawDist
            if dist >= drawDist then
                goto continue_zone
            end

            anyDrawn = true
            drawMarkerAt(zone.coords, zone.kind)

            local useR = USE_RADIUS[zone.kind] or 2.0
            local textR = textDistanceFor(zone.kind)
            if dist < useR then
                local canUse = not zone.requireDuty or isPdOnDuty()
                if canUse and dist < textR then
                    if not closestInteractDist or dist < closestInteractDist then
                        closestInteractDist = dist
                        closestInteract = zone
                    end
                elseif zone.requireDuty and dist < textR then
                    if not closestInteractDist or dist < closestInteractDist then
                        closestInteractDist = dist
                        closestInteract = { coords = zone.coords, kind = zone.kind, requireDutyBlock = true }
                    end
                end
            end

            ::continue_zone::
        end

        if closestInteract and closestInteract.onPress then
            nearInteract = true
            local zone = closestInteract
            if zone.requireDutyBlock then
                QBCore.Functions.DrawText3D(
                    zone.coords.x, zone.coords.y, zone.coords.z + 0.55,
                    'Tik tarnyboje (policija)'
                )
            else
                local pressed
                if isF2InventoryKind(zone.kind) then
                    --- Sandėliai / inventorius: F2, be pilko floating teksto
                    enableStashOpenControl()
                    pressed = isStashOpenPressed()
                else
                    EnableControlAction(0, 38, true)
                    QBCore.Functions.DrawText3D(
                        zone.coords.x, zone.coords.y, zone.coords.z + 0.55,
                        ('[E] %s'):format(zone.label)
                    )
                    pressed = IsControlJustPressed(0, 38)
                end
                if pressed and (GetGameTimer() - lastInteractMs) > 450 then
                    lastInteractMs = GetGameTimer()
                    if zone.onPress then zone.onPress() end
                end
            end
        end

        if nearInteract or anyDrawn then
            sleep = 0
        else
            sleep = 800
        end

        Wait(sleep)
        ::continue::
    end
end)
