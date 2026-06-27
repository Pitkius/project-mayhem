--- Laimės ratas + jackpot automobilis ant podiumo

Casino = Casino or {}

local wheelEntity = nil
local podiumVehicle = nil
local jackpotData = nil

local function loadModel(model)
    local hash = type(model) == 'string' and joaat(model) or model
    if not IsModelInCdimage(hash) then return false end
    RequestModel(hash)
    local t = 0
    while not HasModelLoaded(hash) and t < 150 do
        Wait(10)
        t = t + 1
    end
    return HasModelLoaded(hash), hash
end

function Casino.getWheelEntity()
    return wheelEntity
end

local function ensureWheel()
    local cfg = Config.Wheel or {}
    local coords = cfg.coords
    if not coords then return end

    if wheelEntity and DoesEntityExist(wheelEntity) then return end

    local models = { cfg.model or `vw_prop_vw_luckywheel_02a`, `vw_prop_vw_luckywheel_01a` }
    for _, model in ipairs(models) do
        local found = GetClosestObjectOfType(coords.x, coords.y, coords.z, 6.0, model, false, false, false)
        if found and found ~= 0 then
            wheelEntity = found
            return
        end
    end

    -- IPL ratas dar neužsikrovė — nekuriam dublikato (tuščias be tekstūrų)
end

local function deletePodiumVehicle()
    if podiumVehicle and DoesEntityExist(podiumVehicle) then
        SetEntityAsMissionEntity(podiumVehicle, true, true)
        DeleteVehicle(podiumVehicle)
    end
    podiumVehicle = nil
end

local function spawnPodiumVehicle(data)
    if not data or not data.model then return end
    deletePodiumVehicle()

    local podium = (Config.JackpotCar and Config.JackpotCar.podium) or vector4(1100.47, 220.25, -49.95, 0.0)
    local ok, hash = loadModel(data.model)
    if not ok then return end

    local veh = CreateVehicle(hash, podium.x, podium.y, podium.z, podium.w or 0.0, false, false)
    if veh and veh ~= 0 then
        SetEntityAsMissionEntity(veh, true, true)
        SetVehicleOnGroundProperly(veh)
        FreezeEntityPosition(veh, true)
        SetVehicleDoorsLocked(veh, 2)
        SetVehicleEngineOn(veh, false, true, true)
        SetVehicleDirtLevel(veh, 0.0)
        podiumVehicle = veh
    end
    SetModelAsNoLongerNeeded(hash)
end

RegisterNetEvent('mrp_casino:client:jackpotCarUpdated', function(data)
    jackpotData = data
    if Casino.isInside and Casino.isInside() then
        spawnPodiumVehicle(data)
    end
end)

CreateThread(function()
    Wait(3000)
    local QBCore = exports['qb-core']:GetCoreObject()
    QBCore.Functions.TriggerCallback('mrp_casino:server:getJackpotCar', function(data)
        jackpotData = data
    end)
end)

CreateThread(function()
    while true do
        local sleep = 2000
        if Casino.isInside and Casino.isInside() then
            sleep = 500
            ensureWheel()
            if jackpotData and jackpotData.model and (not podiumVehicle or not DoesEntityExist(podiumVehicle)) then
                spawnPodiumVehicle(jackpotData)
            end
            if podiumVehicle and DoesEntityExist(podiumVehicle) then
                local h = GetEntityHeading(podiumVehicle)
                SetEntityHeading(podiumVehicle, h - 0.15)
            end
            if jackpotData and jackpotData.label and Casino.drawText3D then
                local podium = (Config.JackpotCar and Config.JackpotCar.podium)
                if podium then
                    local p = GetEntityCoords(PlayerPedId())
                    if #(p - vector3(podium.x, podium.y, podium.z)) < 18.0 then
                        Casino.drawText3D(vector3(podium.x, podium.y, podium.z + 1.35), ('Jackpot: %s'):format(jackpotData.label), 0.38)
                    end
                end
            end
        elseif podiumVehicle then
            deletePodiumVehicle()
        end
        Wait(sleep)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if wheelEntity and DoesEntityExist(wheelEntity) then
        local cfg = Config.Wheel or {}
        local coords = cfg.coords
        local model = cfg.model or `vw_prop_vw_luckywheel_02a`
        if coords and GetClosestObjectOfType(coords.x, coords.y, coords.z, 2.0, model, false, false, false) ~= wheelEntity then
            DeleteEntity(wheelEntity)
        end
    end
    deletePodiumVehicle()
end)
