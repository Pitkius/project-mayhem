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

