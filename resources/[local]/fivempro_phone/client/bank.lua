local QBCore = exports['qb-core']:GetCoreObject()

local function bankCb(name, data, cb)
    QBCore.Functions.TriggerCallback(name, function(res)
        cb(res or { ok = false, message = 'Klaida.' })
    end, data or {})
end

RegisterNUICallback('bankGetState', function(_, cb)
    bankCb('fivempro_phone:server:bankGetState', {}, cb)
end)

RegisterNUICallback('bankLookupRecipient', function(data, cb)
    bankCb('fivempro_phone:server:bankLookupRecipient', data, cb)
end)

RegisterNUICallback('bankTransfer', function(data, cb)
    bankCb('fivempro_phone:server:bankTransfer', data, cb)
end)

RegisterNUICallback('bankDeposit', function(data, cb)
    bankCb('fivempro_phone:server:bankDeposit', data, cb)
end)

RegisterNUICallback('bankWithdraw', function(data, cb)
    bankCb('fivempro_phone:server:bankWithdraw', data, cb)
end)

RegisterNUICallback('bankGetHistory', function(data, cb)
    bankCb('fivempro_phone:server:bankGetHistory', data, cb)
end)
