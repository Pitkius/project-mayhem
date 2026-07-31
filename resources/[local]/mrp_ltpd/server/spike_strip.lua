--- Spygluota juosta — serverio būsena, naudojimas bet kam (tik turint itemą)
local QBCore = exports['qb-core']:GetCoreObject()

local SpikeStrips = { byId = {}, nextId = 1 }
local HitPairs = {} --- [stripId:netId] = expireAt

local function cfg()
    return Config.SpikeStrip or {}
end

local function itemName()
    return cfg().item or 'spike_strip'
end

local function listStrips()
    local out = {}
    for _, strip in pairs(SpikeStrips.byId) do
        out[#out + 1] = strip
    end
    table.sort(out, function(a, b) return (a.id or 0) < (b.id or 0) end)
    return out
end

local function syncAll(target)
    TriggerClientEvent('mrp_ltpd:client:syncSpikeStrips', target or -1, listStrips())
end

local function playerNearStrip(src, strip)
    if not strip then return false end
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end
    local c = GetEntityCoords(ped)
    local maxD = (tonumber(cfg().pickupDistance) or 2.5) + 1.5
    return #(c - vector3(strip.x, strip.y, strip.z)) <= maxD
end

local function playerNearCoords(src, x, y, z, maxD)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end
    local c = GetEntityCoords(ped)
    return #(c - vector3(x, y, z)) <= maxD
end

local function giveItemBox(src, item, amount, action)
    local shared = QBCore.Shared.Items[item]
    if shared then
        TriggerClientEvent('qb-inventory:client:ItemBox', src, shared, action, amount)
    end
end

local function stripHitKey(stripId, netId)
    return ('%s:%s'):format(stripId, netId)
end

local function markStripHit(stripId, netId)
    local cooldown = tonumber(cfg().hitCooldownMs) or 8000
    HitPairs[stripHitKey(stripId, netId)] = GetGameTimer() + cooldown
end

local function alreadyHit(stripId, netId)
    local key = stripHitKey(stripId, netId)
    local exp = HitPairs[key]
    if not exp then return false end
    if exp <= GetGameTimer() then
        HitPairs[key] = nil
        return false
    end
    return true
end

RegisterNetEvent('mrp_ltpd:server:placeSpikeStrip', function(x, y, z, heading)
    local src = source
    local P = QBCore.Functions.GetPlayer(src)
    if not P then return end

    local item = itemName()
    if not P.Functions.GetItemByName(item) then
        return TriggerClientEvent('QBCore:Notify', src, 'Neturi spygluotos juostos.', 'error')
    end

    x, y, z, heading = tonumber(x), tonumber(y), tonumber(z), tonumber(heading)
    if not x or not y or not z then return end

    local maxPlace = tonumber(cfg().maxPlaceDistance) or 4.0
    if not playerNearCoords(src, x, y, z, maxPlace) then
        return TriggerClientEvent('QBCore:Notify', src, 'Per toli nuo padėjimo vietos.', 'error')
    end

    if not P.Functions.RemoveItem(item, 1) then
        return TriggerClientEvent('QBCore:Notify', src, 'Nepavyko paimti itemo.', 'error')
    end
    giveItemBox(src, item, 1, 'remove')

    local id = SpikeStrips.nextId
    SpikeStrips.nextId = id + 1
    SpikeStrips.byId[id] = {
        id = id,
        x = x,
        y = y,
        z = z,
        heading = heading or 0.0,
        placedBy = P.PlayerData.citizenid,
    }

    syncAll()
    TriggerClientEvent('QBCore:Notify', src, 'Spygluota juosta padėta.', 'success')
end)

RegisterNetEvent('mrp_ltpd:server:pickupSpikeStrip', function(stripId)
    local src = source
    stripId = tonumber(stripId)
    local strip = stripId and SpikeStrips.byId[stripId]
    if not strip then
        return TriggerClientEvent('QBCore:Notify', src, 'Spygluota juosta nerasta.', 'error')
    end
    if not playerNearStrip(src, strip) then
        return TriggerClientEvent('QBCore:Notify', src, 'Per toli.', 'error')
    end

    local P = QBCore.Functions.GetPlayer(src)
    if not P then return end

    local item = itemName()
    if not P.Functions.AddItem(item, 1) then
        return TriggerClientEvent('QBCore:Notify', src, 'Inventorius pilnas.', 'error')
    end

    SpikeStrips.byId[stripId] = nil
    giveItemBox(src, item, 1, 'add')
    syncAll()
    TriggerClientEvent('QBCore:Notify', src, 'Spygluota juosta surinkta.', 'success')
end)

RegisterNetEvent('mrp_ltpd:server:spikeStripHit', function(stripId, netId)
    stripId = tonumber(stripId)
    netId = tonumber(netId)
    if not stripId or not netId or netId <= 0 then return end

    local strip = SpikeStrips.byId[stripId]
    if not strip then return end
    if alreadyHit(stripId, netId) then return end

    if type(NetworkDoesNetworkIdExist) == 'function' and not NetworkDoesNetworkIdExist(netId) then return end
    local veh = NetworkGetEntityFromNetworkId(netId)
    if veh == 0 or not DoesEntityExist(veh) or not IsEntityAVehicle(veh) then return end

    local vc = GetEntityCoords(veh)
    local burstRadius = (tonumber(cfg().burstRadius) or 2.2) + 1.0
    if #(vc - vector3(strip.x, strip.y, strip.z)) > burstRadius then return end
    if GetEntitySpeed(veh) < (tonumber(cfg().minBurstSpeed) or 1.5) then return end

    markStripHit(stripId, netId)
    TriggerClientEvent('mrp_ltpd:client:burstVehicleTyres', -1, netId)
end)

QBCore.Functions.CreateCallback('mrp_ltpd:server:getSpikeStrips', function(_, cb)
    cb(listStrips())
end)

CreateThread(function()
    Wait(800)
    local item = itemName()
    QBCore.Functions.CreateUseableItem(item, function(source)
        TriggerClientEvent('mrp_ltpd:client:startPlaceSpikeStrip', source)
    end)
end)
