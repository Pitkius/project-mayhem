local QBCore = exports['qb-core']:GetCoreObject()
local REQUIRED_BUILD = 3788

AddEventHandler('onResourceStart', function(res)
    if res ~= GetCurrentResourceName() then return end
    local enforced = GetConvar('sv_enforceGameBuild', '0')
    print(('^2[mrp_buildcheck]^0 sv_enforceGameBuild = %s (reikia %s Kortz Center auto)'):format(enforced, REQUIRED_BUILD))
    if enforced ~= tostring(REQUIRED_BUILD) then
        print('^1[mrp_buildcheck]^0 DĖMESIO: serveris neprivers build 3788 — patikrink server.cfg / txAdmin Additional Arguments.')
    end
end)

QBCore.Functions.CreateCallback('mrp_buildcheck:server:getEnforcedBuild', function(_, cb)
    cb(GetConvar('sv_enforceGameBuild', '0'))
end)

RegisterCommand('serverbuild', function(source)
    local enforced = GetConvar('sv_enforceGameBuild', '0')
    local msg = ('Serveris: sv_enforceGameBuild = %s'):format(enforced)
    if source == 0 then
        print('[mrp_buildcheck] ' .. msg)
    else
        TriggerClientEvent('QBCore:Notify', source, msg, enforced == tostring(REQUIRED_BUILD) and 'success' or 'error', 8000)
    end
end, false)
