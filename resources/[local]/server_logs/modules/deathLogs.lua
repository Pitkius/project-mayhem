-- Death logs

local function weaponLabel(hash)
    return tostring(hash)
end

RegisterNetEvent('server_logs:playerDeath', function(data)
    local src = source
    data = data or {}

    local victim = data.victim or src
    local killer = data.killer
    local weapon = data.weapon or 'Unknown'
    local distance = data.distance or 0
    local headshot = data.headshot and 'Yes' or 'No'
    local vehicleKill = data.vehicleKill and 'Yes' or 'No'
    local deathType = data.deathType or 'unknown'

    local fields = {
        { name = 'Victim', value = ('%s [%s]'):format(GetPlayerName(victim) or '?', victim), inline = true },
        { name = 'Weapon', value = weaponLabel(weapon), inline = true },
        { name = 'Distance', value = ('%.1fm'):format(distance), inline = true },
        { name = 'Headshot', value = headshot, inline = true },
        { name = 'Vehicle Kill', value = vehicleKill, inline = true },
        { name = 'Type', value = deathType, inline = true },
        Identifiers.GetCoordsField(victim),
    }

    if killer and killer > 0 then
        fields[#fields + 1] = { name = 'Killer', value = ('%s [%s]'):format(GetPlayerName(killer) or '?', killer), inline = true }
    end

    SendLog('death', 'Player Death', data.reason or 'Player died', fields, victim)

    if Config.EnableScreenshotOnDeath and GetResourceState('screenshot-basic') == 'started' then
        -- Optional: integrate screenshot-basic upload to webhook
    end
end)

-- baseevents compatibility
RegisterNetEvent('baseevents:onPlayerDied', function(_killertype, pos)
    TriggerEvent('server_logs:playerDeath', {
        victim = source,
        deathType = 'died',
        coords = pos,
    })
end)

RegisterNetEvent('baseevents:onPlayerKilled', function(killerId, data)
    TriggerEvent('server_logs:playerDeath', {
        victim = source,
        killer = killerId,
        weapon = data and data.weaponhash,
        deathType = 'killed',
    })
end)
