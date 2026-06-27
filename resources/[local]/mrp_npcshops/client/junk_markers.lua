--- Ūkio turgelis — 3D žymekliai ant žemės (be NPC, tik blip + [E])
local QBCore = exports['qb-core']:GetCoreObject()

local zones = {}
local spawnedBlips = {}
local lastInteractMs = 0

local function markerCfg()
    return Config.JunkShopMarker or {}
end

local function createBlip(coords)
    local blipCfg = Config.JunkShopBlip
    if not blipCfg or not coords then return end
    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(blip, blipCfg.sprite or 566)
    SetBlipDisplay(blip, 4)
    SetBlipScale(blip, blipCfg.scale or 0.82)
    SetBlipColour(blip, blipCfg.color or 17)
    SetBlipAsShortRange(blip, true)
    local label = blipCfg.label or 'Ūkio turgelis'
    if GetResourceState('mrp_fonts') == 'started' then
        pcall(function()
            exports['mrp_fonts']:SetBlipName(blip, label)
        end)
    else
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName(label)
        EndTextCommandSetBlipName(blip)
    end
    spawnedBlips[#spawnedBlips + 1] = blip
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

for i, row in ipairs(Config.JunkShopLocations or {}) do
    if row then
        local c = row
        zones[#zones + 1] = {
            coords = vector3(c.x + 0.0, c.y + 0.0, c.z + 0.0),
            label = 'Ūkio turgelis',
            index = i,
        }
        createBlip(c)
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
                            TriggerServerEvent('mrp_npcshops:server:openJunkShop')
                        end
                    end
                end
            end
        end

        Wait(sleep)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for i = 1, #spawnedBlips do
        if DoesBlipExist(spawnedBlips[i]) then
            RemoveBlip(spawnedBlips[i])
        end
    end
end)
