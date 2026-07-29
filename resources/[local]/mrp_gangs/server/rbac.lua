GangRBAC = GangRBAC or {}
GangRBAC.Cache = {}

local function permissionsToSet(value)
    if value == '*' then return { wildcard = true, set = {} } end
    local result = { wildcard = false, set = {} }
    for _, permission in ipairs(type(value) == 'table' and value or {}) do
        if Config.GangPermissionSet[permission] then result.set[permission] = true end
    end
    return result
end

function GangRBAC.SeedDefaultRoles(gangId)
    gangId = tonumber(gangId)
    if not gangId then return false end
    for _, role in ipairs(Config.DefaultGangRoles or {}) do
        MySQL.update.await([[
            INSERT IGNORE INTO mrp_gang_roles_v2
                (gang_id, role_key, label, priority, is_owner, permissions_json)
            VALUES (?, ?, ?, ?, ?, ?)
        ]], {
            gangId,
            role.key,
            role.label,
            tonumber(role.priority) or 0,
            role.isOwner and 1 or 0,
            json.encode(role.permissions),
        })
    end
    GangRBAC.Invalidate(gangId)
    return true
end

function GangRBAC.Invalidate(gangId)
    if gangId then
        GangRBAC.Cache[tonumber(gangId)] = nil
    else
        GangRBAC.Cache = {}
    end
end

function GangRBAC.GetRole(gangId, roleKey)
    gangId = tonumber(gangId)
    roleKey = tostring(roleKey or '')
    if not gangId or roleKey == '' then return nil end
    local cache = GangRBAC.Cache[gangId]
    if not cache or cache.expiresAt < os.time() then
        cache = { expiresAt = os.time() + 30, roles = {} }
        local rows = MySQL.query.await([[
            SELECT role_key, label, priority, is_owner, permissions_json
            FROM mrp_gang_roles_v2
            WHERE gang_id = ?
        ]], { gangId }) or {}
        for _, row in ipairs(rows) do
            local decoded = json.decode(row.permissions_json or '[]')
            row.permissions = permissionsToSet(decoded)
            cache.roles[row.role_key] = row
        end
        GangRBAC.Cache[gangId] = cache
    end
    return cache.roles[roleKey]
end

function GangRBAC.Resolve(source)
    local gang = GangCore.GetPlayerGang(source)
    if not gang then return nil end

    local role = GangRBAC.GetRole(gang.gang_id, gang.role_key)
    if not role then
        GangRBAC.SeedDefaultRoles(gang.gang_id)
        role = GangRBAC.GetRole(gang.gang_id, gang.role_key)
    end
    --- Boss / owner must never drop out of membership just because roles weren't seeded.
    if not role then
        local isOwner = tostring(gang.owner_citizenid or '') == tostring(gang.citizenid or '')
            or tostring(gang.role_key or '') == 'boss'
        if isOwner then
            role = {
                role_key = 'boss',
                label = 'Bosas',
                priority = 100,
                is_owner = 1,
                permissions = { wildcard = true, set = {} },
            }
        else
            return nil
        end
    end

    local permissions = {
        wildcard = role.permissions.wildcard,
        set = {},
    }
    for key in pairs(role.permissions.set or {}) do permissions.set[key] = true end

    local responsibilities = MySQL.query.await([[
        SELECT responsibility_key
        FROM mrp_gang_member_responsibilities_v2
        WHERE gang_id = ? AND citizenid = ?
    ]], { gang.gang_id, gang.citizenid }) or {}
    for _, row in ipairs(responsibilities) do
        local definition = Config.GangResponsibilities[row.responsibility_key]
        for _, permission in ipairs(definition and definition.extraPermissions or {}) do
            permissions.set[permission] = true
        end
    end

    return {
        gang = gang,
        role = role,
        permissions = permissions,
        responsibilities = responsibilities,
    }
end

function GangRBAC.HasPermission(source, permission)
    if GangCore.IsAdmin(source) then return true end
    if not Config.GangPermissionSet[tostring(permission or '')] then return false end
    local context = GangRBAC.Resolve(source)
    if not context then return false end
    return context.permissions.wildcard or context.permissions.set[permission] == true
end

function GangRBAC.Require(source, permission)
    if GangRBAC.HasPermission(source, permission) then return true end
    GangCore.Notify(source, 'Neturi teisės atlikti šio veiksmo.', 'error')
    return false
end

function GangRBAC.GetRolePriority(gangId, roleKey)
    local role = GangRBAC.GetRole(gangId, roleKey)
    return role and tonumber(role.priority) or -1
end

function GangRBAC.CanManageRole(source, targetRoleKey)
    if GangCore.IsAdmin(source) then return true end
    local context = GangRBAC.Resolve(source)
    if not context or not GangRBAC.HasPermission(source, 'members.set_role') then return false end
    if tonumber(context.role.is_owner) == 1 then return true end
    return tonumber(context.role.priority) > GangRBAC.GetRolePriority(context.gang.gang_id, targetRoleKey)
end

function GangCore.AcquireIdempotency(key, scope, ttlSeconds)
    key = tostring(key or ''):sub(1, 128)
    scope = tostring(scope or ''):sub(1, 48)
    if key == '' or scope == '' then return false end
    local affected = MySQL.update.await([[
        INSERT IGNORE INTO mrp_gang_idempotency (idempotency_key, scope, expires_at)
        VALUES (?, ?, FROM_UNIXTIME(?))
    ]], { key, scope, os.time() + math.max(60, tonumber(ttlSeconds) or 3600) })
    return (tonumber(affected) or 0) > 0
end

function GangCore.CompleteIdempotency(key, result)
    MySQL.update.await([[
        UPDATE mrp_gang_idempotency
        SET result_json = ?
        WHERE idempotency_key = ?
    ]], { result and json.encode(result) or nil, tostring(key or '') })
end

function GangCore.AddReputation(gangId, amount, reason, referenceType, referenceId, actorCitizenId)
    gangId = tonumber(gangId)
    amount = GangUtils.Round(amount)
    if not gangId or amount == 0 then return false end
    return MySQL.transaction.await({
        {
            query = 'UPDATE mrp_gangs_v2 SET reputation = GREATEST(0, reputation + ?) WHERE id = ?',
            values = { amount, gangId },
        },
        {
            query = [[
                INSERT INTO mrp_gang_reputation_ledger
                    (gang_id, amount, reason, reference_type, reference_id, actor_citizenid)
                VALUES (?, ?, ?, ?, ?, ?)
            ]],
            values = {
                gangId,
                amount,
                tostring(reason or 'unknown'):sub(1, 64),
                referenceType,
                referenceId and tostring(referenceId) or nil,
                actorCitizenId,
            },
        },
    }) == true
end

exports('HasGangPermission', GangRBAC.HasPermission)
exports('AddGangReputation', GangCore.AddReputation)

AddEventHandler('mrp_gangs:server:ready', function()
    local gangs = MySQL.query.await('SELECT id FROM mrp_gangs_v2') or {}
    for _, gang in ipairs(gangs) do GangRBAC.SeedDefaultRoles(gang.id) end
    MySQL.update.await('DELETE FROM mrp_gang_idempotency WHERE expires_at IS NOT NULL AND expires_at <= CURRENT_TIMESTAMP')
end)
