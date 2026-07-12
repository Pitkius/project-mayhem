--- 3D markeriai ant žemės — job garažai ir sandėliai (vietoj NPC / qb-target)
local QBCore = exports['qb-core']:GetCoreObject()

local zonesByJob = {}
local activeZones = {}
local activeJob = nil
local lastInteractMs = 0

local COLORS = {
    garage = { 72, 160, 220, 115 },
    stash = { 255, 180, 72, 140 },
    locker = { 167, 139, 250, 150 },
    armory = { 239, 68, 68, 150 },
    supply = { 34, 197, 94, 140 },
    mdt = { 96, 165, 250, 150 },
    duty = { 250, 204, 21, 150 },
}

local DEFAULT_MARKER_TYPES = {
    garage = 27,
    stash = 2,
    locker = 2,
    armory = 2,
    supply = 2,
    mdt = 2,
    duty = 2,
}

-- PD supply/duty markeriai piešiami mrp_ltpd/pd_markers.lua — čia juos praleidžiam,
-- kad nebūtų dvigubų piešimų ir z-fighting.
local PD_MARKER_SKIP = { police = { supply = true, duty = true } }

local function isMarkerRole(role)
    return role == 'garage' or role == 'stash' or role == 'locker' or role == 'supply'
end

local function isSkippedForJob(job, role)
    return PD_MARKER_SKIP[job] and PD_MARKER_SKIP[job][role]
end

local function markerTypeFor(kind)
    local cfg = Config.JobMarkerTypes
    if cfg and cfg[kind] then return cfg[kind] end
    return DEFAULT_MARKER_TYPES[kind] or 27
end

local function drawJobMarker(pos, kind, scale)
    local c = COLORS[kind] or COLORS.stash
    local sc = scale or Config.JobMarkerScale or { x = 2.4, y = 2.4, z = 0.24 }
    local mType = markerTypeFor(kind)
    local isCarSymbol = mType == 36
    local zOff = isCarSymbol and 0.35 or (mType == 27 and 0.02 or 0.06)
    DrawMarker(
        mType,
        pos.x, pos.y, pos.z + zOff,
        0.0, 0.0, 0.0,
        0.0, 0.0, 0.0,
        sc.x, sc.y, sc.z,
        c[1], c[2], c[3], c[4],
        false, false, 2, isCarSymbol, nil, nil, false
    )
end

local function useRadiusFor(kind)
    if kind == 'stash' or kind == 'mdt' or kind == 'supply' then
        return Config.JobMarkerStashUseRadius or 1.35
    end
    if kind == 'locker' or kind == 'armory' or kind == 'duty' then
        return Config.JobMarkerLockerUseRadius or 1.6
    end
    return Config.JobMarkerUseRadius or 2.2
end

local function refreshActiveJobZones()
    local P = QBCore.Functions.GetPlayerData()
    local jobName = P and P.job and P.job.name or nil
    if jobName == activeJob then return end
    activeJob = jobName
    activeZones = (jobName and zonesByJob[jobName]) or {}
end

local function registerZone(data)
    if not data or not data.coords then return end
    local c = data.coords
    local zone = {
        coords = vector3(c.x + 0.0, c.y + 0.0, c.z + 0.0),
        kind = data.kind or 'stash',
        label = data.label or 'Tarnyba',
        scale = data.scale,
        job = data.job,
        visible = data.visible,
        onPress = data.onPress,
        canUse = data.canUse,
    }

    if data.job then
        zonesByJob[data.job] = zonesByJob[data.job] or {}
        zonesByJob[data.job][#zonesByJob[data.job] + 1] = zone
    end

    if activeJob and data.job == activeJob then
        activeZones[#activeZones + 1] = zone
    end
end

exports('AddJobGroundMarker', registerZone)

for _, entry in ipairs(Config.JobStationNpcs or {}) do
    if isMarkerRole(entry.role) and entry.coords and not isSkippedForJob(entry.job, entry.role) then
        local captured = {
            job = entry.job,
            stationId = entry.stationId,
            role = entry.role,
        }
        registerZone({
            coords = entry.coords,
            kind = entry.role,
            job = entry.job,
            label = entry.label,
            scale = entry.role == 'garage' and (Config.JobMarkerGarageScale or Config.JobMarkerScale)
                or entry.role == 'locker' and (Config.JobMarkerLockerScale or Config.JobMarkerScale)
                or Config.JobMarkerStashScale,
            onPress = function()
                TriggerServerEvent('mrp_npcshops:server:validateJobNpc', captured.job, captured.stationId, captured.role)
            end,
        })
    end
end

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    refreshActiveJobZones()
end)

RegisterNetEvent('QBCore:Client:OnJobUpdate', function()
    refreshActiveJobZones()
end)

CreateThread(function()
    Wait(800)
    refreshActiveJobZones()

    local drawD = Config.JobMarkerDrawDistance or 22.0
    local farSleep = 1200
    local drawSleep = 0

    while true do
        if #activeZones == 0 then
            Wait(farSleep)
            goto continue
        end

        if IsNuiFocused() then
            Wait(400)
            goto continue
        end

        local pcoords = GetEntityCoords(PlayerPedId())
        local nearestDist = math.huge
        local interactZone = nil
        local interactDist = math.huge
        local drawCount = 0

        for i = 1, #activeZones do
            local zone = activeZones[i]
            if zone.visible and not zone.visible() then
                goto next_zone
            end

            local dist = #(pcoords - zone.coords)
            if dist < nearestDist then nearestDist = dist end

            if dist < drawD then
                drawCount = drawCount + 1
                drawJobMarker(zone.coords, zone.kind, zone.scale)

                local useR = useRadiusFor(zone.kind)
                if dist < useR and dist < interactDist then
                    local canUse = true
                    if zone.canUse then canUse = zone.canUse() end
                    if canUse then
                        interactZone = zone
                        interactDist = dist
                    end
                end
            end

            ::next_zone::
        end

        if nearestDist > drawD then
            Wait(farSleep)
            goto continue
        end

        if interactZone then
            local hint
            if interactZone.kind == 'stash' then
                hint = exports['mrp_npcshops']:StashInteractHint(interactZone.label)
                exports['mrp_npcshops']:EnableStashOpenControl()
            else
                EnableControlAction(0, 38, true)
                hint = ('[E] %s'):format(interactZone.label)
            end
            local hintZ = interactZone.kind == 'stash' and 0.55 or 0.75
            QBCore.Functions.DrawText3D(
                interactZone.coords.x,
                interactZone.coords.y,
                interactZone.coords.z + hintZ,
                hint
            )
            local pressed = interactZone.kind == 'stash'
                and exports['mrp_npcshops']:IsStashOpenPressed()
                or IsControlJustPressed(0, 38)
            if pressed and (GetGameTimer() - lastInteractMs) > 450 then
                lastInteractMs = GetGameTimer()
                if interactZone.onPress then interactZone.onPress() end
            end
            Wait(0)
        else
            Wait(drawCount > 0 and drawSleep or farSleep)
        end

        ::continue::
    end
end)
