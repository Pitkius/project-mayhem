local QBCore = exports['qb-core']:GetCoreObject()
local tabletOpen = false
local hackCb = nil
local tabletProp = nil

local function stopTabletAnim()
    local ped = PlayerPedId()
    ClearPedSecondaryTask(ped)
    if tabletProp and DoesEntityExist(tabletProp) then
        DeleteEntity(tabletProp)
    end
    tabletProp = nil
end

local function playTabletAnim()
    local ped = PlayerPedId()
    local dict = 'amb@world_human_seat_wall_tablet@female@base'
    RequestAnimDict(dict)
    while not HasAnimDictLoaded(dict) do Wait(0) end
    TaskPlayAnim(ped, dict, 'base', 8.0, -8.0, -1, 49, 0, false, false, false)
    local model = joaat('prop_cs_tablet')
    RequestModel(model)
    while not HasModelLoaded(model) do Wait(0) end
    tabletProp = CreateObject(model, 1.0, 1.0, 1.0, true, true, false)
    AttachEntityToEntity(tabletProp, ped, GetPedBoneIndex(ped, 60309), 0.03, 0.002, 0.0, 10.0, 160.0, 0.0, true, true, false, true, 1, true)
end

local function closeTablet()
    if not tabletOpen then return end
    tabletOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
    stopTabletAnim()
end

local function closeHack()
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'hackClose' })
end

RegisterNetEvent('fivempro_hacking:client:openTablet', function(opts)
    QBCore.Functions.TriggerCallback('fivempro_hacking:server:getTabletData', function(data)
        if not data or not data.ok then
            return QBCore.Functions.Notify((data and data.msg) or 'Neturi hacking tablet.', 'error')
        end
        tabletOpen = true
        playTabletAnim()
        SetNuiFocus(true, true)
        SendNUIMessage({ action = 'openTablet', data = data, flashTab = opts and opts.flashTab, driveSlot = opts and opts.driveSlot })
    end)
end)

RegisterNUICallback('close', function(_, cb)
    closeTablet()
    cb('ok')
end)

RegisterNUICallback('networkAction', function(data, cb)
    local tierId = data and data.tierId
    local action = data and data.action
    if action == 'breach' then
        closeTablet()
        local label = (Config.RobberyTiers[tierId] and Config.RobberyTiers[tierId].label) or tierId or 'taikinio'
        QBCore.Functions.Notify(('Artėk prie „%s“ ir naudok target zoną (Pradėti įsilaužimą).'):format(label), 'primary', 8000)
    elseif action == 'backdoor' then
        QBCore.Functions.Notify('Backdoor modulis dar neaktyvuotas šiame taikinyje.', 'error')
    end
    cb('ok')
end)

RegisterNUICallback('marketBuy', function(data, cb)
    local idx = tonumber(data and data.index)
    if idx then
        TriggerServerEvent('fivempro_hacking:server:buyBlackMarket', idx)
    end
    cb('ok')
end)

RegisterNUICallback('installDrive', function(data, cb)
    QBCore.Functions.TriggerCallback('fivempro_hacking:server:installFromDrive', function(res)
        cb(res or { ok = false })
        if res and res.ok then
            SendNUIMessage({ action = 'tabletRefresh', data = res })
            QBCore.Functions.Notify('Įdiegta iš flashdrive.', 'success')
        elseif res and res.msg then
            QBCore.Functions.Notify(res.msg, 'error')
        end
    end, data and data.slot)
end)

function StartHackMinigame(tierId, coords, onDone, locId)
    QBCore.Functions.TriggerCallback('fivempro_hacking:server:prepareHack', function(res)
        if not res or not res.ok then
            QBCore.Functions.Notify((res and res.msg) or 'Negali pradėti hack.', 'error')
            if onDone then onDone(false) end
            return
        end
        hackCb = onDone
        exports['fivempro_hacking']:PlayRobberyAnim((Config.RobberyAnims or {}).hack)
        PlaySoundFrontend(-1, 'Background', 'DLC_HEIST_BIOLAB_PREP_HACKING_SOUNDS', true)
        SetNuiFocus(true, true)
        SendNUIMessage({ action = 'hackOpen', profile = res.profile, tierId = tierId })
    end, tierId, locId)
end

RegisterNUICallback('hackResult', function(data, cb)
    local success = data and data.success == true
    local tierId = data and data.tierId
    local coords = GetEntityCoords(PlayerPedId())
    exports['fivempro_hacking']:StopRobberyAnim()
    TriggerServerEvent('fivempro_hacking:server:hackFinished', tierId, success, { x = coords.x, y = coords.y, z = coords.z })
    closeHack()
    if hackCb then
        local fn = hackCb
        hackCb = nil
        fn(success)
    end
    cb('ok')
end)

RegisterNUICallback('hackCancel', function(_, cb)
    closeHack()
    exports['fivempro_hacking']:StopRobberyAnim()
    if hackCb then
        local fn = hackCb
        hackCb = nil
        fn(false)
    end
    cb('ok')
end)

exports('StartHack', StartHackMinigame)

CreateThread(function()
    while true do
        if tabletOpen and IsControlJustPressed(0, 322) then
            closeTablet()
        end
        Wait(tabletOpen and 0 or 500)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    stopTabletAnim()
end)

CreateThread(function()
    local bm = Config.BlackMarket
    if not bm or not bm.coords then return end
    local hash = joaat(bm.pedModel or 's_m_y_dealer_01')
    RequestModel(hash)
    while not HasModelLoaded(hash) do Wait(10) end
    local ped = CreatePed(0, hash, bm.coords.x, bm.coords.y, bm.coords.z - 1.0, bm.heading or 0.0, false, false)
    SetEntityInvincible(ped, true)
    FreezeEntityPosition(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    exports['qb-target']:AddTargetEntity(ped, {
        options = {
            {
                icon = 'fas fa-skull',
                label = 'Black market (hacking)',
                action = function()
                    local rows = { { header = 'Hacking black market', isMenuHeader = true } }
                    for i, e in ipairs(bm.items or {}) do
                        local label = QBCore.Shared.Items[e.item] and QBCore.Shared.Items[e.item].label or e.item
                        local extra = ''
                        if e.payload and e.payload.payload_id then
                            extra = ' [' .. tostring(e.payload.payload_id) .. ']'
                        end
                        rows[#rows + 1] = {
                            header = ('%s — $%s%s'):format(label, e.price, extra),
                            params = {
                                isAction = true,
                                event = function()
                                    TriggerServerEvent('fivempro_hacking:server:buyBlackMarket', i)
                                end,
                            },
                        }
                    end
                    TriggerEvent('qb-menu:client:openMenu', rows, false, true)
                end,
            },
        },
        distance = 2.0,
    })
end)
