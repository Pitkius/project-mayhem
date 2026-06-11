local QBCore = exports['qb-core']:GetCoreObject()

local CarPlaySessions = {}

local function trim(s)
    return tostring(s or ''):gsub('^%s+', ''):gsub('%s+$', '')
end

local function clampStr(s, maxLen)
    s = trim(s)
    if #s > maxLen then s = s:sub(1, maxLen) end
    return s
end

local function parseMediaUrl(raw)
    local url = trim(raw)
    if url == '' then return nil, 'Įveskite nuorodą.' end
    local maxLen = (Config.Phone and Config.Phone.maxCarPlayUrlLength) or 512
    if #url > maxLen then return nil, 'Nuoroda per ilga.' end

    local ytId = url:match('youtu%.be/([%w%-_]+)')
        or url:match('youtube%.com/watch%?v=([%w%-_]+)')
        or url:match('youtube%.com/embed/([%w%-_]+)')
    if ytId then
        return {
            type = 'youtube',
            url = url,
            stream = ('https://www.youtube.com/embed/%s?autoplay=1'):format(ytId),
            title = 'YouTube',
        }
    end

    if url:match('^https?://') and url:match('%.(mp3|ogg|wav|m4a|aac)') then
        return { type = 'audio', url = url, stream = url, title = 'Tiesioginė nuoroda' }
    end

    if url:match('open%.spotify%.com/') or url:match('spotify%.com/') then
        return {
            type = 'spotify',
            url = url,
            stream = url,
            title = 'Spotify',
        }
    end

    if url:match('^https?://') then
        return { type = 'audio', url = url, stream = url, title = 'Medija' }
    end
    return nil, 'Netinkama nuoroda.'
end

local function getSession(netId)
    netId = tonumber(netId) or 0
    if netId == 0 then return nil end
    return CarPlaySessions[netId]
end

local function occupantsOfVehicle(netId)
    local out = {}
    local veh = NetworkGetEntityFromNetworkId(tonumber(netId) or 0)
    if not veh or veh == 0 then return out end
    for _, sid in ipairs(GetPlayers()) do
        local src = tonumber(sid)
        local ped = GetPlayerPed(src)
        if ped and ped ~= 0 and IsPedInAnyVehicle(ped, false) then
            local v = GetVehiclePedIsIn(ped, false)
            if v ~= 0 and NetworkGetNetworkIdFromEntity(v) == tonumber(netId) then
                out[#out + 1] = src
            end
        end
    end
    return out
end

local function broadcastCarPlay(netId, session, audioCmd)
    for _, src in ipairs(occupantsOfVehicle(netId)) do
        TriggerClientEvent('fivempro_phone:client:carplaySync', src, {
            netId = netId,
            session = session,
            audio = audioCmd,
        })
    end
end

local function defaultSession()
    return {
        title = 'Niekas negroja',
        url = '',
        stream = '',
        mediaType = '',
        playing = false,
        volume = 0.65,
        progress = 0,
    }
end

QBCore.Functions.CreateCallback('fivempro_phone:server:getCarPlayState', function(source, cb, data)
    local netId = tonumber(data and data.netId) or 0
    if netId == 0 then return cb({ ok = false, message = 'Nėra transporto.' }) end
    local session = getSession(netId) or defaultSession()
    cb({ ok = true, session = session })
end)

QBCore.Functions.CreateCallback('fivempro_phone:server:carplayControl', function(source, cb, data)
    local netId = tonumber(data and data.netId) or 0
    if netId == 0 then return cb({ ok = false, message = 'Nėra transporto.' }) end

    local action = tostring(data and data.action or '')
    local session = getSession(netId) or defaultSession()

    if action == 'play' then
        local media, err = parseMediaUrl(data and data.url or session.url)
        if not media then return cb({ ok = false, message = err or 'Klaida.' }) end
        session.url = media.url
        session.stream = media.stream
        session.mediaType = media.type
        session.title = clampStr(data and data.title or media.title, 80)
        session.playing = true
        CarPlaySessions[netId] = session
        broadcastCarPlay(netId, session, {
            command = 'play',
            stream = session.stream,
            mediaType = session.mediaType,
            title = session.title,
            volume = session.volume,
        })
        return cb({ ok = true, session = session })
    end

    if action == 'pause' then
        session.playing = false
        CarPlaySessions[netId] = session
        broadcastCarPlay(netId, session, { command = 'pause', volume = session.volume })
        return cb({ ok = true, session = session })
    end

    if action == 'resume' then
        if session.stream == '' then
            return cb({ ok = false, message = 'Nėra ką leisti.' })
        end
        session.playing = true
        CarPlaySessions[netId] = session
        broadcastCarPlay(netId, session, {
            command = 'play',
            stream = session.stream,
            mediaType = session.mediaType,
            title = session.title,
            volume = session.volume,
        })
        return cb({ ok = true, session = session })
    end

    if action == 'stop' then
        session = defaultSession()
        CarPlaySessions[netId] = session
        broadcastCarPlay(netId, session, { command = 'stop' })
        return cb({ ok = true, session = session })
    end

    if action == 'volume' then
        session.volume = math.max(0.0, math.min(1.0, tonumber(data and data.volume) or session.volume))
        CarPlaySessions[netId] = session
        broadcastCarPlay(netId, session, { command = 'volume', volume = session.volume })
        return cb({ ok = true, session = session })
    end

    if action == 'skip' then
        session.playing = false
        session.progress = 0
        CarPlaySessions[netId] = session
        broadcastCarPlay(netId, session, { command = 'stop' })
        return cb({ ok = true, session = session })
    end

    cb({ ok = false, message = 'Nežinomas veiksmas.' })
end)

RegisterNetEvent('fivempro_phone:server:carplayLeave', function()
    local src = source
    TriggerClientEvent('fivempro_phone:client:carplaySync', src, {
        netId = 0,
        session = defaultSession(),
        audio = { command = 'stop' },
    })
end)

AddEventHandler('entityRemoved', function(entity)
    if not entity or entity == 0 then return end
    if GetEntityType(entity) ~= 2 then return end
    local netId = NetworkGetNetworkIdFromEntity(entity)
    if netId ~= 0 and CarPlaySessions[netId] then
        CarPlaySessions[netId] = nil
    end
end)
