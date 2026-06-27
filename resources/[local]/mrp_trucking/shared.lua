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

local TIER_LIST = { 'van', 'medium', 'truck', 'heavy' }
local TIER_RANK = { van = 1, medium = 2, truck = 3, heavy = 4 }

function TruckingShared.TierRank(tier)
    return TIER_RANK[tier] or 1
end

function TruckingShared.TierFromBoxes(boxes)
    boxes = tonumber(boxes) or 1
    if boxes <= 3 then return 'van' end
    if boxes <= 5 then return 'medium' end
    if boxes <= 7 then return 'truck' end
    return 'heavy'
end

function TruckingShared.CargoBoxCount(cargoId)
    local cargo = TruckingShared.Cargo(cargoId) or {}
    local boxCfg = cargo.boxes or (Config.LogisticsCenter and Config.LogisticsCenter.boxCount) or { min = 3, max = 8 }
    local lo = tonumber(boxCfg.min) or 3
    local hi = tonumber(boxCfg.max) or lo
    if hi < lo then hi = lo end
    return math.random(lo, hi)
end

function TruckingShared.MinTierForCargo(cargoId)
    local cargo = TruckingShared.Cargo(cargoId) or {}
    if cargo.minVehicleTier then return cargo.minVehicleTier end
    if cargo.category == 'special' then return 'truck' end
    if cargo.category == 'hazard' then return 'truck' end
    return 'van'
end

function TruckingShared.TrailerForCargo(cargoId, tier)
    if tier ~= 'heavy' then return nil end
    local trailers = (Config.MissionTrucks or {}).trailers or {}
    if cargoId == 'fuel' or cargoId == 'chemicals' then
        return trailers.tanker or 'tanker'
    end
    if cargoId == 'machinery' or cargoId == 'luxury_cars' or cargoId == 'construction' then
        return trailers.bulk or 'trailers2'
    end
    return trailers.default or 'trailers'
end

function TruckingShared.PlayerCanUseVehicle(profile, model)
    local veh = TruckingShared.Vehicle(model)
    if not veh then return false end
    if (profile.level or 1) < (veh.minLevel or 1) then return false end
    if veh.license and not TruckingShared.HasLicense(profile, veh.license) then
        if veh.class == 'heavy' and (profile.level or 1) >= (Config.Unlocks.heavy_truck_license or 5) then
            return true
        end
        return false
    end
    return true
end

function TruckingShared.ResolveMissionTruck(profile, cargoId, boxesRequired)
    local wantRank = math.max(
        TruckingShared.TierRank(TruckingShared.TierFromBoxes(boxesRequired)),
        TruckingShared.TierRank(TruckingShared.MinTierForCargo(cargoId))
    )
    local tiers = (Config.MissionTrucks or {}).tiers or {}
    local chosenTier, chosenModel
    for rank = wantRank, 1, -1 do
        local tierName = TIER_LIST[rank]
        local tierCfg = tiers[tierName]
        if tierCfg and tierCfg.models then
            for _, model in ipairs(tierCfg.models) do
                if TruckingShared.PlayerCanUseVehicle(profile, model) then
                    chosenTier = tierName
                    chosenModel = model
                    break
                end
            end
        end
        if chosenModel then break end
    end
    if not chosenModel then
        chosenModel = 'mule'
        chosenTier = 'van'
    end
    local veh = TruckingShared.Vehicle(chosenModel) or {}
    local trailer = TruckingShared.TrailerForCargo(cargoId, chosenTier)
    return {
        model = chosenModel,
        label = veh.label or chosenModel,
        class = veh.class or chosenTier,
        tier = chosenTier,
        trailer = trailer,
    }
end

function TruckingShared.EnrichContractMission(profile, contract)
    if not contract or not contract.cargoId then return contract end
    if not contract.boxesRequired then
        contract.boxesRequired = TruckingShared.CargoBoxCount(contract.cargoId)
    end
    local truck = TruckingShared.ResolveMissionTruck(profile, contract.cargoId, contract.boxesRequired)
    contract.truckModel = truck.model
    contract.truckLabel = truck.label
    contract.truckClass = truck.class
    contract.truckTier = truck.tier
    contract.trailerModel = truck.trailer
    return contract
end
