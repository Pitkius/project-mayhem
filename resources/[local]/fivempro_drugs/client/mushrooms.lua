local QBCore = exports['qb-core']:GetCoreObject()

local fieldSpawns = {}
local picking = false

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

local function spawnCoordForIndex(field, index)
    local total = math.max(1, tonumber(field.spawnCount) or 12)
    local radius = tonumber(field.radius) or 35.0
    local angle = ((index - 1) / total) * (math.pi * 2.0)
    local ring = 0.32 + (((index - 1) % 4) * 0.16)
    local dist = radius * ring
    local x = field.center.x + math.cos(angle) * dist
    local y = field.center.y + math.sin(angle) * dist
    local z = field.center.z
    local found, gz = GetGroundZFor_3dCoord(x, y, field.center.z + 60.0, false)
    if found then z = gz end
    return vector3(x, y, z)
end

local function deleteSpawnEntity(spawn)
    if spawn.entity and DoesEntityExist(spawn.entity) then
        exports['qb-target']:RemoveTargetEntity(spawn.entity)
        DeleteEntity(spawn.entity)
    end
    spawn.entity = nil
end

local function attachTarget(field, spawn)
    if not spawn.entity or not DoesEntityExist(spawn.entity) then return end
    exports['qb-target']:AddTargetEntity(spawn.entity, {
        options = {
            {
                type = 'client',
                event = 'fivempro_drugs:client:pickMushroom',
                icon = 'fas fa-seedling',
                label = 'Rinkti grybus',
                fieldId = field.id,
                spawnIndex = spawn.index,
                canInteract = function()
                    return spawn.available and not picking
                end,
            },
        },
        distance = field.pickDistance or 2.4,
    })
end

local function spawnMushroomProp(field, spawn)
    if not spawn.available then return end
    deleteSpawnEntity(spawn)
    local hash = loadModel(field.prop or 'prop_stoneshroom2')
    if not hash then return end
    local obj = CreateObject(hash, spawn.coords.x, spawn.coords.y, spawn.coords.z, false, false, false)
    if not obj or obj == 0 then
        SetModelAsNoLongerNeeded(hash)
        return
    end
    PlaceObjectOnGroundProperly(obj)
    FreezeEntityPosition(obj, true)
    SetEntityAsMissionEntity(obj, true, true)
    spawn.entity = obj
    SetModelAsNoLongerNeeded(hash)
    attachTarget(field, spawn)
end

local function initField(field)
    if not field or not field.id or not field.center then return end
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
    for _, spawn in ipairs(spawns) do
        spawnMushroomProp(field, spawn)
    end
end

RegisterNetEvent('fivempro_drugs:client:pickMushroom', function(data)
    if picking then return end
    local fieldId = data and data.fieldId
    local spawnIndex = data and tonumber(data.spawnIndex)
    if not fieldId or not spawnIndex then return end

    local state = fieldSpawns[fieldId]
    if not state then return end
    local spawn = state.spawns[spawnIndex]
    if not spawn or not spawn.available then
        return QBCore.Functions.Notify('Čia jau nieko nėra.', 'error')
    end

    local ped = PlayerPedId()
    local pcoords = GetEntityCoords(ped)
    if #(pcoords - spawn.coords) > (state.field.pickDistance or 2.4) + 1.0 then
        return QBCore.Functions.Notify('Per toli.', 'error')
    end

    picking = true
    QBCore.Functions.Progressbar('fivempro_drugs_mushroom', 'Renki grybus…', state.field.pickDurationMs or 5200, false, true, {
        disableMovement = true,
        disableCarMovement = true,
        disableMouse = false,
        disableCombat = true,
    }, {
        animDict = 'amb@world_human_gardener_plant@male@base',
        anim = 'base',
        flags = 49,
    }, {}, {}, function()
        picking = false
        TriggerServerEvent('fivempro_drugs:server:pickMushroom', fieldId, spawnIndex, pcoords.x, pcoords.y, pcoords.z)
    end, function()
        picking = false
        QBCore.Functions.Notify('Atšaukta.', 'error')
    end)
end)

RegisterNetEvent('fivempro_drugs:client:mushroomDespawn', function(fieldId, spawnIndex)
    local state = fieldSpawns[fieldId]
    if not state then return end
    local spawn = state.spawns[spawnIndex]
    if not spawn then return end
    spawn.available = false
    deleteSpawnEntity(spawn)
end)

RegisterNetEvent('fivempro_drugs:client:mushroomRespawn', function(fieldId, spawnIndex)
    local state = fieldSpawns[fieldId]
    if not state then return end
    local spawn = state.spawns[spawnIndex]
    if not spawn then return end
    spawn.available = true
    spawnMushroomProp(state.field, spawn)
end)

CreateThread(function()
    Wait(1500)
    for _, field in ipairs(Config.MushroomFields or {}) do
        initField(field)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, state in pairs(fieldSpawns) do
        for _, spawn in ipairs(state.spawns or {}) do
            deleteSpawnEntity(spawn)
        end
    end
end)
