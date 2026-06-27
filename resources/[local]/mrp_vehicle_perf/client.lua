local QBCore = exports['qb-core']:GetCoreObject()

local cfg = Config.VehiclePerf or {}
local handlingCfg = cfg.Handling or {}
local modelIndex = {}
local activeVeh = 0
local activeMaxMs = 0.0
local originalHandlingByHash = {}
local appliedSigByVeh = {}

local NON_ROAD_CATEGORIES = {
    boats = true,
    helicopters = true,
    planes = true,
    cycles = true,
    trains = true,
}

local function isRoadCategory(category)
    return category and not NON_ROAD_CATEGORIES[category]
end

local HANDLING_FIELDS = {
    'fInitialDriveForce',
    'fInitialDriveMaxFlatVel',
    'fBrakeForce',
    'fDriveInertia',
    'fInitialDragCoeff',
    'fTractionCurveMax',
    'fTractionCurveMin',
    'fSteeringLock',
    'fLowSpeedTractionLossMult',
    'fMass',
    'fDownforceModifier',
    'fSuspensionForce',
}

local function kmhToMs(kmh)
    return (tonumber(kmh) or 0) / 3.6
end

local function clamp(v, lo, hi)
    v = tonumber(v) or lo
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

local function getHandlingFloat(veh, field)
    return GetVehicleHandlingFloat(veh, 'CHandlingData', field)
end

local function setHandlingFloat(veh, field, value)
    SetVehicleHandlingFloat(veh, 'CHandlingData', field, value)
end

local function isRehModel(name)
    local row = modelIndex[name and joaat(name) or 0]
    return row and row.isReh
end

local function isHyperModel(name)
    return name and cfg.HyperCars and cfg.HyperCars[name] == true
end

local function isFullyTuned(veh)
    if not veh or veh == 0 then return false end
    local eng = GetVehicleMod(veh, 11)
    local needEng = tonumber(cfg.FullTuneMinEngineMod) or 4
    if eng < 0 then eng = 0 end
    if eng < needEng then return false end
    if cfg.RequireTurboForHyperBonus ~= false and not IsToggleModOn(veh, 18) then
        return false
    end
    return true
end

local function categoryCapKmh(category)
    local caps = cfg.VanillaCategoryCap or {}
    return caps[category]
end

local function estimatedModelKmh(hash)
    return (GetVehicleModelEstimatedMaxSpeed(hash) or 0.0) * 3.6
end

local function accelToZeroTo100(accel)
    accel = tonumber(accel) or 0.1
    return 27.777 / math.max(0.08, accel * 7.5)
end

local function cacheOriginalHandling(veh, hash)
    if originalHandlingByHash[hash] then
        return originalHandlingByHash[hash]
    end
    local snap = {}
    for _, field in ipairs(HANDLING_FIELDS) do
        snap[field] = getHandlingFloat(veh, field)
    end
    originalHandlingByHash[hash] = snap
    return snap
end

local function resolveMaxKmh(veh)
    if not cfg.Enabled then return nil end
    if not veh or veh == 0 then return nil end

    local hash = GetEntityModel(veh)
    local row = modelIndex[hash]
    local name = row and row.name or nil
    local category = (row and row.category) or 'sedans'

    if not isRoadCategory(category) then
        return nil
    end

    if name and cfg.HyperCars and cfg.HyperCars[name] then
        if isFullyTuned(veh) then
            return tonumber(cfg.HyperTunedMaxKmh) or 330
        end
        local untuned = cfg.HyperUntunedKmh and cfg.HyperUntunedKmh[name]
        return tonumber(untuned) or tonumber(cfg.GlobalCapKmh) or 310
    end

    if name and cfg.RehMaxKmh and cfg.RehMaxKmh[name] then
        return math.min(cfg.RehMaxKmh[name], cfg.GlobalCapKmh or 310)
    end

    if name and VanillaMaxKmh and VanillaMaxKmh[name] then
        local kmh = tonumber(VanillaMaxKmh[name])
        local cap = categoryCapKmh(category)
        if cap and kmh then kmh = math.min(kmh, cap) end
        return math.min(kmh or 215, cfg.GlobalCapKmh or 310)
    end

    if row and row.isReh then
        local catKmh = (cfg.RehCategoryKmh or {})[category] or 218
        return math.min(catKmh, cfg.GlobalCapKmh or 310)
    end

    local cap = categoryCapKmh(category)
    local est = estimatedModelKmh(hash)
    if cap and est > cap + 2.0 then
        return cap
    end

    return nil
