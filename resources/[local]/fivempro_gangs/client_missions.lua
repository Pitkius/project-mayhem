local QBCore = exports['qb-core']:GetCoreObject()

local missionBlip = nil
local missionData = nil
local missionEntities = {}
local pickupTargetZone = nil
local dropTargetZone = nil
local missionBusy = false

local INTERACT = Config.MissionInteractDistance or 4.5
local DROP_DIST = Config.MissionDropDistance or 15.0
local MARKER_DIST = Config.MissionMarkerDrawDistance or 90.0

local function drawText3D(x, y, z, text)
    if GetResourceState('fivempro_fonts') == 'started' then
        exports['fivempro_fonts']:DrawText3D(x, y, z, text)
    else
        SetTextScale(0.35, 0.35)
        SetTextFont(4)
        SetTextProportional(true)
        SetTextColour(255, 255, 255, 215)
        SetTextEntry('STRING')
        SetTextCentre(true)
        AddTextComponentString(text)
        SetDrawOrigin(x, y, z, 0)
        DrawText(0.0, 0.0)
        ClearDrawOrigin()
    end
end

local function loadModel(model)
    local hash = type(model) == 'number' and model or joaat(model)
    if not IsModelInCdimage(hash) then return nil end
    RequestModel(hash)
    local deadline = GetGameTimer() + 5000
    while not HasModelLoaded(hash) and GetGameTimer() < deadline do
        Wait(10)
    end
    if not HasModelLoaded(hash) then return nil end
    return hash
end

local function removeTargetZone(name)
    if not name or GetResourceState('qb-target') ~= 'started' then return end
    pcall(function()
        exports['qb-target']:RemoveZone(name)
    end)
end

local function clearMissionEntities()
    removeTargetZone(pickupTargetZone)
    removeTargetZone(dropTargetZone)
    pickupTargetZone = nil
    dropTargetZone = nil
    for _, ent in ipairs(missionEntities) do
        if ent and DoesEntityExist(ent) then
            DeleteEntity(ent)
        end
    end
    missionEntities = {}
end

local function clearMission()
    clearMissionEntities()
    missionBusy = false
    if missionBlip and DoesBlipExist(missionBlip) then
        RemoveBlip(missionBlip)
    end
    missionBlip = nil
    missionData = nil
end

local function setMissionBlip(coords, label)
    if missionBlip and DoesBlipExist(missionBlip) then RemoveBlip(missionBlip) end
    missionBlip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(missionBlip, 1)
    SetBlipColour(missionBlip, 27)
    SetBlipRoute(missionBlip, true)
    exports['fivempro_fonts']:SetBlipName(missionBlip, label or 'Misija')
end

local function getCurrentTurfId()
    local p = GetEntityCoords(PlayerPedId())
    return Config.FindTurfAt(p.x, p.y)
end

local function runProgress(ms, label)
    return GangRunProgressSync('gang_mission', label, ms)
end

local function finishStep(token, step)
    QBCore.Functions.TriggerCallback('fivempro_gangs:server:finishMissionStep', function(res)
        missionBusy = false
        if not res or not res.ok then
            QBCore.Functions.Notify((res and res.reason) or 'Misija nepavyko.', 'error')
            TriggerServerEvent('fivempro_gangs:server:cancelMission')
            clearMission()
            return
        end
        if res.done then
            QBCore.Functions.Notify('Misija įvykdyta.', 'success')
            clearMission()
            return
        end
        if missionData and res.nextStep == 2 then
            missionData.step = 2
            clearMissionEntities()
            if missionData.dropInTurf ~= false then
                setMissionBlip(missionData.drop, 'Pristatymas į turf')
                QBCore.Functions.Notify('Nuvežk krovinį į turf centrą — [E] pristatymo taške', 'primary')
            else
                if missionBlip and DoesBlipExist(missionBlip) then
                    RemoveBlip(missionBlip)
                    missionBlip = nil
                end
                QBCore.Functions.Notify('Krovinys paimtas — [E] užbaigti misiją', 'primary')
            end
        end
    end, token, step)
