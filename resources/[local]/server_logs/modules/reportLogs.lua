-- Reportų logai → `reports` kanalas (kviečiama iš mrp_basics)

function LogReportEvent(title, report, extraFields, staffSrc)
    if type(report) ~= 'table' then return end

    local fields = {
        { name = 'Report #', value = tostring(report.id or '?'), inline = true },
        { name = 'Žaidėjas', value = ('%s (ID %s)'):format(report.name or '?', report.source or '?'), inline = true },
        { name = 'CitizenID', value = tostring(report.citizenid or '—'), inline = true },
    }

    if report.title and report.title ~= '' then
        fields[#fields + 1] = { name = 'Pavadinimas', value = tostring(report.title):sub(1, 256), inline = false }
    end

    fields[#fields + 1] = {
        name = 'Pranešimas',
        value = tostring(report.message or '—'):sub(1, 1024),
        inline = false,
    }

    if report.category then
        fields[#fields + 1] = { name = 'Kategorija', value = tostring(report.category), inline = true }
    end
    if report.priority then
        fields[#fields + 1] = { name = 'Prioritetas', value = tostring(report.priority), inline = true }
    end

    if report.coords then
        fields[#fields + 1] = {
            name = 'Koordinatės',
            value = ('`%.1f, %.1f, %.1f`'):format(report.coords.x or 0, report.coords.y or 0, report.coords.z or 0),
            inline = true,
        }
    end

    if type(extraFields) == 'table' then
        for _, f in ipairs(extraFields) do
            fields[#fields + 1] = f
        end
    end

    local logSrc = staffSrc
    if not logSrc or logSrc <= 0 then
        logSrc = report.source
    end

    SendLog('reports', title, tostring(report.message or ''):sub(1, 256), fields, logSrc)
end

exports('LogReportEvent', LogReportEvent)
