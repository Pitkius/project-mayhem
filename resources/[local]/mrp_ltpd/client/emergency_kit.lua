--- PD: šviestuvų ir sirenos režimai masinoje + laikina sirena ant civilinės mašinos (statebag ltPd*)
local QBCore = exports['qb-core']:GetCoreObject()

local TRACKED = {} --- [vehicle] = { supportsNative, mode }
local FLEET_BUILTIN = {} --- [vehicle] = { mode } — tik built-in ELS, be PD kit
local LIGHTBARS = {} --- [vehicle] = { bar, leftLens, rightLens }
local KIT_PERF = {} --- [vehicle] = { sig, orig }
local INGEST_SCHEDULED = {} --- [vehicle] = true
local fleetBoneCache = {} --- [veh] = { bones, checkedAt }
local lastSirenApplyMode = {} --- [veh] = mode — soft off→on tik keičiant režimą

local FLEET_HASHES = {}
local FLEET_CAR_HASHES = {}
local FLEET_MODEL_BY_HASH = {}
local BUILT_IN_FLEET_HASHES = {}
local function rebuildFleetHashes()
    FLEET_HASHES = {}
    FLEET_CAR_HASHES = {}
    FLEET_MODEL_BY_HASH = {}
    BUILT_IN_FLEET_HASHES = {}
    for _, name in ipairs(Config.BuiltInFleetModels or {}) do
        if name and name ~= '' then
            BUILT_IN_FLEET_HASHES[joaat(tostring(name):lower())] = true
        end
    end
    for _, v in ipairs(Config.FleetVehicles or {}) do
        if v and v.model then
            local h = joaat(v.model)
            local name = tostring(v.model):lower()
            FLEET_HASHES[h] = true
            FLEET_CAR_HASHES[h] = true
            FLEET_MODEL_BY_HASH[h] = name
            BUILT_IN_FLEET_HASHES[h] = true
        end
    end
    for _, v in ipairs(Config.FleetHelicopters or {}) do
        if v and v.model then
            local h = joaat(v.model)
            FLEET_HASHES[h] = true
            FLEET_MODEL_BY_HASH[h] = tostring(v.model):lower()
            BUILT_IN_FLEET_HASHES[h] = true
        end
    end
end
rebuildFleetHashes()

local Ec = Config.EmergencyVehicle or {}
-- Teisingas raktas: resetModeWhenLeaveDriverSeat (alias: resetWhenLeaveDriverSeat)
local RESET_ON_EXIT = true
if Ec.resetModeWhenLeaveDriverSeat ~= nil then
    RESET_ON_EXIT = Ec.resetModeWhenLeaveDriverSeat ~= false
elseif Ec.resetWhenLeaveDriverSeat ~= nil then
    RESET_ON_EXIT = Ec.resetWhenLeaveDriverSeat ~= false
end

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
    return FLEET_HASHES[hash] == true
end

--- MRPD / fleet su built-in ELS — PD įrangos scriptas (prop, DrawLight) neįsikiša.
local function usesBuiltInFleetLights(vehicle)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then return false end
    return BUILT_IN_FLEET_HASHES[GetEntityModel(vehicle)] == true
end

local function modelIsFleetCar(hash)
    return FLEET_CAR_HASHES[hash] == true
end

--- Fleet entry: emergencyLights = 'native' | 'hybrid' | 'script' | nil
--- native/hybrid → SetVehicleSiren; script → prop lightbar.
--- Hybrid/native + nativeFlashAssist → raudona/mėlyna flash ant stogo (be prop).
local FLEET_LIGHT_MODE = {}
local function rebuildFleetLightModes()
    FLEET_LIGHT_MODE = {}
    for _, v in ipairs(Config.FleetVehicles or {}) do
        if v and v.model then
            local mode = tostring(v.emergencyLights or v.lights or 'hybrid'):lower()
            if mode == 'kit' then mode = 'script' end
            if mode == 'hybrid' or mode == 'native' or mode == '' then
                mode = 'native' --- SetVehicleSiren kelias; flash assist atskirai
            elseif mode ~= 'script' then
                mode = 'native'
            end
            FLEET_LIGHT_MODE[joaat(v.model)] = mode
        end
    end
end
rebuildFleetLightModes()

local function fleetLightMode(hash)
    return FLEET_LIGHT_MODE[hash] or 'native'
end

--- Ar mašina turi savas PD šviesas (carcols sirens / extras) — naudoti jas, ne prop lightbar.
local function vehicleSupportsNativeEmergency(vehicle)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then return false end
    local hash = GetEntityModel(vehicle)

    -- Fleet: default native/hybrid. Tik explicit 'script' = prop lempos.
    if modelIsFleetCar(hash) then
        return fleetLightMode(hash) ~= 'script'
    end

    for _, name in ipairs({ 'IsThisModelEmergencyVehicle', 'IsThisModelAnEmergencyVehicle' }) do
        local fn = rawget(_G, name)
        if type(fn) == 'function' then
            local ok, r = pcall(fn, hash)
            if ok and r then return true end
        end
    end
    if Ec.trustVehicleClassEmergency == true and GetVehicleClass(vehicle) == 18 then
        return true
    end
    -- Helikopteriai / kiti fleet be car
    if modelIsFleet(hash) then return true end
    return false
