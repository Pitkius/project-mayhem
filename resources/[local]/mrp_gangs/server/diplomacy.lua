local QBCore = GangCore.QBCore

GangDiplomacy = GangDiplomacy or {}

local function normalizedPair(left, right)
    left = tonumber(left)
    right = tonumber(right)
    if not left or not right or left == right then return nil end
    return math.min(left, right), math.max(left, right)
end

local function decodeTerms(raw)
    if type(raw) == 'table' then return raw end
    if not raw or raw == '' then return {} end
    local ok, decoded = pcall(json.decode, raw)
    return ok and type(decoded) == 'table' and decoded or {}
end

function GangDiplomacy.GetBetween(gangId, targetGangId)
    local gangA, gangB = normalizedPair(gangId, targetGangId)
    if not gangA then return nil end
    local row = MySQL.single.await([[
        SELECT * FROM mrp_gang_treaties
        WHERE gang_a_id = ? AND gang_b_id = ?
          AND status IN ('pending','active')
          AND (expires_at IS NULL OR expires_at > CURRENT_TIMESTAMP)
        ORDER BY FIELD(status, 'active', 'pending'), updated_at DESC
        LIMIT 1
    ]], { gangA, gangB })
    if row then row.terms = decodeTerms(row.terms_json) end
    return row
end

function GangDiplomacy.GetView(gangId)
    return MySQL.query.await([[
        SELECT t.*,
               ga.label AS gang_a_label, ga.color_hex AS gang_a_color,
               gb.label AS gang_b_label, gb.color_hex AS gang_b_color
        FROM mrp_gang_treaties t
        INNER JOIN mrp_gangs_v2 ga ON ga.id = t.gang_a_id
        INNER JOIN mrp_gangs_v2 gb ON gb.id = t.gang_b_id
        WHERE (t.gang_a_id = ? OR t.gang_b_id = ?)
          AND t.status IN ('pending','active')
          AND (t.expires_at IS NULL OR t.expires_at > CURRENT_TIMESTAMP)
        ORDER BY t.updated_at DESC
    ]], { tonumber(gangId), tonumber(gangId) }) or {}
end

local function validateTerms(treatyType, terms)
    terms = type(terms) == 'table' and terms or {}
    if treatyType == 'tribute' then
        local amount = GangUtils.Clamp(terms.amountPerHour, 1, Config.DiplomacyRules.maxTributePerHour or 5000)
        local payerGangId = tonumber(terms.payerGangId)
        if not payerGangId then return false, 'tribute_payer_required' end
        return true, { amountPerHour = amount, payerGangId = payerGangId }
    end
    if treatyType == 'protection' then
        local protectedGangId = tonumber(terms.protectedGangId)
        if not protectedGangId then return false, 'protected_gang_required' end
        return true, { protectedGangId = protectedGangId }
    end
    return true, terms
end

