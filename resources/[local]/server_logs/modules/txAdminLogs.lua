-- txAdmin meniu / konsolės / ban-kick ir kt. veiksmai → Discord kanalas `tx_admin`

local function txFields(eventData, extra)
    local fields = extra or {}
    if type(eventData) ~= 'table' then return fields end
    if eventData.author then
        fields[#fields + 1] = { name = 'Adminas (txAdmin)', value = tostring(eventData.author), inline = true }
    end
    if eventData.targetNetId then
        fields[#fields + 1] = { name = 'Tikslas (netId)', value = tostring(eventData.targetNetId), inline = true }
    elseif eventData.target and eventData.target ~= -1 then
        fields[#fields + 1] = { name = 'Tikslas (ID)', value = tostring(eventData.target), inline = true }
    end
    if eventData.targetName then
        fields[#fields + 1] = { name = 'Žaidėjas', value = tostring(eventData.targetName), inline = true }
    end
    if eventData.reason then
        fields[#fields + 1] = { name = 'Priežastis', value = tostring(eventData.reason):sub(1, 1024), inline = false }
    end
    if eventData.message then
        fields[#fields + 1] = { name = 'Žinutė', value = tostring(eventData.message):sub(1, 1024), inline = false }
    end
    if eventData.command then
        fields[#fields + 1] = { name = 'Komanda', value = ('`%s`'):format(tostring(eventData.command):sub(1, 900)), inline = false }
    end
    if eventData.expiration ~= nil then
        local exp = eventData.expiration
        fields[#fields + 1] = {
            name = 'Galiojimas',
            value = exp == false and 'Visam laikui' or os.date('%Y-%m-%d %H:%M', exp),
            inline = true,
        }
    end
    if eventData.actionId then
        fields[#fields + 1] = { name = 'Action ID', value = tostring(eventData.actionId), inline = true }
    end
    return fields
end

local function logTx(title, description, eventData, extra)
    SendLog('tx_admin', title, description or '', txFields(eventData, extra), nil)
end

AddEventHandler('txAdmin:events:consoleCommand', function(eventData)
    logTx('txAdmin konsolė', eventData and eventData.command or '—', eventData)
end)

AddEventHandler('txAdmin:events:playerHealed', function(eventData)
    local target = eventData and eventData.target
    local desc = target == -1 and 'Visas serveris pagydytas' or ('Žaidėjas ID **%s**'):format(target or '?')
    logTx('txAdmin Heal / Revive', desc, eventData)
end)

AddEventHandler('txAdmin:events:healedPlayer', function(eventData)
    local target = eventData and (eventData.target or eventData.id)
    local desc = target == -1 and 'Visas serveris pagydytas' or ('Žaidėjas ID **%s**'):format(target or '?')
    logTx('txAdmin Heal (legacy)', desc, eventData)
end)

AddEventHandler('txAdmin:events:playerBanned', function(eventData)
    logTx('txAdmin Ban', eventData and eventData.targetName or 'Ban', eventData)
end)

AddEventHandler('txAdmin:events:playerKicked', function(eventData)
    logTx('txAdmin Kick', eventData and (eventData.dropMessage or eventData.reason) or 'Kick', eventData)
end)

AddEventHandler('txAdmin:events:playerWarned', function(eventData)
    logTx('txAdmin Warn', eventData and eventData.targetName or 'Warn', eventData)
end)

AddEventHandler('txAdmin:events:playerDirectMessage', function(eventData)
    logTx('txAdmin DM žaidėjui', eventData and eventData.message or '', eventData)
end)

AddEventHandler('txAdmin:events:announcement', function(eventData)
    logTx('txAdmin Announcement', eventData and eventData.message or '', eventData)
end)

AddEventHandler('txAdmin:events:adminAuth', function(eventData)
    if not eventData or not eventData.isAdmin then return end
    local name = eventData.username or ('ID %s'):format(eventData.netid or '?')
    logTx('txAdmin prisijungė', ('**%s** autentifikuotas in-game meniu'):format(name), eventData, {
        { name = 'NetID', value = tostring(eventData.netid or '?'), inline = true },
    })
end)

AddEventHandler('txAdmin:events:actionRevoked', function(eventData)
    logTx('txAdmin veiksmas atšauktas', eventData and eventData.actionType or 'revoke', eventData, {
        { name = 'Atšaukė', value = tostring(eventData and eventData.revokedBy or '?'), inline = true },
    })
end)

AddEventHandler('txAdmin:events:serverShuttingDown', function(eventData)
    logTx('txAdmin serverio stop', eventData and eventData.message or 'Shutdown', eventData)
end)

AddEventHandler('txAdmin:events:scheduledRestart', function(eventData)
    local sec = eventData and eventData.secondsRemaining
    logTx('txAdmin restart artėja', sec and ('Liko **%s s**'):format(sec) or 'Restart', eventData)
end)

AddEventHandler('txAdmin:events:scheduledRestartSkipped', function(eventData)
    logTx('txAdmin restart praleistas', '', eventData)
end)
