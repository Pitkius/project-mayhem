local QBCore = exports['qb-core']:GetCoreObject()

local Calls = {}
local CallSeq = 0
local Crews = {}
local PlayerCrew = {}
local Callsigns = {}

local function citizenIdOf(src)
    local p = QBCore.Functions.GetPlayer(src)
    return p and p.PlayerData and p.PlayerData.citizenid or nil
end

local function logEvent(service, eventType, src, payload)
    if GetResourceState('oxmysql') ~= 'started' then return end
    MySQL.insert(
        'INSERT INTO fivempro_dispatch_logs (service, event_type, actor_source, actor_citizenid, payload) VALUES (?, ?, ?, ?, ?)',
        { tostring(service or 'unknown'), tostring(eventType or 'event'), tonumber(src) or nil, citizenIdOf(src), json.encode(payload or {}) }
    )
end

local function nowMs()
    return GetGameTimer()
end

local function nowIso()
    return os.date('!%Y-%m-%dT%H:%M:%SZ')
end

local function getPlayer(src)
    return QBCore.Functions.GetPlayer(src)
end

local function jobName(src)
    local p = getPlayer(src)
    if not p or not p.PlayerData or not p.PlayerData.job then return nil end
    return p.PlayerData.job.name, p.PlayerData.job.onduty == true
end

local function serviceForJob(name)
    if not name then return nil end
    for service, cfg in pairs(Config.Services or {}) do
        for _, j in ipairs(cfg.jobs or {}) do
            if j == name then return service end
        end
    end
    return nil
end

local function playerService(src)
    local jn, onduty = jobName(src)
    if not onduty then return nil end
    return serviceForJob(jn)
end

local function isServiceMember(src, service)
    return playerService(src) == service
end

local function getName(src)
    local p = getPlayer(src)
    if not p then return ('ID %s'):format(src) end
    local c = p.PlayerData.charinfo or {}
    return (tostring(c.firstname or '') .. ' ' .. tostring(c.lastname or '')):gsub('^%s+', ''):gsub('%s+$', '')
end

