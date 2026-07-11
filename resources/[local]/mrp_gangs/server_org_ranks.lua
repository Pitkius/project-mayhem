--[[
  mrp_gangs — Rangų valdymas (server)
  Custom hierarchija (parent_rank_id), permissions, ciklų apsauga.
  Visa validacija serverio pusėje. Owner rangas apsaugotas.
]]

local QBCore = exports['qb-core']:GetCoreObject()

local RANK_NAME_MAX = tonumber(Config.GangRankNameMax) or 32

local function clampStr(s, n)
    s = tostring(s or '')
    if #s > n then s = s:sub(1, n) end
    return s
end

local function sanitizeHex(hex)
    hex = tostring(hex or ''):upper():gsub('%s+', '')
    if hex:match('^#%x%x%x%x%x%x$') then return hex end
    return '#64748B'
end

-- Ar naujas parent nesukuria ciklo (P negali būti R ar R palikuonis).
local function wouldCreateCycle(struct, rankId, newParentId)
    if not newParentId then return false end
    newParentId = tonumber(newParentId)
    rankId = tonumber(rankId)
    if newParentId == rankId then return true end
    -- Einam aukštyn nuo newParent link šaknies; jei sutinkam rankId → ciklas.
    local guard = 0
    local cur = struct.ranks[newParentId]
    while cur and guard < (Config.GangMaxRanks or 15) + 2 do
        if tonumber(cur.id) == rankId then return true end
        cur = cur.parent_rank_id and struct.ranks[tonumber(cur.parent_rank_id)] or nil
        guard = guard + 1
    end
    return false
end

-- Rango vaikų sąrašas.
local function childrenOf(struct, rankId)
    local out = {}
    for _, r in ipairs(struct.rankList) do
        if tonumber(r.parent_rank_id) == tonumber(rankId) then out[#out + 1] = r end
    end
    return out
end

-- ── Sukurti rangą ──────────────────────────────────────────────────
QBCore.Functions.CreateCallback('mrp_gangs:server:org:createRank', function(src, cb, data)
    if not GangOrg.rateLimit(src, 'rankCreate', 0.75) then return cb({ ok = false, msg = 'Per greitai.' }) end
    local ctx = GangOrg.getContextBySource(src)
    if not ctx then return cb({ ok = false, msg = 'Ne gaujoje.' }) end
    if not (ctx.perms.wildcard or ctx.perms.set['ranks.create']) then return cb({ ok = false, msg = 'Nėra teisės.' }) end

    local st = GangOrg.getStruct(ctx.gangId)
    if #st.rankList >= (Config.GangMaxRanks or 15) then
        return cb({ ok = false, msg = ('Pasiektas rangų limitas (%d).'):format(Config.GangMaxRanks or 15) })
    end

    data = data or {}
    local label = clampStr(data.label, RANK_NAME_MAX)
    if label == '' then return cb({ ok = false, msg = 'Reikia pavadinimo.' }) end
    local name = clampStr((data.name and data.name ~= '' and data.name) or label:lower():gsub('%s+', '_'), RANK_NAME_MAX)

    local parentId = data.parentRankId and tonumber(data.parentRankId) or nil
    if parentId then
        local parent = st.ranks[parentId]
        if not parent then return cb({ ok = false, msg = 'Neteisingas viršesnis rangas.' }) end
        if not parent.can_have_children then return cb({ ok = false, msg = 'Šis rangas negali turėti pavaldžių.' }) end
    end

    local priority = math.max(0, math.min(99, tonumber(data.priority) or 30))
    local perms = GangOrg.filterAssignablePerms(ctx, data.permissions or {})

    local newId = MySQL.insert.await([[
        INSERT INTO fivempro_gang_ranks (gang_id, name, label, priority, parent_rank_id, color, icon, permissions, is_owner_rank, can_have_children)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, 0, ?)
    ]], {
        ctx.gangId, name, label, priority, parentId, sanitizeHex(data.color),
        clampStr(data.icon or 'user', 32), json.encode(perms), (data.canHaveChildren ~= false) and 1 or 0,
    })
    if not newId then return cb({ ok = false, msg = 'Nepavyko sukurti.' }) end

    GangOrg.log(ctx.gangId, GangOrg.actor(ctx, src), 'rank_created', {
        targetType = 'rank', targetId = newId, newValue = { label = label, priority = priority },
    })
    TriggerEvent('mrp_gangs:internal:orgChanged', ctx.gangId)
    cb({ ok = true, msg = 'Rangas sukurtas.', rankId = newId })
end)

