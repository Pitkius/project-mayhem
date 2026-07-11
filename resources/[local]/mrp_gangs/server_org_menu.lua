--[[
  mrp_gangs — Organizacijos meniu būsena, nustatymai, žurnalas (server)
  Agreguoja duomenis NUI. Siunčia TIK tos gaujos duomenis (ne visų).
]]

local QBCore = exports['qb-core']:GetCoreObject()

local function clampStr(s, n)
    s = tostring(s or '')
    if #s > n then s = s:sub(1, n) end
    return s
end

-- citizenid → { src, name } žemėlapis (online žaidėjai).
local function onlineMap()
    local map = {}
    for _, pid in ipairs(GetPlayers()) do
        local P = QBCore.Functions.GetPlayer(tonumber(pid))
        if P then map[P.PlayerData.citizenid] = tonumber(pid) end
    end
    return map
end

local function permsToArray(perms)
    if perms.wildcard then return { '*' } end
    local out = {}
    for k in pairs(perms.set) do out[#out + 1] = k end
    return out
end

-- ── Pilna organizacijos būsena (tik nariams su gang.open_menu) ─────
QBCore.Functions.CreateCallback('mrp_gangs:server:org:getState', function(src, cb)
    local ctx = GangOrg.getContextBySource(src)
    if not ctx then return cb({ ok = false, msg = 'Nepriklausai gaujai.' }) end
    if not (ctx.perms.wildcard or ctx.perms.set['gang.open_menu']) then
        return cb({ ok = false, msg = 'Neturi teisės atidaryti meniu.' })
    end

    local st = GangOrg.getStruct(ctx.gangId)
    local online = onlineMap()
    local settings = {}
    if st.gang.settings and st.gang.settings ~= '' then
        local okj, dec = pcall(json.decode, st.gang.settings)
        if okj and type(dec) == 'table' then settings = dec end
    end

    -- Rangai + narių skaičius.
    local memberRows = GangOrg.getGangMembers(ctx.gangId)
    local countByRank = {}
    local nameByCid = {}
    for _, m in ipairs(memberRows) do
        countByRank[tonumber(m.rank_id) or 0] = (countByRank[tonumber(m.rank_id) or 0] or 0) + 1
        nameByCid[m.citizenid] = m.name
    end

    local ranks = {}
    for _, r in ipairs(st.rankList) do
        ranks[#ranks + 1] = {
            id = tonumber(r.id),
            name = r.name,
            label = r.label,
            priority = r.priority,
            parentRankId = r.parent_rank_id,
            color = r.color,
            icon = r.icon,
            isOwnerRank = r.is_owner_rank,
            canHaveChildren = r.can_have_children,
            permissions = r._perms.wildcard and { '*' } or (function()
                local o = {} for k in pairs(r._perms.set) do o[#o + 1] = k end return o
            end)(),
            memberCount = countByRank[tonumber(r.id)] or 0,
        }
    end

    -- Ar aktorius gali valdyti šį narį (skaičiuojama serveryje).
    local myPriority = ctx.rank and ctx.rank.priority or -1
    local function canManage(m)
        if st.gang.owner_citizenid and tostring(m.citizenid) == tostring(st.gang.owner_citizenid) then return false end
        if ctx.isOwner or ctx.perms.wildcard then return true end
        local tr = m.rank_id and st.ranks[tonumber(m.rank_id)]
        local tp = tr and tr.priority or 0
        return tp < myPriority
    end

    local members = {}
    for _, m in ipairs(memberRows) do
        local rank = m.rank_id and st.ranks[tonumber(m.rank_id)] or nil
        local respRaw = {}
        if m.responsibilities and m.responsibilities ~= '' then
            local okj, dec = pcall(json.decode, m.responsibilities)
            if okj and type(dec) == 'table' then respRaw = dec end
        end
        members[#members + 1] = {
            citizenid = m.citizenid,
            name = m.name,
            serverId = online[m.citizenid] or nil,
            online = online[m.citizenid] ~= nil,
            rankId = tonumber(m.rank_id) or nil,
            rankName = rank and rank.name or nil,
            rankLabel = rank and rank.label or 'Be rango',
            rankColor = rank and rank.color or '#64748B',
            priority = rank and rank.priority or 0,
            isOwner = st.gang.owner_citizenid and tostring(m.citizenid) == tostring(st.gang.owner_citizenid) or false,
            status = m.status or 'active',
            notes = m.notes or '',
            responsibilities = respRaw,
            invitedBy = m.invited_by or nil,
            invitedByName = m.invited_by and nameByCid[m.invited_by] or nil,
            joinedAt = m.joined_at,
            lastActive = m.last_active,
            manageable = canManage(m),
        }
    end

    -- Asocijuoti.
    local associates = {}
    for _, a in ipairs(GangOrg.getGangAssociates(ctx.gangId)) do
        local access = {}
        if a.permissions and a.permissions ~= '' then
            local okj, dec = pcall(json.decode, a.permissions)
            if okj and type(dec) == 'table' then access = dec end
        end
        associates[#associates + 1] = {
            citizenid = a.citizenid,
            name = a.name,
            associateType = a.associate_type,
            handlerCitizenid = a.handler_citizenid,
            handlerName = a.handler_citizenid and nameByCid[a.handler_citizenid] or nil,
            status = a.status,
            notes = a.notes or '',
            permissions = access,
            online = online[a.citizenid] ~= nil,
            serverId = online[a.citizenid] or nil,
            joinedAt = a.joined_at,
        }
    end

    -- Diplomatija (tik jei turi teisę matyti).
    local diplomacy = { relations = {}, incomingOffers = {} }
    if ctx.perms.wildcard or ctx.perms.set['diplomacy.view'] then
        diplomacy = GangOrg.getRelationsView(ctx.gangId)
    end

    -- Kitos gaujos (santykiams siūlyti) — tik id/name/label/color.
    local otherGangs = MySQL.query.await('SELECT id, name, label, color_hex FROM fivempro_gangs WHERE id != ? ORDER BY name ASC', { ctx.gangId }) or {}

    cb({
        ok = true,
        me = {
            citizenid = ctx.member.citizenid,
            isOwner = ctx.isOwner,
            rankId = ctx.rank and tonumber(ctx.rank.id) or nil,
            rankLabel = ctx.rank and ctx.rank.label or nil,
            priority = myPriority,
            permissions = permsToArray(ctx.perms),
            wildcard = ctx.perms.wildcard,
        },
        gang = {
            id = ctx.gangId,
            name = st.gang.name,
            label = st.gang.label or st.gang.name,
            gangType = st.gang.gang_type,
            color = st.gang.color_hex,
            secondaryColor = st.gang.secondary_color_hex,
            emblem = st.gang.emblem,
            reputation = st.gang.reputation,
            createdAt = st.gang.created_at,
            ownerCitizenid = st.gang.owner_citizenid,
            settings = settings,
        },
        ranks = ranks,
        members = members,
        associates = associates,
        diplomacy = diplomacy,
        otherGangs = otherGangs,
        catalog = {
            permissionGroups = Config.GangPermissionGroups,
            responsibilities = Config.GangResponsibilities,
            associateTypes = Config.GangAssociateTypes,
            associateStatuses = Config.GangAssociateStatuses,
            associateAccess = Config.GangAssociateAccessKeys,
            memberStatuses = Config.GangMemberStatuses,
            relationTypes = Config.GangRelationTypes,
            maxRanks = Config.GangMaxRanks,
        },
    })
end)

-- ── Veiklos žurnalas (puslapiuotas + filtras) ──────────────────────
QBCore.Functions.CreateCallback('mrp_gangs:server:org:getLogs', function(src, cb, data)
    local ctx = GangOrg.getContextBySource(src)
    if not ctx then return cb({ ok = false }) end
    if not (ctx.perms.wildcard or ctx.perms.set['gang.view_logs']) then
        return cb({ ok = false, msg = 'Nėra teisės matyti žurnalo.' })
    end

    data = data or {}
    local page = math.max(1, tonumber(data.page) or 1)
    local perPage = math.max(5, math.min(50, tonumber(data.perPage) or 20))
    local offset = (page - 1) * perPage
    local action = data.action and tostring(data.action) or nil
    local search = data.search and clampStr(data.search, 48) or nil

    local where = 'WHERE gang_id = ?'
    local params = { ctx.gangId }
    if action and action ~= '' and action ~= 'all' then
        where = where .. ' AND action = ?'
        params[#params + 1] = action
    end
    if search and search ~= '' then
        where = where .. ' AND (actor_name LIKE ? OR target_id LIKE ?)'
        params[#params + 1] = '%' .. search .. '%'
        params[#params + 1] = '%' .. search .. '%'
    end

    local total = MySQL.scalar.await('SELECT COUNT(*) FROM fivempro_gang_logs ' .. where, params) or 0

    local qParams = {}
    for _, v in ipairs(params) do qParams[#qParams + 1] = v end
    qParams[#qParams + 1] = perPage
    qParams[#qParams + 1] = offset
    local rows = MySQL.query.await(
        'SELECT id, actor_citizenid, actor_name, actor_rank, action, target_type, target_id, old_value, new_value, metadata, created_at FROM fivempro_gang_logs '
        .. where .. ' ORDER BY id DESC LIMIT ? OFFSET ?', qParams) or {}

    cb({ ok = true, logs = rows, total = tonumber(total) or 0, page = page, perPage = perPage })
end)

-- ── Gaujos nustatymai (pavadinimas, spalva, emblema, settings) ─────
QBCore.Functions.CreateCallback('mrp_gangs:server:org:saveSettings', function(src, cb, data)
    if not GangOrg.rateLimit(src, 'saveSettings', 0.75) then return cb({ ok = false, msg = 'Per greitai.' }) end
    local ctx = GangOrg.getContextBySource(src)
    if not ctx then return cb({ ok = false, msg = 'Ne gaujoje.' }) end
    if not (ctx.perms.wildcard or ctx.perms.set['gang.edit_info']) then return cb({ ok = false, msg = 'Nėra teisės.' }) end

    data = data or {}
    local st = GangOrg.getStruct(ctx.gangId)
    local sets, params = {}, {}

    if data.label ~= nil and (ctx.perms.wildcard or ctx.perms.set['gang.edit_name']) then
        sets[#sets + 1] = 'label = ?'; params[#params + 1] = clampStr(data.label, 64)
    end
    if data.color ~= nil and (ctx.perms.wildcard or ctx.perms.set['gang.edit_color']) then
        local hex = tostring(data.color):upper()
        if hex:match('^#%x%x%x%x%x%x$') then sets[#sets + 1] = 'color_hex = ?'; params[#params + 1] = hex end
    end
    if data.secondaryColor ~= nil and (ctx.perms.wildcard or ctx.perms.set['gang.edit_color']) then
        local hex = tostring(data.secondaryColor):upper()
        if hex:match('^#%x%x%x%x%x%x$') then sets[#sets + 1] = 'secondary_color_hex = ?'; params[#params + 1] = hex end
    end
    if data.emblem ~= nil and (ctx.perms.wildcard or ctx.perms.set['gang.edit_emblem']) then
        sets[#sets + 1] = 'emblem = ?'; params[#params + 1] = clampStr(data.emblem, 255)
    end
    if type(data.settings) == 'table' then
        sets[#sets + 1] = 'settings = ?'; params[#params + 1] = json.encode(data.settings)
    end

    if #sets == 0 then return cb({ ok = false, msg = 'Nėra ką keisti.' }) end
    params[#params + 1] = ctx.gangId
    MySQL.update.await('UPDATE fivempro_gangs SET ' .. table.concat(sets, ', ') .. ' WHERE id = ?', params)

    GangOrg.log(ctx.gangId, GangOrg.actor(ctx, src), 'settings_changed', {
        targetType = 'gang', targetId = ctx.gangId, newValue = data,
    })
    TriggerEvent('mrp_gangs:internal:orgChanged', ctx.gangId)
    cb({ ok = true, msg = 'Nustatymai išsaugoti.' })
end)

-- ── Gyvas atnaujinimas online nariams ──────────────────────────────
function GangOrg.pushRefresh(gangId)
    local rows = MySQL.query.await('SELECT citizenid FROM fivempro_gang_members WHERE gang_id = ?', { tonumber(gangId) }) or {}
    for _, r in ipairs(rows) do
        local P = QBCore.Functions.GetPlayerByCitizenId(r.citizenid)
        if P then TriggerClientEvent('mrp_gangs:client:org:refresh', P.PlayerData.source) end
    end
end

-- ── Atidarymas: komanda + įvykis (last_active atnaujinimas) ────────
local function openFor(src)
    local ctx = GangOrg.getContextBySource(src)
    if not ctx then return TriggerClientEvent('QBCore:Notify', src, 'Nepriklausai gaujai.', 'error') end
    if not (ctx.perms.wildcard or ctx.perms.set['gang.open_menu']) then
        return TriggerClientEvent('QBCore:Notify', src, 'Neturi teisės atidaryti meniu.', 'error')
    end
    MySQL.update('UPDATE fivempro_gang_members SET last_active = CURRENT_TIMESTAMP WHERE gang_id = ? AND citizenid = ?', { ctx.gangId, ctx.member.citizenid })
    TriggerClientEvent('mrp_gangs:client:org:open', src)
end

RegisterNetEvent('mrp_gangs:server:org:requestOpen', function()
    openFor(source)
end)

QBCore.Commands.Add('gangmenu', 'Atidaryti gaujos organizacijos meniu', {}, false, function(source)
    openFor(source)
end)
