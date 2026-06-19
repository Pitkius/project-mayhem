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

    AddEventHandler('QBCore:Server:OnMoneyChange', function(src, moneytype, amount, action, reason)
        if not src or src <= 0 then return end
        reason = reason or 'N/A'
        moneytype = moneytype or 'cash'
        amount = tonumber(amount) or 0

        if reason == 'fivempro-bank-deposit' and action == 'add' and moneytype == 'bank' then
            return SendLog('bank', 'Banko įnešimas', ('**$%s** į banką'):format(amount), {
                { name = 'Priežastis', value = reason, inline = true },
            }, src)
        end
        if reason == 'fivempro-bank-withdraw' and action == 'remove' and moneytype == 'bank' then
            return SendLog('bank', 'Banko išėmimas', ('**$%s** iš banko'):format(amount), {
                { name = 'Priežastis', value = reason, inline = true },
            }, src)
        end
        if reason == 'fivempro-bank-transfer-out' and action == 'remove' and moneytype == 'bank' then
            return SendLog('bank', 'Banko pavedimas', ('**$%s** (siuntėjas)'):format(amount), {
                { name = 'Priežastis', value = reason, inline = true },
            }, src)
        end
        if reason == 'fivempro-bank-transfer-in' then
            return
        end

        local title = 'Pinigų pokytis'
        local sign = '+'
        if action == 'remove' then
            title = 'Pinigai pašalinti'
            sign = '-'
        elseif action == 'set' then
            title = 'Pinigai nustatyti'
            sign = '='
        elseif action == 'add' then
            title = 'Pinigai pridėti'
        end

        SendLog('money', title, ('%s$%s **%s**'):format(sign, amount, moneytype), {
            { name = 'Priežastis', value = reason, inline = false },
        }, src)

        local threshold = Config.Security and Config.Security.suspiciousMoneyThreshold or 500000
        if action == 'add' and amount >= threshold then
            TriggerEvent('server_logs:securityCheck', 'suspicious_money', { amount = amount, account = moneytype })
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
