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

local function parseYoutubeVideoId(url)
    return url:match('youtu%.be/([%w%-_]+)')
        or url:match('youtube%.com/watch%?v=([%w%-_]+)')
        or url:match('youtube%.com/embed/([%w%-_]+)')
        or url:match('youtube%.com/shorts/([%w%-_]+)')
end

local function parseYoutubeListId(url)
    return url:match('[?&]list=([%w%-_]+)')
        or url:match('youtube%.com/playlist%?list=([%w%-_]+)')
end

local function parseSpotify(url)
    local kind, id = url:match('open%.spotify%.com/(playlist|album|track)/([%w%-]+)')
    if kind and id then return kind, id end
    kind, id = url:match('spotify%.com/(playlist|album|track)/([%w%-]+)')
    if kind and id then return kind, id end
    return nil, nil
end

local function splitUrlLines(raw)
    local lines = {}
    for line in tostring(raw or ''):gmatch('[^\r\n]+') do
        line = trim(line)
        if line ~= '' then lines[#lines + 1] = line end
    end
    return lines
end

local function parseMediaUrl(raw)
    local url = trim(raw)
    if url == '' then return nil, 'Įveskite nuorodą.' end
    local maxLen = (Config.Phone and Config.Phone.maxCarPlayUrlLength) or 512
    if #url > maxLen then return nil, 'Nuoroda per ilga.' end

    local ytId = parseYoutubeVideoId(url)
    local listId = parseYoutubeListId(url)
    if listId or ytId then
        local media = {
            type = 'youtube',
            url = url,
            youtubeVideoId = ytId,
            youtubeListId = listId,
            playlistKind = listId and 'youtube_list' or 'single',
            title = listId and 'YouTube grojaraštis' or 'YouTube vaizdo įrašas',
        }
        if ytId then
            media.thumbnail = ('https://img.youtube.com/vi/%s/hqdefault.jpg'):format(ytId)
        end
        media.stream = ytId or listId or url
        return media
    end

    local spKind, spId = parseSpotify(url)
    if spKind and spId then
        return {
            type = 'spotify',
            url = url,
            spotifyType = spKind,
            spotifyId = spId,
            playlistKind = (spKind == 'playlist' or spKind == 'album') and 'spotify_embed' or 'single',
            stream = url,
            title = spKind == 'track' and 'Spotify takelis' or ('Spotify ' .. spKind),
        }
    end

    if url:match('^https?://') and url:match('%.(mp3|ogg|wav|m4a|aac)') then
        return { type = 'audio', url = url, stream = url, title = 'Tiesioginė nuoroda', playlistKind = 'single' }
    end

    if url:match('^https?://') then
        return { type = 'audio', url = url, stream = url, title = 'Medija', playlistKind = 'single' }
    end
    return nil, 'Netinkama nuoroda.'
end

local function buildQueueFromInput(raw)
    local lines = splitUrlLines(raw)
    if #lines == 0 then return nil end
    if #lines == 1 then return nil end
    local queue = {}
    for _, line in ipairs(lines) do
        local media, err = parseMediaUrl(line)
        if media then
            queue[#queue + 1] = {
                url = media.url,
                stream = media.stream,
                mediaType = media.type,
                title = media.title,
                thumbnail = media.thumbnail,
                youtubeVideoId = media.youtubeVideoId,
                youtubeListId = media.youtubeListId,
                spotifyType = media.spotifyType,
                spotifyId = media.spotifyId,
                playlistKind = media.playlistKind,
            }
        end
    end
    if #queue == 0 then return nil, 'Netinkamos nuorodos.' end
    return queue
end

local function applyMediaToSession(session, media, meta)
    meta = meta or {}
    session.url = media.url
    session.stream = media.stream or media.url
    session.mediaType = media.type
    session.youtubeVideoId = media.youtubeVideoId
    session.youtubeListId = media.youtubeListId
    session.spotifyType = media.spotifyType
    session.spotifyId = media.spotifyId
    session.playlistKind = media.playlistKind or 'single'
    session.title = clampStr(meta.title or media.title, 120)
    session.artist = clampStr(meta.artist or '', 80)
    session.thumbnail = clampStr(meta.thumbnail or media.thumbnail or '', 500)
    session.progress = 0
    session.position = 0
    session.duration = 0
    session.playing = true
end

local function audioCmdForSession(session, command)
    command = command or 'play'
    return {
        command = command,
        stream = session.stream,
        url = session.url,
        mediaType = session.mediaType,
        title = session.title,
        volume = session.volume,
        youtubeVideoId = session.youtubeVideoId,
        youtubeListId = session.youtubeListId,
        spotifyType = session.spotifyType,
        spotifyId = session.spotifyId,
        playlistKind = session.playlistKind,
        queueIndex = session.queueIndex,
        queueLength = session.queue and #session.queue or 0,
    }
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

local function broadcastCarPlay(netId, session, audioCmd, initiatorSrc)
    local sent = {}
    local function deliver(src)
        src = tonumber(src)
        if not src or sent[src] then return end
        sent[src] = true
        TriggerClientEvent('mrp_phone:client:carplaySync', src, {
            netId = netId,
            session = session,
            audio = audioCmd,
        })
    end
    if initiatorSrc then deliver(initiatorSrc) end
    for _, src in ipairs(occupantsOfVehicle(netId)) do
        deliver(src)
    end
end

local function defaultSession()
    return {
        title = 'Niekas negroja',
        artist = '',
        thumbnail = '',
        url = '',
        stream = '',
        mediaType = '',
        playing = false,
        volume = 0.65,
        progress = 0,
        duration = 0,
        position = 0,
        playlistKind = 'single',
        queue = nil,
        queueIndex = 0,
        youtubeVideoId = nil,
        youtubeListId = nil,
        spotifyType = nil,
        spotifyId = nil,
    }
end

local function playQueueIndex(session, index)
    if not session.queue or not session.queue[index] then return false end
    local item = session.queue[index]
    session.queueIndex = index
    applyMediaToSession(session, {
        type = item.mediaType,
        url = item.url,
        stream = item.stream,
        youtubeVideoId = item.youtubeVideoId,
        youtubeListId = item.youtubeListId,
        spotifyType = item.spotifyType,
        spotifyId = item.spotifyId,
        playlistKind = item.playlistKind or 'single',
        title = item.title,
        thumbnail = item.thumbnail,
    }, {
        title = item.title,
        artist = item.artist,
        thumbnail = item.thumbnail,
    })
    return true
end

local function startPlayback(netId, session, rawInput, meta, source)
    meta = meta or {}
    local queue, qErr = buildQueueFromInput(rawInput)
    if queue then
        session.queue = queue
        session.queueIndex = 1
        playQueueIndex(session, 1)
        if meta.title then session.title = clampStr(meta.title, 120) end
        if meta.artist then session.artist = clampStr(meta.artist, 80) end
        if meta.thumbnail then session.thumbnail = clampStr(meta.thumbnail, 500) end
        session.playlistKind = 'queue'
    else
        local media, err = parseMediaUrl(rawInput)
        if not media then return false, err or qErr or 'Klaida.' end
        session.queue = nil
        session.queueIndex = 0
        applyMediaToSession(session, media, meta)
    end
    CarPlaySessions[netId] = session
    broadcastCarPlay(netId, session, audioCmdForSession(session, 'play'), source)
    return true
end

local function advancePlayback(netId, session, source)
    if session.playlistKind == 'queue' and session.queue then
        local nextIdx = (session.queueIndex or 1) + 1
        if playQueueIndex(session, nextIdx) then
            CarPlaySessions[netId] = session
            broadcastCarPlay(netId, session, audioCmdForSession(session, 'play'), source)
            return true, session
        end
        session.playing = false
        CarPlaySessions[netId] = session
        broadcastCarPlay(netId, session, { command = 'stop' }, source)
        return true, session
    end

    if session.playlistKind == 'youtube_list' then
        CarPlaySessions[netId] = session
        broadcastCarPlay(netId, session, { command = 'ytNext', volume = session.volume }, source)
        return true, session
    end

    session.playing = false
    CarPlaySessions[netId] = session
    broadcastCarPlay(netId, session, { command = 'stop' }, source)
    return true, session
end

QBCore.Functions.CreateCallback('mrp_phone:server:getCarPlayState', function(source, cb, data)
    local netId = tonumber(data and data.netId) or 0
    if netId == 0 then return cb({ ok = false, message = 'Nėra transporto.' }) end
    local session = getSession(netId) or defaultSession()
    cb({ ok = true, session = session })
end)

QBCore.Functions.CreateCallback('mrp_phone:server:carplayControl', function(source, cb, data)
    local netId = tonumber(data and data.netId) or 0
    if netId == 0 then return cb({ ok = false, message = 'Nėra transporto.' }) end

    local action = tostring(data and data.action or '')
    local session = getSession(netId) or defaultSession()

    if action == 'play' then
        local raw = data and data.url or session.url
        if trim(raw) == '' then return cb({ ok = false, message = 'Įveskite nuorodą.' }) end
        local ok, err = startPlayback(netId, session, raw, {
            title = data and data.title,
            artist = data and data.artist,
            thumbnail = data and data.thumbnail,
        }, source)
        if not ok then return cb({ ok = false, message = err or 'Klaida.' }) end
        return cb({ ok = true, session = CarPlaySessions[netId] })
    end

    if action == 'pause' then
        session.playing = false
        CarPlaySessions[netId] = session
        broadcastCarPlay(netId, session, { command = 'pause', volume = session.volume }, source)
        return cb({ ok = true, session = session })
    end

    if action == 'resume' then
        if session.stream == '' and not session.youtubeListId and not session.spotifyId then
            return cb({ ok = false, message = 'Nėra ką leisti.' })
        end
        session.playing = true
        CarPlaySessions[netId] = session
        broadcastCarPlay(netId, session, audioCmdForSession(session, 'play'), source)
        return cb({ ok = true, session = session })
    end

    if action == 'stop' then
        session = defaultSession()
        CarPlaySessions[netId] = session
        broadcastCarPlay(netId, session, { command = 'stop' }, source)
        return cb({ ok = true, session = session })
    end

    if action == 'volume' then
        session.volume = math.max(0.0, math.min(1.0, tonumber(data and data.volume) or session.volume))
        CarPlaySessions[netId] = session
        broadcastCarPlay(netId, session, { command = 'volume', volume = session.volume }, source)
        return cb({ ok = true, session = session })
    end

    if action == 'seek' then
        local seconds = tonumber(data and data.seconds)
        local position = tonumber(data and data.position)
        if seconds then
            session.position = math.max(0, seconds)
            if tonumber(session.duration) and session.duration > 0 then
                session.progress = math.max(0, math.min(1, session.position / session.duration))
            end
        elseif position then
            session.progress = math.max(0.0, math.min(1.0, position))
        end
        CarPlaySessions[netId] = session
        broadcastCarPlay(netId, session, {
            command = 'seek',
            seconds = session.position,
            position = session.progress,
        }, source)
        return cb({ ok = true, session = session })
    end

    if action == 'duration' then
        local dur = tonumber(data and data.duration)
        if dur and dur > 0 then
            session.duration = dur
            CarPlaySessions[netId] = session
        end
        return cb({ ok = true, session = session })
    end

    if action == 'meta' then
        if data and data.title then session.title = clampStr(data.title, 120) end
        if data and data.artist then session.artist = clampStr(data.artist, 80) end
        if data and data.thumbnail then session.thumbnail = clampStr(data.thumbnail, 500) end
        CarPlaySessions[netId] = session
        broadcastCarPlay(netId, session, nil, source)
        return cb({ ok = true, session = session })
    end

    if action == 'next' or action == 'skip' then
        local ok, updated = advancePlayback(netId, session, source)
        return cb({ ok = ok, session = updated or session })
    end

    cb({ ok = false, message = 'Nežinomas veiksmas.' })
end)

RegisterNetEvent('mrp_phone:server:carplayLeave', function()
    local src = source
    TriggerClientEvent('mrp_phone:client:carplaySync', src, {
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