end

--- Script lightbar / DrawLight TIK civilinei TP su kit, arba fleet su emergencyLights='script'.
--- (apibrėžiama po readVehicleStateBag)
local vehicleUsesScriptFlash

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

--- Be Wait() — saugoma kviesti iš statebag / net event (ne coroutine).
local function requestVehicleControl(vehicle)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then return false end
    if NetworkHasControlOfEntity(vehicle) then return true end
    NetworkRequestControlOfEntity(vehicle)
    return NetworkHasControlOfEntity(vehicle)
end

local function canApplyNativeSiren(vehicle)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then return false end
    if NetworkHasControlOfEntity(vehicle) then return true end
    return GetPedInVehicleSeat(vehicle, -1) == PlayerPedId()
end

--- Užtikrina network control su Wait — TIK CreateThread / SetTimeout kontekste.
local function ensureVehicleControl(vehicle, tries)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then return false end
    if NetworkHasControlOfEntity(vehicle) then return true end
    tries = tonumber(tries) or 25
    for _ = 1, tries do
        NetworkRequestControlOfEntity(vehicle)
        if NetworkHasControlOfEntity(vehicle) then return true end
        Wait(0)
    end
    return NetworkHasControlOfEntity(vehicle)
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

local function deleteLightEntity(ent)
    if ent and ent ~= 0 and DoesEntityExist(ent) then
        DetachEntity(ent, true, true)
        DeleteEntity(ent)
    end
end

local function removeLightbar(vehicle)
    local rig = LIGHTBARS[vehicle]
    if type(rig) == 'table' then
        deleteLightEntity(rig.leftLens)
        deleteLightEntity(rig.rightLens)
        deleteLightEntity(rig.bar)
    else
        deleteLightEntity(rig)
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

local function vehicleCanUseSirenMenu(vehicle)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then return false end
    if modelIsFleet(GetEntityModel(vehicle)) then return true end
    if vehicleSupportsNativeEmergency(vehicle) then return true end
    local _, kit = readVehicleStateBag(vehicle)
    return kit == true
end

vehicleUsesScriptFlash = function(vehicle)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then return false end
    --- Built-in fleet: jokio prop/script — tik modelio carcols.
    if usesBuiltInFleetLights(vehicle) then return false end
    local hash = GetEntityModel(vehicle)
    if modelIsFleetCar(hash) and fleetLightMode(hash) == 'script' then
        return true
    end
    local _, kit = readVehicleStateBag(vehicle)
    if kit == true and not vehicleSupportsNativeEmergency(vehicle) then
        return true
    end
    return false
end

local function loadModel(hash)
    if not hash or hash == 0 or not IsModelInCdimage(hash) then return false end
    RequestModel(hash)
    local tries = 0
    while not HasModelLoaded(hash) and tries < 80 do
        Wait(10)
        tries = tries + 1
    end
    return HasModelLoaded(hash)
end

local function attachLensToBar(barEnt, vehicle, side)
    local lensName = Ec.lensModel or 'prop_warninglight_01'
    local hash = joaat(lensName)
    if not loadModel(hash) then return nil end

    local offCfg = side == 'left' and Ec.lensLeftOffset or Ec.lensRightOffset
    local ox = tonumber(offCfg and offCfg.x) or (side == 'left' and -0.26 or 0.26)
    local oy = tonumber(offCfg and offCfg.y) or 0.0
    local oz = tonumber(offCfg and offCfg.z) or 0.07

    local c = GetEntityCoords(barEnt)
    local lens = CreateObject(hash, c.x, c.y, c.z, false, false, false)
    SetModelAsNoLongerNeeded(hash)
    if not lens or lens == 0 then return nil end

    SetEntityCollision(lens, false, false)
    SetEntityAsMissionEntity(lens, true, true)
    if Ec.lensHideProp == false then
        SetEntityAlpha(lens, 255, false)
    else
        SetEntityAlpha(lens, 0, false)
    end
    AttachEntityToEntity(lens, barEnt, 0, ox, oy, oz, 0.0, 0.0, 0.0, false, false, false, false, 2, true)
    return lens
end