end

local function resolveZeroTo100Target(name, category, maxKmh, veh)
    local perfCategory = VehiclePricing.ResolveEffectiveCategory(category, maxKmh)
    local fromPricing = VehiclePricing.ResolveZeroTo100(name or '', perfCategory, maxKmh)
    if fromPricing then
        return fromPricing
    end

    local modelMap = handlingCfg.ModelZeroTo100 or {}
    if name and modelMap[name] then
        return tonumber(modelMap[name])
    end

    if name and isHyperModel(name) then
        if isFullyTuned(veh) then
            return tonumber(handlingCfg.HyperTunedZeroTo100) or 2.55
        end
        return tonumber(handlingCfg.HyperZeroTo100) or 2.75
    end

    local catTable = handlingCfg.CategoryZeroTo100 or {}
    return tonumber(catTable[category]) or 9.0
end

local function resolveTargetMassKg(category, origMass)
    local targets = handlingCfg.CategoryMassKg or {}
    local target = tonumber(targets[category]) or 1520
    origMass = tonumber(origMass) or target

    local minKg = target * 0.78
    local maxKg = target * 1.22
    if category == 'commercial' or category == 'industrial' then
        minKg = target * 0.88
        maxKg = target * 1.08
    end

    if origMass >= minKg and origMass <= maxKg then
        return origMass
    end

    local blend = tonumber(handlingCfg.MassBlend) or 0.72
    if origMass > maxKg then
        return target + ((origMass - target) * (1.0 - blend))
    end
    return target - ((target - origMass) * (1.0 - blend))
end

local function resolveTargetDownforce(category, origDf)
    local caps = handlingCfg.CategoryDownforceMax or {}
    local cap = tonumber(caps[category]) or tonumber(handlingCfg.DefaultDownforceMax) or 0.35
    origDf = tonumber(origDf) or 0.0
    if origDf <= cap then return origDf end
    if origDf > cap * 4.0 then return cap end
    return cap + ((origDf - cap) * 0.12)
end

local function resolveTargetSuspensionForce(category, origForce)
    local caps = handlingCfg.CategorySuspensionForceMax or {}
    local cap = caps[category]
    if not cap then return origForce end
    origForce = tonumber(origForce) or cap
    if origForce <= cap then return origForce end
    return cap + ((origForce - cap) * 0.18)
end

local function resolveBrakeScale(category, name, maxKmh)
    if name and isHyperModel(name) then
        return tonumber(handlingCfg.HyperBrakeScale) or 1.18
    end
    local scale = (handlingCfg.CategoryBrakeScale or {})[category] or 1.0
    if maxKmh and maxKmh > 200 then
        scale = scale * (1.0 + (maxKmh - 200.0) * 0.0012)
    end
    return scale
end

local function resolveDriveInertia(category, name)
    if name and isHyperModel(name) then
        return tonumber(handlingCfg.HyperDriveInertia) or 0.86
    end
    return (handlingCfg.CategoryDriveInertia or {})[category] or 1.0
end

local function resolveSteeringLock(category, origLock)
    local target = (handlingCfg.CategorySteeringLock or {})[category]
    if not target then return origLock end
    return (origLock * 0.35) + (target * 0.65)
end

local function buildApplySignature(veh, name, maxKmh)
    local eng = GetVehicleMod(veh, 11)
    if eng < 0 then eng = 0 end
    local turbo = IsToggleModOn(veh, 18) and 1 or 0
    return ('%s|%.0f|%d|%d'):format(name or '?', maxKmh or 0, eng, turbo)
end

