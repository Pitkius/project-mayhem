--- Server-side shop NPC — spawn tik kai prie taško yra žaidėjas (proximity)
local registry = {}
local activeByKey = {}

local function proximityCfg()
    return Config.NpcProximity or {}
end

local function spawnDistance()
    local p = proximityCfg()
    return tonumber(p.spawnDistance) or 72.0
end

local function despawnDistance()
    local p = proximityCfg()
    local spawn = spawnDistance()
    return tonumber(p.despawnDistance) or (spawn + 20.0)
end

local function proximityEnabled()
    local p = proximityCfg()
    return p.enabled ~= false
end

local function loadModel(model)
    if not model then return nil end
    return type(model) == 'string' and joaat(model) or model
end

local function playerCoordsList()
    local out = {}
    for _, src in ipairs(GetPlayers()) do
        local sid = tonumber(src)
        local ped = sid and GetPlayerPed(sid) or 0
        if ped and ped ~= 0 then
            local c = GetEntityCoords(ped)
            out[#out + 1] = vector3(c.x, c.y, c.z)
        end
    end
    return out
end

local function anyPlayerWithin(coords, dist)
    if not coords then return false end
    local cx, cy, cz = coords.x + 0.0, coords.y + 0.0, coords.z + 0.0
    local d2 = dist * dist
    for _, p in ipairs(playerCoordsList()) do
        local dx, dy, dz = p.x - cx, p.y - cy, p.z - cz
        if (dx * dx + dy * dy + dz * dz) <= d2 then
            return true
        end
    end
    return false
end

local function buildMeta(entry, x, y, z)
    local meta = {
        registryKey = NpcRegistry.entryKey(entry),
        category = entry.category,
        index = entry.index,
        scenario = entry.scenario,
        blip = entry.blip,
        coords = { x = x, y = y, z = z, w = (entry.coords and entry.coords.w) or 0.0 },
    }
    if entry.chair then
        meta.chair = { x = entry.chair.x, y = entry.chair.y, z = entry.chair.z, w = entry.chair.w }
    end
    if entry.category == 'job' then
        meta.job = entry.job
        meta.stationId = entry.stationId
        meta.role = entry.role
        meta.label = entry.label
    end
    return meta
end

local function spawnEntry(entry)
    local c = entry.coords
    if not c then return nil end
    local hash = loadModel(entry.model or 'mp_m_shopkeep_01')
    if not hash then return nil end

    local x, y, z, h = c.x, c.y, c.z, c.w or 0.0
    local ped = CreatePed(0, hash, x, y, z, h, true, true)
    if not ped or ped == 0 then return nil end

    local timeout = GetGameTimer() + 5000
    while not DoesEntityExist(ped) and GetGameTimer() < timeout do
        Wait(0)
    end
    if not DoesEntityExist(ped) then return nil end

    SetEntityCoords(ped, x, y, z, false, false, false)
    SetEntityHeading(ped, h)
    -- Freeze po kliento ground snap (mrp_npcshops:server:setPedPlacement)

    Entity(ped).state:set('npcShopMeta', buildMeta(entry, x, y, z), true)
    return ped
end

local function playerNearCoords(src, x, y, z, maxDist)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end
    local p = GetEntityCoords(ped)
    local dx, dy, dz = p.x - x, p.y - y, p.z - z
    return (dx * dx + dy * dy + dz * dz) <= (maxDist * maxDist)
end

RegisterNetEvent('mrp_npcshops:server:setPedPlacement', function(netId, x, y, z, h)
    local src = source
    netId = tonumber(netId)
    x, y, z, h = tonumber(x), tonumber(y), tonumber(z), tonumber(h)
    if not netId or not x or not y or not z then return end

    local ped = NetworkGetEntityFromNetworkId(netId)
    if not ped or ped == 0 or not DoesEntityExist(ped) then return end

    local meta = Entity(ped).state.npcShopMeta
    if not meta then return end

    if not playerNearCoords(src, x, y, z, 120.0) then return end

    SetEntityCoords(ped, x, y, z, false, false, false)
    SetEntityHeading(ped, h or 0.0)
    FreezeEntityPosition(ped, true)

    meta.coords = { x = x, y = y, z = z, w = h or 0.0 }
    Entity(ped).state:set('npcShopMeta', meta, true)
end)

local function despawnKey(key)
    local row = activeByKey[key]
    if not row then return end
    local ped = row.ped
    activeByKey[key] = nil
    if ped and DoesEntityExist(ped) then
        local netId = NetworkGetNetworkIdFromEntity(ped)
        if netId and netId ~= 0 then
            TriggerClientEvent('mrp_npcshops:client:clearNpcTarget', -1, netId)
        end
        DeleteEntity(ped)
    end
end

local function spawnAll()
    for key in pairs(activeByKey) do
        despawnKey(key)
    end
    for _, entry in ipairs(registry) do
        local ped = spawnEntry(entry)
        if ped then
            activeByKey[NpcRegistry.entryKey(entry)] = { ped = ped, entry = entry }
        end
    end
end

local function tickProximity()
    local spawnDist = spawnDistance()
    local despawnDist = math.max(despawnDistance(), spawnDist + 5.0)

    for _, entry in ipairs(registry) do
        local key = NpcRegistry.entryKey(entry)
        local active = activeByKey[key]
        local nearSpawn = anyPlayerWithin(entry.coords, spawnDist)
        local nearKeep = anyPlayerWithin(entry.coords, despawnDist)

        if nearSpawn and not active then
            local ped = spawnEntry(entry)
            if ped then
                activeByKey[key] = { ped = ped, entry = entry }
            end
        elseif active and not nearKeep then
            despawnKey(key)
        end
    end
end

CreateThread(function()
    Wait(1500)
    registry = NpcRegistry.collect()

    if not proximityEnabled() then
        spawnAll()
        return
    end

    tickProximity()
    local interval = tonumber(proximityCfg().checkIntervalMs) or 1800
    while true do
        Wait(interval)
        tickProximity()
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for key in pairs(activeByKey) do
        despawnKey(key)
    end
    registry = {}
end)
