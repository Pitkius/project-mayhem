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

local function tzOffsetSeconds()
    return (tonumber(Config.TimezoneOffsetHours) or 0) * 3600
end

--- Planinis laikas: offset 0 = OS laikas, kitaip UTC + offset (pvz. 3 = LT ant UTC VPS).
local function wallClockNow()
    local offset = tzOffsetSeconds()
    if offset == 0 then
        return os.date('*t', os.time())
    end
    return os.date('!*t', os.time() + offset)
end

local function wallClockToUnix(year, month, day, hour, min, sec)
    local offset = tzOffsetSeconds()
    local tbl = {
        year = year,
        month = month,
        day = day,
        hour = hour,
        min = min or 0,
        sec = sec or 0,
    }
    if offset == 0 then
        return os.time(tbl)
    end
    return os.time(tbl) - offset
end

local function nextRestartUnix()
    local now = os.time()
    local restartMin = tonumber(Config.RestartAtMinute) or 0
    local hours = Config.RestartHours or { 0, 4, 8, 12, 16, 20 }
    local t = wallClockNow()
    local best = nil

    for dayOffset = 0, 1 do
        for _, hour in ipairs(hours) do
            local target = wallClockToUnix(t.year, t.month, t.day + dayOffset, hour, restartMin, 0)
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

local function formatRestartLabel(unix)
    local offset = tzOffsetSeconds()
    if offset == 0 then
        return os.date('%H:%M', unix)
    end
    return os.date('!%H:%M', unix + offset)
end

local function resetWarningsIfNewCycle()
    local id = nextRestartUnix()
    if id ~= cycleId then
        cycleId = id
        warned = {}
    end
end

local function shutdownServer(reason)
    reason = tostring(reason or Config.QuitReason or 'Planned restart')
    print(('^1[mrp_autorestart]^0 Stabdome serverį: %s'):format(reason))

    -- Pirmas bandymas (su priežastimi)
    ExecuteCommand(('quit "%s"'):format(reason:gsub('"', '')))

    -- Antras bandymas (be argumentų — kai kur ACE blokuoja su tekstu)
    SetTimeout(2000, function()
        ExecuteCommand('quit')
    end)

    -- Paskutinis bandymas
    SetTimeout(5000, function()
        ExecuteCommand('quit')
    end)
end

local function scheduleRestartLockReset()
    SetTimeout(tonumber(Config.RestartLockResetMs) or 60000, function()
        if not restartLock then return end
        restartLock = false
        warned = {}
        print('^1[mrp_autorestart]^0 Quit nepavyko — bandysime vėl kitame cikle. Patikrink txAdmin Auto Start ir ACE (command.quit).')
    end)
end

local function performRestart()
    if restartLock then return end
    restartLock = true

    local msg = Config.Messages.imminent or 'Serveris restartuojamas…'
    broadcastChat(msg, { 255, 90, 90 })
    broadcastNotify(msg, 'error', 12000)

    local kickDelay = tonumber(Config.KickDelayMs or Config.QuitDelayMs) or 4000

    SetTimeout(kickDelay, function()
        for _, pid in ipairs(GetPlayers()) do
            local id = tonumber(pid)
            if id then
                DropPlayer(id, Config.KickMessage or 'Planinis restartas.')
            end
        end

        SetTimeout(1500, function()
            shutdownServer(Config.QuitReason)
            scheduleRestartLockReset()
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
    local nextAt = formatRestartLabel(nextRestartUnix())
    print(('^2[mrp_autorestart]^0 Planinis restartas — %s (kitas: %s, TZ offset %+d h)'):format(
        table.concat(labels, ', '),
        nextAt,
        tonumber(Config.TimezoneOffsetHours) or 0
    ))
    print('^2[mrp_autorestart]^0 Perspėjimai likus: ' .. table.concat(Config.WarningMinutes or {}, ', ') .. ' min.')

    while true do
        Wait(Config.CheckIntervalMs or 15000)
        resetWarningsIfNewCycle()

        local secsLeft = secondsUntilRestart()
        local minsLeft = secsLeft / 60.0
        local warnWindow = (tonumber(Config.CheckIntervalMs) or 15000) / 60000.0 + 0.35

        for _, warnMin in ipairs(Config.WarningMinutes or {}) do
            local key = tostring(warnMin)
            if not warned[key] and minsLeft <= warnMin and minsLeft > (warnMin - warnWindow) then
                warned[key] = true
                local text = (Config.Messages.warning or 'Restart po %s min.'):format(warnMin)
                broadcastChat(text)
                broadcastNotify(text, 'error', 10000)
                print(('^3[mrp_autorestart]^0 %s'):format(text))
            end
        end

        local triggerSec = tonumber(Config.RestartTriggerSeconds) or 8
        if not restartLock and secsLeft <= triggerSec then
            performRestart()
        end
    end
end)

AddEventHandler('onResourceStart', function(res)
    if res ~= GetCurrentResourceName() then return end
    restartLock = false
    warned = {}
    cycleId = nil
end)
