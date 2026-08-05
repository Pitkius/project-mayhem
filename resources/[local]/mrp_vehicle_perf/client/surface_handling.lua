--[[
  Surface handling layer — client only, polled while driving.
  Applies on top of mrp_vehicle_perf baseline; restores on exit / surface change.
]]

SurfaceHandling = SurfaceHandling or {}

local cfg = Config.SurfaceHandling or {}
local baselineByVeh = {}
local lastSigByVeh = {}
local lastSurfaceByVeh = {}

local GTA_CLASS_TO_CATEGORY = {
    [0] = 'compacts',
    [1] = 'sedans',
    [2] = 'suvs',
    [3] = 'coupes',
    [4] = 'muscle',
    [5] = 'sportsclassics',
    [6] = 'sports',
    [7] = 'super',
    [8] = 'motorcycles',
    [9] = 'offroad',
    [10] = 'industrial',
    [11] = 'utility',
    [12] = 'vans',
    [17] = 'service',
    [18] = 'emergency',
    [19] = 'military',
    [20] = 'commercial',
    [22] = 'openwheel',
}

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

local function detectSurface(veh)
    local counts = {}
    local best, bestN = cfg.DefaultSurface or 'asphalt', 0
    for wheel = 0, 3 do
        local mat = GetVehicleWheelSurfaceMaterial(veh, wheel)
        if mat and mat >= 0 then
            local surf = (cfg.MaterialToSurface and cfg.MaterialToSurface[mat]) or (cfg.DefaultSurface or 'asphalt')
            counts[surf] = (counts[surf] or 0) + 1
            if counts[surf] > bestN then
                bestN = counts[surf]
                best = surf
            end
        end
    end
    return best
end

local function resolveModelName(veh)
    local hash = GetEntityModel(veh)
    if SurfaceHandling._resolveModel then
        local n = SurfaceHandling._resolveModel(veh)
        if n and n ~= '' then return n:lower(), hash end
    end
    if GetEntityArchetypeName then
        local arch = GetEntityArchetypeName(veh)
        if arch and arch ~= '' then return arch:lower(), hash end
    end
    local name = GetDisplayNameFromVehicleModel(hash)
    if name then name = name:lower() end
    return name, hash
end

local function resolveSurfaceClass(veh)
    local name = select(1, resolveModelName(veh))
    local modelMap = cfg.ModelClass or {}
    if name and modelMap[name] then
        return modelMap[name], name
    end

    -- HyperCars from VehiclePerf config
    local hyper = Config.VehiclePerf and Config.VehiclePerf.HyperCars
    if name and hyper and hyper[name] then
        return 'Hyper', name
    end

    -- QB Shared vehicles category via export hook
    local category = nil
    if SurfaceHandling._resolveCategory then
        category = SurfaceHandling._resolveCategory(veh)
    end
    if not category then
        local gtaClass = GetVehicleClass(veh)
        category = GTA_CLASS_TO_CATEGORY[gtaClass] or 'sedans'
    end

    local mapped = (cfg.CategoryMap and cfg.CategoryMap[category]) or 'Sedan'
    return mapped, name
end

local function isLowSuspension(veh)
    local mod = GetVehicleMod(veh, 15)
    if mod < 0 then return false end
    local num = GetNumVehicleMods(veh, 15)
    if num <= 0 then return false end
    -- top 2 lowered levels
    return mod >= math.max(0, num - 2)
end

local function hasOffroadTires(veh)
    return GetVehicleWheelType(veh) == 4
end

local function classTable(className)
    if className == 'MotorcycleDirt' then return cfg.MotorcycleDirt end
    if className == 'MotorcycleStreet' then return cfg.MotorcycleStreet end
    return (cfg.Classes and cfg.Classes[className]) or (cfg.Classes and cfg.Classes.Sedan) or {}
end

local function snapshotBaseline(veh)
    local fields = cfg.Fields or {}
    local snap = {}
    for _, field in pairs(fields) do
        snap[field] = getHandlingFloat(veh, field)
    end
    return snap
end

local function restoreBaseline(veh)
    local snap = baselineByVeh[veh]
    if not snap then return end
    for field, value in pairs(snap) do
        if value then setHandlingFloat(veh, field, value) end
    end
end

function SurfaceHandling.Invalidate(veh)
    if not veh or veh == 0 then return end
    baselineByVeh[veh] = nil
    lastSigByVeh[veh] = nil
end

function SurfaceHandling.Clear(veh)
    if not veh or veh == 0 then return end
    restoreBaseline(veh)
    baselineByVeh[veh] = nil
    lastSigByVeh[veh] = nil
    lastSurfaceByVeh[veh] = nil
end

