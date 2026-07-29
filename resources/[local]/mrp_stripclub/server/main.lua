local QBCore = exports['qb-core']:GetCoreObject()

local occupiedSeats = {}

local function seatKey(seatId)
    return tostring(seatId)
end

QBCore.Functions.CreateCallback('mrp_stripclub:server:tryPay', function(src, cb, payType, seatId)
    local price = 0
    if payType == 'lap' then
        price = tonumber(Config.Prices.lapDance) or 120
        local key = seatKey(seatId)
        if occupiedSeats[key] then
            return cb({ ok = false, msg = 'Ši vieta užimta.' })
        end
    elseif payType == 'throw' then
        price = tonumber(Config.Prices.throwCash) or 40
    elseif payType == 'tip' then
        price = tonumber(Config.Prices.tipDancer) or 25
    else
        return cb({ ok = false, msg = 'Netinkamas mokėjimas.' })
    end

    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return cb({ ok = false, msg = 'Klaida.' }) end

    local cash = Player.PlayerData.money and Player.PlayerData.money.cash or 0
    if cash < price then
        return cb({ ok = false, msg = ('Reikia $%s grynaisiais.'):format(price) })
    end

    Player.Functions.RemoveMoney('cash', price, 'stripclub-' .. tostring(payType))
    if payType == 'lap' then
        occupiedSeats[seatKey(seatId)] = src
    end
    cb({ ok = true, price = price })
end)

RegisterNetEvent('mrp_stripclub:server:releaseSeat', function(seatId)
    local key = seatKey(seatId)
    if occupiedSeats[key] == source then
        occupiedSeats[key] = nil
    end
end)

AddEventHandler('playerDropped', function()
    local src = source
    for k, v in pairs(occupiedSeats) do
        if v == src then occupiedSeats[k] = nil end
    end
end)
