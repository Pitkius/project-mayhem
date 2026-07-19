local QBCore = exports['qb-core']:GetCoreObject()

local busy = false

local CFG = {
    reach = 3.6,
    serverReach = 6.0,
    duration = { lockpick = 16000, advancedlockpick = 11000 },
    minigame = {
        lockpick = { mode = 'sequence', label = 'Paskutinis spynos žingsnis', length = 5 },
        advancedlockpick = { mode = 'sequence', label = 'Paskutinis spynos žingsnis', length = 4 },
    },
    anim = {
        dict = 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@',
        clip = 'machinic_loop_mechandplayer',
        flag = 49,
    },
}

local DISABLE = {
    disableMovement = true,
    disableCarMovement = true,
    disableCombat = true,
}

local function notify(msg, ntype)
    QBCore.Functions.Notify(msg, ntype or 'primary')
end

local function normalizePlate(plate)
    return tostring(plate or ''):upper():gsub('%s+', '')
end

local function vehicleLabel(veh)
    local model = GetEntityModel(veh)
    local display = GetDisplayNameFromVehicleModel(model)
    local label = GetLabelText(display)
    if not label or label == '' or label == 'NULL' then
        return display or 'Transportas'
    end
    return label
end

local function rotationToDirection(rot)
    local z = math.rad(rot.z)
    local x = math.rad(rot.x)
    local cosX = math.abs(math.cos(x))
    return vector3(-math.sin(z) * cosX, math.cos(z) * cosX, math.sin(x))
end

local function entityReach(ped, ent, maxDist)
    if not ent or ent == 0 or not DoesEntityExist(ent) then return false end
    return #(GetEntityCoords(ped) - GetEntityCoords(ent)) <= (maxDist or CFG.reach)
end

local function isVehicleLocked(veh)
    local st = GetVehicleDoorLockStatus(veh)
    return st == 2 or st == 3 or st == 4
end

local function playerHasKeys(veh)
    if GetResourceState('qb-vehiclekeys') ~= 'started' then
        return false
    end
    local plate = QBCore.Functions.GetPlate(veh) or GetVehicleNumberPlateText(veh)
    local ok, has = pcall(function()
        return exports['qb-vehiclekeys']:HasKeys(plate)
    end)
    return ok and has == true
end

local function isNpcVehicle(veh)
    if GetResourceState('mrp_basics') ~= 'started' then return false end
    local ok, isNpc = pcall(function()
        return exports['mrp_basics']:IsNaturalNpcVehicle(veh)
    end)
    return ok and isNpc == true
end

local function applyUnlockLocal(veh)
    if not veh or veh == 0 or not DoesEntityExist(veh) then return end
    SetVehicleDoorsLocked(veh, 1)
    SetVehicleDoorsLockedForAllPlayers(veh, false)
    SetVehicleDoorsLockedForPlayer(veh, PlayerId(), false)
    SetVehicleAlarm(veh, false)
    SetVehicleAlarmTimeLeft(veh, 0)
    if isNpcVehicle(veh) then
        pcall(function()
            exports['mrp_basics']:MarkNpcVehicleUnlocked(veh)
        end)
    end
end

local function triggerAlarmLocal(veh, durationMs)
    if not veh or veh == 0 or not DoesEntityExist(veh) then return end
    durationMs = math.max(5000, tonumber(durationMs) or 45000)

    local tries = 0
    while not NetworkHasControlOfEntity(veh) and tries < 25 do
        NetworkRequestControlOfEntity(veh)
        Wait(0)
        tries = tries + 1
    end

    SetVehicleAlarm(veh, true)
    SetVehicleAlarmTimeLeft(veh, durationMs)
    StartVehicleAlarm(veh)
    SetVehicleLights(veh, 2)
    StartVehicleHorn(veh, 800, joaat('HELDDOWN'), false)

    --- Palaikyti signalizaciją (native kartais nutrūksta)
    CreateThread(function()
        local ent = veh
        local untilAt = GetGameTimer() + durationMs
        while GetGameTimer() < untilAt do
            if not DoesEntityExist(ent) then return end
            if not IsVehicleAlarmActivated(ent) then
                SetVehicleAlarm(ent, true)
                StartVehicleAlarm(ent)
                SetVehicleAlarmTimeLeft(ent, math.max(1000, untilAt - GetGameTimer()))
            end
            SetVehicleLights(ent, 2)
            Wait(1200)
        end
        if DoesEntityExist(ent) then
            SetVehicleLights(ent, 0)
        end
    end)
