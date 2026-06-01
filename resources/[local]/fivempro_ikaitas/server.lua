local QBCore = exports['qb-core']:GetCoreObject()

--- aggressorSource -> victimSource
local activeAggressor = {}
--- victimSource -> aggressorSource
local activeVictim = {}

local function notify(src, msg, typ)
    TriggerClientEvent('QBCore:Notify', src, msg, typ or 'primary')
end

local function clearHostage(aggressor, victim, reason)
    if aggressor then
        activeAggressor[aggressor] = nil
        TriggerClientEvent('fivempro_ikaitas:client:stop', aggressor, reason or 'stop')
    end
    if victim then
        activeVictim[victim] = nil
        TriggerClientEvent('fivempro_ikaitas:client:stop', victim, reason or 'stop')
    end
end

local function isOnline(sid)
    sid = tonumber(sid)
    return sid and sid > 0 and QBCore.Functions.GetPlayer(sid) ~= nil
end

RegisterNetEvent('fivempro_ikaitas:server:tryStart', function(targetId)
    local src = source
    targetId = tonumber(targetId)
    if not targetId or targetId == src then return end
    if not isOnline(targetId) then
        notify(src, 'Žaidėjas neprisijungęs.', 'error')
        return
    end
    if activeAggressor[src] or activeVictim[src] then
        notify(src, 'Jau dalyvauji įkaitų situacijoje.', 'error')
        return
    end
    if activeAggressor[targetId] or activeVictim[targetId] then
        notify(src, 'Šis žaidėjas jau įkaitų situacijoje.', 'error')
        return
    end

    activeAggressor[src] = targetId
    activeVictim[targetId] = src

    TriggerClientEvent('fivempro_ikaitas:client:beAggressor', src, targetId)
    TriggerClientEvent('fivempro_ikaitas:client:beVictim', targetId, src)
    notify(src, 'Įkaitas paimtas. G — paleisti, H — nusauti.', 'success')
    notify(targetId, 'Tave laiko įkaitu. Nusigink.', 'error')
end)

RegisterNetEvent('fivempro_ikaitas:server:release', function()
    local src = source
    local victim = activeAggressor[src]
    if not victim then return end
    clearHostage(src, victim, 'release')
    notify(src, 'Įkaitas paleistas.', 'primary')
    notify(victim, 'Tave paleido.', 'success')
end)

RegisterNetEvent('fivempro_ikaitas:server:kill', function()
    local src = source
    local victim = activeAggressor[src]
    if not victim then return end
    TriggerClientEvent('fivempro_ikaitas:client:executeVictim', victim)
    TriggerClientEvent('fivempro_ikaitas:client:stop', src, 'kill')
    TriggerClientEvent('fivempro_ikaitas:client:stop', victim, 'kill')
    activeAggressor[src] = nil
    activeVictim[victim] = nil
    notify(src, 'Įkaitas nusaustas.', 'error')
end)

RegisterNetEvent('fivempro_ikaitas:server:abort', function()
    local src = source
    local asAgg = activeAggressor[src]
    local asVic = activeVictim[src]
    if asAgg then
        clearHostage(src, asAgg, 'abort')
    elseif asVic then
        clearHostage(asVic, src, 'abort')
    end
end)

AddEventHandler('playerDropped', function()
    local src = source
    local victim = activeAggressor[src]
    local aggressor = activeVictim[src]
    if victim then
        clearHostage(src, victim, 'disconnect')
    elseif aggressor then
        clearHostage(aggressor, src, 'disconnect')
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for agg, vic in pairs(activeAggressor) do
        clearHostage(agg, vic, 'stop')
    end
end)
