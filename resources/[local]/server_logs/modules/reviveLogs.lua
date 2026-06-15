RegisterNetEvent('server_logs:revive', function(data)
    data = data or {}
    local victim = data.victim or source
    local reviver = data.reviver or source
    local reviveType = data.type or 'unknown'

    SendLog('revive', 'Player Revived', ('Type: **%s**'):format(reviveType), {
        { name = 'Victim', value = ('%s [%s]'):format(GetPlayerName(victim) or '?', victim), inline = true },
        { name = 'Reviver', value = ('%s [%s]'):format(GetPlayerName(reviver) or '?', reviver), inline = true },
        Identifiers.GetCoordsField(victim),
    }, reviver)
end)

RegisterNetEvent('server_logs:selfRevive', function()
    SendLog('security', 'Suspicious Self Revive', 'Self revive detected', nil, source)
    TriggerEvent('server_logs:revive', { victim = source, reviver = source, type = 'self' })
end)
