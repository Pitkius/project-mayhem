local QBCore = exports['qb-core']:GetCoreObject()
local PlayerData = {}
local seatbeltOn = false

local function clamp(value, minValue, maxValue)
    if value < minValue then return minValue end
    if value > maxValue then return maxValue end
    return value
end

local function getNeeds()
    local metadata = PlayerData.metadata or {}
    local hunger = metadata.hunger or 100
    local thirst = metadata.thirst or 100
    return clamp(hunger, 0, 100), clamp(thirst, 0, 100)
end

local function getMoney()
    local latest = QBCore.Functions.GetPlayerData()
    if latest and latest.money then
        PlayerData = latest
    end
    local money = PlayerData.money or {}
    return tonumber(money.cash) or 0, tonumber(money.bank) or 0
end

local function pushHud()
    local ped = PlayerPedId()
    local health = clamp(GetEntityHealth(ped) - 100, 0, 100)
    local armor = clamp(GetPedArmour(ped), 0, 100)
    local hunger, thirst = getNeeds()
    local cash, bank = getMoney()
    local show = not IsPauseMenuActive()
    local inVehicle = IsPedInAnyVehicle(ped, false)
    local speed, fuel, engine = 0, 0, 0

    if inVehicle then
        local veh = GetVehiclePedIsIn(ped, false)
        if veh == 0 then
            inVehicle = false
        else
            speed = clamp(math.floor(GetEntitySpeed(veh) * 3.6 + 0.5), 0, 450)
            fuel = clamp(math.floor(GetVehicleFuelLevel(veh) + 0.5), 0, 100)
            engine = clamp(math.floor((GetVehicleEngineHealth(veh) / 10.0) + 0.5), 0, 100)
        end
    else
        seatbeltOn = false
    end

    SendNUIMessage({
        action = 'update',
        show = show,
        health = health,
        armor = armor,
        showArmor = armor > 0,
        hunger = hunger,
        thirst = thirst,
        cash = cash,
        bank = bank,
        inVehicle = inVehicle,
        speed = speed,
        fuel = fuel,
        engine = engine,
        seatbelt = seatbeltOn
    })
end

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    PlayerData = QBCore.Functions.GetPlayerData()
end)

RegisterNetEvent('QBCore:Player:SetPlayerData', function(val)
    PlayerData = val
end)

RegisterCommand('fivempro_seatbelt', function()
    local ped = PlayerPedId()
    if not IsPedInAnyVehicle(ped, false) then return end
    seatbeltOn = not seatbeltOn
    local msg = seatbeltOn and 'Dirzas: ijungtas' or 'Dirzas: isjungtas'
    BeginTextCommandThefeedPost('STRING')
    AddTextComponentSubstringPlayerName(msg)
    EndTextCommandThefeedPostTicker(false, false)
end, false)

RegisterKeyMapping('fivempro_seatbelt', 'Toggle seatbelt', 'keyboard', 'B')

CreateThread(function()
    Wait(1000)
    PlayerData = QBCore.Functions.GetPlayerData()

    while true do
        pushHud()
        Wait(700)
    end
end)

CreateThread(function()
    while true do
        -- Remove GTA default weapon/ammo HUD and keep only custom indicators.
        HideHudComponentThisFrame(2)
        HideHudComponentThisFrame(7)
        HideHudComponentThisFrame(9)
        HideHudComponentThisFrame(19)
        HideHudComponentThisFrame(20)
        HideHudComponentThisFrame(22)
        Wait(0)
    end
end)

