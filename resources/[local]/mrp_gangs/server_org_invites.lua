--[[
  mrp_gangs — Narių pakvietimai (server)
  Pasiūlymas → žaidėjas priima/atmeta. Niekada automatiškai neįtraukia.
  Visa validacija serverio pusėje + rate limit + žurnalas.
]]

local QBCore = exports['qb-core']:GetCoreObject()

local pendingInvites = {}   -- [targetSrc] = { gangId, rankId, fromCid, fromName, gangName, expiresAt }
local lastInviteAt = {}     -- [src] = os.clock() (rate limit)

local function now() return os.clock() end

local function actorInfo(ctx, Player)
    return {
        citizenid = Player.PlayerData.citizenid,
        name = (Player.PlayerData.charinfo.firstname or '') .. ' ' .. (Player.PlayerData.charinfo.lastname or ''),
        rank = ctx and ctx.rank and ctx.rank.label or nil,
    }
end

-- Ar kviečiantysis gali siūlyti šį rangą (rangas turi būti žemesnis nei jo, nebent owner/ranks teisė).
local function canOfferRank(ctx, rank)
    if not rank then return false end
    if ctx.isOwner or ctx.perms.wildcard then return true end
    if ctx.perms.set['ranks.assign_leaders'] then return true end
    local myPriority = ctx.rank and ctx.rank.priority or -1
    return (tonumber(rank.priority) or 0) < myPriority
end

-- Pakvietimo sukūrimas (pakartotinai naudoja ir asocijuoto paaukštinimas).
-- Grąžina ok(boolean), msg(string).
function GangOrg.sendInvite(src, targetId, rankId)
    local ctx = GangOrg.getContextBySource(src)
    if not ctx then return false, 'Nepriklausai gaujai.' end
    if not (ctx.perms.wildcard or ctx.perms.set['members.invite']) then
        return false, 'Neturi teisės kviesti narių.'
    end

    targetId = tonumber(targetId)
    local Target = targetId and QBCore.Functions.GetPlayer(targetId)
    if not Target then return false, 'Žaidėjas neprisijungęs.' end
    if targetId == src then return false, 'Savęs pakviesti negalima.' end

    local targetCid = Target.PlayerData.citizenid
    if GangOrg.getMemberRow(targetCid) then return false, 'Žaidėjas jau gaujoje.' end

    local st = GangOrg.getStruct(ctx.gangId)
    if not st then return false, 'Gauja nerasta.' end

    local maxMembers = tonumber(Config.GangMaxMembers) or 0
    if maxMembers > 0 then
        local count = MySQL.scalar.await('SELECT COUNT(*) FROM fivempro_gang_members WHERE gang_id = ?', { ctx.gangId }) or 0
        if tonumber(count) >= maxMembers then return false, 'Gauja pasiekė narių limitą.' end
    end

    local rank = rankId and st.ranks[tonumber(rankId)] or nil
    if not rank then
        local lowest
        for _, r in ipairs(st.rankList) do
            if not r.is_owner_rank and (not lowest or r.priority < lowest.priority) then lowest = r end
        end
        rank = lowest or st.rankList[#st.rankList]
    end
    if not rank then return false, 'Gauja neturi rangų.' end
    if rank.is_owner_rank then return false, 'Negalima kviesti tiesiai į savininko rangą.' end
    if not canOfferRank(ctx, rank) then return false, 'Negali siūlyti šio ar aukštesnio rango.' end

    local Player = QBCore.Functions.GetPlayer(src)
    local fromName = (Player.PlayerData.charinfo.firstname or '') .. ' ' .. (Player.PlayerData.charinfo.lastname or '')

    pendingInvites[targetId] = {
        gangId = ctx.gangId,
        rankId = tonumber(rank.id),
        fromCid = ctx.member.citizenid,
        fromName = fromName,
        gangName = st.gang.label or st.gang.name,
        rankLabel = rank.label,
        expiresAt = now() + (tonumber(Config.GangInviteExpirySec) or 60),
    }

    TriggerClientEvent('mrp_gangs:client:org:invite', targetId, {
        gangName = st.gang.label or st.gang.name,
        fromName = fromName,
        rankLabel = rank.label,
        expirySec = tonumber(Config.GangInviteExpirySec) or 60,
    })
    return true, 'Pakvietimas išsiųstas.'
end

RegisterNetEvent('mrp_gangs:server:org:invitePlayer', function(targetServerId, rankId)
    local src = source
    if lastInviteAt[src] and (now() - lastInviteAt[src]) < 1.5 then return end
    lastInviteAt[src] = now()
    local ok, msg = GangOrg.sendInvite(src, targetServerId, rankId)
    TriggerClientEvent('QBCore:Notify', src, msg, ok and 'success' or 'error')
end)

RegisterNetEvent('mrp_gangs:server:org:respondInvite', function(accept)
    local src = source
    local inv = pendingInvites[src]
    pendingInvites[src] = nil
    if not inv then return end
    if now() > inv.expiresAt then
        return TriggerClientEvent('QBCore:Notify', src, 'Pakvietimas nebegalioja.', 'error')
    end

    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    local cid = Player.PlayerData.citizenid

    if not accept then
        return TriggerClientEvent('QBCore:Notify', src, 'Pakvietimas atmestas.', 'primary')
    end

    -- Pakartotina validacija priėmimo metu (būsena galėjo pasikeisti).
    if GangOrg.getMemberRow(cid) then
        return TriggerClientEvent('QBCore:Notify', src, 'Jau esi gaujoje.', 'error')
    end
    local st = GangOrg.getStruct(inv.gangId)
    if not st then return TriggerClientEvent('QBCore:Notify', src, 'Gauja nebeegzistuoja.', 'error') end
    local rank = st.ranks[tonumber(inv.rankId)]
    if not rank then
        rank = st.rankList[#st.rankList]
    end

    local name = (Player.PlayerData.charinfo.firstname or '') .. ' ' .. (Player.PlayerData.charinfo.lastname or '')
    MySQL.insert.await([[
        INSERT INTO fivempro_gang_members (gang_id, citizenid, name, rank, rank_id, status, invited_by, last_active)
        VALUES (?, ?, ?, ?, ?, 'active', ?, CURRENT_TIMESTAMP)
    ]], { inv.gangId, cid, name, 1, rank and tonumber(rank.id) or nil, inv.fromCid })

    -- Jei buvo asocijuotas — pašalinam iš asocijuotų (dabar pilnas narys).
    MySQL.update.await('DELETE FROM fivempro_gang_associates WHERE gang_id = ? AND citizenid = ?', { inv.gangId, cid })

    GangOrg.syncLegacyRank(inv.gangId, cid)
    GangOrg.log(inv.gangId, { citizenid = inv.fromCid, name = inv.fromName }, 'member_joined', {
        targetType = 'member', targetId = cid,
        newValue = { name = name, rank = rank and rank.label or nil },
    })

    TriggerClientEvent('QBCore:Notify', src, ('Prisijungei prie gaujos %s.'):format(inv.gangName), 'success')
    TriggerEvent('mrp_gangs:internal:orgChanged', inv.gangId)
end)

AddEventHandler('playerDropped', function()
    local src = source
    pendingInvites[src] = nil
    lastInviteAt[src] = nil
end)
