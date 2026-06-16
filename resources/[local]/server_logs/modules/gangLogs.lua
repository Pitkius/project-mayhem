RegisterNetEvent('server_logs:gangCreate', function(gangName)
    SendLog('gang', 'Gang Created', gangName or '?', nil, source)
end)

RegisterNetEvent('server_logs:gangDelete', function(gangName)
    SendLog('gang', 'Gang Deleted', gangName or '?', nil, source)
end)

RegisterNetEvent('server_logs:gangInvite', function(targetId, gangName)
    SendLog('gang', 'Gang Invite', ('%s → %s'):format(targetId or '?', gangName or '?'), nil, source)
end)

RegisterNetEvent('server_logs:gangKick', function(targetId, gangName)
    SendLog('gang', 'Gang Kick', ('%s from %s'):format(targetId or '?', gangName or '?'), nil, source)
end)

RegisterNetEvent('server_logs:gangRankChange', function(targetId, gangName, rank)
    SendLog('gang', 'Gang Rank', ('%s — %s rank %s'):format(targetId or '?', gangName or '?', rank or '?'), nil, source)
end)

RegisterNetEvent('server_logs:gangStash', function(gangName, action, item, amount)
    SendLog('gang', 'Gang Stash', ('%s %s `%s` x%s'):format(gangName or '?', action or '?', item or '?', amount or 1), nil, source)
end)

RegisterNetEvent('server_logs:gangMoney', function(gangName, action, amount)
    SendLog('gang', 'Gang Money', ('%s %s $%s'):format(gangName or '?', action or '?', amount or 0), nil, source)
end)

RegisterNetEvent('server_logs:gangWar', function(gang1, gang2, status)
    SendLog('gang', 'Gang War', ('%s vs %s — %s'):format(gang1 or '?', gang2 or '?', status or '?'), nil, source)
end)

RegisterNetEvent('server_logs:gangMission', function(gangName, mission, status)
    SendLog('gang', 'Gang Mission', ('%s — %s (%s)'):format(gangName or '?', mission or '?', status or '?'), nil, source)
end)
