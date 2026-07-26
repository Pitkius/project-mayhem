local QBCore = exports['qb-core']:GetCoreObject()

GangCore = GangCore or {}
GangCore.QBCore = QBCore
GangCore.RateLimits = {}

local function fullName(player)
    local charinfo = player and player.PlayerData and player.PlayerData.charinfo or {}
    local first = tostring(charinfo.firstname or '')
    local last = tostring(charinfo.lastname or '')
    local name = (first .. ' ' .. last):gsub('^%s+', ''):gsub('%s+$', '')
    if name == '' then return tostring(player.PlayerData.name or player.PlayerData.citizenid) end
    return name
end

function GangCore.GetPlayer(source)
    return QBCore.Functions.GetPlayer(tonumber(source))
end

function GangCore.GetPlayerGang(source)
    local player = GangCore.GetPlayer(source)
    if not player then return nil end

    return MySQL.single.await([[
        SELECT
            g.id AS gang_id,
            g.name,
            g.label,
            g.gang_type,
            g.owner_citizenid,
            g.color_hex,
            g.reputation,
            g.level,
            g.heat,
            g.treasury,
            m.citizenid,
            m.display_name,
            m.role_key,
            m.status AS member_status,
            m.contribution
        FROM mrp_gang_members_v2 m
        INNER JOIN mrp_gangs_v2 g ON g.id = m.gang_id
        WHERE m.citizenid = ? AND m.status = 'active' AND g.status = 'active'
        LIMIT 1
    ]], { player.PlayerData.citizenid })
end

function GangCore.GetGangById(gangId)
    return MySQL.single.await([[
        SELECT id AS gang_id, name, label, gang_type, owner_citizenid, color_hex,
               reputation, level, heat, treasury, status, created_at, updated_at
        FROM mrp_gangs_v2
        WHERE id = ?
        LIMIT 1
    ]], { tonumber(gangId) })
end

function GangCore.IsGangMember(source)
    return GangCore.GetPlayerGang(source) ~= nil
end

function GangCore.GetSourceByCitizenId(citizenid)
    local player = QBCore.Functions.GetPlayerByCitizenId(tostring(citizenid or ''))
    return player and player.PlayerData.source or nil
end

function GangCore.IsAdmin(source)
    for _, permission in ipairs(Config.AdminPermissions or {}) do
        if QBCore.Functions.HasPermission(source, permission) then return true end
    end
    return IsPlayerAceAllowed(source, 'command') or IsPlayerAceAllowed(source, 'group.admin')
end

function GangCore.RateLimit(source, key, seconds)
    local now = os.time()
    local id = ('%s:%s'):format(tonumber(source) or 0, tostring(key))
    if (GangCore.RateLimits[id] or 0) > now then return false end
    GangCore.RateLimits[id] = now + math.max(1, tonumber(seconds) or 1)
    return true
end

function GangCore.Notify(source, message, messageType, duration)
    TriggerClientEvent('QBCore:Notify', source, tostring(message), messageType or 'primary', duration or 6000)
end

function GangCore.Audit(data)
    data = data or {}
    MySQL.insert.await([[
        INSERT INTO mrp_gang_audit_log
            (gang_id, run_id, actor_citizenid, actor_source, action, target_type, target_id, metadata_json)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    ]], {
        tonumber(data.gangId),
        tonumber(data.runId),
        data.actorCitizenId,
        tonumber(data.actorSource),
        tostring(data.action or 'unknown'),
        data.targetType,
        data.targetId and tostring(data.targetId) or nil,
        data.metadata and json.encode(data.metadata) or nil,
    })
end

function GangCore.GetNearbyGangParty(source, gangId)
    local leaderPed = GetPlayerPed(source)
    if not leaderPed or leaderPed == 0 then return {} end
    local leaderCoords = GetEntityCoords(leaderPed)
    local result = {}

    for _, playerId in ipairs(QBCore.Functions.GetPlayers()) do
        local memberSource = tonumber(playerId)
        if memberSource then
            local gang = GangCore.GetPlayerGang(memberSource)
            local ped = GetPlayerPed(memberSource)
            if gang and tonumber(gang.gang_id) == tonumber(gangId) and ped and ped ~= 0 then
                local distance = #(GetEntityCoords(ped) - leaderCoords)
                if distance <= (Config.PartyInviteRadius or 25.0) then
                    result[#result + 1] = {
                        source = memberSource,
                        citizenid = gang.citizenid,
                        displayName = gang.display_name,
                        roleKey = gang.role_key,
                    }
                end
            end
        end
    end

    table.sort(result, function(left, right)
        if left.source == source then return true end
        if right.source == source then return false end
        return left.source < right.source
    end)

    while #result > (Config.MaxMissionParty or 6) do
        table.remove(result)
    end
    return result
end

exports('GetPlayerGang', GangCore.GetPlayerGang)
exports('IsGangMember', GangCore.IsGangMember)
exports('GetGangById', GangCore.GetGangById)

