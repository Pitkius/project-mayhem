local QBCore = exports['qb-core']:GetCoreObject()

local Ownership = {}
--- [property_id] = { [citizenid] = true }
local Keys = {}
local insideProperty = nil
local doorZones = {}
local agencyPed = nil
local agencyBlip = nil
local propertyBlips = {}

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

local function myCitizenId()
    local pData = QBCore.Functions.GetPlayerData()
    return pData and pData.citizenid or nil
end

local function isOwner(propertyId)
    local data = Ownership[propertyId]
    if not data then return false end
    return myCitizenId() == data.citizenid
end

local function hasSharedKey(propertyId)
    local cid = myCitizenId()
    if not cid then return false end
    local set = Keys[propertyId]
    return set and set[cid] == true
end

local function canUseStashHere()
    return insideProperty and insideProperty.canUseStash == true
end

local function setBlipLabel(blip, label)
    if GetResourceState('mrp_fonts') == 'started' then
        exports['mrp_fonts']:SetBlipName(blip, label)
    else
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName(label)
        EndTextCommandSetBlipName(blip)
    end
end

local function clearPropertyBlips()
    for _, blip in pairs(propertyBlips) do
        if blip and DoesBlipExist(blip) then RemoveBlip(blip) end
    end
    propertyBlips = {}
end

local function refreshPropertyBlips()
    clearPropertyBlips()
    local cid = myCitizenId()
    if not cid then return end

    local blipCfg = Config.PropertyBlips or {}
    local ownedCfg = blipCfg.owned or { sprite = 40, color = 2, scale = 0.75, labelPrefix = 'Mano' }
    local sharedCfg = blipCfg.shared or { sprite = 40, color = 5, scale = 0.7, labelPrefix = 'Raktas' }

    for i = 1, #(Config.Properties or {}) do
        local prop = Config.Properties[i]
        local owner = Ownership[prop.id]
        local owned = owner and owner.citizenid == cid
        local shared = (not owned) and hasSharedKey(prop.id)
        if owned or shared then
            local cfg = owned and ownedCfg or sharedCfg
            local blip = AddBlipForCoord(prop.door.x, prop.door.y, prop.door.z)
            SetBlipSprite(blip, cfg.sprite or 40)
            SetBlipColour(blip, cfg.color or (owned and 2 or 5))
            SetBlipScale(blip, cfg.scale or 0.75)
            SetBlipAsShortRange(blip, true)
            local prefix = cfg.labelPrefix or (owned and 'Mano' or 'Raktas')
            setBlipLabel(blip, ('%s — %s'):format(prefix, prop.label))
            propertyBlips[prop.id] = blip
        end
    end
end

local function openAgency()
    TriggerServerEvent('mrp_housing:server:requestOpenAgency')
end

local function exitInterior()
    if not insideProperty then return end
    local prop = insideProperty
    insideProperty = nil

    DoScreenFadeOut(400)
    Wait(450)

    TriggerEvent('mrp_furniture:client:unloadProperty')
    TriggerServerEvent('mrp_housing:server:exit', prop.propertyId, prop.propertyIndex)

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
        furnished = data.furnished == true,
        propertyClass = data.propertyClass,
        door = vector4(data.door.x, data.door.y, data.door.z, data.door.w or 0.0),
        label = data.label,
        isOwner = data.isOwner,
        canUseStash = data.canUseStash == true,
        hasKey = data.hasKey == true,
        canManageFurniture = data.canManageFurniture == true,
    }

    Wait(400)
    DoScreenFadeIn(400)
    QBCore.Functions.Notify(('Įėjote: %s'):format(data.label), 'success')
    TriggerEvent('mrp_furniture:client:loadProperty', {
        propertyId = data.propertyId,
        interiorKey = data.interiorKey,
        canManage = data.canManageFurniture == true,
    })
end

local function openWardrobe()
    TriggerEvent('qb-clothing:client:openOutfitMenu')
end

local function giveKeyNearby(propertyId)
    local closestPlayer, distance = QBCore.Functions.GetClosestPlayer()
    local maxDist = Config.KeyShareDistance or 3.0
    if closestPlayer == -1 or not distance or distance > maxDist then
        return QBCore.Functions.Notify('Šalia nėra žaidėjo.', 'error')
    end
    TriggerServerEvent('mrp_housing:server:giveKey', propertyId, GetPlayerServerId(closestPlayer))
end

