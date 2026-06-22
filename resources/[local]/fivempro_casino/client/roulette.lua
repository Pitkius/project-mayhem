local QBCore = exports['qb-core']:GetCoreObject()

local function colorLabel(color)
    if color == 'red' then return 'Raudona' end
    if color == 'black' then return 'Juoda' end
    return 'Žalia (0)'
end

RegisterNetEvent('fivempro_casino:client:openRoulette', function(_tableId)
    if not Casino.canUseCasino() then return end

    local bet = Casino.promptBet('Ruletės statymas')
    if not bet then return end

    local menu = {
        { header = 'Ruletė — pasirinkite statymą', isMenuHeader = true },
        { header = 'Raudona (x2)', params = { event = 'fivempro_casino:client:rouletteBet', args = { bet = bet, betType = 'red' } } },
        { header = 'Juoda (x2)', params = { event = 'fivempro_casino:client:rouletteBet', args = { bet = bet, betType = 'black' } } },
        { header = 'Nelyginis (x2)', params = { event = 'fivempro_casino:client:rouletteBet', args = { bet = bet, betType = 'odd' } } },
        { header = 'Lyginis (x2)', params = { event = 'fivempro_casino:client:rouletteBet', args = { bet = bet, betType = 'even' } } },
        { header = '1-18 (x2)', params = { event = 'fivempro_casino:client:rouletteBet', args = { bet = bet, betType = 'low' } } },
        { header = '19-36 (x2)', params = { event = 'fivempro_casino:client:rouletteBet', args = { bet = bet, betType = 'high' } } },
        { header = 'Skaičius 0-36 (x36)', params = { event = 'fivempro_casino:client:rouletteNumber', args = { bet = bet } } },
    }
    exports['qb-menu']:openMenu(menu)
end)

RegisterNetEvent('fivempro_casino:client:rouletteNumber', function(data)
    if GetResourceState('qb-input') ~= 'started' then return end
    local r = exports['qb-input']:ShowInput({
        header = 'Ruletė — skaičius',
        submitText = 'Statyti',
        inputs = { { text = 'Skaičius 0-36', name = 'num', type = 'number', isRequired = true } },
    })
    if not r or not r.num then return end
    TriggerEvent('fivempro_casino:client:rouletteBet', { bet = data.bet, betType = 'number', betValue = tonumber(r.num) })
end)

RegisterNetEvent('fivempro_casino:client:rouletteBet', function(data)
    QBCore.Functions.TriggerCallback('fivempro_casino:server:playRoulette', function(res)
        if not res or not res.ok then
            QBCore.Functions.Notify(res and res.msg or 'Klaida.', 'error')
            return
        end

        local msg = ('Iškrito %s (%s)'):format(res.result, colorLabel(res.color))
        if res.won then
            msg = msg .. (' — laimėjote %s žetonų!'):format(res.payout or 0)
            QBCore.Functions.Notify(msg, 'success')
        else
            msg = msg .. ' — pralaimėjote.'
            QBCore.Functions.Notify(msg, 'error')
        end
    end, data.bet, data.betType, data.betValue)
end)
