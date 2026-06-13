local QBCore = exports['qb-core']:GetCoreObject()

--- [freqKey] = { [src] = memberData }
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
    local label = Config.GetFactionForFreq(freq)
    if label then return label end
    freq = RadioFreq.normalize(freq)
    if not freq then return '—' end
    return 'Viešas'
end

function GetRestrictedLabel(freq)
    freq = RadioFreq.normalize(freq)
    if not freq then return nil end
    for _, r in ipairs(Config.RestrictedRanges or {}) do
        if freq >= r.min and freq <= r.max then
            return r.lockLabel
        end
    end
    return nil
end

local function canAccessFrequency(src, rawFreq)
    local freq = RadioFreq.normalize(rawFreq)
    if not freq then
        return false, 'Netinkamas dažnis (pvz. 19.81).'
    end
    if freq >= (Config.PublicMinFrequency or 21.0) then
        return true, freq
    end
    local job = getJobName(src)
    for _, r in ipairs(Config.RestrictedRanges or {}) do
        if freq >= r.min and freq <= r.max then
            for _, allowed in ipairs(r.jobs) do
                if job == allowed then return true, freq end
                if allowed == 'mechanic' and isMechanicJob(job) then return true, freq end
            end
            return false, 'Neturite prieigos prie šio užkoduoto dažnio.'
        end
    end
    return false, 'Neturite prieigos prie šio užkoduoto dažnio.'
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
    for key, members in pairs(ChannelMembers) do
        if members[src] then
            members[src] = nil
            TriggerClientEvent('fivempro_radio:client:channelUpdate', -1, RadioFreq.fromKey(key), buildMemberList(key))
        end
    end
end

function buildMemberList(freqKey)
    local list = {}
    local members = ChannelMembers[freqKey]
    if not members then return list end
    for src, row in pairs(members) do
        if row then list[#list + 1] = row end
    end
    table.sort(list, function(a, b)
        return (a.line or '') < (b.line or '')
    end)
    return list
end

local function broadcastChannel(freqKey)
    local freq = RadioFreq.fromKey(freqKey)
    local payload = buildMemberList(freqKey)
    for src, _ in pairs(ChannelMembers[freqKey] or {}) do
        TriggerClientEvent('fivempro_radio:client:channelUpdate', src, freq, payload)
    end
end

local function setPlayerChannel(src, freq)
    removeFromAllChannels(src)
    if not freq then
        TriggerClientEvent('fivempro_radio:client:setChannel', src, nil, nil, nil, false)
        return
    end
    local key = RadioFreq.toKey(freq)
    if not key then return end
    ChannelMembers[key] = ChannelMembers[key] or {}
    local row = buildMemberRow(src)
    if row then
        ChannelMembers[key][src] = row
    end
    local label = GetChannelMeta(freq)
    local lock = GetRestrictedLabel(freq)
    TriggerClientEvent('fivempro_radio:client:setChannel', src, freq, label, lock, true)
    broadcastChannel(key)
end

RegisterNetEvent('fivempro_radio:server:connect', function(rawFreq, alias)
    local src = source
    alias = tostring(alias or ''):gsub('^%s+', ''):gsub('%s+$', ''):sub(1, 32)
    if alias == '' then
        return TriggerClientEvent('fivempro_radio:client:notify', src, 'Įrašyk savo vardą racijoje.', 'error')
    end
    local ok, result = canAccessFrequency(src, rawFreq)
    if not ok then
        return TriggerClientEvent('fivempro_radio:client:notify', src, result or 'Negalima prisijungti.', 'error')
    end
    local freq = result
    RadioAlias[src] = alias
    setPlayerChannel(src, freq)
    TriggerClientEvent('fivempro_radio:client:voiceJoin', src, freq)
    TriggerClientEvent('fivempro_radio:client:notify', src, ('Prisijungta: %s MHz · %s'):format(
        RadioFreq.format(freq), GetChannelMeta(freq)
    ), 'success')
end)

RegisterNetEvent('fivempro_radio:server:disconnect', function()
    local src = source
    removeFromAllChannels(src)
    TriggerClientEvent('fivempro_radio:client:setChannel', src, nil, nil, nil, false)
    TriggerClientEvent('fivempro_radio:client:voiceLeave', src)
end)

RegisterNetEvent('fivempro_radio:server:validateFrequency', function(rawFreq, alias)
    local src = source
    alias = tostring(alias or ''):gsub('^%s+', ''):gsub('%s+$', ''):sub(1, 32)
    if alias ~= '' then
        RadioAlias[src] = alias
    end
    local ok, result = canAccessFrequency(src, rawFreq)
    if not ok then
        return TriggerClientEvent('fivempro_radio:client:freqDenied', src, result)
    end
    local freq = result
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
    local key = RadioFreq.toKey(freq)
    if not key then return {} end
    return buildMemberList(key)
end)

exports('CanAccessFrequency', function(src, freq)
    local ok = canAccessFrequency(src, freq)
    return ok
end)
