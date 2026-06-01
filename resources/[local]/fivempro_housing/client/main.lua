local QBCore = exports['qb-core']:GetCoreObject()

local Ownership = {}
local insideProperty = nil
local doorZones = {}
local agencyPed = nil
local agencyBlip = nil

local function loadModel(model)
    local hash = type(model) == 'string' and joaat(model) or model
    if not IsModelInCdimage(hash) then return nil end
    RequestModel(hash)
    while not HasModelLoaded(hash) do Wait(0) end
    return hash
end

local function setupPed(ped)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    FreezeEntityPosition(ped, true)
end

local function isOwner(propertyId)
    local data = Ownership[propertyId]
    if not data then return false end
    local pData = QBCore.Functions.GetPlayerData()
    return pData and pData.citizenid == data.citizenid
end

local function getOwner(propertyId)
    return Ownership[propertyId]
end

local function openAgency()
    TriggerServerEvent('fivempro_housing:server:requestOpenAgency')
end

local function exitInterior()
    if not insideProperty then return end
    local prop = insideProperty
    insideProperty = nil

    DoScreenFadeOut(400)
    Wait(450)

    TriggerServerEvent('fivempro_housing:server:exit', prop.propertyId, prop.propertyIndex)

    local ped = PlayerPedId()
    SetEntityCoordsNoOffset(ped, prop.door.x, prop.door.y, prop.door.z, false, false, false)
    SetEntityHeading(ped, prop.door.w or 0.0)

    Wait(300)
    DoScreenFadeIn(400)
end

local function prepareInteriorAtCoords(x, y, z)
    local interiorId = GetInteriorAtCoords(x, y, z)
    if interiorId and interiorId ~= 0 then
        PinInteriorInMemory(interiorId)
        LoadInterior(interiorId)
        RefreshInterior(interiorId)
    end
end

local function enterInterior(data)
    local interior = Config.Interiors[data.interiorKey]
    if not interior then return end

    prepareInteriorAtCoords(interior.enter.x, interior.enter.y, interior.enter.z)

    DoScreenFadeOut(400)
    Wait(450)

    local ped = PlayerPedId()
    SetEntityCoordsNoOffset(ped, interior.enter.x, interior.enter.y, interior.enter.z, false, false, false)
    SetEntityHeading(ped, interior.enter.w or 0.0)

    insideProperty = {
        propertyId = data.propertyId,
        propertyIndex = data.propertyIndex,
        interiorKey = data.interiorKey,
        door = vector4(data.door.x, data.door.y, data.door.z, data.door.w or 0.0),
        label = data.label,
        isOwner = data.isOwner,
    }

    Wait(400)
    DoScreenFadeIn(400)
    QBCore.Functions.Notify(('Įėjote: %s'):format(data.label), 'success')
end

local function openWardrobe()
    TriggerEvent('qb-clothing:client:openOutfitMenu')
end

