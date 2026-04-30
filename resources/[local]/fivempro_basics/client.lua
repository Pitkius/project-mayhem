local QBCore = exports['qb-core']:GetCoreObject()

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

-- Global fail-safe: pressing ESC/P always releases stuck NUI focus and target mode.
CreateThread(function()
    while true do
        if IsControlJustPressed(0, 199) or IsControlJustPressed(0, 200) then
            SetNuiFocus(false, false)
            SetNuiFocusKeepInput(false)
            if GetResourceState('qb-target') == 'started' then
                exports['qb-target']:DisableTarget(true)
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

RegisterNetEvent('fivempro_basics:client:showCoords', function(targetServerId)
    local targetPlayer = GetPlayerFromServerId(tonumber(targetServerId) or -1)
    if targetPlayer == -1 then
        QBCore.Functions.Notify('Nepavyko gauti zaidejo koordinates', 'error')
        return
    end

    local ped = GetPlayerPed(targetPlayer)
    if ped == 0 then
        QBCore.Functions.Notify('Nepavyko gauti zaidejo ped', 'error')
        return
    end

    local coords = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)
    local msg = ('x: %.2f, y: %.2f, z: %.2f, h: %.2f'):format(coords.x, coords.y, coords.z, heading)
    print(('[fivempro_basics] /coords -> %s'):format(msg))
    QBCore.Functions.Notify(msg, 'success', 9000)
end)

RegisterNetEvent('fivempro_basics:client:useSandwich', function(itemName)
    QBCore.Functions.Progressbar('fivempro_eat_sandwich', 'Valgai...', 4500, false, true, {
        disableMovement = false,
        disableCarMovement = false,
        disableMouse = false,
        disableCombat = true
    }, {
        animDict = 'mp_player_inteat@burger',
        anim = 'mp_player_int_eat_burger',
        flags = 49
    }, {
        model = 'prop_cs_burger_01',
        bone = 60309,
        coords = vec3(0.0, 0.0, -0.02),
        rotation = vec3(30.0, 0.0, 0.0)
    }, {}, function()
        TriggerEvent('qb-inventory:client:ItemBox', QBCore.Shared.Items[itemName], 'remove')
        local meta = QBCore.Functions.GetPlayerData().metadata or {}
        local hunger = math.min(100, (tonumber(meta.hunger) or 0) + 40)
        local thirst = math.min(100, (tonumber(meta.thirst) or 0) + 10)
        TriggerServerEvent('consumables:server:addHunger', hunger)
        TriggerServerEvent('consumables:server:addThirst', thirst)
    end, function()
        QBCore.Functions.Notify('Atšaukta', 'error')
    end)
end)

RegisterNetEvent('fivempro_basics:client:useWaterBottle', function(itemName)
    QBCore.Functions.Progressbar('fivempro_drink_water', 'Geri vandeni...', 3500, false, true, {
        disableMovement = false,
        disableCarMovement = false,
        disableMouse = false,
        disableCombat = true
    }, {
        animDict = 'mp_player_intdrink',
        anim = 'loop_bottle',
        flags = 49
    }, {
        model = 'vw_prop_casino_water_bottle_01a',
        bone = 60309,
        coords = vec3(0.0, 0.0, -0.05),
        rotation = vec3(0.0, 0.0, -40.0)
    }, {}, function()
        TriggerEvent('qb-inventory:client:ItemBox', QBCore.Shared.Items[itemName], 'remove')
        local meta = QBCore.Functions.GetPlayerData().metadata or {}
        local thirst = math.min(100, (tonumber(meta.thirst) or 0) + 45)
        local hunger = math.min(100, (tonumber(meta.hunger) or 0) + 5)
        TriggerServerEvent('consumables:server:addThirst', thirst)
        TriggerServerEvent('consumables:server:addHunger', hunger)
    end, function()
        QBCore.Functions.Notify('Atšaukta', 'error')
    end)
end)

