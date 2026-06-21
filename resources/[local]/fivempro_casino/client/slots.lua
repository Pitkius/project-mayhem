local QBCore = exports['qb-core']:GetCoreObject()

RegisterNetEvent('fivempro_casino:client:openSlots', function(_machineId)
    if not Casino.canUseCasino() then return end

    local bet = Casino.promptBet('Lošimo automato statymas')
    if not bet then return end

    QBCore.Functions.TriggerCallback('fivempro_casino:server:playSlots', function(res)
        if not res or not res.ok then
            QBCore.Functions.Notify(res and res.msg or 'Klaida.', 'error')
            return
        end

        local reels = table.concat(res.reels or {}, ' | ')
        if res.won then
            QBCore.Functions.Notify(('%s  →  x%s  →  $%s'):format(reels, res.multiplier or 0, res.payout or 0), 'success')
        else
            QBCore.Functions.Notify(('%s  →  nieko'):format(reels), 'error')
        end
    end, bet)
end)
