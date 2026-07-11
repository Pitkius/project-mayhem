--[[
  mrp_gangs — Narių valdymas (server)
  Rangas, kick, suspend, pastabos, atsakomybės, individualios teisės,
  nuosavybės perdavimas. Hierarchijos taisyklės tikrinamos serveryje.
]]

local QBCore = exports['qb-core']:GetCoreObject()

local function clampStr(s, n)
    s = tostring(s or '')
    if #s > n then s = s:sub(1, n) end
    return s
end

-- Ar aktorius gali valdyti tikslinį narį (žemesnis rangas; owner valdo visus).
local function canManageTarget(ctx, st, targetMember)
    if not targetMember then return false, 'Narys nerastas.' end
    if st.gang.owner_citizenid and tostring(targetMember.citizenid) == tostring(st.gang.owner_citizenid) then
        return false, 'Savininko valdyti negalima.'
    end
    if ctx.isOwner or ctx.perms.wildcard then return true end
    local myPriority = ctx.rank and ctx.rank.priority or -1
    local targetRank = targetMember.rank_id and st.ranks[tonumber(targetMember.rank_id)] or nil
    local targetPriority = targetRank and targetRank.priority or 0
    if targetPriority >= myPriority then
        return false, 'Negali valdyti aukštesnio ar lygaus rango nario.'
    end
    return true
end

local function getTargetMember(gangId, citizenid)
    return MySQL.single.await('SELECT * FROM fivempro_gang_members WHERE gang_id = ? AND citizenid = ? LIMIT 1', {
        tonumber(gangId), tostring(citizenid or ''),
    })
end

local function decodeJson(str, fb)
    if type(str) == 'table' then return str end
    if not str or str == '' then return fb end
    local ok, r = pcall(json.decode, str)
    if ok and r ~= nil then return r end
    return fb
end

-- ── Keisti nario rangą (paaukštinti / pažeminti / perkelti) ────────
QBCore.Functions.CreateCallback('mrp_gangs:server:org:setMemberRank', function(src, cb, data)
    if not GangOrg.rateLimit(src, 'setMemberRank', 0.5) then return cb({ ok = false, msg = 'Per greitai.' }) end
    local ctx = GangOrg.getContextBySource(src)
    if not ctx then return cb({ ok = false, msg = 'Ne gaujoje.' }) end
    if not (ctx.perms.wildcard or ctx.perms.set['members.promote'] or ctx.perms.set['members.demote'] or ctx.perms.set['members.move_rank']) then
        return cb({ ok = false, msg = 'Nėra teisės.' })
    end

    data = data or {}
    local st = GangOrg.getStruct(ctx.gangId)
    local target = getTargetMember(ctx.gangId, data.citizenid)
    local can, err = canManageTarget(ctx, st, target)
    if not can then return cb({ ok = false, msg = err }) end

    local newRank = data.rankId and st.ranks[tonumber(data.rankId)] or nil
    if not newRank then return cb({ ok = false, msg = 'Neteisingas rangas.' }) end
    if newRank.is_owner_rank then return cb({ ok = false, msg = 'Į savininko rangą per šį veiksmą negalima.' }) end

    -- Negali priskirti rango, kuris >= tavo prioriteto (nebent owner).
    if not (ctx.isOwner or ctx.perms.wildcard) then
        local myPriority = ctx.rank and ctx.rank.priority or -1
        if (tonumber(newRank.priority) or 0) >= myPriority then
            return cb({ ok = false, msg = 'Negali suteikti tokio ar aukštesnio rango.' })
        end
    end

    local oldRank = target.rank_id and st.ranks[tonumber(target.rank_id)] or nil
    MySQL.update.await('UPDATE fivempro_gang_members SET rank_id = ? WHERE gang_id = ? AND citizenid = ?', {
        newRank.id, ctx.gangId, target.citizenid,
    })
    GangOrg.syncLegacyRank(ctx.gangId, target.citizenid)
    GangOrg.log(ctx.gangId, GangOrg.actor(ctx, src), 'member_rank_changed', {
        targetType = 'member', targetId = target.citizenid,
        oldValue = oldRank and oldRank.label or nil, newValue = newRank.label,
    })
    TriggerEvent('mrp_gangs:internal:orgChanged', ctx.gangId)
    cb({ ok = true, msg = 'Rangas pakeistas.' })
end)

