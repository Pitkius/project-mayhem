VehiclePricing = VehiclePricing or {}

local function cfg()
    return Config.VehiclePerf or {}
end

local function handlingCfg()
    return (cfg().Handling) or {}
end

local function pricingCfg()
    return cfg().Pricing or {}
end

local function clamp(v, lo, hi)
    v = tonumber(v) or lo
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

local function roundTo(n, step)
    step = tonumber(step) or 500
    if step <= 0 then return math.floor(n + 0.5) end
    return math.floor((n / step) + 0.5) * step
end

function VehiclePricing.IsHyperModel(model)
    model = tostring(model or ''):lower()
    local hyper = cfg().HyperCars or {}
    return hyper[model] == true
end

function VehiclePricing.ResolveEffectiveCategory(category, maxKmh)
    category = tostring(category or 'sedans')
    maxKmh = tonumber(maxKmh) or 215

    if category == 'super' and maxKmh < 285 then
        if maxKmh >= 255 then return 'sports' end
        if maxKmh >= 235 then return 'muscle' end
        return 'sedans'
    end
    if category == 'sports' and maxKmh < 238 then
        if maxKmh >= 220 then return 'muscle' end
        return 'sedans'
    end
    if category == 'muscle' and maxKmh < 210 then
        return 'sedans'
    end
  if category == 'suvs' and maxKmh >= 265 then
        return 'sports'
    end
    return category
end

function VehiclePricing.ResolveTierFromPrice(price)
    price = tonumber(price) or 8000
    local tier = 'D'
    for _, t in ipairs({ 'D', 'C', 'B', 'A', 'S', 'X' }) do
        local band = (pricingCfg().TierBands or {})[t]
        if band and price >= (tonumber(band.min) or 0) then
            tier = t
        end
    end
    return tier
end

local TIER_BASE_KMH = {
    D = 174,
    C = 204,
    B = 242,
    A = 270,
    S = 294,
    X = 304,
}

--- Atvirkštinė kainos formulė — vanilla QB auto max greitis pagal parduotuvės kainą.
function VehiclePricing.MaxKmhFromPrice(price, category)
    price = tonumber(price) or 10000
    category = tostring(category or 'sedans')

    local tier = VehiclePricing.ResolveTierFromPrice(price)
    local kmh = TIER_BASE_KMH[tier] or 204

    local band = (pricingCfg().TierBands or {})[tier]
    if band then
        local minP = tonumber(band.min) or 8000
        local maxP = tonumber(band.max) or (minP + 1)
        if maxP > minP then
            local pos = clamp((price - minP) / (maxP - minP), 0.0, 1.0)
            kmh = kmh + ((pos - 0.5) * 16.0)
        end
    end

    local vanilla = (pricingCfg().VanillaCategoryPerf or {})[category]
    if vanilla and vanilla.maxKmh then
        kmh = (kmh * 0.58) + (tonumber(vanilla.maxKmh) * 0.42)
    end

    local caps = cfg().VanillaCategoryCap or {}
    local cap = caps[category] or cfg().GlobalCapKmh or 310
    return clamp(kmh, 148.0, cap)
end

function VehiclePricing.ResolveMaxKmh(model, category, price)
    model = tostring(model or ''):lower()
    category = tostring(category or 'sedans')

    local reh = cfg().RehMaxKmh or {}
    if reh[model] then
        return tonumber(reh[model])
    end

    if VanillaMaxKmh and VanillaMaxKmh[model] then
        return tonumber(VanillaMaxKmh[model])
    end

    if price and tonumber(price) and tonumber(price) > 0 then
        return VehiclePricing.MaxKmhFromPrice(price, category)
    end

    local rehCat = cfg().RehCategoryKmh or {}
    if rehCat[category] then
        return tonumber(rehCat[category])
    end

    local vanilla = (pricingCfg().VanillaCategoryPerf or {})[category]
    if vanilla and vanilla.maxKmh then
        return tonumber(vanilla.maxKmh)
    end

    return 215
end

