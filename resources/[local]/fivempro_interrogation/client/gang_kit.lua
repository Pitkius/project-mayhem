local QBCore = exports['qb-core']:GetCoreObject()

local KitProps = {} -- [id] = { box, chair }
local placing = false

local function notify(msg, typ)
    QBCore.Functions.Notify(msg, typ or 'primary')
end

local function loadModel(model)
    local hash = type(model) == 'number' and model or joaat(model)
    if not IsModelInCdimage(hash) then return false end
    RequestModel(hash)
    local t = 0
    while not HasModelLoaded(hash) and t < 5000 do
        Wait(10)
        t = t + 10
    end
    return HasModelLoaded(hash)
end

local function deleteKitProps(id)
    local ent = KitProps[id]
    if not ent then return end
    for _, obj in pairs(ent) do
        if obj and DoesEntityExist(obj) then
            DeleteEntity(obj)
        end
    end
    KitProps[id] = nil
end

local function spawnKitProps(kit)
    if not kit or not kit.id then return end
    deleteKitProps(kit.id)
    local cfg = Config.GangKit or {}
    local boxM = cfg.propModel or 'prop_tool_box_05'
    local chairM = cfg.chairModel or 'prop_chair_08'
    if not loadModel(boxM) or not loadModel(chairM) then return end

    local h = kit.heading or 0.0
    local box = CreateObject(joaat(boxM), kit.x, kit.y, kit.z, false, false, false)
    SetEntityHeading(box, h)
    PlaceObjectOnGroundProperly(box)
    FreezeEntityPosition(box, true)

    local off = cfg.suspectSeatOffset or vector4(0, -0.9, -0.45, 0)
    local rad = math.rad(h)
    local cos, sin = math.cos(rad), math.sin(rad)
    local cx = kit.x + off.x * cos - off.y * sin
    local cy = kit.y + off.x * sin + off.y * cos
    local cz = kit.z + off.z
    local chair = CreateObject(joaat(chairM), cx, cy, cz, false, false, false)
    SetEntityHeading(chair, h + (off.w or 0))
    PlaceObjectOnGroundProperly(chair)
    FreezeEntityPosition(chair, true)

    KitProps[kit.id] = { box = box, chair = chair, kit = kit }
    SetModelAsNoLongerNeeded(joaat(boxM))
    SetModelAsNoLongerNeeded(joaat(chairM))
end

local function refreshKitTargets()
    for id, data in pairs(KitProps) do
        local box = data.box
        if box and DoesEntityExist(box) then
            exports['qb-target']:RemoveTargetEntity(box)
            exports['qb-target']:AddTargetEntity(box, {
                options = {
                    {
                        icon = 'fas fa-skull',
                        label = 'Pradėti RP spaudimą',
                        action = function()
                            TriggerEvent('fivempro_interrogation:client:startPickSuspect', {
                                locationKind = 'kit',
                                locationId = tostring(id),
                                mode = 'criminal',
                            })
                        end,
                    },
                    {
                        icon = 'fas fa-box',
                        label = 'Surinkti įrangą',
                        action = function()
                            TriggerServerEvent('fivempro_interrogation:server:pickupKit', id)
                        end,
                    },
                },
                distance = 2.4,
            })
        end
    end
end

RegisterNetEvent('fivempro_interrogation:client:syncKits', function(list)
    for id in pairs(KitProps) do
        deleteKitProps(id)
    end
    for _, kit in ipairs(list or {}) do
        spawnKitProps(kit)
    end
    Wait(200)
    refreshKitTargets()
end)

RegisterNetEvent('fivempro_interrogation:client:startPlaceKit', function()
    if placing then return end
    local cfg = Config.GangKit or {}
    local model = cfg.propModel or 'prop_tool_box_05'
    if not loadModel(model) then
        return notify('Modelis nerastas.', 'error')
    end

    placing = true
    local ped = PlayerPedId()
    local preview = CreateObject(joaat(model), 0.0, 0.0, 0.0, false, false, false)
    SetEntityAlpha(preview, 180, false)
    SetEntityCollision(preview, false, false)
    FreezeEntityPosition(preview, true)

    notify('[E] Padėti · [SCROLL] Sukti · [BACKSPACE] Atšaukti', 'primary')

    CreateThread(function()
        local heading = GetEntityHeading(ped)
        while placing do
            Wait(0)
            local c = GetEntityCoords(ped)
            local fwd = GetEntityForwardVector(ped)
            local pos = c + fwd * 1.35
            SetEntityCoords(preview, pos.x, pos.y, pos.z, false, false, false, false)
            PlaceObjectOnGroundProperly(preview)
            if IsControlPressed(0, 241) then heading = heading + 1.2 end
            if IsControlPressed(0, 242) then heading = heading - 1.2 end
            SetEntityHeading(preview, heading)

            if IsControlJustPressed(0, 177) then
                placing = false
            elseif IsControlJustPressed(0, 38) then
                local fc = GetEntityCoords(preview)
                local fh = GetEntityHeading(preview)
                placing = false
                TriggerServerEvent('fivempro_interrogation:server:placeKit', fc.x, fc.y, fc.z, fh)
            end
        end
        if DoesEntityExist(preview) then DeleteEntity(preview) end
        SetModelAsNoLongerNeeded(joaat(model))
    end)
end)

function GetKitSeatWorld(kit)
    if not kit then return nil end
    local off = (Config.GangKit and Config.GangKit.suspectSeatOffset) or vector4(0, -0.9, -0.45, 0)
    local h = kit.heading or 0.0
    local rad = math.rad(h)
    local cos, sin = math.cos(rad), math.sin(rad)
    local x = kit.x + off.x * cos - off.y * sin
    local y = kit.y + off.x * sin + off.y * cos
    local z = kit.z + off.z
    return vector4(x, y, z, h + (off.w or 0))
end

function GetKitSpotlight(kit)
    if not kit then return nil end
    local so = (Config.GangKit and Config.GangKit.spotlightOffset) or {}
    local o, t = so.origin or vector3(0, 0.6, 1.4), so.target or vector3(0, -0.9, 0.2)
    local h = kit.heading or 0.0
    local rad = math.rad(h)
    local cos, sin = math.cos(rad), math.sin(rad)
    local function rot(v)
        return vector3(
            kit.x + v.x * cos - v.y * sin,
            kit.y + v.x * sin + v.y * cos,
            kit.z + v.z
        )
    end
    return { origin = rot(o), target = rot(t) }
end

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for id in pairs(KitProps) do
        deleteKitProps(id)
    end
end)
