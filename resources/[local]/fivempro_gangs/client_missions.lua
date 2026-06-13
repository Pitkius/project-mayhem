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

local PICKUP_ANIM = { dict = 'random@domestic', clip = 'pickup_low', flag = 1 }
local DROP_ANIM = { dict = 'mp_common', clip = 'givetake1_a', flag = 1 }

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

local function groundZAt(x, y, hintZ)
    local base = hintZ or 40.0
    local probes = { base + 120.0, base + 50.0, base + 10.0 }
    for _, probe in ipairs(probes) do
        local found, gz = GetGroundZFor_3dCoord(x + 0.0, y + 0.0, probe, false)
        if found and gz and gz > -100.0 then
            return gz + 0.08
        end
    end
    local ped = PlayerPedId()
    local ray = StartShapeTestLosProbe(
        x + 0.0, y + 0.0, base + 80.0,
        x + 0.0, y + 0.0, base - 120.0,
        1 + 16, ped, 7
    )
    local _, hit, endCoords = GetShapeTestResult(ray)
    if hit == 1 and endCoords then
        return endCoords.z + 0.08
    end
    return base
end

local function resolveDropPoint(drop)
    if not drop then return drop end
    local ped = PlayerPedId()
    local p = GetEntityCoords(ped)
    local hintZ = p.z
    if flatDist(p, drop) > 60.0 then
        hintZ = drop.z
    end
    return vector3(drop.x, drop.y, groundZAt(drop.x, drop.y, hintZ))
end

local function snapCoordsToGround(coords)
    if not coords then return coords end
    return vector3(coords.x, coords.y, groundZAt(coords.x, coords.y, coords.z))
end

local function flatDist(a, b)
    return #(vector2(a.x, a.y) - vector2(b.x, b.y))
end

local function removeTargetZone(name)
    if not name or GetResourceState('qb-target') ~= 'started' then return end
    pcall(function()
        exports['qb-target']:RemoveZone(name)
    end)
end

local function releasePlayerControl()
    local ped = PlayerPedId()
    ClearPedTasks(ped)
    FreezeEntityPosition(ped, false)
end

local function clearMissionEntities(opts)
    opts = opts or {}
    removeTargetZone(pickupTargetZone)
    pickupTargetZone = nil
    if not opts.keepDropTarget then
        removeTargetZone(dropTargetZone)
        dropTargetZone = nil
    end
    local keepVeh = opts.keepMissionVehicle and missionData and missionData.missionVehicle
    for i = #missionEntities, 1, -1 do
        local ent = missionEntities[i]
        if not (keepVeh and ent == keepVeh) then
            if ent and DoesEntityExist(ent) then
                DeleteEntity(ent)
            end
            table.remove(missionEntities, i)
        end
    end
end

local function clearMission()
    if missionData and missionData.missionVehicle and DoesEntityExist(missionData.missionVehicle) then
        local ped = PlayerPedId()
        if IsPedInVehicle(ped, missionData.missionVehicle, false) then
            TaskLeaveVehicle(ped, missionData.missionVehicle, 16)
            Wait(400)
        end
        if DoesEntityExist(missionData.missionVehicle) then
            DeleteEntity(missionData.missionVehicle)
        end
        missionData.missionVehicle = nil
    end
    clearMissionEntities()
    releasePlayerControl()
    missionBusy = false
    if missionBlip and DoesBlipExist(missionBlip) then
        RemoveBlip(missionBlip)
    end
    missionBlip = nil
    missionData = nil
end

local function setMissionBlip(coords, label)
    if missionBlip and DoesBlipExist(missionBlip) then RemoveBlip(missionBlip) end
    local z = groundZAt(coords.x, coords.y, coords.z)
    missionBlip = AddBlipForCoord(coords.x, coords.y, z)
    SetBlipSprite(missionBlip, 1)
    SetBlipColour(missionBlip, 27)
    SetBlipRoute(missionBlip, true)
    exports['fivempro_fonts']:SetBlipName(missionBlip, label or 'Misija')
end

local function getCurrentTurfId()
    local p = GetEntityCoords(PlayerPedId())
    return Config.FindTurfAt(p.x, p.y)
end

local VEHICLE_PROGRESS_DISABLE = {
    disableMovement = false,
    disableCarMovement = false,
    disableCombat = true,
}

local function runProgress(ms, label, anim, disableControls)
    return GangRunProgressSync('gang_mission', label, ms, disableControls, true, anim)
