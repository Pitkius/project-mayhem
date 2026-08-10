--[[
  Mayhem ESC Dashboard — fully replaces native pause (ESC).
  Map / Settings still open native GTA frontend on demand.
]]

local isOpen = false
--- When true, allow ActivateFrontendMenu (map/settings) without fighting ESC suppress
local allowNativeFrontend = false
--- Keep headshot handle alive while NUI shows the face texture
local mugshotHandle = nil
--- CSGO crate spin overlay (inventory use) — blocks ESC dashboard toggle
local crateSpinOpen = false
local crateSpinTicks = false

local QBCore = exports['qb-core']:GetCoreObject()

local function clearMugshot()
    if mugshotHandle and mugshotHandle ~= 0 then
        UnregisterPedheadshot(mugshotHandle)
    end
    mugshotHandle = nil
end

--- Ped face texture URL for NUI (<img src="https://nui-img/txd/txd">)
local function captureMugshotUrl()
    clearMugshot()
    local ped = PlayerPedId()
    if not ped or ped == 0 then return nil end

    local handle = RegisterPedheadshot(ped)
    if not handle or handle == 0 then
        handle = RegisterPedheadshotTransparent(ped)
    end
    if not handle or handle == 0 then
        return nil
    end

    local deadline = GetGameTimer() + 2500
    while (not IsPedheadshotReady(handle) or not IsPedheadshotValid(handle)) and GetGameTimer() < deadline do
        Wait(50)
    end

    if not IsPedheadshotReady(handle) or not IsPedheadshotValid(handle) then
        UnregisterPedheadshot(handle)
        return nil
    end

    local txd = GetPedheadshotTxdString(handle)
    if type(txd) ~= 'string' or txd == '' then
        UnregisterPedheadshot(handle)
        return nil
    end

    mugshotHandle = handle
    return ('https://nui-img/%s/%s?t=%d'):format(txd, txd, GetGameTimer())
end

local function deepMergePlayer(patch)
    local avatarUrl = captureMugshotUrl()
    if avatarUrl then
        patch.player = patch.player or {}
        patch.player.avatarUrl = avatarUrl
    end
    return patch
end

local function requestDashboardData()
    QBCore.Functions.TriggerCallback('mrp_dashboard:server:getData', function(payload)
        if type(payload) ~= 'table' or not isOpen then return end
        SendNUIMessage({
            action = 'setData',
            payload = deepMergePlayer(payload),
        })
    end)
end

local function openDashboard()
    if isOpen or crateSpinOpen then return end
    if IsPauseMenuActive() then
        SetPauseMenuActive(false)
        SetFrontendActive(false)
    end
    isOpen = true
    allowNativeFrontend = false
    SetNuiFocus(true, true)
    SetNuiFocusKeepInput(false)
    SendNUIMessage({ action = 'open', payload = {} })
    requestDashboardData()
end

local function closeDashboard()
    if not isOpen then return end
    isOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
    clearMugshot()
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

RegisterNUICallback('updateSettings', function(data, cb)
    -- Stub: vėliau sinchronizuoti su mrp_hud / KVP
    if type(data) == 'table' then
        -- optional: TriggerEvent('mrp_hud:client:applySettings', data)
    end
    cb({ ok = true })
end)

RegisterNUICallback('crateSpinDone', function(data, cb)
    local token = data and data.token
    crateSpinTicks = false
    TriggerServerEvent('mrp_dashboard:server:crateSpinDone', token)
    crateSpinOpen = false
    if not isOpen then
        SetNuiFocus(false, false)
    end
    cb({ ok = true })
end)