-- ── Išmesti narį ───────────────────────────────────────────────────
QBCore.Functions.CreateCallback('mrp_gangs:server:org:kickMember', function(src, cb, data)
    if not GangOrg.rateLimit(src, 'kickMember', 0.75) then return cb({ ok = false, msg = 'Per greitai.' }) end
    local ctx = GangOrg.getContextBySource(src)
    if not ctx then return cb({ ok = false, msg = 'Ne gaujoje.' }) end
    if not (ctx.perms.wildcard or ctx.perms.set['members.kick']) then return cb({ ok = false, msg = 'Nėra teisės.' }) end

    data = data or {}
    local st = GangOrg.getStruct(ctx.gangId)
    local target = getTargetMember(ctx.gangId, data.citizenid)
    local can, err = canManageTarget(ctx, st, target)
    if not can then return cb({ ok = false, msg = err }) end

    MySQL.update.await('DELETE FROM fivempro_gang_members WHERE gang_id = ? AND citizenid = ?', { ctx.gangId, target.citizenid })
    GangOrg.log(ctx.gangId, GangOrg.actor(ctx, src), 'member_kicked', {
        targetType = 'member', targetId = target.citizenid, oldValue = { name = target.name },
    })
    TriggerEvent('mrp_gangs:internal:orgChanged', ctx.gangId)

    local Target = QBCore.Functions.GetPlayerByCitizenId(target.citizenid)
    if Target then
        TriggerClientEvent('QBCore:Notify', Target.PlayerData.source, ('Pašalintas iš gaujos %s.'):format(st.gang.label or st.gang.name), 'error')
    end
    cb({ ok = true, msg = 'Narys pašalintas.' })
end)

-- ── Suspenduoti / grąžinti narį ────────────────────────────────────
QBCore.Functions.CreateCallback('mrp_gangs:server:org:setMemberStatus', function(src, cb, data)
    if not GangOrg.rateLimit(src, 'memberStatus', 0.5) then return cb({ ok = false, msg = 'Per greitai.' }) end
    local ctx = GangOrg.getContextBySource(src)
    if not ctx then return cb({ ok = false, msg = 'Ne gaujoje.' }) end
    if not (ctx.perms.wildcard or ctx.perms.set['members.suspend']) then return cb({ ok = false, msg = 'Nėra teisės.' }) end

    data = data or {}
    local status = tostring(data.status or '')
    local valid = false
    for _, s in ipairs(Config.GangMemberStatuses) do if s == status then valid = true break end end
    if not valid then return cb({ ok = false, msg = 'Neteisingas statusas.' }) end

    local st = GangOrg.getStruct(ctx.gangId)
    local target = getTargetMember(ctx.gangId, data.citizenid)
    local can, err = canManageTarget(ctx, st, target)
    if not can then return cb({ ok = false, msg = err }) end

    MySQL.update.await('UPDATE fivempro_gang_members SET status = ? WHERE gang_id = ? AND citizenid = ?', {
        status, ctx.gangId, target.citizenid,
    })
    GangOrg.log(ctx.gangId, GangOrg.actor(ctx, src), 'member_status_changed', {
        targetType = 'member', targetId = target.citizenid, oldValue = target.status, newValue = status,
    })
    TriggerEvent('mrp_gangs:internal:orgChanged', ctx.gangId)
    cb({ ok = true, msg = 'Statusas atnaujintas.' })
end)

