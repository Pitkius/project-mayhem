local QBCore = exports['qb-core']:GetCoreObject()

local cfg = Config.VehiclePerf or {}
local modelIndex = {}
local activeVeh = 0
local activeMaxMs = 0.0

local function kmhToMs(kmh)
    return (tonumber(kmh) or 0) / 3.6
end

local function modelNameFromHash(hash)
    local row = modelIndex[hash]
    if row then return row.name end
    return nil
end

local function isRehModel(name)
    local row = modelIndex[name and joaat(name) or 0]
    return row and row.isReh
end

local function isFullyTuned(veh)
    if not veh or veh == 0 then return false end
    local eng = GetVehicleMod(veh, 11)
    local needEng = tonumber(cfg.FullTuneMinEngineMod) or 4
    if eng < 0 then eng = 0 end
    if eng < needEng then return false end
    if cfg.RequireTurboForHyperBonus ~= false and not IsToggleModOn(veh, 18) then
        return false
    end
    return true
end

local function categoryCapKmh(category)
    local caps = cfg.VanillaCategoryCap or {}
    return caps[category]
end

local function resolveMaxKmh(veh)
    if not cfg.Enabled then return nil end
    if not veh or veh == 0 then return nil end

    local hash = GetEntityModel(veh)
    local row = modelIndex[hash]
    local name = row and row.name or nil

    if name and cfg.HyperCars and cfg.HyperCars[name] then
        if isFullyTuned(veh) then
            return tonumber(cfg.HyperTunedMaxKmh) or 330
        end
        return tonumber(cfg.GlobalCapKmh) or 310
    end

    if name and cfg.RehMaxKmh and cfg.RehMaxKmh[name] then
        return math.min(cfg.RehMaxKmh[name], cfg.GlobalCapKmh or 310)
    end

    if row and row.isReh then
        local cat = row.category or 'sedans'
        local catKmh = (cfg.RehCategoryKmh or {})[cat] or 218
        return math.min(catKmh, cfg.GlobalCapKmh or 310)
    end

    if row and row.category then
        local cap = categoryCapKmh(row.category)
        if cap then
            local est = GetVehicleModelEstimatedMaxSpeed(hash) * 3.6
            if est > cap + 2.0 then
                return cap
            end
        end
    end

    return nil
end

local function applyMaxSpeed(veh)
    if not cfg.Enabled or not veh or veh == 0 then return end
    local kmh = resolveMaxKmh(veh)
    if not kmh then
        if activeVeh == veh then
            SetVehicleMaxSpeed(veh, 0.0)
            activeVeh = 0
            activeMaxMs = 0.0
        end
        return
    end

    local ms = kmhToMs(kmh)
    if activeVeh ~= veh or math.abs(activeMaxMs - ms) > 0.05 then
        SetVehicleMaxSpeed(veh, ms)
        activeVeh = veh
        activeMaxMs = ms
    end
end

local function buildModelIndex()
    modelIndex = {}
    local rehSet = {}
    for name in pairs(cfg.RehMaxKmh or {}) do
        rehSet[name:lower()] = true
    end

    local vehicles = QBCore.Shared and QBCore.Shared.Vehicles or {}
    for name, row in pairs(vehicles) do
        local model = (row.model or name):lower()
        local hash = joaat(model)
        modelIndex[hash] = {
            name = model,
            category = row.category,
            isReh = rehSet[model] == true or rehSet[name:lower()] == true,
        }
        modelIndex[model] = modelIndex[hash]
    end

    for name in pairs(cfg.RehMaxKmh or {}) do
        local model = name:lower()
        local hash = joaat(model)
        if not modelIndex[hash] then
            modelIndex[hash] = { name = model, category = 'sports', isReh = true }
            modelIndex[model] = modelIndex[hash]
        else
            modelIndex[hash].isReh = true
        end
    end
end

CreateThread(function()
    Wait(500)
    buildModelIndex()
end)

AddEventHandler('onResourceStart', function(res)
    if res ~= GetCurrentResourceName() then return end
    Wait(250)
    buildModelIndex()
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    Wait(500)
    buildModelIndex()
end)

CreateThread(function()
    while true do
        if cfg.Enabled then
            local ped = PlayerPedId()
            if IsPedInAnyVehicle(ped, false) then
                local veh = GetVehiclePedIsIn(ped, false)
                if GetPedInVehicleSeat(veh, -1) == ped then
                    applyMaxSpeed(veh)
                    Wait(350)
                else
                    if activeVeh == veh then
                        SetVehicleMaxSpeed(veh, 0.0)
                        activeVeh = 0
                    end
                    Wait(600)
                end
            else
                if activeVeh ~= 0 then
                    SetVehicleMaxSpeed(activeVeh, 0.0)
                    activeVeh = 0
                    activeMaxMs = 0.0
                end
                Wait(800)
            end
        else
            Wait(2000)
        end
    end
end)

exports('GetConfiguredMaxKmh', function(model)
    local hash = type(model) == 'number' and model or joaat(tostring(model or ''))
    local row = modelIndex[hash]
    if not row then return nil end
    if cfg.RehMaxKmh and cfg.RehMaxKmh[row.name] then
        return cfg.RehMaxKmh[row.name]
    end
    if row.isReh and row.category and cfg.RehCategoryKmh then
        return cfg.RehCategoryKmh[row.category]
    end
    return categoryCapKmh(row.category)
end)
