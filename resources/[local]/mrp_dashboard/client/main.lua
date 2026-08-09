--[[
  Mayhem ESC Dashboard — client bridge
  Open: ESC / F10 / /dashboard
  Close: ESC / Close button / NUI callback
  Map / Settings: native GTA frontend (no custom pages)
]]

local isOpen = false

local function openDashboard()
    if isOpen then return end
    isOpen = true
    SetNuiFocus(true, true)
    SetNuiFocusKeepInput(false)
    SendNUIMessage({ action = 'open', payload = {} })
end

local function closeDashboard()
    if not isOpen then return end
    isOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

local function openNativeMap()
    closeDashboard()
    CreateThread(function()
        Wait(120)
        -- Native pause menu (map tab available like normal GTA)
        ActivateFrontendMenu(`FE_MENU_VERSION_MP_PAUSE`, false, -1)
    end)
end

local function openNativeSettings()
    closeDashboard()
    CreateThread(function()
        Wait(120)
        -- Native settings / landing options
        ActivateFrontendMenu(`FE_MENU_VERSION_LANDING_MENU`, false, -1)
    end)
end

RegisterNUICallback('close', function(_, cb)
    closeDashboard()
    cb({ ok = true })
end)

RegisterNUICallback('ready', function(_, cb)
    cb({ ok = true })
end)

RegisterNUICallback('openNativeMap', function(_, cb)
    openNativeMap()
    cb({ ok = true })
end)

RegisterNUICallback('openNativeSettings', function(_, cb)
    openNativeSettings()
    cb({ ok = true })
end)

local STUBS = {
    'claimRpPass', 'claimAllRpPass', 'buyPremium',
    'claimMission', 'claimDailyCrate', 'claimReward', 'claimAllRewards',
    'purchaseImport', 'joinEvent',
}

for _, name in ipairs(STUBS) do
    RegisterNUICallback(name, function(data, cb)
        if name == 'claimDailyCrate' then
            TriggerServerEvent('mrp_dashboard:server:claimDailyCrate')
        end
        cb({ ok = true, stub = name ~= 'claimDailyCrate', data = data })
    end)
end

-- While open: block GTA pause / ESC default
CreateThread(function()
    while true do
        if isOpen then
            DisableControlAction(0, 199, true)
            DisableControlAction(0, 200, true)
            DisableControlAction(0, 322, true)
            if IsDisabledControlJustReleased(0, 200) or IsDisabledControlJustReleased(0, 322) then
                closeDashboard()
            end
            Wait(0)
        else
            Wait(150)
        end
    end
end)

-- Open on pause key (ESC / P) when closed — cancel default pause
CreateThread(function()
    while true do
        Wait(0)
        if not isOpen then
            if IsControlJustPressed(0, 200) or IsControlJustPressed(0, 199) then
                DisableControlAction(0, 200, true)
                DisableControlAction(0, 199, true)
                SetPauseMenuActive(false)
                openDashboard()
            end
        end
    end
end)

RegisterCommand('dashboard', function()
    if isOpen then
        closeDashboard()
    else
        openDashboard()
    end
end, false)

RegisterKeyMapping('dashboard', 'Atidaryti Mayhem Dashboard', 'keyboard', 'F10')

exports('IsOpen', function()
    return isOpen
end)

exports('Open', openDashboard)
exports('Close', closeDashboard)
