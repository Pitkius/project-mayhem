local cfg = Config.ImpactShake or {}

local lastBodyHealth = 1000.0
local lastEngineHealth = 1000.0
local lastVeh = 0
local lastShakeAt = 0

local airborne = false
local airStartedAt = 0
local airPeakZ = 0.0
local airPeakDownSpeed = 0.0

local SKIP_CLASS = {
    [14] = true, -- boats
    [15] = true, -- helicopters
    [16] = true, -- planes
    [21] = true, -- trains
}

local function clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

local function nowMs()
    return GetGameTimer()
end

local function applyShake(intensity, cooldownMs)
    cooldownMs = tonumber(cooldownMs) or 1100
    if (nowMs() - lastShakeAt) < cooldownMs then return end
    intensity = tonumber(intensity) or 0.1
    local scale = tonumber(cfg.IntensityScale) or 1.0
    intensity = clamp(intensity * scale, 0.02, 0.35)
    local shakeName = cfg.ShakeName or 'SMALL_EXPLOSION_SHAKE'
    ShakeGameplayCam(shakeName, intensity)
    lastShakeAt = nowMs()
end

local function crashIntensity(bodyDrop, engineDrop, speedKmh)
    local c = cfg.Crash or {}
    local base = tonumber(c.Intensity) or 0.11
    local maxI = tonumber(c.MaxIntensity) or 0.18
    local bodyPart = clamp((bodyDrop or 0.0) / 80.0, 0.0, 1.0)
    local engPart = clamp((engineDrop or 0.0) / 120.0, 0.0, 1.0)
    local spdPart = clamp(((speedKmh or 0.0) - 28.0) / 120.0, 0.0, 1.0)
    local t = math.max(bodyPart, engPart) * 0.7 + spdPart * 0.3
    return base + (maxI - base) * t
end

local function jumpIntensity(fallHeight, fallSpeed)
    local j = cfg.Jump or {}
    local base = tonumber(j.Intensity) or 0.09
    local maxI = tonumber(j.MaxIntensity) or 0.15
    local hPart = clamp(((fallHeight or 0.0) - 3.0) / 10.0, 0.0, 1.0)
    local sPart = clamp(((fallSpeed or 0.0) - 7.0) / 18.0, 0.0, 1.0)
    local t = math.max(hPart, sPart)
    return base + (maxI - base) * t
end

local function isSkippableVehicle(veh)
    local class = GetVehicleClass(veh)
    return SKIP_CLASS[class] == true
end

local function isReallyAirborne(veh)
    local j = cfg.Jump or {}
    local minHag = tonumber(j.MinHeightAboveGround) or 1.35
    if IsEntityInAir(veh) then return true end
    if not IsVehicleOnAllWheels(veh) then
        local hag = GetEntityHeightAboveGround(veh)
        if hag and hag >= minHag then
            return true
        end
    end
    return false
end

local function resetAirState()
    airborne = false
    airStartedAt = 0
    airPeakZ = 0.0
    airPeakDownSpeed = 0.0
end

local function resetVehicleState(veh)
    lastVeh = veh or 0
    if veh and veh ~= 0 and DoesEntityExist(veh) then
        lastBodyHealth = GetVehicleBodyHealth(veh) or 1000.0
        lastEngineHealth = GetVehicleEngineHealth(veh) or 1000.0
    else
        lastBodyHealth = 1000.0
        lastEngineHealth = 1000.0
    end
    resetAirState()
end

CreateThread(function()
    while true do
        if cfg.Enabled == false then
            Wait(1000)
        else
            local ped = PlayerPedId()
            if IsPedInAnyVehicle(ped, false) then
                local veh = GetVehiclePedIsIn(ped, false)
                if veh and veh ~= 0 and DoesEntityExist(veh) and not isSkippableVehicle(veh) then
                    if veh ~= lastVeh then
                        resetVehicleState(veh)
                    end

                    local bodyNow = GetVehicleBodyHealth(veh) or 1000.0
                    local engNow = GetVehicleEngineHealth(veh) or 1000.0
                    local speedKmh = GetEntitySpeed(veh) * 3.6
                    local coords = GetEntityCoords(veh)
                    local vel = GetEntityVelocity(veh)
                    local downSpeed = math.max(0.0, -(vel and vel.z or 0.0))

                    local c = cfg.Crash or {}
                    local minBody = tonumber(c.MinBodyDamage) or 22.0
                    local minEng = tonumber(c.MinEngineDamage) or 38.0
                    local minSpd = tonumber(c.MinSpeedKmh) or 28.0

                    local bodyDrop = lastBodyHealth - bodyNow
                    local engDrop = lastEngineHealth - engNow
                    local hardHit = (bodyDrop >= minBody) or (engDrop >= minEng)

                    if hardHit and speedKmh >= minSpd then
                        -- Maži parking bakstelėjimai filtruojami greičiu + žalos slenksčiu.
                        applyShake(crashIntensity(bodyDrop, engDrop, speedKmh), c.CooldownMs)
                    end

                    lastBodyHealth = bodyNow
                    lastEngineHealth = engNow

                    local j = cfg.Jump or {}
                    local minAirMs = tonumber(j.MinAirTimeMs) or 420
                    local minHeight = tonumber(j.MinHeight) or 3.2
                    local minFall = tonumber(j.MinFallSpeed) or 7.5

                    if isReallyAirborne(veh) then
                        if not airborne then
                            airborne = true
                            airStartedAt = nowMs()
                            airPeakZ = coords.z
                            airPeakDownSpeed = downSpeed
                        else
                            if coords.z > airPeakZ then
                                airPeakZ = coords.z
                            end
                            if downSpeed > airPeakDownSpeed then
                                airPeakDownSpeed = downSpeed
                            end
                        end
                    elseif airborne then
                        local airMs = nowMs() - airStartedAt
                        local fallHeight = airPeakZ - coords.z
                        local bigJump = airMs >= minAirMs
                            and (fallHeight >= minHeight or airPeakDownSpeed >= minFall)
                        if bigJump then
                            applyShake(jumpIntensity(fallHeight, airPeakDownSpeed), j.CooldownMs)
                        end
                        resetAirState()
                    end

                    Wait(tonumber(cfg.TickMs) or 50)
                else
                    resetVehicleState(0)
                    Wait(tonumber(cfg.IdleTickMs) or 400)
                end
            else
                if lastVeh ~= 0 then
                    resetVehicleState(0)
                end
                Wait(tonumber(cfg.IdleTickMs) or 400)
            end
        end
    end
end)
