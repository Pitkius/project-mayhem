--- PD 3D markeriai — nepriklausomas nuo fivempro_npcshops export
local QBCore = exports['qb-core']:GetCoreObject()

local pdZones = {}
local lastInteractMs = 0

local COLORS = {
    garage = { 72, 160, 220, 140 },
    stash = { 255, 180, 72, 160 },
    locker = { 167, 139, 250, 170 },
    armory = { 239, 68, 68, 170 },
    supply = { 34, 197, 94, 160 },
    mdt = { 96, 165, 250, 170 },
    duty = { 250, 204, 21, 160 },
}

local SCALES = {
    garage = { x = 1.4, y = 1.4, z = 1.4 },
    stash = { x = 0.85, y = 0.85, z = 0.85 },
    locker = { x = 0.95, y = 0.95, z = 0.95 },
    armory = { x = 0.95, y = 0.95, z = 0.95 },
    supply = { x = 0.85, y = 0.85, z = 0.85 },
    mdt = { x = 0.9, y = 0.9, z = 0.9 },
    duty = { x = 0.95, y = 0.95, z = 0.95 },
}

local MARKER_TYPES = {
    garage = 36,
    stash = 2,
    locker = 2,
    armory = 2,
    supply = 2,
    mdt = 2,
    duty = 2,
}

local function isPdOnDuty()
    local P = QBCore.Functions.GetPlayerData()
    return P and P.job and P.job.name == 'police' and P.job.onduty
end

local function isPdJob()
    local P = QBCore.Functions.GetPlayerData()
    return P and P.job and P.job.name == 'police'
end

function RegisterPdGroundMarker(data)
    if not data or not data.coords then return end
    local c = data.coords
    pdZones[#pdZones + 1] = {
        coords = vector3(c.x, c.y, c.z),
        kind = data.kind or 'stash',
        label = data.label or 'PD',
        onPress = data.onPress,
        requireDuty = data.requireDuty ~= false,
    }
end

exports('RegisterPdGroundMarker', RegisterPdGroundMarker)

local function drawMarkerAt(pos, kind)
    local col = COLORS[kind] or COLORS.stash
    local sc = SCALES[kind] or SCALES.stash
    local mType = MARKER_TYPES[kind] or 2
    local zOff = mType == 36 and 0.35 or 0.05
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
    local drawDist = 55.0
    while true do
        local sleep = 500
        local ped = PlayerPedId()
        local pcoords = GetEntityCoords(ped)
        if not IsNuiFocused() then
            for _, zone in ipairs(pdZones) do
                local dist = #(pcoords - zone.coords)
                if dist < drawDist then
                    sleep = 0
                    drawMarkerAt(zone.coords, zone.kind)
                    if dist < 2.0 then
                        local canUse = true
                        if zone.requireDuty and not isPdOnDuty() then
                            canUse = false
                        end
                        if canUse then
                            QBCore.Functions.DrawText3D(zone.coords.x, zone.coords.y, zone.coords.z + 0.85, ('[E] %s'):format(zone.label))
                            if IsControlJustPressed(0, 38) and (GetGameTimer() - lastInteractMs) > 450 then
                                lastInteractMs = GetGameTimer()
                                if zone.onPress then zone.onPress() end
                            end
                        elseif zone.requireDuty then
                            QBCore.Functions.DrawText3D(zone.coords.x, zone.coords.y, zone.coords.z + 0.85, 'Tik tarnyboje')
                        end
                    end
                end
            end
        end
        Wait(sleep)
    end
end)