end

RegisterNetEvent('mrp_basics:client:vehicleAlarm', function(netId, durationMs)
    netId = tonumber(netId) or 0
    if netId <= 0 then return end
    local veh = NetworkGetEntityFromNetworkId(netId)
    if veh == 0 or not DoesEntityExist(veh) then return end
    triggerAlarmLocal(veh, durationMs)
end)

local function getTargetVehicle()
    local ped = PlayerPedId()
    local pCoords = GetEntityCoords(ped)
    local maxDist = CFG.reach

    local camCoord = GetGameplayCamCoord()
    local camRot = GetGameplayCamRot(2)
    local dir = rotationToDirection(camRot)
    local dest = camCoord + (dir * (maxDist + 1.0))
    local ray = StartShapeTestRay(camCoord.x, camCoord.y, camCoord.z, dest.x, dest.y, dest.z, 10, ped, 0)
    local _, hit, _, _, ent = GetShapeTestResult(ray)
    if hit == 1 and ent ~= 0 and DoesEntityExist(ent) and IsEntityAVehicle(ent) then
        if entityReach(ped, ent, maxDist + 0.4) then
            return ent
        end
    end

    local forward = GetEntityForwardVector(ped)
    local best, bestDist = 0, maxDist
    for _, veh in ipairs(GetGamePool('CVehicle')) do
        if DoesEntityExist(veh) then
            local dist = #(pCoords - GetEntityCoords(veh))
            if dist <= maxDist then
                local delta = GetEntityCoords(veh) - pCoords
                local len = #(delta)
                if len > 0.05 then
                    delta = delta / len
                    local dot = forward.x * delta.x + forward.y * delta.y + forward.z * delta.z
                    if dot > 0.15 and dist < bestDist then
                        best = veh
                        bestDist = dist
                    end
                end
            end
        end
    end
    if best ~= 0 then return best end

    local fallback = QBCore.Functions.GetClosestVehicle()
    if fallback and fallback ~= 0 and fallback ~= -1 and DoesEntityExist(fallback) then
        if entityReach(ped, fallback, maxDist) then
            return fallback
        end
    end
    return 0
end

local function loadAnimDict(dict)
    if not dict or dict == '' then return false end
    RequestAnimDict(dict)
    local deadline = GetGameTimer() + 5000
    while not HasAnimDictLoaded(dict) and GetGameTimer() < deadline do
        Wait(10)
    end
    return HasAnimDictLoaded(dict)
end

local function applyDisableControls()
    if DISABLE.disableMovement then
        DisableControlAction(0, 30, true)
        DisableControlAction(0, 31, true)
        DisableControlAction(0, 36, true)
        DisableControlAction(0, 21, true)
    end
    if DISABLE.disableCarMovement then
        DisableControlAction(0, 63, true)
        DisableControlAction(0, 64, true)
        DisableControlAction(0, 71, true)
        DisableControlAction(0, 72, true)
    end
    if DISABLE.disableCombat then
        DisableControlAction(0, 24, true)
        DisableControlAction(0, 25, true)
        DisableControlAction(0, 47, true)
        DisableControlAction(0, 58, true)
        DisableControlAction(0, 140, true)
        DisableControlAction(0, 141, true)
        DisableControlAction(0, 142, true)
        DisableControlAction(0, 143, true)
    end
end

local function runLockpickProgress(advanced)
    local itemKey = advanced and 'advancedlockpick' or 'lockpick'
    local duration = CFG.duration[itemKey] or 16000
    local label = advanced and 'Laužiate spyną (pažangus)…' or 'Laužiate spyną…'
    local anim = CFG.anim

    local finished, cancelled = false, false
    local usedPb = false
    if QBCore.Functions.Progressbar then
        usedPb = true
        QBCore.Functions.Progressbar('mrp_vehicle_lockpick', label, duration, false, true, DISABLE, {
            animDict = anim.dict,
            anim = anim.clip,
            flags = anim.flag,
        }, {}, {}, function()
            finished = true
        end, function()
            cancelled = true
        end)
        local deadline = GetGameTimer() + duration + 1500
        while GetGameTimer() < deadline do
            if cancelled then return false end
            if finished then return true end
            Wait(50)
        end
        return finished
    end

    local ped = PlayerPedId()
    if loadAnimDict(anim.dict) then
        TaskPlayAnim(ped, anim.dict, anim.clip, 3.0, 3.0, -1, anim.flag, 0.0, false, false, false)
    end

    notify(label, 'primary')
    local endAt = GetGameTimer() + duration
    while GetGameTimer() < endAt do
        applyDisableControls()
        if anim.dict and anim.clip and not IsEntityPlayingAnim(ped, anim.dict, anim.clip, 3) then
            TaskPlayAnim(ped, anim.dict, anim.clip, 3.0, 3.0, -1, anim.flag, 0.0, false, false, false)
        end
        if IsControlJustReleased(0, 73) or IsControlJustReleased(0, 200) then
            ClearPedTasks(ped)
            return false
        end
        Wait(0)
    end
    ClearPedTasks(ped)
    return true
