--[[
  Daily crate: dashboard claims item into inventory;
  opening happens via inventory useable (random loot, no weapons).
]]

local QBCore = exports['qb-core']:GetCoreObject()

--- Placeholder loot table (no weapons). Server will expand later.
local LOOT_POOL = {
    { item = 'water_bottle', amount = 5, weight = 40 },
    { item = 'coffee', amount = 3, weight = 35 },
    { item = 'lockpick', amount = 2, weight = 25 },
    { item = 'repairkit', amount = 1, weight = 20 },
    { item = 'radio', amount = 1, weight = 12 },
    { item = 'firstaid', amount = 2, weight = 18 },
}

local function pickLoot()
    local total = 0
    for _, e in ipairs(LOOT_POOL) do
        total = total + (e.weight or 1)
    end
    local roll = math.random(1, math.max(total, 1))
    local acc = 0
    for _, e in ipairs(LOOT_POOL) do
        acc = acc + (e.weight or 1)
        if roll <= acc then
            return e
        end
    end
    return LOOT_POOL[1]
end

-- NUI claim → give dienos_deze (playtime / once-per-day checks later)
RegisterNetEvent('mrp_dashboard:server:claimDailyCrate', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local ok = Player.Functions.AddItem('dienos_deze', 1)
    if ok then
        TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items['dienos_deze'], 'add')
        TriggerClientEvent('QBCore:Notify', src, 'Gavai Dienos dėžę. Atidaryk ją inventoriuje.', 'success')
    else
        TriggerClientEvent('QBCore:Notify', src, 'Inventorius pilnas.', 'error')
    end
end)

QBCore.Functions.CreateUseableItem('dienos_deze', function(source, item)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return end

    local slot = item and item.slot
    if not Player.Functions.RemoveItem('dienos_deze', 1, slot) then
        return
    end
    TriggerClientEvent('inventory:client:ItemBox', source, QBCore.Shared.Items['dienos_deze'], 'remove')

    local drop = pickLoot()
    if drop and QBCore.Shared.Items[drop.item] then
        Player.Functions.AddItem(drop.item, drop.amount or 1)
        TriggerClientEvent('inventory:client:ItemBox', source, QBCore.Shared.Items[drop.item], 'add')
        local label = QBCore.Shared.Items[drop.item].label or drop.item
        TriggerClientEvent(
            'QBCore:Notify',
            source,
            ('Dienos dėžė: gavai %sx %s'):format(drop.amount or 1, label),
            'success'
        )
    else
        TriggerClientEvent('QBCore:Notify', source, 'Dėžė tuščia (loot stub).', 'error')
    end
end)

print('^2[mrp_dashboard]^7 daily crate (dienos_deze) ready')
