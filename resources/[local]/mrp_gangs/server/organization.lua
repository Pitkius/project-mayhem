local QBCore = GangCore.QBCore

GangOrganization = GangOrganization or {}

local function playerDisplayName(player)
    local info = player and player.PlayerData and player.PlayerData.charinfo or {}
    local name = (tostring(info.firstname or '') .. ' ' .. tostring(info.lastname or '')):gsub('^%s+', ''):gsub('%s+$', '')
    return name ~= '' and name or tostring(player.PlayerData.citizenid)
end

local function roleExists(gangId, roleKey)
    return MySQL.scalar.await([[
        SELECT id FROM mrp_gang_roles_v2 WHERE gang_id = ? AND role_key = ? LIMIT 1
    ]], { tonumber(gangId), tostring(roleKey or '') }) ~= nil
end

function GangOrganization.GetView(source)
    local context = GangRBAC.Resolve(source)
    if not context then return nil end
    local gangId = context.gang.gang_id
    local members = MySQL.query.await([[
        SELECT citizenid, display_name, role_key, status, contribution, joined_at, last_seen_at
        FROM mrp_gang_members_v2
        WHERE gang_id = ?
        ORDER BY FIELD(role_key, 'boss','underboss','lieutenant','member','prospect'), joined_at
    ]], { gangId }) or {}
    local roles = MySQL.query.await([[
        SELECT role_key, label, priority, is_owner, permissions_json
        FROM mrp_gang_roles_v2
        WHERE gang_id = ?
        ORDER BY priority DESC
    ]], { gangId }) or {}
    for _, role in ipairs(roles) do
        local decoded = {}
        local ok, parsed = pcall(json.decode, role.permissions_json or '[]')
        if ok and type(parsed) == 'table' then
            if parsed == '*' or parsed.wildcard == true then
                role.permissions = { wildcard = true, set = {} }
            else
                local set = {}
                if parsed[1] ~= nil then
                    for _, perm in ipairs(parsed) do set[tostring(perm)] = true end
                elseif type(parsed.set) == 'table' then
                    for perm, enabled in pairs(parsed.set) do
                        if enabled then set[tostring(perm)] = true end
                    end
                else
                    for perm, enabled in pairs(parsed) do
                        if enabled == true or enabled == 1 then set[tostring(perm)] = true end
                    end
                end
                role.permissions = { wildcard = false, set = set }
            end
        else
            role.permissions = { wildcard = false, set = {} }
        end
        role.permissions_json = nil
    end
    local responsibilities = MySQL.query.await([[
        SELECT citizenid, responsibility_key, assigned_by, assigned_at
        FROM mrp_gang_member_responsibilities_v2
        WHERE gang_id = ?
    ]], { gangId }) or {}
    local permissionList = {}
    for key in pairs(context.permissions.set) do permissionList[#permissionList + 1] = key end
    table.sort(permissionList)
    return {
        gang = context.gang,
        members = members,
        roles = roles,
        responsibilities = responsibilities,
        permissions = context.permissions.wildcard and '*' or permissionList,
        permissionGroups = Config.GangPermissionGroups,
        responsibilityCatalog = Config.GangResponsibilities,
        gangTypes = Config.GangTypes,
    }
end

local function inviteMember(source, targetSource, roleKey)
    if not GangRBAC.Require(source, 'members.invite') then return false, 'permission_denied' end
    if not GangCore.RateLimit(source, 'organization_invite', 2) then return false, 'rate_limited' end
    local context = GangRBAC.Resolve(source)
    local target = GangCore.GetPlayer(targetSource)
    if not context or not target then return false, 'player_not_found' end
    if GangCore.GetPlayerGang(targetSource) then return false, 'target_already_in_gang' end
    roleKey = tostring(roleKey or 'prospect')
    if not roleExists(context.gang.gang_id, roleKey) then return false, 'role_not_found' end
    if not GangRBAC.CanManageRole(source, roleKey) then return false, 'role_too_high' end

    local memberCount = tonumber(MySQL.scalar.await('SELECT COUNT(*) FROM mrp_gang_members_v2 WHERE gang_id = ?', {
        context.gang.gang_id,
    })) or 0
    if memberCount >= (Config.GangLimits.maxMembers or 60) then return false, 'member_limit' end

    MySQL.update.await([[
        UPDATE mrp_gang_invites_v2
        SET status = 'expired', resolved_at = CURRENT_TIMESTAMP
        WHERE citizenid = ? AND status = 'pending' AND expires_at <= CURRENT_TIMESTAMP
    ]], { target.PlayerData.citizenid })
    local inviteId = MySQL.insert.await([[
        INSERT INTO mrp_gang_invites_v2
            (gang_id, citizenid, invited_by, role_key, expires_at)
        VALUES (?, ?, ?, ?, FROM_UNIXTIME(?))
    ]], {
        context.gang.gang_id,
        target.PlayerData.citizenid,
        context.gang.citizenid,
        roleKey,
        os.time() + (Config.GangLimits.inviteExpirySec or 300),
    })
    if not inviteId then return false, 'invite_failed' end
    GangCore.Audit({
        gangId = context.gang.gang_id,
        actorCitizenId = context.gang.citizenid,
        actorSource = source,
        action = 'member_invited',
        targetType = 'citizen',
        targetId = target.PlayerData.citizenid,
        metadata = { inviteId = inviteId, roleKey = roleKey },
    })
    GangCore.Notify(targetSource, ('Gavai kvietimą į „%s“. Atidaryk gaujų tabletę.'):format(context.gang.label), 'primary', 10000)
    return true, inviteId
end

local function acceptInvite(source, inviteId)
    local player = GangCore.GetPlayer(source)
    if not player then return false, 'player_not_found' end
    if GangCore.GetPlayerGang(source) then return false, 'already_in_gang' end
    local invite = MySQL.single.await([[
        SELECT i.*, g.label AS gang_label
        FROM mrp_gang_invites_v2 i
        INNER JOIN mrp_gangs_v2 g ON g.id = i.gang_id
        WHERE i.id = ? AND i.citizenid = ? AND i.status = 'pending'
          AND i.expires_at > CURRENT_TIMESTAMP AND g.status = 'active'
        LIMIT 1
    ]], { tonumber(inviteId), player.PlayerData.citizenid })
    if not invite then return false, 'invite_not_found' end

    local key = ('gang-invite:%s:%s'):format(invite.id, player.PlayerData.citizenid)
    if not GangCore.AcquireIdempotency(key, 'gang_invite', 86400) then return false, 'already_processed' end
    local ok = MySQL.transaction.await({
        {
            query = [[
                INSERT INTO mrp_gang_members_v2 (gang_id, citizenid, display_name, role_key)
                VALUES (?, ?, ?, ?)
            ]],
            values = { invite.gang_id, player.PlayerData.citizenid, playerDisplayName(player), invite.role_key },
        },
        {
            query = [[
                UPDATE mrp_gang_invites_v2
                SET status = 'accepted', resolved_at = CURRENT_TIMESTAMP
                WHERE id = ? AND status = 'pending'
            ]],
            values = { invite.id },
        },
    })
    if not ok then return false, 'invite_accept_failed' end
    GangCore.CompleteIdempotency(key, { gangId = invite.gang_id })
    GangCore.Audit({
        gangId = invite.gang_id,
        actorCitizenId = player.PlayerData.citizenid,
        actorSource = source,
        action = 'member_joined',
        targetType = 'citizen',
        targetId = player.PlayerData.citizenid,
    })
    GangCore.Notify(source, ('Prisijungei prie „%s“.'):format(invite.gang_label), 'success')
    return true
end

local function kickMember(source, citizenid)
    if not GangRBAC.Require(source, 'members.kick') then return false, 'permission_denied' end
    local context = GangRBAC.Resolve(source)
    local target = MySQL.single.await([[
        SELECT citizenid, role_key FROM mrp_gang_members_v2
        WHERE gang_id = ? AND citizenid = ? LIMIT 1
    ]], { context.gang.gang_id, tostring(citizenid or '') })
    if not target then return false, 'member_not_found' end
    if target.citizenid == context.gang.owner_citizenid or target.citizenid == context.gang.citizenid then
        return false, 'protected_member'
    end
    if not GangRBAC.CanManageRole(source, target.role_key) then return false, 'role_too_high' end
    MySQL.update.await('DELETE FROM mrp_gang_members_v2 WHERE gang_id = ? AND citizenid = ?', {
        context.gang.gang_id,
        target.citizenid,
    })
    GangCore.Audit({
        gangId = context.gang.gang_id,
        actorCitizenId = context.gang.citizenid,
        actorSource = source,
        action = 'member_kicked',
        targetType = 'citizen',
        targetId = target.citizenid,
    })
    local targetSource = GangCore.GetSourceByCitizenId(target.citizenid)
    if targetSource then GangCore.Notify(targetSource, 'Buvai pašalintas iš gaujos.', 'error') end
    return true
end

local function setMemberRole(source, citizenid, roleKey)
    if not GangRBAC.Require(source, 'members.set_role') then return false, 'permission_denied' end
    local context = GangRBAC.Resolve(source)
    roleKey = tostring(roleKey or '')
    local target = MySQL.single.await([[
        SELECT citizenid, role_key FROM mrp_gang_members_v2
        WHERE gang_id = ? AND citizenid = ? LIMIT 1
    ]], { context.gang.gang_id, tostring(citizenid or '') })
    if not target or not roleExists(context.gang.gang_id, roleKey) then return false, 'member_or_role_not_found' end
    if target.citizenid == context.gang.owner_citizenid then return false, 'owner_role_locked' end
    if not GangRBAC.CanManageRole(source, target.role_key) or not GangRBAC.CanManageRole(source, roleKey) then
        return false, 'role_too_high'
    end
    MySQL.update.await('UPDATE mrp_gang_members_v2 SET role_key = ? WHERE gang_id = ? AND citizenid = ?', {
        roleKey,
        context.gang.gang_id,
        target.citizenid,
    })
    GangCore.Audit({
        gangId = context.gang.gang_id,
        actorCitizenId = context.gang.citizenid,
        actorSource = source,
        action = 'member_role_changed',
        targetType = 'citizen',
        targetId = target.citizenid,
        metadata = { oldRole = target.role_key, newRole = roleKey },
    })
    return true
end

local function setResponsibility(source, citizenid, responsibilityKey, enabled)
    if not GangRBAC.Require(source, 'members.set_role') then return false, 'permission_denied' end
    local context = GangRBAC.Resolve(source)
    responsibilityKey = tostring(responsibilityKey or '')
    if not Config.GangResponsibilities[responsibilityKey] then return false, 'responsibility_not_found' end
    local member = MySQL.scalar.await([[
        SELECT citizenid FROM mrp_gang_members_v2 WHERE gang_id = ? AND citizenid = ? LIMIT 1
    ]], { context.gang.gang_id, tostring(citizenid or '') })
    if not member then return false, 'member_not_found' end
    if enabled then
        MySQL.update.await([[
            INSERT IGNORE INTO mrp_gang_member_responsibilities_v2
                (gang_id, citizenid, responsibility_key, assigned_by)
            VALUES (?, ?, ?, ?)
        ]], { context.gang.gang_id, citizenid, responsibilityKey, context.gang.citizenid })
    else
        MySQL.update.await([[
            DELETE FROM mrp_gang_member_responsibilities_v2
            WHERE gang_id = ? AND citizenid = ? AND responsibility_key = ?
        ]], { context.gang.gang_id, citizenid, responsibilityKey })
    end
    return true
end

local function saveRole(source, data)
    if not GangRBAC.Require(source, 'roles.manage') then return false, 'permission_denied' end
    local context = GangRBAC.Resolve(source)
    data = data or {}
    local roleKey = tostring(data.roleKey or ''):lower():gsub('[^%w_%-]', ''):sub(1, 32)
    local label = tostring(data.label or ''):sub(1, 64)
    local priority = GangUtils.Clamp(data.priority, 1, 99)
    if roleKey == '' or label == '' or roleKey == 'boss' then return false, 'invalid_role' end
    if not GangCore.IsAdmin(source) and context.role.is_owner ~= 1
        and priority >= tonumber(context.role.priority) then
        return false, 'role_too_high'
    end
    local permissions = {}
    for _, permission in ipairs(type(data.permissions) == 'table' and data.permissions or {}) do
        if Config.GangPermissionSet[permission] then permissions[#permissions + 1] = permission end
    end
    local existing = MySQL.scalar.await([[
        SELECT id FROM mrp_gang_roles_v2 WHERE gang_id = ? AND role_key = ? LIMIT 1
    ]], { context.gang.gang_id, roleKey })
    if not existing then
        local roleCount = tonumber(MySQL.scalar.await('SELECT COUNT(*) FROM mrp_gang_roles_v2 WHERE gang_id = ?', {
            context.gang.gang_id,
        })) or 0
        if roleCount >= (Config.GangLimits.maxRoles or 12) then return false, 'role_limit' end
    end
    MySQL.update.await([[
        INSERT INTO mrp_gang_roles_v2
            (gang_id, role_key, label, priority, is_owner, permissions_json)
        VALUES (?, ?, ?, ?, 0, ?)
        ON DUPLICATE KEY UPDATE
            label = VALUES(label),
            priority = VALUES(priority),
            permissions_json = VALUES(permissions_json)
    ]], { context.gang.gang_id, roleKey, label, priority, json.encode(permissions) })
    GangRBAC.Invalidate(context.gang.gang_id)
    GangCore.Audit({
        gangId = context.gang.gang_id,
        actorCitizenId = context.gang.citizenid,
        actorSource = source,
        action = existing and 'role_updated' or 'role_created',
        targetType = 'role',
        targetId = roleKey,
        metadata = { label = label, priority = priority, permissions = permissions },
    })
    return true
end

local function deleteRole(source, roleKey)
    if not GangRBAC.Require(source, 'roles.manage') then return false, 'permission_denied' end
    local context = GangRBAC.Resolve(source)
    roleKey = tostring(roleKey or '')
    local role = GangRBAC.GetRole(context.gang.gang_id, roleKey)
    if not role then return false, 'role_not_found' end
    if role.is_owner == 1 or roleKey == 'boss' then return false, 'owner_role_locked' end
    if not GangCore.IsAdmin(source) and tonumber(role.priority) >= tonumber(context.role.priority) then
        return false, 'role_too_high'
    end
    local members = tonumber(MySQL.scalar.await([[
        SELECT COUNT(*) FROM mrp_gang_members_v2 WHERE gang_id = ? AND role_key = ?
    ]], { context.gang.gang_id, roleKey })) or 0
    if members > 0 then return false, 'role_in_use' end
    MySQL.update.await('DELETE FROM mrp_gang_roles_v2 WHERE gang_id = ? AND role_key = ?', {
        context.gang.gang_id,
        roleKey,
    })
    GangRBAC.Invalidate(context.gang.gang_id)
    return true
end

local function treasury(source, operation, amount)
    local permission = operation == 'deposit' and 'finance.deposit' or 'finance.withdraw'
    if not GangRBAC.Require(source, permission) then return false, 'permission_denied' end
    local context = GangRBAC.Resolve(source)
    amount = GangUtils.Round(amount)
    if amount <= 0 or amount > 1000000 then return false, 'invalid_amount' end
    local key = ('treasury:%s:%s:%s:%s'):format(context.gang.gang_id, operation, context.gang.citizenid, os.time())
    if not GangCore.AcquireIdempotency(key, 'gang_treasury', 3600) then return false, 'already_processed' end
    if operation == 'deposit' then
        if not GangAdapters.Money.Remove(source, 'cash', amount, 'gang-treasury-deposit') then return false, 'not_enough_cash' end
        local affected = MySQL.update.await('UPDATE mrp_gangs_v2 SET treasury = treasury + ? WHERE id = ?', {
            amount,
            context.gang.gang_id,
        })
        if (tonumber(affected) or 0) <= 0 then
            GangAdapters.Money.Add(source, 'cash', amount, 'gang-treasury-deposit-refund')
            return false, 'treasury_update_failed'
        end
    else
        local affected = MySQL.update.await([[
            UPDATE mrp_gangs_v2 SET treasury = treasury - ?
            WHERE id = ? AND treasury >= ?
        ]], { amount, context.gang.gang_id, amount })
        if (tonumber(affected) or 0) <= 0 then return false, 'not_enough_treasury' end
        if not GangAdapters.Money.Add(source, 'cash', amount, 'gang-treasury-withdraw') then
            MySQL.update.await('UPDATE mrp_gangs_v2 SET treasury = treasury + ? WHERE id = ?', {
                amount,
                context.gang.gang_id,
            })
            return false, 'withdraw_delivery_failed'
        end
    end
    GangCore.CompleteIdempotency(key, { amount = amount, operation = operation })
    GangCore.Audit({
        gangId = context.gang.gang_id,
        actorCitizenId = context.gang.citizenid,
        actorSource = source,
        action = 'treasury_' .. operation,
        targetType = 'gang',
        targetId = context.gang.gang_id,
        metadata = { amount = amount },
    })
    return true
end

local function updateGangInfo(source, data)
    if not GangRBAC.Require(source, 'gang.edit') then return false, 'permission_denied' end
    local context = GangRBAC.Resolve(source)
    data = data or {}
    local label = tostring(data.label or context.gang.label):sub(1, 96)
    local color = tostring(data.colorHex or context.gang.color_hex):upper()
    if label:gsub('%s+', '') == '' then return false, 'invalid_label' end
    if not color:match('^#%x%x%x%x%x%x$') then return false, 'invalid_color' end
    MySQL.update.await('UPDATE mrp_gangs_v2 SET label = ?, color_hex = ? WHERE id = ?', {
        label,
        color,
        context.gang.gang_id,
    })
    GangCore.Audit({
        gangId = context.gang.gang_id,
        actorCitizenId = context.gang.citizenid,
        actorSource = source,
        action = 'gang_info_updated',
        targetType = 'gang',
        targetId = context.gang.gang_id,
        metadata = { label = label, colorHex = color },
    })
    return true
end

local function saveRole(source, data)
    if not GangRBAC.Require(source, 'roles.manage') then return false, 'permission_denied' end
    local context = GangRBAC.Resolve(source)
    data = data or {}
    local roleKey = tostring(data.roleKey or ''):lower():gsub('[^%w_%-]', ''):sub(1, 32)
    local label = tostring(data.label or ''):sub(1, 64)
    local priority = math.floor(tonumber(data.priority) or 0)
    if roleKey == '' or label == '' or roleKey == 'boss' then return false, 'invalid_role' end
    if tonumber(context.role.is_owner) ~= 1 and priority >= tonumber(context.role.priority) then return false, 'role_too_high' end

    local count = tonumber(MySQL.scalar.await('SELECT COUNT(*) FROM mrp_gang_roles_v2 WHERE gang_id = ?', {
        context.gang.gang_id,
    })) or 0
    local exists = roleExists(context.gang.gang_id, roleKey)
    if not exists and count >= (Config.GangLimits.maxRoles or 12) then return false, 'role_limit' end

    local permissions = {}
    for _, permission in ipairs(type(data.permissions) == 'table' and data.permissions or {}) do
        if Config.GangPermissionSet[permission] then permissions[#permissions + 1] = permission end
    end
    MySQL.update.await([[
        INSERT INTO mrp_gang_roles_v2
            (gang_id, role_key, label, priority, is_owner, permissions_json)
        VALUES (?, ?, ?, ?, 0, ?)
        ON DUPLICATE KEY UPDATE
            label = VALUES(label),
            priority = VALUES(priority),
            permissions_json = VALUES(permissions_json)
    ]], { context.gang.gang_id, roleKey, label, priority, json.encode(permissions) })
    GangRBAC.Invalidate(context.gang.gang_id)
    GangCore.Audit({
        gangId = context.gang.gang_id,
        actorCitizenId = context.gang.citizenid,
        actorSource = source,
        action = exists and 'role_updated' or 'role_created',
        targetType = 'role',
        targetId = roleKey,
        metadata = { label = label, priority = priority, permissions = permissions },
    })
    return true
end

local function deleteRole(source, roleKey)
    if not GangRBAC.Require(source, 'roles.manage') then return false, 'permission_denied' end
    local context = GangRBAC.Resolve(source)
    roleKey = tostring(roleKey or '')
    if roleKey == 'boss' or roleKey == 'underboss' or roleKey == 'lieutenant'
        or roleKey == 'member' or roleKey == 'prospect' then
        return false, 'protected_role'
    end
    local role = GangRBAC.GetRole(context.gang.gang_id, roleKey)
    if not role then return false, 'role_not_found' end
    if tonumber(context.role.is_owner) ~= 1 and tonumber(role.priority) >= tonumber(context.role.priority) then
        return false, 'role_too_high'
    end
    local memberCount = tonumber(MySQL.scalar.await([[
        SELECT COUNT(*) FROM mrp_gang_members_v2 WHERE gang_id = ? AND role_key = ?
    ]], { context.gang.gang_id, roleKey })) or 0
    if memberCount > 0 then return false, 'role_in_use' end
    MySQL.update.await('DELETE FROM mrp_gang_roles_v2 WHERE gang_id = ? AND role_key = ?', {
        context.gang.gang_id,
        roleKey,
    })
    GangRBAC.Invalidate(context.gang.gang_id)
    return true
end

QBCore.Functions.CreateCallback('mrp_gangs:server:getOrganization', function(source, callback)
    callback(GangOrganization.GetView(source))
end)

QBCore.Functions.CreateCallback('mrp_gangs:server:inviteMember', function(source, callback, targetSource, roleKey)
    local ok, result = inviteMember(source, tonumber(targetSource), roleKey)
    callback({ ok = ok, result = result })
end)

QBCore.Functions.CreateCallback('mrp_gangs:server:getInvites', function(source, callback)
    local player = GangCore.GetPlayer(source)
    if not player then return callback({}) end
    callback(MySQL.query.await([[
        SELECT i.id, i.role_key, i.expires_at, g.label AS gang_label, g.gang_type
        FROM mrp_gang_invites_v2 i
        INNER JOIN mrp_gangs_v2 g ON g.id = i.gang_id
        WHERE i.citizenid = ? AND i.status = 'pending' AND i.expires_at > CURRENT_TIMESTAMP
        ORDER BY i.created_at DESC
    ]], { player.PlayerData.citizenid }) or {})
end)

QBCore.Functions.CreateCallback('mrp_gangs:server:acceptInvite', function(source, callback, inviteId)
    local ok, reason = acceptInvite(source, tonumber(inviteId))
    callback({ ok = ok, reason = reason })
end)

QBCore.Functions.CreateCallback('mrp_gangs:server:kickMember', function(source, callback, citizenid)
    local ok, reason = kickMember(source, citizenid)
    callback({ ok = ok, reason = reason })
end)

QBCore.Functions.CreateCallback('mrp_gangs:server:setMemberRole', function(source, callback, citizenid, roleKey)
    local ok, reason = setMemberRole(source, citizenid, roleKey)
    callback({ ok = ok, reason = reason })
end)

QBCore.Functions.CreateCallback('mrp_gangs:server:setResponsibility', function(source, callback, citizenid, key, enabled)
    local ok, reason = setResponsibility(source, citizenid, key, enabled == true)
    callback({ ok = ok, reason = reason })
end)

QBCore.Functions.CreateCallback('mrp_gangs:server:saveRole', function(source, callback, data)
    local ok, reason = saveRole(source, data)
    callback({ ok = ok, reason = reason })
end)

QBCore.Functions.CreateCallback('mrp_gangs:server:deleteRole', function(source, callback, roleKey)
    local ok, reason = deleteRole(source, roleKey)
    callback({ ok = ok, reason = reason })
end)

QBCore.Functions.CreateCallback('mrp_gangs:server:treasury', function(source, callback, operation, amount)
    local ok, reason = treasury(source, tostring(operation), amount)
    callback({ ok = ok, reason = reason })
end)

QBCore.Functions.CreateCallback('mrp_gangs:server:updateGangInfo', function(source, callback, data)
    local ok, reason = updateGangInfo(source, data)
    callback({ ok = ok, reason = reason })
end)

QBCore.Functions.CreateCallback('mrp_gangs:server:saveRole', function(source, callback, data)
    local ok, reason = saveRole(source, data)
    callback({ ok = ok, reason = reason })
end)

QBCore.Functions.CreateCallback('mrp_gangs:server:deleteRole', function(source, callback, roleKey)
    local ok, reason = deleteRole(source, roleKey)
    callback({ ok = ok, reason = reason })
end)

exports('GetGangOrganization', GangOrganization.GetView)
