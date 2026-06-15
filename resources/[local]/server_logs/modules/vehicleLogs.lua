RegisterNetEvent('server_logs:vehicleSpawn', function(model, plate)
    SendLog('vehicle', 'Vehicle Spawned', ('`%s` plate `%s`'):format(model or '?', plate or '?'), nil, source)
    TriggerEvent('server_logs:securityCheck', 'vehicle_spawn', { model = model })
end)

RegisterNetEvent('server_logs:vehicleDelete', function(plate, reason)
    SendLog('vehicle', 'Vehicle Deleted', ('Plate `%s` — %s'):format(plate or '?', reason or '?'), nil, source)
end)

RegisterNetEvent('server_logs:vehicleBuy', function(model, plate, price)
    SendLog('vehicle', 'Vehicle Bought', ('`%s` `%s` — $%s'):format(model or '?', plate or '?', price or 0), nil, source)
end)

RegisterNetEvent('server_logs:vehicleSell', function(plate, price)
    SendLog('vehicle', 'Vehicle Sold', ('`%s` — $%s'):format(plate or '?', price or 0), nil, source)
end)

RegisterNetEvent('server_logs:vehicleTransfer', function(targetId, plate)
    SendLog('vehicle', 'Vehicle Transfer', ('To %s — `%s`'):format(targetId or '?', plate or '?'), nil, source)
end)

RegisterNetEvent('server_logs:plateChange', function(oldPlate, newPlate)
    SendLog('vehicle', 'Plate Changed', ('`%s` → `%s`'):format(oldPlate or '?', newPlate or '?'), nil, source)
end)

RegisterNetEvent('server_logs:garageStore', function(plate, garage)
    SendLog('vehicle', 'Garage Store', ('`%s` → %s'):format(plate or '?', garage or '?'), nil, source)
end)

RegisterNetEvent('server_logs:garageRetrieve', function(plate, garage)
    SendLog('vehicle', 'Garage Retrieve', ('`%s` ← %s'):format(plate or '?', garage or '?'), nil, source)
end)

RegisterNetEvent('server_logs:impound', function(plate, reason)
    SendLog('vehicle', 'Impound', ('`%s` — %s'):format(plate or '?', reason or '?'), nil, source)
end)
