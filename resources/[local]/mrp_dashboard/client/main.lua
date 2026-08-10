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

local function buildPlayerPatch()
    local patch = {
        player = {},
    }
    local avatarUrl = captureMugshotUrl()
    if avatarUrl then
        patch.player.avatarUrl = avatarUrl
    end

    local QBCore = exports['qb-core'] and exports['qb-core']:GetCoreObject() or nil
    local pdata = QBCore and QBCore.Functions.GetPlayerData() or nil
    if pdata and pdata.charinfo then
        local ci = pdata.charinfo
        local first = ci.firstname or ''
        local last = ci.lastname or ''
        local name = (first .. ' ' .. last):gsub('^%s+', ''):gsub('%s+$', '')
        if name ~= '' then
            patch.player.characterName = name
        end
        if ci.cid or pdata.citizenid then
            -- keep display id as server id; citizenid is longer
        end
    end
    if pdata and pdata.job and pdata.job.label then
        patch.player.job = pdata.job.label
    end
    patch.player.id = GetPlayerServerId(PlayerId())
    if pdata and pdata.money then
        if pdata.money.cash ~= nil then patch.player.cash = pdata.money.cash end
        if pdata.money.bank ~= nil then patch.player.bank = pdata.money.bank end
        if pdata.money.credits ~= nil then patch.player.credits = pdata.money.credits end
    end
    if GetResourceState('mrp_credits') == 'started' then
        -- balance already on money.credits after resource sync; keep fallback
    end

    return patch
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

    CreateThread(function()
        local patch = buildPlayerPatch()
        if isOpen then
            SendNUIMessage({ action = 'setData', payload = patch })
        end
    end)
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

RegisterNUICallback('crateSpinDone', function(data, cb)
    local token = data and data.token
    TriggerServerEvent('mrp_dashboard:server:crateSpinDone', token)
    crateSpinOpen = false
    if not isOpen then
        SetNuiFocus(false, false)
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

local STUBS = {
    'claimRpPass', 'claimAllRpPass',
    'claimMission', 'claimDailyCrate', 'claimReward', 'claimAllRewards',
    'joinEvent',
}

for _, name in ipairs(STUBS) do
    RegisterNUICallback(name, function(payload, cb)
        if name == 'claimDailyCrate' then
            TriggerServerEvent('mrp_dashboard:server:claimDailyCrate')
        end
        cb({ ok = true, stub = name ~= 'claimDailyCrate', data = payload })
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
                -- Block closing mid-spin; ESC ignored until spin finishes
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
    clearMugshot()
end)

exports('IsOpen', function()
    return isOpen
end)

exports('Open', openDashboard)
exports('Close', closeDashboard)
