--- Ūkio turgelis — 3D žymekliai ant žemės (kartu su žemėlapio blipais ir NPC)
local QBCore = exports['qb-core']:GetCoreObject()

local zones = {}
local lastInteractMs = 0

local function markerCfg()
    return Config.JunkShopMarker or {}
end

local function drawJunkMarker(pos)
    local cfg = markerCfg()
    local c = cfg.color or { 184, 134, 72, 135 }
    local sc = cfg.scale or { x = 1.15, y = 1.15, z = 0.32 }
    local zOff = cfg.zOffset or 0.02
    DrawMarker(
        cfg.type or 27,
        pos.x, pos.y, pos.z + zOff,
        0.0, 0.0, 0.0,
        0.0, 0.0, 0.0,
        sc.x, sc.y, sc.z,
        c[1], c[2], c[3], c[4],
        false, false, 2, false, nil, nil, false
    )
end

for i, row in ipairs(Config.JunkShopPeds or {}) do
    if row.coords then
        local c = row.coords
        zones[#zones + 1] = {
            coords = vector3(c.x + 0.0, c.y + 0.0, c.z + 0.0),
            label = 'Ūkio turgelis',
            index = i,
        }
    end
end

CreateThread(function()
    local cfg = markerCfg()
    local drawD = cfg.drawDistance or 32.0
    local useR = cfg.useRadius or 2.4

    while true do
        local sleep = 500
        local ped = PlayerPedId()
        local pcoords = GetEntityCoords(ped)

        if not IsNuiFocused() then
            for _, zone in ipairs(zones) do
                local dist = #(pcoords - zone.coords)
                if dist < drawD then
                    sleep = 0
                    drawJunkMarker(zone.coords)
                    if dist < useR then
                        EnableControlAction(0, 38, true)
                        QBCore.Functions.DrawText3D(
                            zone.coords.x,
                            zone.coords.y,
                            zone.coords.z + 0.72,
                            ('[E] %s'):format(zone.label)
                        )
                        if IsControlJustPressed(0, 38) and (GetGameTimer() - lastInteractMs) > 450 then
                            lastInteractMs = GetGameTimer()
                            TriggerServerEvent('fivempro_npcshops:server:openJunkShop')
                        end
                    end
                end
            end
        end

        Wait(sleep)
    end
end)
