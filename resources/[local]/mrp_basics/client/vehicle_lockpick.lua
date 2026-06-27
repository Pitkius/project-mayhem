local QBCore = exports['qb-core']:GetCoreObject()

local lockpickBusy = false

local function vehicleLabel(veh)
    local model = GetEntityModel(veh)
    local display = GetDisplayNameFromVehicleModel(model)
    local label = GetLabelText(display)
    if not label or label == '' or label == 'NULL' then
        return display or 'Transportas'
    end
    return label
end

local function isVehicleLocked(veh)
    local st = GetVehicleDoorLockStatus(veh)
    return st == 2 or st == 4
end

local function playerHasKeys(veh)
    local plate = QBCore.Functions.GetPlate(veh) or GetVehicleNumberPlateText(veh)
    if GetResourceState('qb-vehiclekeys') == 'started' then
        local ok, has = pcall(function()
            return exports['qb-vehiclekeys']:HasKeys(plate)
        end)
        if ok then return has == true end
    end
    return false
end

local function unlockVehicleDoors(veh)
    SetVehicleDoorsLocked(veh, 1)
    SetVehicleDoorsLockedForAllPlayers(veh, false)
    SetVehicleDoorsLockedForPlayer(veh, PlayerId(), false)
    SetVehicleAlarm(veh, false)
    SetVehicleAlarmTimeLeft(veh, 0)

    if GetResourceState('mrp_basics') == 'started' then
        pcall(function()
            exports['mrp_basics']:MarkNpcVehicleUnlocked(veh)
        end)
    end

    local netId = NetworkGetNetworkIdFromEntity(veh)
    if netId and netId > 0 then
        TriggerServerEvent('mrp_hud:server:setVehicleLock', netId, false)
    end
end

local function triggerVehicleAlarm(veh)
    SetVehicleAlarm(veh, true)
    StartVehicleAlarm(veh)
    SetVehicleAlarmTimeLeft(veh, 45000)
end

local function loadAnimDict(dict)
    RequestAnimDict(dict)
    local t = GetGameTimer() + 5000
    while not HasAnimDictLoaded(dict) do
        if GetGameTimer() > t then return false end
        Wait(10)
    end
    return true
end

local function runLockpickMinigame(advanced, onDone)
    local ped = PlayerPedId()
    local dict = 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@'
    local anim = 'machinic_loop_mechandplayer'
    if not loadAnimDict(dict) then
        return onDone(false)
    end

    TaskPlayAnim(ped, dict, anim, 3.0, 3.0, -1, 16, 0.0, false, false, false)

    CreateThread(function()
        while lockpickBusy do
            if not IsEntityPlayingAnim(ped, dict, anim, 3) then
                TaskPlayAnim(ped, dict, anim, 3.0, 3.0, -1, 16, 0.0, false, false, false)
            end
            Wait(400)
        end
    end)

    QBCore.Functions.Progressbar('mrp_vehicle_lockpick', advanced and 'Laužiate spyną (pažangus)…' or 'Laužiate spyną…', advanced and 9000 or 12000, false, true, {
        disableMovement = true,
        disableCarMovement = true,
        disableMouse = false,
        disableCombat = true,
    }, {}, {}, {}, function()
        ClearPedTasks(ped)
        onDone(true)
    end, function()
        ClearPedTasks(ped)
        onDone(false)
    end)
end

RegisterNetEvent('mrp_basics:client:vehicleLockpickResult', function(data)
    data = data or {}
    local veh = data.netId and NetworkGetEntityFromNetworkId(data.netId) or 0
    if veh == 0 or not DoesEntityExist(veh) then return end

    if data.success then
        unlockVehicleDoors(veh)
        QBCore.Functions.Notify(data.msg or 'Spyna atrakinta.', 'success')
        return
    end

    triggerVehicleAlarm(veh)
    QBCore.Functions.Notify(data.msg or 'Nepavyko — įjungta signalizacija!', 'error')
end)

RegisterNetEvent('lockpicks:UseLockpick', function(advanced)
    if lockpickBusy then return end

    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) then
        return QBCore.Functions.Notify('Išlipk iš transporto.', 'error')
    end

    local veh = QBCore.Functions.GetClosestVehicle()
    if not veh or veh == 0 or not DoesEntityExist(veh) then
        return QBCore.Functions.Notify('Nėra transporto šalia.', 'error')
    end

    if #(GetEntityCoords(ped) - GetEntityCoords(veh)) > 3.2 then
        return QBCore.Functions.Notify('Per toli nuo transporto.', 'error')
    end

    if not isVehicleLocked(veh) then
        return QBCore.Functions.Notify('Transportas jau atrakintas.', 'primary')
    end

    if playerHasKeys(veh) then
        unlockVehicleDoors(veh)
        return QBCore.Functions.Notify('Durys atrakintos (turite raktus).', 'success')
    end

    lockpickBusy = true
    runLockpickMinigame(advanced == true, function(completed)
        lockpickBusy = false
        if not completed then
            return QBCore.Functions.Notify('Atšaukta.', 'error')
        end

        local netId = NetworkGetNetworkIdFromEntity(veh)
        if not netId or netId <= 0 then
            return QBCore.Functions.Notify('Nepavyko nustatyti transporto.', 'error')
        end

        local plate = QBCore.Functions.GetPlate(veh) or GetVehicleNumberPlateText(veh) or '???'
        TriggerServerEvent('mrp_basics:server:vehicleLockpick', netId, plate, vehicleLabel(veh), advanced == true)
    end)
end)