-- ── Redaguoti rangą (pavadinimas, spalva, ikona, prioritetas) ──────
QBCore.Functions.CreateCallback('mrp_gangs:server:org:editRank', function(src, cb, data)
    if not GangOrg.rateLimit(src, 'rankEdit', 0.5) then return cb({ ok = false, msg = 'Per greitai.' }) end
    local ctx = GangOrg.getContextBySource(src)
    if not ctx then return cb({ ok = false, msg = 'Ne gaujoje.' }) end
    if not (ctx.perms.wildcard or ctx.perms.set['ranks.edit']) then return cb({ ok = false, msg = 'Nėra teisės.' }) end

    data = data or {}
    local st = GangOrg.getStruct(ctx.gangId)
    local rank = data.rankId and st.ranks[tonumber(data.rankId)] or nil
    if not rank then return cb({ ok = false, msg = 'Rangas nerastas.' }) end

    local label = clampStr(data.label or rank.label, RANK_NAME_MAX)
    if label == '' then return cb({ ok = false, msg = 'Reikia pavadinimo.' }) end
    local priority = rank.is_owner_rank and rank.priority or math.max(0, math.min(99, tonumber(data.priority) or rank.priority))
    local canChildren = rank.is_owner_rank and 1 or ((data.canHaveChildren ~= false) and 1 or 0)

    MySQL.update.await('UPDATE fivempro_gang_ranks SET label = ?, color = ?, icon = ?, priority = ?, can_have_children = ? WHERE id = ? AND gang_id = ?', {
        label, sanitizeHex(data.color or rank.color), clampStr(data.icon or rank.icon, 32),
        priority, canChildren, rank.id, ctx.gangId,
    })
    GangOrg.log(ctx.gangId, GangOrg.actor(ctx, src), 'rank_edited', {
        targetType = 'rank', targetId = rank.id, oldValue = { label = rank.label }, newValue = { label = label },
    })
    TriggerEvent('mrp_gangs:internal:orgChanged', ctx.gangId)
    GangOrg.syncAllLegacyRanks(ctx.gangId)
    cb({ ok = true, msg = 'Rangas atnaujintas.' })
end)

-- ── Keisti rango teises (su anti-escalation) ───────────────────────
QBCore.Functions.CreateCallback('mrp_gangs:server:org:setRankPermissions', function(src, cb, data)
    if not GangOrg.rateLimit(src, 'rankPerms', 0.5) then return cb({ ok = false, msg = 'Per greitai.' }) end
    local ctx = GangOrg.getContextBySource(src)
    if not ctx then return cb({ ok = false, msg = 'Ne gaujoje.' }) end
    if not (ctx.perms.wildcard or ctx.perms.set['ranks.edit_permissions']) then return cb({ ok = false, msg = 'Nėra teisės.' }) end

    data = data or {}
    local st = GangOrg.getStruct(ctx.gangId)
    local rank = data.rankId and st.ranks[tonumber(data.rankId)] or nil
    if not rank then return cb({ ok = false, msg = 'Rangas nerastas.' }) end
    if rank.is_owner_rank then return cb({ ok = false, msg = 'Savininko rango teisių keisti negalima.' }) end

    local perms = GangOrg.filterAssignablePerms(ctx, data.permissions or {})
    MySQL.update.await('UPDATE fivempro_gang_ranks SET permissions = ? WHERE id = ? AND gang_id = ?', {
        json.encode(perms), rank.id, ctx.gangId,
    })
    GangOrg.log(ctx.gangId, GangOrg.actor(ctx, src), 'rank_permissions_changed', {
        targetType = 'rank', targetId = rank.id, newValue = perms,
    })
    TriggerEvent('mrp_gangs:internal:orgChanged', ctx.gangId)
    GangOrg.syncAllLegacyRanks(ctx.gangId)
    cb({ ok = true, msg = 'Teisės atnaujintos.' })
end)

-- ── Perkelti rangą hierarchijoje (parent) ──────────────────────────
QBCore.Functions.CreateCallback('mrp_gangs:server:org:setRankParent', function(src, cb, data)
    if not GangOrg.rateLimit(src, 'rankParent', 0.5) then return cb({ ok = false, msg = 'Per greitai.' }) end
    local ctx = GangOrg.getContextBySource(src)
    if not ctx then return cb({ ok = false, msg = 'Ne gaujoje.' }) end
    if not (ctx.perms.wildcard or ctx.perms.set['ranks.reorder']) then return cb({ ok = false, msg = 'Nėra teisės.' }) end

    data = data or {}
    local st = GangOrg.getStruct(ctx.gangId)
    local rank = data.rankId and st.ranks[tonumber(data.rankId)] or nil
    if not rank then return cb({ ok = false, msg = 'Rangas nerastas.' }) end
    if rank.is_owner_rank then return cb({ ok = false, msg = 'Savininko rangas visada šaknyje.' }) end

    local newParentId = data.parentRankId and tonumber(data.parentRankId) or nil
    if newParentId then
        local parent = st.ranks[newParentId]
        if not parent then return cb({ ok = false, msg = 'Neteisingas viršesnis rangas.' }) end
        if not parent.can_have_children then return cb({ ok = false, msg = 'Tas rangas negali turėti pavaldžių.' }) end
        if wouldCreateCycle(st, rank.id, newParentId) then
            return cb({ ok = false, msg = 'Toks perkėlimas sukurtų ciklą.' })
        end
    end

    MySQL.update.await('UPDATE fivempro_gang_ranks SET parent_rank_id = ? WHERE id = ? AND gang_id = ?', {
        newParentId, rank.id, ctx.gangId,
    })
    GangOrg.log(ctx.gangId, GangOrg.actor(ctx, src), 'rank_moved', {
        targetType = 'rank', targetId = rank.id,
        oldValue = rank.parent_rank_id, newValue = newParentId,
    })
    TriggerEvent('mrp_gangs:internal:orgChanged', ctx.gangId)
    cb({ ok = true, msg = 'Hierarchija atnaujinta.' })
end)