local function ensureLightbar(vehicle)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then return end
    --- Prop lightbar tik kai script flash (civilinis kit / explicit script fleet)
    if not vehicleUsesScriptFlash(vehicle) then
        removeLightbar(vehicle)
        return
    end
    local _, kit = readVehicleStateBag(vehicle)
    local hash = GetEntityModel(vehicle)
    local forceScript = modelIsFleetCar(hash) and fleetLightMode(hash) == 'script'
    if not forceScript and kit ~= true then
        removeLightbar(vehicle)
        return
    end

    local rig = LIGHTBARS[vehicle]
    if type(rig) == 'table' and rig.bar and DoesEntityExist(rig.bar) then
        if rig.leftLens and DoesEntityExist(rig.leftLens) and rig.rightLens and DoesEntityExist(rig.rightLens) then
            return
        end
        removeLightbar(vehicle)
    elseif rig and DoesEntityExist(rig) then
        removeLightbar(vehicle)
    end

    local modelName = Ec.lightbarModel or 'prop_lightbar_01'
    local hash = joaat(modelName)
    if not loadModel(hash) then return end

    local c = GetEntityCoords(vehicle)
    local bar = CreateObject(hash, c.x, c.y, c.z + 1.0, false, false, false)
    SetModelAsNoLongerNeeded(hash)
    if not bar or bar == 0 then return end

    SetEntityCollision(bar, false, false)
    SetEntityAsMissionEntity(bar, true, true)

    local bone = GetEntityBoneIndexByName(vehicle, 'roof')
    local yOff = tonumber(Ec.lightbarYOffset) or -0.10
    local zOff = tonumber(Ec.lightbarZOffset) or 0.06
    if bone == -1 then
        bone = GetEntityBoneIndexByName(vehicle, 'bodyshell')
        local mn, mx = GetModelDimensions(GetEntityModel(vehicle))
        zOff = mx.z + 0.02 + zOff
    end
    AttachEntityToEntity(bar, vehicle, bone, 0.0, yOff, zOff, 0.0, 0.0, 0.0, false, false, false, false, 2, true)

    local leftLens = attachLensToBar(bar, vehicle, 'left')
    local rightLens = attachLensToBar(bar, vehicle, 'right')
    LIGHTBARS[vehicle] = { bar = bar, leftLens = leftLens, rightLens = rightLens }
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
    if vehicleUsesScriptFlash(vehicle) then
        ensureLightbar(vehicle)
        local _, kit = readVehicleStateBag(vehicle)
        if kit then
            syncKitPerformance(vehicle)
        else
            removeKitPerformance(vehicle)
        end
    else
        removeLightbar(vehicle)
        removeKitPerformance(vehicle)
    end
end

local function cleanupVehicleEmergency(vehicle)
    if not vehicle then return end
    stopScriptSound(vehicle)
    removeLightbar(vehicle)
    removeKitPerformance(vehicle)
    INGEST_SCHEDULED[vehicle] = nil
    fleetBoneCache[vehicle] = nil
    lastSirenApplyMode[vehicle] = nil
    TRACKED[vehicle] = nil
    FLEET_BUILTIN[vehicle] = nil
end

local function lensWorldPos(lensEnt, barEnt, vehicle, side)
    if lensEnt and lensEnt ~= 0 and DoesEntityExist(lensEnt) then
        return GetEntityCoords(lensEnt)
    end
    if barEnt and barEnt ~= 0 and DoesEntityExist(barEnt) then
        local offCfg = side == 'left' and Ec.lensLeftOffset or Ec.lensRightOffset
        local ox = tonumber(offCfg and offCfg.x) or (side == 'left' and -0.26 or 0.26)
        local oy = tonumber(offCfg and offCfg.y) or 0.0
        local oz = tonumber(offCfg and offCfg.z) or 0.07
        return GetOffsetFromEntityInWorldCoords(barEnt, ox, oy, oz)
    end
    local mn, mx = GetModelDimensions(GetEntityModel(vehicle))
    local halfW = math.max(0.22, (mx.x - mn.x) * 0.22)
    local roofZ = mx.z - 0.04
    local xOff = side == 'left' and -halfW or halfW
    return GetOffsetFromEntityInWorldCoords(vehicle, xOff, 0.0, roofZ)
end

local function vehicleBeamForward(vehicle)
    local fwd = GetEntityForwardVector(vehicle)
    local len = #(fwd)
    if len < 0.01 then return vector3(0.0, 1.0, 0.0) end
    return vector3(fwd.x / len, fwd.y / len, fwd.z / len)
end

local function worldLightPoints(vehicle)
    local rig = LIGHTBARS[vehicle]
    local barEnt = type(rig) == 'table' and rig.bar or rig
    local leftPos = lensWorldPos(type(rig) == 'table' and rig.leftLens or nil, barEnt, vehicle, 'left')
    local rightPos = lensWorldPos(type(rig) == 'table' and rig.rightLens or nil, barEnt, vehicle, 'right')
    local centerPos
    if barEnt and DoesEntityExist(barEnt) then
        centerPos = GetEntityCoords(barEnt)
    else
        local mn, mx = GetModelDimensions(GetEntityModel(vehicle))
        centerPos = GetOffsetFromEntityInWorldCoords(vehicle, 0.0, 0.0, mx.z - 0.04)
    end
    return centerPos, leftPos, rightPos, centerPos, vehicleBeamForward(vehicle)
end

local function flashColor(name)
    local palette = Ec.flashColors or {}
    local c = palette[name]
    if not c then
        if name == 'red' then return 255, 48, 52 end
        if name == 'blue' then return 58, 128, 255 end
        return 248, 252, 255
    end
    return tonumber(c.r) or 255, tonumber(c.g) or 255, tonumber(c.b) or 255
