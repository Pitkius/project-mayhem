--- Spygluota juosta — padėjimas, qb-target surinkimas, padangų pradūrimas
local QBCore = exports['qb-core']:GetCoreObject()

local StripProps = {} --- [id] = entity
local placing = false

local function cfg()
    return Config.SpikeStrip or {}
end

local function itemName()
    return cfg().item or 'spike_strip'
end

local function notify(msg, typ)
    QBCore.Functions.Notify(msg, typ or 'primary')
end

local function loadModel(model)
    local hash = type(model) == 'number' and model or joaat(model)
    if not hash or hash == 0 or not IsModelInCdimage(hash) then return false end
    RequestModel(hash)
    local t = 0
    while not HasModelLoaded(hash) and t < 5000 do
        Wait(10)
        t = t + 10
    end
    return HasModelLoaded(hash)
end

local function deleteStripProp(id)
    local ent = StripProps[id]
    if ent and DoesEntityExist(ent) then
        exports['qb-target']:RemoveTargetEntity(ent)
        DeleteEntity(ent)
    end
    StripProps[id] = nil
end

local function spawnStripProp(strip)
    if not strip or not strip.id then return end
    deleteStripProp(strip.id)

    local model = cfg().propModel or 'p_ld_stinger_s'
    if not loadModel(model) then return end

    local ent = CreateObject(joaat(model), strip.x, strip.y, strip.z, false, false, false)
    if not ent or ent == 0 then return end

    SetEntityHeading(ent, strip.heading or 0.0)
    PlaceObjectOnGroundProperly(ent)
    FreezeEntityPosition(ent, true)
    SetEntityCollision(ent, true, true)
    SetEntityAsMissionEntity(ent, true, true)

    StripProps[strip.id] = ent
    SetModelAsNoLongerNeeded(joaat(model))

    exports['qb-target']:AddTargetEntity(ent, {
        options = {
            {
                icon = 'fas fa-grip-lines',
                label = cfg().pickupLabel or 'Paimti spygluotą juostą',
                action = function()
                    TriggerServerEvent('mrp_ltpd:server:pickupSpikeStrip', strip.id)
                end,
            },
        },
        distance = cfg().pickupDistance or 2.5,
    })
end

local function syncAllStrips(list)
    local seen = {}
    for _, strip in ipairs(list or {}) do
        seen[strip.id] = true
        spawnStripProp(strip)
    end
    for id in pairs(StripProps) do
        if not seen[id] then
            deleteStripProp(id)
        end
    end
end

RegisterNetEvent('mrp_ltpd:client:syncSpikeStrips', function(list)
    syncAllStrips(list)
end)

RegisterNetEvent('mrp_ltpd:client:startPlaceSpikeStrip', function()
    if placing then return end

    local model = cfg().propModel or 'p_ld_stinger_s'
    if not loadModel(model) then
        return notify('Spygluotos juostos modelis nerastas.', 'error')
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
        local placeDist = tonumber(cfg().placeDistance) or 1.8
        while placing do
            Wait(0)
            local c = GetEntityCoords(ped)
            local fwd = GetEntityForwardVector(ped)
            local pos = c + fwd * placeDist
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
                TriggerServerEvent('mrp_ltpd:server:placeSpikeStrip', fc.x, fc.y, fc.z, fh)
            end
        end
        if DoesEntityExist(preview) then DeleteEntity(preview) end
        SetModelAsNoLongerNeeded(joaat(model))
    end)
end)

local function burstVehicleTyres(vehicle)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) or not IsEntityAVehicle(vehicle) then
        return
    end
    for wheel = 0, 7 do
        if not IsVehicleTyreBurst(vehicle, wheel, false) then
            SetVehicleTyreBurst(vehicle, wheel, true, 1000.0)
        end
    end
end

RegisterNetEvent('mrp_ltpd:client:burstVehicleTyres', function(netId)
    netId = tonumber(netId) or 0
    if netId <= 0 then return end
    if type(NetworkDoesNetworkIdExist) == 'function' and not NetworkDoesNetworkIdExist(netId) then return end
    local veh = NetworkGetEntityFromNetworkId(netId)
    if veh ~= 0 and IsEntityAVehicle(veh) then
        burstVehicleTyres(veh)
    end
end)

CreateThread(function()
    Wait(2500)
    QBCore.Functions.TriggerCallback('mrp_ltpd:server:getSpikeStrips', function(list)
        syncAllStrips(list)
    end)
end)

CreateThread(function()
    local burstRadius = tonumber(cfg().burstRadius) or 2.2
    local minSpeed = tonumber(cfg().minBurstSpeed) or 1.5
    while true do
        local strips = {}
        for id, ent in pairs(StripProps) do
            if ent and DoesEntityExist(ent) then
                strips[#strips + 1] = { id = id, coords = GetEntityCoords(ent) }
            end
        end

        if #strips == 0 then
            Wait(900)
        else
            local vehicles = GetGamePool('CVehicle')
            for _, veh in ipairs(vehicles) do
                if DoesEntityExist(veh) and IsEntityAVehicle(veh) then
                    local speed = GetEntitySpeed(veh)
                    if speed >= minSpeed then
                        local vc = GetEntityCoords(veh)
                        for _, strip in ipairs(strips) do
                            if #(vc - strip.coords) <= burstRadius then
                                local netId = NetworkGetNetworkIdFromEntity(veh)
                                if netId and netId ~= 0 then
                                    TriggerServerEvent('mrp_ltpd:server:spikeStripHit', strip.id, netId)
                                end
                            end
                        end
                    end
                end
            end
            Wait(180)
        end
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for id in pairs(StripProps) do
        deleteStripProp(id)
    end
end)