QBCore.Commands.Add('gangcreatev2', 'Sukurti Gang System 2.0 gaują', {
    { name = 'type', help = 'street/cartel/mafia/biker/racing' },
    { name = 'name', help = 'Unikalus techninis pavadinimas' },
    { name = 'label', help = 'Rodomas pavadinimas' },
}, true, function(source, args)
    if not GangCore.IsAdmin(source) then return end
    local gangType = tostring(args[1] or ''):lower()
    local name = tostring(args[2] or ''):lower():gsub('[^%w_%-]', '')
    local label = table.concat(args, ' ', 3)
    if not Config.GangTypes[gangType] or name == '' or label == '' then
        return GangCore.Notify(source, 'Naudojimas: /gangcreatev2 [type] [name] [label]', 'error')
    end

    local player = GangCore.GetPlayer(source)
    if not player then return end
    if GangCore.GetPlayerGang(source) then
        return GangCore.Notify(source, 'Jau priklausai gaujai.', 'error')
    end

    local gangId
    local ok = MySQL.transaction.await({
        {
            query = [[
                INSERT INTO mrp_gangs_v2 (name, label, gang_type, owner_citizenid)
                VALUES (?, ?, ?, ?)
            ]],
            values = { name, label:sub(1, 96), gangType, player.PlayerData.citizenid },
        },
        {
            query = [[
                INSERT INTO mrp_gang_members_v2 (gang_id, citizenid, display_name, role_key)
                VALUES (LAST_INSERT_ID(), ?, ?, 'boss')
            ]],
            values = { player.PlayerData.citizenid, fullName(player) },
        },
    })

    if not ok then
        return GangCore.Notify(source, 'Gaujos sukurti nepavyko. Patikrink unikalų pavadinimą.', 'error')
    end
    gangId = MySQL.scalar.await('SELECT id FROM mrp_gangs_v2 WHERE name = ? LIMIT 1', { name })
    GangRBAC.SeedDefaultRoles(gangId)
    GangCore.Audit({
        gangId = gangId,
        actorCitizenId = player.PlayerData.citizenid,
        actorSource = source,
        action = 'gang_created',
        targetType = 'gang',
        targetId = gangId,
        metadata = { name = name, label = label, gangType = gangType },
    })
    GangCore.Notify(source, ('Gauja „%s“ sukurta (ID %s).'):format(label, gangId), 'success')
end, 'admin')

QBCore.Commands.Add('gangaddv2', 'Pridėti žaidėją į V2 gaują', {
    { name = 'playerId', help = 'Žaidėjo server ID' },
    { name = 'gangId', help = 'V2 gaujos ID' },
}, true, function(source, args)
    if not GangCore.IsAdmin(source) then return end
    local targetSource = tonumber(args[1])
    local gangId = tonumber(args[2])
    local target = targetSource and GangCore.GetPlayer(targetSource)
    if not target or not gangId then
        return GangCore.Notify(source, 'Neteisingas player ID arba gang ID.', 'error')
    end
    if GangCore.GetPlayerGang(targetSource) then
        return GangCore.Notify(source, 'Žaidėjas jau priklauso gaujai.', 'error')
    end
    local gangExists = MySQL.scalar.await('SELECT id FROM mrp_gangs_v2 WHERE id = ? AND status = ? LIMIT 1', { gangId, 'active' })
    if not gangExists then return GangCore.Notify(source, 'Gauja nerasta.', 'error') end

    GangRBAC.SeedDefaultRoles(gangId)
    local inserted = MySQL.update.await([[
        INSERT INTO mrp_gang_members_v2 (gang_id, citizenid, display_name, role_key)
        VALUES (?, ?, ?, 'member')
    ]], { gangId, target.PlayerData.citizenid, fullName(target) })
    if (tonumber(inserted) or 0) <= 0 then return GangCore.Notify(source, 'Nario pridėti nepavyko.', 'error') end
    GangCore.Notify(targetSource, 'Buvai pridėtas prie Gang System 2.0 gaujos.', 'success')
    GangCore.Notify(source, 'Narys pridėtas.', 'success')
end, 'admin')

AddEventHandler('QBCore:Server:PlayerLoaded', function(player)
    local citizenid = player and player.PlayerData and player.PlayerData.citizenid
    if not citizenid then return end
    MySQL.update.await([[
        UPDATE mrp_gang_members_v2
        SET last_seen_at = CURRENT_TIMESTAMP,
            display_name = ?
        WHERE citizenid = ?
    ]], { fullName(player), citizenid })
end)

AddEventHandler('playerDropped', function()
    local source = source
    for key in pairs(GangCore.RateLimits) do
        if key:sub(1, #tostring(source) + 1) == tostring(source) .. ':' then
            GangCore.RateLimits[key] = nil
        end
    end
end)