end

local function drawLensMarker(x, y, z, r, g, b, alpha, scale)
    scale = scale or (tonumber(Ec.flashMarkerScale) or 0.048)
    DrawMarker(
        28,
        x, y, z,
        0.0, 0.0, 0.0,
        0.0, 0.0, 0.0,
        scale, scale, scale,
        r, g, b, alpha,
        false, false, 2, false, false, false, false
    )
end

local function drawLensLight(x, y, z, r, g, b, enhanced)
    local coreScale = tonumber(Ec.flashMarkerScale) or 0.048
    drawLensMarker(x, y, z, r, g, b, 235, coreScale)
    if not enhanced or Ec.flashUseLensGlow == false then return end
    local glowScale = tonumber(Ec.flashMarkerGlowScale) or 0.115
    drawLensMarker(x, y, z, r, g, b, 95, glowScale)
    drawLensMarker(x, y, z, r, g, b, 42, glowScale * 1.28)
end

local function drawEmergencyBeam(origin, dir, r, g, b, intensityMul)
    local spotR = tonumber(Ec.flashSpotRange) or 16.0
    local spotI = (tonumber(Ec.flashSpotIntensity) or 5.0) * (tonumber(intensityMul) or 1.0)
    DrawSpotLight(origin.x, origin.y, origin.z, dir.x, dir.y, dir.z, r, g, b, spotR, spotI, 0.0, spotR * 0.78, 1.0)
end

local function drawAmbientGlow(x, y, z, r, g, b)
    local lightRange = tonumber(Ec.flashLightRange) or 9.5
    local lightPower = tonumber(Ec.flashLightIntensity) or 3.4
    if lightRange <= 0 or lightPower <= 0 then return end
    DrawLightWithRange(x, y, z, r, g, b, lightRange, lightPower)
end

local function drawBarPulse(centerPos, r, g, b)
    if not centerPos or Ec.flashUseBarGlow == false then return end
    local scale = (tonumber(Ec.flashMarkerScale) or 0.048) * 0.82
    drawLensMarker(centerPos.x, centerPos.y, centerPos.z + 0.02, r, g, b, 110, scale)
    local wr, wg, wb = flashColor('white')
    drawLensMarker(centerPos.x, centerPos.y, centerPos.z + 0.02, wr, wg, wb, 55, scale * 0.65)
end

local function pulseVisibleLensEntity(lensEnt, active)
    if not lensEnt or lensEnt == 0 or not DoesEntityExist(lensEnt) then return end
    if Ec.lensHideProp ~= false then return end
    SetEntityAlpha(lensEnt, active and 255 or 120, false)
end

local function drawScriptFlash(vehicle, viewerDist)
    if not DoesEntityExist(vehicle) then return end

    local interval = tonumber(Ec.flashIntervalMs) or 480
    local phase = math.floor(GetGameTimer() / interval) % 2 == 0
    local centerPos, leftPos, rightPos, _, beamDir = worldLightPoints(vehicle)
    local useAmbient = Ec.flashUseAmbientGlow ~= false
    local enhanced = (Ec.flashVisualPreset or 'enhanced') ~= 'standard'
    local nearDist = tonumber(Ec.flashNearSpotDistance) or 32.0
    local useSpot = Ec.flashUseSpotBeams == true
        or (Ec.flashUseNearSpotBeams == true and (viewerDist or 999.0) <= nearDist)
    local spotMul = (viewerDist or 999.0) <= (nearDist * 0.55) and 1.0 or 0.82

    local rr, rg, rb = flashColor('red')
    local br, bg, bb = flashColor('blue')
    local rig = LIGHTBARS[vehicle]

    if phase then
        if type(rig) == 'table' then
            pulseVisibleLensEntity(rig.leftLens, true)
            pulseVisibleLensEntity(rig.rightLens, false)
        end
        drawLensLight(leftPos.x, leftPos.y, leftPos.z, rr, rg, rb, enhanced)
        if useAmbient then drawAmbientGlow(leftPos.x, leftPos.y, leftPos.z, rr, rg, rb) end
        if useSpot then drawEmergencyBeam(leftPos, beamDir, rr, rg, rb, spotMul) end
        if enhanced then drawBarPulse(centerPos, rr, rg, rb) end
    else
        if type(rig) == 'table' then
            pulseVisibleLensEntity(rig.leftLens, false)
            pulseVisibleLensEntity(rig.rightLens, true)
        end
        drawLensLight(rightPos.x, rightPos.y, rightPos.z, br, bg, bb, enhanced)
        if useAmbient then drawAmbientGlow(rightPos.x, rightPos.y, rightPos.z, br, bg, bb) end
        if useSpot then drawEmergencyBeam(rightPos, beamDir, br, bg, bb, spotMul) end
        if enhanced then drawBarPulse(centerPos, br, bg, bb) end
    end
end

