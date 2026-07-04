local QBCore = exports['qb-core']:GetCoreObject()

local currentVehNet = 0
local inVehicle = false

local function sendUi(action, payload)
    SendNUIMessage({ action = action, payload = payload or {} })
end

local function audioCmdForAction(action, session)
    action = tostring(action or '')
    if action == 'pause' then
        return { command = 'pause', volume = session.volume }
    end
    if action == 'resume' or action == 'play' then
        if session.stream and session.stream ~= '' or session.youtubeListId or session.spotifyId then
            return {
                command = 'play',
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
        return nil
    end
    if action == 'stop' then
        return { command = 'stop' }
    end
    if action == 'skip' or action == 'next' then
        if session.playlistKind == 'youtube_list' then
            return { command = 'ytNext', volume = session.volume }
        end
        if session.playing and (session.stream or session.spotifyId or session.youtubeListId) then
            return {
                command = 'play',
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
        return { command = 'stop' }
    end
    if action == 'volume' then
        return { command = 'volume', volume = session.volume }
    end
    if action == 'seek' then
        return {
            command = 'seek',
            seconds = session.position,
            position = session.progress,
        }
    end
    return nil
end

local function getVehicleNetId()
    local ped = PlayerPedId()
    if not IsPedInAnyVehicle(ped, false) then return 0 end
    local veh = GetVehiclePedIsIn(ped, false)
    if veh == 0 or not DoesEntityExist(veh) then return 0 end
    return VehToNet(veh)
end

local function refreshCarPlayState()
    local netId = getVehicleNetId()
    inVehicle = netId ~= 0
    currentVehNet = netId
    if not inVehicle then
        sendUi('carplayState', { inVehicle = false })
        TriggerServerEvent('mrp_phone:server:carplayLeave')
        return
    end
    QBCore.Functions.TriggerCallback('mrp_phone:server:getCarPlayState', function(res)
        sendUi('carplayState', {
            inVehicle = true,
            netId = netId,
            session = res and res.session or nil,
        })
    end, { netId = netId })
end

CreateThread(function()
    while true do
        Wait(1200)
        local netId = getVehicleNetId()
        if netId ~= currentVehNet then
            if currentVehNet ~= 0 and netId == 0 then
                sendUi('carplayAudio', { command = 'stop' })
                TriggerServerEvent('mrp_phone:server:carplayLeave')
            end
            currentVehNet = netId
            inVehicle = netId ~= 0
            if inVehicle then
                refreshCarPlayState()
            else
                sendUi('carplayState', { inVehicle = false })
            end
        end
    end
end)

RegisterNUICallback('carplayGetState', function(_, cb)
    local netId = getVehicleNetId()
    if netId == 0 then
        return cb({ ok = false, message = 'Turite būti transporto priemonėje.' })
    end
    QBCore.Functions.TriggerCallback('mrp_phone:server:getCarPlayState', function(res)
        cb(res or { ok = false })
    end, { netId = netId })
end)

RegisterNUICallback('carplayControl', function(data, cb)
    local netId = getVehicleNetId()
    if netId == 0 then
        return cb({ ok = false, message = 'Turite būti transporto priemonėje.' })
    end
    QBCore.Functions.TriggerCallback('mrp_phone:server:carplayControl', function(res)
        if res and res.ok and res.session then
            sendUi('carplayState', {
                inVehicle = true,
                netId = netId,
                session = res.session,
            })
        end
        cb(res or { ok = false })
    end, {
        netId = netId,
        action = data and data.action,
        url = data and data.url,
        title = data and data.title,
        artist = data and data.artist,
        thumbnail = data and data.thumbnail,
        volume = data and data.volume,
        position = data and data.position,
        seconds = data and data.seconds,
        duration = data and data.duration,
    })
end)

RegisterNUICallback('carplayEnded', function(_, cb)
    local netId = getVehicleNetId()
    if netId == 0 then return cb({ ok = false }) end
    QBCore.Functions.TriggerCallback('mrp_phone:server:carplayControl', function(res)
        if res and res.ok and res.session then
            sendUi('carplayState', {
                inVehicle = true,
                netId = netId,
                session = res.session,
            })
        end
        cb(res or { ok = false })
    end, { netId = netId, action = 'next' })
end)

RegisterNetEvent('mrp_phone:client:carplaySync', function(payload)
    if not payload then return end
    local myNet = getVehicleNetId()
    if myNet == 0 or tonumber(payload.netId) ~= myNet then return end
    sendUi('carplayState', {
        inVehicle = true,
        netId = myNet,
        session = payload.session,
    })
    if payload.audio then
        sendUi('carplayAudio', payload.audio)
    end
end)