-- ── Nario pastaba ──────────────────────────────────────────────────
QBCore.Functions.CreateCallback('mrp_gangs:server:org:setMemberNotes', function(src, cb, data)
    if not GangOrg.rateLimit(src, 'memberNotes', 0.5) then return cb({ ok = false, msg = 'Per greitai.' }) end
    local ctx = GangOrg.getContextBySource(src)
    if not ctx then return cb({ ok = false, msg = 'Ne gaujoje.' }) end
    if not (ctx.perms.wildcard or ctx.perms.set['members.edit_notes']) then return cb({ ok = false, msg = 'Nėra teisės.' }) end

    data = data or {}
    local st = GangOrg.getStruct(ctx.gangId)
    local target = getTargetMember(ctx.gangId, data.citizenid)
    if not target then return cb({ ok = false, msg = 'Narys nerastas.' }) end
    local notes = clampStr(data.notes, tonumber(Config.GangNoteMax) or 300)
    MySQL.update.await('UPDATE fivempro_gang_members SET notes = ? WHERE gang_id = ? AND citizenid = ?', {
        notes, ctx.gangId, target.citizenid,
    })
    GangOrg.log(ctx.gangId, GangOrg.actor(ctx, src), 'member_notes_edited', { targetType = 'member', targetId = target.citizenid })
    TriggerEvent('mrp_gangs:internal:orgChanged', ctx.gangId)
    cb({ ok = true, msg = 'Pastaba išsaugota.' })
end)

