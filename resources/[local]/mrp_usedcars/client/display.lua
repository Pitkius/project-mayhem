local QBCore = exports['qb-core']:GetCoreObject()

local listings = {}
local spawned = {} -- [listingId] = { entity = veh, plate = ... }

local function clearTarget(entity)
    if not entity or entity == 0 then return end
    pcall(function()
        exports['qb-target']:RemoveTargetEntity(entity)
    end)
end

local function deleteDisplayVehicle(entry)
    if not entry then return end
    if entry.entity and DoesEntityExist(entry.entity) then
        clearTarget(entry.entity)
        SetEntityAsMissionEntity(entry.entity, true, true)
        DeleteEntity(entry.entity)
    end
end

local function despawnAll()
    for id, entry in pairs(spawned) do
        deleteDisplayVehicle(entry)
        spawned[id] = nil
    end
end

local function listingsById(id)
    id = tonumber(id)
    for i = 1, #listings do
        if tonumber(listings[i].id) == id then
            return listings[i]
        end
    end
    return nil
end

local function applyDisplayProps(veh, listing)
    SetVehicleModKit(veh, 0)
    SetVehicleNumberPlateText(veh, listing.plate or 'USED')
    if type(listing.mods) == 'table' then
        QBCore.Functions.SetVehicleProperties(veh, listing.mods)
        SetVehicleNumberPlateText(veh, listing.plate or 'USED')
    end
    SetVehicleDoorsLocked(veh, 2)
    SetVehicleUndriveable(veh, true)
    SetVehicleEngineOn(veh, false, true, true)
    FreezeEntityPosition(veh, true)
    SetEntityInvincible(veh, true)
    SetVehicleDirtLevel(veh, 0.0)
end

local function attachInspectTarget(veh, listing)
    exports['qb-target']:AddTargetEntity(veh, {
        options = {
            {
                icon = 'fas fa-search',
                label = 'Apžiūrėti / pirkti',
                action = function(entity)
                    local live = listingsById(listing.id) or listing
                    if OpenInspectUi then
                        OpenInspectUi(live)
                    end
                end,
            },
        },
        distance = Config.VehicleTargetDistance,
    })
end

local function spawnListing(listing)
    local id = tonumber(listing.id)
    if not id or spawned[id] then return end

    local slotIndex = tonumber(listing.slotIndex) or 0
    local slot = Config.Slots[slotIndex + 1]
    if not slot then return end

    local model = listing.model
    local hash = type(model) == 'number' and model or joaat(model)
    if not IsModelInCdimage(hash) then return end

    RequestModel(hash)
    local timeout = GetGameTimer() + 6000
    while not HasModelLoaded(hash) and GetGameTimer() < timeout do
        Wait(0)
    end
    if not HasModelLoaded(hash) then return end

    -- Re-check distance / still needed
    if spawned[id] then
        SetModelAsNoLongerNeeded(hash)
        return
    end

    local veh = CreateVehicle(hash, slot.x, slot.y, slot.z, slot.w or 0.0, false, false)
    SetModelAsNoLongerNeeded(hash)
    if not veh or veh == 0 then return end

    SetEntityAsMissionEntity(veh, true, true)
    SetVehicleOnGroundProperly(veh)
    applyDisplayProps(veh, listing)
    attachInspectTarget(veh, listing)

    spawned[id] = { entity = veh, plate = listing.plate }
end

local function syncSpawns()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local spawnDist = Config.SpawnDistance
    local despawnDist = Config.DespawnDistance

    local activeIds = {}
    for i = 1, #listings do
        local listing = listings[i]
        local id = tonumber(listing.id)
        if id then
            activeIds[id] = true
            local slotIndex = tonumber(listing.slotIndex) or 0
            local slot = Config.Slots[slotIndex + 1]
            if slot then
                local dist = #(coords - vector3(slot.x, slot.y, slot.z))
                if dist <= spawnDist then
                    if not spawned[id] then
                        spawnListing(listing)
                    end
                elseif dist >= despawnDist then
                    if spawned[id] then
                        deleteDisplayVehicle(spawned[id])
                        spawned[id] = nil
                    end
                end
            end
        end
    end

    for id, entry in pairs(spawned) do
        if not activeIds[id] then
            deleteDisplayVehicle(entry)
            spawned[id] = nil
        end
    end
end

RegisterNetEvent('mrp_usedcars:client:setListings', function(list)
    listings = list or {}
    -- Refresh existing entities' props / targets if still valid
    for id, entry in pairs(spawned) do
        local live = listingsById(id)
        if not live then
            deleteDisplayVehicle(entry)
            spawned[id] = nil
        end
    end
    syncSpawns()
end)

CreateThread(function()
    while true do
        Wait(Config.ProximityTickMs or 1250)
        if #listings > 0 or next(spawned) then
            syncSpawns()
        end
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    despawnAll()
end)
