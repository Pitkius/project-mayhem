RegisterNetEvent('server_logs:jobSet', function(job, grade, playerId)
    local src = (playerId and playerId > 0) and playerId or source
    SendLog('job', 'Job Set', ('**%s** grade %s'):format(job or '?', grade or 0), nil, src)
end)

RegisterNetEvent('server_logs:jobGradeChange', function(job, oldGrade, newGrade)
    SendLog('job', 'Job Grade Change', ('%s: %s → %s'):format(job or '?', oldGrade or '?', newGrade or '?'), nil, source)
end)

RegisterNetEvent('server_logs:bossAction', function(action, details)
    SendLog('job', 'Boss Menu', ('%s — %s'):format(action or '?', details or ''), nil, source)
end)

RegisterNetEvent('server_logs:dutyToggle', function(job, onDuty)
    SendLog('job', 'Duty Toggle', ('%s — %s'):format(job or '?', onDuty and 'ON' or 'OFF'), nil, source)
end)

RegisterNetEvent('server_logs:policeJail', function(targetId, time, reason)
    SendLog('job', 'Police Jail', ('Target %s — %s min'):format(targetId or '?', time or 0), {
        { name = 'Reason', value = reason or 'N/A' },
    }, source)
end)

RegisterNetEvent('server_logs:emsHeal', function(targetId)
    SendLog('job', 'EMS Heal', ('Target %s'):format(targetId or '?'), nil, source)
end)

RegisterNetEvent('server_logs:mechanicRepair', function(plate, cost)
    SendLog('job', 'Mechanic Repair', ('Plate `%s` — $%s'):format(plate or '?', cost or 0), nil, source)
end)

RegisterNetEvent('server_logs:jobMission', function(job, mission, status, reward)
    SendLog('mission', 'Job Mission', ('**%s** / %s — %s'):format(job or '?', mission or '?', status or '?'), {
        { name = 'Reward', value = tostring(reward or 'N/A'), inline = true },
    }, source)
end)
