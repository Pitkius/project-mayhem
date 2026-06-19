local QBCore = exports['qb-core']:GetCoreObject()

local reports = {}
local nextReportId = 1
local reportCooldown = {}

local REPORT_COOLDOWN_SEC = 90
local REPORT_MIN_LEN = 5
local REPORT_MAX_LEN = 480
local MAX_STORED_REPORTS = 80
local STAFF_PERMS = { 'mod', 'admin', 'god' }

local function playerDisplayName(src, Player)
    if Player and Player.PlayerData and Player.PlayerData.charinfo then
        local c = Player.PlayerData.charinfo
        local full = ('%s %s'):format(c.firstname or '', c.lastname or '')
        full = full:gsub('^%s+', ''):gsub('%s+$', '')
        if full ~= '' then return full end
    end
    return GetPlayerName(src) or ('Žaidėjas %s'):format(src)
end

local function isStaff(src)
    for _, perm in ipairs(STAFF_PERMS) do
        if QBCore.Functions.HasPermission(src, perm) then
            return true
        end
    end
    return false
end

local function sanitizeText(text)
    text = tostring(text or ''):gsub('[~<].-[>~]', ''):gsub('%s+', ' '):gsub('^%s+', ''):gsub('%s+$', '')
    return text
end

local function getPlayerCoords(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    local c = GetEntityCoords(ped)
    return { x = c.x, y = c.y, z = c.z }
end

local function findReport(reportId)
    reportId = tonumber(reportId)
    if not reportId then return nil end
    for _, report in ipairs(reports) do
        if report.id == reportId then
            return report
        end
    end
end

local function trimOldReports()
    while #reports > MAX_STORED_REPORTS do
        table.remove(reports, 1)
    end
end

local function logReportToDiscord(title, report, extraFields, staffSrc)
    if GetResourceState('server_logs') ~= 'started' then return end
    pcall(function()
        exports['server_logs']:LogReportEvent(title, report, extraFields, staffSrc)
    end)
end

local function notifyStaffNewReport(report)
    local header = ('[#%s] %s (ID %s)'):format(report.id, report.name, report.source)
    local body = report.message
    for _, playerId in ipairs(QBCore.Functions.GetPlayers()) do
        if isStaff(playerId) then
            TriggerClientEvent('QBCore:Notify', playerId, ('Naujas report: %s'):format(header), 'error', 12000)
            TriggerClientEvent('chat:addMessage', playerId, {
                color = { 255, 90, 90 },
                multiline = true,
                args = { 'REPORT', ('%s\n%s'):format(header, body) },
            })
            TriggerClientEvent('fivempro_basics:client:staffReportAlert', playerId, report.id)
        end
    end
end

local function createReport(source, message)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return false, 'Žaidėjas nerastas.' end

    message = sanitizeText(message)
    if #message < REPORT_MIN_LEN then
        return false, ('Žinutė per trumpa (min. %s simboliai).'):format(REPORT_MIN_LEN)
    end
    if #message > REPORT_MAX_LEN then
        return false, ('Žinutė per ilga (max. %s simbolių).'):format(REPORT_MAX_LEN)
    end

    local now = os.time()
    if reportCooldown[source] and (now - reportCooldown[source]) < REPORT_COOLDOWN_SEC then
        local wait = REPORT_COOLDOWN_SEC - (now - reportCooldown[source])
        return false, ('Palauk %s s. prieš kitą reportą.'):format(wait)
    end

    local report = {
        id = nextReportId,
        source = source,
        name = playerDisplayName(source, Player),
        citizenid = Player.PlayerData.citizenid,
        message = message,
        coords = getPlayerCoords(source),
        createdAt = now,
        status = 'open',
        closedBy = nil,
        closedByName = nil,
        closedAt = nil,
        handledBy = nil,
        handledByName = nil,
        replies = {},
    }
    nextReportId = nextReportId + 1
    reports[#reports + 1] = report
    trimOldReports()
    reportCooldown[source] = now

    notifyStaffNewReport(report)
    logReportToDiscord('📩 Naujas report', report, {
        { name = 'Būsena', value = 'Atviras', inline = true },
    }, report.source)

    return true, report
end

local function listOpenReports(source)
    if not isStaff(source) then
        TriggerClientEvent('QBCore:Notify', source, 'Neturi staff teisių.', 'error')
        return
    end

    local openCount = 0
    for _, report in ipairs(reports) do
        if report.status == 'open' then
            openCount = openCount + 1
            local online = QBCore.Functions.GetPlayer(report.source) and 'online' or 'offline'
            TriggerClientEvent('chat:addMessage', source, {
                color = { 255, 180, 80 },
                multiline = true,
                args = {
                    ('REPORT #%s'):format(report.id),
                    ('%s · ID %s · %s\n%s'):format(report.name, report.source, online, report.message),
                },
            })
        end
    end

    if openCount == 0 then
        TriggerClientEvent('QBCore:Notify', source, 'Atvirų reportų nėra.', 'primary')
        return
    end
    TriggerClientEvent('QBCore:Notify', source, ('Rasta %s atvirų reportų (žiūrėk chat).'):format(openCount), 'primary')
end

local function replyToReport(source, args)
    if not isStaff(source) then
        TriggerClientEvent('QBCore:Notify', source, 'Neturi staff teisių.', 'error')
        return
    end
    if #args < 2 then
        TriggerClientEvent('QBCore:Notify', source, 'Naudojimas: /atsakyti [report id] [žinutė]', 'error')
        return
    end

    local report = findReport(args[1])
    if not report then
        TriggerClientEvent('QBCore:Notify', source, 'Reportas nerastas.', 'error')
        return
    end

    local reply = sanitizeText(table.concat(args, ' ', 2))
    if reply == '' then
        TriggerClientEvent('QBCore:Notify', source, 'Tuščias atsakymas.', 'error')
        return
    end

    local staffName = GetPlayerName(source) or ('Staff %s'):format(source)
    if not report.handledBy then
        report.handledBy = source
        report.handledByName = staffName
    end
    report.replies[#report.replies + 1] = {
        staffId = source,
        staffName = staffName,
        text = reply,
        at = os.time(),
    }

    local targetPlayer = QBCore.Functions.GetPlayer(report.source)
    if targetPlayer then
        TriggerClientEvent('QBCore:Notify', report.source, ('Admin atsakymas (#%s): %s'):format(report.id, reply), 'primary', 12000)
        TriggerClientEvent('chat:addMessage', report.source, {
            color = { 100, 200, 255 },
            multiline = true,
            args = { ('REPORT #%s'):format(report.id), ('%s: %s'):format(staffName, reply) },
        })
        TriggerClientEvent('QBCore:Notify', source, ('Atsakymas į #%s išsiųstas.'):format(report.id), 'success')
    else
        TriggerClientEvent('QBCore:Notify', source, 'Žaidėjas neprisijungęs — Discord logas išsaugotas.', 'primary')
    end

    logReportToDiscord(('💬 Report #%s — admin atsakė'):format(report.id), report, {
        { name = 'Adminas', value = ('%s [ID %s]'):format(staffName, source), inline = true },
        { name = 'Atsakymas', value = reply:sub(1, 1024), inline = false },
        { name = 'Būsena', value = 'Atviras', inline = true },
    }, source)
end

QBCore.Commands.Add('report', 'Pranešti adminams apie problemą / žaidėją', {
    { name = 'žinutė', help = 'Kas nutiko? Kuo detaliau, tuo geriau.' },
}, false, function(source, args)
    if #args < 1 then
        TriggerClientEvent('QBCore:Notify', source, 'Naudojimas: /report tekstas', 'error')
        return
    end

    local ok, result = createReport(source, table.concat(args, ' '))
    if not ok then
        TriggerClientEvent('QBCore:Notify', source, result or 'Nepavyko išsiųsti.', 'error')
        return
    end

    TriggerClientEvent('QBCore:Notify', source, ('Report #%s išsiųstas adminams. Atsakysime kuo greičiau.'):format(result.id), 'success', 8000)
end, 'user')

QBCore.Commands.Add('reports', 'Peržiūrėti atvirus reportus (staff)', {}, false, function(source)
    listOpenReports(source)
end, 'mod')

QBCore.Commands.Add('reportai', 'Alias /reports — atviri reportai', {}, false, function(source)
    listOpenReports(source)
end, 'mod')

QBCore.Commands.Add('atsakyti', 'Atsakyti žaidėjui į reportą (staff)', {
    { name = 'id', help = 'Report numeris (#)' },
    { name = 'žinutė', help = 'Atsakymas žaidėjui' },
}, false, function(source, args)
    replyToReport(source, args)
end, 'mod')

QBCore.Commands.Add('reportreply', 'Alias /atsakyti — atsakyti į reportą', {
    { name = 'id', help = 'Report numeris' },
    { name = 'žinutė', help = 'Atsakymas' },
}, false, function(source, args)
    replyToReport(source, args)
end, 'mod')

QBCore.Commands.Add('closereport', 'Uždaryti reportą (staff)', {
    { name = 'id', help = 'Report numeris' },
}, false, function(source, args)
    if not isStaff(source) then
        TriggerClientEvent('QBCore:Notify', source, 'Neturi staff teisių.', 'error')
        return
    end

    local report = findReport(args[1])
    if not report then
        TriggerClientEvent('QBCore:Notify', source, 'Reportas nerastas.', 'error')
        return
    end

    report.status = 'closed'
    report.closedBy = source
    report.closedByName = GetPlayerName(source) or ('Staff %s'):format(source)
    report.closedAt = os.time()

    local replySummary = '—'
    if report.replies and #report.replies > 0 then
        local parts = {}
        for _, row in ipairs(report.replies) do
            parts[#parts + 1] = ('%s: %s'):format(row.staffName or '?', row.text or '')
        end
        replySummary = table.concat(parts, '\n'):sub(1, 1024)
    end

    logReportToDiscord(('✅ Report #%s — uždarytas'):format(report.id), report, {
        { name = 'Uždarė', value = ('%s [ID %s]'):format(report.closedByName, source), inline = true },
        { name = 'Sureagavo', value = report.handledByName or '—', inline = true },
        { name = 'Būsena', value = 'Uždarytas / išspręstas', inline = true },
        { name = 'Admin atsakymai', value = replySummary, inline = false },
    }, source)

    TriggerClientEvent('QBCore:Notify', source, ('Report #%s uždarytas.'):format(report.id), 'success')
end, 'mod')

AddEventHandler('playerDropped', function()
    reportCooldown[source] = nil
end)