local function applyHandlingTune(veh)
    if not handlingCfg.Enabled or not veh or veh == 0 then return end

    local hash = GetEntityModel(veh)
    local row = modelIndex[hash]
    local name = row and row.name or nil
    local category = (row and row.category) or 'sedans'
    local maxKmh = resolveMaxKmh(veh)

    if not isRoadCategory(category) then return end

    if not maxKmh and not handlingCfg.ApplyToAllVehicles then return end
    if not maxKmh then
        maxKmh = estimatedModelKmh(hash)
    end
    if maxKmh <= 0 then return end

    local sig = buildApplySignature(veh, name, maxKmh)
    if appliedSigByVeh[veh] == sig then return end

    local orig = cacheOriginalHandling(veh, hash)
    local estKmh = math.max(estimatedModelKmh(hash), 1.0)
    local speedRatio = clamp(
        maxKmh / estKmh,
        handlingCfg.SpeedRatioMin or 0.82,
        handlingCfg.SpeedRatioMax or 1.12
    )

    local newMaxFlatVel = clamp(
        orig.fInitialDriveMaxFlatVel * speedRatio,
        handlingCfg.MaxFlatVelMin or 118.0,
        handlingCfg.MaxFlatVelMax or 205.0
    )

    local currentZeroTo100 = accelToZeroTo100(GetVehicleModelAcceleration(hash))
    local targetZeroTo100 = resolveZeroTo100Target(name, category, maxKmh, veh)
    local accelRatio = clamp(
        currentZeroTo100 / math.max(targetZeroTo100, 2.0),
        handlingCfg.AccelRatioMin or 0.78,
        handlingCfg.AccelRatioMax or 1.15
    )
    local newDriveForce = clamp(
        orig.fInitialDriveForce * accelRatio,
        handlingCfg.DriveForceMin or 0.10,
        handlingCfg.DriveForceMax or 0.36
    )

    local brakeScale = resolveBrakeScale(category, name, maxKmh)
    local newBrakeForce = clamp(
        orig.fBrakeForce * brakeScale,
        handlingCfg.BrakeForceMin or 0.62,
        handlingCfg.BrakeForceMax or 1.32
    )

    local inertiaMult = resolveDriveInertia(category, name)
    local newInertia = clamp(orig.fDriveInertia * inertiaMult, 0.82, 1.22)

    local dragBoost = 1.0
    if maxKmh > 200 then
        dragBoost = 1.0 + (maxKmh - 200.0) * (handlingCfg.DragCoeffPerKmhAbove200 or 0.0018)
    end
    local newDrag = orig.fInitialDragCoeff * dragBoost

    local newSteering = resolveSteeringLock(category, orig.fSteeringLock)

    local newMass = resolveTargetMassKg(category, orig.fMass)
    local newDownforce = resolveTargetDownforce(category, orig.fDownforceModifier)
    local newSuspension = resolveTargetSuspensionForce(category, orig.fSuspensionForce)

    local tractionMult = 1.0
    if category == 'super' or (name and isHyperModel(name)) then
        tractionMult = 0.99
    elseif category == 'muscle' then
        tractionMult = 0.995
    elseif category == 'offroad' or category == 'suvs' then
        tractionMult = 1.01
    end

    setHandlingFloat(veh, 'fMass', newMass)
    setHandlingFloat(veh, 'fDownforceModifier', newDownforce)
    if orig.fSuspensionForce and orig.fSuspensionForce > 0 then
        setHandlingFloat(veh, 'fSuspensionForce', newSuspension)
    end
    setHandlingFloat(veh, 'fInitialDriveMaxFlatVel', newMaxFlatVel)
    setHandlingFloat(veh, 'fInitialDriveForce', newDriveForce)
    setHandlingFloat(veh, 'fBrakeForce', newBrakeForce)
    setHandlingFloat(veh, 'fDriveInertia', newInertia)
    setHandlingFloat(veh, 'fInitialDragCoeff', newDrag)
    setHandlingFloat(veh, 'fSteeringLock', newSteering)
    setHandlingFloat(veh, 'fTractionCurveMax', orig.fTractionCurveMax * tractionMult)
    setHandlingFloat(veh, 'fTractionCurveMin', orig.fTractionCurveMin * tractionMult)

    if category == 'muscle' then
        setHandlingFloat(veh, 'fLowSpeedTractionLossMult', clamp(orig.fLowSpeedTractionLossMult * 1.03, 0.55, 1.25))
    end

    appliedSigByVeh[veh] = sig
end

local function applyMaxSpeed(veh)
    if not cfg.Enabled or not veh or veh == 0 then return end
    local kmh = resolveMaxKmh(veh)
    if not kmh then
        if activeVeh == veh then
            SetVehicleMaxSpeed(veh, 0.0)
            activeVeh = 0
            activeMaxMs = 0.0
        end
        return
    end

    local ms = kmhToMs(kmh)
    if activeVeh ~= veh or math.abs(activeMaxMs - ms) > 0.05 then
        SetVehicleMaxSpeed(veh, ms)
        activeVeh = veh
        activeMaxMs = ms
    end
end

local function applyVehiclePerf(veh)
    applyMaxSpeed(veh)
    if not handlingCfg.Enabled or not veh or veh == 0 then return end
    local hash = GetEntityModel(veh)
    local row = modelIndex[hash]
    if row and row.isReh then return end
    applyHandlingTune(veh)
