local QBCore = exports['qb-core']:GetCoreObject()
local PlayerData = {}
local seatbeltOn = false
local hudPreset = 1
local HUD_PRESET_COUNT = 3

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

local function pushHud()
    local ped = PlayerPedId()
    local health = clamp(GetEntityHealth(ped) - 100, 0, 100)
    local armor = clamp(GetPedArmour(ped), 0, 100)
    local hunger, thirst = getNeeds()
    local show = not IsPauseMenuActive()
    local inVehicle = IsPedInAnyVehicle(ped, false)
    local speed, fuel = 0, 0

    if inVehicle then
        local veh = GetVehiclePedIsIn(ped, false)
        if veh == 0 then
            inVehicle = false
        else
            speed = clamp(math.floor(GetEntitySpeed(veh) * 3.6 + 0.5), 0, 450)
            fuel = clamp(math.floor(GetVehicleFuelLevel(veh) + 0.5), 0, 100)
        end
    else
        seatbeltOn = false
    end

    SendNUIMessage({
        action = 'update',
        show = show,
        hudPreset = hudPreset,
        health = health,
        armor = armor,
        showArmor = armor > 0,
        hunger = hunger,
        thirst = thirst,
        inVehicle = inVehicle,
        speed = speed,
        fuel = fuel,
        seatbelt = seatbeltOn
    })
end

local function saveHudPreset()
    SetResourceKvpInt('fivempro_hud:preset', hudPreset)
end

local function setHudPreset(newPreset)
    local p = tonumber(newPreset) or 1
    p = math.floor(p)
    if p < 1 then p = HUD_PRESET_COUNT end
    if p > HUD_PRESET_COUNT then p = 1 end
    hudPreset = p
    saveHudPreset()
    SendNUIMessage({
        action = 'preset',
        hudPreset = hudPreset
    })
    QBCore.Functions.Notify(('HUD stilius: %s/%s'):format(hudPreset, HUD_PRESET_COUNT), 'primary')
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

RegisterCommand('hud', function(_, args)
    local arg = args and args[1] and tostring(args[1]) or ''
    if arg == '+' then
        setHudPreset(hudPreset + 1)
        return
    end
    if arg == '-' then
        setHudPreset(hudPreset - 1)
        return
    end
    local asNum = tonumber(arg)
    if asNum then
        setHudPreset(asNum)
        return
    end
    QBCore.Functions.Notify('Naudok: /hud + , /hud - , /hud 1-3', 'primary')
end, false)

CreateThread(function()
    Wait(1000)
    PlayerData = QBCore.Functions.GetPlayerData()
    hudPreset = GetResourceKvpInt('fivempro_hud:preset')
    if hudPreset < 1 or hudPreset > HUD_PRESET_COUNT then
        hudPreset = 1
    end
    SendNUIMessage({
        action = 'preset',
        hudPreset = hudPreset
    })

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

