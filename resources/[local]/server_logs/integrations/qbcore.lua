-- QBCore integration examples
-- Add hooks in your qb-core / script events

CreateThread(function()
    if GetResourceState('qb-core') ~= 'started' then return end
    local QBCore = exports['qb-core']:GetCoreObject()

    print('[server_logs] QBCore integration loaded')

    AddEventHandler('QBCore:Server:OnJobUpdate', function(src, job)
        if not job then return end
        TriggerEvent('server_logs:jobSet', job.name, job.grade and job.grade.level or 0, src)
    end)

    -- Money (example - hook your economy events)
    RegisterNetEvent('server_logs:qbcoreMoney', function(src, moneytype, amount, action, reason)
        if action == 'add' then
            TriggerClientEvent('server_logs:internal', src) -- placeholder
            TriggerEvent('server_logs:moneyAdd', moneytype, amount, reason)
        end
    end)
end)

--[[
EXAMPLE: in your give item script (server):

RegisterNetEvent('inventory:server:GiveItem', function(target, item, amount)
    -- ... your logic ...
    TriggerEvent('server_logs:inventoryAdd', item, amount, 'give')
end)

EXAMPLE: bank (fivempro_bank or qb-banking):

TriggerEvent('server_logs:bankDeposit', amount, balanceBefore, balanceAfter)

EXAMPLE: death from ambulance script:

TriggerEvent('server_logs:playerDeath', {
    victim = victimId,
    killer = killerId,
    weapon = weaponHash,
    distance = dist,
    headshot = wasHeadshot,
    vehicleKill = wasVehicle,
    deathType = 'pvp',
})

EXAMPLE: EMS revive:

TriggerEvent('server_logs:revive', {
    victim = victimId,
    reviver = src,
    type = 'ems',
})

EXAMPLE: custom export:

exports['server_logs']:SendCustomLog('admin', 'Custom Title', 'Message here', source)
]]
