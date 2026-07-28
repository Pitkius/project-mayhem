FPMHousing = FPMHousing or {}

local function vec3From(v)
    if type(v) == 'vector4' then return vector3(v.x, v.y, v.z) end
    if type(v) == 'vector3' then return v end
    return vector3(v.x or 0, v.y or 0, v.z or 0)
end

function FPMHousing.GetProperty(id)
    for i = 1, #(Config.Properties or {}) do
        local p = Config.Properties[i]
        if p.id == id then return p, i end
    end
    return nil, nil
end

function FPMHousing.GetInterior(key)
    return Config.Interiors[key]
end

function FPMHousing.GetInteriorStash(interiorKey)
    local intr = Config.Interiors[interiorKey]
    local cap = intr and intr.stashCapacity
    if cap then
        return {
            maxweight = cap.maxweight or Config.Stash.maxweight,
            slots = cap.slots or Config.Stash.slots,
        }
    end
    return {
        maxweight = Config.Stash.maxweight,
        slots = Config.Stash.slots,
    }
end

function FPMHousing.InteriorCatalogEntry(interiorKey, property)
    local intr = Config.Interiors[interiorKey]
    if not intr then return nil end
    local stash = FPMHousing.GetInteriorStash(interiorKey)
    return {
        key = interiorKey,
        label = intr.label,
        qualityLabel = intr.qualityLabel or '—',
        tier = intr.tier or 1,
        description = intr.description,
        price = FPMHousing.CalculatePrice(property, interiorKey),
        hasWardrobe = intr.hasWardrobe ~= false,
        stashSlots = stash.slots,
        stashWeight = stash.maxweight,
    }
end

--- Kaina: nuo Config.BasePrice (200k) + rajonas + interjeras + arčiau centro = brangiau
function FPMHousing.CalculatePrice(property, interiorKey)
    if not property or not interiorKey then return Config.BasePrice end
    local interior = Config.Interiors[interiorKey]
    local district = Config.Districts[property.district]
    if not interior or not district then return Config.BasePrice end

    local door = vec3From(property.door)
    local dist = #(door - Config.CityCenter)
    local norm = math.min(1.0, dist / Config.MaxDistFromCenter)
    local centerFactor = 1.0 + (1.0 - norm) * (Config.CenterPriceMultiplier - 1.0)

    local price = Config.BasePrice * (district.mult or 1.0) * (interior.priceMult or 1.0) * centerFactor
    local step = Config.PriceRoundStep or 1000
    return math.floor(price / step) * step
end

function FPMHousing.RoutingBucket(propertyIndex)
    return (Config.RoutingBucketBase or 5000) + propertyIndex
end
