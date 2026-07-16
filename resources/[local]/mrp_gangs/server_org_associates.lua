--[[
  mrp_gangs — Asocijuoti civiliai (server)
  Asocijuotas civilis NĖRA pilnas gaujos narys ir NEGAUNA Dark Net misijos
  praleidimo (tą sprendžia IsInGang/IsGangMember pagal fivempro_gang_members).
]]

local QBCore = exports['qb-core']:GetCoreObject()

local function clampStr(s, n)
    s = tostring(s or '')
    if #s > n then s = s:sub(1, n) end
    return s
end

local function isValidType(t)
    for _, e in ipairs(Config.GangAssociateTypes) do if e.id == t then return true end end
    return false
end

local function isValidStatus(s)
    for _, e in ipairs(Config.GangAssociateStatuses) do if e == s then return true end end
    return false
end

local function getAssoc(gangId, citizenid)
    return MySQL.single.await('SELECT * FROM fivempro_gang_associates WHERE gang_id = ? AND citizenid = ? LIMIT 1', {
        tonumber(gangId), tostring(citizenid or ''),
    })
end

-- ── Pridėti asocijuotą civilį ──────────────────────────────────────
QBCore.Functions.CreateCallback('mrp_gangs:server:org:addAssociate', function(src, cb, data)
    if not GangOrg.rateLimit(src, 'assocAdd', 0.75) then return cb({ ok = false, msg = GangOrg.rateLimitFailMsg(src) }) end
    local ctx = GangOrg.getContextBySource(src)
    if not ctx then return cb({ ok = false, msg = 'Ne gaujoje.' }) end
    if not (ctx.perms.wildcard or ctx.perms.set['associates.add']) then return cb({ ok = false, msg = 'Nėra teisės.' }) end

    data = data or {}
    local targetId = tonumber(data.targetServerId)
    local Target = targetId and QBCore.Functions.GetPlayer(targetId)
    if not Target then return cb({ ok = false, msg = 'Žaidėjas neprisijungęs.' }) end
    local cid = Target.PlayerData.citizenid

    if GangOrg.getMemberRow(cid) then return cb({ ok = false, msg = 'Žaidėjas jau pilnas gaujos narys.' }) end
    if GangOrg.getAssociateRow(cid) then return cb({ ok = false, msg = 'Žaidėjas jau asocijuotas kažkuriai gaujai.' }) end

    local atype = tostring(data.associateType or 'hired')
    if not isValidType(atype) then atype = 'hired' end
    local name = (Target.PlayerData.charinfo.firstname or '') .. ' ' .. (Target.PlayerData.charinfo.lastname or '')

    -- Handler: pagal nutylėjimą pats aktorius, jei nenurodyta kitaip.
    local handler = ctx.member.citizenid
    if data.handlerCitizenid and tostring(data.handlerCitizenid) ~= '' then
        local h = MySQL.scalar.await('SELECT citizenid FROM fivempro_gang_members WHERE gang_id = ? AND citizenid = ? LIMIT 1', { ctx.gangId, tostring(data.handlerCitizenid) })
        if h then handler = h end
    end

    -- Ribotos asocijuoto prieigos (tik assoc.* raktai).
    local access = {}
    if type(data.permissions) == 'table' then
        for _, k in ipairs(data.permissions) do
            if Config.GangAssociateAccessSet[tostring(k)] then access[#access + 1] = tostring(k) end
        end
    end

    MySQL.insert.await([[
        INSERT INTO fivempro_gang_associates (gang_id, citizenid, name, associate_type, handler_citizenid, status, notes, permissions)
        VALUES (?, ?, ?, ?, ?, 'active', ?, ?)
    ]], {
        ctx.gangId, cid, name, atype, handler,
        clampStr(data.notes, tonumber(Config.GangNoteMax) or 300), json.encode(access),
    })
    GangOrg.log(ctx.gangId, GangOrg.actor(ctx, src), 'associate_added', {
        targetType = 'associate', targetId = cid, newValue = { name = name, type = atype },
    })
    TriggerEvent('mrp_gangs:internal:orgChanged', ctx.gangId)
    cb({ ok = true, msg = 'Asocijuotas civilis pridėtas.' })
end)

-- ── Redaguoti asocijuotą (tipas, statusas, handler, pastaba, prieigos) ─
QBCore.Functions.CreateCallback('mrp_gangs:server:org:editAssociate', function(src, cb, data)
    if not GangOrg.rateLimit(src, 'assocEdit', 0.5) then return cb({ ok = false, msg = GangOrg.rateLimitFailMsg(src) }) end
    local ctx = GangOrg.getContextBySource(src)
    if not ctx then return cb({ ok = false, msg = 'Ne gaujoje.' }) end
    if not (ctx.perms.wildcard or ctx.perms.set['associates.edit_status']) then return cb({ ok = false, msg = 'Nėra teisės.' }) end

    data = data or {}
    local assoc = getAssoc(ctx.gangId, data.citizenid)
    if not assoc then return cb({ ok = false, msg = 'Asocijuotas nerastas.' }) end

    local atype = tostring(data.associateType or assoc.associate_type)
    if not isValidType(atype) then atype = assoc.associate_type end
    local status = tostring(data.status or assoc.status)
    if not isValidStatus(status) then status = assoc.status end

    local handler = assoc.handler_citizenid
    if data.handlerCitizenid ~= nil then
        if tostring(data.handlerCitizenid) == '' then
            handler = nil
        else
            local h = MySQL.scalar.await('SELECT citizenid FROM fivempro_gang_members WHERE gang_id = ? AND citizenid = ? LIMIT 1', { ctx.gangId, tostring(data.handlerCitizenid) })
            if h then handler = h end
        end
    end

    local access = {}
    if type(data.permissions) == 'table' then
        for _, k in ipairs(data.permissions) do
            if Config.GangAssociateAccessSet[tostring(k)] then access[#access + 1] = tostring(k) end
        end
    else
        access = nil
    end

    MySQL.update.await([[
        UPDATE fivempro_gang_associates
        SET associate_type = ?, status = ?, handler_citizenid = ?, notes = ?, permissions = ?
        WHERE gang_id = ? AND citizenid = ?
    ]], {
        atype, status, handler,
        clampStr(data.notes ~= nil and data.notes or assoc.notes, tonumber(Config.GangNoteMax) or 300),
        json.encode(access or json.decode(assoc.permissions or '[]')),
        ctx.gangId, assoc.citizenid,
    })
    GangOrg.log(ctx.gangId, GangOrg.actor(ctx, src), 'associate_edited', {
        targetType = 'associate', targetId = assoc.citizenid,
        oldValue = { status = assoc.status, type = assoc.associate_type }, newValue = { status = status, type = atype },
    })
    TriggerEvent('mrp_gangs:internal:orgChanged', ctx.gangId)
    cb({ ok = true, msg = 'Asocijuotas atnaujintas.' })
end)

-- ── Pašalinti asocijuotą ───────────────────────────────────────────
QBCore.Functions.CreateCallback('mrp_gangs:server:org:removeAssociate', function(src, cb, data)
    if not GangOrg.rateLimit(src, 'assocRemove', 0.5) then return cb({ ok = false, msg = GangOrg.rateLimitFailMsg(src) }) end
    local ctx = GangOrg.getContextBySource(src)
    if not ctx then return cb({ ok = false, msg = 'Ne gaujoje.' }) end
    if not (ctx.perms.wildcard or ctx.perms.set['associates.remove']) then return cb({ ok = false, msg = 'Nėra teisės.' }) end

    data = data or {}
    local assoc = getAssoc(ctx.gangId, data.citizenid)
    if not assoc then return cb({ ok = false, msg = 'Asocijuotas nerastas.' }) end

    MySQL.update.await('DELETE FROM fivempro_gang_associates WHERE gang_id = ? AND citizenid = ?', { ctx.gangId, assoc.citizenid })
    GangOrg.log(ctx.gangId, GangOrg.actor(ctx, src), 'associate_removed', {
        targetType = 'associate', targetId = assoc.citizenid, oldValue = { name = assoc.name },
    })
    TriggerEvent('mrp_gangs:internal:orgChanged', ctx.gangId)
    cb({ ok = true, msg = 'Asocijuotas pašalintas.' })
end)

-- ── Paaukštinti asocijuotą į pilną narį (per pakvietimą) ───────────
QBCore.Functions.CreateCallback('mrp_gangs:server:org:promoteAssociate', function(src, cb, data)
    if not GangOrg.rateLimit(src, 'assocPromote', 1.0) then return cb({ ok = false, msg = GangOrg.rateLimitFailMsg(src) }) end
    local ctx = GangOrg.getContextBySource(src)
    if not ctx then return cb({ ok = false, msg = 'Ne gaujoje.' }) end
    if not (ctx.perms.wildcard or ctx.perms.set['associates.promote']) then return cb({ ok = false, msg = 'Nėra teisės.' }) end

    data = data or {}
    local assoc = getAssoc(ctx.gangId, data.citizenid)
    if not assoc then return cb({ ok = false, msg = 'Asocijuotas nerastas.' }) end

    local Target = QBCore.Functions.GetPlayerByCitizenId(assoc.citizenid)
    if not Target then return cb({ ok = false, msg = 'Žaidėjas turi būti prisijungęs paaukštinimui.' }) end

    -- Paaukštinimas = pakvietimas (žaidėjas turi priimti). Asocijuotas įrašas
    -- pašalinamas tik priėmus (respondInvite tai padaro automatiškai).
    local ok, msg = GangOrg.sendInvite(src, Target.PlayerData.source, data.rankId)
    if not ok then return cb({ ok = false, msg = msg }) end
    GangOrg.log(ctx.gangId, GangOrg.actor(ctx, src), 'associate_promotion_offered', {
        targetType = 'associate', targetId = assoc.citizenid,
    })
    cb({ ok = true, msg = 'Pasiūlymas tapti nariu išsiųstas.' })
end)
