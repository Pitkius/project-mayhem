--[[
  mrp_gangs — Diplomatija (server)
  Abipusiai santykiai (draugystė/sąjunga) reikalauja priėmimo.
  Vienašaliai (neutrali/įtempti/priešiška/blokuota) — iškart.
  „Karas" — apribotas (valdomas admin/serverio taisyklių), čia nekuriamas.
]]

local QBCore = exports['qb-core']:GetCoreObject()

local function clampStr(s, n)
    s = tostring(s or '')
    if #s > n then s = s:sub(1, n) end
    return s
end

local function upsertRelation(gangId, targetGangId, fields)
    local existing = MySQL.single.await('SELECT id FROM fivempro_gang_relations WHERE gang_id = ? AND target_gang_id = ? LIMIT 1', { gangId, targetGangId })
    if existing then
        MySQL.update.await([[
            UPDATE fivempro_gang_relations
            SET relation_type = ?, status = ?, requested_by = ?, accepted_by = ?, note = ?
            WHERE gang_id = ? AND target_gang_id = ?
        ]], { fields.relation_type, fields.status, fields.requested_by, fields.accepted_by, fields.note, gangId, targetGangId })
    else
        MySQL.insert.await([[
            INSERT INTO fivempro_gang_relations (gang_id, target_gang_id, relation_type, status, requested_by, accepted_by, note)
            VALUES (?, ?, ?, ?, ?, ?, ?)
        ]], { gangId, targetGangId, fields.relation_type, fields.status, fields.requested_by, fields.accepted_by, fields.note })
    end
end

local function notifyGangOnline(gangId, message, ntype)
    local rows = MySQL.query.await('SELECT citizenid FROM fivempro_gang_members WHERE gang_id = ?', { tonumber(gangId) }) or {}
    for _, r in ipairs(rows) do
        local P = QBCore.Functions.GetPlayerByCitizenId(r.citizenid)
        if P then TriggerClientEvent('QBCore:Notify', P.PlayerData.source, message, ntype or 'primary', 8000) end
    end
end

-- ── Siųsti / nustatyti santykį ─────────────────────────────────────
QBCore.Functions.CreateCallback('mrp_gangs:server:org:setRelation', function(src, cb, data)
    if not GangOrg.rateLimit(src, 'relSet', 0.75) then return cb({ ok = false, msg = GangOrg.rateLimitFailMsg(src) }) end
    local ctx = GangOrg.getContextBySource(src)
    if not ctx then return cb({ ok = false, msg = 'Ne gaujoje.' }) end

    data = data or {}
    local targetGangId = tonumber(data.targetGangId)
    if not targetGangId then return cb({ ok = false, msg = 'Neteisinga gauja.' }) end
    if targetGangId == ctx.gangId then return cb({ ok = false, msg = 'Negalima nustatyti santykio su savimi.' }) end

    local rtype = tostring(data.relationType or '')
    local def = Config.GangRelationSet[rtype]
    if not def then return cb({ ok = false, msg = 'Neteisingas santykio tipas.' }) end
    if def.restricted then return cb({ ok = false, msg = 'Karo statusą valdo administracija.' }) end

    local targetGang = MySQL.single.await('SELECT id, name, label FROM fivempro_gangs WHERE id = ? LIMIT 1', { targetGangId })
    if not targetGang then return cb({ ok = false, msg = 'Tikslinė gauja nerasta.' }) end

    local note = clampStr(data.note, 255)
    local st = GangOrg.getStruct(ctx.gangId)
    local myName = st.gang.label or st.gang.name

    if def.mutual then
        -- Draugystė/sąjunga — reikia priėmimo.
        if not (ctx.perms.wildcard or ctx.perms.set['diplomacy.send_offer']) then
            return cb({ ok = false, msg = 'Nėra teisės siųsti pasiūlymų.' })
        end
        upsertRelation(ctx.gangId, targetGangId, {
            relation_type = rtype, status = 'pending',
            requested_by = ctx.member.citizenid, accepted_by = nil, note = note,
        })
        GangOrg.log(ctx.gangId, GangOrg.actor(ctx, src), 'relation_offer_sent', {
            targetType = 'gang', targetId = targetGangId, newValue = { type = rtype },
        })
        notifyGangOnline(targetGangId, ('Gauja „%s" siūlo santykį: %s.'):format(myName, def.label), 'primary')
        TriggerEvent('mrp_gangs:internal:orgChanged', ctx.gangId)
        TriggerEvent('mrp_gangs:internal:orgChanged', targetGangId)
        return cb({ ok = true, msg = 'Pasiūlymas išsiųstas.' })
    else
        -- Vienašalis statusas.
        local needPerm = (rtype == 'hostile') and 'diplomacy.set_hostile'
            or (rtype == 'neutral') and 'diplomacy.set_neutral'
            or 'diplomacy.send_offer'
        if not (ctx.perms.wildcard or ctx.perms.set[needPerm] or ctx.perms.set['diplomacy.send_offer']) then
            return cb({ ok = false, msg = 'Nėra teisės.' })
        end
        upsertRelation(ctx.gangId, targetGangId, {
            relation_type = rtype, status = 'active',
            requested_by = ctx.member.citizenid, accepted_by = ctx.member.citizenid, note = note,
        })
        GangOrg.log(ctx.gangId, GangOrg.actor(ctx, src), 'relation_set', {
            targetType = 'gang', targetId = targetGangId, newValue = { type = rtype },
        })
        TriggerEvent('mrp_gangs:internal:orgChanged', ctx.gangId)
        return cb({ ok = true, msg = 'Santykis nustatytas.' })
    end
end)

