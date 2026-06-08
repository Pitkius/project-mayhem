local QBCore = exports['qb-core']:GetCoreObject()

--- [frequency] = { [src] = memberData }
local ChannelMembers = {}
--- [src] = žaidėjo įrašytas vardas racijoje
local RadioAlias = {}

local function getJobName(src)
    local P = QBCore.Functions.GetPlayer(src)
    if not P then return nil end
    return P.PlayerData.job and P.PlayerData.job.name
end

local function isMechanicJob(job)
    if not job then return false end
    if job == 'mechanic' then return true end
    local J = QBCore.Shared.Jobs[job]
    return J and J.type == 'mechanic'
end

function GetChannelMeta(freq)
    freq = tonumber(freq)
    if not freq then return nil end
    if Config.ChannelNames and Config.ChannelNames[freq] then
        return Config.ChannelNames[freq]
    end
    for _, r in ipairs(Config.RestrictedRanges or {}) do
        if freq >= r.min and freq <= r.max then
            return ('%s %s'):format(r.label, freq)
        end
    end
    if freq >= (Config.PublicMinFrequency or 21) then
        return ('Viešas %s'):format(freq)
    end
    return ('Dažnis %s'):format(freq)
end

function GetRestrictedLabel(freq)
    freq = tonumber(freq)
    if not freq then return nil end
    for _, r in ipairs(Config.RestrictedRanges or {}) do
        if freq >= r.min and freq <= r.max then
            return r.lockLabel
        end
    end
    return nil
end

local function canAccessFrequency(src, freq)
    freq = math.floor(tonumber(freq) or 0)
    if freq < (Config.MinFrequency or 1) or freq > (Config.MaxFrequency or 999) then
        return false, 'Netinkamas dažnis.'
    end
    if freq >= (Config.PublicMinFrequency or 21) then
        return true
    end
    local job = getJobName(src)
    for _, r in ipairs(Config.RestrictedRanges or {}) do
        if freq >= r.min and freq <= r.max then
            for _, allowed in ipairs(r.jobs) do
                if job == allowed then return true end
                if allowed == 'mechanic' and isMechanicJob(job) then return true end
            end
            return false, 'Neturite prieigos prie šio užkoduoto dažnio.'
        end
    end
    return false, 'Neturite prieigos prie šio užkoduoto dažnio.'
end

local function getCallsign(P)
    if not P then return '' end
    local md = P.PlayerData.metadata or {}
    if type(md.callsign) == 'string' and md.callsign ~= '' then
        return md.callsign:upper()
    end
    if type(md.ltpd_callsign) == 'string' and md.ltpd_callsign ~= '' then
        return md.ltpd_callsign:upper()
    end
    return ''
end

local function buildMemberRow(src)
    local P = QBCore.Functions.GetPlayer(src)
    if not P then return nil end
    local ci = P.PlayerData.charinfo or {}
    local first = ci.firstname or ''
    local last = ci.lastname or ''
    local full = (first .. ' ' .. last):gsub('^%s+', ''):gsub('%s+$', '')
    if full == '' then full = 'Nežinomas' end
    local alias = RadioAlias[src] or ''
    return {
        src = src,
        name = full,
        alias = alias,
        line = alias ~= '' and alias or full,
    }
end

local function removeFromAllChannels(src)
    for freq, members in pairs(ChannelMembers) do
        if members[src] then
            members[src] = nil
            TriggerClientEvent('fivempro_radio:client:channelUpdate', -1, freq, buildMemberList(freq))
        end
    end
end

function buildMemberList(freq)
    local list = {}
    local members = ChannelMembers[freq]
    if not members then return list end
    for src, row in pairs(members) do
        if row then list[#list + 1] = row end
    end
    table.sort(list, function(a, b)
        return (a.line or '') < (b.line or '')
    end)
    return list
end

local function broadcastChannel(freq)
    local payload = buildMemberList(freq)
    for src, _ in pairs(ChannelMembers[freq] or {}) do
        TriggerClientEvent('fivempro_radio:client:channelUpdate', src, freq, payload)
    end
end

local function setPlayerChannel(src, freq)
    removeFromAllChannels(src)
    if not freq then
        TriggerClientEvent('fivempro_radio:client:setChannel', src, nil, nil, nil, false)
        return
    end
    ChannelMembers[freq] = ChannelMembers[freq] or {}
    local row = buildMemberRow(src)
    if row then
        ChannelMembers[freq][src] = row
    end
    local label = GetChannelMeta(freq)
    local lock = GetRestrictedLabel(freq)
    TriggerClientEvent('fivempro_radio:client:setChannel', src, freq, label, lock, true)
    broadcastChannel(freq)
end

RegisterNetEvent('fivempro_radio:server:connect', function(freq, alias)
    local src = source
    freq = math.floor(tonumber(freq) or 0)
    alias = tostring(alias or ''):gsub('^%s+', ''):gsub('%s+$', ''):sub(1, 32)
    if alias == '' then
        return TriggerClientEvent('fivempro_radio:client:notify', src, 'Įrašyk savo vardą racijoje.', 'error')
    end
    local ok, err = canAccessFrequency(src, freq)
    if not ok then
        return TriggerClientEvent('fivempro_radio:client:notify', src, err or 'Negalima prisijungti.', 'error')
    end
    RadioAlias[src] = alias
    setPlayerChannel(src, freq)
    TriggerClientEvent('fivempro_radio:client:voiceJoin', src, freq)
    TriggerClientEvent('fivempro_radio:client:notify', src, ('Sėkmingai prisijungta prie dažnio %s'):format(freq), 'success')
end)

RegisterNetEvent('fivempro_radio:server:disconnect', function()
    local src = source
    removeFromAllChannels(src)
    TriggerClientEvent('fivempro_radio:client:setChannel', src, nil, nil, nil, false)
    TriggerClientEvent('fivempro_radio:client:voiceLeave', src)
end)

RegisterNetEvent('fivempro_radio:server:validateFrequency', function(freq, alias)
    local src = source
    freq = math.floor(tonumber(freq) or 0)
    alias = tostring(alias or ''):gsub('^%s+', ''):gsub('%s+$', ''):sub(1, 32)
    if alias ~= '' then
        RadioAlias[src] = alias
    end
    local ok, err = canAccessFrequency(src, freq)
    if not ok then
        return TriggerClientEvent('fivempro_radio:client:freqDenied', src, err)
    end
    TriggerClientEvent('fivempro_radio:client:freqOk', src, freq, GetChannelMeta(freq), GetRestrictedLabel(freq), alias)
end)

AddEventHandler('playerDropped', function()
    local src = source
    RadioAlias[src] = nil
    removeFromAllChannels(src)
end)

QBCore.Functions.CreateUseableItem('radio', function(source)
    TriggerClientEvent('fivempro_radio:client:open', source)
end)

exports('GetChannelMembers', function(freq)
    return buildMemberList(freq)
end)

exports('CanAccessFrequency', canAccessFrequency)
