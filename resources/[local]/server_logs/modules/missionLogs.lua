RegisterNetEvent('server_logs:missionStart', function(missionType, details)
    SendLog('mission', 'Mission Started', ('**%s** — %s'):format(missionType or '?', details or ''), {
        Identifiers.GetCoordsField(source),
    }, source)
end)

RegisterNetEvent('server_logs:missionComplete', function(missionType, rewardMoney, rewardItems)
    SendLog('mission', 'Mission Completed', missionType or '?', {
        { name = 'Money', value = tostring(rewardMoney or 0), inline = true },
        { name = 'Items', value = rewardItems or 'N/A', inline = true },
    }, source)
end)

RegisterNetEvent('server_logs:missionFailed', function(missionType, reason)
    SendLog('mission', 'Mission Failed', ('%s — %s'):format(missionType or '?', reason or '?'), nil, source)
end)

RegisterNetEvent('server_logs:missionAbuse', function(missionType, reason)
    SendLog('security', 'Mission Abuse', ('%s — %s'):format(missionType or '?', reason or '?'), nil, source)
end)
