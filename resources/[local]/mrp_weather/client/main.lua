local gameMinutes = 0
local lastWeather = nil
local lastRegion = nil
local lastHourKey = nil
local transitioning = false
local weatherPaused = false
local pendingWeather = nil
local stickyRegion = nil
local stickyUntil = 0

local function weatherCfg()
    return Config.Weather or {}
end

local function syncGameMinutes(base, offset)
    gameMinutes = math.floor((tonumber(base) or 0) + (tonumber(offset) or 0))
end

local function getDayHour()
    local day = math.floor(gameMinutes / 1440)
    local hour = math.floor((gameMinutes % 1440) / 60)
    local minute = gameMinutes % 60
    return day, hour, minute
end

local function rainLevelFor(weather)
    if weather == 'RAIN' then return 0.32 end
    if weather == 'THUNDER' then return 0.52 end
    if weather == 'CLEARING' then return 0.12 end
    return 0.0
end

local function applyTrails(weather)
    local snow = weather == 'XMAS' or weather == 'SNOW' or weather == 'BLIZZARD' or weather == 'SNOWLIGHT'
    SetForceVehicleTrails(snow)
    SetForcePedFootstepsTracks(snow)
end

local function commitWeatherNow(weather)
    ClearOverrideWeather()
    ClearWeatherTypePersist()
    SetWeatherTypePersist(weather)
    SetWeatherTypeNow(weather)
    SetWeatherTypeNowPersist(weather)
    SetRainLevel(rainLevelFor(weather))
    applyTrails(weather)
end

--- Soft transition: OverTime only. Persist/Now only after blend finishes.
local function applyWeather(weather, withTransition)
    if not weather or weather == '' then return end
    if weather == lastWeather and weather == pendingWeather then return end

    local cfg = weatherCfg()
    local duration = tonumber(cfg.TransitionSeconds) or 45.0
    if duration < 5.0 then duration = 5.0 end

    pendingWeather = weather

    if withTransition and lastWeather and lastWeather ~= weather then
        transitioning = true
        SetWeatherTypeOverTime(weather, duration)
        local target = weather
        SetTimeout(math.floor(duration * 1000), function()
            if pendingWeather ~= target then return end
            commitWeatherNow(target)
            lastWeather = target
            transitioning = false
        end)
        -- Keep lastWeather as previous until blend ends, but track target via pendingWeather.
        -- Rain eases in near the end of the blend.
        SetTimeout(math.floor(duration * 700), function()
            if pendingWeather == target then
                SetRainLevel(rainLevelFor(target) * 0.55)
            end
        end)
        return
    end

    transitioning = false
    lastWeather = weather
    commitWeatherNow(weather)
end

local function resolveRegion(x, y)
    local regionId = WeatherForecast.getRegionAtCoords(x, y)
    local now = GetGameTimer()
    local stickMs = math.floor((tonumber(weatherCfg().RegionStickSeconds) or 12.0) * 1000)

    if stickyRegion == regionId then
        stickyUntil = now + stickMs
        return regionId
    end

    -- Border hysteresis: keep previous region briefly to avoid flicker.
    if stickyRegion and stickyRegion ~= regionId and now < stickyUntil then
        return stickyRegion
    end

    stickyRegion = regionId
    stickyUntil = now + stickMs
    return regionId
end

local function refreshRegionalWeather(force)
    if weatherPaused then return end
    if transitioning and not force then return end

    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local regionId = resolveRegion(coords.x, coords.y)
    local day, hour = getDayHour()
    -- Weather blocks (multi-hour) — key uses block, not raw hour.
    local blockHours = math.max(1, math.floor(tonumber(weatherCfg().WeatherBlockHours) or 3))
    local block = math.floor(hour / blockHours)
    local hourKey = ('%s:%d:b%d'):format(regionId, day, block)

    if not force and hourKey == lastHourKey and regionId == lastRegion then
        return
    end

    local seed = weatherCfg().Seed or 1
    local slot = WeatherForecast.buildSlot(regionId, day, hour, seed)
    local changed = lastWeather ~= nil and lastWeather ~= slot.weather
    local regionChanged = lastRegion ~= nil and lastRegion ~= regionId

    lastHourKey = hourKey
    lastRegion = regionId
    applyWeather(slot.weather, (not force or changed or regionChanged) and lastWeather ~= nil)
end

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    TriggerServerEvent('qb-weathersync:server:RequestStateSync')
end)

RegisterNetEvent('qb-weathersync:client:SyncTime', function(base, offset)
    -- Laikas atnaujinamas dažnai — orą perkrauname tik kai pasikeičia blokas/regionas.
    syncGameMinutes(base, offset)
    refreshRegionalWeather(false)
end)

RegisterNetEvent('qb-weathersync:client:SyncWeather', function()
    -- Ignoruojame globalų qb-weathersync orą; tik patikriname regioninę prognozę.
    refreshRegionalWeather(false)
end)

CreateThread(function()
    Wait(1500)
    TriggerServerEvent('qb-weathersync:server:RequestStateSync')
    while true do
        if not weatherPaused then
            refreshRegionalWeather(false)
        end
        Wait(2000)
    end
end)

exports('SetWeatherPaused', function(paused)
    weatherPaused = paused == true
end)

exports('IsWeatherPaused', function()
    return weatherPaused
end)

exports('RefreshNow', function()
    refreshRegionalWeather(true)
end)

exports('getCurrentSlot', function(regionId)
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    regionId = regionId or resolveRegion(coords.x, coords.y)
    local day, hour = getDayHour()
    return WeatherForecast.buildSlot(regionId, day, hour, weatherCfg().Seed or 1)
end)

exports('getRegionAtCoords', function(x, y)
    return WeatherForecast.getRegionAtCoords(x, y)
end)

exports('getRegions', function()
    return weatherCfg().Regions or {}
end)
