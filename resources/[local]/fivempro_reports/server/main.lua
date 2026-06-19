local QBCore = exports['qb-core']:GetCoreObject()

local cfg = Config.Reports or {}
local reports = {}
local nextReportId = 1
local reportCooldown = {}

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
    for _, perm in ipairs(cfg.StaffPerms or {}) do
        if QBCore.Functions.HasPermission(src, perm) then
            return true
        end
    end
    return false
end

local function sanitizeText(text, maxLen)
    text = tostring(text or ''):gsub('[~<].-[>~]', ''):gsub('\r\n', '\n'):gsub('^%s+', ''):gsub('%s+$', '')
    if maxLen and #text > maxLen then
        text = text:sub(1, maxLen)
    end
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
    local maxStored = tonumber(cfg.MaxStoredReports) or 120
    while #reports > maxStored do
        table.remove(reports, 1)
    end
end

local function categoryById(id)
    for _, row in ipairs(cfg.Categories or {}) do
        if row.id == id then return row end
    end
end

local function logReportToDiscord(title, report, extraFields, staffSrc)
    if GetResourceState('server_logs') ~= 'started' then return end
    pcall(function()
        exports['server_logs']:LogReportEvent(title, report, extraFields, staffSrc)
    end)
end

local function notifyStaffNewReport(report)
    local header = ('[#%s] %s — %s'):format(report.id, report.title or 'Report', report.name)
    for _, playerId in ipairs(QBCore.Functions.GetPlayers()) do
        if isStaff(playerId) then
            TriggerClientEvent('QBCore:Notify', playerId, ('Naujas report: %s'):format(header), 'error', 12000)
            TriggerClientEvent('fivempro_reports:client:staffAlert', playerId, report.id)
            TriggerClientEvent('fivempro_reports:client:refreshAdmin', playerId)
        end
    end
end

local function serializeReport(report, viewerSrc, forStaff)
    local cat = categoryById(report.category)
    local online = QBCore.Functions.GetPlayer(report.source) ~= nil
  return {
        id = report.id,
        source = report.source,
        name = report.name,
        citizenid = report.citizenid,
        category = report.category,
        categoryLabel = cat and cat.label or report.category,
        categoryIcon = cat and cat.icon or 'other',
        categoryColor = cat and cat.color or '#a78bfa',
        title = report.title,
        message = report.message,
        attachments = report.attachments or {},
        priority = report.priority,
        priorityLabel = (cfg.PriorityLabels or {})[report.priority] or report.priority,
        status = report.status,
        statusLabel = (cfg.StatusLabels or {})[report.status] or report.status,
        createdAt = report.createdAt,
        updatedAt = report.updatedAt,
        closedAt = report.closedAt,
        handledByName = report.handledByName,
        closedByName = report.closedByName,
        replies = report.replies or {},
        playerOnline = online,
        canManage = forStaff and isStaff(viewerSrc) or false,
        isOwner = report.citizenid and QBCore.Functions.GetPlayer(viewerSrc)
            and QBCore.Functions.GetPlayer(viewerSrc).PlayerData.citizenid == report.citizenid,
    }
end