RegisterNUICallback('crateSpinSound', function(data, cb)
    local kind = data and data.kind
    if kind == 'start' then
        PlaySoundFrontend(-1, 'SELECT', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
        crateSpinTicks = true
        CreateThread(function()
            local delay = 85
            while crateSpinTicks do
                PlaySoundFrontend(-1, 'NAV_UP_DOWN', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
                Wait(delay)
                delay = math.min(180, delay + 4)
            end
        end)
    elseif kind == 'win' then
        crateSpinTicks = false
        PlaySoundFrontend(-1, 'PROPERTY_PURCHASE', 'HUD_AWARDS', true)
        PlaySoundFrontend(-1, 'CHECKPOINT_PERFECT', 'HUD_MINI_GAME_SOUNDSET', true)
    elseif kind == 'stop' then
        crateSpinTicks = false
    end
    cb({ ok = true })
end)

RegisterNetEvent('mrp_dashboard:client:openCrateSpin', function(payload)
    if type(payload) ~= 'table' then return end
    crateSpinOpen = true
    SetNuiFocus(true, true)
    SetNuiFocusKeepInput(false)
    SendNUIMessage({ action = 'openCrateSpin', payload = payload })
end)

RegisterNetEvent('mrp_dashboard:client:setData', function(payload)
    if type(payload) ~= 'table' then return end
    if payload.player then
        payload = deepMergePlayer(payload)
    end
    SendNUIMessage({ action = 'setData', payload = payload })
end)

RegisterNetEvent('mrp_dashboard:client:setCredits', function(bal)
    SendNUIMessage({
        action = 'setData',
        payload = { player = { credits = tonumber(bal) or 0 } },
    })
end)

RegisterNetEvent('mrp_dashboard:client:setVip', function(tier, days)
    SendNUIMessage({
        action = 'setData',
        payload = {
            player = {
                vip = tier or 'NONE',
                vipDays = tonumber(days) or 0,
            },
        },
    })
end)

RegisterNUICallback('openTebexStore', function(_, cb)
    TriggerServerEvent('mrp_dashboard:server:openTebex')
    cb({ ok = true })
end)

RegisterNUICallback('purchaseCrate', function(data, cb)
    TriggerServerEvent('mrp_dashboard:server:purchaseCrate', data and data.id)
    cb({ ok = true })
end)

RegisterNUICallback('buyPremium', function(data, cb)
    TriggerServerEvent('mrp_dashboard:server:buyVip', data and data.plan)
    cb({ ok = true })
end)

RegisterNUICallback('purchaseImport', function(data, cb)
    TriggerServerEvent('mrp_dashboard:server:purchaseImport', data and data.id)
    cb({ ok = true })
end)

RegisterNUICallback('claimDailyCrate', function(_, cb)
    TriggerServerEvent('mrp_dashboard:server:claimDailyCrate')
    cb({ ok = true })
end)

RegisterNUICallback('claimWeeklyCrate', function(_, cb)
    TriggerServerEvent('mrp_dashboard:server:claimWeeklyCrate')
    cb({ ok = true })
end)

RegisterNUICallback('claimMission', function(data, cb)
    TriggerServerEvent('mrp_dashboard:server:claimMission', data and data.id)
    cb({ ok = true })
end)

local STUBS = {
    'claimRpPass', 'claimAllRpPass',
    'claimReward', 'claimAllRewards',
    'joinEvent',
}

for _, name in ipairs(STUBS) do
    RegisterNUICallback(name, function(payload, cb)
        cb({ ok = true, stub = true, data = payload })
    end)
end

CreateThread(function()
    while true do
        if allowNativeFrontend then
            Wait(100)
        else
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

            if crateSpinOpen then
                DisableControlAction(0, 322, true)
                Wait(0)
            elseif isOpen then
                DisableControlAction(0, 322, true) -- ESC alt
                if IsDisabledControlJustReleased(0, 200)
                    or IsDisabledControlJustReleased(0, 199)
                    or IsDisabledControlJustReleased(0, 322)
                then
                    closeDashboard()
                end
                Wait(0)
            else
                if IsDisabledControlJustReleased(0, 200) or IsDisabledControlJustReleased(0, 199) then
                    openDashboard()
                end
                Wait(0)
            end
        end
    end
end)

RegisterCommand('dashboard', function()
    if allowNativeFrontend or crateSpinOpen then return end
    if isOpen then
        closeDashboard()
    else
        openDashboard()
    end
end, false)

RegisterKeyMapping('dashboard', 'Atidaryti Mayhem Dashboard', 'keyboard', 'F10')

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    crateSpinTicks = false
    clearMugshot()
end)

exports('IsOpen', function()
    return isOpen
end)

exports('Open', openDashboard)
exports('Close', closeDashboard)
