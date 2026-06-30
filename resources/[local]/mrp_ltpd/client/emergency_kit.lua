--- PD: šviestuvų ir sirenos režimai masinoje + laikina sirena ant civilinės mašinos (statebag ltPd*)
local QBCore = exports['qb-core']:GetCoreObject()

local TRACKED = {} --- [vehicle] = { supportsNative }
local LIGHTBARS = {} --- [vehicle] = prop entity
local KIT_PERF = {} --- [vehicle] = { sig, orig }

local Ec = Config.EmergencyVehicle or {}
local RESET_ON_EXIT = Ec.resetWhenLeaveDriverSeat ~= false

local EMS_JOB = 'ambulance'

local function isPdJobName(name)
    return name == Config.JobName
end

local function pdOnDuty()
    local P = QBCore.Functions.GetPlayerData()
    return P and P.job and isPdJobName(P.job.name) and P.job.onduty
end

local function emsOnDuty()
    local P = QBCore.Functions.GetPlayerData()
    return P and P.job and P.job.name == EMS_JOB and P.job.onduty
end

local function emergencyOnDuty()
    return pdOnDuty() or emsOnDuty()
end

local function hasGradePerm(minGrade)
    local P = QBCore.Functions.GetPlayerData()
    if not P or not P.job then return false end
    local g = tonumber(P.job.grade and P.job.grade.level or 0) or 0
    return g >= minGrade
end

local function canPdSirenMenu()
    if not pdOnDuty() then return false end
    local need = (Config.Permissions and Config.Permissions.pd_siren_controller) or 0
    return hasGradePerm(need)
end

local function canPdEmergencyKit()
    if not pdOnDuty() then return false end
    local need = (Config.Permissions and Config.Permissions.pd_emergency_kit) or 0
    return hasGradePerm(need)
end

local function commandsAdminOnly()
    local ec = Config.EmergencyVehicle or {}
    return ec.commandsAdminOnly ~= false
end

local function runIfAdminCommand(fn)
    if not commandsAdminOnly() then
        return fn()
    end
    QBCore.Functions.TriggerCallback('mrp_ltpd:server:isAdmin', function(ok)
        if not ok then
            local item = (Config.EmergencyVehicle or {}).kitItem or 'pd_emergency_kit'
            return QBCore.Functions.Notify(
                ('Komandą gali naudoti tik adminai. Naudok itemą „%s“ inventoriuje.'):format(item),
                'error'
            )
        end
        fn()
    end)
end

local function modelIsFleet(hash)
    if Config.FleetVehicles then
        for _, v in ipairs(Config.FleetVehicles) do
            if v and v.model and joaat(v.model) == hash then return true end
        end
    end
    if Config.FleetHelicopters then
        for _, v in ipairs(Config.FleetHelicopters) do
            if v and v.model and joaat(v.model) == hash then return true end
        end
    end
    return false
end

local function vehicleSupportsNativeEmergency(vehicle)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then return false end
    local hash = GetEntityModel(vehicle)
    -- Kai kuriuose artefaktuose native neeksportuotas – nekrentam į nil call.
    for _, name in ipairs({ 'IsThisModelEmergencyVehicle', 'IsThisModelAnEmergencyVehicle' }) do
        local fn = rawget(_G, name)
        if type(fn) == 'function' then
            local ok, r = pcall(fn, hash)
            if ok and r then return true end
        end
    end
    if GetVehicleClass(vehicle) == 18 then return true end
    return modelIsFleet(hash)
end

local function getDriverVehicleLocal()
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    if not veh or veh == 0 then return nil end
    if GetPedInVehicleSeat(veh, -1) ~= ped then return nil end
    return veh
end

local function stopNativeSirenVisual(vehicle)
    if not DoesEntityExist(vehicle) then return end
    SetVehicleSiren(vehicle, false)
    SetVehicleHasMutedSirens(vehicle, false)
end

local soundIds = {}

local function stopScriptSound(vehicle)
    local sid = soundIds[vehicle]
    if sid and sid ~= -1 then
        StopSound(sid)
        ReleaseSoundId(sid)
    end
    soundIds[vehicle] = nil
end

local function playShortSirenBurst(vehicle)
    if not DoesEntityExist(vehicle) then return end
    local sid = soundIds[vehicle]
    if not sid then
        sid = GetSoundId()
        if sid == -1 then return end
        soundIds[vehicle] = sid
    end
    StopSound(sid)
    pcall(function()
        PlaySoundFromEntity(sid, 'VEHICLES_HORNS_SIREN_1', vehicle)
    end)