function VehiclePricing.ResolveZeroTo100(model, category, maxKmh)
    model = tostring(model or ''):lower()
    category = tostring(category or 'sedans')
    maxKmh = tonumber(maxKmh) or 215

    local handling = handlingCfg()
    local modelMap = handling.ModelZeroTo100 or {}
    if modelMap[model] then
        return tonumber(modelMap[model])
    end

    if VehiclePricing.IsHyperModel(model) then
        return tonumber(handling.HyperZeroTo100) or 2.75
    end

    local catTable = handling.CategoryZeroTo100 or {}
    local base = tonumber(catTable[category]) or 9.0

    if maxKmh > 80 then
        local speedNorm = clamp(maxKmh / 240.0, 0.55, 1.35)
        base = base / speedNorm
    end

    return clamp(base, 2.4, 18.0)
end

function VehiclePricing.ResolveTier(maxKmh, zeroTo100, isHyper)
    maxKmh = tonumber(maxKmh) or 0
    zeroTo100 = tonumber(zeroTo100) or 99

    if isHyper then return 'X' end
    if maxKmh >= 298 or zeroTo100 <= 3.2 then return 'S' end
    if maxKmh >= 268 or zeroTo100 <= 4.6 then return 'A' end
    if maxKmh >= 238 or zeroTo100 <= 6.8 then return 'B' end
    if maxKmh >= 195 or zeroTo100 <= 9.8 then return 'C' end
    return 'D'
end

function VehiclePricing.ResolveProfile(model, category, price)
    model = tostring(model or ''):lower()
    category = tostring(category or 'sedans')

    local maxKmh = VehiclePricing.ResolveMaxKmh(model, category, price)
    local perfCategory = VehiclePricing.ResolveEffectiveCategory(category, maxKmh)
    local zeroTo100 = VehiclePricing.ResolveZeroTo100(model, perfCategory, maxKmh)
    local isHyper = VehiclePricing.IsHyperModel(model)

    return {
        model = model,
        category = category,
        perfCategory = perfCategory,
        maxKmh = maxKmh,
        zeroTo100 = zeroTo100,
        isHyper = isHyper,
        tier = VehiclePricing.ResolveTier(maxKmh, zeroTo100, isHyper),
    }
end

function VehiclePricing.CalculatePrice(model, category, priceHint)
    local profile = VehiclePricing.ResolveProfile(model, category, priceHint)
    local pCfg = pricingCfg()

    local maxKmh = profile.maxKmh
    local zeroTo100 = profile.zeroTo100
    local cat = profile.perfCategory or profile.category

    local speedNorm = clamp((maxKmh - 140.0) / 170.0, 0.0, 1.15)
    local accelNorm = clamp((14.0 / zeroTo100) - 0.5, 0.2, 5.5)

    local base = tonumber(pCfg.BasePrice) or 10000
    local speedWeight = tonumber(pCfg.SpeedWeight) or 400000
    local accelWeight = tonumber(pCfg.AccelWeight) or 88000

    local price = base
        + (speedNorm ^ 2.0) * speedWeight
        + (accelNorm ^ 1.25) * accelWeight

    local catMult = (pCfg.CategoryMultiplier or {})[cat] or 1.0
    price = price * catMult

    if profile.isHyper then
        price = math.max(price, tonumber(cfg().HyperMinPrice) or 3000000)
    end

    local tierBands = pCfg.TierBands or {}
    local band = tierBands[profile.tier]
    if band then
        price = clamp(price, tonumber(band.min) or 0, tonumber(band.max) or price)
    end

    local globalMax = tonumber(pCfg.GlobalMaxPrice) or 4500000
    local globalMin = tonumber(pCfg.GlobalMinPrice) or 8000
    price = clamp(price, globalMin, globalMax)

    return roundTo(price, tonumber(pCfg.RoundTo) or 500), profile
end

function VehiclePricing.GetTierLabel(tier)
    local labels = (pricingCfg().TierLabels) or {}
    return labels[tier] or tier
end