end

local function clearVehicleState(veh)
    if veh and veh ~= 0 then
        appliedSigByVeh[veh] = nil
    end
    if activeVeh == veh then
        if veh and veh ~= 0 then
            SetVehicleMaxSpeed(veh, 0.0)
        end
        activeVeh = 0
        activeMaxMs = 0.0
    end
end

local function buildModelIndex()
    modelIndex = {}
    local rehSet = {}
    for name in pairs(cfg.RehMaxKmh or {}) do
        rehSet[name:lower()] = true
    end

    local vehicles = QBCore.Shared and QBCore.Shared.Vehicles or {}
    for name, row in pairs(vehicles) do
        local model = (row.model or name):lower()
        local hash = joaat(model)
        modelIndex[hash] = {
            name = model,
            category = row.category,
            price = tonumber(row.price) or 0,
            isReh = rehSet[model] == true or rehSet[name:lower()] == true,
        }
        modelIndex[model] = modelIndex[hash]
    end

    for name in pairs(cfg.RehMaxKmh or {}) do
        local model = name:lower()
        local hash = joaat(model)
        if not modelIndex[hash] then
            modelIndex[hash] = { name = model, category = 'sports', isReh = true }
            modelIndex[model] = modelIndex[hash]
        else
            modelIndex[hash].isReh = true
        end
    end
end

CreateThread(function()
    Wait(500)
    buildModelIndex()
end)

AddEventHandler('onResourceStart', function(res)
    if res ~= GetCurrentResourceName() then return end
    Wait(250)
    buildModelIndex()
    originalHandlingByHash = {}
    appliedSigByVeh = {}
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    Wait(500)
    buildModelIndex()
end)

CreateThread(function()
    while true do
        if cfg.Enabled then
            local ped = PlayerPedId()
            if IsPedInAnyVehicle(ped, false) then
                local veh = GetVehiclePedIsIn(ped, false)
                if GetPedInVehicleSeat(veh, -1) == ped then
                    applyVehiclePerf(veh)
                    Wait(300)
                else
                    clearVehicleState(veh)
                    Wait(600)
                end
            else
                if activeVeh ~= 0 then
                    clearVehicleState(activeVeh)
                end
                Wait(800)
            end
        else
            Wait(2000)
        end
    end
end)

exports('GetConfiguredMaxKmh', function(model)
    local hash = type(model) == 'number' and model or joaat(tostring(model or ''))
    local row = modelIndex[hash]
    if not row then return nil end
    if cfg.RehMaxKmh and cfg.RehMaxKmh[row.name] then
        return cfg.RehMaxKmh[row.name]
    end
    if row.isReh and row.category and cfg.RehCategoryKmh then
        return cfg.RehCategoryKmh[row.category]
    end
    if row.price and row.price > 0 and VanillaMaxKmh and VanillaMaxKmh[row.name] then
        return VanillaMaxKmh[row.name]
    end
    if row.price and row.price > 0 then
        return VehiclePricing.MaxKmhFromPrice(row.price, row.category or 'sedans')
    end
    return categoryCapKmh(row.category)
end)

exports('GetVehiclePerfProfile', function(model, category)
    model = tostring(model or ''):lower()
    category = tostring(category or 'sedans')
    local hash = joaat(model)
    local row = modelIndex[hash]
    if row and row.category and category == 'sedans' then
        category = row.category
    end

    local profile = VehiclePricing.ResolveProfile(model, category, row and row.price)
    local accel = GetVehicleModelAcceleration(hash)
    local brakeScale = (handlingCfg.CategoryBrakeScale or {})[category] or 1.0
    if VehiclePricing.IsHyperModel(model) then
        brakeScale = tonumber(handlingCfg.HyperBrakeScale) or 1.18
    end
    local braking = GetVehicleModelMaxBraking(hash) * brakeScale
    local traction = GetVehicleModelMaxTraction(hash)

    return {
        maxKmh = profile.maxKmh,
        zeroTo100 = profile.zeroTo100,
        tier = profile.tier,
        tierLabel = VehiclePricing.GetTierLabel(profile.tier),
        braking = clamp(braking, 0.0, 1.0),
        traction = clamp(traction, 0.0, 1.0),
        accel = accel,
    }
end)

exports('IsRehModel', function(model)
    model = tostring(model or ''):lower()
    return (cfg.RehMaxKmh or {})[model] ~= nil
end)
