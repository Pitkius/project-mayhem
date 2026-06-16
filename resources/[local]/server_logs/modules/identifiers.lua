Identifiers = Identifiers or {}

local function getIds(source)
    local ids = {
        license = 'N/A',
        steam = 'N/A',
        discord = 'N/A',
        fivem = 'N/A',
        ip = 'N/A',
    }

    for _, id in ipairs(GetPlayerIdentifiers(source)) do
        if id:find('license:') then ids.license = id
        elseif id:find('steam:') then ids.steam = id
        elseif id:find('discord:') then ids.discord = id:gsub('discord:', '<@') .. '>'
        elseif id:find('fivem:') then ids.fivem = id
        elseif id:find('ip:') then ids.ip = id
        end
    end

    return ids
end

function Identifiers.GetFormatted(source)
    local ids = getIds(source)
    local lines = {
        ('License: `%s`'):format(ids.license),
        ('Steam: `%s`'):format(ids.steam),
        ('Discord: %s'):format(ids.discord),
        ('FiveM: `%s`'):format(ids.fivem),
    }
    if Config.LogIpAddresses then
        lines[#lines + 1] = ('IP: `%s`'):format(ids.ip)
    end
    return table.concat(lines, '\n')
end

function Identifiers.GetCoords(source)
    local ped = GetPlayerPed(source)
    if not ped or ped == 0 then return 'N/A' end
    local c = GetEntityCoords(ped)
    return ('%.2f, %.2f, %.2f'):format(c.x, c.y, c.z)
end

function Identifiers.GetCoordsField(source)
    return { name = 'Coords', value = ('`%s`'):format(Identifiers.GetCoords(source)), inline = true }
end

exports('GetPlayerIdentifiersFormatted', Identifiers.GetFormatted)
