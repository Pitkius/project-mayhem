local gameMinutes = 0
local lastWeather = nil
local lastRegion = nil
local lastHourKey = nil
local transitioning = false

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

local function applyWeather(weather, withTransition)
    if not weather or weather == '' then return end
    local cfg = weatherCfg()
    if withTransition and lastWeather and lastWeather ~= weather then
        transitioning = true
        SetWeatherTypeOverTime(weather, cfg.TransitionSeconds or 12.0)
        SetTimeout(math.floor((cfg.TransitionSeconds or 12.0) * 1000), function()
            transitioning = false
        end)
    end
    lastWeather = weather
    ClearOverrideWeather()
    ClearWeatherTypePersist()
    SetWeatherTypePersist(weather)
    SetWeatherTypeNow(weather)
    SetWeatherTypeNowPersist(weather)
    SetRainLevel(rainLevelFor(weather))
    if weather == 'XMAS' then
        SetForceVehicleTrails(true)
        SetForcePedFootstepsTracks(true)
    else
        SetForceVehicleTrails(false)
        SetForcePedFootstepsTracks(false)
    end
end

local function refreshRegionalWeather(force)
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local regionId = WeatherForecast.getRegionAtCoords(coords.x, coords.y)
    local day, hour = getDayHour()
    local hourKey = ('%s:%d:%d'):format(regionId, day, hour)
    if not force and hourKey == lastHourKey and regionId == lastRegion then return end

    lastHourKey = hourKey
    lastRegion = regionId
    local seed = weatherCfg().Seed or 1
    local slot = WeatherForecast.buildSlot(regionId, day, hour, seed)
    applyWeather(slot.weather, lastWeather ~= nil)
end

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    TriggerServerEvent('qb-weathersync:server:RequestStateSync')
end)

RegisterNetEvent('qb-weathersync:client:SyncTime', function(base, offset)
    syncGameMinutes(base, offset)
    refreshRegionalWeather(true)
end)

RegisterNetEvent('qb-weathersync:client:SyncWeather', function()
    -- Prognozė valdo orus — ignoruojame globalų qb-weathersync orą.
    refreshRegionalWeather(true)
end)

CreateThread(function()
    Wait(1500)
    TriggerServerEvent('qb-weathersync:server:RequestStateSync')
    while true do
        if not transitioning then
            refreshRegionalWeather(false)
        end
        Wait(100)
    end
end)

exports('getCurrentSlot', function(regionId)
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    regionId = regionId or WeatherForecast.getRegionAtCoords(coords.x, coords.y)
    local day, hour = getDayHour()
    return WeatherForecast.buildSlot(regionId, day, hour, weatherCfg().Seed or 1)
end)

exports('getRegionAtCoords', function(x, y)
    return WeatherForecast.getRegionAtCoords(x, y)
end)

exports('getRegions', function()
    return weatherCfg().Regions or {}
end)