end

local function runLockpickMinigame(advanced)
    --- Visada progress bar + animacija pirma (ne instant)
    if not runLockpickProgress(advanced) then
        return false, 'cancel'
    end

    local itemKey = advanced and 'advancedlockpick' or 'lockpick'
    local mg = CFG.minigame[itemKey] or CFG.minigame.lockpick
    local anim = CFG.anim

    if GetResourceState('mrp_hacking') == 'started' then
        local ok, result = pcall(function()
            return exports['mrp_hacking']:RunPhysicalMinigame(mg.mode, {
                label = mg.label,
                anim = { dict = anim.dict, name = anim.clip, flags = anim.flag },
                data = { length = mg.length },
            })
        end)
        if ok then
            if result == true then
                return true, 'ok'
            end
            return false, 'fail'
        end
    end

    return true, 'ok'
end

RegisterNetEvent('mrp_basics:client:vehicleLockpickResult', function(data)
    data = data or {}
    local netId = tonumber(data.netId) or 0
    if netId <= 0 then return end

    local veh = NetworkGetEntityFromNetworkId(netId)
    if veh == 0 or not DoesEntityExist(veh) then return end

    if data.success then
        applyUnlockLocal(veh)
        notify(data.msg or 'Spyna atrakinta.', 'success')
        return
    end

    triggerAlarmLocal(veh, 45000)
    notify(data.msg or 'Nepavyko — įjungta signalizacija!', 'error')
end)

RegisterNetEvent('lockpicks:UseLockpick', function(advanced)
    if busy then return end

    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) then
        return notify('Išlipk iš transporto.', 'error')
    end

    local veh = getTargetVehicle()
    if veh == 0 then
        return notify('Nėra transporto šalia.', 'error')
    end

    if not entityReach(ped, veh, CFG.reach) then
        return notify('Per toli nuo transporto.', 'error')
    end

    if not isVehicleLocked(veh) then
        return notify('Transportas jau atrakintas.', 'primary')
    end

    if playerHasKeys(veh) then
        applyUnlockLocal(veh)
        local netId = NetworkGetNetworkIdFromEntity(veh)
        if netId and netId > 0 then
            TriggerServerEvent('mrp_basics:server:syncVehicleUnlock', netId)
        end
        return notify('Durys atrakintos (turite raktus).', 'success')
    end

    if not NetworkGetEntityIsNetworked(veh) then
        return notify('Šio transporto negalima atrakinti.', 'error')
    end

    local netId = NetworkGetNetworkIdFromEntity(veh)
    if not netId or netId <= 0 then
        return notify('Nepavyko nustatyti transporto.', 'error')
    end

    local plate = normalizePlate(QBCore.Functions.GetPlate(veh) or GetVehicleNumberPlateText(veh))
    local label = vehicleLabel(veh)

    busy = true
    local completed, reason = runLockpickMinigame(advanced == true)
    busy = false

    if not completed then
        if reason == 'cancel' then
            return notify('Įsilaužimas nutrauktas.', 'primary')
        end
        --- Sufailintas įsilaužimas: signalizacija + PD
        triggerAlarmLocal(veh, 45000)
        TriggerServerEvent('mrp_basics:server:vehicleLockpickFail', netId, plate, label, advanced == true)
        return notify('Nepavyko atrakinti — signalizacija!', 'error')
    end

    if not DoesEntityExist(veh) or not entityReach(PlayerPedId(), veh, CFG.reach + 0.5) then
        return notify('Per toli nuo transporto.', 'error')
    end

    TriggerServerEvent(
        'mrp_basics:server:vehicleLockpick',
        netId,
        plate,
        label,
        advanced == true
    )
end)
