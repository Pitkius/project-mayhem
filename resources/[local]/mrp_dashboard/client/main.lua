--[[
  Mayhem ESC Dashboard — fully replaces native pause (ESC).
  Map / Settings still open native GTA frontend on demand.
]]

local isOpen = false
--- When true, allow ActivateFrontendMenu (map/settings) without fighting ESC suppress
local allowNativeFrontend = false

local function openDashboard()
    if isOpen then return end
    if IsPauseMenuActive() then
        SetPauseMenuActive(false)
        SetFrontendActive(false)
    end
    isOpen = true
    allowNativeFrontend = false
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

local function openNativeFrontend(menuHash)
    allowNativeFrontend = true
    closeDashboard()
    CreateThread(function()
        Wait(80)
        SetPauseMenuActive(false)
        SetFrontendActive(false)
        Wait(50)
        ActivateFrontendMenu(menuHash, false, -1)
        -- Keep allow flag until frontend closes
        local deadline = GetGameTimer() + 15000
        while GetGameTimer() < deadline do
            if IsPauseMenuActive() then
                break
            end
            Wait(50)
        end
        while IsPauseMenuActive() do
            Wait(200)
        end
        Wait(100)
        allowNativeFrontend = false
    end)
end

local function openNativeMap()
    openNativeFrontend(`FE_MENU_VERSION_MP_PAUSE`)
end

local function openNativeSettings()
    openNativeFrontend(`FE_MENU_VERSION_LANDING_MENU`)
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

--- Hard-replace native ESC / P pause with our dashboard
CreateThread(function()
    while true do
        if allowNativeFrontend then
            Wait(100)
        else
            -- Kill native pause every frame before it paints
            DisableControlAction(0, 199, true) -- P
            DisableControlAction(0, 200, true) -- ESC / pause
            DisableControlAction(1, 199, true)
            DisableControlAction(1, 200, true)
            DisableControlAction(2, 199, true)
            DisableControlAction(2, 200, true)

            if IsPauseMenuActive() then
                SetPauseMenuActive(false)
                SetFrontendActive(false)
            end

            if isOpen then
                DisableControlAction(0, 322, true) -- ESC alt
                if IsDisabledControlJustReleased(0, 200)
                    or IsDisabledControlJustReleased(0, 199)
                    or IsDisabledControlJustReleased(0, 322)
                then
                    closeDashboard()
                end
            else
                if IsDisabledControlJustReleased(0, 200) or IsDisabledControlJustReleased(0, 199) then
                    openDashboard()
                end
            end

            Wait(0)
        end
    end
end)

RegisterCommand('dashboard', function()
    if allowNativeFrontend then return end
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