-- ── Ištrinti rangą (tuščią; vaikai perkeliami parent'ui) ───────────
QBCore.Functions.CreateCallback('mrp_gangs:server:org:deleteRank', function(src, cb, data)
    if not GangOrg.rateLimit(src, 'rankDelete', 0.75) then return cb({ ok = false, msg = 'Per greitai.' }) end
    local ctx = GangOrg.getContextBySource(src)
    if not ctx then return cb({ ok = false, msg = 'Ne gaujoje.' }) end
    if not (ctx.perms.wildcard or ctx.perms.set['ranks.delete']) then return cb({ ok = false, msg = 'Nėra teisės.' }) end

    data = data or {}
    local st = GangOrg.getStruct(ctx.gangId)
    local rank = data.rankId and st.ranks[tonumber(data.rankId)] or nil
    if not rank then return cb({ ok = false, msg = 'Rangas nerastas.' }) end
    if rank.is_owner_rank then return cb({ ok = false, msg = 'Savininko rango trinti negalima.' }) end

    local memberCount = MySQL.scalar.await('SELECT COUNT(*) FROM fivempro_gang_members WHERE gang_id = ? AND rank_id = ?', { ctx.gangId, rank.id }) or 0
    if tonumber(memberCount) > 0 then
        return cb({ ok = false, msg = 'Rangas ne tuščias. Pirma perkelk narius.' })
    end

    -- Vaikų rangų perreparentinimas į trinamo rango parent.
    for _, child in ipairs(childrenOf(st, rank.id)) do
        MySQL.update.await('UPDATE fivempro_gang_ranks SET parent_rank_id = ? WHERE id = ?', { rank.parent_rank_id, child.id })
    end
    MySQL.update.await('DELETE FROM fivempro_gang_ranks WHERE id = ? AND gang_id = ? AND is_owner_rank = 0', { rank.id, ctx.gangId })

    GangOrg.log(ctx.gangId, GangOrg.actor(ctx, src), 'rank_deleted', {
        targetType = 'rank', targetId = rank.id, oldValue = { label = rank.label },
    })
    TriggerEvent('mrp_gangs:internal:orgChanged', ctx.gangId)
    cb({ ok = true, msg = 'Rangas ištrintas.' })
end)

-- ── Perkelti visus rango narius į kitą rangą ───────────────────────
QBCore.Functions.CreateCallback('mrp_gangs:server:org:moveRankMembers', function(src, cb, data)
    if not GangOrg.rateLimit(src, 'moveMembers', 1.0) then return cb({ ok = false, msg = 'Per greitai.' }) end
    local ctx = GangOrg.getContextBySource(src)
    if not ctx then return cb({ ok = false, msg = 'Ne gaujoje.' }) end
    if not (ctx.perms.wildcard or ctx.perms.set['ranks.reorder'] or ctx.perms.set['members.move_rank']) then
        return cb({ ok = false, msg = 'Nėra teisės.' })
    end

    data = data or {}
    local st = GangOrg.getStruct(ctx.gangId)
    local fromRank = data.fromRankId and st.ranks[tonumber(data.fromRankId)] or nil
    local toRank = data.toRankId and st.ranks[tonumber(data.toRankId)] or nil
    if not fromRank or not toRank then return cb({ ok = false, msg = 'Neteisingi rangai.' }) end
    if toRank.is_owner_rank then return cb({ ok = false, msg = 'Į savininko rangą perkelti negalima.' }) end

    -- Owner narys nekeičiamas.
    MySQL.update.await([[
        UPDATE fivempro_gang_members SET rank_id = ?
        WHERE gang_id = ? AND rank_id = ? AND citizenid != IFNULL(?, '')
    ]], { toRank.id, ctx.gangId, fromRank.id, st.gang.owner_citizenid })

    GangOrg.log(ctx.gangId, GangOrg.actor(ctx, src), 'rank_members_moved', {
        targetType = 'rank', targetId = fromRank.id, newValue = { to = toRank.label },
    })
    TriggerEvent('mrp_gangs:internal:orgChanged', ctx.gangId)
    GangOrg.syncAllLegacyRanks(ctx.gangId)
    cb({ ok = true, msg = 'Nariai perkelti.' })
end)
