-- In-game admin komandos: giveitem, givemoney, setmoney, revive, heal → `admin_actions`

local function adminName(src)
    if not src or src <= 0 then return 'txAdmin / konsolė' end
    return GetPlayerName(src) or ('Admin %s'):format(src)
end

local function targetName(targetId)
    targetId = tonumber(targetId)
    if not targetId then return '?' end
    local name = GetPlayerName(targetId)
    if name then return ('%s [%s]'):format(name, targetId) end
    return ('ID %s'):format(targetId)
end

function LogAdminAction(src, command, description, extraFields)
    local fields = {
        { name = 'Komanda', value = ('`/%s`'):format(command or '?'), inline = true },
        { name = 'Adminas', value = adminName(src), inline = true },
    }
    if type(extraFields) == 'table' then
        for _, f in ipairs(extraFields) do
            fields[#fields + 1] = f
        end
    end
    if src and src > 0 and Identifiers and Identifiers.GetCoordsField then
        fields[#fields + 1] = Identifiers.GetCoordsField(src)
    end
    SendLog('admin_actions', ('Admin: /%s'):format(command or 'action'), description or '', fields, (src and src > 0) and src or nil)
end

exports('LogAdminAction', LogAdminAction)

AddEventHandler('server_logs:adminAction', function(src, command, description, extraFields)
    LogAdminAction(src, command, description, extraFields)
end)
