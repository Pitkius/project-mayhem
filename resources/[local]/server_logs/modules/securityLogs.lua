local lastPositions = {}

-- Security / anti-cheat style logs (warning only)

AddEventHandler('server_logs:securityCheck', function(checkType, data)
    data = data or {}
    local src = source
    if src and src > 0 then
        if checkType == 'weapon_spawn' or checkType == 'item_spawn' then
            local list = checkType == 'weapon_spawn' and Config.Security.blacklistedWeapons or Config.Security.blacklistedItems
            local key = data.weapon or data.item
            for _, banned in ipairs(list or {}) do
                if key == banned then
                    SendLog('security', 'Blacklisted Spawn', ('Type: %s\nKey: `%s`'):format(checkType, key), nil, src)
                    return
                end
            end
        end
        if checkType == 'vehicle_spawn' then
            for _, banned in ipairs(Config.Security.blacklistedVehicles or {}) do
                if data.model == banned then
                    SendLog('security', 'Blacklisted Vehicle', ('Model: `%s`'):format(data.model), nil, src)
                    return
                end
            end
        end
        if checkType == 'suspicious_money' then
            SendLog('security', 'Suspicious Money Gain', ('$%s in %s'):format(data.amount or 0, data.account or 'cash'), nil, src)
        end
    end
end)

RegisterNetEvent('server_logs:securityAlert', function(alertType, message)
    SendLog('security', alertType or 'Security Alert', message or 'No details', nil, source)
end)

RegisterNetEvent('server_logs:unauthorizedCommand', function(command)
    SendLog('security', 'Unauthorized Command', ('`%s`'):format(command or '?'), nil, source)
end)

RegisterNetEvent('server_logs:unauthorizedEvent', function(eventName)
    SendLog('security', 'Unauthorized Event', ('`%s`'):format(eventName or '?'), nil, source)
end)

RegisterNetEvent('server_logs:eventSpam', function(eventName, count)
    SendLog('security', 'Event Spam', ('`%s` x%s'):format(eventName or '?', count or 0), nil, source)
end)

RegisterNetEvent('server_logs:explosionSpam', function(count)
    SendLog('security', 'Explosion Spam', ('Count: %s'):format(count or 0), nil, source)
end)

RegisterNetEvent('server_logs:entitySpam', function(count)
    SendLog('security', 'Entity Spam', ('Count: %s'):format(count or 0), nil, source)
end)

-- Speed / teleport checks (client reports position)
RegisterNetEvent('server_logs:positionUpdate', function(coords)
    local src = source
    if not coords then return end

    local prev = lastPositions[src]
    lastPositions[src] = coords

    if not prev then return end

    local dx = coords.x - prev.x
    local dy = coords.y - prev.y
    local dz = coords.z - prev.z
    local dist = math.sqrt(dx * dx + dy * dy + dz * dz)

    -- ~100m per 2s tick = suspicious teleport
    if dist > 100.0 then
        SendLog('security', 'Impossible Teleport', ('Distance: %.1fm'):format(dist), {
            Identifiers.GetCoordsField(src),
        }, src)
    end
end)

RegisterNetEvent('server_logs:speedAlert', function(speedKmh)
    local max = Config.Security and Config.Security.maxSpeedKmh or 350
    if (speedKmh or 0) > max then
        SendLog('security', 'High Speed', ('%.0f km/h'):format(speedKmh), nil, source)
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then return end
    -- Log only if triggered suspiciously from client event in your AC layer
end)
