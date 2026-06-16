-- ESX integration examples

CreateThread(function()
    if GetResourceState('es_extended') ~= 'started' then return end
    local ESX = exports['es_extended']:getSharedObject()

    print('[server_logs] ESX integration loaded')

    AddEventHandler('esx:playerLoaded', function(playerId, xPlayer)
        TriggerEvent('server_logs:spawn', { spawnType = 'esx_load', details = 'ESX player loaded' })
    end)

    AddEventHandler('esx:setJob', function(playerId, job, _lastJob)
        TriggerEvent('server_logs:jobSet', job.name, job.grade, playerId)
    end)
end)

--[[
EXAMPLE: ESX add account money (in es_extended or custom):

AddEventHandler('esx:addAccountMoney', function(source, account, amount)
    TriggerEvent('server_logs:moneyAdd', account, amount, 'esx_addAccountMoney')
end)

EXAMPLE: ESX give inventory item:

TriggerEvent('server_logs:inventoryAdd', itemName, count, 'esx_give')

EXAMPLE: export:

exports['server_logs']:SendLog('money', 'ESX Custom', 'Details', {
    { name = 'Extra', value = 'data', inline = true },
}, source)
]]
