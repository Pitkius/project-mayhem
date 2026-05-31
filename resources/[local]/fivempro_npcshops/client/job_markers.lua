--- 3D markeriai ant žemės — job garažai ir sandėliai (vietoj NPC / qb-target)
local QBCore = exports['qb-core']:GetCoreObject()

local zones = {}
local lastInteractMs = 0

local COLORS = {
    garage = { 72, 160, 220, 115 },
    stash = { 255, 180, 72, 115 },
}

local function isMarkerRole(role)
    return role == 'garage' or role == 'stash'
end

local function drawFlatMarker(pos, kind, scale)
    local c = COLORS[kind] or COLORS.stash
    local sc = scale or Config.JobMarkerScale or { x = 2.4, y = 2.4, z = 0.24 }
    DrawMarker(
        27,
        pos.x, pos.y, pos.z + 0.02,
        0.0, 0.0, 0.0,
        0.0, 0.0, 0.0,
        sc.x, sc.y, sc.z,
        c[1], c[2], c[3], c[4],
        false, false, 2, false, nil, nil, false
    )
end

local function registerZone(data)
    if not data or not data.coords then return end
    local c = data.coords
    zones[#zones + 1] = {
        coords = vector3(c.x + 0.0, c.y + 0.0, c.z + 0.0),
        kind = data.kind or 'stash',
        label = data.label or 'Tarnyba',
        scale = data.scale,
        onPress = data.onPress,
        canUse = data.canUse,
    }
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
            label = entry.label,
            scale = entry.role == 'garage' and (Config.JobMarkerGarageScale or Config.JobMarkerScale) or Config.JobMarkerStashScale,
            onPress = function()
                TriggerServerEvent('fivempro_npcshops:server:validateJobNpc', captured.job, captured.stationId, captured.role)
            end,
        })
    end
end

CreateThread(function()
    local drawD = Config.JobMarkerDrawDistance or 28.0
    local useR = Config.JobMarkerUseRadius or 2.2

    while true do
        local sleep = 500
        local ped = PlayerPedId()
        local pcoords = GetEntityCoords(ped)

        if not IsNuiFocused() then
            for _, zone in ipairs(zones) do
                local dist = #(pcoords - zone.coords)
                if dist < drawD then
                    sleep = 0
                    drawFlatMarker(zone.coords, zone.kind, zone.scale)
                    if dist < useR then
                        local canUse = true
                        if zone.canUse then
                            canUse = zone.canUse()
                        end
                        if canUse then
                            EnableControlAction(0, 38, true)
                            QBCore.Functions.DrawText3D(zone.coords.x, zone.coords.y, zone.coords.z + 0.85, ('[E] %s'):format(zone.label))
                            if IsControlJustPressed(0, 38) and (GetGameTimer() - lastInteractMs) > 450 then
                                lastInteractMs = GetGameTimer()
                                if zone.onPress then zone.onPress() end
                            end
                        end
                    end
                end
            end
        end

        Wait(sleep)
    end
end)
