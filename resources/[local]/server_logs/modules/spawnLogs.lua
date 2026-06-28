RegisterNetEvent('server_logs:spawn', function(data)
    data = data or {}
    SendLog('spawn', 'Player Spawn', data.details or 'Spawned', {
        { name = 'Type', value = data.spawnType or 'player', inline = true },
        Identifiers.GetCoordsField(source),
    }, source)
end)

RegisterNetEvent('server_logs:itemSpawn', function(item, amount)
    SendLog('spawn', 'Item Spawn', ('`%s` x%s'):format(item or '?', amount or 1), nil, source)
    TriggerEvent('server_logs:securityCheck', 'item_spawn', { item = item, amount = amount, source = source })
end)

RegisterNetEvent('server_logs:weaponSpawn', function(weapon, amount)
    SendLog('spawn', 'Weapon Spawn', ('`%s` x%s'):format(weapon or '?', amount or 1), nil, source)
    TriggerEvent('server_logs:securityCheck', 'weapon_spawn', { weapon = weapon, source = source })
end)

RegisterNetEvent('server_logs:moneySpawn', function(amount, account)
    SendLog('spawn', 'Money Spawn', ('%s — %s'):format(amount or 0, account or 'cash'), nil, source)
end)

RegisterNetEvent('server_logs:entityCreated', function(model, entityType)
    SendLog('spawn', 'Entity Created', ('Model: `%s` Type: %s'):format(model or '?', entityType or '?'), nil, source)
end)
