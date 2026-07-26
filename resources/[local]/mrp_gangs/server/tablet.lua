local QBCore = GangCore.QBCore

GangTablet = GangTablet or {}

local function publicGangList()
    return MySQL.query.await([[
        SELECT id, name, label, gang_type, color_hex, reputation, level, heat, status
        FROM mrp_gangs_v2
        WHERE status = 'active'
        ORDER BY label
    ]]) or {}
end

local function topGangs()
    return MySQL.query.await([[
        SELECT g.id, g.label, g.gang_type, g.color_hex, g.reputation, g.level, g.heat,
               (SELECT COUNT(*) FROM mrp_gang_members_v2 m WHERE m.gang_id = g.id AND m.status = 'active') AS members,
               (SELECT COUNT(*) FROM mrp_gang_territories t WHERE t.owner_gang_id = g.id) AS territories
        FROM mrp_gangs_v2 g
        WHERE g.status = 'active'
        ORDER BY g.reputation DESC, g.level DESC
        LIMIT 15
    ]]) or {}
end

local function activityFor(context)
    if not context then return {} end
    if not (context.permissions.wildcard or context.permissions.set['gang.logs']) then return {} end
    return MySQL.query.await([[
        SELECT id, actor_citizenid, action, target_type, target_id, metadata_json, created_at
        FROM mrp_gang_audit_log
        WHERE gang_id = ?
        ORDER BY id DESC
        LIMIT 100
    ]], { context.gang.gang_id }) or {}
end

local function progressionFor(gang)
    if not gang then return nil end
    local reputation = tonumber(gang.reputation) or 0
    local levels = {
        { level = 1, required = 0, unlock = 'Easy kontraktai' },
        { level = 2, required = 500, unlock = 'Medium kontraktai' },
        { level = 3, required = 1500, unlock = 'Hard kontraktai' },
        { level = 4, required = 3500, unlock = 'Specializacijos bonusai' },
        { level = 5, required = 7000, unlock = 'Extreme operacijos' },
        { level = 6, required = 12000, unlock = 'Weekly finale' },
    }
    local current = 1
    local nextRequired = nil
    for _, level in ipairs(levels) do
        if reputation >= level.required then current = level.level else nextRequired = nextRequired or level.required end
    end
    return {
        reputation = reputation,
        level = current,
        nextRequired = nextRequired,
        levels = levels,
    }
end

