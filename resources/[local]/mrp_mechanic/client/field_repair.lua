local QBCore = exports['qb-core']:GetCoreObject()

local busy = false

local function notify(msg, typ)
    QBCore.Functions.Notify(msg, typ or 'primary')
end

local function isMechanicOnDuty()
    local P = QBCore.Functions.GetPlayerData()
    return P and P.job and P.job.name == Config.JobName and P.job.onduty
end

local function runProgress(name, label, durationMs, anim)
    durationMs = tonumber(durationMs) or 5000
    local done, cancelled = false, false
    local animDict, animClip, animFlags = nil, nil, 49
    if type(anim) == 'table' then
        animDict = anim.dict
        animClip = anim.clip
        animFlags = anim.flag or 49
    end
    QBCore.Functions.Progressbar(name, label or 'Vykdoma…', durationMs, false, true, {
        disableMovement = true,
        disableCarMovement = true,
        disableCombat = true,
    }, {
        animDict = animDict,
        anim = animClip,
        flags = animFlags,
    }, {}, {}, function()
        done = true
    end, function()
        cancelled = true
        ClearPedTasks(PlayerPedId())
    end)
    local deadline = GetGameTimer() + durationMs + 1000
    while GetGameTimer() < deadline do
        if cancelled then return false end
        if done then return true end
        Wait(50)
    end
    return done
end

local function ensureVehicleControl(veh)
    if not veh or veh == 0 or not DoesEntityExist(veh) then return false end
    if NetworkHasControlOfEntity(veh) then return true end
    NetworkRequestControlOfEntity(veh)
    local deadline = GetGameTimer() + 1500
    while not NetworkHasControlOfEntity(veh) and GetGameTimer() < deadline do
        NetworkRequestControlOfEntity(veh)
        Wait(50)
    end
    return NetworkHasControlOfEntity(veh)
end

local function applyFullRepair(veh)
    if not ensureVehicleControl(veh) then return false end
    SetVehicleEngineHealth(veh, 1000.0)
    SetVehicleBodyHealth(veh, 1000.0)
    SetVehiclePetrolTankHealth(veh, 1000.0)
    SetVehicleFixed(veh)
    SetVehicleDeformationFixed(veh)
    SetVehicleUndriveable(veh, false)
    SetVehicleEngineOn(veh, false, true, false)
    return true
end

local function applyClean(veh)
    if not ensureVehicleControl(veh) then return false end
    SetVehicleDirtLevel(veh, 0.0)
    WashDecalsFromVehicle(veh, 1.0)
    return true
end

local function applyFlip(veh)
    if not ensureVehicleControl(veh) then return false end
    local c = GetEntityCoords(veh)
    local h = GetEntityHeading(veh)
    SetEntityCoords(veh, c.x, c.y, c.z + 0.6, false, false, false, false)
    SetEntityRotation(veh, 0.0, 0.0, h, 2, true)
    SetVehicleOnGroundProperly(veh)
    return true
end

local function vehicleNeedsRepair(veh)
    if not veh or veh == 0 then return false end
    if GetVehicleEngineHealth(veh) < 950.0 then return true end
    if GetVehicleBodyHealth(veh) < 950.0 then return true end
    return false
end

local function vehicleIsFlipped(veh)
    if not veh or veh == 0 then return false end
    local roll = GetEntityRoll(veh)
    return math.abs(roll) > 65.0
end

local function runFieldRepair(veh)
    if busy or not isMechanicOnDuty() then return end
    if IsPedInAnyVehicle(PlayerPedId(), false) then
        return notify('Išlipkite iš transporto.', 'error')
    end
    if not vehicleNeedsRepair(veh) then
        return notify('Transportas nereikalauja remonto.', 'error')
    end
    local netId = NetworkGetNetworkIdFromEntity(veh)
    busy = true
    QBCore.Functions.TriggerCallback('mrp_mechanic:server:canFieldRepair', function(ok, msg)
        if not ok then
            busy = false
            return notify(msg or 'Negalima remontuoti.', 'error')
        end
        local cfg = Config.FieldRepair or {}
        local done = runProgress('mrp_mech_field_repair', cfg.label or 'Remontuojama…', cfg.progressMs or 9000, cfg.anim)
        if not done then
            busy = false
            return notify('Remontas atšauktas.', 'error')
        end
        TriggerServerEvent('mrp_mechanic:server:fieldRepair', netId)
        busy = false
    end, netId)
