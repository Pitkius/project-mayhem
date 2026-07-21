local QBCore = exports['qb-core']:GetCoreObject()

local REQUIRED_BUILD = 3095

CreateThread(function()
    Wait(2000)
    local enforced = GetConvar('sv_enforceGameBuild', '0')
    print(('^2[mrp_buildcheck]^0 sv_enforceGameBuild = %s (reikia %s — Bottom Dollar / PD šviesos)'):format(enforced, REQUIRED_BUILD))
    if tonumber(enforced) ~= REQUIRED_BUILD then
        print(('^1[mrp_buildcheck]^0 DĖMESIO: serveris neprivers build %s — patikrink server.cfg / txAdmin.'):format(REQUIRED_BUILD))
    end
end)

QBCore.Functions.CreateCallback('mrp_buildcheck:server:getEnforcedBuild', function(_, cb)
    cb(GetConvar('sv_enforceGameBuild', '0'))
end)

RegisterCommand('serverbuild', function(src)
    local enforced = GetConvar('sv_enforceGameBuild', '0')
    local msg = ('Serveris: sv_enforceGameBuild = %s (tikimasi %s)'):format(enforced, REQUIRED_BUILD)
    if src == 0 then
        print('[mrp_buildcheck] ' .. msg)
    else
        TriggerClientEvent('QBCore:Notify', src, msg, 'primary', 6000)
    end
end, true)