end

local function tryPickup()
    if missionBusy or not missionData or missionData.step ~= 1 or missionData.hacking then return end
    local ped = PlayerPedId()
    local dist = #(GetEntityCoords(ped) - missionData.pickup)
    if dist > INTERACT then
        return QBCore.Functions.Notify('Per toli nuo paėmimo taško.', 'error')
    end
    if missionData.requireVehicle and not IsPedInAnyVehicle(ped, false) then
        return QBCore.Functions.Notify('Įsėsk į transportą ir bandyk dar kartą.', 'error')
    end
    missionBusy = true
    if runProgress(missionData.durationMs or 7000, 'Renkamas krovinys…') then
        finishStep(missionData.token, 1)
    else
        missionBusy = false
        TriggerServerEvent('fivempro_gangs:server:cancelMission')
        clearMission()
    end
end

local function tryDrop()
    if missionBusy or not missionData or missionData.step ~= 2 or missionData.hacking then return end
    local ped = PlayerPedId()
    if missionData.dropInTurf ~= false then
        local dist = #(GetEntityCoords(ped) - missionData.drop)
        if dist > DROP_DIST then
            return QBCore.Functions.Notify('Per toli nuo pristatymo taško.', 'error')
        end
    end
    if missionData.requireVehicle and not IsPedInAnyVehicle(ped, false) then
        return QBCore.Functions.Notify('Reikia transporto.', 'error')
    end
    missionBusy = true
    if runProgress(missionData.durationMs or 7000, 'Pristatoma…') then
        finishStep(missionData.token, 2)
    else
        missionBusy = false
        TriggerServerEvent('fivempro_gangs:server:cancelMission')
        clearMission()
    end
end

local function addPickupTarget()
    if GetResourceState('qb-target') ~= 'started' or not missionData or not missionData.pickup then return end
    pickupTargetZone = 'gang_mission_pickup'
    exports['qb-target']:AddCircleZone(pickupTargetZone, missionData.pickup, 2.0, {
        name = pickupTargetZone,
        debugPoly = false,
        useZ = true,
    }, {
        options = {
            {
                icon = 'fas fa-box',
                label = 'Paimti krovinį',
                action = tryPickup,
            },
        },
        distance = INTERACT,
    })
end

