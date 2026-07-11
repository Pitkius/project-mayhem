--[[
  ═══════════════════════════════════════════════════════════════════
  mrp_gangs — Organizacijos valdymo branduolys (server)
  ═══════════════════════════════════════════════════════════════════
  1 ETAPAS: duomenų sluoksnis, cache, teisių skaičiavimas, numatytų
  rangų sėjimas, legacy `rank` veidrodis ir suderinamumo exports.

  Autoritetinga teisių logika — TIK čia. UI niekada nesprendžia teisių.

  Suderinamumas:
    · Paliekamas `fivempro_gang_members.rank` (INT) kaip legacy veidrodis
      (owner→4, valdantis rangas→3, kiti→1), kad mrp_drugs / mrp_interrogation
      / senas tablet toliau veiktų.
    · Nauja tiesa — `rank_id` → `fivempro_gang_ranks` su JSON permissions.
]]

local QBCore = exports['qb-core']:GetCoreObject()

GangOrg = GangOrg or {}

-- ═══════════════════════════════════════════════════════════════════
--  CACHE (gaujos struktūra: gang + rangai). Invaliduojamas po pakeitimų.
-- ═══════════════════════════════════════════════════════════════════
local GangCache = {}  -- [gangId] = { gang = {...}, ranks = { [id]=rank }, rankList = {...}, at = time }

function GangOrg.invalidate(gangId)
    if gangId then GangCache[tonumber(gangId)] = nil else GangCache = {} end
end

-- ── JSON helperiai ─────────────────────────────────────────────────
local function decodeJson(str, fallback)
    if type(str) == 'table' then return str end
    if not str or str == '' then return fallback end
    local ok, res = pcall(json.decode, str)
    if ok and res ~= nil then return res end
    return fallback
end

-- Normalizuoja rango permissions į { wildcard=bool, set={[key]=true} }.
local function normalizePerms(permsRaw)
    local decoded = decodeJson(permsRaw, {})
    if decoded == '*' or (type(decoded) == 'table' and decoded[1] == '*') then
        return { wildcard = true, set = {} }
    end
    local set = {}
    if type(decoded) == 'table' then
        for _, k in ipairs(decoded) do set[tostring(k)] = true end
    end
    return { wildcard = false, set = set }
end

-- ═══════════════════════════════════════════════════════════════════
--  DUOMENŲ PAKROVIMAS
-- ═══════════════════════════════════════════════════════════════════
local function loadGangRow(gangId)
    return MySQL.single.await('SELECT * FROM fivempro_gangs WHERE id = ? LIMIT 1', { tonumber(gangId) })
end

local function loadRankRows(gangId)
    return MySQL.query.await(
        'SELECT * FROM fivempro_gang_ranks WHERE gang_id = ? ORDER BY priority DESC, id ASC',
        { tonumber(gangId) }
    ) or {}
end

-- Numatytų rangų sėjimas gaujai, kuri jų dar neturi (tinginio migracija).
local function seedDefaultRanks(gangId, gang)
    gangId = tonumber(gangId)
    if not gangId then return end
    local nameToId = {}
    for _, def in ipairs(Config.GangDefaultRanks) do
        local permsJson = (def.permissions == '*') and json.encode('*') or json.encode(def.permissions or {})
        local newId = MySQL.insert.await([[
            INSERT INTO fivempro_gang_ranks
            (gang_id, name, label, priority, parent_rank_id, color, icon, permissions, is_owner_rank, can_have_children)
            VALUES (?, ?, ?, ?, NULL, ?, ?, ?, ?, ?)
        ]], {
            gangId, def.name, def.label, def.priority, def.color, def.icon,
            permsJson, def.isOwner and 1 or 0, def.canHaveChildren and 1 or 0,
        })
        nameToId[def.name] = newId
    end
    -- Hierarchija: kiekvienas žemesnis rangas pavaldus aukštesniam (grandinė).
    for i = 2, #Config.GangDefaultRanks do
        local child = Config.GangDefaultRanks[i]
        local parent = Config.GangDefaultRanks[i - 1]
        local cid, pid = nameToId[child.name], nameToId[parent.name]
        if cid and pid then
            MySQL.update.await('UPDATE fivempro_gang_ranks SET parent_rank_id = ? WHERE id = ?', { pid, cid })
        end
    end

    -- Esamų narių priskyrimas rangams pagal legacy skaičių (4→boss ... 0→prospect).
    local legacyToName = { [4] = 'boss', [3] = 'underboss', [2] = 'capo', [1] = 'soldier', [0] = 'prospect' }
    local members = MySQL.query.await('SELECT citizenid, rank FROM fivempro_gang_members WHERE gang_id = ?', { gangId }) or {}
    for _, m in ipairs(members) do
        local nm = legacyToName[tonumber(m.rank) or 1] or 'soldier'
        local rid = nameToId[nm] or nameToId['soldier']
        MySQL.update.await('UPDATE fivempro_gang_members SET rank_id = ? WHERE gang_id = ? AND citizenid = ?', { rid, gangId, m.citizenid })
    end
    -- Owner visada gauna boss rangą.
    if gang and gang.owner_citizenid and nameToId['boss'] then
        MySQL.update.await('UPDATE fivempro_gang_members SET rank_id = ? WHERE gang_id = ? AND citizenid = ?', {
            nameToId['boss'], gangId, gang.owner_citizenid,
        })
    end
    return nameToId
