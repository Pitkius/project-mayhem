--- Premium siren controller NUI + sinchronizacija su PD/EMS statebag
local QBCore = exports['qb-core']:GetCoreObject()

local uiOpen = false
local activeJobType = nil
local manualHeld = false
local lastUiSyncSig = ''

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

local function getOccupiedVehicle()
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    if not veh or veh == 0 then return nil end
    return veh
end

local function safeVehicleNetId(veh)
    if not veh or veh == 0 or not DoesEntityExist(veh) then return 0 end
    if NetworkGetEntityIsNetworked and not NetworkGetEntityIsNetworked(veh) then return 0 end
    local netId = NetworkGetNetworkIdFromEntity(veh)
    if not netId or netId == 0 then return 0 end
    return netId
end

local function getSirenVehicle()
    if Config.AllowPassengerControl == false then
        return getDriverVehicle()
    end
    return getOccupiedVehicle()
end

local function applySirenNuiFocus(open)
    if open then
        SetNuiFocus(true, true)
        if Config.KeepInputWhileOpen ~= false then
            SetNuiFocusKeepInput(true)
        end
    else
        SetNuiFocusKeepInput(false)
        SetNuiFocus(false, false)
    end
end

local function fleetHashSet(jobType)
    local list = Config.FleetVehicles[jobType] or {}
    local set = {}
    for _, m in ipairs(list) do
        set[joaat(m)] = true
    end
    return set
end

local elsFleetHashes = nil
local function getElsFleetHashes()
    if elsFleetHashes then return elsFleetHashes end
    elsFleetHashes = {}
    for _, m in ipairs(Config.ElsFleetVehicles or {}) do
        elsFleetHashes[joaat(m)] = true
    end
    return elsFleetHashes
end

local function vehicleIsElsFleet(veh)
    if not veh or veh == 0 then return false end
    return getElsFleetHashes()[GetEntityModel(veh)] == true
end

--- ELS mašinoms F6 režimą perduodam ELS-FiveM (be apatinio panelio).
local function applyElsModeIfNeeded(veh, mode)
    if not vehicleIsElsFleet(veh) then return end
    if GetResourceState('ELS-FiveM') ~= 'started' then return end
    local ped = PlayerPedId()
    if GetVehiclePedIsIn(ped, false) ~= veh then return end
    if GetPedInVehicleSeat(veh, -1) ~= ped and Config.AllowPassengerControl == false then return end
    pcall(function()
        exports['ELS-FiveM']:ApplyEmergencyMode(mode or 'off')
    end)
end

local function vehicleIsFleet(veh, jobType)
    if not veh or veh == 0 then return false end
    local hash = GetEntityModel(veh)
    if fleetHashSet(jobType)[hash] then return true end
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

local function commandsAdminOnly()
    return Config.CommandsAdminOnly ~= false
end

local function runIfAdminCommand(fn)
    if not commandsAdminOnly() then
        return fn()
    end
    QBCore.Functions.TriggerCallback('mrp_ltpd:server:isAdmin', function(ok)
        if not ok then
            return QBCore.Functions.Notify('Šią komandą gali naudoti tik adminai. Naudok itemus arba F6.', 'error')
        end
        fn()
    end)
end

local function pushUiSync()
    if not uiOpen or not activeJobType then return end
    local veh = getSirenVehicle()
    if not veh then return end
    local mode, tone, muted = readVehicleState(veh, activeJobType)
    local label = vehicleDisplayName(veh, activeJobType)
    local sig = ('%s|%s|%s|%s'):format(mode, tone, tostring(muted), label)
    if sig == lastUiSyncSig then return end
    lastUiSyncSig = sig
    SendNUIMessage({
        action = 'sync',
        code = mode,
        tone = tone,
        muted = muted,
        vehicleLabel = label,
        jobType = activeJobType,
    })
end

