DiscordLog = DiscordLog or {}

local queue = {}
local lastSend = 0
local sendCount = 0

local function resetRateWindow()
    local now = GetGameTimer()
    if now - lastSend >= 1000 then
        sendCount = 0
        lastSend = now
    end
end

local function canSend()
    resetRateWindow()
    return sendCount < (Config.RateLimitPerSecond or 4)
end

local function buildEmbed(logType, title, description, fields, source)
    local color = (Config.Colors and Config.Colors[logType]) or Config.DefaultColor
    local embed = {
        title = title or 'Server Log',
        description = description or '',
        color = color,
        timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ'),
        footer = { text = Config.ServerName or 'FiveM Server' },
        fields = fields or {},
    }

    local playerId = tonumber(source)
    if playerId and playerId > 0 then
        local name = GetPlayerName(playerId) or 'Unknown'
        table.insert(embed.fields, 1, { name = 'Player', value = ('%s [%s]'):format(name, playerId), inline = true })
        if Identifiers and Identifiers.GetFormatted then
            table.insert(embed.fields, {
                name = 'Identifiers',
                value = Identifiers.GetFormatted(playerId):sub(1, 1024),
                inline = false,
            })
        end
    end

    return embed
end

function DiscordLog.Enqueue(logType, title, description, fields, source)
    local webhook = Config.Webhooks and Config.Webhooks[logType]
    if not webhook or webhook == '' then return end

    queue[#queue + 1] = {
        webhook = webhook,
        payload = json.encode({
            username = Config.ServerName or 'Server Logs',
            embeds = { buildEmbed(logType, title, description, fields, source) },
        }),
    }
end

function DiscordLog.Send(logType, title, description, fields, source)
    DiscordLog.Enqueue(logType, title, description, fields, source)
end

CreateThread(function()
    while true do
        Wait(Config.QueueProcessInterval or 250)
        if #queue == 0 then goto continue end
        if not canSend() then goto continue end

        local item = table.remove(queue, 1)
        sendCount = sendCount + 1

        PerformHttpRequest(item.webhook, function() end, 'POST', item.payload, {
            ['Content-Type'] = 'application/json',
        })

        ::continue::
    end
end)

-- Eksportuojama visiems moduliams
function SendLog(logType, title, description, fields, source)
    DiscordLog.Send(logType, title, description, fields, source)
end

function SendCustomLog(logType, title, message, source, extraFields)
    SendLog(logType, title, message, extraFields, source)
end

exports('SendLog', SendLog)
exports('SendCustomLog', SendCustomLog)

RegisterNetEvent('server_logs:sendLog', function(logType, title, message, source, fields)
    SendLog(logType, title, message, fields, source)
end)
