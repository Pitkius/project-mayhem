local QBCore = exports['qb-core']:GetCoreObject()

local fieldSpawns = {}
local picking = false
local fieldsReady = {}

local function allHarvestFields()
    local out = {}
    for _, field in ipairs(Config.MushroomFields or {}) do
        out[#out + 1] = field
    end
    for _, field in ipairs(Config.CocaFields or {}) do
        out[#out + 1] = field
    end
    return out
end

local function zoneName(fieldId, spawnIndex)
    return ('mrp_harvest_%s_%s'):format(tostring(fieldId), tostring(spawnIndex))
end

local function loadModel(model)
    local hash = type(model) == 'string' and joaat(model) or model
    if not IsModelInCdimage(hash) then return nil end
    RequestModel(hash)
    local t = 0
    while not HasModelLoaded(hash) and t < 100 do
        Wait(10)
        t = t + 1
    end
    if not HasModelLoaded(hash) then return nil end
    return hash
end

local function ensureGroundLoaded(x, y, z)
    if GetResourceState('mrp_cayoperico') == 'started' then
        pcall(function()
            exports['mrp_cayoperico']:RequestIslandCollision(x, y, z)
        end)
    end
    for _ = 1, 12 do
        RequestCollisionAtCoord(x, y, z)
        RequestCollisionAtCoord(x, y, z + 20.0)
        Wait(0)
    end
end

local function resolveGroundZ(x, y, refZ)
    local z = refZ
    local found, gz = GetGroundZFor_3dCoord(x, y, refZ + 80.0, false)
    if found then z = gz end
    return z
end

local function spawnCoordForIndex(field, index)
    local total = math.max(1, tonumber(field.spawnCount) or 12)
    local radius = tonumber(field.radius) or 35.0
    local angle = ((index - 1) / total) * (math.pi * 2.0)
    local ring = 0.32 + (((index - 1) % 4) * 0.16)
    local dist = radius * ring
    local x = field.center.x + math.cos(angle) * dist
    local y = field.center.y + math.sin(angle) * dist
    local z = resolveGroundZ(x, y, field.center.z)
    return vector3(x, y, z)
end

local function removeHarvestZone(fieldId, spawnIndex)
    pcall(function()
        exports['qb-target']:RemoveZone(zoneName(fieldId, spawnIndex))
    end)
end

local function deleteSpawnEntity(fieldId, spawn)
    if spawn.entity and DoesEntityExist(spawn.entity) then
        DeleteEntity(spawn.entity)
    end
    spawn.entity = nil
    removeHarvestZone(fieldId, spawn.index)
end

local function tryPickHarvest(fieldId, spawnIndex)
    if picking then return end
    spawnIndex = tonumber(spawnIndex)
    if not fieldId or not spawnIndex then return end

    local state = fieldSpawns[fieldId]
    if not state then return end
    local spawn = state.spawns[spawnIndex]
    if not spawn or not spawn.available then
        return QBCore.Functions.Notify('Čia jau nieko nėra.', 'error')
    end

    local ped = PlayerPedId()
    local pcoords = GetEntityCoords(ped)
    local interactAt = spawn.coords
    if spawn.entity and DoesEntityExist(spawn.entity) then
        interactAt = GetEntityCoords(spawn.entity)
    end

    if #(pcoords - interactAt) > (state.field.pickDistance or 2.4) + 1.0 then
        return QBCore.Functions.Notify('Per toli.', 'error')
    end

    local profile = Config.GetHarvestMinigameForField and Config.GetHarvestMinigameForField(state.field)
    if profile and GetResourceState(GetCurrentResourceName()) == 'started' then
        picking = true
        exports[GetCurrentResourceName()]:RunScheduleMinigame(profile, function(success)
            picking = false
            if success then
                TriggerServerEvent('mrp_drugs:server:pickMushroom', fieldId, spawnIndex, pcoords.x, pcoords.y, pcoords.z)
            else
                QBCore.Functions.Notify('Derliaus rinkimas nepavyko.', 'error')
            end
        end)
        return
    end

    picking = true
    local label = state.field.pickLabel or 'Renki…'
    DrugProgress.run('mrp_drugs_harvest', label, state.field.pickDurationMs or 5200, false, true, {
        disableMovement = true,
        disableCarMovement = true,
        disableMouse = false,
        disableCombat = true,
    }, {
        animDict = 'amb@world_human_gardener_plant@male@base',
        anim = 'base',
        flags = 49,
    }, function()
        picking = false
        TriggerServerEvent('mrp_drugs:server:pickMushroom', fieldId, spawnIndex, pcoords.x, pcoords.y, pcoords.z)
    end, function()
        picking = false
        QBCore.Functions.Notify('Atšaukta.', 'error')
    end)
end

local function attachHarvestZone(field, spawn)
    if not spawn.available or not spawn.coords then return end

    local zname = zoneName(field.id, spawn.index)
    removeHarvestZone(field.id, spawn.index)

    local zoneRadius = tonumber(field.zoneRadius) or 1.05
    exports['qb-target']:AddCircleZone(zname, spawn.coords, zoneRadius, {
        name = zname,
        debugPoly = false,
        useZ = true,
    }, {
        options = {
            {
                icon = 'fas fa-seedling',
                label = field.pickLabel or 'Rinkti',
                action = function()
                    tryPickHarvest(field.id, spawn.index)
                end,
                canInteract = function()
                    return spawn.available and not picking
                end,
            },
        },
        distance = (field.pickDistance or 2.4) + 0.35,
    })
end

local function setEntityScale(entity, scale)
    scale = tonumber(scale)
    if not entity or not DoesEntityExist(entity) or not scale or math.abs(scale - 1.0) < 0.01 then return end
    local forward, right, up, position = GetEntityMatrix(entity)
    SetEntityMatrix(entity, forward * scale, right * scale, up * scale, position)
end

local function spawnMushroomProp(field, spawn)
    if not spawn.available then return end
    deleteSpawnEntity(field.id, spawn)
    local hash = loadModel(field.prop or 'prop_stoneshroom2')
    if not hash then return end
    local obj = CreateObject(hash, spawn.coords.x, spawn.coords.y, spawn.coords.z, false, false, false)
    if not obj or obj == 0 then
        SetModelAsNoLongerNeeded(hash)
        return
    end
    PlaceObjectOnGroundProperly(obj)
    setEntityScale(obj, field.propScale)
    FreezeEntityPosition(obj, true)
    SetEntityAsMissionEntity(obj, true, true)
    spawn.entity = obj
    spawn.coords = GetEntityCoords(obj)
    SetModelAsNoLongerNeeded(hash)
    attachHarvestZone(field, spawn)
end

local function initField(field)
    if not field or not field.id or not field.center then return end
    if fieldsReady[field.id] then return end
    ensureGroundLoaded(field.center.x, field.center.y, field.center.z)

    local spawns = {}
    local count = math.max(1, tonumber(field.spawnCount) or 12)
    for i = 1, count do
        spawns[i] = {
            index = i,
            coords = spawnCoordForIndex(field, i),
            available = true,
            entity = nil,
        }
    end
    fieldSpawns[field.id] = { field = field, spawns = spawns }
    fieldsReady[field.id] = true
    for _, spawn in ipairs(spawns) do
        spawnMushroomProp(field, spawn)
    end
end

RegisterNetEvent('mrp_drugs:client:pickMushroom', function(data)
    if type(data) ~= 'table' then return end
    tryPickHarvest(data.fieldId, data.spawnIndex)
end)

RegisterNetEvent('mrp_drugs:client:mushroomDespawn', function(fieldId, spawnIndex)
    local state = fieldSpawns[fieldId]
    if not state then return end
    local spawn = state.spawns[spawnIndex]
    if not spawn then return end
    spawn.available = false
    deleteSpawnEntity(fieldId, spawn)
end)

RegisterNetEvent('mrp_drugs:client:mushroomRespawn', function(fieldId, spawnIndex)
    local state = fieldSpawns[fieldId]
    if not state then return end
    local spawn = state.spawns[spawnIndex]
    if not spawn then return end
    spawn.available = true
    spawn.coords = spawnCoordForIndex(state.field, spawnIndex)
    spawnMushroomProp(state.field, spawn)
end)

CreateThread(function()
    Wait(1500)
    while true do
        local ped = PlayerPedId()
        local pcoords = GetEntityCoords(ped)
        for _, field in ipairs(allHarvestFields()) do
            local loadDist = tonumber(field.loadDistance) or 180.0
            if #(pcoords - field.center) <= loadDist then
                initField(field)
            end
        end
        Wait(1200)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for fieldId, state in pairs(fieldSpawns) do
        for _, spawn in ipairs(state.spawns or {}) do
            deleteSpawnEntity(fieldId, spawn)
        end
    end
end)
