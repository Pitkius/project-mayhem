local QBCore = exports['qb-core']:GetCoreObject()

local spawned = {} --- [furnitureId] = entity
local currentPropertyId = nil
local canManage = false
local placing = nil --- { key, slot, entity, heading }

local function loadModel(hash)
    if not IsModelInCdimage(hash) then return false end
    RequestModel(hash)
    local t = GetGameTimer() + 5000
    while not HasModelLoaded(hash) and GetGameTimer() < t do
        Wait(10)
    end
    return HasModelLoaded(hash)
end

local function clearTargets(entity)
    if entity and DoesEntityExist(entity) then
        pcall(function()
            exports['qb-target']:RemoveTargetEntity(entity)
        end)
    end
end

local function deletePiece(furnitureId)
    local ent = spawned[furnitureId]
    if ent and DoesEntityExist(ent) then
        clearTargets(ent)
        DeleteEntity(ent)
    end
    spawned[furnitureId] = nil
end

local function unloadAll()
    for id in pairs(spawned) do
        deletePiece(id)
    end
    spawned = {}
    currentPropertyId = nil
    canManage = false
end

local function standUp()
    local ped = PlayerPedId()
    ClearPedTasks(ped)
    FreezeEntityPosition(ped, false)
end

local function attachTargets(entity, row)
    if not entity or not DoesEntityExist(entity) then return end
    local entry = FPMFurniture.GetEntry(row.item_key)
    if not entry then return end
    local interact = entry.interact or 'none'
    local options = {}

    if interact == 'chair' or interact == 'sofa' then
        options[#options + 1] = {
            icon = 'fas fa-chair',
            label = 'Atsisėsti',
            action = function()
                local ped = PlayerPedId()
                local coords = GetEntityCoords(entity)
                local heading = GetEntityHeading(entity)
                TaskStartScenarioAtPosition(
                    ped,
                    interact == 'sofa' and 'PROP_HUMAN_SEAT_SOFA' or 'PROP_HUMAN_SEAT_CHAIR',
                    coords.x, coords.y, coords.z + 0.45,
                    heading, 0, true, false
                )
            end,
        }
        options[#options + 1] = {
            icon = 'fas fa-person-walking',
            label = 'Atsikelti',
            action = function() standUp() end,
        }
    elseif interact == 'bed' then
        options[#options + 1] = {
            icon = 'fas fa-bed',
            label = 'Atsigulti',
            action = function()
                local ped = PlayerPedId()
                local coords = GetEntityCoords(entity)
                local heading = GetEntityHeading(entity)
                TaskStartScenarioAtPosition(ped, 'WORLD_HUMAN_SUNBATHE_BACK', coords.x, coords.y, coords.z + 0.3, heading, 0, true, false)
            end,
        }
        options[#options + 1] = {
            icon = 'fas fa-person-walking',
            label = 'Atsikelti',
            action = function() standUp() end,
        }
    elseif interact == 'tv' then
        options[#options + 1] = {
            icon = 'fas fa-tv',
            label = 'Žiūrėti televizorių',
            action = function()
                local ped = PlayerPedId()
                TaskStartScenarioInPlace(ped, 'PROP_HUMAN_MOVIE_BULB', 0, true)
                QBCore.Functions.Notify('Žiūrite televizorių…', 'primary')
            end,
        }
        options[#options + 1] = {
            icon = 'fas fa-power-off',
            label = 'Išjungti / atsikelti',
            action = function() standUp() end,
        }
    elseif interact == 'wardrobe' then
        options[#options + 1] = {
            icon = 'fas fa-shirt',
            label = 'Atidaryti spintą',
            action = function()
                TriggerEvent('qb-clothing:client:openOutfitMenu')
            end,
        }
    elseif interact == 'safe' then
        options[#options + 1] = {
            icon = 'fas fa-vault',
            label = 'Atidaryti seifą',
            action = function()
                if not currentPropertyId then return end
                TriggerServerEvent('mrp_furniture:server:openSafe', currentPropertyId, row.id)
            end,
        }
    end

    if canManage then
        options[#options + 1] = {
            icon = 'fas fa-hand',
            label = 'Paimti baldą',
            action = function()
                if not currentPropertyId then return end
                TriggerServerEvent('mrp_furniture:server:pickup', currentPropertyId, row.id)
            end,
        }
    end

    if #options == 0 then return end
    exports['qb-target']:AddTargetEntity(entity, {
        options = options,
        distance = 2.0,
    })
end

local function spawnPiece(row)
    if not row or spawned[row.id] then return end
    local entry = FPMFurniture.GetEntry(row.item_key)
    if not entry then return end
    local model = entry.model
    if not loadModel(model) then return end

    local obj = CreateObject(model, row.x, row.y, row.z, false, false, false)
    SetEntityHeading(obj, row.rz or 0.0)
    FreezeEntityPosition(obj, true)
    SetEntityAsMissionEntity(obj, true, true)
    SetModelAsNoLongerNeeded(model)
    spawned[row.id] = obj
    attachTargets(obj, row)
end

local function loadProperty(data)
    unloadAll()
    if not data or not data.propertyId then return end
    currentPropertyId = data.propertyId
    canManage = data.canManage == true

    QBCore.Functions.TriggerCallback('mrp_furniture:server:getPropertyFurniture', function(list)
        if currentPropertyId ~= data.propertyId then return end
        for _, row in ipairs(list or {}) do
            spawnPiece(row)
        end
    end, data.propertyId)
end

RegisterNetEvent('mrp_furniture:client:loadProperty', function(data)
    loadProperty(data)
end)