end

-- Grąžina (ir prireikus pastato) gaujos cache įrašą.
function GangOrg.getStruct(gangId)
    gangId = tonumber(gangId)
    if not gangId then return nil end
    local cached = GangCache[gangId]
    if cached then return cached end

    local gang = loadGangRow(gangId)
    if not gang then return nil end

    local rankRows = loadRankRows(gangId)
    if #rankRows == 0 then
        seedDefaultRanks(gangId, gang)
        rankRows = loadRankRows(gangId)
    end

    local ranks, rankList = {}, {}
    for _, r in ipairs(rankRows) do
        r.priority = tonumber(r.priority) or 0
        r.parent_rank_id = r.parent_rank_id and tonumber(r.parent_rank_id) or nil
        r.is_owner_rank = tonumber(r.is_owner_rank) == 1
        r.can_have_children = tonumber(r.can_have_children) == 1
        r._perms = normalizePerms(r.permissions)
        ranks[tonumber(r.id)] = r
        rankList[#rankList + 1] = r
    end

    local struct = { gang = gang, ranks = ranks, rankList = rankList, at = os.time() }
    GangCache[gangId] = struct
    return struct
end

function GangOrg.getOwnerRank(gangId)
    local st = GangOrg.getStruct(gangId)
    if not st then return nil end
    for _, r in ipairs(st.rankList) do
        if r.is_owner_rank then return r end
    end
    -- Atsarginis variantas — aukščiausias prioritetas.
    return st.rankList[1]
end

-- ═══════════════════════════════════════════════════════════════════
--  NARIAI / ASOCIJUOTI
-- ═══════════════════════════════════════════════════════════════════
function GangOrg.getMemberRow(citizenid)
    if not citizenid or citizenid == '' then return nil end
    return MySQL.single.await('SELECT * FROM fivempro_gang_members WHERE citizenid = ? LIMIT 1', { citizenid })
end

function GangOrg.getAssociateRow(citizenid)
    if not citizenid or citizenid == '' then return nil end
    return MySQL.single.await('SELECT * FROM fivempro_gang_associates WHERE citizenid = ? LIMIT 1', { citizenid })
end

function GangOrg.getGangMembers(gangId)
    return MySQL.query.await([[
        SELECT gm.gang_id, gm.citizenid, gm.name, gm.rank, gm.rank_id, gm.status, gm.notes,
               gm.responsibilities, gm.permission_overrides, gm.invited_by, gm.joined_at, gm.last_active
        FROM fivempro_gang_members gm WHERE gm.gang_id = ? ORDER BY gm.rank_id DESC, gm.name ASC
    ]], { tonumber(gangId) }) or {}
end

function GangOrg.getGangAssociates(gangId)
    return MySQL.query.await([[
        SELECT id, gang_id, citizenid, name, associate_type, handler_citizenid, status, notes, permissions, joined_at
        FROM fivempro_gang_associates WHERE gang_id = ? ORDER BY name ASC
    ]], { tonumber(gangId) }) or {}
end

-- ═══════════════════════════════════════════════════════════════════
--  TEISIŲ SKAIČIAVIMAS
-- ═══════════════════════════════════════════════════════════════════
-- Galutinės nario teisės = RANGO ∪ ATSAKOMYBIŲ extraPerms ∪ GRANT − REVOKE.
-- Owner (owner_citizenid) arba owner rangas → wildcard (visos teisės).
function GangOrg.computeMemberPermissions(gangId, member)
    local st = GangOrg.getStruct(gangId)
    if not st or not member then return { wildcard = false, set = {} } end

    local gang = st.gang
    if gang.owner_citizenid and tostring(member.citizenid) == tostring(gang.owner_citizenid) then
        return { wildcard = true, set = {} }
    end

    local rank = member.rank_id and st.ranks[tonumber(member.rank_id)]
    if not rank then
        return { wildcard = false, set = {} }
    end
    if rank._perms.wildcard then
        return { wildcard = true, set = {} }
    end

    local set = {}
    for k in pairs(rank._perms.set) do set[k] = true end

    -- Atsakomybių papildomos teisės.
    local resp = decodeJson(member.responsibilities, {})
    if type(resp) == 'table' then
        for _, rid in ipairs(resp) do
            local rDef = Config.GangResponsibilitySet[tostring(rid)]
            if rDef and rDef.extraPerms then
                for _, k in ipairs(rDef.extraPerms) do set[k] = true end
            end
        end
    end

    -- Individualios išimtys.
    local ov = decodeJson(member.permission_overrides, {})
    if type(ov) == 'table' then
        if type(ov.grant) == 'table' then
            for _, k in ipairs(ov.grant) do set[tostring(k)] = true end
        end
        if type(ov.revoke) == 'table' then
            for _, k in ipairs(ov.revoke) do set[tostring(k)] = nil end
        end
    end

    return { wildcard = false, set = set }
end

-- Pilnas žaidėjo gaujos kontekstas (naudoja callback'ai ir exports).
function GangOrg.getPlayerContext(citizenid)
    local member = GangOrg.getMemberRow(citizenid)
    if not member then return nil end
    local st = GangOrg.getStruct(member.gang_id)
    if not st then return nil end
    -- Jei rank_id dar nepriskirtas (pvz. ką tik pasėti rangai) — perskaitom iš naujo.
    if not member.rank_id then
        local fresh = GangOrg.getMemberRow(citizenid)
        if fresh then member = fresh end
    end
    local rank = member.rank_id and st.ranks[tonumber(member.rank_id)] or nil
    local perms = GangOrg.computeMemberPermissions(member.gang_id, member)
    local isOwner = st.gang.owner_citizenid and tostring(citizenid) == tostring(st.gang.owner_citizenid)
    return {
        gang = st.gang,
        gangId = tonumber(member.gang_id),
        member = member,
        rank = rank,
        perms = perms,
        isOwner = isOwner == true,
    }
end

function GangOrg.hasPermission(citizenid, perm)
    if not perm then return false end
    local ctx = GangOrg.getPlayerContext(citizenid)
    if not ctx then return false end
    if ctx.perms.wildcard then return true end
    return ctx.perms.set[tostring(perm)] == true
end

-- Konteksto gavimas pagal serverio src.
function GangOrg.getContextBySource(src)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return nil end
    return GangOrg.getPlayerContext(Player.PlayerData.citizenid)
end

function GangOrg.sourceHasPermission(src, perm)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return false end
    return GangOrg.hasPermission(Player.PlayerData.citizenid, perm)
end

-- ═══════════════════════════════════════════════════════════════════
--  LEGACY `rank` VEIDRODIS (suderinamumui su senais resursais)
-- ═══════════════════════════════════════════════════════════════════
-- owner→4, valdantysis (turi members.kick arba ranks.*)→3, kiti→1.
function GangOrg.syncLegacyRank(gangId, citizenid)
    local member = MySQL.single.await('SELECT * FROM fivempro_gang_members WHERE gang_id = ? AND citizenid = ? LIMIT 1', {
        tonumber(gangId), citizenid,
    })
    if not member then return end
    local perms = GangOrg.computeMemberPermissions(gangId, member)
    local legacy = 1
    local st = GangOrg.getStruct(gangId)
    if st and st.gang.owner_citizenid and tostring(citizenid) == tostring(st.gang.owner_citizenid) then
        legacy = 4
    elseif perms.wildcard then
        legacy = 4
    elseif perms.set['members.kick'] or perms.set['ranks.edit'] or perms.set['ranks.create'] then
        legacy = 3
    end
    MySQL.update.await('UPDATE fivempro_gang_members SET rank = ? WHERE gang_id = ? AND citizenid = ?', {
        legacy, tonumber(gangId), citizenid,
    })
end

function GangOrg.syncAllLegacyRanks(gangId)
    local members = MySQL.query.await('SELECT citizenid FROM fivempro_gang_members WHERE gang_id = ?', { tonumber(gangId) }) or {}
    for _, m in ipairs(members) do
        GangOrg.syncLegacyRank(gangId, m.citizenid)
    end
end

-- ═══════════════════════════════════════════════════════════════════
--  DIPLOMATIJA (skaitymas — mutacijos 5 etape)
-- ═══════════════════════════════════════════════════════════════════
function GangOrg.getRelation(gangA, gangB)
    gangA, gangB = tonumber(gangA), tonumber(gangB)
    if not gangA or not gangB then return nil end
    return MySQL.single.await(
        'SELECT * FROM fivempro_gang_relations WHERE gang_id = ? AND target_gang_id = ? LIMIT 1',
        { gangA, gangB }
    )
end

function GangOrg.areAllied(gangA, gangB)
    local rel = GangOrg.getRelation(gangA, gangB)
    return rel ~= nil and rel.status == 'active' and (rel.relation_type == 'allied' or rel.relation_type == 'friendly')
end

-- ═══════════════════════════════════════════════════════════════════
--  DDL AUTO-MIGRACIJA (kaip esamas server.lua stilius)
-- ═══════════════════════════════════════════════════════════════════
local function columnExists(tableName, columnName)
    local n = MySQL.scalar.await([[
        SELECT COUNT(*) FROM information_schema.columns
        WHERE table_schema = DATABASE() AND table_name = ? AND column_name = ?
    ]], { tableName, columnName })
    return (tonumber(n) or 0) > 0
end

local function ensureColumn(tableName, columnName, definition)
    if not columnExists(tableName, columnName) then
        MySQL.query.await(('ALTER TABLE `%s` ADD COLUMN %s'):format(tableName, definition))
    end
end

CreateThread(function()
    -- Palaukiam kol server.lua MySQL.ready sukurs bazines lenteles.
    Wait(2500)

    ensureColumn('fivempro_gangs', 'label', "`label` VARCHAR(64) NULL AFTER `name`")
    ensureColumn('fivempro_gangs', 'emblem', "`emblem` VARCHAR(255) NULL AFTER `secondary_color_hex`")
    ensureColumn('fivempro_gangs', 'settings', "`settings` LONGTEXT NULL AFTER `emblem`")

    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `fivempro_gang_ranks` (
          `id` INT NOT NULL AUTO_INCREMENT,
          `gang_id` INT NOT NULL,
          `name` VARCHAR(32) NOT NULL,
          `label` VARCHAR(48) NOT NULL,
          `priority` INT NOT NULL DEFAULT 0,
          `parent_rank_id` INT NULL,
          `color` VARCHAR(16) NOT NULL DEFAULT '#64748B',
          `icon` VARCHAR(32) NOT NULL DEFAULT 'user',
          `permissions` LONGTEXT NOT NULL,
          `is_owner_rank` TINYINT(1) NOT NULL DEFAULT 0,
          `can_have_children` TINYINT(1) NOT NULL DEFAULT 1,
          `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
          PRIMARY KEY (`id`),
          KEY `idx_gang_ranks_gang` (`gang_id`),
          KEY `idx_gang_ranks_parent` (`parent_rank_id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])

    ensureColumn('fivempro_gang_members', 'rank_id', "`rank_id` INT NULL AFTER `rank`")
    ensureColumn('fivempro_gang_members', 'status', "`status` VARCHAR(20) NOT NULL DEFAULT 'active' AFTER `rank_id`")
    ensureColumn('fivempro_gang_members', 'notes', "`notes` TEXT NULL AFTER `status`")
    ensureColumn('fivempro_gang_members', 'responsibilities', "`responsibilities` LONGTEXT NULL AFTER `notes`")
    ensureColumn('fivempro_gang_members', 'permission_overrides', "`permission_overrides` LONGTEXT NULL AFTER `responsibilities`")
    ensureColumn('fivempro_gang_members', 'invited_by', "`invited_by` VARCHAR(64) NULL AFTER `permission_overrides`")
    ensureColumn('fivempro_gang_members', 'last_active', "`last_active` TIMESTAMP NULL DEFAULT NULL AFTER `invited_by`")

    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `fivempro_gang_associates` (
          `id` INT NOT NULL AUTO_INCREMENT,
          `gang_id` INT NOT NULL,
          `citizenid` VARCHAR(64) NOT NULL,
          `name` VARCHAR(128) NOT NULL,
          `associate_type` VARCHAR(32) NOT NULL DEFAULT 'hired',
          `handler_citizenid` VARCHAR(64) NULL,
          `status` VARCHAR(20) NOT NULL DEFAULT 'active',
          `notes` TEXT NULL,
          `permissions` LONGTEXT NULL,
          `joined_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
          PRIMARY KEY (`id`),
          UNIQUE KEY `ux_gang_associate` (`gang_id`, `citizenid`),
          KEY `idx_gang_associates_cid` (`citizenid`),
          KEY `idx_gang_associates_handler` (`handler_citizenid`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])

    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `fivempro_gang_relations` (
          `id` INT NOT NULL AUTO_INCREMENT,
          `gang_id` INT NOT NULL,
          `target_gang_id` INT NOT NULL,
          `relation_type` VARCHAR(20) NOT NULL DEFAULT 'neutral',
          `requested_by` VARCHAR(64) NULL,
          `accepted_by` VARCHAR(64) NULL,
          `status` VARCHAR(20) NOT NULL DEFAULT 'active',
          `note` VARCHAR(255) NULL,
          `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
          `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
          PRIMARY KEY (`id`),
          UNIQUE KEY `ux_gang_relation` (`gang_id`, `target_gang_id`),
          KEY `idx_gang_relations_target` (`target_gang_id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])

    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `fivempro_gang_logs` (
          `id` BIGINT NOT NULL AUTO_INCREMENT,
          `gang_id` INT NOT NULL,
          `actor_citizenid` VARCHAR(64) NULL,
          `actor_name` VARCHAR(128) NULL,
          `actor_rank` VARCHAR(48) NULL,
          `action` VARCHAR(48) NOT NULL,
          `target_type` VARCHAR(32) NULL,
          `target_id` VARCHAR(64) NULL,
          `old_value` TEXT NULL,
          `new_value` TEXT NULL,
          `metadata` LONGTEXT NULL,
          `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
          PRIMARY KEY (`id`),
          KEY `idx_gang_logs_gang` (`gang_id`),
          KEY `idx_gang_logs_action` (`action`),
          KEY `idx_gang_logs_created` (`created_at`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])

    print('[^2mrp_gangs^7] Organizacijos schema paruošta (rangai, asocijuoti, diplomatija, žurnalas).')
end)

-- ═══════════════════════════════════════════════════════════════════
--  VEIKLOS ŽURNALAS (serverio pusėje — klientas nesiunčia teksto)
-- ═══════════════════════════════════════════════════════════════════
function GangOrg.log(gangId, actor, action, data)
    gangId = tonumber(gangId)
    if not gangId or not action then return end
    data = data or {}
    local function enc(v)
        if v == nil then return nil end
        if type(v) == 'table' then return json.encode(v) end
        return tostring(v)
    end
    MySQL.insert('INSERT INTO fivempro_gang_logs (gang_id, actor_citizenid, actor_name, actor_rank, action, target_type, target_id, old_value, new_value, metadata) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)', {
        gangId,
        actor and actor.citizenid or nil,
        actor and actor.name or nil,
        actor and actor.rank or nil,
        tostring(action),
        data.targetType,
        data.targetId and tostring(data.targetId) or nil,
        enc(data.oldValue),
        enc(data.newValue),
        data.metadata and json.encode(data.metadata) or nil,
    })
end

-- ═══════════════════════════════════════════════════════════════════
--  SUDERINAMUMO EXPORTS (kitiems resursams)
-- ═══════════════════════════════════════════════════════════════════

--- Ar žaidėjas OFICIALUS gaujos narys (ne asocijuotas).
exports('IsGangMember', function(citizenid)
    if not citizenid then return false end
    return GangOrg.getMemberRow(citizenid) ~= nil
end)

--- Ar žaidėjas TIK asocijuotas civilis (ir NE pilnas narys).
exports('IsGangAssociate', function(citizenid)
    if not citizenid then return false end
    if GangOrg.getMemberRow(citizenid) then return false end
    return GangOrg.getAssociateRow(citizenid) ~= nil
end)

--- Pilna žaidėjo gaujos info (gang, rank, isOwner). nil jei ne narys.
exports('GetPlayerGang', function(citizenid)
    local ctx = GangOrg.getPlayerContext(citizenid)
    if not ctx then return nil end
    return {
        gangId = ctx.gangId,
        name = ctx.gang.name,
        label = ctx.gang.label or ctx.gang.name,
        rankId = ctx.rank and tonumber(ctx.rank.id) or nil,
        rankName = ctx.rank and ctx.rank.name or nil,
        rankLabel = ctx.rank and ctx.rank.label or nil,
        priority = ctx.rank and ctx.rank.priority or 0,
        isOwner = ctx.isOwner,
    }
end)

--- Žaidėjo rango info.
exports('GetGangRank', function(citizenid)
    local ctx = GangOrg.getPlayerContext(citizenid)
    if not ctx or not ctx.rank then return nil end
    return { id = tonumber(ctx.rank.id), name = ctx.rank.name, label = ctx.rank.label, priority = ctx.rank.priority }
end)

--- Konkrečios teisės patikra.
exports('HasGangPermission', function(citizenid, permission)
    return GangOrg.hasPermission(citizenid, permission)
end)

--- Žaidėjo atsakomybės (žymos).
exports('GetGangResponsibilities', function(citizenid)
    local member = GangOrg.getMemberRow(citizenid)
    if not member then return {} end
    return decodeJson(member.responsibilities, {})
end)

--- Gaujos savininko citizenid.
exports('GetGangOwner', function(gangId)
    local st = GangOrg.getStruct(gangId)
    return st and st.gang.owner_citizenid or nil
end)

--- Gaujos narių sąrašas (naujas formatas su rank_id/status).
exports('GetGangMembersEx', function(gangId)
    return GangOrg.getGangMembers(gangId)
end)

--- Gaujos asocijuotų civilių sąrašas.
exports('GetGangAssociates', function(gangId)
    return GangOrg.getGangAssociates(gangId)
end)

--- Dviejų gaujų santykis (raw row).
exports('GetGangRelation', function(gangA, gangB)
    return GangOrg.getRelation(gangA, gangB)
end)

--- Ar dvi gaujos sąjungininkės/draugiškos.
exports('AreGangsAllied', function(gangA, gangB)
    return GangOrg.areAllied(gangA, gangB)
end)

-- ═══════════════════════════════════════════════════════════════════
--  BENDRI PAGALBININKAI (naudoja visi org moduliai)
-- ═══════════════════════════════════════════════════════════════════
local rateStore = {} -- [src..key] = os.clock()

--- Paprasta rate limit apsauga jautriems veiksmams. true = leidžiama.
function GangOrg.rateLimit(src, key, seconds)
    local id = tostring(src) .. ':' .. tostring(key)
    local t = os.clock()
    if rateStore[id] and (t - rateStore[id]) < (seconds or 0.75) then
        return false
    end
    rateStore[id] = t
    return true
end

--- Aktoriaus info žurnalui iš konteksto + Player.
function GangOrg.actor(ctx, src)
    local Player = QBCore.Functions.GetPlayer(src)
    local name = 'Nežinomas'
    local cid = ctx and ctx.member and ctx.member.citizenid or nil
    if Player then
        name = (Player.PlayerData.charinfo.firstname or '') .. ' ' .. (Player.PlayerData.charinfo.lastname or '')
        cid = Player.PlayerData.citizenid
    end
    return { citizenid = cid, name = name, rank = ctx and ctx.rank and ctx.rank.label or nil }
end

--- Anti-escalation: grąžina tik tas teises iš list, kurias aktorius pats turi.
--- Owner/wildcard aktorius gali skirti bet ką (grąžina visą validų sąrašą).
function GangOrg.filterAssignablePerms(ctx, list)
    local out = {}
    if type(list) ~= 'table' then return out end
    local seen = {}
    for _, k in ipairs(list) do
        k = tostring(k)
        if Config.IsValidGangPermission(k) and not seen[k] then
            if ctx.perms.wildcard or ctx.perms.set[k] then
                out[#out + 1] = k
                seen[k] = true
            end
        end
    end
    return out
end

-- ═══════════════════════════════════════════════════════════════════
--  CACHE INVALIDACIJA + gyvas atnaujinimas (naudoja visi org moduliai)
-- ═══════════════════════════════════════════════════════════════════
AddEventHandler('mrp_gangs:internal:orgChanged', function(gangId)
    GangOrg.invalidate(gangId)
    if GangOrg.pushRefresh then GangOrg.pushRefresh(gangId) end
end)