end

local function removeLightbar(vehicle)
    local prop = LIGHTBARS[vehicle]
    if prop and prop ~= 0 and DoesEntityExist(prop) then
        DetachEntity(prop, true, true)
        DeleteEntity(prop)
    end
    LIGHTBARS[vehicle] = nil
end

local function readVehicleStateBag(vehicle)
    local bag = Entity(vehicle).state
    if bag == nil then return 'off', false end
    local mode = bag.ltPdSirenMode or bag.ltEmsSirenMode or 'off'
    if type(mode) ~= 'string' then mode = 'off' end
    mode = mode:lower()
    local kit = bag.ltPdKit == true or bag.ltEmsKit == true
    return mode, kit
end

local function ensureLightbar(vehicle)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then return end
    local _, kit = readVehicleStateBag(vehicle)
    if vehicleSupportsNativeEmergency(vehicle) or kit ~= true then
        removeLightbar(vehicle)
        return
    end
    if LIGHTBARS[vehicle] and DoesEntityExist(LIGHTBARS[vehicle]) then return end

    local modelName = Ec.lightbarModel or 'prop_lightbar_01'
    local hash = joaat(modelName)
    if not IsModelInCdimage(hash) then return end
    RequestModel(hash)
    local tries = 0
    while not HasModelLoaded(hash) and tries < 80 do
        Wait(10)
        tries = tries + 1
    end
    if not HasModelLoaded(hash) then return end

    local c = GetEntityCoords(vehicle)
    local prop = CreateObject(hash, c.x, c.y, c.z + 1.0, false, false, false)
    if not prop or prop == 0 then
        SetModelAsNoLongerNeeded(hash)
        return
    end
    SetEntityCollision(prop, false, false)
    SetEntityAsMissionEntity(prop, true, true)
    SetEntityCompletelyDisableCollision(prop, false, false)

    local bone = GetEntityBoneIndexByName(vehicle, 'roof')
    if bone == -1 then bone = GetEntityBoneIndexByName(vehicle, 'bodyshell') end
    local yOff = tonumber(Ec.lightbarYOffset) or 0.28
    local zOff = tonumber(Ec.lightbarZOffset) or 0.0
    AttachEntityToEntity(prop, vehicle, bone, 0.0, yOff, zOff, 0.0, 0.0, 0.0, false, false, false, false, 2, true)
    LIGHTBARS[vehicle] = prop
    SetModelAsNoLongerNeeded(hash)
end

local PERF_FIELDS = {
    'fInitialDriveForce',
    'fInitialDriveMaxFlatVel',
    'fBrakeForce',
    'fSteeringLock',
    'fTractionCurveMax',
    'fTractionCurveMin',
    'fDriveInertia',
}

local function getPerformanceTuneCfg()
    return Ec.performanceTune or {}
end

local function performanceTuneEnabled()
    local tune = getPerformanceTuneCfg()
    return tune.enabled ~= false
end

local function buildPerfSignature(vehicle)
    local eng = GetVehicleMod(vehicle, 11)
    if eng < 0 then eng = 0 end
    local turbo = IsToggleModOn(vehicle, 18) and 1 or 0
    return ('%s|%d|%d'):format(GetEntityModel(vehicle), eng, turbo)
end

local function snapshotPerformanceBaseline(vehicle)
    local snap = {}
    for _, field in ipairs(PERF_FIELDS) do
        snap[field] = GetVehicleHandlingFloat(vehicle, 'CHandlingData', field)
    end
    snap.maxSpeedMs = 0.0
    local capped = GetVehicleMaxSpeed(vehicle)
    if capped and capped > 0.5 then
        snap.maxSpeedMs = capped
    end
    return snap
end

