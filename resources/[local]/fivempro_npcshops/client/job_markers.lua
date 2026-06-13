--- 3D markeriai ant žemės — job garažai ir sandėliai (vietoj NPC / qb-target)
local QBCore = exports['qb-core']:GetCoreObject()

local zones = {}
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

local function isMarkerRole(role)
    return role == 'garage' or role == 'stash' or role == 'locker' or role == 'supply'
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

local function registerZone(data)
    if not data or not data.coords then return end
    local c = data.coords
    zones[#zones + 1] = {
        coords = vector3(c.x + 0.0, c.y + 0.0, c.z + 0.0),
        kind = data.kind or 'stash',
        label = data.label or 'Tarnyba',
        scale = data.scale,
        job = data.job,
        visible = data.visible,
        onPress = data.onPress,
        canUse = data.canUse,
    }
end

local function playerHasJob(jobName)
    if not jobName or jobName == '' then return false end
    local P = QBCore.Functions.GetPlayerData()
    return P and P.job and P.job.name == jobName
end

local function zoneVisible(zone)
    if zone.visible then
        return zone.visible()
    end
    if zone.job then
        return playerHasJob(zone.job)
    end
    return false
end

exports('AddJobGroundMarker', registerZone)

for _, entry in ipairs(Config.JobStationNpcs or {}) do
    if isMarkerRole(entry.role) and entry.coords then
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
                TriggerServerEvent('fivempro_npcshops:server:validateJobNpc', captured.job, captured.stationId, captured.role)
            end,
        })
    end
end

CreateThread(function()
    local drawD = Config.JobMarkerDrawDistance or 28.0
    while true do
        local sleep = 500
        local ped = PlayerPedId()
        local pcoords = GetEntityCoords(ped)

        if not IsNuiFocused() then
            for _, zone in ipairs(zones) do
                if not zoneVisible(zone) then
                    goto continue_zone
                end
                local dist = #(pcoords - zone.coords)
                local useR = useRadiusFor(zone.kind)
                if dist < drawD then
                    sleep = 0
                    drawJobMarker(zone.coords, zone.kind, zone.scale)
                    if dist < useR then
                        local canUse = true
                        if zone.canUse then
                            canUse = zone.canUse()
                        end
                        if canUse then
                            EnableControlAction(0, 38, true)
                            local hintZ = zone.kind == 'stash' and 0.55 or 0.75
                            QBCore.Functions.DrawText3D(zone.coords.x, zone.coords.y, zone.coords.z + hintZ, ('[E] %s'):format(zone.label))
                            if IsControlJustPressed(0, 38) and (GetGameTimer() - lastInteractMs) > 450 then
                                lastInteractMs = GetGameTimer()
                                if zone.onPress then zone.onPress() end
                            end
                        end
                    end
                end
                ::continue_zone::
            end
        end

        Wait(sleep)
    end
end)
