local QBCore = exports['qb-core']:GetCoreObject()

local function weatherCfg()
    return Config.Weather or {}
end

local function getGameTime()
    if GetResourceState('qb-weathersync') ~= 'started' then
        return 0, 0, 0, 0
    end
    local ok, day, hour, minute, total = pcall(function()
        return exports['qb-weathersync']:getGameDayHour()
    end)
    if ok and day then
        return day, hour, minute, total
    end
    local hour, minute = exports['qb-weathersync']:getTime()
    return 0, hour or 0, minute or 0, (hour or 0) * 60 + (minute or 0)
end

local function buildPayload(regionId)
    local cfg = weatherCfg()
    local seed = cfg.Seed or 1
    local day, hour = getGameTime()
    local current = WeatherForecast.buildSlot(regionId, day, hour, seed)
    return {
        ok = true,
        region = regionId,
        gameDay = day,
        gameHour = hour,
        current = current,
        days = WeatherForecast.buildWeek(regionId, day, seed, cfg.ForecastDays or 7),
    }
end

CreateThread(function()
    Wait(3000)
    local cfg = weatherCfg()
    if not cfg.DisableDynamicWeather then return end
    if GetResourceState('qb-weathersync') ~= 'started' then return end
    pcall(function()
        exports['qb-weathersync']:setDynamicWeather(false)
    end)
end)

QBCore.Functions.CreateCallback('mrp_weather:server:getForecast', function(_, cb, regionId)
    regionId = tostring(regionId or 'los_santos')
    local valid = false
    for _, r in ipairs(weatherCfg().Regions or {}) do
        if r.id == regionId then
            valid = true
            break
        end
    end
    if not valid then regionId = 'los_santos' end
    cb(buildPayload(regionId))
end)

QBCore.Functions.CreateCallback('mrp_weather:server:getRegions', function(_, cb)
    local regions = {}
    for _, r in ipairs(weatherCfg().Regions or {}) do
        regions[#regions + 1] = {
            id = r.id,
            label = r.label,
            hint = r.hint,
        }
    end
    cb({ ok = true, regions = regions })
end)

exports('getGameTime', getGameTime)

exports('getForecast', function(regionId)
    return buildPayload(regionId or 'los_santos')
end)

exports('getCurrentSlot', function(regionId)
    local cfg = weatherCfg()
    local day, hour = getGameTime()
    return WeatherForecast.buildSlot(regionId or 'los_santos', day, hour, cfg.Seed or 1)
end)