local function registerDoorTargets()
    for _, z in ipairs(doorZones) do
        if z then exports['qb-target']:RemoveZone(z) end
    end
    doorZones = {}

    for i = 1, #(Config.Properties or {}) do
        local prop = Config.Properties[i]
        local zoneName = ('fpmho_door_%s'):format(prop.id)
        exports['qb-target']:AddBoxZone(zoneName, vector3(prop.door.x, prop.door.y, prop.door.z), 1.2, 1.2, {
            name = zoneName,
            heading = prop.door.w or 0.0,
            minZ = prop.door.z - 1.0,
            maxZ = prop.door.z + 1.5,
            debugPoly = false,
        }, {
            options = {
                {
                    type = 'client',
                    event = 'fivempro_housing:client:doorEnter',
                    icon = 'fas fa-door-open',
                    label = 'Įeiti į vidų',
                    propertyId = prop.id,
                    canInteract = function()
                        return Ownership[prop.id] ~= nil
                    end,
                },
                {
                    type = 'client',
                    event = 'fivempro_housing:client:toggleLock',
                    icon = 'fas fa-lock',
                    label = 'Raktai / užraktas',
                    propertyId = prop.id,
                    canInteract = function()
                        return isOwner(prop.id)
                    end,
                },
            },
            distance = 2.0,
        })
        doorZones[#doorZones + 1] = zoneName
    end
end

RegisterNetEvent('fivempro_housing:client:syncOwnership', function(data)
    Ownership = data or {}
    registerDoorTargets()
end)

RegisterNetEvent('fivempro_housing:client:openAgency', function(payload)
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open', data = payload })
end)

RegisterNetEvent('fivempro_housing:client:enterInterior', function(data)
    enterInterior(data)
end)

RegisterNUICallback('close', function(_, cb)
    SetNuiFocus(false, false)
    cb('ok')
end)

RegisterNUICallback('purchase', function(body, cb)
    QBCore.Functions.TriggerCallback('fivempro_housing:server:purchase', function(result)
        if result and result.ok then
            QBCore.Functions.Notify(result.msg, 'success')
            if result.catalog then
                SendNUIMessage({ action = 'refresh', data = { properties = result.catalog } })
            end
        else
            QBCore.Functions.Notify(result and result.msg or 'Pirkimas nepavyko.', 'error')
        end
        cb(result or { ok = false })
    end, body.propertyId, body.interiorKey)
end)

RegisterNUICallback('setWaypoint', function(body, cb)
    local prop = FPMHousing.GetProperty(body.propertyId)
    if prop then
        SetNewWaypoint(prop.door.x, prop.door.y)
        QBCore.Functions.Notify('GPS nustatytas į objektą.', 'primary')
    end
    cb('ok')
end)

RegisterNetEvent('fivempro_housing:client:doorEnter', function(data)
    local propertyId = data and data.propertyId
    if not propertyId then return end
    TriggerServerEvent('fivempro_housing:server:enter', propertyId)
end)

RegisterNetEvent('fivempro_housing:client:toggleLock', function(data)
    local propertyId = data and data.propertyId
    if propertyId then
        TriggerServerEvent('fivempro_housing:server:toggleLock', propertyId)
    end
end)

CreateThread(function()
    for _, ipl in ipairs({ 'apa_v_mp_h_01_a', 'apa_v_mp_h_01_b', 'apa_v_mp_h_01_c' }) do
        RequestIpl(ipl)
    end
end)

CreateThread(function()
    local agency = Config.Agency
    local hash = loadModel(agency.pedModel)
    if hash then
        local c = agency.coords
        agencyPed = CreatePed(0, hash, c.x, c.y, c.z - 1.0, c.w, false, false)
        SetEntityCoordsNoOffset(agencyPed, c.x, c.y, c.z, false, false, false)
        SetEntityHeading(agencyPed, c.w)
        if agency.scenario then
            TaskStartScenarioInPlace(agencyPed, agency.scenario, 0, true)
        end
        setupPed(agencyPed)
        SetModelAsNoLongerNeeded(hash)

        exports['qb-target']:AddTargetEntity(agencyPed, {
            options = {
                {
                    type = 'client',
                    event = 'fivempro_housing:client:openAgencyTarget',
                    icon = 'fas fa-building',
                    label = 'Dynasty 8 — nekilnojamasis turtas',
                },
            },
            distance = agency.targetDistance or 2.2,
        })
    end

    if agency.blip then
        agencyBlip = AddBlipForCoord(agency.coords.x, agency.coords.y, agency.coords.z)
        SetBlipSprite(agencyBlip, agency.blip.sprite or 374)
        SetBlipColour(agencyBlip, agency.blip.color or 2)
        SetBlipScale(agencyBlip, agency.blip.scale or 0.85)
        SetBlipAsShortRange(agencyBlip, true)
        exports['fivempro_fonts']:SetBlipName(agencyBlip, agency.label or 'Dynasty 8')
    end

    QBCore.Functions.TriggerCallback('fivempro_housing:server:getOwnership', function(data)
        Ownership = data or {}
        registerDoorTargets()
    end)
end)

RegisterNetEvent('fivempro_housing:client:openAgencyTarget', function()
    openAgency()
end)

CreateThread(function()
    while true do
        local sleep = 1000
        if insideProperty then
            sleep = 0
            local interior = Config.Interiors[insideProperty.interiorKey]
            if interior then
                local ped = PlayerPedId()
                local pCoords = GetEntityCoords(ped)

                local exitPos = vector3(
                    interior.enter.x + (interior.exitOffset and interior.exitOffset.x or 1.0),
                    interior.enter.y + (interior.exitOffset and interior.exitOffset.y or 0.0),
                    interior.enter.z + (interior.exitOffset and interior.exitOffset.z or 0.0)
                )
                if #(pCoords - exitPos) < 1.6 then
                    DrawText3D(exitPos.x, exitPos.y, exitPos.z + 0.35, '[E] Išeiti')
                    if IsControlJustReleased(0, 38) then
                        exitInterior()
                    end
                end

                if insideProperty.isOwner and interior.stash then
                    if #(pCoords - interior.stash) < 1.5 then
                        DrawText3D(interior.stash.x, interior.stash.y, interior.stash.z + 0.25, '[E] Sandėliukas')
                        if IsControlJustReleased(0, 38) then
                            TriggerServerEvent('fivempro_housing:server:openStash', insideProperty.propertyId)
                        end
                    end
                end

                if interior.hasWardrobe == true and interior.wardrobe and #(pCoords - interior.wardrobe) < 1.5 then
                    DrawText3D(interior.wardrobe.x, interior.wardrobe.y, interior.wardrobe.z + 0.25, '[E] Drabužinė')
                    if IsControlJustReleased(0, 38) then
                        openWardrobe()
                    end
                end
            end
        end
        Wait(sleep)
    end
end)

function DrawText3D(x, y, z, text)
    SetTextScale(0.32, 0.32)
    SetTextFont(4)
    SetTextProportional(1)
    SetTextColour(255, 255, 255, 215)
    SetTextCentre(true)
    SetTextEntry('STRING')
    AddTextComponentString(text)
    SetDrawOrigin(x, y, z, 0)
    DrawText(0.0, 0.0)
    ClearDrawOrigin()
end

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if insideProperty then
        local ped = PlayerPedId()
        SetEntityCoordsNoOffset(ped, insideProperty.door.x, insideProperty.door.y, insideProperty.door.z, false, false, false)
        insideProperty = nil
    end
    if agencyPed and DoesEntityExist(agencyPed) then DeleteEntity(agencyPed) end
    if agencyBlip then RemoveBlip(agencyBlip) end
    SetNuiFocus(false, false)
end)