local function applyKitPerformanceFromBaseline(vehicle, orig, tune)
    local accelMult = tonumber(tune.acceleration) or 1.045
    local topMult = tonumber(tune.topSpeed) or 1.028
    local brakeMult = tonumber(tune.braking) or 1.06
    local steerMult = tonumber(tune.steering) or 1.025
    local tractionMult = tonumber(tune.traction) or 1.03
    local inertiaMult = tonumber(tune.driveInertia) or 0.97
    local extraKmh = tonumber(tune.extraMaxKmh) or 6

    SetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fInitialDriveForce', orig.fInitialDriveForce * accelMult)
    SetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fInitialDriveMaxFlatVel', orig.fInitialDriveMaxFlatVel * topMult)
    SetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fBrakeForce', orig.fBrakeForce * brakeMult)
    SetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fSteeringLock', orig.fSteeringLock * steerMult)
    SetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fTractionCurveMax', orig.fTractionCurveMax * tractionMult)
    SetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fTractionCurveMin', orig.fTractionCurveMin * tractionMult)
    SetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fDriveInertia', orig.fDriveInertia * inertiaMult)

    if orig.maxSpeedMs and orig.maxSpeedMs > 0.5 then
        SetVehicleMaxSpeed(vehicle, (orig.maxSpeedMs * topMult) + (extraKmh / 3.6))
    end
end

local function removeKitPerformance(vehicle)
    if not vehicle or vehicle == 0 then
        KIT_PERF[vehicle] = nil
        return
    end
    local entry = KIT_PERF[vehicle]
    if not entry or not entry.orig or not DoesEntityExist(vehicle) then
        KIT_PERF[vehicle] = nil
        return
    end
    for _, field in ipairs(PERF_FIELDS) do
        local val = entry.orig[field]
        if val then
            SetVehicleHandlingFloat(vehicle, 'CHandlingData', field, val)
        end
    end
    if entry.orig.maxSpeedMs and entry.orig.maxSpeedMs > 0.5 then
        SetVehicleMaxSpeed(vehicle, entry.orig.maxSpeedMs)
    else
        SetVehicleMaxSpeed(vehicle, 0.0)
    end
    KIT_PERF[vehicle] = nil
end

local function syncKitPerformance(vehicle)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then return end
    if not performanceTuneEnabled() then
        removeKitPerformance(vehicle)
        return
    end

    local _, kit = readVehicleStateBag(vehicle)
    if kit ~= true or vehicleSupportsNativeEmergency(vehicle) then
        removeKitPerformance(vehicle)
        return
    end

    local tune = getPerformanceTuneCfg()
    local sig = buildPerfSignature(vehicle)
    local entry = KIT_PERF[vehicle]

    if not entry or entry.sig ~= sig or not entry.orig then
        if entry then removeKitPerformance(vehicle) end
        KIT_PERF[vehicle] = {
            sig = sig,
            orig = snapshotPerformanceBaseline(vehicle),
        }
        entry = KIT_PERF[vehicle]
    end

    applyKitPerformanceFromBaseline(vehicle, entry.orig, tune)
end

local function syncKitVisuals(vehicle)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then return end
    local _, kit = readVehicleStateBag(vehicle)
    if kit and not vehicleSupportsNativeEmergency(vehicle) then
        ensureLightbar(vehicle)
        syncKitPerformance(vehicle)
    else
        removeLightbar(vehicle)
        removeKitPerformance(vehicle)
    end
end

local function drawLensMarker(x, y, z, r, g, b, alpha)
    DrawMarker(
        28,
        x, y, z,
        0.0, 0.0, 0.0,
        0.0, 0.0, 0.0,
        0.085, 0.085, 0.085,
        r, g, b, alpha,
        false, false, 2, false, false, false, false
    )
end

local function drawScriptFlash(vehicle)
    if not DoesEntityExist(vehicle) then return end

    local interval = tonumber(Ec.flashIntervalMs) or 560
    local phase = math.floor(GetGameTimer() / interval) % 2 == 0
    local lightRange = tonumber(Ec.flashLightRange) or 2.2
    local lightPower = tonumber(Ec.flashLightIntensity) or 3.5

    local prop = LIGHTBARS[vehicle]
    local barPos
    local fwd = GetEntityForwardVector(vehicle)
    local right = vector3(-fwd.y, fwd.x, 0.0)

    if prop and DoesEntityExist(prop) then
        barPos = GetEntityCoords(prop)
    else
        local mn, mx = GetModelDimensions(GetEntityModel(vehicle))
        local z = mx.z + 0.12
        local yBias = mn.y + 0.35
        local c = GetEntityCoords(vehicle)
        barPos = vector3(c.x + fwd.x * yBias, c.y + fwd.y * yBias, c.z + z)
    end

    local leftPos = barPos + right * (-0.38)
    local rightPos = barPos + right * 0.38
    local centerPos = barPos + vector3(0.0, 0.0, 0.06)

    if phase then
        drawLensMarker(leftPos.x, leftPos.y, leftPos.z, 220, 28, 28, 175)
        drawLensMarker(centerPos.x, centerPos.y, centerPos.z, 200, 40, 40, 120)
        if lightRange > 0 and lightPower > 0 then
            DrawLightWithRange(leftPos.x, leftPos.y, leftPos.z, 220, 30, 30, lightRange, lightPower)
        end
    else
        drawLensMarker(rightPos.x, rightPos.y, rightPos.z, 28, 72, 220, 175)
        drawLensMarker(centerPos.x, centerPos.y, centerPos.z, 40, 80, 200, 120)
        if lightRange > 0 and lightPower > 0 then
            DrawLightWithRange(rightPos.x, rightPos.y, rightPos.z, 30, 72, 220, lightRange, lightPower)
        end
    end