local function callsForService(service)
    local out = {}
    for _, c in pairs(Calls) do
        if c.service == service then
            out[#out + 1] = c
        end
    end
    table.sort(out, function(a, b) return (a.createdAtMs or 0) > (b.createdAtMs or 0) end)
    return out
end

local function crewsForService(service)
    local out = {}
    for crewId, crew in pairs(Crews) do
        if crew and crew.service == service then
            local members = {}
            for _, src in ipairs(crew.members or {}) do
                local ped = GetPlayerPed(src)
                local pos = ped and ped ~= 0 and GetEntityCoords(ped) or nil
                members[#members + 1] = {
                    source = src,
                    name = getName(src),
                    callsign = Callsigns[src] or '',
                    x = pos and pos.x or nil,
                    y = pos and pos.y or nil,
                    z = pos and pos.z or nil,
                }
            end
            out[#out + 1] = {
                crewId = crewId,
                crewNumber = crew.crewNumber,
                callsign = crew.callsign or '',
                status = crew.status or 'active',
                leader = crew.leader,
                assignedCallId = crew.assignedCallId,
                members = members,
            }
        end
    end
    table.sort(out, function(a, b) return tostring(a.crewNumber) < tostring(b.crewNumber) end)
    return out
end

local function unitBlipsForService(service)
    local units = {}
    for _, src in ipairs(QBCore.Functions.GetPlayers() or {}) do
        if isServiceMember(src, service) then
            local ped = GetPlayerPed(src)
            if ped and ped ~= 0 then
                local p = GetEntityCoords(ped)
                units[#units + 1] = {
                    source = src,
                    name = getName(src),
                    callsign = Callsigns[src] or '',
                    x = p.x,
                    y = p.y,
                    z = p.z,
                    heading = GetEntityHeading(ped),
                    inVeh = IsPedInAnyVehicle(ped, false) and true or false,
                    crewId = PlayerCrew[src],
                }
            end
        end
    end
    return units
end

local function pushServiceUpdate(service)
    local payload = {
        service = service,
        calls = callsForService(service),
        crews = crewsForService(service),
        units = unitBlipsForService(service),
        ts = nowMs(),
    }
    for _, src in ipairs(QBCore.Functions.GetPlayers() or {}) do
        if isServiceMember(src, service) then
            TriggerClientEvent('fivempro_dispatch:client:update', src, payload)
        end
    end
end

local function pruneCalls()
    local arr = {}
    for _, c in pairs(Calls) do arr[#arr + 1] = c end
    table.sort(arr, function(a, b) return (a.createdAtMs or 0) < (b.createdAtMs or 0) end)
    while #arr > (Config.MaxActiveCalls or 120) do
        local rem = table.remove(arr, 1)
        Calls[rem.id] = nil
    end
end

local function createCall(service, callType, coords, text, createdBy)
    CallSeq = CallSeq + 1
    local id = ('C-%05d'):format(CallSeq)
    local c = {
        id = id,
        service = service,
        callType = callType or 'custom',
        callTypeLabel = (Config.CallTypes and Config.CallTypes[callType]) or callType or 'Kitas',
        text = tostring(text or ''),
        x = coords.x + 0.0,
        y = coords.y + 0.0,
        z = coords.z + 0.0,
        status = 'pending',
        statusLabel = (Config.CallStatus and Config.CallStatus.pending) or 'Laukia',
        createdAt = nowIso(),
        createdAtMs = nowMs(),
        createdBy = createdBy,
        acceptedBy = {},
        enrouteBy = {},
    }
    Calls[id] = c
    logEvent(service, 'call_created', createdBy, c)
    pruneCalls()
    pushServiceUpdate(service)
    return c
end

exports('CreateDispatchCall', function(service, callType, coords, text, createdBy)
    if not service or not coords then return nil end
    return createCall(service, callType, coords, text, createdBy)
end)

QBCore.Functions.CreateCallback('fivempro_dispatch:server:getSnapshot', function(src, cb, service)
    if not isServiceMember(src, service) then return cb({ ok = false }) end
    cb({
        ok = true,
        service = service,
        calls = callsForService(service),
        crews = crewsForService(service),
        units = unitBlipsForService(service),
    })
end)

RegisterNetEvent('fivempro_dispatch:server:createCrew', function(callsign)
    local src = source
    local service = playerService(src)
    if not service then return end
    local oldCrew = PlayerCrew[src]
    if oldCrew and Crews[oldCrew] then
        return TriggerClientEvent('QBCore:Notify', src, 'Jau esi ekipaže.', 'error')
    end
    local crewId = ('CRW-%s-%s'):format(service, math.random(1000, 9999))
    local crewNumber = math.random(10, 999)
    Crews[crewId] = {
        service = service,
        crewNumber = crewNumber,
        callsign = tostring(callsign or ''),
        status = 'active',
        members = { src },
        leader = src,
        assignedCallId = nil,
    }
    PlayerCrew[src] = crewId
    logEvent(service, 'crew_created', src, { crewId = crewId, callsign = callsign })
    pushServiceUpdate(service)
end)

RegisterNetEvent('fivempro_dispatch:server:joinCrew', function(crewId)
    local src = source
    local service = playerService(src)
    local crew = crewId and Crews[crewId]
    if not service or not crew or crew.service ~= service then return end
    if PlayerCrew[src] then return end
    crew.members[#crew.members + 1] = src
    PlayerCrew[src] = crewId
    logEvent(service, 'crew_joined', src, { crewId = crewId })
    pushServiceUpdate(service)
end)

RegisterNetEvent('fivempro_dispatch:server:addToCrew', function(crewId, targetSrc)
    local src = source
    local service = playerService(src)
    local crew = crewId and Crews[crewId]
    targetSrc = tonumber(targetSrc)
    if not service or not crew or crew.service ~= service or not targetSrc then return end
    if crew.leader ~= src then
        return TriggerClientEvent('QBCore:Notify', src, 'Tik ekipažo vadas gali pridėti narį.', 'error')
    end
    if PlayerCrew[targetSrc] then
        return TriggerClientEvent('QBCore:Notify', src, 'Žaidėjas jau kitame ekipaže.', 'error')
    end
    if not isServiceMember(targetSrc, service) then
        return TriggerClientEvent('QBCore:Notify', src, 'Žaidėjas ne šios tarnybos duty metu.', 'error')
    end
    crew.members[#crew.members + 1] = targetSrc
    PlayerCrew[targetSrc] = crewId
    logEvent(service, 'crew_member_added', src, { crewId = crewId, target = targetSrc })
    pushServiceUpdate(service)
end)

RegisterNetEvent('fivempro_dispatch:server:deleteCrew', function(crewId)
    local src = source
    local service = playerService(src)
    local crew = crewId and Crews[crewId]
    if not service or not crew or crew.service ~= service then return end
    if crew.leader ~= src then
        return TriggerClientEvent('QBCore:Notify', src, 'Tik ekipažo vadas gali ištrinti ekipažą.', 'error')
    end
    for _, memberSrc in ipairs(crew.members or {}) do
        PlayerCrew[memberSrc] = nil
    end
    Crews[crewId] = nil
    logEvent(service, 'crew_deleted', src, { crewId = crewId })
    pushServiceUpdate(service)
end)

RegisterNetEvent('fivempro_dispatch:server:leaveCrew', function()
    local src = source
    local crewId = PlayerCrew[src]
    if not crewId then return end
    local crew = Crews[crewId]
    local service = crew and crew.service or playerService(src)
    if crew then
        local nextMembers = {}
        for _, id in ipairs(crew.members) do
            if id ~= src then nextMembers[#nextMembers + 1] = id end
        end
        crew.members = nextMembers
        if #crew.members == 0 then
            Crews[crewId] = nil
        elseif crew.leader == src then
            crew.leader = crew.members[1]
        end
    end
    PlayerCrew[src] = nil
    logEvent(service, 'crew_left', src, { crewId = crewId })
    if service then pushServiceUpdate(service) end
end)

RegisterNetEvent('fivempro_dispatch:server:setCallsign', function(callsign)
    local src = source
    local service = playerService(src)
    if not service then return end
    callsign = tostring(callsign or ''):upper():gsub('[^A-Z0-9]', ''):sub(1, 12)
    Callsigns[src] = callsign
    local crewId = PlayerCrew[src]
    if crewId and Crews[crewId] and callsign ~= '' then
        Crews[crewId].callsign = callsign
    end
    logEvent(service, 'callsign_set', src, { callsign = callsign })
    pushServiceUpdate(service)
end)

RegisterNetEvent('fivempro_dispatch:server:updateCallStatus', function(callId, action)
    local src = source
    local service = playerService(src)
    local c = callId and Calls[callId]
    if not service or not c or c.service ~= service then return end
    action = tostring(action or '')
    if action == 'accept' then
        c.acceptedBy[tostring(src)] = true
        c.status = 'accepted'
        c.statusLabel = (Config.CallStatus and Config.CallStatus.accepted) or 'Priimtas'
    elseif action == 'enroute' then
        c.enrouteBy[tostring(src)] = true
        c.status = 'enroute'
        c.statusLabel = (Config.CallStatus and Config.CallStatus.enroute) or 'Vykstu'
    elseif action == 'reject' then
        c.status = 'rejected'
        c.statusLabel = (Config.CallStatus and Config.CallStatus.rejected) or 'Atmestas'
    elseif action == 'done' then
        c.status = 'done'
        c.statusLabel = (Config.CallStatus and Config.CallStatus.done) or 'Baigta'
    elseif action == 'panic_off' and c.panic then
        c.status = 'done'
        c.statusLabel = 'PANIC IŠJUNGTAS'
        for _, id in ipairs(QBCore.Functions.GetPlayers() or {}) do
            if isServiceMember(id, 'police') then
                TriggerClientEvent('fivempro_dispatch:client:panicClear', id, { callId = c.id })
            end
        end
    end
    local crewId = PlayerCrew[src]
    if crewId and Crews[crewId] then
        Crews[crewId].assignedCallId = c.status == 'done' and nil or c.id
    end
    logEvent(service, 'call_status', src, { callId = c.id, action = action, status = c.status })
    pushServiceUpdate(service)
end)

RegisterNetEvent('fivempro_dispatch:server:panic', function()
    local src = source
    local service = playerService(src)
    if service ~= 'police' then return end
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return end
    local p = GetEntityCoords(ped)
    local crewId = PlayerCrew[src]
    local crew = crewId and Crews[crewId] or nil
    local callsign = Callsigns[src] or (crew and crew.callsign) or ''
    local c = createCall('police', 'custom', p, 'PANIC BUTTON', src)
    c.priority = true
    c.panic = true
    c.officerName = getName(src)
    c.callsign = callsign
    c.status = 'enroute'
    c.statusLabel = 'PRIORITY ALERT'
    logEvent('police', 'panic_triggered', src, c)
    pushServiceUpdate('police')
    for _, id in ipairs(QBCore.Functions.GetPlayers() or {}) do
        if isServiceMember(id, 'police') then
            TriggerClientEvent('fivempro_dispatch:client:panic', id, {
                callId = c.id,
                officerName = c.officerName,
                callsign = callsign,
                x = p.x, y = p.y, z = p.z,
                time = c.createdAt,
            })
        end
    end
end)

RegisterNetEvent('fivempro_dispatch:server:createServiceCall', function(service, callType, text, coords)
    local src = source
    if not Config.Services[service] then return end
    local ped = GetPlayerPed(src)
    local p = coords
    if not p and ped and ped ~= 0 then
        local c = GetEntityCoords(ped)
        p = { x = c.x, y = c.y, z = c.z }
    end
    if not p then return end
    createCall(service, callType or 'civilian_help', p, text or '', src)
end)

CreateThread(function()
    while true do
        for service, _ in pairs(Config.Services or {}) do
            pushServiceUpdate(service)
        end
        Wait(tonumber(Config.BlipRefreshMs) or 1500)
    end
end)

AddEventHandler('playerDropped', function()
    local src = source
    local crewId = PlayerCrew[src]
    if crewId and Crews[crewId] then
        local service = Crews[crewId].service
        local members = {}
        for _, id in ipairs(Crews[crewId].members or {}) do
            if id ~= src then members[#members + 1] = id end
        end
        Crews[crewId].members = members
        if #members == 0 then Crews[crewId] = nil end
        PlayerCrew[src] = nil
        if service then pushServiceUpdate(service) end
    end
    Callsigns[src] = nil
end)

