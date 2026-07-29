local QBCore = GangCore.QBCore

GangTerritories = GangTerritories or {}

local function configTerritoryIds()
    local ids = {}
    for territoryId in pairs(Config.Territories or {}) do
        ids[#ids + 1] = territoryId
    end
    return ids
end

local function seedTerritories()
    for territoryId, definition in pairs(Config.Territories or {}) do
        MySQL.update.await([[
            INSERT INTO mrp_gang_territories
                (territory_id, territory_type, control_state, stability, bonus_json)
            VALUES (?, ?, 'neutral', ?, ?)
            ON DUPLICATE KEY UPDATE
                territory_type = VALUES(territory_type),
                bonus_json = VALUES(bonus_json)
        ]], {
            territoryId,
            definition.type,
            Config.TerritoryRules.baseStability or 50,
            json.encode(definition.bonuses or {}),
        })
    end

    local ids = configTerritoryIds()
    if #ids == 0 then return end
    local placeholders = {}
    for i = 1, #ids do placeholders[i] = '?' end
    local inClause = table.concat(placeholders, ',')

    local orphanWars = MySQL.query.await(([[
        SELECT id FROM mrp_gang_wars WHERE territory_id NOT IN (%s)
    ]]):format(inClause), ids) or {}
    if #orphanWars > 0 then
        local warIds = {}
        for i = 1, #orphanWars do warIds[i] = orphanWars[i].id end
        local warPlace = {}
        for i = 1, #warIds do warPlace[i] = '?' end
        MySQL.update.await(('DELETE FROM mrp_gang_wars WHERE id IN (%s)'):format(table.concat(warPlace, ',')), warIds)
        print(('[mrp_gangs] removed %s orphan war(s) for retired territories'):format(#warIds))
    end

    local deleted = MySQL.update.await(([[
        DELETE FROM mrp_gang_territories WHERE territory_id NOT IN (%s)
    ]]):format(inClause), ids)
    if (tonumber(deleted) or 0) > 0 then
        print(('[mrp_gangs] purged %s orphan territory row(s)'):format(deleted))
    end
end

local function countActiveMembersByTerritory()
    local counts = {}
    for _, playerId in ipairs(GetPlayers()) do
        local src = tonumber(playerId)
        if src and GangCore.GetPlayerGang(src) then
            local ped = GetPlayerPed(src)
            if ped and ped ~= 0 then
                local coords = GetEntityCoords(ped)
                local atId = GangUtils.FindTerritoryAt(coords.x, coords.y)
                if atId then
                    counts[atId] = (counts[atId] or 0) + 1
                end
            end
        end
    end
    return counts
end

local function recentWarsByTerritory()
    local rows = MySQL.query.await([[
        SELECT w.id, w.territory_id, w.state, w.settled_at, w.created_at, w.active_ends_at,
               w.attacker_gang_id, w.defender_gang_id, w.winner_gang_id,
               ga.label AS attacker_label, gd.label AS defender_label
        FROM mrp_gang_wars w
        LEFT JOIN mrp_gangs_v2 ga ON ga.id = w.attacker_gang_id
        LEFT JOIN mrp_gangs_v2 gd ON gd.id = w.defender_gang_id
        ORDER BY COALESCE(w.settled_at, w.created_at) DESC
        LIMIT 120
    ]]) or {}
    local byTerritory = {}
    for _, row in ipairs(rows) do
        local list = byTerritory[row.territory_id]
        if not list then
            list = {}
            byTerritory[row.territory_id] = list
        end
        if #list < 3 then
            list[#list + 1] = {
                id = row.id,
                state = row.state,
                settledAt = row.settled_at,
                createdAt = row.created_at,
                activeEndsAt = row.active_ends_at,
                attackerLabel = row.attacker_label,
                defenderLabel = row.defender_label,
                winnerGangId = row.winner_gang_id,
            }
        end
    end
    return byTerritory
end

function GangTerritories.GetSnapshot()
    local rows = MySQL.query.await([[
        SELECT t.territory_id, t.territory_type, t.owner_gang_id, t.control_state,
               t.stability, t.heat, t.control_version, t.bonus_json,
               t.controlled_since, t.locked_until,
               g.label AS owner_label, g.color_hex AS owner_color, g.reputation AS owner_reputation
        FROM mrp_gang_territories t
        LEFT JOIN mrp_gangs_v2 g ON g.id = t.owner_gang_id
        ORDER BY t.territory_type, t.territory_id
    ]]) or {}
    local warsByTerritory = recentWarsByTerritory()
    local membersByTerritory = countActiveMembersByTerritory()
    local result = {}
    for _, row in ipairs(rows) do
        local definition = Config.Territories[row.territory_id]
        if definition then
            local bonuses = definition.bonuses or {}
            local centroid = definition.anchor or GangUtils.PolygonCentroid(definition.vertices)
            result[#result + 1] = {
                id = row.territory_id,
                label = definition.label,
                type = row.territory_type,
                vertices = definition.vertices,
                anchor = centroid,
                ownerGangId = row.owner_gang_id,
                ownerLabel = row.owner_label,
                ownerColor = row.owner_color,
                ownerReputation = row.owner_reputation,
                state = row.control_state,
                stability = row.stability,
                heat = row.heat,
                version = row.control_version,
                bonuses = bonuses,
                hourlyIncome = tonumber(bonuses.hourlyIncome) or 0,
                drugProduct = definition.drugProduct,
                allowsDrugSales = definition.allowsDrugSales == true,
                controlledSince = row.controlled_since,
                lockedUntil = row.locked_until,
                recentWars = warsByTerritory[row.territory_id] or {},
                activeMembersNearby = membersByTerritory[row.territory_id] or 0,
                runtime = definition.runtime == true,
                stock = Config.StockTerritoryIds and Config.StockTerritoryIds[row.territory_id] == true,
            }
        end
    end
    return result
end

function GangTerritories.Get(territoryId)
    local definition = Config.Territories[tostring(territoryId or '')]
    if not definition then return nil end
    local state = MySQL.single.await([[
        SELECT * FROM mrp_gang_territories WHERE territory_id = ? LIMIT 1
    ]], { tostring(territoryId) })
    if not state then return nil end
    return { id = territoryId, definition = definition, state = state }
end

function GangTerritories.TransferControl(territoryId, newOwnerGangId, reason, referenceType, referenceId, metadata)
    local territory = GangTerritories.Get(territoryId)
    if not territory then return false, 'territory_not_found' end
    newOwnerGangId = tonumber(newOwnerGangId)
    if newOwnerGangId then
        local exists = MySQL.scalar.await('SELECT id FROM mrp_gangs_v2 WHERE id = ? AND status = ? LIMIT 1', {
            newOwnerGangId,
            'active',
        })
        if not exists then return false, 'gang_not_found' end
        if reason ~= 'admin_override' then
            local cap = tonumber(
                Config.TerritoryRules.maxOwnedByType
                and Config.TerritoryRules.maxOwnedByType[territory.definition.type]
            ) or 0
            local owned = tonumber(MySQL.scalar.await([[
                SELECT COUNT(*) FROM mrp_gang_territories
                WHERE owner_gang_id = ? AND territory_type = ? AND control_state = 'controlled'
            ]], { newOwnerGangId, territory.definition.type })) or 0
            if cap > 0 and owned >= cap then return false, 'territory_ownership_cap' end
        end
    end
    local previousOwner = tonumber(territory.state.owner_gang_id)
    if previousOwner == newOwnerGangId then return false, 'already_owner' end
    local nextState = newOwnerGangId and 'controlled' or 'neutral'
    local lockUntil = newOwnerGangId and os.time() + (Config.TerritoryRules.ownershipLockSec or 259200) or nil
    local affected = MySQL.update.await([[
        UPDATE mrp_gang_territories
        SET owner_gang_id = ?,
            control_state = ?,
            stability = ?,
            control_version = control_version + 1,
            controlled_since = CASE WHEN ? IS NULL THEN NULL ELSE CURRENT_TIMESTAMP END,
            locked_until = CASE WHEN ? IS NULL THEN NULL ELSE FROM_UNIXTIME(?) END
        WHERE territory_id = ? AND control_version = ?
    ]], {
        newOwnerGangId,
        nextState,
        newOwnerGangId and (Config.TerritoryRules.captureStability or 65) or (Config.TerritoryRules.baseStability or 50),
        newOwnerGangId,
        newOwnerGangId,
        lockUntil,
        territoryId,
        territory.state.control_version,
    })
    if (tonumber(affected) or 0) <= 0 then return false, 'territory_version_conflict' end
    MySQL.insert.await([[
        INSERT INTO mrp_gang_territory_history
            (territory_id, previous_owner_gang_id, new_owner_gang_id, reason, reference_type, reference_id, metadata_json)
        VALUES (?, ?, ?, ?, ?, ?, ?)
    ]], {
        territoryId,
        previousOwner,
        newOwnerGangId,
        tostring(reason or 'control_transfer'):sub(1, 64),
        referenceType,
        referenceId and tostring(referenceId) or nil,
        metadata and json.encode(metadata) or nil,
    })
    TriggerClientEvent('mrp_gangs:client:territoriesUpdated', -1)
    return true
end

function GangTerritories.CanSellDrug(source, itemName, coords)
    local gang = GangCore.GetPlayerGang(source)
    if not gang then return false, 'not_in_gang' end
    if not coords then
        local ped = GetPlayerPed(source)
        if not ped or ped == 0 then return false, 'player_missing' end
        coords = GetEntityCoords(ped)
    end
    local territoryId, definition = GangUtils.FindTerritoryAt(coords.x, coords.y)
    if not territoryId or not definition or not definition.allowsDrugSales then
        return false, 'drug_sales_not_allowed_here'
    end
    local state = MySQL.single.await([[
        SELECT owner_gang_id, control_state, locked_until
        FROM mrp_gang_territories
        WHERE territory_id = ?
        LIMIT 1
    ]], { territoryId })
    if not state or tonumber(state.owner_gang_id) ~= tonumber(gang.gang_id)
        or state.control_state ~= 'controlled' then
        return false, 'gang_does_not_control_territory'
    end
    local productItems = Config.DrugTerritoryItems[definition.drugProduct] or {}
    if not productItems[tostring(itemName or '')] then return false, 'wrong_drug_for_territory' end
    local multiplier = definition.type == 'pvp'
        and (Config.TerritoryRules.pvpDrugMultiplier or 1.18)
        or (Config.TerritoryRules.drugBaseMultiplier or 1.0)
    return true, {
        territoryId = territoryId,
        territoryType = definition.type,
        drugProduct = definition.drugProduct,
        priceMultiplier = multiplier,
    }
end

function GangTerritories.IsGangOwner(gangId, territoryId)
    local owner = MySQL.scalar.await([[
        SELECT owner_gang_id FROM mrp_gang_territories
        WHERE territory_id = ? AND control_state = 'controlled'
        LIMIT 1
    ]], { tostring(territoryId or '') })
    return tonumber(owner) == tonumber(gangId)
end

local function sanitizeVertices(raw)
    local vertices = {}
    if type(raw) ~= 'table' then return nil end
    for _, point in ipairs(raw) do
        if type(point) == 'table' then
            local x = tonumber(point.x)
            local y = tonumber(point.y)
            if x and y then
                vertices[#vertices + 1] = { x = x + 0.0, y = y + 0.0 }
            end
        end
    end
    if #vertices < 3 then return nil end
    if #vertices > 128 then
        while #vertices > 128 do table.remove(vertices) end
    end
    return vertices
end

local function sanitizeTerritoryId(raw)
    local id = tostring(raw or ''):lower():gsub('[^a-z0-9_]', '')
    if #id < 3 or #id > 48 then return nil end
    return id
end

local function territoryOverrideKey(territoryId)
    return 'territory_override:' .. tostring(territoryId)
end

local function saveTerritoryOverride(territoryId, definition, source)
    local player = GangCore.GetPlayer(source)
    local payload = {
        id = territoryId,
        label = definition.label,
        type = definition.type,
        drugProduct = definition.drugProduct,
        allowsDrugSales = definition.allowsDrugSales == true,
        bonuses = definition.bonuses or {},
        vertices = definition.vertices or {},
        anchor = definition.anchor,
        runtime = definition.runtime == true,
    }
    MySQL.update.await([[
        INSERT INTO mrp_gang_admin_settings (setting_key, value_json, updated_by)
        VALUES (?, ?, ?)
        ON DUPLICATE KEY UPDATE value_json = VALUES(value_json), updated_by = VALUES(updated_by)
    ]], {
        territoryOverrideKey(territoryId),
        json.encode(payload),
        player and player.PlayerData.citizenid or nil,
    })
end

local function deleteTerritoryOverride(territoryId)
    MySQL.update.await('DELETE FROM mrp_gang_admin_settings WHERE setting_key = ?', {
        territoryOverrideKey(territoryId),
    })
end

local function applyDefinitionToConfig(territoryId, definition)
    Config.TerritoryPolygons = Config.TerritoryPolygons or {}
    Config.Territories = Config.Territories or {}
    Config.TerritoryPolygons[territoryId] = definition.vertices
    Config.Territories[territoryId] = definition
end

local function broadcastTerritoryDefs(removedIds)
    local defs = {}
    for territoryId, definition in pairs(Config.Territories or {}) do
        defs[territoryId] = {
            label = definition.label,
            type = definition.type,
            drugProduct = definition.drugProduct,
            allowsDrugSales = definition.allowsDrugSales == true,
            bonuses = definition.bonuses or {},
            vertices = definition.vertices or {},
            anchor = definition.anchor,
            runtime = definition.runtime == true,
        }
    end
    TriggerClientEvent('mrp_gangs:client:syncTerritoryDefs', -1, defs, removedIds or {})
    TriggerClientEvent('mrp_gangs:client:territoriesUpdated', -1)
end

function GangTerritories.ApplyOverrideDefinition(payload)
    if type(payload) ~= 'table' then return false end
    local territoryId = sanitizeTerritoryId(payload.id)
    local vertices = sanitizeVertices(payload.vertices)
    if not territoryId or not vertices then return false end
    local territoryType = tostring(payload.type or 'gang')
    if territoryType ~= 'gang' and territoryType ~= 'pvp' and territoryType ~= 'racket' then
        territoryType = 'gang'
    end
    local label = tostring(payload.label or territoryId):gsub('^%s+', ''):gsub('%s+$', '')
    if label == '' then label = territoryId end
    if #label > 64 then label = label:sub(1, 64) end
    local isStock = Config.StockTerritoryIds and Config.StockTerritoryIds[territoryId] == true
    local definition = {
        label = label,
        type = territoryType,
        drugProduct = payload.drugProduct and tostring(payload.drugProduct):sub(1, 32) or nil,
        allowsDrugSales = payload.allowsDrugSales == true,
        bonuses = type(payload.bonuses) == 'table' and payload.bonuses or {},
        vertices = vertices,
        runtime = not isStock,
    }
    definition.anchor = GangUtils.PolygonCentroid(vertices)
    applyDefinitionToConfig(territoryId, definition)
    MySQL.update.await([[
        INSERT INTO mrp_gang_territories
            (territory_id, territory_type, control_state, stability, bonus_json)
        VALUES (?, ?, 'neutral', ?, ?)
        ON DUPLICATE KEY UPDATE
            territory_type = VALUES(territory_type),
            bonus_json = VALUES(bonus_json)
    ]], {
        territoryId,
        territoryType,
        Config.TerritoryRules.baseStability or 50,
        json.encode(definition.bonuses or {}),
    })
    return true, definition
end

function GangTerritories.AdminUpsert(source, payload)
    if not GangCore.IsAdmin(source) then return false, 'permission_denied' end
    payload = type(payload) == 'table' and payload or {}
    local territoryId = sanitizeTerritoryId(payload.id or payload.territoryId)
    local vertices = sanitizeVertices(payload.vertices)
    if not territoryId then return false, 'invalid_id' end
    if not vertices then return false, 'invalid_vertices' end

    local ok, definition = GangTerritories.ApplyOverrideDefinition({
        id = territoryId,
        label = payload.label,
        type = payload.type,
        drugProduct = payload.drugProduct,
        allowsDrugSales = payload.allowsDrugSales,
        bonuses = payload.bonuses,
        vertices = vertices,
    })
    if not ok then return false, 'apply_failed' end

    saveTerritoryOverride(territoryId, definition, source)
    GangCore.Audit({
        actorSource = source,
        action = 'admin_upsert_territory',
        targetType = 'territory',
        targetId = territoryId,
        metadata = {
            label = definition.label,
            type = definition.type,
            vertexCount = #definition.vertices,
            runtime = definition.runtime == true,
        },
    })

    local ownerGangId = tonumber(payload.ownerGangId)
    if payload.ownerGangId ~= nil then
        if ownerGangId and ownerGangId > 0 then
            local transferred, transferReason = GangTerritories.TransferControl(
                territoryId,
                ownerGangId,
                'admin_override',
                'admin',
                nil,
                { source = source }
            )
            if not transferred and transferReason ~= 'already_owner' then
                -- Geometry saved; owner apply failed — still report success for geometry.
                GangCore.Notify(source, ('Turf geometrija išsaugota, bet savininko priskirti nepavyko (%s).'):format(tostring(transferReason)), 'error')
            end
        else
            GangTerritories.AdminReset(territoryId, source, true)
        end
    end

    broadcastTerritoryDefs()
    return true, definition
end

function GangTerritories.AdminDelete(source, territoryId)
    if not GangCore.IsAdmin(source) then return false, 'permission_denied' end
    territoryId = sanitizeTerritoryId(territoryId)
    if not territoryId then return false, 'invalid_id' end
    if Config.StockTerritoryIds and Config.StockTerritoryIds[territoryId] then
        return false, 'stock_territory'
    end
    if not Config.Territories[territoryId] then return false, 'territory_not_found' end

    MySQL.update.await('DELETE FROM mrp_gang_wars WHERE territory_id = ?', { territoryId })
    MySQL.update.await('DELETE FROM mrp_gang_territory_history WHERE territory_id = ?', { territoryId })
    MySQL.update.await('DELETE FROM mrp_gang_territories WHERE territory_id = ?', { territoryId })
    deleteTerritoryOverride(territoryId)
    Config.Territories[territoryId] = nil
    if Config.TerritoryPolygons then Config.TerritoryPolygons[territoryId] = nil end

    GangCore.Audit({
        actorSource = source,
        action = 'admin_delete_territory',
        targetType = 'territory',
        targetId = territoryId,
    })
    broadcastTerritoryDefs({ territoryId })
    return true
end

function GangTerritories.AdminReset(territoryId, source, silent)
    territoryId = tostring(territoryId or '')
    local territory = GangTerritories.Get(territoryId)
    if not territory then return false, 'territory_not_found' end
    local previousOwner = tonumber(territory.state.owner_gang_id)
    MySQL.update.await([[
        UPDATE mrp_gang_territories
        SET owner_gang_id = NULL,
            control_state = 'neutral',
            stability = ?,
            heat = 0,
            control_version = control_version + 1,
            controlled_since = NULL,
            locked_until = NULL
        WHERE territory_id = ?
    ]], { Config.TerritoryRules.baseStability or 50, territoryId })
    MySQL.insert.await([[
        INSERT INTO mrp_gang_territory_history
            (territory_id, previous_owner_gang_id, new_owner_gang_id, reason, reference_type, reference_id, metadata_json)
        VALUES (?, ?, NULL, 'admin_reset', 'admin', ?, ?)
    ]], {
        territoryId,
        previousOwner,
        source and tostring(source) or nil,
        json.encode({ source = source }),
    })
    if not silent then
        TriggerClientEvent('mrp_gangs:client:territoriesUpdated', -1)
    end
    return true
end

function GangTerritories.LoadAdminOverrides()
    local settings = MySQL.query.await([[
        SELECT setting_key, value_json FROM mrp_gang_admin_settings
        WHERE setting_key LIKE 'territory_override:%'
    ]]) or {}
    local loaded = 0
    for _, setting in ipairs(settings) do
        local value = json.decode(setting.value_json or '{}')
        if GangTerritories.ApplyOverrideDefinition(value) then
            loaded = loaded + 1
        end
    end
    if loaded > 0 then
        print(('[mrp_gangs] applied %s admin territory override(s)'):format(loaded))
        broadcastTerritoryDefs()
    end
end

QBCore.Functions.CreateCallback('mrp_gangs:server:getTerritories', function(_, callback)
    callback(GangTerritories.GetSnapshot())
end)

QBCore.Functions.CreateCallback('mrp_gangs:server:adminSetTerritoryOwner', function(source, callback, territoryId, gangId)
    if not GangCore.IsAdmin(source) then return callback({ ok = false, reason = 'permission_denied' }) end
    local player = GangCore.GetPlayer(source)
    local ownerId = tonumber(gangId)
    if not ownerId or ownerId <= 0 then
        local ok, reason = GangTerritories.AdminReset(territoryId, source)
        return callback({ ok = ok, reason = reason })
    end
    local ok, reason = GangTerritories.TransferControl(
        territoryId,
        ownerId,
        'admin_override',
        'admin',
        player and player.PlayerData.citizenid,
        { source = source }
    )
    if not ok and reason == 'already_owner' then
        return callback({ ok = true })
    end
    callback({ ok = ok, reason = reason })
end)

QBCore.Functions.CreateCallback('mrp_gangs:server:adminResetTerritory', function(source, callback, territoryId)
    if not GangCore.IsAdmin(source) then return callback({ ok = false, reason = 'permission_denied' }) end
    local ok, reason = GangTerritories.AdminReset(territoryId, source)
    callback({ ok = ok, reason = reason })
end)

QBCore.Functions.CreateCallback('mrp_gangs:server:adminUpsertTerritory', function(source, callback, payload)
    local ok, result = GangTerritories.AdminUpsert(source, payload)
    if not ok then return callback({ ok = false, reason = result }) end
    callback({ ok = true, territory = result, territories = GangTerritories.GetSnapshot() })
end)

QBCore.Functions.CreateCallback('mrp_gangs:server:adminDeleteTerritory', function(source, callback, territoryId)
    local ok, reason = GangTerritories.AdminDelete(source, territoryId)
    callback({
        ok = ok,
        reason = reason,
        territories = ok and GangTerritories.GetSnapshot() or nil,
    })
end)

exports('FindTerritoryAt', GangUtils.FindTerritoryAt)
exports('GetTerritory', GangTerritories.Get)
exports('GetTerritories', GangTerritories.GetSnapshot)
exports('CanSellDrug', GangTerritories.CanSellDrug)
exports('IsGangTerritoryOwner', GangTerritories.IsGangOwner)

AddEventHandler('mrp_gangs:server:ready', function()
    GangTerritories.LoadAdminOverrides()
    seedTerritories()
end)

CreateThread(function()
    while true do
        Wait((Config.TerritoryRules.racketIncomeIntervalMin or 60) * 60000)
        if GangSystem.Ready then
            local rackets = MySQL.query.await([[
                SELECT territory_id, owner_gang_id
                FROM mrp_gang_territories
                WHERE territory_type = 'racket' AND control_state = 'controlled' AND owner_gang_id IS NOT NULL
            ]]) or {}
            for _, racket in ipairs(rackets) do
                local definition = Config.Territories[racket.territory_id]
                local income = tonumber(definition and definition.bonuses and definition.bonuses.hourlyIncome) or 0
                if income > 0 then
                    MySQL.update.await('UPDATE mrp_gangs_v2 SET treasury = treasury + ? WHERE id = ?', {
                        income,
                        racket.owner_gang_id,
                    })
                    GangCore.Audit({
                        gangId = racket.owner_gang_id,
                        action = 'racket_income',
                        targetType = 'territory',
                        targetId = racket.territory_id,
                        metadata = { amount = income },
                    })
                end
            end
        end
    end
end)
