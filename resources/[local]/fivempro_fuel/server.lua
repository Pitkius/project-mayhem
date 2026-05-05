local QBCore = exports['qb-core']:GetCoreObject()

RegisterNetEvent('fivempro_fuel:server:payTick', function(pricePerLiter)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then
        TriggerClientEvent('fivempro_fuel:client:payResult', src, { ok = false })
        return
    end
    local price = tonumber(pricePerLiter) or 7
    price = math.max(1, price)
    local bank = Player.PlayerData.money and Player.PlayerData.money.bank or 0
    local cash = Player.PlayerData.money and Player.PlayerData.money.cash or 0
    if cash >= price then
        Player.Functions.RemoveMoney('cash', price, 'fuel-pump')
        TriggerClientEvent('fivempro_fuel:client:payResult', src, { ok = true })
        return
    end
    if bank >= price then
        Player.Functions.RemoveMoney('bank', price, 'fuel-pump')
        TriggerClientEvent('fivempro_fuel:client:payResult', src, { ok = true })
        return
    end
    TriggerClientEvent('fivempro_fuel:client:payResult', src, { ok = false })
end)

