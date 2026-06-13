local QBCore = exports['qb-core']:GetCoreObject()

local function nearStash(src, maxDist)
    local cfg = Config.PublicStash
    if not cfg or not cfg.coords then return false end
    maxDist = tonumber(maxDist) or cfg.maxDistance or 3.0
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end
    local p = GetEntityCoords(ped)
    return #(p - cfg.coords) <= maxDist
end

RegisterNetEvent('fivempro_motel:server:openPublicStash', function()
    local src = source
    if GetResourceState('qb-inventory') ~= 'started' then
        return TriggerClientEvent('QBCore:Notify', src, 'qb-inventory neįjungtas.', 'error')
    end
    if Player(src).state.inv_busy then
        return TriggerClientEvent('QBCore:Notify', src, 'Uždaryk inventorių ir bandyk dar kartą.', 'error')
    end
    if not nearStash(src) then
        return TriggerClientEvent('QBCore:Notify', src, 'Per toli nuo sandėlio.', 'error')
    end

    local P = QBCore.Functions.GetPlayer(src)
    if not P or not P.PlayerData or not P.PlayerData.citizenid then return end

    local citizenid = tostring(P.PlayerData.citizenid)
    local cfg = Config.PublicStash
    local stashId = ('motel_public_%s'):format(citizenid)

    exports['qb-inventory']:OpenInventory(src, stashId, {
        label = cfg.label or 'Motelio sandėlis',
        maxweight = cfg.maxweight or 200000,
        slots = cfg.slots or 30,
    })
end)