local function giveKeyById(propertyId)
    if GetResourceState('qb-input') ~= 'started' then
        return QBCore.Functions.Notify('Reikia qb-input.', 'error')
    end
    local input = exports['qb-input']:ShowInput({
        header = 'Duoti namo raktą',
        submitText = 'Duoti',
        inputs = {
            { text = 'Žaidėjo serverio ID', name = 'id', type = 'number', isRequired = true },
        },
    })
    if not input or not input.id then return end
    TriggerServerEvent('mrp_housing:server:giveKey', propertyId, tonumber(input.id))
end

local function openRevokeMenu(propertyId)
    if GetResourceState('qb-menu') ~= 'started' then
        return QBCore.Functions.Notify('Reikia qb-menu.', 'error')
    end
    QBCore.Functions.TriggerCallback('mrp_housing:server:getKeyHolders', function(holders)
        local menu = {
            { header = 'Atšaukti raktą', isMenuHeader = true },
        }
        if not holders or #holders == 0 then
            menu[#menu + 1] = {
                header = 'Nėra išdalintų raktų',
                txt = 'Dar niekam nedavėte rakto',
                disabled = true,
            }
        else
            for _, h in ipairs(holders) do
                menu[#menu + 1] = {
                    header = h.name or h.citizenid,
                    txt = h.online and 'Prisijungęs' or 'Neprisijungęs',
                    params = {
                        isAction = true,
                        event = function()
                            TriggerServerEvent('mrp_housing:server:revokeKey', propertyId, h.citizenid)
                        end,
                    },
                }
            end
        end
        menu[#menu + 1] = { header = '« Atgal', params = { event = 'mrp_housing:client:manageKeys', args = { propertyId = propertyId } } }
        TriggerEvent('qb-menu:client:openMenu', menu, false, true)
    end, propertyId)
end

local function openKeysMenu(propertyId)
    if not isOwner(propertyId) then
        return QBCore.Functions.Notify('Tik savininkas gali valdyti raktus.', 'error')
    end
    if GetResourceState('qb-menu') ~= 'started' then
        return QBCore.Functions.Notify('Reikia qb-menu.', 'error')
    end
    local prop = FPMHousing.GetProperty(propertyId)
    local title = prop and prop.label or 'Namai'
    TriggerEvent('qb-menu:client:openMenu', {
        { header = ('Raktai — %s'):format(title), isMenuHeader = true },
        {
            header = 'Duoti raktą artimiausiam',
            txt = ('Iki %.0f m'):format(Config.KeyShareDistance or 3.0),
            icon = 'fas fa-key',
            params = {
                isAction = true,
                event = function()
                    giveKeyNearby(propertyId)
                end,
            },
        },
        {
            header = 'Duoti raktą pagal ID',
            txt = 'Įveskite žaidėjo serverio ID',
            icon = 'fas fa-id-card',
            params = {
                isAction = true,
                event = function()
                    giveKeyById(propertyId)
                end,
            },
        },
        {
            header = 'Atšaukti raktą…',
            txt = 'Pašalinti prieigą',
            icon = 'fas fa-user-slash',
            params = {
                isAction = true,
                event = function()
                    openRevokeMenu(propertyId)
                end,
            },
        },
        { header = 'Uždaryti', params = { event = 'qb-menu:client:closeMenu' } },
    }, false, true)
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
                    event = 'mrp_housing:client:doorEnter',
                    icon = 'fas fa-door-open',
                    label = 'Įeiti į vidų',
                    propertyId = prop.id,
                    canInteract = function()
                        return Ownership[prop.id] ~= nil
                    end,
                },
                {
                    type = 'client',
                    event = 'mrp_housing:client:toggleLock',
                    icon = 'fas fa-lock',
                    label = 'Užrakinti / atrakinti',
                    propertyId = prop.id,
                    canInteract = function()
                        return isOwner(prop.id)
                    end,
                },
                {
                    type = 'client',
                    event = 'mrp_housing:client:manageKeys',
                    icon = 'fas fa-key',
                    label = 'Dalintis raktais',
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

RegisterNetEvent('mrp_housing:client:syncOwnership', function(data)
    Ownership = data or {}
    registerDoorTargets()
    refreshPropertyBlips()
end)

RegisterNetEvent('mrp_housing:client:syncKeys', function(data)
    Keys = data or {}
    refreshPropertyBlips()
    --- Serveris išmeta atšauktą raktininką; čia tik atnaujinam sandėlio teisę
    if insideProperty then
        local pid = insideProperty.propertyId
        local owned = isOwner(pid)
        insideProperty.isOwner = owned
        insideProperty.hasKey = hasSharedKey(pid)
        insideProperty.canUseStash = owned or insideProperty.hasKey
    end
end)

RegisterNetEvent('mrp_housing:client:openAgency', function(payload)
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open', data = payload })
end)

RegisterNetEvent('mrp_housing:client:enterInterior', function(data)
    enterInterior(data)
end)

RegisterNetEvent('mrp_housing:client:forceExit', function(reason)
    if reason then
        QBCore.Functions.Notify(reason, 'error')
    end
    if insideProperty then
        exitInterior()
    end
end)

RegisterNUICallback('close', function(_, cb)
    SetNuiFocus(false, false)
    cb('ok')
end)

RegisterNUICallback('purchase', function(body, cb)
    QBCore.Functions.TriggerCallback('mrp_housing:server:purchase', function(result)
        if result and result.ok then
            QBCore.Functions.Notify(result.msg, 'success')
            if result.catalog then
                SendNUIMessage({ action = 'refresh', data = { properties = result.catalog } })
            end
        else
            QBCore.Functions.Notify(result and result.msg or 'Pirkimas nepavyko.', 'error')
        end
        cb(result or { ok = false })
    end, body.propertyId, body.interiorKey, body.furnished == true)
end)

RegisterNUICallback('setWaypoint', function(body, cb)
    local prop = FPMHousing.GetProperty(body.propertyId)
    if prop then
        SetNewWaypoint(prop.door.x, prop.door.y)
        QBCore.Functions.Notify('GPS nustatytas į objektą.', 'primary')
    end
    cb('ok')
end)

RegisterNetEvent('mrp_housing:client:doorEnter', function(data)
    local propertyId = data and data.propertyId
    if not propertyId then return end
    TriggerServerEvent('mrp_housing:server:enter', propertyId)
end)

RegisterNetEvent('mrp_housing:client:toggleLock', function(data)
    local propertyId = data and data.propertyId
    if propertyId then
        TriggerServerEvent('mrp_housing:server:toggleLock', propertyId)
    end
end)

RegisterNetEvent('mrp_housing:client:manageKeys', function(data)
    local propertyId = data and data.propertyId
    if propertyId then
        openKeysMenu(propertyId)
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
                    event = 'mrp_housing:client:openAgencyTarget',
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
        setBlipLabel(agencyBlip, agency.label or 'Dynasty 8')
    end

    QBCore.Functions.TriggerCallback('mrp_housing:server:getOwnership', function(data)
        Ownership = data or {}
        registerDoorTargets()
        QBCore.Functions.TriggerCallback('mrp_housing:server:getKeys', function(keyData)
            Keys = keyData or {}
            refreshPropertyBlips()
        end)
    end)
end)

RegisterNetEvent('mrp_housing:client:openAgencyTarget', function()
    openAgency()
end)

--- Po personažo užkrovimo — atnaujinti blipus (citizenid jau žinomas)
RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    Wait(500)
    QBCore.Functions.TriggerCallback('mrp_housing:server:getOwnership', function(data)
        Ownership = data or {}
        registerDoorTargets()
        QBCore.Functions.TriggerCallback('mrp_housing:server:getKeys', function(keyData)
            Keys = keyData or {}
            refreshPropertyBlips()
        end)
    end)
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

                if canUseStashHere() and interior.stash then
                    if #(pCoords - interior.stash) < 1.5 then
                        local stashLabel = '[F2] Sandėliukas'
                        if GetResourceState('mrp_npcshops') == 'started' then
                            stashLabel = exports['mrp_npcshops']:StashInteractHint('Sandėliukas')
                            exports['mrp_npcshops']:EnableStashOpenControl()
                        else
                            EnableControlAction(0, 289, true)
                        end
                        DrawText3D(interior.stash.x, interior.stash.y, interior.stash.z + 0.25, stashLabel)
                        local pressed = GetResourceState('mrp_npcshops') == 'started'
                            and exports['mrp_npcshops']:IsStashOpenPressed()
                            or (IsControlJustReleased(0, 289) or IsDisabledControlJustPressed(0, 289))
                        if pressed then
                            TriggerServerEvent('mrp_housing:server:openStash', insideProperty.propertyId)
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
    if GetResourceState('mrp_fonts') == 'started' then
        exports['mrp_fonts']:DrawText3D(x, y, z, text, { scale = 0.32, background = false })
        return
    end
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
    clearPropertyBlips()
    SetNuiFocus(false, false)
end)
