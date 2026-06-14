--- Premium siren controller NUI + sinchronizacija su PD/EMS statebag
local QBCore = exports['qb-core']:GetCoreObject()

local uiOpen = false
local activeJobType = nil
local manualHeld = false

local function getJobCfg(jobType)
    return Config.Jobs[jobType]
end

local function playerData()
    return QBCore.Functions.GetPlayerData()
end

local function isOnDutyJob(jobName)
    local p = playerData()
    return p and p.job and p.job.name == jobName and p.job.onduty
end

local function hasGrade(minGrade)
    local p = playerData()
    if not p or not p.job then return false end
    local g = tonumber(p.job.grade and p.job.grade.level or 0) or 0
    return g >= (minGrade or 0)
end

local function getDriverVehicle()
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    if not veh or veh == 0 then return nil end
    if GetPedInVehicleSeat(veh, -1) ~= ped then return nil end
    return veh
end

local function fleetHashSet(jobType)
    local list = Config.FleetVehicles[jobType] or {}
    local set = {}
    for _, m in ipairs(list) do
        set[joaat(m)] = true
    end
    return set
end

local function vehicleIsFleet(veh, jobType)
    if not veh or veh == 0 then return false end
    local hash = GetEntityModel(veh)
    if fleetHashSet(jobType)[hash] then return true end
    if GetVehicleClass(veh) == 18 then return true end
    for _, name in ipairs({ 'IsThisModelEmergencyVehicle', 'IsThisModelAnEmergencyVehicle' }) do
        local fn = rawget(_G, name)
        if type(fn) == 'function' then
            local ok, r = pcall(fn, hash)
            if ok and r then return true end
        end
    end
    return false
end

local function vehicleDisplayName(veh, jobType)
    local cfg = getJobCfg(jobType)
    if not veh or veh == 0 then return cfg and cfg.defaultVehicleLabel or 'Transportas' end
    local hash = GetEntityModel(veh)
    local disp = GetDisplayNameFromVehicleModel(hash)
    if disp and disp ~= 'CARNOTFOUND' then
        local label = GetLabelText(disp)
        if label and label ~= 'NULL' and label ~= '' then
            return label
        end
        return disp
    end
    return cfg and cfg.defaultVehicleLabel or 'Transportas'
end

local function readVehicleState(veh, jobType)
    local cfg = getJobCfg(jobType)
    if not cfg then return 'off', 'wail', false end
    local bag = Entity(veh).state
    local mode = bag[cfg.modeStateKey] or 'off'
    if type(mode) ~= 'string' then mode = 'off' end
    mode = mode:lower()
    local tone = bag.fpSirenTone or 'wail'
    if type(tone) ~= 'string' then tone = 'wail' end
    tone = tone:lower()
    local muted = bag.fpSirenMuted == true
    return mode, tone, muted
end

local function detectActiveJobType()
    if isOnDutyJob(Config.Jobs.police.jobName) then return 'police' end
    if isOnDutyJob(Config.Jobs.ambulance.jobName) then return 'ambulance' end
    return nil
end

local function canOpenForJob(jobType)
    local cfg = getJobCfg(jobType)
    if not cfg or not isOnDutyJob(cfg.jobName) then return false end
    if not hasGrade(cfg.minGrade or 0) then return false end
    return true
end

local function pushUiSync()
    if not uiOpen or not activeJobType then return end
    local veh = getDriverVehicle()
    if not veh then return end
    local mode, tone, muted = readVehicleState(veh, activeJobType)
    SendNUIMessage({
        action = 'sync',
        code = mode,
        tone = tone,
        muted = muted,
        vehicleLabel = vehicleDisplayName(veh, activeJobType),
        jobType = activeJobType,
    })
end

local function openController(jobType)
    jobType = jobType or detectActiveJobType()
    if not jobType or not canOpenForJob(jobType) then
        return QBCore.Functions.Notify('Neturi teisės arba neesi tarnyboje.', 'error')
    end
    local veh = getDriverVehicle()
    if not veh then
        return QBCore.Functions.Notify('Turi būti vairo vietoje.', 'error')
    end
    local cfg = getJobCfg(jobType)
    local bag = Entity(veh).state
    if not vehicleIsFleet(veh, jobType) and bag[cfg.kitStateKey] ~= true then
        local kitCmd = cfg.kitCommand or '/pdiranga'
        return QBCore.Functions.Notify(
            ('Ant civilinės TP pirmiau įjunk laikinas sirenas (%s).'):format(kitCmd),
            'error'
        )
    end

    activeJobType = jobType
    uiOpen = true
    local mode, tone, muted = readVehicleState(veh, jobType)
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'open',
        code = mode,
        tone = tone,
        muted = muted,
        vehicleLabel = vehicleDisplayName(veh, jobType),
        jobType = jobType,
    })
end

local function closeController()
    if not uiOpen then return end
    uiOpen = false
    activeJobType = nil
    manualHeld = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

