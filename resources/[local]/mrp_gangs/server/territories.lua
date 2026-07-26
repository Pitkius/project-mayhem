local QBCore = GangCore.QBCore

GangTerritories = GangTerritories or {}

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
end

function GangTerritories.GetSnapshot()
    local rows = MySQL.query.await([[
        SELECT t.territory_id, t.territory_type, t.owner_gang_id, t.control_state,
               t.stability, t.heat, t.control_version, t.bonus_json,
               t.controlled_since, t.locked_until,
               g.label AS owner_label, g.color_hex AS owner_color
        FROM mrp_gang_territories t
        LEFT JOIN mrp_gangs_v2 g ON g.id = t.owner_gang_id
        ORDER BY t.territory_type, t.territory_id
    ]]) or {}
    local result = {}
    for _, row in ipairs(rows) do
        local definition = Config.Territories[row.territory_id]
        if definition then
            result[#result + 1] = {
                id = row.territory_id,
                label = definition.label,
                type = row.territory_type,
                vertices = definition.vertices,
                ownerGangId = row.owner_gang_id,
                ownerLabel = row.owner_label,
                ownerColor = row.owner_color,
                state = row.control_state,
                stability = row.stability,
                heat = row.heat,
                version = row.control_version,
                bonuses = definition.bonuses,
                drugProduct = definition.drugProduct,
                controlledSince = row.controlled_since,
                lockedUntil = row.locked_until,
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

QBCore.Functions.CreateCallback('mrp_gangs:server:getTerritories', function(_, callback)
    callback(GangTerritories.GetSnapshot())
end)

QBCore.Functions.CreateCallback('mrp_gangs:server:adminSetTerritoryOwner', function(source, callback, territoryId, gangId)
    if not GangCore.IsAdmin(source) then return callback({ ok = false, reason = 'permission_denied' }) end
    local player = GangCore.GetPlayer(source)
    local ok, reason = GangTerritories.TransferControl(
        territoryId,
        tonumber(gangId),
        'admin_override',
        'admin',
        player and player.PlayerData.citizenid,
        { source = source }
    )
    callback({ ok = ok, reason = reason })
end)

exports('FindTerritoryAt', GangUtils.FindTerritoryAt)
exports('GetTerritory', GangTerritories.Get)
exports('GetTerritories', GangTerritories.GetSnapshot)
exports('CanSellDrug', GangTerritories.CanSellDrug)
exports('IsGangTerritoryOwner', GangTerritories.IsGangOwner)

AddEventHandler('mrp_gangs:server:ready', function()
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