local function openController(jobType)
    jobType = jobType or detectActiveJobType()
    if not jobType or not canOpenForJob(jobType) then
        return QBCore.Functions.Notify('Neturi teisės arba neesi tarnyboje.', 'error')
    end
    local veh = getSirenVehicle()
    if not veh then
        return QBCore.Functions.Notify('Turi būti transporto salėje.', 'error')
    end
    local cfg = getJobCfg(jobType)
    local bag = Entity(veh).state
    if not vehicleIsFleet(veh, jobType) and bag[cfg.kitStateKey] ~= true then
        local kitItem = 'pd_emergency_kit'
        if jobType == 'ambulance' then
            kitItem = (Config.EmergencyKit and Config.EmergencyKit.emsKitItem) or 'ems_emergency_kit'
        end
        return QBCore.Functions.Notify(
            ('Ant civilinės TP pirmiau įdėk avarinę įrangą (itemas „%s“).'):format(kitItem),
            'error'
        )
    end
    if safeVehicleNetId(veh) == 0 then
        return QBCore.Functions.Notify('Mašina turi būti tinkamai sinchronizuota (išimk iš garažo / naujas spawn).', 'error')
    end

    activeJobType = jobType
    uiOpen = true
    lastUiSyncSig = ''
    local mode, tone, muted = readVehicleState(veh, jobType)
    applySirenNuiFocus(true)
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
    applySirenNuiFocus(false)
    SendNUIMessage({ action = 'close' })
end

local function requestMode(jobType, veh, mode)
    local cfg = getJobCfg(jobType)
    if not cfg or not veh or veh == 0 then return end
    --- Tik statebag / server event. Native SetVehicleSiren valdo vienintelis
    --- mrp_ltpd — čia nebekviečiame, kad nebūtų on/off lenktynių.
    --- ELS fleet: iškart map'inam į ELS stage (F6 / E).
    applyElsModeIfNeeded(veh, mode)
    TriggerServerEvent(cfg.serverEvent, mode)
    SetTimeout(220, pushUiSync)
end

local function setCode(mode)
    if not activeJobType then return end
    local veh = getSirenVehicle()
    if not veh then return end
    local curMode = select(1, readVehicleState(veh, activeJobType))
    if curMode == mode then mode = 'off' end
    requestMode(activeJobType, veh, mode)
end

local function setTone(tone)
    if not activeJobType then return end
    local veh = getSirenVehicle()
    if not veh then return end
    TriggerServerEvent('mrp_siren:server:setTone', tone)
    SetTimeout(120, pushUiSync)
end

local function toggleMute()
    if not activeJobType then return end
    local veh = getSirenVehicle()
    if not veh then return end
    local _, _, muted = readVehicleState(veh, activeJobType)
    TriggerServerEvent('mrp_siren:server:setMuted', not muted)
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
    TriggerEvent('mrp_siren:client:playAirhorn')
    cb('ok')
end)

RegisterNUICallback('manual', function(data, cb)
    manualHeld = data and data.held == true
    TriggerEvent('mrp_siren:client:manualHeld', manualHeld)
    cb('ok')
end)

exports('OpenSirenController', openController)
exports('CloseSirenController', closeController)
exports('IsSirenControllerOpen', function() return uiOpen end)

RegisterNetEvent('mrp_siren:client:open', function(jobType)
    openController(jobType)
end)

RegisterNetEvent('mrp_siren:client:syncUi', function()
    pushUiSync()
end)

