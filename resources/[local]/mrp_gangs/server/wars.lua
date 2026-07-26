local QBCore = GangCore.QBCore

GangWars = GangWars or {}
GangWars.ObjectiveLocks = {}

local function decodeRules(raw)
    if type(raw) == 'table' then return raw end
    local ok, decoded = pcall(json.decode, raw or '{}')
    return ok and type(decoded) == 'table' and decoded or {}
end

local function onlineGangMembers(gangId)
    local result = {}
    local rows = MySQL.query.await([[
        SELECT citizenid, display_name
        FROM mrp_gang_members_v2
        WHERE gang_id = ? AND status = 'active'
        ORDER BY contribution DESC, joined_at ASC
    ]], { tonumber(gangId) }) or {}
    for _, row in ipairs(rows) do
        if GangCore.GetSourceByCitizenId(row.citizenid) then result[#result + 1] = row end
    end
    return result
end

local function activeWarCount(gangId)
    return tonumber(MySQL.scalar.await([[
        SELECT COUNT(*) FROM mrp_gang_wars
        WHERE (attacker_gang_id = ? OR defender_gang_id = ?)
          AND state IN ('declared','preparation','active','settlement')
    ]], { tonumber(gangId), tonumber(gangId) })) or 0
end

local function ownedCount(gangId)
    return tonumber(MySQL.scalar.await([[
        SELECT COUNT(*) FROM mrp_gang_territories
        WHERE owner_gang_id = ? AND control_state = 'controlled'
    ]], { tonumber(gangId) })) or 0
end

local function buildWarRules(attackerGangId, defenderGangId)
    local attackerOwned = ownedCount(attackerGangId)
    local defenderOwned = ownedCount(defenderGangId)
    local attackerUnderdog = defenderOwned > attackerOwned
        and math.min(Config.WarRules.underdogMultiplierMax or 1.25, 1.0 + ((defenderOwned - attackerOwned) * 0.05))
        or 1.0
    local defenderUnderdog = attackerOwned > defenderOwned
        and math.min(Config.WarRules.underdogMultiplierMax or 1.25, 1.0 + ((attackerOwned - defenderOwned) * 0.05))
        or 1.0
    return {
        scoreToWin = Config.WarRules.scoreToWin,
        attackerMultiplier = attackerUnderdog,
        defenderMultiplier = (Config.WarRules.defenderScoreMultiplier or 1.10) * defenderUnderdog,
        attackerOwnedAtDeclaration = attackerOwned,
        defenderOwnedAtDeclaration = defenderOwned,
    }
end

local function seedRoster(warId, gangId)
    local members = onlineGangMembers(gangId)
    local cap = Config.WarRules.maxRosterPerGang or 12
    for index = 1, math.min(#members, cap) do
        local member = members[index]
        MySQL.update.await([[
            INSERT IGNORE INTO mrp_gang_war_roster (war_id, gang_id, citizenid, display_name)
            VALUES (?, ?, ?, ?)
        ]], { warId, gangId, member.citizenid, member.display_name })
    end
end

local function seedObjectives(warId, activeStartsAt)
    local offset = 0
    for objectiveType, definition in pairs(Config.WarRules.objectives or {}) do
        local startsAt = activeStartsAt + offset
        local endsAt = startsAt + (tonumber(definition.durationSec) or 600)
        MySQL.update.await([[
            INSERT INTO mrp_gang_war_objectives
                (war_id, objective_key, objective_type, state, payload_json, starts_at, ends_at)
            VALUES (?, ?, ?, 'pending', ?, FROM_UNIXTIME(?), FROM_UNIXTIME(?))
        ]], {
            warId,
            ('%s_%s'):format(objectiveType, warId),
            objectiveType,
            json.encode({
                label = definition.label,
                attackerPoints = definition.attackerPoints,
                defenderPoints = definition.defenderPoints,
            }),
            startsAt,
            endsAt,
        })
        offset = offset + 120
    end
end

local function declareWar(source, defenderGangId, territoryId)
    if not GangRBAC.Require(source, 'wars.declare') then return false, 'permission_denied' end
    if not GangCore.RateLimit(source, 'war_declaration', 10) then return false, 'rate_limited' end
    local context = GangRBAC.Resolve(source)
    defenderGangId = tonumber(defenderGangId)
    local territory = GangTerritories.Get(territoryId)
    if not context or not defenderGangId or not territory then return false, 'invalid_war_target' end
    if tonumber(context.gang.gang_id) == defenderGangId then return false, 'invalid_war_target' end
    if territory.definition.type == 'racket' then return false, 'racket_requires_economic_campaign' end
    if tonumber(territory.state.owner_gang_id) ~= defenderGangId then return false, 'defender_does_not_own_territory' end
    local territoryLockedUntil = tonumber(MySQL.scalar.await([[
        SELECT UNIX_TIMESTAMP(locked_until)
        FROM mrp_gang_territories
        WHERE territory_id = ?
    ]], { territoryId })) or 0
    if territoryLockedUntil > os.time() then
        return false, 'territory_locked'
    end
    local diplomacyOk, diplomacyReason = GangDiplomacy.CanDeclareWar(context.gang.gang_id, defenderGangId)
    if not diplomacyOk then return false, diplomacyReason end
    if activeWarCount(context.gang.gang_id) >= (Config.WarRules.maxConcurrentWarsPerGang or 1)
        or activeWarCount(defenderGangId) >= (Config.WarRules.maxConcurrentWarsPerGang or 1) then
        return false, 'gang_already_in_war'
    end
    if #onlineGangMembers(context.gang.gang_id) < (Config.WarRules.minOnlinePerGang or 2)
        or #onlineGangMembers(defenderGangId) < (Config.WarRules.minOnlinePerGang or 2) then
        return false, 'not_enough_online_members'
    end

    local preparationStartsAt = os.time()
    local activeStartsAt = preparationStartsAt + (Config.WarRules.preparationSec or 86400)
    local activeEndsAt = activeStartsAt + (Config.WarRules.activeSec or 3600)
    local rules = buildWarRules(context.gang.gang_id, defenderGangId)
    local warId = MySQL.insert.await([[
        INSERT INTO mrp_gang_wars
            (attacker_gang_id, defender_gang_id, territory_id, state, rules_json,
             declared_by_citizenid, preparation_starts_at, active_starts_at, active_ends_at)
        VALUES (?, ?, ?, 'preparation', ?, ?, FROM_UNIXTIME(?), FROM_UNIXTIME(?), FROM_UNIXTIME(?))
    ]], {
        context.gang.gang_id,
        defenderGangId,
        territoryId,
        json.encode(rules),
        context.gang.citizenid,
        preparationStartsAt,
        activeStartsAt,
        activeEndsAt,
    })
    if not warId then return false, 'war_create_failed' end
    seedRoster(warId, context.gang.gang_id)
    seedRoster(warId, defenderGangId)
    seedObjectives(warId, activeStartsAt)
    MySQL.update.await([[
        UPDATE mrp_gang_territories
        SET control_state = 'contested', locked_until = FROM_UNIXTIME(?)
        WHERE territory_id = ?
    ]], { activeEndsAt + (Config.WarRules.settlementSec or 600), territoryId })
    GangCore.Audit({
        gangId = context.gang.gang_id,
        actorCitizenId = context.gang.citizenid,
        actorSource = source,
        action = 'war_declared',
        targetType = 'war',
        targetId = warId,
        metadata = { defenderGangId = defenderGangId, territoryId = territoryId, rules = rules },
    })
    TriggerClientEvent('mrp_gangs:client:warsUpdated', -1)
    return true, warId
end

function GangWars.AddScore(warId, objectiveId, gangId, citizenid, points, reason, idempotencyKey)
    warId = tonumber(warId)
    gangId = tonumber(gangId)
    points = math.floor(tonumber(points) or 0)
    if not warId or not gangId or points <= 0 then return false, 'invalid_score' end
    local war = MySQL.single.await('SELECT * FROM mrp_gang_wars WHERE id = ? AND state = ? LIMIT 1', { warId, 'active' })
    if not war then return false, 'war_not_active' end
    if gangId ~= tonumber(war.attacker_gang_id) and gangId ~= tonumber(war.defender_gang_id) then
        return false, 'gang_not_in_war'
    end
    if citizenid then
        local rostered = MySQL.scalar.await([[
            SELECT citizenid FROM mrp_gang_war_roster
            WHERE war_id = ? AND gang_id = ? AND citizenid = ?
            LIMIT 1
        ]], { warId, gangId, citizenid })
        if not rostered then return false, 'not_on_war_roster' end
    end
    local rules = decodeRules(war.rules_json)
    local multiplier = gangId == tonumber(war.attacker_gang_id)
        and (tonumber(rules.attackerMultiplier) or 1.0)
        or (tonumber(rules.defenderMultiplier) or 1.0)
    local awarded = math.max(1, GangUtils.Round(points * multiplier))
    idempotencyKey = tostring(idempotencyKey or ''):sub(1, 128)
    if idempotencyKey == '' then return false, 'idempotency_required' end
    local inserted = MySQL.insert.await([[
        INSERT IGNORE INTO mrp_gang_war_score_ledger
            (war_id, objective_id, gang_id, citizenid, points, reason, idempotency_key)
        VALUES (?, ?, ?, ?, ?, ?, ?)
    ]], { warId, tonumber(objectiveId), gangId, citizenid, awarded, tostring(reason or 'objective'), idempotencyKey })
    if not inserted or tonumber(inserted) == 0 then return false, 'score_already_recorded' end
    local field = gangId == tonumber(war.attacker_gang_id) and 'attacker_score' or 'defender_score'
    MySQL.update.await(('UPDATE mrp_gang_wars SET %s = %s + ? WHERE id = ? AND state = ?'):format(field, field), {
        awarded,
        warId,
        'active',
    })
    return true, awarded
end

function GangWars.CompleteObjective(warId, objectiveKey, winnerGangId, citizenid, idempotencyKey)
    local objective = MySQL.single.await([[
        SELECT o.*, w.attacker_gang_id, w.defender_gang_id, w.state AS war_state
        FROM mrp_gang_war_objectives o
        INNER JOIN mrp_gang_wars w ON w.id = o.war_id
        WHERE o.war_id = ? AND o.objective_key = ?
        LIMIT 1
    ]], { tonumber(warId), tostring(objectiveKey or '') })
    if not objective or objective.war_state ~= 'active' then return false, 'objective_not_active' end
    if objective.state ~= 'active' and objective.state ~= 'pending' then return false, 'objective_already_resolved' end
    if GangWars.ObjectiveLocks[objective.id] then return false, 'objective_busy' end
    GangWars.ObjectiveLocks[objective.id] = true
    local existingScore = MySQL.scalar.await([[
        SELECT id FROM mrp_gang_war_score_ledger WHERE idempotency_key = ? LIMIT 1
    ]], { tostring(idempotencyKey or '') })
    if existingScore then
        GangWars.ObjectiveLocks[objective.id] = nil
        return false, 'score_already_recorded'
    end
    winnerGangId = tonumber(winnerGangId)
    local payload = decodeRules(objective.payload_json)
    local points = winnerGangId == tonumber(objective.attacker_gang_id)
        and tonumber(payload.attackerPoints)
        or winnerGangId == tonumber(objective.defender_gang_id) and tonumber(payload.defenderPoints)
        or nil
    if not points then
        GangWars.ObjectiveLocks[objective.id] = nil
        return false, 'invalid_objective_winner'
    end
    local affected = MySQL.update.await([[
        UPDATE mrp_gang_war_objectives
        SET state = 'completed',
            attacker_points = ?,
            defender_points = ?,
            completed_at = CURRENT_TIMESTAMP
        WHERE id = ? AND state IN ('pending','active')
    ]], {
        winnerGangId == tonumber(objective.attacker_gang_id) and points or 0,
        winnerGangId == tonumber(objective.defender_gang_id) and points or 0,
        objective.id,
    })
    if (tonumber(affected) or 0) <= 0 then
        GangWars.ObjectiveLocks[objective.id] = nil
        return false, 'objective_version_conflict'
    end
    local ok, result = GangWars.AddScore(
        objective.war_id,
        objective.id,
        winnerGangId,
        citizenid,
        points,
        'war_objective_' .. objective.objective_type,
        idempotencyKey
    )
    if not ok then
        MySQL.update.await([[
            UPDATE mrp_gang_war_objectives
            SET state = 'active', attacker_points = 0, defender_points = 0, completed_at = NULL
            WHERE id = ? AND state = 'completed'
        ]], { objective.id })
    end
    GangWars.ObjectiveLocks[objective.id] = nil
    return ok, result
end

function GangWars.GetView(gangId)
    return MySQL.query.await([[
        SELECT w.*,
               a.label AS attacker_label, a.color_hex AS attacker_color,
               d.label AS defender_label, d.color_hex AS defender_color
        FROM mrp_gang_wars w
        INNER JOIN mrp_gangs_v2 a ON a.id = w.attacker_gang_id
        INNER JOIN mrp_gangs_v2 d ON d.id = w.defender_gang_id
        WHERE w.attacker_gang_id = ? OR w.defender_gang_id = ?
        ORDER BY w.created_at DESC
        LIMIT 30
    ]], { tonumber(gangId), tonumber(gangId) }) or {}
end

function GangWars.GetDetails(gangId, warId)
    local war = MySQL.single.await([[
        SELECT * FROM mrp_gang_wars
        WHERE id = ? AND (attacker_gang_id = ? OR defender_gang_id = ?)
        LIMIT 1
    ]], { tonumber(warId), tonumber(gangId), tonumber(gangId) })
    if not war then return nil end
    war.rules = decodeRules(war.rules_json)
    war.roster = MySQL.query.await([[
        SELECT gang_id, citizenid, display_name, locked_at
        FROM mrp_gang_war_roster
        WHERE war_id = ?
        ORDER BY gang_id, display_name
    ]], { war.id }) or {}
    war.objectives = MySQL.query.await([[
        SELECT id, objective_key, objective_type, state, attacker_points, defender_points,
               payload_json, starts_at, ends_at, completed_at
        FROM mrp_gang_war_objectives
        WHERE war_id = ?
        ORDER BY starts_at, id
    ]], { war.id }) or {}
    return war
end

local function manageRoster(source, warId, citizenid, enabled)
    if not GangRBAC.Require(source, 'wars.manage_roster') then return false, 'permission_denied' end
    local context = GangRBAC.Resolve(source)
    local war = MySQL.single.await([[
        SELECT * FROM mrp_gang_wars
        WHERE id = ? AND state = 'preparation'
          AND (attacker_gang_id = ? OR defender_gang_id = ?)
        LIMIT 1
    ]], { tonumber(warId), context.gang.gang_id, context.gang.gang_id })
    if not war then return false, 'war_roster_locked' end
    local member = MySQL.single.await([[
        SELECT citizenid, display_name
        FROM mrp_gang_members_v2
        WHERE gang_id = ? AND citizenid = ? AND status = 'active'
        LIMIT 1
    ]], { context.gang.gang_id, tostring(citizenid or '') })
    if not member then return false, 'member_not_found' end
    if enabled then
        local count = tonumber(MySQL.scalar.await([[
            SELECT COUNT(*) FROM mrp_gang_war_roster WHERE war_id = ? AND gang_id = ?
        ]], { war.id, context.gang.gang_id })) or 0
        if count >= (Config.WarRules.maxRosterPerGang or 12) then return false, 'war_roster_full' end
        MySQL.update.await([[
            INSERT IGNORE INTO mrp_gang_war_roster (war_id, gang_id, citizenid, display_name)
            VALUES (?, ?, ?, ?)
        ]], { war.id, context.gang.gang_id, member.citizenid, member.display_name })
    else
        MySQL.update.await([[
            DELETE FROM mrp_gang_war_roster
            WHERE war_id = ? AND gang_id = ? AND citizenid = ?
        ]], { war.id, context.gang.gang_id, member.citizenid })
    end
    return true
end

local function settleWar(war)
    if war.state ~= 'settlement' then return false end
    local winner = tonumber(war.defender_gang_id)
    if tonumber(war.attacker_score) > tonumber(war.defender_score) then winner = tonumber(war.attacker_gang_id) end
    local reason = winner == tonumber(war.attacker_gang_id) and 'war_attacker_victory' or 'war_defender_victory'
    if winner == tonumber(war.attacker_gang_id) then
        local ok = GangTerritories.TransferControl(war.territory_id, winner, reason, 'war', war.id, {
            attackerScore = war.attacker_score,
            defenderScore = war.defender_score,
        })
        if not ok then
            winner = tonumber(war.defender_gang_id)
        else
            MySQL.update.await([[
                UPDATE mrp_gang_territories SET locked_until = FROM_UNIXTIME(?) WHERE territory_id = ?
            ]], { os.time() + (Config.WarRules.cooldownSec or 604800), war.territory_id })
        end
    end
    if winner == tonumber(war.defender_gang_id) then
        MySQL.update.await([[
            UPDATE mrp_gang_territories
            SET control_state = 'controlled',
                stability = LEAST(100, stability + 10),
                locked_until = FROM_UNIXTIME(?)
            WHERE territory_id = ?
        ]], { os.time() + (Config.WarRules.cooldownSec or 604800), war.territory_id })
    end
    MySQL.update.await([[
        UPDATE mrp_gang_wars
        SET state = 'completed',
            winner_gang_id = ?,
            settled_at = CURRENT_TIMESTAMP,
            cooldown_until = FROM_UNIXTIME(?)
        WHERE id = ? AND state = 'settlement'
    ]], { winner, os.time() + (Config.WarRules.cooldownSec or 604800), war.id })
    TriggerClientEvent('mrp_gangs:client:warsUpdated', -1)
    TriggerClientEvent('mrp_gangs:client:territoriesUpdated', -1)
    return true
end

QBCore.Functions.CreateCallback('mrp_gangs:server:getWars', function(source, callback)
    local gang = GangCore.GetPlayerGang(source)
    callback(gang and GangWars.GetView(gang.gang_id) or {})
end)

QBCore.Functions.CreateCallback('mrp_gangs:server:declareWar', function(source, callback, defenderGangId, territoryId)
    local ok, result = declareWar(source, defenderGangId, territoryId)
    callback({ ok = ok, result = result, reason = ok and nil or result })
end)

QBCore.Functions.CreateCallback('mrp_gangs:server:getWarDetails', function(source, callback, warId)
    local gang = GangCore.GetPlayerGang(source)
    callback(gang and GangWars.GetDetails(gang.gang_id, warId) or nil)
end)

QBCore.Functions.CreateCallback('mrp_gangs:server:manageWarRoster', function(source, callback, warId, citizenid, enabled)
    local ok, reason = manageRoster(source, warId, citizenid, enabled == true)
    callback({ ok = ok, reason = reason })
end)

exports('AddGangWarScore', GangWars.AddScore)
exports('CompleteGangWarObjective', GangWars.CompleteObjective)

CreateThread(function()
    while true do
        Wait(10000)
        if GangSystem.Ready then
            local now = os.time()
            local wars = MySQL.query.await([[
                SELECT *,
                       UNIX_TIMESTAMP(active_starts_at) AS active_starts_ts,
                       UNIX_TIMESTAMP(active_ends_at) AS active_ends_ts
                FROM mrp_gang_wars
                WHERE state IN ('preparation','active','settlement')
            ]]) or {}
            for _, war in ipairs(wars) do
                local activeStarts = tonumber(war.active_starts_ts) or 0
                local activeEnds = tonumber(war.active_ends_ts) or 0
                if war.state == 'preparation' and now >= activeStarts then
                    if #onlineGangMembers(war.attacker_gang_id) < (Config.WarRules.minOnlinePerGang or 2)
                        or #onlineGangMembers(war.defender_gang_id) < (Config.WarRules.minOnlinePerGang or 2) then
                        MySQL.update.await('UPDATE mrp_gang_wars SET state = ? WHERE id = ?', { 'cancelled', war.id })
                        MySQL.update.await([[
                            UPDATE mrp_gang_territories
                            SET control_state = 'controlled', locked_until = NULL
                            WHERE territory_id = ?
                        ]], { war.territory_id })
                    else
                        MySQL.update.await('UPDATE mrp_gang_wars SET state = ? WHERE id = ?', { 'active', war.id })
                        MySQL.update.await([[
                            UPDATE mrp_gang_war_objectives
                            SET state = 'active'
                            WHERE war_id = ? AND state = 'pending'
                        ]], { war.id })
                    end
                    TriggerClientEvent('mrp_gangs:client:warsUpdated', -1)
                elseif war.state == 'active' and now >= activeEnds then
                    MySQL.update.await('UPDATE mrp_gang_wars SET state = ? WHERE id = ?', { 'settlement', war.id })
                elseif war.state == 'settlement' and now >= activeEnds + (Config.WarRules.settlementSec or 600) then
                    settleWar(war)
                end
            end
        end
    end
end)
