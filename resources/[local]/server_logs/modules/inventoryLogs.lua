RegisterNetEvent('server_logs:inventoryAdd', function(item, amount, reason)
    SendLog('inventory', 'Item Added', ('`%s` x%s'):format(item or '?', amount or 1), {
        { name = 'Reason', value = reason or 'N/A', inline = true },
    }, source)
    TriggerEvent('server_logs:securityCheck', 'item_add', { item = item, amount = amount })
end)

RegisterNetEvent('server_logs:inventoryRemove', function(item, amount, reason)
    SendLog('inventory', 'Item Removed', ('`%s` x%s'):format(item or '?', amount or 1), {
        { name = 'Reason', value = reason or 'N/A', inline = true },
    }, source)
end)

RegisterNetEvent('server_logs:inventoryUse', function(item, amount)
    SendLog('inventory', 'Item Used', ('`%s` x%s'):format(item or '?', amount or 1), nil, source)
end)

RegisterNetEvent('server_logs:inventoryDrop', function(item, amount)
    SendLog('inventory', 'Item Dropped', ('`%s` x%s'):format(item or '?', amount or 1), nil, source)
end)

RegisterNetEvent('server_logs:inventoryPickup', function(item, amount)
    SendLog('inventory', 'Item Picked Up', ('`%s` x%s'):format(item or '?', amount or 1), nil, source)
end)

RegisterNetEvent('server_logs:inventoryTransfer', function(targetId, item, amount)
    SendLog('inventory', 'Item Transfer', ('To %s — `%s` x%s'):format(targetId or '?', item or '?', amount or 1), nil, source)
end)

RegisterNetEvent('server_logs:stashDeposit', function(stashId, item, amount)
    SendLog('warehouse', 'Stash Deposit', ('`%s` — `%s` x%s'):format(stashId or '?', item or '?', amount or 1), nil, source)
end)

RegisterNetEvent('server_logs:stashWithdraw', function(stashId, item, amount)
    SendLog('warehouse', 'Stash Withdraw', ('`%s` — `%s` x%s'):format(stashId or '?', item or '?', amount or 1), nil, source)
end)

RegisterNetEvent('server_logs:trunkLog', function(plate, action, item, amount)
    SendLog('vehicle', 'Trunk Log', ('`%s` %s `%s` x%s'):format(plate or '?', action or '?', item or '?', amount or 1), nil, source)
end)

RegisterNetEvent('server_logs:gloveboxLog', function(plate, action, item, amount)
    SendLog('vehicle', 'Glovebox Log', ('`%s` %s `%s` x%s'):format(plate or '?', action or '?', item or '?', amount or 1), nil, source)
end)