-- ── Priimti pasiūlymą ──────────────────────────────────────────────
QBCore.Functions.CreateCallback('mrp_gangs:server:org:acceptRelation', function(src, cb, data)
    if not GangOrg.rateLimit(src, 'relAccept', 0.75) then return cb({ ok = false, msg = GangOrg.rateLimitFailMsg(src) }) end
    local ctx = GangOrg.getContextBySource(src)
    if not ctx then return cb({ ok = false, msg = 'Ne gaujoje.' }) end
    if not (ctx.perms.wildcard or ctx.perms.set['diplomacy.accept_offer']) then return cb({ ok = false, msg = 'Nėra teisės priimti.' }) end

    data = data or {}
    local fromGangId = tonumber(data.fromGangId)
    if not fromGangId then return cb({ ok = false, msg = 'Neteisinga gauja.' }) end

    -- Pasiūlymas: fromGang → mano gauja, status pending.
    local offer = MySQL.single.await('SELECT * FROM fivempro_gang_relations WHERE gang_id = ? AND target_gang_id = ? AND status = ? LIMIT 1', {
        fromGangId, ctx.gangId, 'pending',
    })
    if not offer then return cb({ ok = false, msg = 'Nėra galiojančio pasiūlymo.' }) end

    -- Abi kryptys → active.
    upsertRelation(fromGangId, ctx.gangId, {
        relation_type = offer.relation_type, status = 'active',
        requested_by = offer.requested_by, accepted_by = ctx.member.citizenid, note = offer.note,
    })
    upsertRelation(ctx.gangId, fromGangId, {
        relation_type = offer.relation_type, status = 'active',
        requested_by = offer.requested_by, accepted_by = ctx.member.citizenid, note = offer.note,
    })
    GangOrg.log(ctx.gangId, GangOrg.actor(ctx, src), 'relation_accepted', {
        targetType = 'gang', targetId = fromGangId, newValue = { type = offer.relation_type },
    })
    notifyGangOnline(fromGangId, ('Tavo pasiūlymas priimtas (%s).'):format(Config.GangRelationSet[offer.relation_type] and Config.GangRelationSet[offer.relation_type].label or offer.relation_type), 'success')
    TriggerEvent('mrp_gangs:internal:orgChanged', ctx.gangId)
    TriggerEvent('mrp_gangs:internal:orgChanged', fromGangId)
    cb({ ok = true, msg = 'Santykis patvirtintas.' })
end)