end

local function safeVehicleNetId(vehicle)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then return 0 end
    return NetworkGetNetworkIdFromEntity(vehicle)
end

local function applyNativeForEveryone(vehicle, mode)
    if not DoesEntityExist(vehicle) then return end
    if not vehicleSupportsNativeEmergency(vehicle) then return end
    mode = mode or 'off'
    if mode == 'off' then
        stopNativeSirenVisual(vehicle)
        return
    end
    if mode == 'sound' then
        stopNativeSirenVisual(vehicle)
        return
    end
    --- lights ir full naudoja GTA sirenos šviesas
    SetVehicleSiren(vehicle, true)
    local muted = Entity(vehicle).state.fpSirenMuted == true
    if mode == 'lights' then
        SetVehicleHasMutedSirens(vehicle, true)
    elseif mode == 'full' then
        SetVehicleHasMutedSirens(vehicle, muted)
    end
end

local function ingestFromEntity(vehicle)
    if not vehicle or vehicle == 0 or not IsEntityAVehicle(vehicle) or not DoesEntityExist(vehicle) then return end
    local mode, kit = readVehicleStateBag(vehicle)
    TRACKED[vehicle] = TRACKED[vehicle] or {}
    TRACKED[vehicle].supportsNative = vehicleSupportsNativeEmergency(vehicle)
    syncKitVisuals(vehicle)

    if mode == 'off' then
        stopNativeSirenVisual(vehicle)
        stopScriptSound(vehicle)
        if not kit then
            TRACKED[vehicle] = nil
        end
        return
    elseif mode == 'lights' then
        stopScriptSound(vehicle)
        applyNativeForEveryone(vehicle, mode)
    elseif mode == 'sound' then
        --- Tik garsas – natyvus „siren“ išjungtas, nesinaudoja automatinėmis šviesomis (sceninė sirena žemiau).
        stopNativeSirenVisual(vehicle)
    elseif mode == 'full' then
        if TRACKED[vehicle].supportsNative then
            stopScriptSound(vehicle)
            applyNativeForEveryone(vehicle, 'full')
        end
    end
end

local function resolveEntityFromBagName(bagName)
    bagName = tostring(bagName or '')
    if type(GetEntityFromStateBagName) == 'function' then
        local e = GetEntityFromStateBagName(bagName)
        if e and e ~= 0 and DoesEntityExist(e) then
            return e
        end
    end
    local nidStr = bagName:match('^entity:(%d+)$') or bagName:match('^%w+:(%d+)$')
    local nid = tonumber(nidStr)
    if nid and NetworkDoesNetworkIdExist(nid) then
        local ent = NetworkGetEntityFromNetworkId(nid)
        if ent ~= 0 and DoesEntityExist(ent) then return ent end
    end
    return 0
end

local function onAnyPdBag(_, bagName)
    Wait(25)
    local ent = resolveEntityFromBagName(bagName)
    if ent ~= 0 and IsEntityAVehicle(ent) then
        ingestFromEntity(ent)
    end
end

AddStateBagChangeHandler('ltPdSirenMode', '', onAnyPdBag)
AddStateBagChangeHandler('ltEmsSirenMode', '', onAnyPdBag)

AddStateBagChangeHandler('ltPdKit', '', onAnyPdBag)
AddStateBagChangeHandler('ltEmsKit', '', onAnyPdBag)
AddStateBagChangeHandler('fpSirenMuted', '', onAnyPdBag)