local function validateAttachments(list)
    local out = {}
    if type(list) ~= 'table' then return out end
    local max = tonumber(cfg.MaxAttachments) or 5
    for i = 1, math.min(#list, max) do
        local row = list[i]
        if type(row) == 'table' then
            local typ = tostring(row.type or 'link'):lower()
            local url = sanitizeText(row.url, 512)
            if url ~= '' and (#url >= 8) and (url:find('^https?://') or url:find('^www%.') or typ == 'image') then
                if url:find('^www%.') then url = 'https://' .. url end
                out[#out + 1] = { type = typ, url = url, label = sanitizeText(row.label, 64) }
            end
        end
    end
    return out
end

local function createReport(source, payload)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return false, 'Žaidėjas nerastas.' end

    payload = payload or {}
    local categoryId = tostring(payload.category or '')
    local cat = categoryById(categoryId)
    if not cat then return false, 'Pasirinkite kategoriją.' end

    local title = sanitizeText(payload.title, cfg.TitleMaxLen or 80)
    local message = sanitizeText(payload.message, cfg.MessageMaxLen or 1200)
    if #title < (cfg.TitleMinLen or 4) then
        return false, ('Pavadinimas per trumpas (min. %s simboliai).'):format(cfg.TitleMinLen or 4)
    end
    if #message < (cfg.MessageMinLen or 10) then
        return false, ('Aprašymas per trumpas (min. %s simboliai).'):format(cfg.MessageMinLen or 10)
    end

    local now = os.time()
    local cd = tonumber(cfg.CooldownSeconds) or 90
    if reportCooldown[source] and (now - reportCooldown[source]) < cd then
        return false, ('Palauk %s s. prieš kitą reportą.'):format(cd - (now - reportCooldown[source]))
    end

    local attachments = validateAttachments(payload.attachments)
    local priority = cat.priority or 'medium'

    local report = {
        id = nextReportId,
        source = source,
        name = playerDisplayName(source, Player),
        citizenid = Player.PlayerData.citizenid,
        category = categoryId,
        title = title,
        message = message,
        attachments = attachments,
        priority = priority,
        coords = getPlayerCoords(source),
        createdAt = now,
        updatedAt = now,
        status = 'waiting',
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
        { name = 'Kategorija', value = cat.label or categoryId, inline = true },
        { name = 'Pavadinimas', value = title, inline = true },
        { name = 'Prioritetas', value = (cfg.PriorityLabels or {})[priority] or priority, inline = true },
        { name = 'Būsena', value = 'Laukiama', inline = true },
    }, source)

    return true, report
end

local function getReportsForPlayer(source)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return {} end
    local cid = Player.PlayerData.citizenid
    local out = {}
    for _, report in ipairs(reports) do
        if report.citizenid == cid then
            out[#out + 1] = serializeReport(report, source, false)
        end
    end
    table.sort(out, function(a, b) return (a.id or 0) > (b.id or 0) end)
    return out
end

local function getReportsForStaff(source)
    if not isStaff(source) then return nil end
    local out = {}
    for _, report in ipairs(reports) do
        out[#out + 1] = serializeReport(report, source, true)
    end
    table.sort(out, function(a, b) return (a.id or 0) > (b.id or 0) end)
    return out
end

local function setReportStatus(source, reportId, status)
    if not isStaff(source) then return false, 'Neturi teisių.' end
    local report = findReport(reportId)
    if not report then return false, 'Reportas nerastas.' end

    local allowed = { waiting = true, in_progress = true, resolved = true, rejected = true }
    if not allowed[status] then return false, 'Neteisinga būsena.' end

    report.status = status
    report.updatedAt = os.time()
    if not report.handledBy and status == 'in_progress' then
        report.handledBy = source
        report.handledByName = GetPlayerName(source) or ('Staff %s'):format(source)
    end
    if status == 'resolved' or status == 'rejected' then
        report.closedBy = source
        report.closedByName = GetPlayerName(source) or ('Staff %s'):format(source)
        report.closedAt = os.time()
    end

    local target = QBCore.Functions.GetPlayer(report.source)
    if target then
        local label = (cfg.StatusLabels or {})[status] or status
        TriggerClientEvent('QBCore:Notify', report.source, ('Report #%s: %s'):format(report.id, label), 'primary', 10000)
        TriggerClientEvent('fivempro_reports:client:refreshPlayer', report.source)
    end

    for _, playerId in ipairs(QBCore.Functions.GetPlayers()) do
        if isStaff(playerId) then
            TriggerClientEvent('fivempro_reports:client:refreshAdmin', playerId)
        end
    end

    logReportToDiscord(('📋 Report #%s — %s'):format(report.id, (cfg.StatusLabels or {})[status] or status), report, {
        { name = 'Staff', value = GetPlayerName(source) or tostring(source), inline = true },
        { name = 'Būsena', value = (cfg.StatusLabels or {})[status] or status, inline = true },
    }, source)

    return true
end

local function replyToReport(source, reportId, text)
    if not isStaff(source) then return false, 'Neturi teisių.' end
    local report = findReport(reportId)
    if not report then return false, 'Reportas nerastas.' end

    text = sanitizeText(text, 600)
    if text == '' then return false, 'Tuščias atsakymas.' end

    local staffName = GetPlayerName(source) or ('Staff %s'):format(source)
    if not report.handledBy then
        report.handledBy = source
        report.handledByName = staffName
    end
    if report.status == 'waiting' then
        report.status = 'in_progress'
    end
    report.updatedAt = os.time()
    report.replies[#report.replies + 1] = {
        staffId = source,
        staffName = staffName,
        text = text,
        at = os.time(),
    }

    local targetPlayer = QBCore.Functions.GetPlayer(report.source)
    if targetPlayer then
        TriggerClientEvent('QBCore:Notify', report.source, ('Admin (#%s): %s'):format(report.id, text), 'primary', 12000)
        TriggerClientEvent('fivempro_reports:client:refreshPlayer', report.source)
    end

    for _, playerId in ipairs(QBCore.Functions.GetPlayers()) do
        if isStaff(playerId) then
            TriggerClientEvent('fivempro_reports:client:refreshAdmin', playerId)
        end
    end

    logReportToDiscord(('💬 Report #%s — atsakymas'):format(report.id), report, {
        { name = 'Adminas', value = staffName, inline = true },
        { name = 'Atsakymas', value = text:sub(1, 1024), inline = false },
    }, source)

    return true
end

QBCore.Functions.CreateCallback('fivempro_reports:server:getBootstrap', function(source, cb)
    cb({
        categories = cfg.Categories or {},
        priorityLabels = cfg.PriorityLabels or {},
        statusLabels = cfg.StatusLabels or {},
        isStaff = isStaff(source),
        myReports = getReportsForPlayer(source),
        adminReports = getReportsForStaff(source),
    })
end)

QBCore.Functions.CreateCallback('fivempro_reports:server:submit', function(source, cb, payload)
    local ok, result = createReport(source, payload)
    if not ok then
        cb({ ok = false, error = result })
        return
    end
    cb({ ok = true, report = serializeReport(result, source, false) })
end)

QBCore.Functions.CreateCallback('fivempro_reports:server:myReports', function(source, cb)
    cb(getReportsForPlayer(source))
end)

QBCore.Functions.CreateCallback('fivempro_reports:server:adminReports', function(source, cb)
    if not isStaff(source) then cb(nil) return end
    cb(getReportsForStaff(source))
end)

QBCore.Functions.CreateCallback('fivempro_reports:server:setStatus', function(source, cb, reportId, status)
    local ok, err = setReportStatus(source, reportId, status)
    cb({ ok = ok, error = err })
end)

QBCore.Functions.CreateCallback('fivempro_reports:server:reply', function(source, cb, reportId, text)
    local ok, err = replyToReport(source, reportId, text)
    cb({ ok = ok, error = err })
end)

QBCore.Commands.Add('report', 'Atidaryti pagalbos centrą / reportą', {}, false, function(source)
    TriggerClientEvent('fivempro_reports:client:open', source, 'create')
end, 'user')

QBCore.Commands.Add('myreports', 'Mano reportai', {}, false, function(source)
    TriggerClientEvent('fivempro_reports:client:open', source, 'mine')
end, 'user')

QBCore.Commands.Add('reports', 'Admin reportų panelė', {}, false, function(source)
    if not isStaff(source) then
        TriggerClientEvent('QBCore:Notify', source, 'Neturi staff teisių.', 'error')
        return
    end
    TriggerClientEvent('fivempro_reports:client:open', source, 'admin')
end, 'mod')

QBCore.Commands.Add('reportai', 'Admin reportų panelė', {}, false, function(source)
    if not isStaff(source) then
        TriggerClientEvent('QBCore:Notify', source, 'Neturi staff teisių.', 'error')
        return
    end
    TriggerClientEvent('fivempro_reports:client:open', source, 'admin')
end, 'mod')

QBCore.Commands.Add('atsakyti', 'Atsakyti į reportą (staff)', {
    { name = 'id', help = 'Report #' },
    { name = 'žinutė', help = 'Atsakymas' },
}, false, function(source, args)
    if #args < 2 then
        TriggerClientEvent('QBCore:Notify', source, 'Naudojimas: /atsakyti [id] [žinutė]', 'error')
        return
    end
    local ok, err = replyToReport(source, args[1], table.concat(args, ' ', 2))
    TriggerClientEvent('QBCore:Notify', source, ok and 'Atsakymas išsiųstas.' or (err or 'Klaida'), ok and 'success' or 'error')
end, 'mod')

QBCore.Commands.Add('closereport', 'Uždaryti reportą kaip išspręstą', {
    { name = 'id', help = 'Report #' },
}, false, function(source, args)
    local ok, err = setReportStatus(source, args[1], 'resolved')
    TriggerClientEvent('QBCore:Notify', source, ok and 'Reportas uždarytas.' or (err or 'Klaida'), ok and 'success' or 'error')
end, 'mod')

AddEventHandler('playerDropped', function()
    reportCooldown[source] = nil
end)

-- Suderinamumas su server_logs (message laukas)
AddEventHandler('fivempro_reports:internal:logCompat', function() end)

exports('GetOpenReportCount', function()
    local n = 0
    for _, r in ipairs(reports) do
        if r.status == 'waiting' or r.status == 'in_progress' then n = n + 1 end
    end
    return n
end)
