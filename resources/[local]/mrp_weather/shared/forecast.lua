WeatherForecast = WeatherForecast or {}

local function cfg()
    return (Config and Config.Weather) or {}
end

local function stableHash(str)
    local h = 5381
    for i = 1, #str do
        h = (h * 33 + string.byte(str, i)) % 2147483647
    end
    return h
end

local function pickWeighted(weights, roll)
    local total = 0
    for _, w in pairs(weights) do
        total = total + w
    end
    if total <= 0 then return 'CLEAR' end
    local cursor = roll % total
    for weather, w in pairs(weights) do
        cursor = cursor - w
        if cursor < 0 then
            return weather
        end
    end
    return 'CLEAR'
end

function WeatherForecast.getRegionWeights(regionId)
    local weights = cfg().RegionWeights or {}
    return weights[regionId] or weights.los_santos or { CLEAR = 1 }
end

function WeatherForecast.getWeatherType(regionId, gameDay, hour, seed)
    local key = ('%s:%d:%d:%d'):format(regionId or 'los_santos', gameDay or 0, hour or 0, seed or 0)
    local roll = stableHash(key)
    return pickWeighted(WeatherForecast.getRegionWeights(regionId), roll)
end

function WeatherForecast.getTemperature(regionId, weatherType)
    local base = (cfg().BaseTempC or {})[regionId] or 20
    local mod = (cfg().TempModifier or {})[weatherType] or 0
    local jitter = (stableHash(regionId .. weatherType) % 5) - 2
    return base + mod + jitter
end

function WeatherForecast.getLabel(weatherType)
    local labels = cfg().Labels or {}
    return labels[weatherType] or weatherType or 'Nežinoma'
end

function WeatherForecast.getIcon(weatherType)
    local icons = cfg().Icons or {}
    return icons[weatherType] or 'cloud'
end

function WeatherForecast.buildSlot(regionId, gameDay, hour, seed)
    local weather = WeatherForecast.getWeatherType(regionId, gameDay, hour, seed)
    return {
        gameDay = gameDay,
        hour = hour,
        weather = weather,
        label = WeatherForecast.getLabel(weather),
        icon = WeatherForecast.getIcon(weather),
        tempC = WeatherForecast.getTemperature(regionId, weather),
    }
end

local function dayLabel(offset, gameDay)
    if offset == 0 then return 'Šiandien'
    elseif offset == 1 then return 'Rytoj'
    end
    return ('Diena %d'):format(gameDay)
end

function WeatherForecast.buildWeek(regionId, startGameDay, seed, daysCount)
    local count = daysCount or (cfg().ForecastDays or 7)
    local days = {}
    for offset = 0, count - 1 do
        local gameDay = startGameDay + offset
        local hours = {}
        for hour = 0, 23 do
            hours[#hours + 1] = WeatherForecast.buildSlot(regionId, gameDay, hour, seed)
        end
        days[#days + 1] = {
            offset = offset,
            gameDay = gameDay,
            label = dayLabel(offset, gameDay),
            hours = hours,
        }
    end
    return days
end

function WeatherForecast.getRegionAtCoords(x, y)
    local regions = cfg().Regions or {}
    local bestId = 'los_santos'
    local bestDist = math.huge
    for _, region in ipairs(regions) do
        local c = region.center
        if c then
            local dx = (x or 0.0) - c.x
            local dy = (y or 0.0) - c.y
            local dist = math.sqrt(dx * dx + dy * dy)
            local radius = region.radius or 5000.0
            if dist <= radius and dist < bestDist then
                bestDist = dist
                bestId = region.id
            end
        end
    end
    return bestId
end