local function propose(source, targetGangId, treatyType, durationHours, terms)
    if not GangRBAC.Require(source, 'diplomacy.propose') then return false, 'permission_denied' end
    if not GangCore.RateLimit(source, 'diplomacy_propose', Config.DiplomacyRules.proposalCooldownSec or 300) then
        return false, 'proposal_cooldown'
    end
    local context = GangRBAC.Resolve(source)
    targetGangId = tonumber(targetGangId)
    local definition = Config.TreatyTypes[tostring(treatyType or '')]
    if not context or not targetGangId or not definition then return false, 'invalid_treaty' end
    local gangA, gangB = normalizedPair(context.gang.gang_id, targetGangId)
    if not gangA then return false, 'invalid_target' end
    local target = GangCore.GetGangById(targetGangId)
    if not target or target.status ~= 'active' then return false, 'gang_not_found' end
    local existing = GangDiplomacy.GetBetween(gangA, gangB)
    if existing then
        local existingDefinition = Config.TreatyTypes[existing.treaty_type]
        if definition.mutual or (existingDefinition and existingDefinition.mutual) then
            return false, 'treaty_already_exists'
        end
        MySQL.update.await([[
            UPDATE mrp_gang_treaties
            SET status = 'broken', ended_at = CURRENT_TIMESTAMP
            WHERE id = ?
        ]], { existing.id })
    end

    local termsOk, normalizedTerms = validateTerms(treatyType, terms)
    if not termsOk then return false, normalizedTerms end
    if normalizedTerms.payerGangId
        and normalizedTerms.payerGangId ~= gangA and normalizedTerms.payerGangId ~= gangB then
        return false, 'invalid_tribute_payer'
    end
    if normalizedTerms.protectedGangId
        and normalizedTerms.protectedGangId ~= gangA and normalizedTerms.protectedGangId ~= gangB then
        return false, 'invalid_protected_gang'
    end

    durationHours = tonumber(durationHours) or definition.defaultDurationHours or 0
    if durationHours > 0 then
        durationHours = GangUtils.Clamp(
            durationHours,
            Config.DiplomacyRules.minDurationHours or 1,
            Config.DiplomacyRules.maxDurationHours or 720
        )
    end
    local status = definition.mutual and 'pending' or 'active'
    local startsAt = status == 'active' and os.time() or nil
    local expiresAt = durationHours > 0 and os.time() + math.floor(durationHours * 3600) or nil
    local treatyId = MySQL.insert.await([[
        INSERT INTO mrp_gang_treaties
            (gang_a_id, gang_b_id, treaty_type, status, terms_json,
             proposed_by_gang_id, proposed_by_citizenid, accepted_by_citizenid,
             starts_at, expires_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, FROM_UNIXTIME(?), FROM_UNIXTIME(?))
    ]], {
        gangA,
        gangB,
        treatyType,
        status,
        json.encode(normalizedTerms),
        context.gang.gang_id,
        context.gang.citizenid,
        status == 'active' and context.gang.citizenid or nil,
        startsAt,
        expiresAt,
    })
    if not treatyId then return false, 'treaty_create_failed' end
    GangCore.Audit({
        gangId = context.gang.gang_id,
        actorCitizenId = context.gang.citizenid,
        actorSource = source,
        action = status == 'active' and 'treaty_activated' or 'treaty_proposed',
        targetType = 'treaty',
        targetId = treatyId,
        metadata = { targetGangId = targetGangId, treatyType = treatyType, durationHours = durationHours },
    })
    return true, treatyId
end

local function resolveProposal(source, treatyId, accept)
    local permission = accept and 'diplomacy.accept' or 'diplomacy.break'
    if not GangRBAC.Require(source, permission) then return false, 'permission_denied' end
    local context = GangRBAC.Resolve(source)
    local treaty = MySQL.single.await([[
        SELECT * FROM mrp_gang_treaties WHERE id = ? AND status = 'pending' LIMIT 1
    ]], { tonumber(treatyId) })
    if not treaty then return false, 'treaty_not_found' end
    if tonumber(treaty.proposed_by_gang_id) == tonumber(context.gang.gang_id)
        or (tonumber(treaty.gang_a_id) ~= tonumber(context.gang.gang_id)
            and tonumber(treaty.gang_b_id) ~= tonumber(context.gang.gang_id)) then
        return false, 'not_treaty_recipient'
    end
    if accept then
        MySQL.update.await([[
            UPDATE mrp_gang_treaties
            SET status = 'active', accepted_by_citizenid = ?, starts_at = CURRENT_TIMESTAMP
            WHERE id = ? AND status = 'pending'
        ]], { context.gang.citizenid, treaty.id })
    else
        MySQL.update.await([[
            UPDATE mrp_gang_treaties
            SET status = 'declined', ended_at = CURRENT_TIMESTAMP
            WHERE id = ? AND status = 'pending'
        ]], { treaty.id })
    end
    return true
end

local function breakTreaty(source, treatyId)
    if not GangRBAC.Require(source, 'diplomacy.break') then return false, 'permission_denied' end
    local context = GangRBAC.Resolve(source)
    local treaty = MySQL.single.await([[
        SELECT * FROM mrp_gang_treaties
        WHERE id = ? AND status = 'active' AND (gang_a_id = ? OR gang_b_id = ?)
        LIMIT 1
    ]], { tonumber(treatyId), context.gang.gang_id, context.gang.gang_id })
    if not treaty then return false, 'treaty_not_found' end
    MySQL.update.await([[
        UPDATE mrp_gang_treaties SET status = 'broken', ended_at = CURRENT_TIMESTAMP WHERE id = ?
    ]], { treaty.id })
    local definition = Config.TreatyTypes[treaty.treaty_type]
    if definition and (definition.breakPenaltyReputation or 0) > 0 then
        GangCore.AddReputation(
            context.gang.gang_id,
            -definition.breakPenaltyReputation,
            'treaty_broken',
            'treaty',
            treaty.id,
            context.gang.citizenid
        )
    end
    return true