local function adminView(source)
    if not GangCore.IsAdmin(source) then return nil end
    local missions = {}
    for key, mission in pairs(Config.Missions or {}) do
        missions[#missions + 1] = { id = key, label = mission.label, enabled = mission.enabled == true }
    end
    table.sort(missions, function(left, right) return left.label < right.label end)
    return {
        missions = missions,
        gangs = MySQL.query.await([[
            SELECT id, name, label, gang_type, reputation, level, heat, treasury, status, created_at
            FROM mrp_gangs_v2 ORDER BY id DESC
        ]]) or {},
        activeWars = MySQL.query.await([[
            SELECT id, attacker_gang_id, defender_gang_id, territory_id, state,
                   attacker_score, defender_score, active_starts_at, active_ends_at
            FROM mrp_gang_wars
            WHERE state IN ('preparation','active','settlement')
            ORDER BY created_at DESC
        ]]) or {},
        quotas = MySQL.query.await('SELECT * FROM mrp_gang_supply_quota ORDER BY quota_key') or {},
        missionStats = MySQL.query.await([[
            SELECT mission_key, difficulty, state, COUNT(*) AS runs,
                   AVG(TIMESTAMPDIFF(SECOND, started_at, finished_at)) AS avg_seconds
            FROM mrp_gang_mission_runs
            WHERE started_at >= DATE_SUB(CURRENT_TIMESTAMP, INTERVAL 30 DAY)
            GROUP BY mission_key, difficulty, state
            ORDER BY runs DESC
        ]]) or {},
        recentAudit = MySQL.query.await([[
            SELECT id, gang_id, actor_citizenid, actor_source, action, target_type,
                   target_id, metadata_json, created_at
            FROM mrp_gang_audit_log
            ORDER BY id DESC LIMIT 150
        ]]) or {},
    }
end

function GangTablet.GetBootstrap(source)
    local context = GangRBAC.Resolve(source)
    local organization = context and GangOrganization.GetView(source) or nil
    local gang = context and context.gang or nil
    local invites = {}
    if not gang then
        local player = GangCore.GetPlayer(source)
        if player then
            invites = MySQL.query.await([[
                SELECT i.id, i.role_key, i.expires_at, g.label AS gang_label, g.gang_type
                FROM mrp_gang_invites_v2 i
                INNER JOIN mrp_gangs_v2 g ON g.id = i.gang_id
                WHERE i.citizenid = ? AND i.status = 'pending' AND i.expires_at > CURRENT_TIMESTAMP
                ORDER BY i.created_at DESC
            ]], { player.PlayerData.citizenid }) or {}
        end
    end
    local heat = gang and (tonumber(gang.heat) or 0) or 0
    --- UI „įspėjimai“: heat 0–100 → 0–5 lygiai (kaip senoji plansetė).
    local warningLevel = math.max(0, math.min(5, math.floor((heat / 100) * 5 + 0.0001)))
    return {
        organization = organization,
        invites = invites,
        progression = progressionFor(gang),
        territories = GangTerritories.GetSnapshot(),
        missions = gang and GangMissions.GetBoard(source) or { missions = {}, difficulties = Config.Difficulties },
        diplomacy = gang and GangDiplomacy.GetView(gang.gang_id) or {},
        wars = gang and GangWars.GetView(gang.gang_id) or {},
        activity = activityFor(context),
        gangs = publicGangList(),
        topGangs = topGangs(),
        treatyTypes = Config.TreatyTypes,
        missionRoles = Config.MissionRoles,
        permissionGroups = Config.GangPermissionGroups,
        gangTypes = Config.GangTypes,
        allowCreate = Config.AllowPlayerGangCreate == true and not gang,
        warnings = {
            heat = heat,
            level = warningLevel,
            max = 5,
            hint = warningLevel <= 0 and 'Gauja neturi aktyvaus heat / įspėjimų.'
                or warningLevel <= 2 and 'Žemas heat — stebėkite PD dėmesį.'
                or warningLevel <= 4 and 'Aukštas heat — venkite atvirų konfliktų.'
                or 'Kritinis heat — gauja greitai trauks dėmesį.',
        },
        admin = adminView(source),
    }
end

QBCore.Functions.CreateCallback('mrp_gangs:server:createGang', function(source, callback, payload)
    if Config.AllowPlayerGangCreate ~= true and not GangCore.IsAdmin(source) then
        return callback({ ok = false, reason = 'create_disabled' })
    end
    if not GangCore.RateLimit(source, 'tablet_create_gang', 5) then
        return callback({ ok = false, reason = 'rate_limited' })
    end
    payload = type(payload) == 'table' and payload or {}
    local ok, result = GangCore.CreateGang(
        source,
        payload.gangType,
        payload.name,
        payload.label,
        payload.colorHex
    )
    if not ok then return callback({ ok = false, reason = result }) end
    GangCore.Notify(source, ('Gauja „%s“ sukurta.'):format(result.label), 'success')
    callback({ ok = true, result = result })
end)

local function saveSetting(key, value, source)
    local player = GangCore.GetPlayer(source)
    MySQL.update.await([[
        INSERT INTO mrp_gang_admin_settings (setting_key, value_json, updated_by)
        VALUES (?, ?, ?)
        ON DUPLICATE KEY UPDATE value_json = VALUES(value_json), updated_by = VALUES(updated_by)
    ]], { key, json.encode(value), player and player.PlayerData.citizenid or nil })
end

QBCore.Functions.CreateCallback('mrp_gangs:server:getTabletBootstrap', function(source, callback)
    if not GangCore.RateLimit(source, 'tablet_bootstrap', 1) then return callback(nil) end
    callback(GangTablet.GetBootstrap(source))
end)

QBCore.Functions.CreateCallback('mrp_gangs:server:canOpenTablet', function(source, callback)
    callback(GangCore.IsAdmin(source) or GangAdapters.Inventory.Has(source, Config.TabletItem, 1))
end)

QBCore.Functions.CreateCallback('mrp_gangs:server:adminSetMissionState', function(source, callback, missionKey, enabled)
    if not GangCore.IsAdmin(source) then return callback({ ok = false, reason = 'permission_denied' }) end
    local mission = Config.Missions[tostring(missionKey or '')]
    if not mission then return callback({ ok = false, reason = 'mission_not_found' }) end
    mission.enabled = enabled == true
    saveSetting('mission:' .. mission.id, { enabled = mission.enabled }, source)
    GangCore.Audit({
        actorSource = source,
        action = 'admin_mission_state',
        targetType = 'mission',
        targetId = mission.id,
        metadata = { enabled = mission.enabled },
    })
    callback({ ok = true })
end)

QBCore.Functions.CreateCallback('mrp_gangs:server:adminUpdateTerritoryBonus', function(source, callback, territoryId, bonuses)
    if not GangCore.IsAdmin(source) then return callback({ ok = false, reason = 'permission_denied' }) end
    local definition = Config.Territories[tostring(territoryId or '')]
    if not definition or type(bonuses) ~= 'table' then return callback({ ok = false, reason = 'territory_not_found' }) end
    local sanitized = {}
    for key, value in pairs(bonuses) do
        if type(key) == 'string' and type(value) == 'number' then
            sanitized[key:sub(1, 48)] = GangUtils.Clamp(value, 0, 100000)
        end
    end
    definition.bonuses = sanitized
    MySQL.update.await('UPDATE mrp_gang_territories SET bonus_json = ? WHERE territory_id = ?', {
        json.encode(sanitized),
        territoryId,
    })
    saveSetting('territory_bonus:' .. territoryId, sanitized, source)
    TriggerClientEvent('mrp_gangs:client:territoriesUpdated', -1)
    callback({ ok = true })
end)

QBCore.Functions.CreateCallback('mrp_gangs:server:adminCancelWar', function(source, callback, warId)
    if not GangCore.IsAdmin(source) then return callback({ ok = false, reason = 'permission_denied' }) end
    local war = MySQL.single.await([[
        SELECT * FROM mrp_gang_wars
        WHERE id = ? AND state IN ('preparation','active','settlement')
        LIMIT 1
    ]], { tonumber(warId) })
    if not war then return callback({ ok = false, reason = 'war_not_found' }) end
    MySQL.update.await([[
        UPDATE mrp_gang_wars SET state = 'cancelled', settled_at = CURRENT_TIMESTAMP WHERE id = ?
    ]], { war.id })
    MySQL.update.await([[
        UPDATE mrp_gang_territories SET control_state = 'controlled', locked_until = NULL
        WHERE territory_id = ?
    ]], { war.territory_id })
    TriggerClientEvent('mrp_gangs:client:warsUpdated', -1)
    TriggerClientEvent('mrp_gangs:client:territoriesUpdated', -1)
    callback({ ok = true })
end)

QBCore.Functions.CreateCallback('mrp_gangs:server:adminSetGangStatus', function(source, callback, gangId, status)
    if not GangCore.IsAdmin(source) then return callback({ ok = false, reason = 'permission_denied' }) end
    status = tostring(status or '')
    if status ~= 'active' and status ~= 'suspended' and status ~= 'archived' then
        return callback({ ok = false, reason = 'invalid_status' })
    end
    MySQL.update.await('UPDATE mrp_gangs_v2 SET status = ? WHERE id = ?', { status, tonumber(gangId) })
    callback({ ok = true })
end)

AddEventHandler('mrp_gangs:server:ready', function()
    local settings = MySQL.query.await('SELECT setting_key, value_json FROM mrp_gang_admin_settings') or {}
    for _, setting in ipairs(settings) do
        local value = json.decode(setting.value_json or '{}')
        local missionKey = setting.setting_key:match('^mission:(.+)$')
        local territoryId = setting.setting_key:match('^territory_bonus:(.+)$')
        if missionKey and Config.Missions[missionKey] and type(value) == 'table' then
            Config.Missions[missionKey].enabled = value.enabled == true
        elseif territoryId and Config.Territories[territoryId] and type(value) == 'table' then
            Config.Territories[territoryId].bonuses = value
        end
    end
end)

if QBCore.Shared.Items[Config.TabletItem] then
    QBCore.Functions.CreateUseableItem(Config.TabletItem, function(source)
        TriggerClientEvent('mrp_gangs:client:openTablet', source)
    end)
end