for jobType, cfg in pairs(Config.Jobs) do
    if cfg.command then
        RegisterCommand(cfg.command, function()
            runIfAdminCommand(function()
                if uiOpen and activeJobType == jobType then
                    closeController()
                else
                    openController(jobType)
                end
            end)
        end, false)
    end
    if cfg.kitCommand and cfg.kitServerEvent then
        RegisterCommand(cfg.kitCommand, function()
            runIfAdminCommand(function()
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
            end)
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

--- MRPD valdymas kaip vanilla policijos TP: E įjungia/išjungia viską.
CreateThread(function()
    local control = tonumber(Config.VanillaEToggleControl) or 86 -- INPUT_VEH_HORN
    local debounceMs = math.max(250, tonumber(Config.VanillaEToggleDebounceMs) or 450)
    local policeFleet = fleetHashSet('police')
    local lastToggleAt = 0

    while true do
        local ped = PlayerPedId()
        local veh = GetVehiclePedIsIn(ped, false)
        local eligible = Config.VanillaEToggle ~= false
            and veh ~= 0
            and GetPedInVehicleSeat(veh, -1) == ped
            and policeFleet[GetEntityModel(veh)] == true
            and isOnDutyJob(Config.Jobs.police.jobName)

        if eligible then
            DisableControlAction(0, control, true)
            if IsDisabledControlJustPressed(0, control) then
                local now = GetGameTimer()
                if now - lastToggleAt >= debounceMs then
                    lastToggleAt = now
                    local mode = select(1, readVehicleState(veh, 'police'))
                    requestMode('police', veh, mode == 'full' and 'off' or 'full')
                end
            end
            Wait(0)
        else
            Wait(300)
        end
    end
end)

CreateThread(function()
    while true do
        if uiOpen then
            local veh = getOccupiedVehicle()
            if not veh then
                closeController()
            else
                pushUiSync()
            end
            Wait(700)
        else
            Wait(900)
        end
    end
end)

CreateThread(function()
    while true do
        Wait(350)
        local inVeh = GetVehiclePedIsIn(PlayerPedId(), false)
        if uiOpen and (not inVeh or inVeh == 0) then
            closeController()
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
        AddStateBagChangeHandler(cfg.modeStateKey, '', function(bagName, _key, value)
            if uiOpen then SetTimeout(50, pushUiSync) end
            --- Jei statebag atėjo iš kito kliento / sync — vairuotojas taip pat užtikrina ELS.
            local ent = GetEntityFromStateBagName and GetEntityFromStateBagName(bagName)
            if ent and ent ~= 0 and DoesEntityExist(ent) and vehicleIsElsFleet(ent) then
                local ped = PlayerPedId()
                if GetVehiclePedIsIn(ped, false) == ent and GetPedInVehicleSeat(ent, -1) == ped then
                    applyElsModeIfNeeded(ent, value or 'off')
                end
            end
        end)
    end
end

local function openEmsKitMenu()
    if not isOnDutyJob(Config.Jobs.ambulance.jobName) then
        return QBCore.Functions.Notify('Tik EMS tarnyboje.', 'error')
    end
    local veh = getDriverVehicle()
    if not veh then
        return QBCore.Functions.Notify('Turi būti vairo vietoje.', 'error')
    end
    if vehicleIsFleet(veh, 'ambulance') then
        return QBCore.Functions.Notify('Šiai mašinai nereikia – jau tarnybinė.', 'error')
    end
    if GetResourceState('qb-menu') ~= 'started' then
        return QBCore.Functions.Notify('Reikia qb-menu.', 'error')
    end
    local hasKit = Entity(veh).state.ltEmsKit == true
    local kitItem = (Config.EmergencyKit and Config.EmergencyKit.emsKitItem) or 'ems_emergency_kit'
    local menu = {
        { header = 'EMS laikinos sirenos civilinei TP', isMenuHeader = true },
    }
    if not hasKit then
        menu[#menu + 1] = {
            header = 'Įmontuoti sirenas ir lempas',
            txt = ('Sunaudoja vieną „%s“ iš inventoriaus.'):format(kitItem),
            params = { event = 'mrp_siren:client:setEmsEmergencyKit', args = { equip = true } },
        }
    else
        menu[#menu + 1] = {
            header = 'Nuimti įrangą',
            txt = 'Įranga grąžinama į inventorių.',
            params = { event = 'mrp_siren:client:setEmsEmergencyKit', args = { equip = false } },
        }
    end
    menu[#menu + 1] = { header = '< Užverti meniu', params = { event = 'qb-menu:client:closeMenu' } }
    TriggerEvent('qb-menu:client:openMenu', menu, false, true)
end

RegisterNetEvent('mrp_siren:client:openEmsEmergencyKitMenu', function()
    openEmsKitMenu()
end)

RegisterNetEvent('mrp_siren:client:setEmsEmergencyKit', function(data)
    local equip = data and data.equip == true
    TriggerServerEvent('mrp_siren:server:setEmsEmergencyKit', equip)
end)