--- Also listen as AddEventHandler for TriggerEvent from housing
AddEventHandler('mrp_furniture:client:loadProperty', function(data)
    loadProperty(data)
end)

RegisterNetEvent('mrp_furniture:client:unloadProperty', function()
    unloadAll()
end)

AddEventHandler('mrp_furniture:client:unloadProperty', function()
    unloadAll()
end)

RegisterNetEvent('mrp_furniture:client:addPiece', function(propertyId, row)
    if currentPropertyId ~= propertyId or not row then return end
    spawnPiece(row)
end)

RegisterNetEvent('mrp_furniture:client:removePiece', function(propertyId, furnitureId)
    if currentPropertyId ~= propertyId then return end
    deletePiece(furnitureId)
end)

local function stopPlace(refund)
    if placing and placing.entity and DoesEntityExist(placing.entity) then
        DeleteEntity(placing.entity)
    end
    placing = nil
end

local function finishPlace()
    if not placing or not currentPropertyId then
        stopPlace()
        return
    end
    local ent = placing.entity
    if not ent or not DoesEntityExist(ent) then
        stopPlace()
        return
    end
    local coords = GetEntityCoords(ent)
    local heading = GetEntityHeading(ent)
    local key = placing.key
    local slot = placing.slot
    DeleteEntity(ent)
    placing = nil
    TriggerServerEvent('mrp_furniture:server:place', currentPropertyId, key, {
        x = coords.x, y = coords.y, z = coords.z,
    }, heading, slot)
end

RegisterNetEvent('mrp_furniture:client:startPlace', function(itemKey, slot)
    if placing then
        return QBCore.Functions.Notify('Jau statote baldą.', 'error')
    end
    if not currentPropertyId then
        return QBCore.Functions.Notify('Baldus galima statyti tik savo būste.', 'error')
    end
    if not canManage then
        return QBCore.Functions.Notify('Neturite teisės statyti baldų.', 'error')
    end
    local entry = FPMFurniture.GetEntry(itemKey)
    if not entry then return end
    if not loadModel(entry.model) then
        return QBCore.Functions.Notify('Nepavyko užkrauti modelio.', 'error')
    end

    local ped = PlayerPedId()
    local c = GetEntityCoords(ped)
    local obj = CreateObject(entry.model, c.x, c.y, c.z, false, false, false)
    SetEntityCollision(obj, false, false)
    SetEntityAlpha(obj, 180, false)
    FreezeEntityPosition(obj, true)
    placing = { key = itemKey, slot = slot, entity = obj, heading = GetEntityHeading(ped) }
    QBCore.Functions.Notify('Statymas: [E] patvirtinti · [X] atšaukti · [←/→] sukti', 'primary', 7000)

    CreateThread(function()
        local step = (Config.Place and Config.Place.rotateStep) or 15.0
        while placing and placing.entity do
            Wait(0)
            DisableControlAction(0, 24, true)
            DisableControlAction(0, 25, true)
            local hit, _, endCoords = nil, nil, nil
            local camCoord = GetGameplayCamCoord()
            local camRot = GetGameplayCamRot(2)
            local dir = RotationToDirection and RotationToDirection(camRot) or nil
            --- simple ray from player
            local pcoords = GetEntityCoords(PlayerPedId())
            local forward = GetEntityForwardVector(PlayerPedId())
            local dest = pcoords + forward * ((Config.Place and Config.Place.maxDistance) or 8.0)
            local ray = StartShapeTestRay(pcoords.x, pcoords.y, pcoords.z + 0.5, dest.x, dest.y, dest.z - 0.5, -1, PlayerPedId(), 0)
            local _, hitOk, hitCoords = GetShapeTestResult(ray)
            local pos = hitOk == 1 and hitCoords or (pcoords + forward * 2.0)
            SetEntityCoordsNoOffset(placing.entity, pos.x, pos.y, pos.z, false, false, false)
            SetEntityHeading(placing.entity, placing.heading)

            if IsControlJustPressed(0, 174) then -- left
                placing.heading = (placing.heading - step) % 360.0
            elseif IsControlJustPressed(0, 175) then -- right
                placing.heading = (placing.heading + step) % 360.0
            elseif IsControlJustPressed(0, 38) then -- E
                finishPlace()
                break
            elseif IsControlJustPressed(0, 73) then -- X
                stopPlace()
                QBCore.Functions.Notify('Statymas atšauktas.', 'error')
                break
            end
        end
    end)
end)

--- Shop ped
CreateThread(function()
    local shop = Config.Shop
    if not shop or not shop.coords then return end
    local model = joaat(shop.pedModel or 's_m_m_autoshop_02')
    if not loadModel(model) then return end
    local ped = CreatePed(0, model, shop.coords.x, shop.coords.y, shop.coords.z - 1.0, shop.coords.w or 0.0, false, true)
    SetEntityAsMissionEntity(ped, true, true)
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetModelAsNoLongerNeeded(model)

    if shop.blip then
        local blip = AddBlipForCoord(shop.coords.x, shop.coords.y, shop.coords.z)
        SetBlipSprite(blip, shop.blip.sprite or 566)
        SetBlipColour(blip, shop.blip.color or 5)
        SetBlipScale(blip, shop.blip.scale or 0.8)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName(shop.label or 'Baldų parduotuvė')
        EndTextCommandSetBlipName(blip)
    end

    exports['qb-target']:AddTargetEntity(ped, {
        options = {
            {
                icon = 'fas fa-couch',
                label = 'Atidaryti baldų parduotuvę',
                action = function()
                    TriggerServerEvent('mrp_furniture:server:openShop')
                end,
            },
        },
        distance = 2.2,
    })
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    unloadAll()
    stopPlace()
end)