-- ── Atsakomybės (žymos) ────────────────────────────────────────────
QBCore.Functions.CreateCallback('mrp_gangs:server:org:setMemberResponsibilities', function(src, cb, data)
    if not GangOrg.rateLimit(src, 'memberResp', 0.5) then return cb({ ok = false, msg = 'Per greitai.' }) end
    local ctx = GangOrg.getContextBySource(src)
    if not ctx then return cb({ ok = false, msg = 'Ne gaujoje.' }) end
    if not (ctx.perms.wildcard or ctx.perms.set['members.assign_resp']) then return cb({ ok = false, msg = 'Nėra teisės.' }) end

    data = data or {}
    local st = GangOrg.getStruct(ctx.gangId)
    local target = getTargetMember(ctx.gangId, data.citizenid)
    local can, err = canManageTarget(ctx, st, target)
    if not can then return cb({ ok = false, msg = err }) end

    local resp = {}
    local seen = {}
    if type(data.responsibilities) == 'table' then
        for _, rid in ipairs(data.responsibilities) do
            rid = tostring(rid)
            if Config.IsValidResponsibility(rid) and not seen[rid] then
                resp[#resp + 1] = rid
                seen[rid] = true
            end
        end
    end
    MySQL.update.await('UPDATE fivempro_gang_members SET responsibilities = ? WHERE gang_id = ? AND citizenid = ?', {
        json.encode(resp), ctx.gangId, target.citizenid,
    })
    GangOrg.syncLegacyRank(ctx.gangId, target.citizenid)
    GangOrg.log(ctx.gangId, GangOrg.actor(ctx, src), 'member_responsibilities_changed', {
        targetType = 'member', targetId = target.citizenid, newValue = resp,
    })
    TriggerEvent('mrp_gangs:internal:orgChanged', ctx.gangId)
    cb({ ok = true, msg = 'Atsakomybės atnaujintos.' })
end)

-- ── Individualios teisių išimtys (grant/revoke) — tik owner/wildcard ─
QBCore.Functions.CreateCallback('mrp_gangs:server:org:setMemberOverrides', function(src, cb, data)
    if not GangOrg.rateLimit(src, 'memberOverrides', 0.5) then return cb({ ok = false, msg = 'Per greitai.' }) end
    local ctx = GangOrg.getContextBySource(src)
    if not ctx then return cb({ ok = false, msg = 'Ne gaujoje.' }) end
    -- Individualias išimtis valdo tik owner arba turintis ranks.edit_permissions.
    if not (ctx.isOwner or ctx.perms.wildcard or ctx.perms.set['ranks.edit_permissions']) then
        return cb({ ok = false, msg = 'Nėra teisės.' })
    end

    data = data or {}
    local st = GangOrg.getStruct(ctx.gangId)
    local target = getTargetMember(ctx.gangId, data.citizenid)
    local can, err = canManageTarget(ctx, st, target)
    if not can then return cb({ ok = false, msg = err }) end

    local grant = GangOrg.filterAssignablePerms(ctx, data.grant or {})
    local revoke = {}
    if type(data.revoke) == 'table' then
        for _, k in ipairs(data.revoke) do
            if Config.IsValidGangPermission(k) then revoke[#revoke + 1] = tostring(k) end
        end
    end
    MySQL.update.await('UPDATE fivempro_gang_members SET permission_overrides = ? WHERE gang_id = ? AND citizenid = ?', {
        json.encode({ grant = grant, revoke = revoke }), ctx.gangId, target.citizenid,
    })
    GangOrg.syncLegacyRank(ctx.gangId, target.citizenid)
    GangOrg.log(ctx.gangId, GangOrg.actor(ctx, src), 'member_overrides_changed', {
        targetType = 'member', targetId = target.citizenid, newValue = { grant = grant, revoke = revoke },
    })
    TriggerEvent('mrp_gangs:internal:orgChanged', ctx.gangId)
    cb({ ok = true, msg = 'Individualios teisės atnaujintos.' })
end)

-- ── Nuosavybės perdavimas (reikia patvirtinimo) ────────────────────
QBCore.Functions.CreateCallback('mrp_gangs:server:org:transferOwnership', function(src, cb, data)
    if not GangOrg.rateLimit(src, 'transferOwner', 3.0) then return cb({ ok = false, msg = 'Per greitai.' }) end
    local ctx = GangOrg.getContextBySource(src)
    if not ctx then return cb({ ok = false, msg = 'Ne gaujoje.' }) end
    if not ctx.isOwner then return cb({ ok = false, msg = 'Tik savininkas gali perduoti nuosavybę.' }) end

    data = data or {}
    if data.confirm ~= true then return cb({ ok = false, msg = 'Reikia patvirtinimo.' }) end

    local st = GangOrg.getStruct(ctx.gangId)
    local target = getTargetMember(ctx.gangId, data.citizenid)
    if not target then return cb({ ok = false, msg = 'Narys nerastas.' }) end
    if tostring(target.citizenid) == tostring(st.gang.owner_citizenid) then
        return cb({ ok = false, msg = 'Jau savininkas.' })
    end

    local ownerRank = GangOrg.getOwnerRank(ctx.gangId)
    if not ownerRank then return cb({ ok = false, msg = 'Nėra savininko rango.' }) end

    -- Antras pagal prioritetą rangas senam savininkui.
    local secondRank
    for _, r in ipairs(st.rankList) do
        if not r.is_owner_rank and (not secondRank or r.priority > secondRank.priority) then secondRank = r end
    end

    -- Transakcija: perkelti nuosavybę saugiai.
    local queries = {
        { query = 'UPDATE fivempro_gangs SET owner_citizenid = ? WHERE id = ?', values = { target.citizenid, ctx.gangId } },
        { query = 'UPDATE fivempro_gang_members SET rank_id = ? WHERE gang_id = ? AND citizenid = ?', values = { ownerRank.id, ctx.gangId, target.citizenid } },
    }
    if secondRank then
        queries[#queries + 1] = { query = 'UPDATE fivempro_gang_members SET rank_id = ? WHERE gang_id = ? AND citizenid = ?', values = { secondRank.id, ctx.gangId, st.gang.owner_citizenid } }
    end
    local ok = MySQL.transaction.await(queries)
    if not ok then return cb({ ok = false, msg = 'Nepavyko perduoti nuosavybės.' }) end

    GangOrg.log(ctx.gangId, GangOrg.actor(ctx, src), 'ownership_transferred', {
        targetType = 'member', targetId = target.citizenid,
        oldValue = st.gang.owner_citizenid, newValue = target.citizenid,
    })
    TriggerEvent('mrp_gangs:internal:orgChanged', ctx.gangId)
    GangOrg.syncAllLegacyRanks(ctx.gangId)

    local Target = QBCore.Functions.GetPlayerByCitizenId(target.citizenid)
    if Target then
        TriggerClientEvent('QBCore:Notify', Target.PlayerData.source, ('Tapai gaujos %s savininku.'):format(st.gang.label or st.gang.name), 'success')
    end
    cb({ ok = true, msg = 'Nuosavybė perduota.' })
end)
