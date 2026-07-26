GangSystem = GangSystem or {}
GangSystem.Ready = false

local RESOURCE = GetCurrentResourceName()

local function executeSchema()
    local raw = LoadResourceFile(RESOURCE, 'sql/schema_v2.sql')
    if not raw or raw == '' then
        error('[mrp_gangs] sql/schema_v2.sql is missing')
    end

    raw = raw:gsub('%-%-[^\r\n]*', '')
    local executed = 0
    for statement in raw:gmatch('([^;]+)') do
        if statement:match('%S') then
            MySQL.query.await(statement)
            executed = executed + 1
        end
    end
    return executed
end

local function seedSupplyQuotas()
    for quotaKey, quota in pairs(Config.RestrictedSupply or {}) do
        MySQL.insert.await([[
            INSERT IGNORE INTO mrp_gang_supply_quota
                (quota_key, window_started_at, window_days, global_cap, issued_count)
            VALUES (?, CURRENT_TIMESTAMP, ?, ?, 0)
        ]], {
            quotaKey,
            tonumber(quota.rollingDays) or 7,
            tonumber(quota.globalCap) or 0,
        })
    end
end

local function applySafeMigrations()
    local deliveredColumn = MySQL.single.await([[
        SELECT COLUMN_NAME
        FROM information_schema.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE()
          AND TABLE_NAME = 'mrp_gang_mission_rewards'
          AND COLUMN_NAME = 'delivered_at'
        LIMIT 1
    ]])
    if not deliveredColumn then
        MySQL.query.await('ALTER TABLE mrp_gang_mission_rewards ADD COLUMN delivered_at TIMESTAMP NULL AFTER metadata_json')
    end

    local pendingIndex = MySQL.single.await([[
        SELECT INDEX_NAME
        FROM information_schema.STATISTICS
        WHERE TABLE_SCHEMA = DATABASE()
          AND TABLE_NAME = 'mrp_gang_mission_rewards'
          AND INDEX_NAME = 'idx_mrp_gang_mission_rewards_pending'
        LIMIT 1
    ]])
    if not pendingIndex then
        MySQL.query.await([[
            ALTER TABLE mrp_gang_mission_rewards
            ADD KEY idx_mrp_gang_mission_rewards_pending (recipient_type, recipient_id, delivered_at)
        ]])
    end
end

local function recoverInterruptedRuns()
    MySQL.update.await([[
        UPDATE mrp_gang_mission_runs
        SET state = 'failed',
            failure_reason = 'resource_restart',
            finished_at = CURRENT_TIMESTAMP
        WHERE state IN ('reserved', 'active', 'extracting') AND settled_at IS NULL
    ]])
    MySQL.update.await('DELETE FROM mrp_gang_mission_locks')
end

MySQL.ready(function()
    if GangSystem.ContentValid == false then
        print('[mrp_gangs] startup blocked because mission content validation failed.')
        return
    end
    local ok, result = pcall(executeSchema)
    if not ok then
        print(('[mrp_gangs] schema initialization failed: %s'):format(tostring(result)))
        return
    end

    local quotaOk, quotaError = pcall(function()
        applySafeMigrations()
        seedSupplyQuotas()
        recoverInterruptedRuns()
    end)
    if not quotaOk then
        print(('[mrp_gangs] supply quota initialization failed: %s'):format(tostring(quotaError)))
        return
    end

    GangSystem.Ready = true
    print(('[mrp_gangs] Gang System 2.0 mission foundation ready (%s schema statements).'):format(result))
    TriggerEvent('mrp_gangs:server:ready')
end)
