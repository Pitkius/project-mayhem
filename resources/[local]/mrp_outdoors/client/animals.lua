local QBCore = exports['qb-core']:GetCoreObject()

local zoneAnimals = {}
local guttedCorpses = {}

local function pickAnimalModel()
    local total = 0
    for _, row in ipairs(Config.AnimalSpawn.models) do
        total = total + row.weight
    end
    local roll = math.random(1, total)
    local acc = 0
    for _, row in ipairs(Config.AnimalSpawn.models) do
        acc = acc + row.weight
        if roll <= acc then return row end
    end
    return Config.AnimalSpawn.models[1]
end

local function loadModel(model)
    RequestModel(model)
    local t = 0
    while not HasModelLoaded(model) and t < 100 do
        Wait(10)
        t = t + 1
    end
    return HasModelLoaded(model)
end

local function randomPointInZone(zone)
    local angle = math.random() * math.pi * 2
    local dist = math.random() * zone.radius * 0.85
    return vector3(
        zone.coords.x + math.cos(angle) * dist,
        zone.coords.y + math.sin(angle) * dist,
        zone.coords.z
    )
end

local function getGroundZ(x, y, zHint)
    local found, z = GetGroundZFor_3dCoord(x, y, zHint + 50.0, false)
    if found then return z end
    return zHint
end

local function spawnAnimalInZone(zoneIndex, zone)
    local def = pickAnimalModel()
    if not loadModel(def.model) then return end
    local pt = randomPointInZone(zone)
    local gz = getGroundZ(pt.x, pt.y, pt.z)
    local ped = CreatePed(28, def.model, pt.x, pt.y, gz, math.random(0, 360) + 0.0, true, true)
    if not DoesEntityExist(ped) then
        SetModelAsNoLongerNeeded(def.model)
        return
    end
    SetEntityAsMissionEntity(ped, true, true)
    SetPedRelationshipGroupHash(ped, joaat('WILD_ANIMAL'))
    TaskWanderStandard(ped, 10.0, 10)
    local netId = NetworkGetNetworkIdFromEntity(ped)
    zoneAnimals[zoneIndex] = zoneAnimals[zoneIndex] or {}
    zoneAnimals[zoneIndex][#zoneAnimals[zoneIndex] + 1] = {
        entity = ped,
        netId = netId,
        meat = def.meat,
        extra = def.extra,
        zone = zoneIndex,
    }
    SetModelAsNoLongerNeeded(def.model)
end

local function cleanupZone(zoneIndex)
    local list = zoneAnimals[zoneIndex]
    if not list then return end
    for i = #list, 1, -1 do
        local row = list[i]
        if row.entity and (not DoesEntityExist(row.entity) or (#(GetEntityCoords(PlayerPedId()) - GetEntityCoords(row.entity)) > 400.0 and IsEntityDead(row.entity))) then
            if DoesEntityExist(row.entity) then DeleteEntity(row.entity) end
            table.remove(list, i)
        end
    end
end

local gutBusy = false

local function resolveLootForEntity(entity)
    if not entity or entity == 0 or not DoesEntityExist(entity) then return nil, nil end
    local model = GetEntityModel(entity)
    local row = AnimalLoot.resolve(model)
    if row then
        return row.meat, row.extra
    end
    for _, zones in pairs(zoneAnimals) do
        for _, spawnRow in ipairs(zones) do
            if spawnRow.entity == entity then
                return spawnRow.meat, spawnRow.extra
            end
        end
    end
    return nil, nil
end

local function tryGutCorpse(entity)
    if gutBusy or guttedCorpses[entity] then return end
    local meat, extra = resolveLootForEntity(entity)
    if not meat then
        QBCore.Functions.Notify('Nežinomas gyvūnas — negalima skersti.', 'error')
        return
    end
    QBCore.Functions.TriggerCallback('mrp_outdoors:server:hasLicense', function(has)
        if not has then
            QBCore.Functions.Notify('Reikia medžioklės licencijos.', 'error')
            return
        end
        if not QBCore.Functions.HasItem('hunting_knife', 1) then
            QBCore.Functions.Notify('Reikia medžioklinio peilio.', 'error')
            return
        end
        gutBusy = true
        local ped = PlayerPedId()
        TaskTurnPedToFaceEntity(ped, entity, 800)
        Wait(500)
        local ok = exports['mrp_outdoors']:OpenMinigame('butcher', { label = 'Skerdimo minigame — rodyklės' })
        if ok then
            guttedCorpses[entity] = true
            TriggerServerEvent('mrp_outdoors:server:gutAnimal', GetEntityModel(entity))
            SetTimeout(Config.HuntGutCooldown * 1000, function()
                if DoesEntityExist(entity) then DeleteEntity(entity) end
            end)
        else
            QBCore.Functions.Notify('Skerdimas nepavyko.', 'error')
        end
        SetTimeout(2000, function() gutBusy = false end)
    end, 'hunting_license')
end

--- qb-target ant negyvų gyvūnų
CreateThread(function()
    Wait(2000)
    exports['qb-target']:AddGlobalPed({
        options = {
            {
                icon = 'fas fa-drumstick-bite',
                label = 'Skersti gyvūną',
                action = function(entity)
                    if not IsEntityDead(entity) then return end
                    if not IsPedHuman(entity) then
                        tryGutCorpse(entity)
                    end
                end,
                canInteract = function(entity)
                    if not (IsEntityDead(entity) and not IsPedHuman(entity) and not IsPedAPlayer(entity) and not guttedCorpses[entity]) then
                        return false
                    end
                    return AnimalLoot.resolve(GetEntityModel(entity)) ~= nil
                end,
            },
        },
        distance = 2.0,
    })
end)

CreateThread(function()
    while true do
        local ped = PlayerPedId()
        local pos = GetEntityCoords(ped)
        for zi, zone in ipairs(Config.HuntingZones) do
            if #(pos - zone.coords) <= zone.radius + 50.0 then
                zoneAnimals[zi] = zoneAnimals[zi] or {}
                cleanupZone(zi)
                while #zoneAnimals[zi] < Config.AnimalSpawn.maxPerZone do
                    spawnAnimalInZone(zi, zone)
                    Wait(200)
                end
            else
                if zoneAnimals[zi] then
                    for _, row in ipairs(zoneAnimals[zi]) do
                        if DoesEntityExist(row.entity) then DeleteEntity(row.entity) end
                    end
                    zoneAnimals[zi] = {}
                end
            end
        end
        Wait(Config.AnimalSpawn.respawnSec * 1000)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, list in pairs(zoneAnimals) do
        for _, row in ipairs(list) do
            if DoesEntityExist(row.entity) then DeleteEntity(row.entity) end
        end
    end
end)
