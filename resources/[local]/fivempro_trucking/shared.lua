TruckingShared = TruckingShared or {}

function TruckingShared.Clamp(n, lo, hi)
    n = tonumber(n) or lo
    if n < lo then return lo end
    if n > hi then return hi end
    return n
end

function TruckingShared.LevelFromXp(xp)
    xp = tonumber(xp) or 0
    local lvl = 1
    local thresholds = Config.LevelXp or {}
    for level = 1, #thresholds do
        if xp >= (thresholds[level] or 0) then
            lvl = level
        end
    end
    return lvl
end

function TruckingShared.XpForNextLevel(level)
    level = tonumber(level) or 1
    local next = (Config.LevelXp or {})[level + 1]
    if not next then return nil end
    return next
end

function TruckingShared.ReputationStars(rep)
    rep = tonumber(rep) or 0
    local tiers = Config.ReputationStars or {}
    local stars = 1
    for i = #tiers, 1, -1 do
        if rep >= (tiers[i] or 0) then
            stars = i
            break
        end
    end
    return stars
end

function TruckingShared.Hub(id)
    return (Config.Hubs or {})[id]
end

function TruckingShared.Cargo(id)
    return (Config.CargoTypes or {})[id]
end

function TruckingShared.Vehicle(model)
    return (Config.Vehicles or {})[model]
end

function TruckingShared.PlayerCanAccessCargo(profile, cargoId)
    local cargo = TruckingShared.Cargo(cargoId)
    if not cargo then return false end
    local level = profile.level or 1
    local stars = TruckingShared.ReputationStars(profile.reputation or 0)
    if level < (cargo.minLevel or 1) then return false end
    if stars < (cargo.minReputation or 1) then return false end
    if cargo.illegal and level < (Config.IllegalMinLevel or 12) then return false end
    return true
end

function TruckingShared.HasLicense(profile, license)
    if not profile or not profile.licenses then return false end
    return profile.licenses[license] == true
end

function TruckingShared.StraightDistanceKm(a, b)
    if not a or not b then return 0 end
    return #(vector3(a.x, a.y, a.z) - vector3(b.x, b.y, b.z)) / 1000.0
end

--- Tiesi linija × koeficientas (serveris). Tikslų kelio atstumą skaičiuoja klientas.
function TruckingShared.DistanceKm(a, b)
    local straight = TruckingShared.StraightDistanceKm(a, b)
    return math.floor(straight * (Config.RoadDistanceFactor or 1.28) * 10) / 10
end

function TruckingShared.ValidateRoadDistanceKm(straightKm, roadKm)
    straightKm = tonumber(straightKm) or 0
    roadKm = tonumber(roadKm) or 0
    if roadKm <= 0 or straightKm <= 0 then return false end
    if roadKm < straightKm * 0.92 then return false end
    if roadKm > straightKm * 3.8 then return false end
    return true
end

function TruckingShared.ApplyDistanceMetrics(contract, distanceKm)
    distanceKm = math.floor((tonumber(distanceKm) or 0) * 10) / 10
    if distanceKm <= 0 then return contract end
    contract.distanceKm = distanceKm
    contract.timeLimitMin = math.max(12, math.floor(distanceKm * 1.35 + 8))
    contract.pay = nil
    return contract
end

function TruckingShared.TimePayMultiplier(secondsLeft, totalSeconds)
    if totalSeconds <= 0 then return 1.0 end
    local ratio = secondsLeft / totalSeconds
    if ratio >= 0 then return 1.0 end
    local late = math.abs(ratio)
    if late <= 0.35 then return 0.7 end
    return 0.5
end

function TruckingShared.ConditionPayMultiplier(conditionPct)
    conditionPct = TruckingShared.Clamp(conditionPct, 0, 100)
    if conditionPct >= 95 then return 1.0 end
    if conditionPct >= 80 then return 0.9
    elseif conditionPct >= 65 then return 0.75
    elseif conditionPct >= 50 then return 0.6
    else return 0.45 end
end
