RegisterNetEvent('server_logs:warehouseCreate', function(warehouseId)
    SendLog('warehouse', 'Warehouse Created', ('ID: `%s`'):format(warehouseId or '?'), nil, source)
end)

RegisterNetEvent('server_logs:warehouseDelete', function(warehouseId)
    SendLog('warehouse', 'Warehouse Deleted', ('ID: `%s`'):format(warehouseId or '?'), nil, source)
end)

RegisterNetEvent('server_logs:warehouseDeposit', function(warehouseId, item, amount)
    SendLog('warehouse', 'Warehouse Deposit', ('`%s` — `%s` x%s'):format(warehouseId or '?', item or '?', amount or 1), nil, source)
end)

RegisterNetEvent('server_logs:warehouseWithdraw', function(warehouseId, item, amount)
    SendLog('warehouse', 'Warehouse Withdraw', ('`%s` — `%s` x%s'):format(warehouseId or '?', item or '?', amount or 1), nil, source)
end)

RegisterNetEvent('server_logs:stashOpen', function(stashId, stashType)
    SendLog('warehouse', 'Stash Opened', ('`%s` (%s)'):format(stashId or '?', stashType or 'unknown'), nil, source)
end)

RegisterNetEvent('server_logs:houseStash', function(houseId, action, item, amount)
    SendLog('warehouse', 'House Stash', ('House %s — %s `%s` x%s'):format(houseId or '?', action or '?', item or '?', amount or 1), nil, source)
end)
