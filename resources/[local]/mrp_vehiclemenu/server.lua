local QBCore = exports['qb-core']:GetCoreObject()

QBCore.Functions.CreateUseableItem('vehicle_key_copy', function(source)
    TriggerClientEvent('mrp_vehiclemenu:client:grantKeysNearest', source)
end)
