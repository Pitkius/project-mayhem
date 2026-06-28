RegisterNetEvent('server_logs:moneyAdd', function(account, amount, reason, balanceBefore, balanceAfter)
    SendLog('money', 'Money Added', ('+%s %s'):format(amount or 0, account or 'cash'), {
        { name = 'Reason', value = reason or 'N/A', inline = true },
        { name = 'Before', value = tostring(balanceBefore or '?'), inline = true },
        { name = 'After', value = tostring(balanceAfter or '?'), inline = true },
    }, source)

    local threshold = Config.Security and Config.Security.suspiciousMoneyThreshold or 500000
    if (amount or 0) >= threshold then
        TriggerEvent('server_logs:securityCheck', 'suspicious_money', { amount = amount, account = account, source = source })
    end
end)

RegisterNetEvent('server_logs:moneyRemove', function(account, amount, reason)
    SendLog('money', 'Money Removed', ('-%s %s'):format(amount or 0, account or 'cash'), {
        { name = 'Reason', value = reason or 'N/A', inline = true },
    }, source)
end)

RegisterNetEvent('server_logs:dirtyMoney', function(action, amount)
    SendLog('money', 'Dirty Money', ('%s $%s'):format(action or 'change', amount or 0), nil, source)
end)

RegisterNetEvent('server_logs:societyMoney', function(society, action, amount)
    SendLog('money', 'Society Money', ('**%s** %s $%s'):format(society or '?', action or '?', amount or 0), nil, source)
end)