local function safeVehicleNetId(vehicle)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then return 0 end
    return NetworkGetNetworkIdFromEntity(vehicle)
end

--- Lightbar extras: enable-all tik jei modelis turi extras (daug MRPD neturi).
local function ensureFleetLightbarExtras(vehicle)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then return end
    if not usesBuiltInFleetLights(vehicle) and not modelIsFleet(GetEntityModel(vehicle)) then return end
    for i = 0, 20 do
        if DoesExtraExist(vehicle, i) then
            SetVehicleExtra(vehicle, i, 0)
        end
    end
end

local SIREN_BONE_NAMES = {
    'siren', 'siren1', 'siren2', 'siren3', 'siren4', 'siren5', 'siren6',
    'siren7', 'siren8', 'siren9', 'siren10', 'siren11', 'siren12',
    'siren13', 'siren14', 'siren15', 'siren16', 'siren17', 'siren18',
    'siren19', 'siren20',
}

local function getFleetSirenBones(vehicle)
    local cached = fleetBoneCache[vehicle]
    local now = GetGameTimer()
    if cached and (now - (cached.checkedAt or 0)) < 5000 then
        return cached.bones
    end
    local bones = {}
    for i = 1, #SIREN_BONE_NAMES do
        local idx = GetEntityBoneIndexByName(vehicle, SIREN_BONE_NAMES[i])
        if idx and idx ~= -1 then
            bones[#bones + 1] = idx
        end
    end
    fleetBoneCache[vehicle] = { bones = bones, checkedAt = now }
    return bones
end

--- R/B tik ant modelio siren kaulų — viena spalva per fazę (R+B kartu = balta).
local function drawFleetSirenBoneLights(vehicle)
    if Ec.fleetSirenBoneLights == false then return end
    local bones = getFleetSirenBones(vehicle)
    if #bones == 0 then return end

    --- Max 4 taškai — 20 DrawLight = baltas bloom.
    local maxPts = math.max(2, math.min(4, tonumber(Ec.fleetSirenBoneMaxPoints) or 4))
    local selected = {}
    if #bones <= maxPts then
        for i = 1, #bones do selected[i] = bones[i] end
    else
        for i = 1, maxPts do
            local idx = math.floor((i - 1) * (#bones - 1) / (maxPts - 1)) + 1
            selected[#selected + 1] = bones[idx]
        end
    end

    local interval = tonumber(Ec.fleetSirenBoneIntervalMs) or 420
    local phase = math.floor(GetGameTimer() / interval) % 2 == 0
    local range = tonumber(Ec.fleetSirenBoneRange) or 5.5
    local power = tonumber(Ec.fleetSirenBoneIntensity) or 3.2
    local r, g, b
    if phase then
        r, g, b = flashColor('red')
    else
        r, g, b = flashColor('blue')
    end

    for i = 1, #selected do
        local pos = GetWorldPositionOfEntityBone(vehicle, selected[i])
        if pos then
            DrawLightWithRange(pos.x, pos.y, pos.z, r, g, b, range, power)
        end
    end
end

local function setMutedForMode(vehicle, mode)
    if mode == 'lights' then
        SetVehicleHasMutedSirens(vehicle, true)
    elseif mode == 'full' then
        SetVehicleHasMutedSirens(vehicle, Entity(vehicle).state.fpSirenMuted == true)
    end
end

--- Įjungia modelio policijos lempas (carcols ant mesh) — be jokių script lempų.
local function applyBuiltInFleetLights(vehicle, mode)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then return end
    mode = tostring(mode or 'off'):lower()
    if mode ~= 'lights' and mode ~= 'full' then return end
    if lastSirenApplyMode[vehicle] == mode and IsVehicleSirenOn(vehicle) then
        setMutedForMode(vehicle, mode)
        return
    end

    NetworkRequestControlOfEntity(vehicle)
    SetVehicleEngineOn(vehicle, true, true, false)
    lastSirenApplyMode[vehicle] = mode

    --- Tik GTA native: įjungia lempas, kurios jau yra ant modelio.
    SetVehicleSiren(vehicle, true)
    if mode == 'lights' then
        --- Tylios lempos (garsą duoda F6 / mrp_siren_controller).
        SetVehicleHasMutedSirens(vehicle, true)
    else
        SetVehicleHasMutedSirens(vehicle, Entity(vehicle).state.fpSirenMuted == true)
    end
end

local function ingestBuiltInFleet(vehicle, mode)
    removeLightbar(vehicle)
    removeKitPerformance(vehicle)
    TRACKED[vehicle] = nil
    FLEET_BUILTIN[vehicle] = { mode = mode }

    if mode == 'off' then
        stopNativeSirenVisual(vehicle)
        stopScriptSound(vehicle)
        lastSirenApplyMode[vehicle] = 'off'
        FLEET_BUILTIN[vehicle] = nil
        return
    end

    if mode == 'sound' then
        --- Tik garsas — modelio lempos OFF.
        stopNativeSirenVisual(vehicle)
        stopScriptSound(vehicle)
        lastSirenApplyMode[vehicle] = 'sound'
        return
    end

    if mode == 'lights' or mode == 'full' then
        stopScriptSound(vehicle)
        applyBuiltInFleetLights(vehicle, mode)
    end
end

--- Soft off→on TIK kai keičiasi režimas (ne kiekvieną tick) — atgaivina carcols be balto spam.

local function applyNativeForEveryone(vehicle, mode)
    if not DoesEntityExist(vehicle) then return end
    if not vehicleSupportsNativeEmergency(vehicle) then return end
    mode = tostring(mode or 'off'):lower()
    if mode == 'off' or mode == 'sound' then
        stopNativeSirenVisual(vehicle)
        lastSirenApplyMode[vehicle] = mode
        return
    end

    --- Civilinis native kelias — tas pats soft kick be Wait eventuose.
    return applyBuiltInFleetLights(vehicle, mode)
end

local function ingestPdKitVehicle(vehicle, forcedMode)
    if not vehicle or vehicle == 0 or not IsEntityAVehicle(vehicle) or not DoesEntityExist(vehicle) then return end
    FLEET_BUILTIN[vehicle] = nil
    local mode, kit = readVehicleStateBag(vehicle)
    if type(forcedMode) == 'string' and forcedMode ~= '' then
        mode = forcedMode:lower()
    end
    local supportsNative = vehicleSupportsNativeEmergency(vehicle)
    local scriptFlash = vehicleUsesScriptFlash(vehicle)
    if supportsNative and not scriptFlash then
        removeLightbar(vehicle)
    end
    TRACKED[vehicle] = TRACKED[vehicle] or {}
    TRACKED[vehicle].supportsNative = supportsNative
    TRACKED[vehicle].scriptFlash = scriptFlash
    TRACKED[vehicle].roofFlash = false
    TRACKED[vehicle].assistFlash = false
    TRACKED[vehicle].fleetBoneLights = false
    TRACKED[vehicle].mode = mode
    syncKitVisuals(vehicle)

    if mode == 'off' then
        stopNativeSirenVisual(vehicle)
        stopScriptSound(vehicle)
        fleetBoneCache[vehicle] = nil
        lastSirenApplyMode[vehicle] = 'off'
        if not kit then
            cleanupVehicleEmergency(vehicle)
        end
        return
    elseif mode == 'lights' then
        stopScriptSound(vehicle)
        if scriptFlash then
            stopNativeSirenVisual(vehicle)
        else
            applyNativeForEveryone(vehicle, mode)
        end
    elseif mode == 'sound' then
        stopNativeSirenVisual(vehicle)
        lastSirenApplyMode[vehicle] = 'sound'
    elseif mode == 'full' then
        if not scriptFlash then
            applyNativeForEveryone(vehicle, 'full')
        end
    end
end

local function ingestFromEntity(vehicle, forcedMode)
    if not vehicle or vehicle == 0 or not IsEntityAVehicle(vehicle) or not DoesEntityExist(vehicle) then return end
    local mode
    if type(forcedMode) == 'string' and forcedMode ~= '' then
        mode = forcedMode:lower()
    else
        mode = select(1, readVehicleStateBag(vehicle))
    end
    if usesBuiltInFleetLights(vehicle) then
        return ingestBuiltInFleet(vehicle, mode)
    end
    return ingestPdKitVehicle(vehicle, mode)
end

local function requestEmergencyRestoreIfNeeded(vehicle)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then return end
    --- Fleet MRPD: F6 režimas be pd_emergency_kit — restore iš DB išjungdavo ltPdSirenMode.
    if usesBuiltInFleetLights(vehicle) then return end
    if modelIsFleet(GetEntityModel(vehicle)) then return end
    local _, kit = readVehicleStateBag(vehicle)
    if kit then return end
    local netId = safeVehicleNetId(vehicle)
    if netId == 0 then return end
    TriggerServerEvent('mrp_ltpd:server:restoreVehicleEmergency', netId)
end

local function scheduleIngest(vehicle)
    if not vehicle or vehicle == 0 then return end
    if INGEST_SCHEDULED[vehicle] then return end
    INGEST_SCHEDULED[vehicle] = true
    SetTimeout(60, function()
        INGEST_SCHEDULED[vehicle] = nil
        if DoesEntityExist(vehicle) then
            ingestFromEntity(vehicle)
        end
    end)
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
    local ent = resolveEntityFromBagName(bagName)
    if ent ~= 0 and IsEntityAVehicle(ent) then
        scheduleIngest(ent)
    end
end

AddStateBagChangeHandler('ltPdSirenMode', '', onAnyPdBag)
AddStateBagChangeHandler('ltEmsSirenMode', '', onAnyPdBag)

AddStateBagChangeHandler('ltPdKit', '', onAnyPdBag)
AddStateBagChangeHandler('ltEmsKit', '', onAnyPdBag)
AddStateBagChangeHandler('fpSirenMuted', '', onAnyPdBag)

CreateThread(function()
    local drawDistance = tonumber(Ec.flashDrawDistance) or 55.0
    local tickMs = math.max(50, tonumber(Ec.flashTickMs) or 80)
    while true do
        local drew = false
        if next(TRACKED) ~= nil then
            local ped = PlayerPedId()
            local pCoords = GetEntityCoords(ped)
            for veh, meta in pairs(TRACKED) do
                if not DoesEntityExist(veh) then
                    cleanupVehicleEmergency(veh)
                else
                    local mode = meta.mode or select(1, readVehicleStateBag(veh))
                    meta.mode = mode
                    --- Script flash tik civiliniam pd_emergency_kit (prop lightbar)
                    if (mode == 'lights' or mode == 'full') and meta.scriptFlash == true then
                        local vehCoords = GetEntityCoords(veh)
                        if #(pCoords - vehCoords) <= drawDistance then
                            drawScriptFlash(veh, #(pCoords - vehCoords))
                            drew = true
                        end
                    elseif (mode == 'lights' or mode == 'full') and meta.fleetBoneLights then
                        local vehCoords = GetEntityCoords(veh)
                        if #(pCoords - vehCoords) <= drawDistance then
                            drawFleetSirenBoneLights(veh)
                            drew = true
                        end
                    end
                end
            end
        end
        Wait(drew and tickMs or (next(TRACKED) and 400 or 1200))
    end
end)

--- Natyvios sirenos: tik įjungti jei išjungtos. NIEKADA off→on (sugadina R/B sequencerį → balta).
CreateThread(function()
    while true do
        local anyLights = false
        if next(TRACKED) ~= nil then
            for veh, meta in pairs(TRACKED) do
                if DoesEntityExist(veh) and meta.supportsNative then
                    local mode = meta.mode or select(1, readVehicleStateBag(veh))
                    meta.mode = mode
                    if mode == 'lights' or mode == 'full' then
                        anyLights = true
                        if not NetworkHasControlOfEntity(veh) then
                            NetworkRequestControlOfEntity(veh)
                        end
                        ensureFleetLightbarExtras(veh)
                        if not IsVehicleSirenOn(veh) then
                            SetVehicleSiren(veh, true)
                            SetVehicleHasMutedSirens(veh, true)
                        end
                    elseif mode == 'sound' then
                        if IsVehicleSirenOn(veh) then
                            stopNativeSirenVisual(veh)
                        end
                    end
                elseif not DoesEntityExist(veh) then
                    cleanupVehicleEmergency(veh)
                end
            end
        end
        Wait(anyLights and 400 or 800)
    end
end)

--- Fleet: palaikyti modelio lempas ON (ne kiekvieną frame — gadina carcols).
CreateThread(function()
    while true do
        local any = false
        if next(FLEET_BUILTIN) ~= nil then
            for veh, meta in pairs(FLEET_BUILTIN) do
                if not DoesEntityExist(veh) then
                    cleanupVehicleEmergency(veh)
                else
                    local mode = meta.mode or select(1, readVehicleStateBag(veh))
                    meta.mode = mode
                    if mode == 'lights' or mode == 'full' then
                        any = true
                        if NetworkHasControlOfEntity(veh) or GetPedInVehicleSeat(veh, -1) == PlayerPedId() then
                            if not IsVehicleSirenOn(veh) then
                                SetVehicleSiren(veh, true)
                            end
                            setMutedForMode(veh, mode)
                        else
                            NetworkRequestControlOfEntity(veh)
                        end
                    elseif (mode == 'sound' or mode == 'off') and IsVehicleSirenOn(veh) then
                        if NetworkHasControlOfEntity(veh) or GetPedInVehicleSeat(veh, -1) == PlayerPedId() then
                            stopNativeSirenVisual(veh)
                        end
                    end
                end
            end
        end
        Wait(any and 500 or 1000)
    end
end)

--- Periodiškai tik lightbar candidate extras (ne enable-all).
CreateThread(function()
    while true do
        local onDuty = emergencyOnDuty()
        local tracking = next(TRACKED) ~= nil
        if not onDuty and not tracking then
            Wait(8000)
        else
            Wait(onDuty and 9000 or 12000)
            local ped = PlayerPedId()
            local pCoords = GetEntityCoords(ped)
            local pool = GetGamePool('CVehicle')
            for i = 1, #pool do
                local veh = pool[i]
                if DoesEntityExist(veh) and #(GetEntityCoords(veh) - pCoords) <= 90.0 then
                    ensureFleetLightbarExtras(veh)
                end
            end
        end
    end
end)

--- Atsarginis garsas tik jei mrp_siren_controller neveikia.
CreateThread(function()
    while true do
        if next(TRACKED) == nil then
            Wait(1500)
        elseif GetResourceState('mrp_siren_controller') == 'started' then
            Wait(2000)
        else
            Wait(950)
            for veh, meta in pairs(TRACKED) do
                if not DoesEntityExist(veh) then
                    cleanupVehicleEmergency(veh)
                else
                    local mode = meta.mode or select(1, readVehicleStateBag(veh))
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
    local exitMissTicks = 0
    -- ~1.1s patvirtinimas — GetVehiclePedIsIn kartais trumpam grąžina 0 ir anksčiau išjungdavo sirenas
    local EXIT_CONFIRM_TICKS = 4
    while true do
        Wait(275)
        local ped = PlayerPedId()
        local veh = GetVehiclePedIsIn(ped, false)
        local isDriver = veh ~= 0 and GetPedInVehicleSeat(veh, -1) == ped
        -- Atsarginis check: jei GetVehiclePedIsIn „mirktelėjo“, bet ped vis dar vairuotojo sėdynėje
        if not isDriver and lastVehAsDriver ~= 0 and DoesEntityExist(lastVehAsDriver)
            and GetPedInVehicleSeat(lastVehAsDriver, -1) == ped then
            isDriver = true
            veh = lastVehAsDriver
        end
        if isDriver then
            lastVehAsDriver = veh
            exitMissTicks = 0
            if emergencyOnDuty() then
                --- Fleet: ne spam'inti ingest kiekvieną tick (gadina native lempas).
                if usesBuiltInFleetLights(veh) then
                    local cur = FLEET_BUILTIN[veh]
                    local mode = select(1, readVehicleStateBag(veh))
                    if not cur or cur.mode ~= mode then
                        scheduleIngest(veh)
                    end
                else
                    requestEmergencyRestoreIfNeeded(veh)
                    scheduleIngest(veh)
                end
            end
        elseif lastVehAsDriver ~= 0 then
            exitMissTicks = exitMissTicks + 1
            if exitMissTicks >= EXIT_CONFIRM_TICKS then
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
                exitMissTicks = 0
            end
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
    if not vehicleCanUseSirenMenu(veh) then
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
    if vehicleSupportsNativeEmergency(veh) or usesBuiltInFleetLights(veh) then
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

RegisterNetEvent('mrp_ltpd:client:vehicleEmergencyRestored', function(netId)
    netId = tonumber(netId) or 0
    if netId <= 0 then return end
    if type(NetworkDoesNetworkIdExist) == 'function' and not NetworkDoesNetworkIdExist(netId) then return end
    local ent = NetworkGetEntityFromNetworkId(netId)
    if ent ~= 0 and IsEntityAVehicle(ent) then
        scheduleIngest(ent)
    end
end)

--- Server priverstinai sinchronizuoja šviesas visiems klientams (ne tik statebag).
RegisterNetEvent('mrp_ltpd:client:forceEmergencyVisual', function(netId, mode)
    netId = tonumber(netId) or 0
    if netId <= 0 then return end
    if type(NetworkDoesNetworkIdExist) == 'function' and not NetworkDoesNetworkIdExist(netId) then return end
    local ent = NetworkGetEntityFromNetworkId(netId)
    if ent == 0 or not DoesEntityExist(ent) or not IsEntityAVehicle(ent) then return end
    mode = type(mode) == 'string' and mode:lower() or nil
    --- Per CreateThread — saugus Wait / SetTimeout kontekstas.
    CreateThread(function()
        if mode then
            if not usesBuiltInFleetLights(ent) then
                TRACKED[ent] = TRACKED[ent] or {}
                TRACKED[ent].mode = mode
            end
            lastSirenApplyMode[ent] = nil
            ingestFromEntity(ent, mode)
        else
            ingestFromEntity(ent)
        end
    end)
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for veh in pairs(LIGHTBARS) do
        removeLightbar(veh)
    end
    for veh in pairs(KIT_PERF) do
        if veh and DoesEntityExist(veh) then
            removeKitPerformance(veh)
        else
            KIT_PERF[veh] = nil
        end
    end
end)

exports('EnsureFleetLightbarExtras', ensureFleetLightbarExtras)

RegisterCommand('pdlightsdebug', function()
    local veh = GetVehiclePedIsIn(PlayerPedId(), false)
    if not veh or veh == 0 then
        return QBCore.Functions.Notify('Nesi transporte.', 'error')
    end
    local mode = select(1, readVehicleStateBag(veh))
    local builtIn = usesBuiltInFleetLights(veh)
    requestVehicleControl(veh)
    if builtIn and (mode == 'lights' or mode == 'full') then
        lastSirenApplyMode[veh] = nil
        ingestBuiltInFleet(veh, mode)
    end
    SetTimeout(200, function()
        if not DoesEntityExist(veh) then return end
        local msg = ('mode=%s | sirenOn=%s | builtIn=%s | ctrl=%s | class=%s | boneFlash=off'):format(
            tostring(mode),
            tostring(IsVehicleSirenOn(veh)),
            tostring(builtIn),
            tostring(NetworkHasControlOfEntity(veh)),
            tostring(GetVehicleClass(veh))
        )
        QBCore.Functions.Notify(msg, 'primary', 12000)
        print('[mrp_ltpd/pdlightsdebug] ' .. msg)
    end)
end, false)
