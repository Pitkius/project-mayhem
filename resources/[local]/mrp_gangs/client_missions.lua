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
local CHECKPOINT_DIST = Config.MissionCheckpointDistance or 12.0

local PICKUP_ANIM = { dict = 'random@domestic', clip = 'pickup_low', flag = 1 }
local DROP_ANIM = { dict = 'mp_common', clip = 'givetake1_a', flag = 1 }
local SPRAY_ANIM = { dict = 'switch@franklin@lamar_tagging_wall', clip = 'lamar_tagging_wall_loop_lamar', flag = 1 }

local function drawText3D(x, y, z, text)
    if GetResourceState('mrp_fonts') == 'started' then
        exports['mrp_fonts']:DrawText3D(x, y, z, text)
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

local function flatDist(a, b)
    return #(vector2(a.x, a.y) - vector2(b.x, b.y))
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

local TRUNK_LOAD_DIST = 4.5
local CARRY_ANIM = { dict = 'anim@heists@box_carry@', clip = 'idle', flag = 49 }

local function missionArchetype()
    return missionData and missionData.archetype or 'delivery'
end

local function missionUsesTrunk()
    return missionData and missionData.spawnVehicle and missionData.spawnVehicle ~= ''
end

local function removeCarriedProp()
    if not missionData then return end
    local ped = PlayerPedId()
    ClearPedTasks(ped)
    if missionData.carriedProp and DoesEntityExist(missionData.carriedProp) then
        DetachEntity(missionData.carriedProp, true, true)
        DeleteEntity(missionData.carriedProp)
    end
    missionData.carriedProp = nil
end

