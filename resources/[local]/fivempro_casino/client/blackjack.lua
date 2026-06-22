local QBCore = exports['qb-core']:GetCoreObject()

local activeSession = false

local function resultText(res)
    if res.result == 'blackjack' then
        return ('Blackjack! Laimėjote %s žetonų'):format(res.payout or 0)
    elseif res.result == 'win' then
        return ('Laimėjote %s žetonų'):format(res.payout or 0)
    elseif res.result == 'push' then
        return 'Lygiosios — statymas grąžintas.'
    elseif res.result == 'bust' then
        return 'Permušėte — pralaimėjote.'
    end
    return 'Pralaimėjote.'
end

local function openActionMenu()
    local menu = {
        {
            header = 'Blackjack',
            isMenuHeader = true,
        },
        {
            header = 'Hit',
            txt = 'Imti kortą',
            params = { event = 'fivempro_casino:client:bjAction', args = { action = 'hit' } },
        },
        {
            header = 'Stand',
            txt = 'Sustoti',
            params = { event = 'fivempro_casino:client:bjAction', args = { action = 'stand' } },
        },
        {
            header = 'Double',
            txt = 'Dvigubinti statymą',
            params = { event = 'fivempro_casino:client:bjAction', args = { action = 'double' } },
        },
    }
    exports['qb-menu']:openMenu(menu)
end

RegisterNetEvent('fivempro_casino:client:bjAction', function(data)
    if not activeSession then return end
    QBCore.Functions.TriggerCallback('fivempro_casino:server:blackjackAction', function(res)
        if not res or not res.ok then
            QBCore.Functions.Notify(res and res.msg or 'Klaida.', 'error')
            activeSession = false
            return
        end

        QBCore.Functions.Notify(('Jūs: %s (%s) | Dalintojas: %s'):format(
            res.playerHand or '?', res.playerValue or '?', res.dealerHand or '?'
        ), 'primary')

        if res.finished then
            activeSession = false
            QBCore.Functions.Notify(resultText(res), res.payout and res.payout > 0 and 'success' or 'error')
            return
        end

        openActionMenu()
    end, data.action)
end)

RegisterNetEvent('fivempro_casino:client:openBlackjack', function(_tableId)
    if activeSession then
        QBCore.Functions.Notify('Jau žaidžiate blackjack.', 'error')
        return
    end
    if not Casino.canUseCasino() then return end

    local bet = Casino.promptBet('Blackjack statymas')
    if not bet then return end

    QBCore.Functions.TriggerCallback('fivempro_casino:server:startBlackjack', function(res)
        if not res or not res.ok then
            QBCore.Functions.Notify(res and res.msg or 'Nepavyko pradėti.', 'error')
            return
        end

        QBCore.Functions.Notify(('Jūs: %s (%s) | Dalintojas: %s'):format(
            res.playerHand or '?', res.playerValue or '?', res.dealerHand or '?'
        ), 'primary')

        if res.finished then
            QBCore.Functions.Notify(resultText(res), res.payout and res.payout > 0 and 'success' or 'error')
            return
        end

        activeSession = true
        openActionMenu()
    end, bet)
end)