function SurfaceHandling.Apply(veh)
    if not cfg.Enabled or not veh or veh == 0 then return end
    if not IsPedInVehicle(PlayerPedId(), veh, false) then return end
    if GetPedInVehicleSeat(veh, -1) ~= PlayerPedId() then return end

    local gtaClass = GetVehicleClass(veh)
    if gtaClass == 13 or gtaClass == 14 or gtaClass == 15 or gtaClass == 16 or gtaClass == 21 then
        return -- cycles/boats/heli/planes/trains
    end

    if not baselineByVeh[veh] then
        baselineByVeh[veh] = snapshotBaseline(veh)
    end

    local surface = detectSurface(veh)
    local className, modelName = resolveSurfaceClass(veh)
    local lowSus = isLowSuspension(veh)
    local offTires = hasOffroadTires(veh)
    local sig = ('%s|%s|%s|%s|%s'):format(surface, className, tostring(lowSus), tostring(offTires), tostring(modelName))
    if lastSigByVeh[veh] == sig then return end

    restoreBaseline(veh)
    local base = baselineByVeh[veh]
    if not base then return end

    local feel = (cfg.SurfaceFeel and cfg.SurfaceFeel[surface]) or (cfg.SurfaceFeel and cfg.SurfaceFeel.asphalt) or {}
    local classMult = classTable(className)[surface] or 1.0

    if modelName and cfg.SpecialModels and cfg.SpecialModels[modelName] and surface ~= 'asphalt' and surface ~= 'concrete' then
        classMult = classMult + (tonumber(cfg.SpecialBonus) or 0.08)
    end

    -- Offroad tires: reduce penalty (1 - mult)
    if offTires and surface ~= 'asphalt' and surface ~= 'concrete' then
        local reduce = (cfg.OffroadTires and cfg.OffroadTires[surface]) or 0.0
        local penalty = 1.0 - classMult
        classMult = 1.0 - (penalty * (1.0 - reduce))
    end

    -- Low suspension: deepen penalty
    if lowSus and surface ~= 'asphalt' then
        local extra = (cfg.Suspension and cfg.Suspension.LowExtraDebuff and cfg.Suspension.LowExtraDebuff[className]) or 0.1
        local penalty = 1.0 - classMult
        classMult = 1.0 - (penalty * (1.0 + extra))
    end

    classMult = clamp(classMult, 0.25, 1.15)

    local traction = (feel.traction or 1.0) * classMult
    local accel = (feel.accel or 1.0) * (0.55 + classMult * 0.45)
    local brake = (feel.brake or 1.0) * (0.60 + classMult * 0.40)
    local steer = (feel.steer or 1.0) * (0.70 + classMult * 0.30)
    local drag = (feel.drag or 1.0) * (2.0 - classMult)
    local lowLoss = (feel.lowSpeedLoss or 1.0) * (2.0 - classMult)

    local F = cfg.Fields or {}
    if F.tractionMax and base[F.tractionMax] then
        setHandlingFloat(veh, F.tractionMax, base[F.tractionMax] * traction)
    end
    if F.tractionMin and base[F.tractionMin] then
        setHandlingFloat(veh, F.tractionMin, base[F.tractionMin] * traction)
    end
    if F.lowSpeedLoss and base[F.lowSpeedLoss] then
        setHandlingFloat(veh, F.lowSpeedLoss, clamp(base[F.lowSpeedLoss] * lowLoss, 0.2, 2.5))
    end
    if F.driveForce and base[F.driveForce] then
        setHandlingFloat(veh, F.driveForce, base[F.driveForce] * accel)
    end
    if F.inertia and base[F.inertia] then
        setHandlingFloat(veh, F.inertia, clamp(base[F.inertia] * (2.0 - accel), 0.5, 2.0))
    end
    if F.brake and base[F.brake] then
        setHandlingFloat(veh, F.brake, base[F.brake] * brake)
    end
    if F.steer and base[F.steer] then
        setHandlingFloat(veh, F.steer, base[F.steer] * steer)
    end
    if F.drag and base[F.drag] then
        setHandlingFloat(veh, F.drag, base[F.drag] * drag)
    end

    lastSigByVeh[veh] = sig
    lastSurfaceByVeh[veh] = surface
end

CreateThread(function()
    while true do
        if not cfg.Enabled then
            Wait(2000)
        else
            local ped = PlayerPedId()
            if IsPedInAnyVehicle(ped, false) then
                local veh = GetVehiclePedIsIn(ped, false)
                if veh ~= 0 and GetPedInVehicleSeat(veh, -1) == ped then
                    SurfaceHandling.Apply(veh)
                    Wait(tonumber(cfg.TickMs) or 750)
                else
                    Wait(tonumber(cfg.IdleTickMs) or 1200)
                end
            else
                -- clear any leftover baseline for last vehicle is handled on exit hook
                Wait(tonumber(cfg.IdleTickMs) or 1200)
            end
        end
    end
end)

AddEventHandler('gameEventTriggered', function(name, args)
    if name ~= 'CEventNetworkPlayerEnteredVehicle' and name ~= 'CEventNetworkPlayerLeftVehicle' then return end
end)

-- Exit detection
CreateThread(function()
    local lastVeh = 0
    while true do
        Wait(500)
        local ped = PlayerPedId()
        local veh = GetVehiclePedIsIn(ped, false)
        if lastVeh ~= 0 and (veh == 0 or veh ~= lastVeh) then
            SurfaceHandling.Clear(lastVeh)
        end
        lastVeh = veh
    end
end)