local function setCode(mode)
    if not activeJobType then return end
    local veh = getDriverVehicle()
    if not veh then return end
    local curMode = select(1, readVehicleState(veh, activeJobType))
    if curMode == mode then mode = 'off' end
    local cfg = getJobCfg(activeJobType)
    TriggerServerEvent(cfg.serverEvent, mode)
    SetTimeout(180, pushUiSync)
end

local function setTone(tone)
    if not activeJobType then return end
    local veh = getDriverVehicle()
    if not veh then return end
    TriggerServerEvent('fivempro_siren:server:setTone', NetworkGetNetworkIdFromEntity(veh), tone)
    SetTimeout(120, pushUiSync)
end

local function toggleMute()
    if not activeJobType then return end
    local veh = getDriverVehicle()
    if not veh then return end
    local _, _, muted = readVehicleState(veh, activeJobType)
    TriggerServerEvent('fivempro_siren:server:setMuted', NetworkGetNetworkIdFromEntity(veh), not muted)
    SetTimeout(120, pushUiSync)
end

RegisterNUICallback('close', function(_, cb)
    closeController()
    cb('ok')
end)

RegisterNUICallback('setCode', function(data, cb)
    local mode = data and data.code
    if mode then setCode(mode) end
    cb('ok')
end)

RegisterNUICallback('setTone', function(data, cb)
    local tone = data and data.tone
    if tone then setTone(tone) end
    cb('ok')
end)

RegisterNUICallback('toggleMute', function(_, cb)
    toggleMute()
    cb('ok')
end)

RegisterNUICallback('airhorn', function(_, cb)
    TriggerEvent('fivempro_siren:client:playAirhorn')
    cb('ok')
end)

RegisterNUICallback('manual', function(data, cb)
    manualHeld = data and data.held == true
    TriggerEvent('fivempro_siren:client:manualHeld', manualHeld)
    cb('ok')
end)

exports('OpenSirenController', openController)
exports('CloseSirenController', closeController)
exports('IsSirenControllerOpen', function() return uiOpen end)

RegisterNetEvent('fivempro_siren:client:open', function(jobType)
    openController(jobType)
end)

RegisterNetEvent('fivempro_siren:client:syncUi', function()
    pushUiSync()
end)

for jobType, cfg in pairs(Config.Jobs) do
    if cfg.command then
        RegisterCommand(cfg.command, function()
            if uiOpen and activeJobType == jobType then
                closeController()
            else
                openController(jobType)
            end
        end, false)
    end
    if cfg.kitCommand and cfg.kitServerEvent then
        RegisterCommand(cfg.kitCommand, function()
            if not canOpenForJob(jobType) then
                return QBCore.Functions.Notify('Neturi teisės.', 'error')
            end
            local veh = getDriverVehicle()
            if not veh then
                return QBCore.Functions.Notify('Turi būti vairo vietoje.', 'error')
            end
            if vehicleIsFleet(veh, jobType) then
                return QBCore.Functions.Notify('Šiai mašinai nereikia laikinos įrangos.', 'error')
            end
            local bag = Entity(veh).state
            local hasKit = bag[cfg.kitStateKey] == true
            TriggerServerEvent(cfg.kitServerEvent, not hasKit)
        end, false)
    end
end

RegisterKeyMapping('sirencontroller', 'Sirenų valdymo pultas', 'keyboard', Config.OpenKey or 'F6')

RegisterCommand('sirencontroller', function()
    local jt = detectActiveJobType()
    if not jt then
        return QBCore.Functions.Notify('Tik policijai ar EMS tarnyboje.', 'error')
    end
    if uiOpen then closeController() else openController(jt) end
end, false)

CreateThread(function()
    while true do
        if uiOpen then
            local veh = getDriverVehicle()
            if not veh then
                closeController()
            else
                pushUiSync()
            end
            Wait(400)
        else
            Wait(800)
        end
    end
end)

CreateThread(function()
    local lastVeh = 0
    while true do
        Wait(350)
        local veh = getDriverVehicle()
        if veh and veh ~= 0 then
            lastVeh = veh
        elseif lastVeh ~= 0 then
            local jt = detectActiveJobType()
            if jt then
                local cfg = getJobCfg(jt)
                if cfg and cfg.clearOnExitEvent then
                    local netId = NetworkGetNetworkIdFromEntity(lastVeh)
                    if netId and netId ~= 0 then
                        TriggerServerEvent(cfg.clearOnExitEvent, netId)
                    end
                end
            end
            if uiOpen then closeController() end
            lastVeh = 0
        end
    end
end)

AddStateBagChangeHandler('fpSirenTone', '', function()
    if uiOpen then SetTimeout(50, pushUiSync) end
end)

AddStateBagChangeHandler('fpSirenMuted', '', function()
    if uiOpen then SetTimeout(50, pushUiSync) end
end)

for _, cfg in pairs(Config.Jobs) do
    if cfg.modeStateKey then
        AddStateBagChangeHandler(cfg.modeStateKey, '', function()
            if uiOpen then SetTimeout(50, pushUiSync) end
        end)
    end
end