end

function GangDiplomacy.CanDeclareWar(attackerGangId, defenderGangId)
    local treaty = GangDiplomacy.GetBetween(attackerGangId, defenderGangId)
    if not treaty then return false, 'enemy_status_required' end
    local definition = Config.TreatyTypes[treaty.treaty_type]
    if treaty.status == 'active' and definition and definition.blocksWar then return false, 'treaty_blocks_war' end
    if treaty.status ~= 'active' or treaty.treaty_type ~= 'enemy' then return false, 'enemy_status_required' end
    return true
end

function GangDiplomacy.CanPerformHostileAction(attackerGangId, targetGangId)
    local treaty = GangDiplomacy.GetBetween(attackerGangId, targetGangId)
    if not treaty or treaty.status ~= 'active' then return true end
    local definition = Config.TreatyTypes[treaty.treaty_type]
    if definition and (definition.blocksHostileActions or definition.blocksWar) then
        return false, 'treaty_blocks_hostile_action'
    end
    return true
end

QBCore.Functions.CreateCallback('mrp_gangs:server:getDiplomacy', function(source, callback)
    local gang = GangCore.GetPlayerGang(source)
    callback(gang and GangDiplomacy.GetView(gang.gang_id) or {})
end)

QBCore.Functions.CreateCallback('mrp_gangs:server:proposeTreaty', function(source, callback, data)
    data = data or {}
    local ok, result = propose(source, data.targetGangId, data.treatyType, data.durationHours, data.terms)
    callback({ ok = ok, result = result, reason = ok and nil or result })
end)

QBCore.Functions.CreateCallback('mrp_gangs:server:resolveTreaty', function(source, callback, treatyId, accept)
    local ok, reason = resolveProposal(source, treatyId, accept == true)
    callback({ ok = ok, reason = reason })
end)

QBCore.Functions.CreateCallback('mrp_gangs:server:breakTreaty', function(source, callback, treatyId)
    local ok, reason = breakTreaty(source, treatyId)
    callback({ ok = ok, reason = reason })
end)

exports('GetGangTreaty', GangDiplomacy.GetBetween)
exports('CanDeclareGangWar', GangDiplomacy.CanDeclareWar)
exports('CanPerformGangHostileAction', GangDiplomacy.CanPerformHostileAction)

CreateThread(function()
    while true do
        Wait(60000)
        if GangSystem.Ready then
            MySQL.update.await([[
                UPDATE mrp_gang_treaties
                SET status = 'expired', ended_at = CURRENT_TIMESTAMP
                WHERE status IN ('pending','active')
                  AND expires_at IS NOT NULL
                  AND expires_at <= CURRENT_TIMESTAMP
            ]])
        end
    end
end)

CreateThread(function()
    while true do
        Wait(3600000)
        if GangSystem.Ready then
            local tributes = MySQL.query.await([[
                SELECT * FROM mrp_gang_treaties
                WHERE treaty_type = 'tribute' AND status = 'active'
                  AND (expires_at IS NULL OR expires_at > CURRENT_TIMESTAMP)
            ]]) or {}
            for _, treaty in ipairs(tributes) do
                local terms = decodeTerms(treaty.terms_json)
                local payer = tonumber(terms.payerGangId)
                local amount = GangUtils.Clamp(terms.amountPerHour, 1, Config.DiplomacyRules.maxTributePerHour or 5000)
                local receiver = payer == tonumber(treaty.gang_a_id) and tonumber(treaty.gang_b_id) or tonumber(treaty.gang_a_id)
                local affected = MySQL.update.await([[
                    UPDATE mrp_gangs_v2 SET treasury = treasury - ?
                    WHERE id = ? AND treasury >= ?
                ]], { amount, payer, amount })
                if (tonumber(affected) or 0) > 0 then
                    MySQL.update.await('UPDATE mrp_gangs_v2 SET treasury = treasury + ? WHERE id = ?', { amount, receiver })
                    GangCore.Audit({
                        gangId = payer,
                        action = 'tribute_paid',
                        targetType = 'gang',
                        targetId = receiver,
                        metadata = { treatyId = treaty.id, amount = amount },
                    })
                end
            end
        end
    end
end)