local function spawnMissionWorld(missionType, pickup, heading, siteVehicle)
    clearMissionEntities()
    local visual = Config.MissionVisuals and Config.MissionVisuals[missionType]
    local mCfg = Config.MissionTypes and Config.MissionTypes[missionType]
    heading = heading or 0.0

    if mCfg and mCfg.requireVehicle then
        local model = siteVehicle or 'burrito3'
        local hash = loadModel(model)
        if hash then
            local veh = CreateVehicle(hash, pickup.x, pickup.y, pickup.z, heading, true, false)
            SetEntityAsMissionEntity(veh, true, true)
            SetVehicleOnGroundProperly(veh)
            SetVehicleEngineOn(veh, true, true, false)
            SetVehicleDoorsLocked(veh, 1)
            missionEntities[#missionEntities + 1] = veh
        end
    elseif visual and visual.prop then
        local hash = loadModel(visual.prop)
        if hash then
            local obj = CreateObject(hash, pickup.x, pickup.y, pickup.z - 1.0, false, false, false)
            SetEntityHeading(obj, heading)
            PlaceObjectOnGroundProperly(obj)
            FreezeEntityPosition(obj, true)
            missionEntities[#missionEntities + 1] = obj
        end
    elseif visual and visual.ped then
        local hash = loadModel(visual.ped)
        if hash then
            local npc = CreatePed(4, hash, pickup.x, pickup.y, pickup.z - 1.0, heading, false, true)
            SetEntityInvincible(npc, true)
            SetBlockingOfNonTemporaryEvents(npc, true)
            FreezeEntityPosition(npc, true)
            if visual.scenario then
                TaskStartScenarioInPlace(npc, visual.scenario, 0, true)
            end
            missionEntities[#missionEntities + 1] = npc
            if GetResourceState('qb-target') == 'started' then
                exports['qb-target']:AddTargetEntity(npc, {
                    options = {
                        {
                            icon = 'fas fa-hand-holding-usd',
                            label = 'Paimti krovinį',
                            action = tryPickup,
                        },
                    },
                    distance = INTERACT,
                })
            end
        end
    end

    addPickupTarget()
end

local function drawMissionMarker(coords, r, g, b, label)
    DrawMarker(
        1, coords.x, coords.y, coords.z - 1.0,
        0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
        2.2, 2.2, 1.0,
        r, g, b, 140,
        false, false, 2, false, nil, nil, false
    )
    if label then
        drawText3D(coords.x, coords.y, coords.z + 1.1, label)
    end
end

local function startMissionAt(turfId, missionType)
    QBCore.Functions.TriggerCallback('fivempro_gangs:server:startMission', function(res)
        if not res or not res.ok then
            return QBCore.Functions.Notify((res and res.reason) or 'Negalima pradėti.', 'error')
        end
        if missionType == 'hacking' then
            missionData = { token = res.token, step = 1, hacking = true }
            return QBCore.Functions.Notify('Atlik sėkmingą hack — turf progresas bus priskirtas.', 'primary')
        end
        missionData = {
            token = res.token,
            step = 1,
            missionType = res.missionType or missionType,
            pickup = vector3(res.pickup.x, res.pickup.y, res.pickup.z),
            drop = vector3(res.drop.x, res.drop.y, res.drop.z),
            durationMs = res.durationMs or 7000,
            requireVehicle = res.requireVehicle == true,
            dropInTurf = res.dropInTurf ~= false,
            siteLabel = res.siteLabel,
        }
        spawnMissionWorld(missionData.missionType, missionData.pickup, res.heading or 0.0, res.siteVehicle)
        local blipLabel = res.siteLabel and ('Paėmimas: ' .. res.siteLabel) or res.label
        setMissionBlip(missionData.pickup, blipLabel)
        local hint = res.requireVehicle and 'įsėsk į transportą ir [E]' or '[E]'
        QBCore.Functions.Notify(('Misija: %s — %s paėmimo taške'):format(res.label, hint), 'success')
    end, turfId, missionType)
end

RegisterNetEvent('fivempro_gangs:client:startMission', function(turfId, missionType)
    startMissionAt(turfId, missionType)
end)

RegisterCommand('gangmission', function(_, args)
    local turfId = getCurrentTurfId()
    if not turfId then
        return QBCore.Functions.Notify('Stovėk turf zonoje.', 'error')
    end
    startMissionAt(turfId, tostring(args[1] or 'smuggle'))
end, false)

RegisterCommand('gangmissiondrop', function()
    tryDrop()
end, false)

CreateThread(function()
    while true do
        local sleep = 1000
        if missionData and not missionData.hacking then
            local ped = PlayerPedId()
            local pos = GetEntityCoords(ped)

            if missionData.step == 1 and missionData.pickup then
                local dist = #(pos - missionData.pickup)
                if dist < MARKER_DIST then
                    sleep = 0
                    drawMissionMarker(missionData.pickup, 59, 130, 246, '[E] Paimti krovinį')
                    if dist < INTERACT and IsControlJustReleased(0, 38) and not missionBusy then
                        tryPickup()
                    end
                end
            elseif missionData.step == 2 then
                sleep = 0
                if missionData.dropInTurf ~= false and missionData.drop then
                    local dist = #(pos - missionData.drop)
                    if dist < MARKER_DIST then
                        drawMissionMarker(missionData.drop, 34, 197, 94, '[E] Pristatyti krovinį')
                        if dist < DROP_DIST and IsControlJustReleased(0, 38) and not missionBusy then
                            tryDrop()
                        end
                    end
                elseif IsControlJustReleased(0, 38) and not missionBusy then
                    tryDrop()
                end
            end
        end
        Wait(sleep)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    clearMission()
end)