-- ── Atmesti pasiūlymą ──────────────────────────────────────────────
QBCore.Functions.CreateCallback('mrp_gangs:server:org:declineRelation', function(src, cb, data)
    if not GangOrg.rateLimit(src, 'relDecline', 0.75) then return cb({ ok = false, msg = GangOrg.rateLimitFailMsg(src) }) end
    local ctx = GangOrg.getContextBySource(src)
    if not ctx then return cb({ ok = false, msg = 'Ne gaujoje.' }) end
    if not (ctx.perms.wildcard or ctx.perms.set['diplomacy.accept_offer']) then return cb({ ok = false, msg = 'Nėra teisės.' }) end

    data = data or {}
    local fromGangId = tonumber(data.fromGangId)
    if not fromGangId then return cb({ ok = false, msg = 'Neteisinga gauja.' }) end
    MySQL.update.await('DELETE FROM fivempro_gang_relations WHERE gang_id = ? AND target_gang_id = ? AND status = ?', { fromGangId, ctx.gangId, 'pending' })
    GangOrg.log(ctx.gangId, GangOrg.actor(ctx, src), 'relation_declined', { targetType = 'gang', targetId = fromGangId })
    TriggerEvent('mrp_gangs:internal:orgChanged', ctx.gangId)
    TriggerEvent('mrp_gangs:internal:orgChanged', fromGangId)
    cb({ ok = true, msg = 'Pasiūlymas atmestas.' })
end)

-- ── Nutraukti santykį (abi kryptys) ────────────────────────────────
QBCore.Functions.CreateCallback('mrp_gangs:server:org:breakRelation', function(src, cb, data)
    if not GangOrg.rateLimit(src, 'relBreak', 0.75) then return cb({ ok = false, msg = GangOrg.rateLimitFailMsg(src) }) end
    local ctx = GangOrg.getContextBySource(src)
    if not ctx then return cb({ ok = false, msg = 'Ne gaujoje.' }) end
    if not (ctx.perms.wildcard or ctx.perms.set['diplomacy.break']) then return cb({ ok = false, msg = 'Nėra teisės.' }) end

    data = data or {}
    local targetGangId = tonumber(data.targetGangId)
    if not targetGangId then return cb({ ok = false, msg = 'Neteisinga gauja.' }) end

    local rel = MySQL.single.await('SELECT relation_type FROM fivempro_gang_relations WHERE gang_id = ? AND target_gang_id = ? LIMIT 1', { ctx.gangId, targetGangId })
    local wasMutual = rel and Config.GangRelationSet[rel.relation_type] and Config.GangRelationSet[rel.relation_type].mutual

    MySQL.update.await('DELETE FROM fivempro_gang_relations WHERE gang_id = ? AND target_gang_id = ?', { ctx.gangId, targetGangId })
    -- Jei buvo abipusis — nutraukiam ir kitą pusę.
    if wasMutual then
        MySQL.update.await('DELETE FROM fivempro_gang_relations WHERE gang_id = ? AND target_gang_id = ?', { targetGangId, ctx.gangId })
        TriggerEvent('mrp_gangs:internal:orgChanged', targetGangId)
    end
    GangOrg.log(ctx.gangId, GangOrg.actor(ctx, src), 'relation_broken', { targetType = 'gang', targetId = targetGangId })
    TriggerEvent('mrp_gangs:internal:orgChanged', ctx.gangId)
    cb({ ok = true, msg = 'Santykis nutrauktas.' })
end)

-- ── Santykių sąrašas (skaitymui NUI) ───────────────────────────────
function GangOrg.getRelationsView(gangId)
    gangId = tonumber(gangId)
    local rows = MySQL.query.await([[
        SELECT r.target_gang_id, r.relation_type, r.status, r.requested_by, r.accepted_by, r.note, r.created_at, r.updated_at,
               g.name AS target_name, g.label AS target_label, g.color_hex AS target_color, g.emblem AS target_emblem
        FROM fivempro_gang_relations r
        JOIN fivempro_gangs g ON g.id = r.target_gang_id
        WHERE r.gang_id = ?
        ORDER BY r.updated_at DESC
    ]], { gangId }) or {}

    -- Neatsakyti pasiūlymai MUMS (kitos gaujos → mūsų gauja, pending).
    local incoming = MySQL.query.await([[
        SELECT r.gang_id AS from_gang_id, r.relation_type, r.note, r.created_at,
               g.name AS from_name, g.label AS from_label, g.color_hex AS from_color, g.emblem AS from_emblem
        FROM fivempro_gang_relations r
        JOIN fivempro_gangs g ON g.id = r.gang_id
        WHERE r.target_gang_id = ? AND r.status = 'pending'
        ORDER BY r.created_at DESC
    ]], { gangId }) or {}

    return { relations = rows, incomingOffers = incoming }
end
