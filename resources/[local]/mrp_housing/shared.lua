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

function FPMHousing.GetPropertyClass(property)
    if type(property) == 'string' then
        property = FPMHousing.GetProperty(property)
    end
    return property and (property.class or 'standard') or 'standard'
end

function FPMHousing.InteriorAllowedForClass(interiorKey, propertyClass)
    local intr = Config.Interiors[interiorKey]
    if not intr then return false end
    local classes = intr.classes
    if not classes or #classes == 0 then return false end
    for i = 1, #classes do
        if classes[i] == propertyClass then return true end
    end
    return false
end

--- Interjerai, leidžiami šiam objektui pagal klasę
function FPMHousing.GetAllowedInteriorKeys(property)
    local list = {}
    local pClass = FPMHousing.GetPropertyClass(property)
    for key, intr in pairs(Config.Interiors or {}) do
        if FPMHousing.InteriorAllowedForClass(key, pClass) then
            list[#list + 1] = key
        end
    end
    table.sort(list, function(a, b)
        local ta = (Config.Interiors[a] and Config.Interiors[a].tier) or 0
        local tb = (Config.Interiors[b] and Config.Interiors[b].tier) or 0
        if ta ~= tb then return ta < tb end
        return a < b
    end)
    return list
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

--- Kaina: Base * district * class * interior * center * furnished
function FPMHousing.CalculatePrice(property, interiorKey, furnished)
    if not property or not interiorKey then return Config.BasePrice end
    local interior = Config.Interiors[interiorKey]
    local district = Config.Districts[property.district]
    if not interior or not district then return Config.BasePrice end

    local door = vec3From(property.door)
    local dist = #(door - Config.CityCenter)
    local norm = math.min(1.0, dist / Config.MaxDistFromCenter)
    local centerFactor = 1.0 + (1.0 - norm) * (Config.CenterPriceMultiplier - 1.0)

    local pClass = FPMHousing.GetPropertyClass(property)
    local classMult = (Config.ClassMult and Config.ClassMult[pClass]) or 1.0
    local furnMult = furnished and (Config.FurnishedMult or 1.32) or (Config.UnfurnishedMult or 1.0)

    local price = Config.BasePrice
        * (district.mult or 1.0)
        * classMult
        * (interior.priceMult or 1.0)
        * centerFactor
        * furnMult
    local step = Config.PriceRoundStep or 1000
    return math.floor(price / step) * step
end

function FPMHousing.InteriorCatalogEntry(interiorKey, property, furnished)
    local intr = Config.Interiors[interiorKey]
    if not intr then return nil end
    if not FPMHousing.InteriorAllowedForClass(interiorKey, FPMHousing.GetPropertyClass(property)) then
        return nil
    end
    local stash = FPMHousing.GetInteriorStash(interiorKey)
    local furn = furnished == true
    return {
        key = interiorKey,
        label = intr.label,
        qualityLabel = intr.qualityLabel or '—',
        tier = intr.tier or 1,
        description = intr.description,
        price = FPMHousing.CalculatePrice(property, interiorKey, furn),
        priceFurnished = FPMHousing.CalculatePrice(property, interiorKey, true),
        priceUnfurnished = FPMHousing.CalculatePrice(property, interiorKey, false),
        hasWardrobe = intr.hasWardrobe ~= false,
        stashSlots = stash.slots,
        stashWeight = stash.maxweight,
    }
end

function FPMHousing.RoutingBucket(propertyIndex)
    return (Config.RoutingBucketBase or 5000) + propertyIndex
end

function FPMHousing.GetInteriorEnter(interiorKey)
    local intr = Config.Interiors[interiorKey]
    if not intr or not intr.enter then return nil end
    return intr.enter
end
