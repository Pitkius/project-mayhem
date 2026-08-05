--[[
  Device open flow: prepare → PIN setup/unlock → hydrate apps.
]]

local QBCore = exports['qb-core']:GetCoreObject()

local currentPhoneId = nil
local currentPhoneType = 'legal'

local function nui(action, payload)
    SendNUIMessage({ action = action, payload = payload or {} })
end

local function openDeviceShell(opts)
    opts = opts or {}
    QBCore.Functions.TriggerCallback('mrp_phone:server:prepareOpen', function(res)
        if not res or not res.ok then
            QBCore.Functions.Notify((res and res.message) or 'Nepavyko atidaryti telefono.', 'error')
            return
        end
        currentPhoneId = res.phone and res.phone.phoneId or nil
        currentPhoneType = (res.phone and res.phone.phoneType) or 'legal'

        -- DarkNet access gate (buy/use still requires drugs unlock)
        if currentPhoneType == 'darknet' and GetResourceState('mrp_drugs') == 'started' then
            local st = nil
            pcall(function()
                st = exports['mrp_drugs']:GetDrugPlayerState and exports['mrp_drugs']:GetDrugPlayerState()
            end)
            -- server also validates market actions; open UI still allowed if item owned
        end

        TriggerEvent('mrp_phone:client:internalShowPhone', {
            devicePayload = res,
            needSetup = res.needSetup == true,
            phoneType = currentPhoneType,
        })
    end, opts)
end

RegisterNetEvent('mrp_phone:client:openPhoneDevice', function(data)
    openDeviceShell(data or {})
end)

-- Local TriggerEvent from F1 / other client scripts
AddEventHandler('mrp_phone:client:openPhoneDevice', function(data)
    openDeviceShell(data or {})
end)

RegisterNetEvent('mrp_phone:client:forceClose', function(info)
    currentPhoneId = nil
    TriggerEvent('mrp_phone:client:closePhone')
    if info and info.reason then
        QBCore.Functions.Notify(('Telefonas uždarytas (%s).'):format(tostring(info.reason)), 'error')
    end
end)

RegisterNUICallback('phoneSetupPin', function(data, cb)
    QBCore.Functions.TriggerCallback('mrp_phone:server:setupPin', function(res)
        if res and res.ok then
            nui('deviceReady', res.payload or {})
            TriggerEvent('mrp_phone:client:afterUnlock')
        end
        cb(res or { ok = false })
    end, {
        phoneId = currentPhoneId or (data and data.phoneId),
        pin = data and data.pin,
    })
end)

RegisterNUICallback('phoneUnlockPin', function(data, cb)
    QBCore.Functions.TriggerCallback('mrp_phone:server:unlockPin', function(res)
        if res and res.ok then
            nui('deviceReady', res.payload or {})
            TriggerEvent('mrp_phone:client:afterUnlock')
        end
        cb(res or { ok = false })
    end, {
        phoneId = currentPhoneId or (data and data.phoneId),
        pin = data and data.pin,
    })
end)

RegisterNUICallback('phoneFactoryReset', function(data, cb)
    QBCore.Functions.TriggerCallback('mrp_phone:server:factoryReset', function(res)
        cb(res or { ok = false })
    end, {
        phoneId = currentPhoneId or (data and data.phoneId),
        pin = data and data.pin,
    })
end)

RegisterNUICallback('darknetMarketState', function(_, cb)
    QBCore.Functions.TriggerCallback('mrp_phone:server:darknetMarketState', function(res)
        cb(res or { ok = false })
    end)
end)

RegisterNUICallback('darknetDropState', function(_, cb)
    QBCore.Functions.TriggerCallback('mrp_phone:server:darknetDropState', function(res)
        cb(res or { ok = false })
    end)
end)

RegisterNUICallback('darknetPlaceOrder', function(data, cb)
    QBCore.Functions.TriggerCallback('mrp_drugs:server:darknetPlaceOrder', function(res)
        cb(res or { ok = false })
    end, data and data.cart or {})
end)

RegisterNUICallback('darknetCollect', function(data, cb)
    QBCore.Functions.TriggerCallback('mrp_phone:server:darknetDropState', function(st)
        local orderId = st and st.order and st.order.id
        if not orderId then return cb({ ok = false, reason = 'Nėra užsakymo.' }) end
        QBCore.Functions.TriggerCallback('mrp_drugs:server:darknetCollect', function(res)
            cb(res or { ok = false })
        end, orderId, data and data.pin)
    end)
end)

RegisterNUICallback('encryptedList', function(_, cb)
    QBCore.Functions.TriggerCallback('mrp_phone:server:encryptedList', function(res)
        cb(res or { ok = false, threads = {} })
    end)
end)

RegisterNUICallback('encryptedSend', function(data, cb)
    QBCore.Functions.TriggerCallback('mrp_phone:server:encryptedSend', function(res)
        cb(res or { ok = false })
    end, data or {})
end)

exports('GetCurrentPhoneId', function()
    return currentPhoneId
end)

exports('GetCurrentPhoneType', function()
    return currentPhoneType
end)
