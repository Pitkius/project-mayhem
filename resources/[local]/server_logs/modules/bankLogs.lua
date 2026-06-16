RegisterNetEvent('server_logs:bankDeposit', function(amount, balanceBefore, balanceAfter)
    SendLog('bank', 'Bank Deposit', ('**$%s**'):format(amount or 0), {
        { name = 'Before', value = tostring(balanceBefore or '?'), inline = true },
        { name = 'After', value = tostring(balanceAfter or '?'), inline = true },
    }, source)
end)

RegisterNetEvent('server_logs:bankWithdraw', function(amount, balanceBefore, balanceAfter)
    SendLog('bank', 'Bank Withdraw', ('**$%s**'):format(amount or 0), {
        { name = 'Before', value = tostring(balanceBefore or '?'), inline = true },
        { name = 'After', value = tostring(balanceAfter or '?'), inline = true },
    }, source)
end)

RegisterNetEvent('server_logs:bankTransfer', function(targetId, amount)
    SendLog('bank', 'Bank Transfer', ('To **%s** — $%s'):format(targetId or '?', amount or 0), nil, source)
end)
