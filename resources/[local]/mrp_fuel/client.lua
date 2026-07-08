local QBCore = exports['qb-core']:GetCoreObject()

local pumping = false
local fuelSession = nil
local lastPayResult = { ok = false }
local lastEmptyNotify = 0
local payMethod = 'cash'

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
    local newFuel = math.max(0.0, fuel - use)
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
        if SetFuelConsumptionRateMultiplier then SetFuelConsumptionRateMultiplier(0.0) end
    end)
end

if Config.EnableConsumption ~= false then
    CreateThread(function()
        local tick = math.max(400, tonumber(Config.ConsumptionTickMs) or 1000)
        while true do
            local ped = PlayerPedId()
            if IsPedInAnyVehicle(ped, false) and not pumping then
                local veh = GetVehiclePedIsIn(ped, false)
                if veh ~= 0 and GetPedInVehicleSeat(veh, -1) == ped then
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

local function sendUi(action, data)
    SendNUIMessage({ action = action, data = data or {} })
end

local function nearestVehicle(maxDist)
    local ped = PlayerPedId()
    local pos = GetEntityCoords(ped)
    if IsPedInAnyVehicle(ped, false) then
        return GetVehiclePedIsIn(ped, false)
    end
    local veh = GetClosestVehicle(pos.x, pos.y, pos.z, maxDist or 6.0, 0, 70)
    if veh ~= 0 and DoesEntityExist(veh) then return veh end
    return 0
end

local function nearStation(pos)
    local maxD = (tonumber(Config.MaxDistanceToPump) or 4.5) + 8.0
    for _, s in ipairs(Config.Stations or {}) do
        if #(pos - vector3(s.x, s.y, s.z)) <= maxD then return true end
    end
    return false
end

local function playFuelAnim()
    local ped = PlayerPedId()
    local dict = 'timetable@gardener@filling_can'
    RequestAnimDict(dict)
    while not HasAnimDictLoaded(dict) do Wait(10) end
    TaskPlayAnim(ped, dict, 'gar_ig_5_filling_can', 8.0, -8.0, -1, 49, 0, false, false, false)
end

local function stopFuelAnim()
    local ped = PlayerPedId()
    StopAnimTask(ped, 'timetable@gardener@filling_can', 'gar_ig_5_filling_can', 1.0)
    ClearPedSecondaryTask(ped)
end

local function closeFuelUi()
    pumping = false
    fuelSession = nil
    SetNuiFocus(false, false)
    sendUi('close')
    stopFuelAnim()
end

local function openFuelUi(data)
    local choosePay = data and data.choosePay == true
    SetNuiFocus(choosePay, choosePay)
    sendUi('open', data or {})
end

local function updateFuelUi()
    if not fuelSession then return end
    sendUi('update', {
        fuel = fuelSession.currentFuel,
        liters = fuelSession.liters,
        cost = fuelSession.cost,
        target = 100,
        label = 'Pildomas kuras…',
        choosePay = false,
    })
end

local function finishFuelSession()
    if not fuelSession then return end
    TriggerServerEvent('mrp_fuel:server:finish', {
        cost = math.floor(fuelSession.cost),
        liters = fuelSession.liters,
        method = payMethod,
    })
    closeFuelUi()
    QBCore.Functions.Notify(('Pripilta %.1f L · $%s'):format(fuelSession.liters, math.floor(fuelSession.cost)), 'success')
end

local function startFuelSession(veh)
    if pumping or not veh or veh == 0 then return end
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) then
        TaskLeaveVehicle(ped, veh, 0)
        local timeout = GetGameTimer() + 3500
        while IsPedInAnyVehicle(ped, false) and GetGameTimer() < timeout do Wait(50) end
    end
    if not nearStation(GetEntityCoords(veh)) and not nearStation(GetEntityCoords(ped)) then
        return QBCore.Functions.Notify('Per toli nuo degalinės.', 'error')
    end

    payMethod = 'cash'
    pumping = true
    fuelSession = {
        veh = veh,
        currentFuel = GetFuel(veh),
        liters = 0.0,
        cost = 0.0,
    }

    openFuelUi({
        fuel = fuelSession.currentFuel,
        liters = 0,
        cost = 0,
        target = 100,
        label = 'Pasirinkite mokėjimą',
        choosePay = true,
    })
    playFuelAnim()

    CreateThread(function()
        while pumping and fuelSession do
            Wait(0)
            DisableControlAction(0, 24, true)
            DisableControlAction(0, 25, true)
            if IsControlJustPressed(0, 177) or IsControlJustPressed(0, 200) then
                if fuelSession.liters > 0 then finishFuelSession() else closeFuelUi() end
                break
            end
        end
    end)
end

RegisterNUICallback('fuelChoosePay', function(data, cb)
    payMethod = (data and data.method == 'bank') and 'bank' or 'cash'
    if not fuelSession then cb({ ok = false }) return end
    SetNuiFocus(false, false)
    sendUi('update', {
        fuel = fuelSession.currentFuel,
        liters = fuelSession.liters,
        cost = fuelSession.cost,
        target = 100,
        label = ('Mokėjimas: %s'):format(payMethod == 'bank' and 'kortele' or 'grynais'),
        choosePay = false,
    })

    CreateThread(function()
        local tick = math.max(250, tonumber(Config.FuelTickMs) or 450)
        local perTick = tonumber(Config.LitersPerTick) or 1.2
        local price = tonumber(Config.PricePerLiter) or 7
        while pumping and fuelSession do
            local veh = fuelSession.veh
            if not veh or not DoesEntityExist(veh) then break end
            if fuelSession.currentFuel >= 99.5 then
                QBCore.Functions.Notify('Bakas pilnas.', 'primary')
                break
            end
            local paid = false
            lastPayResult = { ok = false }
            TriggerServerEvent('mrp_fuel:server:payTick', payMethod)
            local deadline = GetGameTimer() + 1500
            while GetGameTimer() < deadline do
                if lastPayResult and lastPayResult.ok then paid = true break end
                Wait(30)
            end
            if not paid then
                QBCore.Functions.Notify('Nebepakanka pinigų.', 'error')
                break
            end
            fuelSession.currentFuel = math.min(100.0, fuelSession.currentFuel + (perTick * 0.9))
            fuelSession.liters = fuelSession.liters + perTick
            fuelSession.cost = fuelSession.cost + (perTick * price)
            SetFuel(veh, fuelSession.currentFuel)
            updateFuelUi()
            Wait(tick)
        end
        if fuelSession and fuelSession.liters > 0 then finishFuelSession() else closeFuelUi() end
    end)
    cb({ ok = true })
end)

RegisterNUICallback('fuelCancel', function(_, cb)
    if fuelSession and fuelSession.liters > 0 then finishFuelSession() else closeFuelUi() end
    cb({ ok = true })
end)

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

CreateThread(function()
    while GetResourceState('qb-target') ~= 'started' do Wait(300) end
    exports['qb-target']:AddTargetModel(Config.PumpModels or {}, {
        options = {
            {
                icon = 'fas fa-gas-pump',
                label = 'Pilti kurą',
                action = function()
                    local veh = nearestVehicle(7.0)
                    if veh == 0 then
                        return QBCore.Functions.Notify('Pastatyk automobilį šalia kolonėlės.', 'error')
                    end
                    startFuelSession(veh)
                end,
                canInteract = function()
                    return not pumping and nearestVehicle(7.0) ~= 0
                end,
            },
        },
        distance = 2.2,
    })
end)
