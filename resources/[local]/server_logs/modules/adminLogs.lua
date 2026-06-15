-- Admin command / action logs

local function logAdmin(source, command, details)
    SendLog('admin', 'Admin Command', ('`/%s` — %s'):format(command, details or ''), {
        { name = 'Command', value = command, inline = true },
        Identifiers.GetCoordsField(source),
    }, source)
end

RegisterNetEvent('server_logs:adminCommand', function(command, details)
    logAdmin(source, command, details)
end)

-- Generic hook - call from your admin menu via events (see README)
-- Do NOT register duplicate commands here; use server_logs:adminCommand event

RegisterNetEvent('server_logs:adminDuty', function(onDuty)
    SendLog('admin', 'Admin Duty', onDuty and 'ON' or 'OFF', nil, source)
end)

RegisterNetEvent('server_logs:adminTeleport', function(targetId, coords)
    SendLog('admin', 'Admin Teleport', ('Target: %s'):format(targetId or 'self'), {
        { name = 'Coords', value = coords or Identifiers.GetCoords(source), inline = false },
    }, source)
end)

RegisterNetEvent('server_logs:adminSpawnVehicle', function(model, plate)
    SendLog('admin', 'Admin Vehicle Spawn', ('Model: `%s` Plate: `%s`'):format(model or '?', plate or '?'), nil, source)
end)

RegisterNetEvent('server_logs:adminRevive', function(targetId)
    SendLog('admin', 'Admin Revive', ('Target: %s'):format(targetId or source), nil, source)
end)

RegisterNetEvent('server_logs:adminHeal', function(targetId)
    SendLog('admin', 'Admin Heal', ('Target: %s'):format(targetId or source), nil, source)
end)

RegisterNetEvent('server_logs:adminAnnounce', function(text)
    SendLog('admin', 'Announce', text, nil, source)
end)
