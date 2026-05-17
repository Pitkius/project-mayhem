local QBCore = exports['qb-core']:GetCoreObject()
local tabletOpen = false
local hackCb = nil

local function closeTablet()
    if not tabletOpen then return end
    tabletOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
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
        SetNuiFocus(true, true)
        SendNUIMessage({ action = 'openTablet', data = data, flashTab = opts and opts.flashTab })
    end)
end)

RegisterNUICallback('close', function(_, cb)
    closeTablet()
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

function StartHackMinigame(tierId, coords, onDone)
    QBCore.Functions.TriggerCallback('fivempro_hacking:server:prepareHack', function(res)
        if not res or not res.ok then
            QBCore.Functions.Notify((res and res.msg) or 'Negali pradėti hack.', 'error')
            if onDone then onDone(false) end
            return
        end
        hackCb = onDone
        SetNuiFocus(true, true)
        SendNUIMessage({ action = 'hackOpen', profile = res.profile, tierId = tierId })
    end, tierId)
end

RegisterNUICallback('hackResult', function(data, cb)
    local success = data and data.success == true
    local tierId = data and data.tierId
    local coords = GetEntityCoords(PlayerPedId())
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
    if hackCb then
        local fn = hackCb
        hackCb = nil
        fn(false)
    end
    cb('ok')
end)

exports('StartHack', StartHackMinigame)

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
