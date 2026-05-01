local QBCore = exports['qb-core']:GetCoreObject()
local coordsHudEnabled = false

CreateThread(function()
    Wait(1500)
    print("[fivempro_basics] Client script aktyvus.")
end)

-- Disable GTA default weapon wheel (TAB) so inventory/hotbar flow is consistent.
CreateThread(function()
    while true do
        DisableControlAction(0, 37, true) -- INPUT_SELECT_WEAPON (TAB)
        -- Keep pause/menu keys available even if another resource aggressively disables controls.
        EnableControlAction(0, 199, true) -- INPUT_FRONTEND_PAUSE_ALTERNATE (P)
        EnableControlAction(0, 200, true) -- INPUT_FRONTEND_PAUSE (ESC)
        Wait(0)
    end
end)

-- TAB shows qb-inventory hotbar (slots 1-5) while held.
CreateThread(function()
    local tabHotbarShown = false
    while true do
        if IsControlJustPressed(0, 37) then
            ExecuteCommand('hotbar')
            tabHotbarShown = true
        elseif tabHotbarShown and IsControlJustReleased(0, 37) then
            ExecuteCommand('hotbar')
            tabHotbarShown = false
        end
        Wait(0)
    end
end)

-- Global fail-safe: pressing ESC/P always releases stuck NUI focus and target mode.
CreateThread(function()
    while true do
        if IsControlJustPressed(0, 199) or IsControlJustPressed(0, 200) then
            SetNuiFocus(false, false)
            SetNuiFocusKeepInput(false)
            TriggerEvent('qb-menu:client:closeMenu')
            TriggerEvent('qb-inventory:client:closeInv')
            if GetResourceState('qb-target') == 'started' then
                exports['qb-target']:DisableTarget(false)
            end
        end
        Wait(0)
    end
end)

local function reviveLocalPlayer()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)

    NetworkResurrectLocalPlayer(coords.x, coords.y, coords.z + 0.5, heading, true, false)
    SetPlayerInvincible(PlayerId(), false)
    ClearPedBloodDamage(ped)
    ClearPedTasksImmediately(ped)
    SetEntityHealth(ped, 200)
    SetPedArmour(ped, 0)

    BeginTextCommandThefeedPost('STRING')
    AddTextComponentSubstringPlayerName('Atsigavai (test revive).')
    EndTextCommandThefeedPostTicker(false, false)
    print('[fivempro_basics] Test revive ivykdytas.')
end

local function healLocalPlayer()
    local ped = PlayerPedId()
    SetEntityHealth(ped, 200)
    ClearPedBloodDamage(ped)
end

RegisterCommand('fprevive', function()
    reviveLocalPlayer()
end, false)

RegisterKeyMapping('fprevive', 'Fivempro test revive', 'keyboard', 'F6')

RegisterNetEvent('fivempro_basics:client:adminRevive', function()
    reviveLocalPlayer()
end)

RegisterNetEvent('fivempro_basics:client:adminHeal', function()
    healLocalPlayer()
end)

RegisterNetEvent('fivempro_basics:client:openRegister', function()
    if GetResourceState('qb-clothing') ~= 'started' then
        BeginTextCommandThefeedPost('STRING')
        AddTextComponentSubstringPlayerName('qb-clothing nera paleistas.')
        EndTextCommandThefeedPostTicker(false, false)
        return
    end

    TriggerEvent('qb-clothes:client:CreateFirstCharacter')
end)

RegisterNetEvent('fivempro_basics:client:toggleCoords', function()
    coordsHudEnabled = not coordsHudEnabled
    if coordsHudEnabled then
        QBCore.Functions.Notify('/coords ijungta', 'success')
    else
        QBCore.Functions.Notify('/coords isjungta', 'error')
    end
end)

CreateThread(function()
    while true do
        if coordsHudEnabled then
            local ped = PlayerPedId()
            local coords = GetEntityCoords(ped)
            local heading = GetEntityHeading(ped)
            local text = ('COORDS  X: %.2f  Y: %.2f  Z: %.2f  H: %.2f'):format(coords.x, coords.y, coords.z, heading)

            SetTextFont(4)
            SetTextProportional(1)
            SetTextScale(0.38, 0.38)
            SetTextColour(255, 255, 255, 220)
            SetTextCentre(true)
            SetTextOutline()
            BeginTextCommandDisplayText('STRING')
            AddTextComponentSubstringPlayerName(text)
            EndTextCommandDisplayText(0.5, 0.02)

            Wait(0)
        else
            Wait(250)
        end
    end
end)

RegisterNetEvent('fivempro_basics:client:useSandwich', function(itemName)
    local ped = PlayerPedId()
    RequestAnimDict('mp_player_inteat@burger')
    while not HasAnimDictLoaded('mp_player_inteat@burger') do Wait(0) end
    local prop = CreateObject(`prop_cs_burger_01`, 0.0, 0.0, 0.0, true, true, false)
    AttachEntityToEntity(prop, ped, GetPedBoneIndex(ped, 60309), 0.0, 0.0, -0.02, 30.0, 0.0, 0.0, true, true, false, true, 1, true)
    TaskPlayAnim(ped, 'mp_player_inteat@burger', 'mp_player_int_eat_burger', 8.0, -8.0, 4500, 49, 0, false, false, false)
    Wait(4500)
    ClearPedTasks(ped)
    DeleteEntity(prop)

    TriggerEvent('qb-inventory:client:ItemBox', QBCore.Shared.Items[itemName], 'remove')
    local meta = QBCore.Functions.GetPlayerData().metadata or {}
    local hunger = math.min(100, (tonumber(meta.hunger) or 0) + 40)
    local thirst = math.min(100, (tonumber(meta.thirst) or 0) + 10)
    TriggerServerEvent('consumables:server:addHunger', hunger)
    TriggerServerEvent('consumables:server:addThirst', thirst)
end)

RegisterNetEvent('fivempro_basics:client:useWaterBottle', function(itemName)
    local ped = PlayerPedId()
    RequestAnimDict('mp_player_intdrink')
    while not HasAnimDictLoaded('mp_player_intdrink') do Wait(0) end
    local prop = CreateObject(`vw_prop_casino_water_bottle_01a`, 0.0, 0.0, 0.0, true, true, false)
    AttachEntityToEntity(prop, ped, GetPedBoneIndex(ped, 60309), 0.0, 0.0, -0.05, 0.0, 0.0, -40.0, true, true, false, true, 1, true)
    TaskPlayAnim(ped, 'mp_player_intdrink', 'loop_bottle', 8.0, -8.0, 3500, 49, 0, false, false, false)
    Wait(3500)
    ClearPedTasks(ped)
    DeleteEntity(prop)

    TriggerEvent('qb-inventory:client:ItemBox', QBCore.Shared.Items[itemName], 'remove')
    local meta = QBCore.Functions.GetPlayerData().metadata or {}
    local thirst = math.min(100, (tonumber(meta.thirst) or 0) + 45)
    local hunger = math.min(100, (tonumber(meta.hunger) or 0) + 5)
    TriggerServerEvent('consumables:server:addThirst', thirst)
    TriggerServerEvent('consumables:server:addHunger', hunger)
end)