CreateThread(function()
    --- Laikinai palaiko natyvias sirenas užrakinant „lights/full“ prieš GTA resetą
    while true do
        local hasTracked = next(TRACKED) ~= nil
        if not hasTracked then
            Wait(1500)
        else
        Wait(500)
        for veh, meta in pairs(TRACKED) do
            if not DoesEntityExist(veh) then
                stopScriptSound(veh)
                removeLightbar(veh)
                removeKitPerformance(veh)
                TRACKED[veh] = nil
            else
                local mode = select(1, readVehicleStateBag(veh))
                if mode ~= 'off' and meta.supportsNative then
                    if mode == 'lights' then
                        SetVehicleSiren(veh, true)
                        SetVehicleHasMutedSirens(veh, true)
                    elseif mode == 'full' then
                        SetVehicleSiren(veh, true)
                        SetVehicleHasMutedSirens(veh, Entity(veh).state.fpSirenMuted == true)
                    elseif mode == 'sound' then
                        stopNativeSirenVisual(veh)
                    end
                end
            end
        end
        end
    end
end)

CreateThread(function()
    while true do
        local sleep = 100
        local drew = false
        for veh, meta in pairs(TRACKED) do
            if not DoesEntityExist(veh) then
                stopScriptSound(veh)
                removeLightbar(veh)
                removeKitPerformance(veh)
                TRACKED[veh] = nil
            else
                local mode = select(1, readVehicleStateBag(veh))
                local nat = meta.supportsNative
                if (mode == 'lights' or mode == 'full') and (not nat) then
                    drawScriptFlash(veh)
                    drew = true
                end
            end
        end
        if not drew then sleep = 400 end
        Wait(sleep)
    end
end)

--- Sceninė sirena – garsą valdo mrp_siren_controller (tonai WAIL/YELP/PRIORITY).
CreateThread(function()
    while true do
        if next(TRACKED) == nil then
            Wait(1500)
        elseif GetResourceState('mrp_siren_controller') == 'started' then
            Wait(1200)
        else
        Wait(900)
        for veh, meta in pairs(TRACKED) do
            if not DoesEntityExist(veh) then
                stopScriptSound(veh)
                removeLightbar(veh)
                removeKitPerformance(veh)
                TRACKED[veh] = nil
            else
                local mode = select(1, readVehicleStateBag(veh))
                local nat = meta.supportsNative
                local needSound = (mode == 'sound') or (mode == 'full' and (not nat))
                if mode == 'off' then
                    stopScriptSound(veh)
                elseif needSound then
                    playShortSirenBurst(veh)
                else
                    stopScriptSound(veh)
                end
            end
        end
        end
    end
end)

CreateThread(function()
    local lastVehAsDriver = 0
    while true do
        Wait(275)
        local ped = PlayerPedId()
        local veh = GetVehiclePedIsIn(ped, false)
        if veh ~= 0 and GetPedInVehicleSeat(veh, -1) == ped then
            lastVehAsDriver = veh
            if emergencyOnDuty() then
                ingestFromEntity(veh)
                local _, kit = readVehicleStateBag(veh)
                if kit and not vehicleSupportsNativeEmergency(veh) and performanceTuneEnabled() then
                    syncKitPerformance(veh)
                end
            end
        elseif lastVehAsDriver ~= 0 then
            if RESET_ON_EXIT and DoesEntityExist(lastVehAsDriver) then
                local netId = safeVehicleNetId(lastVehAsDriver)
                if netId ~= 0 then
                    if pdOnDuty() then
                        TriggerServerEvent('mrp_ltpd:server:clearPdEmergencyOnExit', netId)
                    end
                    if emsOnDuty() then
                        TriggerServerEvent('mrp_siren:server:clearEmsEmergencyOnExit', netId)
                    end
                end
            end
            if DoesEntityExist(lastVehAsDriver) then ingestFromEntity(lastVehAsDriver) end
            lastVehAsDriver = 0
        end
    end
end)

local function getOccupiedVehicleLocal()
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    if not veh or veh == 0 then return nil end
    return veh
end

