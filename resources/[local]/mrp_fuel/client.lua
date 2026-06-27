local QBCore = exports['qb-core']:GetCoreObject()

local pumping = false
local currentPump = nil
local lastPayResult = { ok = false }
local lastEmptyNotify = 0

local function clampFuel(v)
    return math.max(0.0, math.min(100.0, tonumber(v) or 0.0))
end

function GetFuel(veh)
    veh = veh or (IsPedInAnyVehicle(PlayerPedId(), false) and GetVehiclePedIsIn(PlayerPedId(), false) or 0)
    if not veh or veh == 0 then return 0.0 end
    return clampFuel(GetVehicleFuelLevel(veh))
end

function SetFuel(veh, amount)
    if not veh or veh == 0 then return end
    SetVehicleFuelLevel(veh, clampFuel(amount))
end

exports('GetFuel', GetFuel)
exports('SetFuel', SetFuel)

local function classMultiplier(veh)
    local class = GetVehicleClass(veh)
    local mult = Config.ClassMultiplier and Config.ClassMultiplier[class]
    if mult == nil then mult = 1.0 end
    return mult
end

local function applyConsumption(veh)
    if not veh or veh == 0 or not DoesEntityExist(veh) then return end
    if not GetIsVehicleEngineRunning(veh) then return end

    local classMult = classMultiplier(veh)
    if classMult <= 0.0 then return end

    local speedKmh = GetEntitySpeed(veh) * 3.6
    local base = tonumber(Config.ConsumptionBase) or 0.028
    local perKmh = tonumber(Config.ConsumptionPerKmh) or 0.0011
    local use = (base + math.max(0.0, speedKmh) * perKmh) * classMult

    local fuel = GetVehicleFuelLevel(veh)
    local newFuel = fuel - use
    if newFuel < 0.0 then newFuel = 0.0 end
    SetVehicleFuelLevel(veh, newFuel)

    if Config.ShutEngineOnEmpty and newFuel <= 0.5 then
        SetVehicleEngineOn(veh, false, true, true)
        local now = GetGameTimer()
        if GetPedInVehicleSeat(veh, -1) == PlayerPedId()
            and (now - lastEmptyNotify) > (Config.EmptyNotifyCooldownMs or 12000) then
            lastEmptyNotify = now
            QBCore.Functions.Notify('Baigėsi kuras.', 'error')
        end
    end
end

if Config.DisableGtaFuelConsumption ~= false then
    CreateThread(function()
        Wait(500)
        if SetFuelConsumptionRateMultiplier then
            SetFuelConsumptionRateMultiplier(0.0)
        end
    end)
end

if Config.EnableConsumption ~= false then
    CreateThread(function()
        local tick = math.max(400, tonumber(Config.ConsumptionTickMs) or 1000)
        while true do
            local ped = PlayerPedId()
            if IsPedInAnyVehicle(ped, false) then
                local veh = GetVehiclePedIsIn(ped, false)
                if veh ~= 0 and GetPedInVehicleSeat(veh, -1) == ped and not pumping then
                    applyConsumption(veh)
                    Wait(tick)
                else
                    Wait(tick)
                end
            else
                Wait(1500)
            end
        end
    end)
end

RegisterNetEvent('mrp_fuel:client:payResult', function(res)
    lastPayResult = res or { ok = false }
end)

local function createFuelBlips()
    for _, s in ipairs(Config.Stations or {}) do
        local blip = AddBlipForCoord(s.x + 0.0, s.y + 0.0, s.z + 0.0)
        SetBlipSprite(blip, Config.BlipSprite or 361)
        SetBlipScale(blip, Config.BlipScale or 0.75)
        SetBlipColour(blip, Config.BlipColor or 2)
        SetBlipDisplay(blip, 4)
        SetBlipAsShortRange(blip, true)
        exports['mrp_fonts']:SetBlipName(blip, Config.BlipLabel or 'Degalinė')
    end
end

CreateThread(function()
    Wait(1500)
    createFuelBlips()
end)

local function findNearestPump()
    local ped = PlayerPedId()
    if not IsPedInAnyVehicle(ped, false) then return nil end
    local veh = GetVehiclePedIsIn(ped, false)
    if GetPedInVehicleSeat(veh, -1) ~= ped then return nil end

    local pos = GetEntityCoords(veh)
    local bestDist, best = 9999.0, nil
    local maxD = Config.MaxDistanceToPump or 2.8
    for _, s in ipairs(Config.Stations or {}) do
        local d = #(pos - vector3(s.x, s.y, s.z))
        if d < maxD and d < bestDist then
            bestDist = d
            best = s
        end
    end
    if not best then return nil end
    return { coords = vector3(best.x, best.y, best.z), veh = veh }
end

local function stopPumping()
    if not pumping then return end
    pumping = false
    currentPump = nil
    ClearPedTasks(PlayerPedId())
end

local function startPumping(pump)
    if pumping then
        stopPumping()
        return
    end
    pumping = true
    currentPump = pump
    local ped = PlayerPedId()
    TaskTurnPedToFaceCoord(ped, pump.coords.x, pump.coords.y, pump.coords.z, 800)
    CreateThread(function()
        local pricePerL = Config.PricePerLiter or 7
        while pumping and currentPump and DoesEntityExist(currentPump.veh) do
            local veh = currentPump.veh
            local fuel = GetVehicleFuelLevel(veh)
            if fuel >= 99.5 then
                QBCore.Functions.Notify('Bakas pilnas.', 'primary')
                break
            end
            if not IsPedInAnyVehicle(ped, false) or GetVehiclePedIsIn(ped, false) ~= veh then
                QBCore.Functions.Notify('Turi likti automobilyje kol pilasi kuras.', 'error')
                break
            end
            lastPayResult = { ok = false }
            TriggerServerEvent('mrp_fuel:server:payTick')
            local waitMs = GetGameTimer() + 700
            while GetGameTimer() < waitMs and pumping do
                Wait(50)
            end
            if not lastPayResult.ok then
                QBCore.Functions.Notify('Nebepakanka pinigų kurui.', 'error')
                break
            end
            local add = 1.5
            SetVehicleFuelLevel(veh, math.min(100.0, fuel + add))
        end
        stopPumping()
    end)
end

CreateThread(function()
    while true do
        local ped = PlayerPedId()
        if IsPedInAnyVehicle(ped, false) then
            local pump = findNearestPump()
            if pump then
                local msg = pumping and '[E] Sustabdyti pildymą' or '[E] Pildyti kurą'
                local coords = pump.coords
                SetTextFont(0)
                SetTextProportional(1)
                SetTextScale(0.35, 0.35)
                SetTextColour(255, 255, 255, 215)
                SetTextCentre(true)
                BeginTextCommandDisplayText('STRING')
                AddTextComponentSubstringPlayerName(msg)
                EndTextCommandDisplayText(0.5, 0.90)

                if IsControlJustPressed(0, 38) then
                    startPumping(pump)
                end
                Wait(50)
            else
                Wait(400)
            end
        else
            if pumping then
                stopPumping()
            end
            Wait(600)
        end
    end
end)