end

local function runFieldClean(veh)
    if busy or not isMechanicOnDuty() then return end
    if GetVehicleDirtLevel(veh) <= 0.15 then
        return notify('Transportas jau švarus.', 'error')
    end
    local netId = NetworkGetNetworkIdFromEntity(veh)
    busy = true
    local cfg = Config.FieldRepair or {}
    local done = runProgress('mrp_mech_field_clean', cfg.cleanLabel or 'Plaunama…', cfg.cleanProgressMs or 4500, cfg.anim)
    if not done then
        busy = false
        return notify('Atšaukta.', 'error')
    end
    TriggerServerEvent('mrp_mechanic:server:fieldClean', netId)
    busy = false
end

local function runFieldFlip(veh)
    if busy or not isMechanicOnDuty() then return end
    if not vehicleIsFlipped(veh) then
        return notify('Transportas nestovi ant stogo.', 'error')
    end
    local netId = NetworkGetNetworkIdFromEntity(veh)
    busy = true
    local cfg = Config.FieldRepair or {}
    local done = runProgress('mrp_mech_field_flip', cfg.flipLabel or 'Apverčiama…', cfg.flipProgressMs or 3500, cfg.anim)
    if not done then
        busy = false
        return notify('Atšaukta.', 'error')
    end
    TriggerServerEvent('mrp_mechanic:server:fieldFlip', netId)
    busy = false
end

RegisterNetEvent('mrp_mechanic:client:doFieldRepair', function(netId)
    local veh = NetworkGetEntityFromNetworkId(tonumber(netId) or 0)
    if veh == 0 or not DoesEntityExist(veh) then return end
    if applyFullRepair(veh) then
        notify('Transportas suremontuotas.', 'success')
    else
        notify('Nepavyko perimti transporto valdymo.', 'error')
    end
end)

RegisterNetEvent('mrp_mechanic:client:doFieldClean', function(netId)
    local veh = NetworkGetEntityFromNetworkId(tonumber(netId) or 0)
    if veh == 0 or not DoesEntityExist(veh) then return end
    if applyClean(veh) then
        notify('Transportas nuplautas.', 'success')
    end
end)

RegisterNetEvent('mrp_mechanic:client:doFieldFlip', function(netId)
    local veh = NetworkGetEntityFromNetworkId(tonumber(netId) or 0)
    if veh == 0 or not DoesEntityExist(veh) then return end
    if applyFlip(veh) then
        notify('Transportas apverstas.', 'success')
    end
end)

CreateThread(function()
    while GetResourceState('qb-target') ~= 'started' do
        Wait(300)
    end
    local dist = (Config.FieldRepair and Config.FieldRepair.maxDistance) or 4.0
    exports['qb-target']:AddGlobalVehicle({
        options = {
            {
                icon = 'fas fa-wrench',
                label = 'Suremontuoti',
                canInteract = function(entity)
                    if not isMechanicOnDuty() then return false end
                    if IsPedInAnyVehicle(PlayerPedId(), false) then return false end
                    return vehicleNeedsRepair(entity)
                end,
                action = function(entity)
                    runFieldRepair(entity)
                end,
            },
            {
                icon = 'fas fa-soap',
                label = 'Nuplauti',
                canInteract = function(entity)
                    if not isMechanicOnDuty() then return false end
                    if IsPedInAnyVehicle(PlayerPedId(), false) then return false end
                    return GetVehicleDirtLevel(entity) > 0.15
                end,
                action = function(entity)
                    runFieldClean(entity)
                end,
            },
            {
                icon = 'fas fa-car-crash',
                label = 'Apversti',
                canInteract = function(entity)
                    if not isMechanicOnDuty() then return false end
                    if IsPedInAnyVehicle(PlayerPedId(), false) then return false end
                    return vehicleIsFlipped(entity)
                end,
                action = function(entity)
                    runFieldFlip(entity)
                end,
            },
        },
        distance = dist,
    })
end)