local function openSirenModesMenu()
    if not canPdSirenMenu() then
        return QBCore.Functions.Notify('Šis meniu – tik tarnybiniu policininkų.', 'error')
    end
    local veh = getOccupiedVehicleLocal()
    if not veh then
        return QBCore.Functions.Notify('Turi būti transporto salėje.', 'error')
    end
    local _, kit = readVehicleStateBag(veh)
    if (not vehicleSupportsNativeEmergency(veh)) and kit ~= true then
        local item = (Config.EmergencyVehicle or {}).kitItem or 'pd_emergency_kit'
        return QBCore.Functions.Notify(
            ('Ant įprastos TP pirmiau įdėk avarinę įrangą (itemas „%s“).'):format(item),
            'error'
        )
    end
    ingestFromEntity(veh)
    if GetResourceState('mrp_siren_controller') == 'started' then
        return exports['mrp_siren_controller']:OpenSirenController('police')
    end
    return QBCore.Functions.Notify('Reikia mrp_siren_controller resurso.', 'error')
end

RegisterNetEvent('mrp_ltpd:client:setPdEmergencyMode', function(data)
    local mode = data and data.mode or 'off'
    TriggerServerEvent('mrp_ltpd:server:setPdEmergencyMode', mode)
    SetTimeout(200, function()
        local veh = getDriverVehicleLocal()
        if veh then ingestFromEntity(veh) end
    end)
end)

local function openKitMenu()
    if not canPdEmergencyKit() then
        return QBCore.Functions.Notify('Neturi teisės montuoti įrangos.', 'error')
    end
    local veh = getDriverVehicleLocal()
    if not veh then
        return QBCore.Functions.Notify('Turi būti vairo vietoje.', 'error')
    end
    if vehicleSupportsNativeEmergency(veh) then
        return QBCore.Functions.Notify('Šiai mašinai nereikia – jau tarnybinė arba turi sirenas.', 'error')
    end
    if GetResourceState('qb-menu') ~= 'started' then
        return QBCore.Functions.Notify('Reikia qb-menu.', 'error')
    end
    local _, hasKit = readVehicleStateBag(veh)
    local menu = {
        { header = 'PD laikinos sirenos civilinei TP', txt = 'Iki nuėmimo statebag išlieka tame pačiame TA', isMenuHeader = true },
    }
    if not hasKit then
        menu[#menu + 1] = {
            header = 'Įmontuoti sirenas ir lempas',
            txt = 'Sunaudoja vieną „pd_emergency_kit“ iš inventoriaus.',
            params = { event = 'mrp_ltpd:client:setPdEmergencyKit', args = { equip = true } },
        }
    else
        menu[#menu + 1] = {
            header = 'Nuimti įrangą',
            txt = 'Įranga grąžinama į inventorių.',
            params = { event = 'mrp_ltpd:client:setPdEmergencyKit', args = { equip = false } },
        }
    end
    menu[#menu + 1] = { header = '< Užverti meniu', params = { event = 'qb-menu:client:closeMenu' } }
    TriggerEvent('qb-menu:client:openMenu', menu, false, true)
end

RegisterNetEvent('mrp_ltpd:client:openEmergencyKitMenu', function()
    openKitMenu()
end)

RegisterNetEvent('mrp_ltpd:client:setPdEmergencyKit', function(data)
    local equip = data and data.equip == true
    TriggerServerEvent('mrp_ltpd:server:setPdEmergencyKit', equip)
    SetTimeout(240, function()
        local veh = getDriverVehicleLocal()
        if veh then ingestFromEntity(veh) end
    end)
end)

local cmdLights = Ec.sirenMenuCommand or 'pdsirenai'
local cmdKit = Ec.kitMenuCommand or 'pdiranga'

RegisterCommand(cmdLights, function()
    runIfAdminCommand(openSirenModesMenu)
end, false)
RegisterCommand(cmdKit, function()
    runIfAdminCommand(openKitMenu)
end, false)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for veh, prop in pairs(LIGHTBARS) do
        if prop and DoesEntityExist(prop) then
            DeleteEntity(prop)
        end
        LIGHTBARS[veh] = nil
    end
    for veh in pairs(KIT_PERF) do
        if veh and DoesEntityExist(veh) then
            removeKitPerformance(veh)
        else
            KIT_PERF[veh] = nil
        end
    end
end)

CreateThread(function()
    while true do
        Wait(750)
        local ped = PlayerPedId()
        local veh = GetVehiclePedIsIn(ped, false)
        if veh == 0 or GetPedInVehicleSeat(veh, -1) ~= ped then
            goto continue
        end
        local _, kit = readVehicleStateBag(veh)
        if kit ~= true or vehicleSupportsNativeEmergency(veh) or not performanceTuneEnabled() then
            goto continue
        end
        syncKitPerformance(veh)
        ::continue::
    end
end)
