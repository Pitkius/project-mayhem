-- Player join / leave / connecting logs

AddEventHandler('playerConnecting', function(name, _setKickReason, deferrals)
    local src = source
    deferrals.defer()
    Wait(0)
    deferrals.update(('Sveiki, %s. Tikrinama...'):format(name))
    Wait(0)

    SendLog('join_leave', 'Player Connecting', ('**%s** jungiasi...'):format(name), {
        { name = 'Name', value = name, inline = true },
    }, src)

    deferrals.done()
end)

AddEventHandler('playerJoining', function()
    local src = source
    SendLog('join_leave', 'Player Joined', ('**%s** prisijunge.'):format(GetPlayerName(src) or 'Unknown'), {
        { name = 'Ping', value = tostring(GetPlayerPing(src) or 0), inline = true },
        Identifiers.GetCoordsField(src),
    }, src)
end)

AddEventHandler('playerDropped', function(reason)
    local src = source
    SendLog('join_leave', 'Player Dropped', ('**%s** atsijunge.'):format(GetPlayerName(src) or 'Unknown'), {
        { name = 'Reason', value = reason or 'Unknown', inline = false },
        { name = 'Ping', value = tostring(GetPlayerPing(src) or 0), inline = true },
        Identifiers.GetCoordsField(src),
    }, src)
end)

-- Chat logs (default chat resource)
AddEventHandler('chatMessage', function(src, name, message)
    if not src or src <= 0 then return end

    if Config.BlockDiscordInvites and message:lower():find('discord%.gg') then
        SendLog('security', 'Discord Invite Blocked', message, nil, src)
        CancelEvent()
        return
    end

    for _, word in ipairs(Config.BannedWords or {}) do
        if message:lower():find(word:lower(), 1, true) then
            SendLog('security', 'Banned Word', ('Word: `%s`\nMessage: %s'):format(word, message), nil, src)
            break
        end
    end

    SendLog('chat', 'Chat Message', message, {
        { name = 'Name', value = name or GetPlayerName(src), inline = true },
    }, src)
end)

-- /me /do style (example - hook your chat resource)
RegisterNetEvent('server_logs:chatMe', function(text)
    SendLog('chat', '/me', text, nil, source)
end)

RegisterNetEvent('server_logs:chatDo', function(text)
    SendLog('chat', '/do', text, nil, source)
end)

RegisterNetEvent('server_logs:chatOoc', function(text)
    SendLog('chat', '/ooc', text, nil, source)
end)

RegisterNetEvent('server_logs:adminChat', function(text)
    SendLog('admin', 'Admin Chat', text, nil, source)
end)

RegisterNetEvent('server_logs:reportChat', function(text)
    SendLog('chat', 'Report', text, nil, source)
end)