end

local function progressForStep(inVehicle)
    if inVehicle then
        return VEHICLE_PROGRESS_DISABLE, nil
    end
    return nil, nil
end

local function finishStep(token, step)
    QBCore.Functions.TriggerCallback('fivempro_gangs:server:finishMissionStep', function(res)
        missionBusy = false
        if not res or not res.ok then
            releasePlayerControl()
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
            clearMissionEntities({ keepMissionVehicle = missionData.requireVehicle == true })
            missionData.drop = resolveDropPoint(missionData.drop)
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
    if flatDist(GetEntityCoords(ped), missionData.pickup) > INTERACT then
        return QBCore.Functions.Notify('Per toli nuo paėmimo taško.', 'error')
    end
    if missionData.requireVehicle and not IsPedInAnyVehicle(ped, false) then
        return QBCore.Functions.Notify('Įsėsk į transportą ir bandyk dar kartą.', 'error')
    end
    missionBusy = true
    local inVehicle = missionData.requireVehicle and IsPedInAnyVehicle(ped, false)
    local disableControls, anim = progressForStep(inVehicle)
    if not inVehicle then anim = PICKUP_ANIM end
    local label = missionData.pickupLabel or (inVehicle and 'Vagiamas transportas…' or 'Renkamas krovinys…')
    if runProgress(missionData.durationMs or 7000, label, anim, disableControls) then
        finishStep(missionData.token, 1)
    else
        missionBusy = false
        releasePlayerControl()
        TriggerServerEvent('fivempro_gangs:server:cancelMission')
        clearMission()
    end
end

local function tryDrop()
    if missionBusy or not missionData or missionData.step ~= 2 or missionData.hacking then return end
    local ped = PlayerPedId()
    if missionData.dropInTurf ~= false then
        if flatDist(GetEntityCoords(ped), missionData.drop) > DROP_DIST then
            return QBCore.Functions.Notify('Per toli nuo pristatymo taško.', 'error')
        end
    end
    if missionData.requireVehicle and not IsPedInAnyVehicle(ped, false) then
        return QBCore.Functions.Notify('Reikia transporto.', 'error')
    end
    missionBusy = true
    local inVehicle = missionData.requireVehicle and IsPedInAnyVehicle(ped, false)
    local disableControls, anim = progressForStep(inVehicle)
    if not inVehicle then anim = DROP_ANIM end
    local label = missionData.dropLabel or (inVehicle and 'Pristatomas transportas…' or 'Pristatoma…')
    if runProgress(missionData.durationMs or 7000, label, anim, disableControls) then
        finishStep(missionData.token, 2)
    else
        missionBusy = false
        releasePlayerControl()
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

local function findVehicleSpawn(x, y, z, heading)
    local found, outPos, outHeading = GetClosestVehicleNodeWithHeading(x + 0.0, y + 0.0, z + 0.0, 1, 3.0, 0)
    if found and outPos then
        local nx, ny, nz = outPos.x, outPos.y, outPos.z
        local gz = groundZAt(nx, ny, nz)
        return nx, ny, gz, outHeading or heading
    end
    return x, y, groundZAt(x, y, z), heading
end

local function spawnMissionVehicle(model, x, y, z, heading)
    local hash = loadModel(model or 'sultan')
    if not hash then return nil end
    local sx, sy, sz, sh = findVehicleSpawn(x, y, z, heading)
    local veh = CreateVehicle(hash, sx, sy, sz + 0.15, sh or 0.0, true, false)
    if not veh or veh == 0 then return nil end
    SetEntityAsMissionEntity(veh, true, true)
    SetVehicleHasBeenOwnedByPlayer(veh, true)
    SetVehicleOnGroundProperly(veh)
    SetVehicleEngineOn(veh, true, true, false)
    SetVehicleDoorsLocked(veh, 1)
    SetVehicleNumberPlateText(veh, 'GANG' .. math.random(100, 999))
    if missionData then
        missionData.missionVehicle = veh
    end
    missionEntities[#missionEntities + 1] = veh
    return veh
end

local function spawnDeliveryVehicle(model, pickup, heading)
    local hash = loadModel(model or 'burrito3')
    if not hash then return nil end
    local gz = groundZAt(pickup.x, pickup.y, pickup.z)
    local spawnX = pickup.x + 3.5
    local spawnY = pickup.y + 1.5
    local vehZ = groundZAt(spawnX, spawnY, gz)
    local veh = CreateVehicle(hash, spawnX, spawnY, vehZ, heading, true, false)
    if not veh or veh == 0 then return nil end
    SetEntityAsMissionEntity(veh, true, true)
    SetVehicleOnGroundProperly(veh)
    SetVehicleEngineOn(veh, true, true, false)
    SetVehicleDoorsLocked(veh, 1)
    SetVehicleNumberPlateText(veh, 'GANG' .. math.random(100, 999))
    missionEntities[#missionEntities + 1] = veh
    return veh
end

local function spawnMissionWorld(missionType, pickup, heading, siteVehicle, spawnVehicle)
    clearMissionEntities()
    local visual = Config.MissionVisuals and Config.MissionVisuals[missionType]
    local mCfg = Config.MissionTypes and Config.MissionTypes[missionType]
    heading = heading or 0.0
    local gz = groundZAt(pickup.x, pickup.y, pickup.z)

    local vehicleModel = siteVehicle or spawnVehicle
    if mCfg and mCfg.requireVehicle then
        spawnMissionVehicle(vehicleModel or 'sultan', pickup.x, pickup.y, gz, heading)
    elseif vehicleModel then
        spawnDeliveryVehicle(vehicleModel, pickup, heading)
    end

    if visual and visual.prop then
        local hash = loadModel(visual.prop)
        if hash then
            local obj = CreateObject(hash, pickup.x, pickup.y, gz, false, false, false)
            SetEntityHeading(obj, heading)
            PlaceObjectOnGroundProperly(obj)
            FreezeEntityPosition(obj, true)
            missionEntities[#missionEntities + 1] = obj
        end
    elseif visual and visual.ped then
        local hash = loadModel(visual.ped)
        if hash then
            local npc = CreatePed(4, hash, pickup.x, pickup.y, gz, heading, false, true)
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
    local gz = groundZAt(coords.x, coords.y, coords.z)
    DrawMarker(
        1, coords.x, coords.y, gz + 0.02,
        0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
        2.2, 2.2, 0.9,
        r, g, b, 140,
        false, false, 2, false, nil, nil, false
    )
    if label then
        drawText3D(coords.x, coords.y, gz + 1.05, label)
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
        local pickup = snapCoordsToGround(vector3(res.pickup.x, res.pickup.y, res.pickup.z))
        local drop = snapCoordsToGround(vector3(res.drop.x, res.drop.y, res.drop.z))
        missionData = {
            token = res.token,
            step = 1,
            missionType = res.missionType or missionType,
            pickup = pickup,
            drop = drop,
            durationMs = res.durationMs or 7000,
            requireVehicle = res.requireVehicle == true,
            dropInTurf = res.dropInTurf ~= false,
            siteLabel = res.siteLabel,
            pickupLabel = res.pickupLabel,
            dropLabel = res.dropLabel,
        }
        spawnMissionWorld(
            missionData.missionType,
            missionData.pickup,
            res.heading or 0.0,
            res.siteVehicle,
            res.spawnVehicle
        )
        local blipLabel = res.siteLabel and ('Paėmimas: ' .. res.siteLabel) or res.label
        setMissionBlip(missionData.pickup, blipLabel)
        local hint = res.requireVehicle and 'įsėsk į transportą ir [E]' or '[E]'
        if res.spawnVehicle and not res.requireVehicle then
            hint = 'paėmimo taške [E] — šalia stovi furgonas'
        end
        QBCore.Functions.Notify(('Misija: %s — %s'):format(res.label, hint), 'success')
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
                local dist = flatDist(pos, missionData.pickup)
                if dist < MARKER_DIST then
                    sleep = 0
                    local pickupLabel = missionData.requireVehicle and '[E] Pavogti transportą' or '[E] Paimti krovinį'
                    drawMissionMarker(missionData.pickup, 59, 130, 246, pickupLabel)
                    if dist < INTERACT and IsControlJustReleased(0, 38) and not missionBusy then
                        tryPickup()
                    end
                end
            elseif missionData.step == 2 then
                sleep = 0
                if missionData.dropInTurf ~= false and missionData.drop then
                    local dist = flatDist(pos, missionData.drop)
                    if dist < MARKER_DIST then
                        drawMissionMarker(missionData.drop, 34, 197, 94, missionData.dropLabel and ('[E] ' .. missionData.dropLabel) or '[E] Pristatyti krovinį')
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
