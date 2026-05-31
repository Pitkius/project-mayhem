--- Server-side shop NPC spawn — viena pozicija visam serveriui (OneSync)
local spawned = {}

local function loadModel(model)
    if not model then return nil end
    return type(model) == 'string' and joaat(model) or model
end

local function spawnEntry(entry)
    local c = entry.coords
    if not c then return nil end
    local hash = loadModel(entry.model or 'mp_m_shopkeep_01')
    if not hash then return nil end

    local x, y, z, h = c.x, c.y, c.z, c.w or 0.0
    local ped = CreatePed(0, hash, x, y, z - 1.0, h, true, true)
    if not ped or ped == 0 then return nil end

    local timeout = GetGameTimer() + 5000
    while not DoesEntityExist(ped) and GetGameTimer() < timeout do
        Wait(0)
    end
    if not DoesEntityExist(ped) then return nil end

    SetEntityCoords(ped, x, y, z - 1.0, false, false, false)
    SetEntityHeading(ped, h)
    FreezeEntityPosition(ped, true)
    -- Invincible / blocking / scenario: client/peds.lua (setupPedEntity) — tik kliente

    local meta = {
        category = entry.category,
        index = entry.index,
        scenario = entry.scenario,
        blip = entry.blip,
        coords = { x = x, y = y, z = z },
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

    Entity(ped).state:set('npcShopMeta', meta, true)
    spawned[#spawned + 1] = ped
    return ped
end

local function spawnAll()
    for _, ped in ipairs(spawned) do
        if DoesEntityExist(ped) then DeleteEntity(ped) end
    end
    spawned = {}

    for _, entry in ipairs(NpcRegistry.collect()) do
        spawnEntry(entry)
    end
end

CreateThread(function()
    Wait(1500)
    spawnAll()
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, ped in ipairs(spawned) do
        if DoesEntityExist(ped) then DeleteEntity(ped) end
    end
    spawned = {}
end)
