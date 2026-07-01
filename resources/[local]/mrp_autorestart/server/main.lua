local restartLock = false
local warned = {}
local cycleId = nil

local function broadcastChat(msg, color)
    color = color or { 255, 180, 60 }
    TriggerClientEvent('chat:addMessage', -1, {
        color = color,
        multiline = true,
        args = { 'SERVERIS', msg },
    })
end

local function broadcastNotify(msg, nType, duration)
    TriggerClientEvent('QBCore:Notify', -1, msg, nType or 'primary', duration or 8000)
end

local function nextRestartUnix()
    local now = os.time()
    local restartMin = Config.RestartAtMinute or 0
    local hours = Config.RestartHours or { 0, 4, 8, 12, 16, 20 }
    local t = os.date('*t', now)
    local best = nil

    for dayOffset = 0, 1 do
        for _, hour in ipairs(hours) do
            local target = os.time({
                year = t.year,
                month = t.month,
                day = t.day + dayOffset,
                hour = hour,
                min = restartMin,
                sec = 0,
            })
            if target > now and (not best or target < best) then
                best = target
            end
        end
    end

    return best or (now + (4 * 3600))
end

local function secondsUntilRestart()
    return nextRestartUnix() - os.time()
end

local function resetWarningsIfNewCycle()
    local id = nextRestartUnix()
    if id ~= cycleId then
        cycleId = id
        warned = {}
    end
end

local function performRestart()
    if restartLock then return end
    restartLock = true

    local msg = Config.Messages.imminent or 'Serveris restartuojamas…'
    broadcastChat(msg, { 255, 90, 90 })
    broadcastNotify(msg, 'error', 12000)

    SetTimeout(Config.KickDelayMs or Config.QuitDelayMs or 4000, function()
        for _, pid in ipairs(GetPlayers()) do
            local id = tonumber(pid)
            if id then
                DropPlayer(id, Config.KickMessage or 'Planinis restartas.')
            end
        end

        SetTimeout(1500, function()
            print('^3[mrp_autorestart]^0 Planinis restartas — quit')
            ExecuteCommand(('quit "%s"'):format(Config.QuitReason or 'Planned restart'))
        end)
    end)
end

CreateThread(function()
    Wait(5000)
    local hours = Config.RestartHours or { 0, 4, 8, 12, 16, 20 }
    local labels = {}
    for _, h in ipairs(hours) do
        labels[#labels + 1] = string.format('%02d:%02d', h, Config.RestartAtMinute or 0)
    end
    print('^2[mrp_autorestart]^0 Planinis restartas kas 4 val. — '
        .. table.concat(labels, ', ')
        .. ' | perspėjimai likus: '
        .. table.concat(Config.WarningMinutes or {}, ', ')
        .. ' min.')

    while true do
        Wait(Config.CheckIntervalMs or 15000)
        resetWarningsIfNewCycle()

        local secsLeft = secondsUntilRestart()
        local minsLeft = secsLeft / 60.0

        for _, warnMin in ipairs(Config.WarningMinutes or {}) do
            local key = tostring(warnMin)
            if not warned[key] and minsLeft <= warnMin and minsLeft > (warnMin - 0.6) then
                warned[key] = true
                local text = (Config.Messages.warning or 'Restart po %s min.'):format(warnMin)
                broadcastChat(text)
                broadcastNotify(text, 'error', 10000)
                print(('^3[mrp_autorestart]^0 %s'):format(text))
            end
        end

        if not restartLock and secsLeft <= 5 then
            performRestart()
        end
    end
end)

AddEventHandler('onResourceStart', function(res)
    if res ~= GetCurrentResourceName() then return end
    restartLock = false
end)