local function spawnCarriedProp(missionType, visualKey)
    removeCarriedProp()
    local key = visualKey or missionType
    local visual = Config.MissionVisuals and Config.MissionVisuals[key]
    if not visual or not visual.prop then return end
    local hash = loadModel(visual.prop)
    if not hash then return end
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local obj = CreateObject(hash, coords.x, coords.y, coords.z, true, true, false)
    AttachEntityToEntity(
        obj, ped, GetPedBoneIndex(ped, 57005),
        0.12, 0.02, -0.02, 5.0, 0.0, 0.0,
        true, true, false, true, 1, true
    )
    RequestAnimDict(CARRY_ANIM.dict)
    local deadline = GetGameTimer() + 3000
    while not HasAnimDictLoaded(CARRY_ANIM.dict) and GetGameTimer() < deadline do
        Wait(10)
    end
    if HasAnimDictLoaded(CARRY_ANIM.dict) then
        TaskPlayAnim(ped, CARRY_ANIM.dict, CARRY_ANIM.clip, 8.0, -8.0, -1, CARRY_ANIM.flag, 0, false, false, false)
    end
    missionData.carriedProp = obj
    missionEntities[#missionEntities + 1] = obj
end

local function getVehicleTrunkPos(veh)
    if not veh or veh == 0 or not DoesEntityExist(veh) then return nil end
    local bone = GetEntityBoneIndexByName(veh, 'boot')
    if bone ~= -1 then
        return GetWorldPositionOfEntityBone(veh, bone)
    end
    return GetOffsetFromEntityInWorldCoords(veh, 0.0, -2.8, 0.35)
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
    local keepDelivery = opts.keepDeliveryVehicle and missionData and missionData.deliveryVehicle
    local keepCarried = opts.keepCarriedProp and missionData and missionData.carriedProp
    for i = #missionEntities, 1, -1 do
        local ent = missionEntities[i]
        if not (keepVeh and ent == keepVeh)
            and not (keepDelivery and ent == keepDelivery)
            and not (keepCarried and ent == keepCarried) then
            if ent and DoesEntityExist(ent) then
                DeleteEntity(ent)
            end
            table.remove(missionEntities, i)
        end
    end
end

local function clearMission()
    removeCarriedProp()
    if missionData and missionData.deliveryVehicle and DoesEntityExist(missionData.deliveryVehicle) then
        DeleteEntity(missionData.deliveryVehicle)
        missionData.deliveryVehicle = nil
    end
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
    exports['mrp_fonts']:SetBlipName(missionBlip, label or 'Misija')
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

local function advanceCheckpoint()
    if missionBusy or not missionData or not missionData.checkpoints then return end
    local idx = missionData.checkpointIndex or 1
    local pt = missionData.checkpoints[idx]
    if not pt then return end
    local ped = PlayerPedId()
    local pos = GetEntityCoords(ped)
    if flatDist(pos, pt) > CHECKPOINT_DIST then
        return QBCore.Functions.Notify('Eik arčiau checkpoint.', 'error')
    end
    if missionData.archetype == 'racing' and not IsPedInAnyVehicle(ped, false) then
        return QBCore.Functions.Notify('Reikia transporto.', 'error')
    end
    missionBusy = true
    local label = missionData.archetype == 'racing' and 'Checkpoint…' or 'Patikrinama…'
    if missionData.archetype ~= 'racing' then
        if not runProgress(missionData.durationMs or 4000, label, nil, nil) then
            missionBusy = false
            return
        end
    end
    QBCore.Functions.TriggerCallback('mrp_gangs:server:advanceMissionCheckpoint', function(res)
        missionBusy = false
        if not res or not res.ok then
            QBCore.Functions.Notify((res and res.reason) or 'Checkpoint nepavyko.', 'error')
            if res and res.done == false then
                TriggerServerEvent('mrp_gangs:server:cancelMission')
                clearMission()
            end
            return
        end
        if res.done then
            QBCore.Functions.Notify('Misija įvykdyta.', 'success')
            clearMission()
            return
        end
        missionData.checkpointIndex = res.nextIndex or (idx + 1)
        local nextPt = missionData.checkpoints[missionData.checkpointIndex]
        if nextPt then
            setMissionBlip(nextPt, ('Checkpoint %s/%s'):format(missionData.checkpointIndex, #missionData.checkpoints))
        end
    end, missionData.token, idx)
end

local function tryGraffitiMission()
    if missionBusy or not missionData or missionData.archetype ~= 'graffiti' then return end
    if missionData.turfId and Config.FindTurfAt then
        local p = GetEntityCoords(PlayerPedId())
        local here = Config.FindTurfAt(p.x, p.y)
        if here ~= missionData.turfId then
            return QBCore.Functions.Notify('Turi būti pasirinkto turf zonoje.', 'error')
        end
    end
    missionBusy = true
    if runProgress(missionData.durationMs or 5000, 'Dažoma graffiti…', SPRAY_ANIM, nil) then
        finishStep(missionData.token, 1)
    else
        missionBusy = false
        releasePlayerControl()
    end
end

local function completeHoldMission()
    if missionBusy or not missionData or missionData.archetype ~= 'hold' then return end
    missionBusy = true
    QBCore.Functions.TriggerCallback('mrp_gangs:server:completeHoldMission', function(res)
        missionBusy = false
        if not res or not res.ok then
            QBCore.Functions.Notify((res and res.reason) or 'Kontrolė nepavyko.', 'error')
            return
        end
        QBCore.Functions.Notify('Misija įvykdyta.', 'success')
        clearMission()
    end, missionData.token)
end

local function finishStep(token, step)
    QBCore.Functions.TriggerCallback('mrp_gangs:server:finishMissionStep', function(res)
        missionBusy = false
        if not res or not res.ok then
            releasePlayerControl()
            QBCore.Functions.Notify((res and res.reason) or 'Misija nepavyko.', 'error')
            TriggerServerEvent('mrp_gangs:server:cancelMission')
            clearMission()
            return
        end
        if res.done then
            QBCore.Functions.Notify('Misija įvykdyta.', 'success')
            clearMission()
            return
        end
        if not missionData then return end
        if res.nextStep == 2 and res.phase == 'trunk' then
            missionData.step = 2
            missionData.cargoLoaded = false
            clearMissionEntities({ keepDeliveryVehicle = true })
            removeTargetZone(pickupTargetZone)
            pickupTargetZone = nil
            spawnCarriedProp(missionData.missionType, missionData.visualKey)
            if missionBlip and DoesBlipExist(missionBlip) then
                RemoveBlip(missionBlip)
                missionBlip = nil
            end
            if missionData.deliveryVehicle and DoesEntityExist(missionData.deliveryVehicle) then
                local v = missionData.deliveryVehicle
                local vc = GetEntityCoords(v)
                missionBlip = AddBlipForEntity(v)
                SetBlipSprite(missionBlip, 477)
                SetBlipColour(missionBlip, 5)
                SetBlipRoute(missionBlip, true)
                exports['mrp_fonts']:SetBlipName(missionBlip, 'Furgonas — bagažinė')
            end
            QBCore.Functions.Notify('Įdėk krovinį į furgono bagažinę — [E] už galinės durų', 'primary')
            return
        end
        if res.nextStep == 3 or (res.nextStep == 2 and res.phase ~= 'trunk') then
            missionData.step = missionUsesTrunk() and 3 or 2
            missionData.cargoLoaded = missionUsesTrunk() and true or missionData.cargoLoaded
            clearMissionEntities({ keepDeliveryVehicle = true, keepMissionVehicle = missionData.requireVehicle == true })
            missionData.drop = resolveDropPoint(missionData.drop)
            if missionData.dropInTurf ~= false then
                setMissionBlip(missionData.drop, 'Pristatymas į turf')
                QBCore.Functions.Notify('Nuvežk krovinį į turf — [E] pristatymo taške', 'primary')
            else
                if missionBlip and DoesBlipExist(missionBlip) then
                    RemoveBlip(missionBlip)
                    missionBlip = nil
                end
                QBCore.Functions.Notify('Krovinys pristatytas — [E] užbaigti misiją', 'primary')
            end
        end
    end, token, step)
end

local function tryLoadTrunk()
    if missionBusy or not missionData or missionData.step ~= 2 or not missionUsesTrunk() then return end
    if not missionData.carriedProp or not DoesEntityExist(missionData.carriedProp) then
        return QBCore.Functions.Notify('Pirmiausia paimk krovinį.', 'error')
    end
    local veh = missionData.deliveryVehicle
    if not veh or not DoesEntityExist(veh) then
        return QBCore.Functions.Notify('Furgonas nerastas.', 'error')
    end
    local ped = PlayerPedId()
    local trunk = getVehicleTrunkPos(veh)
    if not trunk or flatDist(GetEntityCoords(ped), trunk) > TRUNK_LOAD_DIST then
        return QBCore.Functions.Notify('Eik prie furgono bagažinės.', 'error')
    end
    missionBusy = true
    SetVehicleDoorOpen(veh, 5, false, false)
    SetVehicleDoorOpen(veh, 2, false, false)
    SetVehicleDoorOpen(veh, 3, false, false)
    if runProgress(missionData.durationMs or 6000, 'Kraunama į bagažinę…', PICKUP_ANIM, nil) then
        removeCarriedProp()
        SetVehicleDoorShut(veh, 5, false)
        SetVehicleDoorShut(veh, 2, false)
        SetVehicleDoorShut(veh, 3, false)
        finishStep(missionData.token, 2)
    else
        SetVehicleDoorShut(veh, 5, false)
        SetVehicleDoorShut(veh, 2, false)
        SetVehicleDoorShut(veh, 3, false)
        missionBusy = false
        releasePlayerControl()
        spawnCarriedProp(missionData.missionType, missionData.visualKey)
    end
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
        TriggerServerEvent('mrp_gangs:server:cancelMission')
        clearMission()
    end
end

local function tryDrop()
    if missionBusy or not missionData or missionData.hacking then return end
    local dropStep = missionUsesTrunk() and 3 or 2
    if missionData.step ~= dropStep then return end
    if missionUsesTrunk() and not missionData.cargoLoaded then
        return QBCore.Functions.Notify('Pirmiausia įdėk krovinį į furgono bagažinę.', 'error')
    end
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
        finishStep(missionData.token, dropStep)
    else
        missionBusy = false
        releasePlayerControl()
        TriggerServerEvent('mrp_gangs:server:cancelMission')
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
    SetVehicleDoorsLocked(veh, 2)
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
    if missionData then
        missionData.deliveryVehicle = veh
    end
    missionEntities[#missionEntities + 1] = veh
    return veh
end

local function spawnMissionWorld(missionType, pickup, heading, siteVehicle, spawnVehicle, visualKey)
    clearMissionEntities()
    local visual = Config.MissionVisuals and Config.MissionVisuals[visualKey or missionType]
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
    QBCore.Functions.TriggerCallback('mrp_gangs:server:startMission', function(res)
        if not res or not res.ok then
            return QBCore.Functions.Notify((res and res.reason) or 'Negalima pradėti.', 'error')
        end
        if missionType == 'hacking' then
            missionData = { token = res.token, step = 1, hacking = true }
            return QBCore.Functions.Notify('Hacking misija pašalinta — naudok gaujos misijas planšetėje.', 'error')
        end
        local archetype = res.archetype or 'delivery'
        local pickup = snapCoordsToGround(vector3(res.pickup.x, res.pickup.y, res.pickup.z))
        local drop = snapCoordsToGround(vector3(res.drop.x, res.drop.y, res.drop.z))
        local checkpoints = nil
        if res.checkpoints then
            checkpoints = {}
            for i, c in ipairs(res.checkpoints) do
                checkpoints[i] = snapCoordsToGround(vector3(c.x, c.y, c.z))
            end
        end
        missionData = {
            token = res.token,
            step = 1,
            missionType = res.missionType or missionType,
            archetype = archetype,
            turfId = res.turfId,
            pickup = pickup,
            drop = drop,
            checkpoints = checkpoints,
            checkpointIndex = 1,
            holdSeconds = res.holdSeconds or 60,
            holdRadius = res.holdRadius or 80,
            holdElapsed = 0,
            holdNotified = false,
            durationMs = res.durationMs or 7000,
            requireVehicle = res.requireVehicle == true,
            spawnVehicle = res.spawnVehicle,
            dropInTurf = res.dropInTurf ~= false,
            cargoLoaded = false,
            visualKey = res.visualKey,
            siteLabel = res.siteLabel,
            pickupLabel = res.pickupLabel,
            dropLabel = res.dropLabel,
        }
        if res.randomEvent and res.randomEvent.notify then
            QBCore.Functions.Notify(res.randomEvent.notify, 'primary', 6000)
        end
        if archetype == 'patrol' or archetype == 'racing' then
            if checkpoints and checkpoints[1] then
                setMissionBlip(checkpoints[1], archetype == 'racing' and 'Lenktynių startas' or 'Patrulio taškas 1')
            end
            local hint = archetype == 'racing' and 'važiuok per checkpoint\'us' or 'aplankyk visus patrulio taškus [E]'
            QBCore.Functions.Notify(('Misija: %s — %s'):format(res.label, hint), 'success')
            return
        end
        if archetype == 'hold' then
            setMissionBlip(drop, 'Kontrolės zona')
            spawnMissionWorld(missionData.missionType, pickup, res.heading or 0.0, res.siteVehicle, res.spawnVehicle, res.visualKey)
            QBCore.Functions.Notify(('Misija: %s — išlaikyk zoną %ss'):format(res.label, missionData.holdSeconds), 'success')
            return
        end
        if archetype == 'graffiti' then
            setMissionBlip(drop, 'Graffiti vieta')
            QBCore.Functions.Notify(('Misija: %s — pažymėk turf [E]'):format(res.label), 'success')
            return
        end
        spawnMissionWorld(
            missionData.missionType,
            missionData.pickup,
            res.heading or 0.0,
            res.siteVehicle,
            res.spawnVehicle,
            res.visualKey
        )
        local blipLabel = res.siteLabel and ('Paėmimas: ' .. res.siteLabel) or res.label
        setMissionBlip(missionData.pickup, blipLabel)
        local hint = res.requireVehicle and 'įsėsk į transportą ir [E]' or '[E]'
        if res.spawnVehicle and not res.requireVehicle then
            hint = 'paimk krovinį [E], tada įdėk į furgono bagažinę'
        end
        if archetype == 'extortion' then
            hint = '[E] atlikti veiksmą'
        end
        QBCore.Functions.Notify(('Misija: %s — %s'):format(res.label, hint), 'success')
    end, turfId, missionType)
end

RegisterNetEvent('mrp_gangs:client:startMission', function(turfId, missionType)
    startMissionAt(turfId, missionType)
end)

RegisterCommand('gangmission', function(_, args)
    local turfId = getCurrentTurfId()
    if not turfId then
        return QBCore.Functions.Notify('Stovėk turf zonoje.', 'error')
    end
    startMissionAt(turfId, tostring(args[1] or 'street_patrol'))
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
            local arch = missionArchetype()

            if arch == 'patrol' and missionData.checkpoints then
                local idx = missionData.checkpointIndex or 1
                local pt = missionData.checkpoints[idx]
                if pt then
                    local dist = flatDist(pos, pt)
                    if dist < MARKER_DIST then
                        sleep = 0
                        drawMissionMarker(pt, 59, 130, 246, ('[E] Patrulio taškas %s/%s'):format(idx, #missionData.checkpoints))
                        if dist < CHECKPOINT_DIST and IsControlJustReleased(0, 38) and not missionBusy then
                            advanceCheckpoint()
                        end
                    end
                end
            elseif arch == 'racing' and missionData.checkpoints then
                sleep = 0
                local idx = missionData.checkpointIndex or 1
                local pt = missionData.checkpoints[idx]
                if pt then
                    local dist = flatDist(pos, pt)
                    if dist < MARKER_DIST then
                        drawMissionMarker(pt, 250, 204, 21, ('Checkpoint %s/%s'):format(idx, #missionData.checkpoints))
                    end
                    if dist < CHECKPOINT_DIST and not missionBusy and IsPedInAnyVehicle(ped, false) then
                        advanceCheckpoint()
                    end
                end
            elseif arch == 'hold' and missionData.drop then
                sleep = 0
                local dist = flatDist(pos, missionData.drop)
                local inZone = dist <= (missionData.holdRadius or 80)
                if dist < MARKER_DIST then
                    drawMissionMarker(missionData.drop, 168, 85, 247, inZone and '[E] Laikoma zona' or 'Eik į kontrolės zoną')
                end
                if inZone then
                    if not missionData.holdStartTime then
                        missionData.holdStartTime = GetGameTimer()
                        TriggerServerEvent('mrp_gangs:server:holdMissionStarted', missionData.token)
                        QBCore.Functions.Notify(('Laikyk zoną %ss…'):format(missionData.holdSeconds), 'primary')
                    end
                    local elapsed = (GetGameTimer() - missionData.holdStartTime) / 1000.0
                    if elapsed >= (missionData.holdSeconds or 60) and not missionBusy then
                        completeHoldMission()
                    end
                else
                    missionData.holdStartTime = nil
                end
            elseif arch == 'graffiti' and missionData.drop then
                local dist = flatDist(pos, missionData.drop)
                if dist < MARKER_DIST then
                    sleep = 0
                    drawMissionMarker(missionData.drop, 236, 72, 153, '[E] Pažymėti graffiti')
                    if dist < INTERACT and IsControlJustReleased(0, 38) and not missionBusy then
                        tryGraffitiMission()
                    end
                end
            elseif missionData.step == 1 and missionData.pickup then
                local dist = flatDist(pos, missionData.pickup)
                if dist < MARKER_DIST then
                    sleep = 0
                    local pickupLabel = missionData.pickupLabel
                        or (missionData.requireVehicle and '[E] Pavogti transportą' or '[E] Paimti krovinį')
                    if arch == 'extortion' then
                        pickupLabel = missionData.pickupLabel or '[E] Atlikti'
                    end
                    drawMissionMarker(missionData.pickup, 59, 130, 246, pickupLabel)
                    if dist < INTERACT and IsControlJustReleased(0, 38) and not missionBusy then
                        tryPickup()
                    end
                end
            elseif missionData.step == 2 and missionUsesTrunk() then
                sleep = 0
                local veh = missionData.deliveryVehicle
                if veh and DoesEntityExist(veh) and missionData.carriedProp then
                    local trunk = getVehicleTrunkPos(veh)
                    if trunk then
                        local dist = flatDist(pos, trunk)
                        if dist < MARKER_DIST then
                            drawMissionMarker(trunk, 250, 204, 21, '[E] Įdėti į bagažinę')
                            if dist < TRUNK_LOAD_DIST and IsControlJustReleased(0, 38) and not missionBusy then
                                tryLoadTrunk()
                            end
                        end
                    end
                end
            elseif missionData.step == 2 or missionData.step == 3 then
                local dropStep = missionUsesTrunk() and 3 or 2
                if missionData.step ~= dropStep then
                    -- wait for trunk step
                else
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
        end
        Wait(sleep)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    clearMission()
end)
