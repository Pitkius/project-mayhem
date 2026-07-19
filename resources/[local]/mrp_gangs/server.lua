local QBCore = exports['qb-core']:GetCoreObject()

--- Try ADD COLUMN without information_schema (avoids Errcode 28 temp-table writes when disk is full).
--- Duplicate column / already-exists errors are ignored.
local function safeAddColumn(tableName, definition)
    local sql = ('ALTER TABLE `%s` ADD COLUMN %s'):format(tableName, definition)
    local ok, err = pcall(function()
        MySQL.query.await(sql)
    end)
    if ok then
        print(('[mrp_gangs] Added column on %s: %s'):format(tableName, definition:match('^`?([%w_]+)') or '?'))
        return true
    end
    local msg = tostring(err or '')
    if msg:find('Duplicate column', 1, true) or msg:find('already exists', 1, true) then
        return false
    end
    print(('[mrp_gangs] WARN safeAddColumn %s failed: %s'):format(tableName, msg))
    return false
end

local function playerInTurfServer(src, turfId)
    return Config.PlayerInTurfCell and Config.PlayerInTurfCell(src, turfId) or false
end

local function getPlayerGang(src)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return nil end
    local citizenid = Player.PlayerData.citizenid
    local ok, row = pcall(function()
        return MySQL.single.await([[
            SELECT gm.gang_id, gm.rank, g.name, g.gang_type, g.color_hex, g.secondary_color_hex,
                   g.reputation, g.heat, g.warnings, g.created_at, g.parent_gang_id
            FROM fivempro_gang_members gm
            JOIN fivempro_gangs g ON g.id = gm.gang_id
            WHERE gm.citizenid = ?
            LIMIT 1
        ]], { citizenid })
    end)
    if ok and row then return row end

    -- Fallback when migrations did not apply (e.g. disk full) — older schema without parent/secondary.
    ok, row = pcall(function()
        return MySQL.single.await([[
            SELECT gm.gang_id, gm.rank, g.name, g.gang_type, g.color_hex,
                   g.reputation, g.heat, g.warnings, g.created_at
            FROM fivempro_gang_members gm
            JOIN fivempro_gangs g ON g.id = gm.gang_id
            WHERE gm.citizenid = ?
            LIMIT 1
        ]], { citizenid })
    end)
    if ok and row then
        row.secondary_color_hex = row.secondary_color_hex or row.color_hex or '#FFFFFF'
        row.parent_gang_id = nil
        return row
    end
    return nil
end

local function getGangById(gangId)
    return MySQL.single.await('SELECT * FROM fivempro_gangs WHERE id = ? LIMIT 1', { tonumber(gangId) })
end

local function isUnofficialGangRow(gang)
    return gang and Config.IsUnofficialGangType and Config.IsUnofficialGangType(gang.gang_type)
end

--- parentId = oficiali gauja, childId = neoficiali. parentId nil = atjungti.
local function setGangParent(childId, parentId)
    childId = tonumber(childId)
    if not childId then return false, 'Neteisinga gauja.' end
    local child = getGangById(childId)
    if not child then return false, 'Gauja nerasta.' end
    if not isUnofficialGangRow(child) then
        return false, 'Tik neoficialią gaują galima prijungti prie organizacijos.'
    end
    if parentId == nil or tonumber(parentId) == 0 then
        MySQL.update.await('UPDATE fivempro_gangs SET parent_gang_id = NULL WHERE id = ?', { childId })
        return true, 'Afiliacija atjungta.'
    end
    parentId = tonumber(parentId)
    if parentId == childId then return false, 'Negalima prijungti prie savęs.' end
    local parent = getGangById(parentId)
    if not parent then return false, 'Organizacija nerasta.' end
    if isUnofficialGangRow(parent) then
        return false, 'Tėvinė organizacija turi būti oficiali gauja.'
    end
    MySQL.update.await('UPDATE fivempro_gangs SET parent_gang_id = ? WHERE id = ?', { parentId, childId })
    return true, 'Afiliacija nustatyta.'
end

local function getGangAffiliation(gangId)
    gangId = tonumber(gangId)
    if not gangId then return nil end
    local gang = getGangById(gangId)
    if not gang then return nil end
    local unofficial = isUnofficialGangRow(gang)
    local parent = nil
    if gang.parent_gang_id then
        local p = getGangById(gang.parent_gang_id)
        if p then
            parent = { id = tonumber(p.id), name = p.name, label = p.label or p.name, gang_type = p.gang_type, color_hex = p.color_hex }
        end
    end
    local children = {}
    if not unofficial then
        children = MySQL.query.await([[
            SELECT id, name, label, gang_type, color_hex
            FROM fivempro_gangs
            WHERE parent_gang_id = ?
            ORDER BY name ASC
        ]], { gangId }) or {}
        for _, c in ipairs(children) do
            c.id = tonumber(c.id)
            c.label = c.label or c.name
        end
    end
    local officialCandidates = {}
    local unofficialCandidates = {}
    if unofficial then
        officialCandidates = MySQL.query.await([[
            SELECT id, name, label, gang_type, color_hex
            FROM fivempro_gangs
            WHERE gang_type != ? AND id != ?
            ORDER BY name ASC
        ]], { Config.UnofficialGang and Config.UnofficialGang.typeKey or 'unofficial', gangId }) or {}
    else
        unofficialCandidates = MySQL.query.await([[
            SELECT id, name, label, gang_type, color_hex, parent_gang_id
            FROM fivempro_gangs
            WHERE gang_type = ?
            ORDER BY name ASC
        ]], { Config.UnofficialGang and Config.UnofficialGang.typeKey or 'unofficial' }) or {}
    end
    return {
        isUnofficial = unofficial == true,
        parent = parent,
        children = children,
        officialCandidates = officialCandidates,
        unofficialCandidates = unofficialCandidates,
        turfBlockedMessage = Config.GetUnofficialTurfBlockMessage and Config.GetUnofficialTurfBlockMessage() or nil,
    }
end

local function isGangBoss(src)
    local g = getPlayerGang(src)
    return g and (tonumber(g.rank) or 0) >= 4, g
end

local function canManageMembers(src)
    local g = getPlayerGang(src)
    local rank = g and (tonumber(g.rank) or 0) or -1
    return rank >= 3, g
end

local function getGangMembers(gangId)
    return MySQL.query.await('SELECT citizenid, name, rank FROM fivempro_gang_members WHERE gang_id = ? ORDER BY rank DESC, name ASC', { tonumber(gangId) }) or {}
end

local function getGangWarnings(gangId, limit)
    limit = tonumber(limit) or 8
    return MySQL.query.await([[
        SELECT id, reason, admin_name, created_at
        FROM fivempro_gang_warnings
        WHERE gang_id = ?
        ORDER BY id DESC
        LIMIT ?
    ]], { tonumber(gangId), limit }) or {}
end

local function notifyGangMembersOnline(gangId, message, ntype, payload)
    local members = getGangMembers(gangId)
    for _, m in ipairs(members) do
        local tPlayer = QBCore.Functions.GetPlayerByCitizenId(m.citizenid)
        if tPlayer then
            TriggerClientEvent('QBCore:Notify', tPlayer.PlayerData.source, message, ntype or 'error', 9000)
            TriggerClientEvent('mrp_gangs:client:gangWarning', tPlayer.PlayerData.source, payload or {})
        end
    end
end

local function fetchAdminGangs()
    local rows = MySQL.query.await([[
        SELECT g.id, g.name, g.gang_type, g.color_hex, g.reputation, g.heat, g.warnings, g.created_at, g.parent_gang_id,
            (SELECT COUNT(*) FROM fivempro_gang_members m WHERE m.gang_id = g.id) AS member_count,
            (SELECT COUNT(*) FROM fivempro_gang_tablets t WHERE t.gang_id = g.id) AS tablet_count,
            p.name AS parent_name
        FROM fivempro_gangs g
        LEFT JOIN fivempro_gangs p ON p.id = g.parent_gang_id
        ORDER BY g.id ASC
    ]]) or {}
    for _, g in ipairs(rows) do
        g.is_unofficial = isUnofficialGangRow(g)
        g.parent_gang_id = tonumber(g.parent_gang_id)
        g.tablet_count = tonumber(g.tablet_count) or 0
    end
    return rows
end

local function getGangColorLegend()
    local rows = MySQL.query.await('SELECT color_hex, secondary_color_hex FROM fivempro_gangs ORDER BY id ASC') or {}
    local seen, out = {}, {}
    local function add(hex)
        if not hex or hex == '' or hex == '#FFFFFF' or hex == '#ffffff' then return end
        local key = string.upper(tostring(hex))
        if seen[key] then return end
        seen[key] = true
        out[#out + 1] = { color_hex = hex }
    end
    for _, r in ipairs(rows) do
        add(r.color_hex)
        add(r.secondary_color_hex)
    end
    return out
end

local function getTopGangs(limit)
    limit = tonumber(limit) or 5
    return MySQL.query.await([[
        SELECT g.id, g.name, g.color_hex, g.secondary_color_hex, g.reputation,
               COUNT(t.turf_id) AS turf_count
        FROM fivempro_gangs g
        LEFT JOIN fivempro_gang_turfs t ON t.owner_gang_id = g.id
        GROUP BY g.id, g.name, g.color_hex, g.secondary_color_hex, g.reputation
        ORDER BY turf_count DESC, g.reputation DESC
        LIMIT ?
    ]], { limit }) or {}
end

local function getActiveTurfWars()
    local rows = MySQL.query.await([[
        SELECT t.turf_id, t.owner_name, t.influence, g.color_hex
        FROM fivempro_gang_turfs t
        LEFT JOIN fivempro_gangs g ON g.id = t.owner_gang_id
        WHERE t.owner_gang_id IS NOT NULL AND t.influence > 0 AND t.influence < 100
        ORDER BY t.influence ASC
        LIMIT 12
    ]]) or {}
    local out = {}
    for _, r in ipairs(rows) do
        local cfg = Config.GetTurfCell and Config.GetTurfCell(r.turf_id) or (Config.Turfs and Config.Turfs[r.turf_id])
        out[#out + 1] = {
            turfId = r.turf_id,
            cell_num = cfg and cfg.cell_num or 0,
            label = cfg and (cfg.district or cfg.label) or r.turf_id,
            owner = r.owner_name or '—',
            influence = tonumber(r.influence) or 0,
            color_hex = r.color_hex or '#f87171',
            timeLabel = 'Aktyvus',
        }
    end
    return out
end

local function getRecentGangActivities(limit)
    limit = tonumber(limit) or 6
    local rows = MySQL.query.await([[
        SELECT l.turf_id, l.profit, l.created_at, g.name AS gang_name, g.color_hex
        FROM fivempro_gang_sales_logs l
        JOIN fivempro_gangs g ON g.id = l.gang_id
        ORDER BY l.created_at DESC
        LIMIT ?
    ]], { limit }) or {}
    local out = {}
    for _, r in ipairs(rows) do
        local cfg = Config.GetTurfCell and Config.GetTurfCell(r.turf_id) or (Config.Turfs and Config.Turfs[r.turf_id])
        out[#out + 1] = {
            turfId = r.turf_id,
            label = cfg and (cfg.district or cfg.label) or r.turf_id,
            gangName = r.gang_name,
            colorHex = r.color_hex,
            profit = tonumber(r.profit) or 0,
            createdAt = r.created_at,
        }
    end
    return out
end

local function enrichTurfRow(r)
    local cfg = Config.GetTurfCell and Config.GetTurfCell(r.turf_id) or (Config.Turfs and Config.Turfs[r.turf_id])
    r.turf_label = cfg and cfg.label or r.turf_id
    r.district = cfg and cfg.district or r.turf_label
    r.cell_num = cfg and cfg.cell_num or 0
    if cfg and cfg.center then
        r.center_x = tonumber(cfg.center.x) or 0.0
        r.center_y = tonumber(cfg.center.y) or 0.0
        r.center_z = tonumber(cfg.center.z) or 0.0
        r.radius = tonumber(cfg.radius) or 90.0
        r.min_x = tonumber(cfg.minX)
        r.min_y = tonumber(cfg.minY)
        r.max_x = tonumber(cfg.maxX)
        r.max_y = tonumber(cfg.maxY)
    else
        r.center_x, r.center_y, r.center_z, r.radius = 0.0, 0.0, 0.0, 90.0
    end
    local inf = tonumber(r.influence)
    if inf == nil then inf = tonumber(r.progress) or 0 end
    r.influence = inf
    r.progress = inf
    r.graffiti_pct = math.min(100, math.floor(inf / 5))
    r.graffiti_max = 20
    r.graffiti_count = math.min(r.graffiti_max, math.floor(inf / 5))
    local ownerId = tonumber(r.owner_gang_id) or 0
    if ownerId > 0 then
        r.status = inf >= 75 and 'kontroliuojamas' or (inf >= 25 and 'užimtas' or 'ginčijamas')
        r.is_war = inf > 0 and inf < 100
    else
        r.status = inf > 0 and 'ginčijamas' or 'neužimtas'
        r.is_war = inf > 0
    end
    r.owner_display = (r.owner_name and r.owner_name ~= '') and r.owner_name or 'Neutralu'
    local ownerHex = r.owner_color_hex
    if ownerHex and ownerHex ~= '' and ownerHex ~= '#FFFFFF' and ownerHex ~= '#ffffff' then
        r.map_color = ownerHex
    else
        r.map_color = Config.FactionColorForOwner and Config.FactionColorForOwner(r.owner_display, ownerHex) or '#64748B'
    end
    r.active_members = tonumber(r.active_members) or 0
    return r
end

local function countPlayersPerTurf()
    local counts = {}
    for _, playerId in ipairs(GetPlayers()) do
        local src = tonumber(playerId)
        if not src then goto continue end
        local ped = GetPlayerPed(src)
        if not ped or ped == 0 then goto continue end
        local p = GetEntityCoords(ped)
        local tid = Config.FindTurfAt and Config.FindTurfAt(p.x, p.y)
        if tid then
            counts[tid] = (counts[tid] or 0) + 1
        end
        ::continue::
    end
    return counts
end

local function getTurfs()
    local activeCounts = countPlayersPerTurf()
    local dbRows = MySQL.query.await([[
        SELECT t.turf_id, t.owner_gang_id, t.owner_name, t.progress, t.influence, t.heat, t.sales_count, t.total_profit,
               g.color_hex AS owner_color_hex, g.secondary_color_hex AS owner_secondary_color_hex
        FROM fivempro_gang_turfs t
        LEFT JOIN fivempro_gangs g ON g.id = t.owner_gang_id
    ]]) or {}
    local dbMap = {}
    for _, r in ipairs(dbRows) do
        dbMap[r.turf_id] = r
    end
    local out = {}
    for turfId, _ in pairs(Config.TurfCells or Config.Turfs or {}) do
        local r = dbMap[turfId] or { turf_id = turfId }
        r.active_members = activeCounts[turfId] or 0
        enrichTurfRow(r)
        out[#out + 1] = r
    end
    table.sort(out, function(a, b)
        return (tonumber(a.cell_num) or 0) < (tonumber(b.cell_num) or 0)
    end)
    return out
end

local function createGang(src, name, gangType, colorHex, secondaryColorHex)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return false, 'Nerastas žaidėjas.' end
    if getPlayerGang(src) then return false, 'Jau priklausai gaujai.' end
    name = tostring(name or ''):sub(1, 42)
    if name == '' then return false, 'Neteisingas pavadinimas.' end
    if not Config.GangTypes[tostring(gangType)] then return false, 'Neteisingas tipas.' end
    colorHex = tostring(colorHex or '#FFFFFF'):upper()
    secondaryColorHex = tostring(secondaryColorHex or '#FFFFFF'):upper()

    local exists = MySQL.single.await('SELECT id FROM fivempro_gangs WHERE name = ? LIMIT 1', { name })
    if exists then return false, 'Toks pavadinimas jau naudojamas.' end

    local gangId = MySQL.insert.await('INSERT INTO fivempro_gangs (name, gang_type, color_hex, secondary_color_hex, owner_citizenid) VALUES (?, ?, ?, ?, ?)', {
        name, gangType, colorHex, secondaryColorHex, Player.PlayerData.citizenid
    })
    if not gangId then return false, 'Nepavyko sukurti gaujos.' end

    MySQL.insert.await('INSERT INTO fivempro_gang_members (gang_id, citizenid, name, rank) VALUES (?, ?, ?, ?)', {
        gangId, Player.PlayerData.citizenid,
        (Player.PlayerData.charinfo.firstname or '') .. ' ' .. (Player.PlayerData.charinfo.lastname or ''),
        4
    })
    if GangOrg and GangOrg.giveRegisteredTablet then
        GangOrg.giveRegisteredTablet(src, gangId)
    end
    return true, gangId
end

local function getColorUsage()
    local ok, rows = pcall(function()
        return MySQL.query.await('SELECT color_hex, COUNT(*) AS used_count FROM fivempro_gangs GROUP BY color_hex') or {}
    end)
    if not ok or not rows then return {} end
    local out = {}
    for _, r in ipairs(rows) do
        out[tostring(r.color_hex or ''):upper()] = tonumber(r.used_count) or 0
    end
    return out
end

local function getMissionCatalog(gangType)
    local out = {}
    for key, m in pairs(Config.MissionTypes or {}) do
        local allowed = true
        if m.gangs and gangType then
            allowed = m.gangs[tostring(gangType)] == true
        end
        if allowed then
            out[#out + 1] = {
                id = key,
                label = m.label or key,
                reputationReward = tonumber(m.reputationReward) or tonumber(m.progress) or (Config.TaskReputation and Config.TaskReputation[key]) or 0,
                influenceReward = tonumber(m.influenceReward) or 0,
                moneyReward = tonumber(m.moneyReward) or 0,
                archetype = m.archetype or 'delivery',
            }
        end
    end
    table.sort(out, function(a, b) return a.label < b.label end)
    return out
end

QBCore.Functions.CreateCallback('mrp_gangs:server:getTabletState', function(src, cb, data)
    local ok, err = pcall(function()
        data = type(data) == 'table' and data or {}
        local plateGangId = tonumber(data.gangId)
        --- Refresh be gangId — naudoti aktyvią planšetės sesiją
        if not plateGangId and GangOrg and GangOrg.getTabletSession then
            local sess = GangOrg.getTabletSession(src)
            if sess then plateGangId = tonumber(sess.gangId) end
        end
        local playerGang = getPlayerGang(src)
        local claimThreshold = tonumber(Config.TurfCapture and Config.TurfCapture.claimThreshold) or tonumber(Config.TurfClaimThreshold) or 100

        --- Planšetės gauja (metadata) — jei nėra, žaidėjo gauja
        local viewGangId = plateGangId
        if not viewGangId and playerGang then
            viewGangId = tonumber(playerGang.gang_id)
        end

        local readOnly = false
        local viewGang = nil
        if viewGangId then
            viewGang = getGangById(viewGangId)
            if viewGang then
                viewGang.gang_id = tonumber(viewGang.id)
                --- Svetima planšetė = tik peržiūra
                if not playerGang or tonumber(playerGang.gang_id) ~= tonumber(viewGangId) then
                    readOnly = true
                end
            end
        end

        if GangOrg and GangOrg.setTabletSession then
            if viewGangId and viewGang then
                GangOrg.setTabletSession(src, viewGangId, readOnly)
            else
                GangOrg.clearTabletSession(src)
            end
        end

        if not viewGang then
            cb({
                ok = true,
                hasGang = false,
                readOnly = false,
                plateGangId = nil,
                gangTypes = Config.GangTypes,
                palette = Config.GangColors or {},
                colorUsage = getColorUsage(),
                turfs = getTurfs(),
                tabletMap = Config.TabletMap or {},
                gangColors = getGangColorLegend(),
                topGangs = getTopGangs(5),
                activeWars = getActiveTurfWars(),
                recentActivities = getRecentGangActivities(6),
                claimThreshold = claimThreshold,
                missions = {},
            })
            return
        end

        --- Tablet UI naudoja gang.gang_id / name laukus
        local isUnofficial = isUnofficialGangRow(viewGang)
        local affiliation = getGangAffiliation(viewGang.id)
        local gangPayload = {
            gang_id = tonumber(viewGang.id),
            name = viewGang.name,
            label = viewGang.label or viewGang.name,
            gang_type = viewGang.gang_type,
            color_hex = viewGang.color_hex,
            secondary_color_hex = viewGang.secondary_color_hex,
            reputation = viewGang.reputation,
            heat = viewGang.heat,
            warnings = viewGang.warnings,
            created_at = viewGang.created_at,
            rank = (not readOnly and playerGang and playerGang.rank) or 0,
            parent_gang_id = tonumber(viewGang.parent_gang_id),
            is_unofficial = isUnofficial,
        }

        cb({
            ok = true,
            hasGang = true,
            readOnly = readOnly,
            plateGangId = tonumber(viewGang.id),
            isUnofficial = isUnofficial,
            turfBlocked = isUnofficial,
            turfBlockedTitle = (Config.UnofficialGang and Config.UnofficialGang.turfBlockedTitle) or 'Teritorijos užblokuotos',
            turfBlockedMessage = Config.GetUnofficialTurfBlockMessage and Config.GetUnofficialTurfBlockMessage() or nil,
            affiliation = affiliation,
            gang = gangPayload,
            members = getGangMembers(viewGang.id),
            warnings = readOnly and {} or getGangWarnings(viewGang.id, 8),
            maxWarnings = tonumber(Config.MaxGangWarnings) or 5,
            turfs = getTurfs(),
            gangTypes = Config.GangTypes,
            palette = Config.GangColors or {},
            colorUsage = getColorUsage(),
            tabletMap = Config.TabletMap or {},
            gangColors = getGangColorLegend(),
            topGangs = getTopGangs(5),
            activeWars = isUnofficial and {} or getActiveTurfWars(),
            recentActivities = getRecentGangActivities(6),
            claimThreshold = claimThreshold,
            missions = readOnly and {} or getMissionCatalog(viewGang.gang_type),
        })
    end)
    if not ok then
        print(('[mrp_gangs] getTabletState klaida: %s'):format(tostring(err)))
        cb({ ok = false, msg = 'Planšetės duomenų klaida.' })
    end
end)

RegisterNetEvent('mrp_gangs:server:createGang', function(data)
    local src = source
    local ok, result = createGang(src, data and data.name, data and data.gangType, data and data.colorHex, data and data.secondaryColorHex)
    if not ok then
        return TriggerClientEvent('QBCore:Notify', src, tostring(result), 'error')
    end
    TriggerClientEvent('QBCore:Notify', src, 'Gauja užregistruota.', 'success')
end)

--- mode: 'official' | 'unofficial'
local function buyGangTablet(src, mode)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    local gang = getPlayerGang(src)
    if not gang then
        return TriggerClientEvent('QBCore:Notify', src, 'Planšetę gali pirkti tik gaujos narys — ji registruojama tavo gaujai.', 'error')
    end
    local unofficial = isUnofficialGangRow(gang)
    if mode == 'unofficial' then
        if not unofficial then
            return TriggerClientEvent('QBCore:Notify', src, 'Neoficialios gaujos planšetę gali pirkti tik neoficialios gaujos narys.', 'error')
        end
    else
        if unofficial then
            return TriggerClientEvent('QBCore:Notify', src, 'Tu esi neoficialioje gaujoje — rinkis neoficialios gaujos planšetę.', 'error')
        end
    end
    local vendor = Config.TabletVendor or {}
    local price = mode == 'unofficial'
        and (tonumber(vendor.unofficialTabletPrice) or tonumber(vendor.tabletPrice) or 5000)
        or (tonumber(vendor.tabletPrice) or 5000)
    local hasCash = (Player.PlayerData.money and Player.PlayerData.money.cash or 0) >= price
    local hasBank = (Player.PlayerData.money and Player.PlayerData.money.bank or 0) >= price
    if not hasCash and not hasBank then
        return TriggerClientEvent('QBCore:Notify', src, ('Reikia $%s planšetei.'):format(price), 'error')
    end
    if hasCash then
        Player.Functions.RemoveMoney('cash', price, 'gang-tablet-purchase')
    else
        Player.Functions.RemoveMoney('bank', price, 'gang-tablet-purchase')
    end
    local ok, nameOrErr = GangOrg.giveRegisteredTablet(src, gang.gang_id)
    if not ok then
        if hasCash then
            Player.Functions.AddMoney('cash', price, 'gang-tablet-refund')
        else
            Player.Functions.AddMoney('bank', price, 'gang-tablet-refund')
        end
        return TriggerClientEvent('QBCore:Notify', src, tostring(nameOrErr or 'Nepavyko duoti planšetės.'), 'error')
    end
    local kind = mode == 'unofficial' and 'neoficialios gaujos' or 'gaujos'
    TriggerClientEvent('QBCore:Notify', src, ('Nupirkta „%s“ %s planšetė už $%s.'):format(nameOrErr, kind, price), 'success')
end

RegisterNetEvent('mrp_gangs:server:buyTablet', function()
    buyGangTablet(source, 'official')
end)

RegisterNetEvent('mrp_gangs:server:buyUnofficialTablet', function()
    buyGangTablet(source, 'unofficial')
end)

--- Išsitraukti neoficialios gaujos planšetę (nemokamai): narys → savo gauja; admin → /neoficialitablet [gangId]
local function giveUnofficialTabletCommand(src, gangIdArg)
    local targetGangId = tonumber(gangIdArg)
    if targetGangId then
        if not HasGangAdminPermission(src) then
            return TriggerClientEvent('QBCore:Notify', src, 'Gaujos ID argumentas — tik adminams.', 'error')
        end
        local gang = getGangById(targetGangId)
        if not gang then
            return TriggerClientEvent('QBCore:Notify', src, 'Gauja nerasta.', 'error')
        end
        if not isUnofficialGangRow(gang) then
            return TriggerClientEvent('QBCore:Notify', src, 'Ši gauja nėra neoficiali.', 'error')
        end
        local ok, nameOrErr = GangOrg.giveRegisteredTablet(src, targetGangId)
        if not ok then
            return TriggerClientEvent('QBCore:Notify', src, tostring(nameOrErr or 'Nepavyko.'), 'error')
        end
        return TriggerClientEvent('QBCore:Notify', src, ('Ištraukta neoficialios gaujos planšetė: %s.'):format(nameOrErr), 'success')
    end

    local gang = getPlayerGang(src)
    if not gang then
        return TriggerClientEvent('QBCore:Notify', src, 'Nepriklausai gaujai. Admin: /neoficialitablet [gangId]', 'error')
    end
    if not isUnofficialGangRow(gang) then
        return TriggerClientEvent('QBCore:Notify', src, 'Komanda skirta tik neoficialios gaujos nariams.', 'error')
    end
    local ok, nameOrErr = GangOrg.giveRegisteredTablet(src, gang.gang_id)
    if not ok then
        return TriggerClientEvent('QBCore:Notify', src, tostring(nameOrErr or 'Nepavyko.'), 'error')
    end
    TriggerClientEvent('QBCore:Notify', src, ('Ištraukta „%s“ neoficialios gaujos planšetė.'):format(nameOrErr), 'success')
end

QBCore.Commands.Add('neoficialitablet', 'Išsitraukti neoficialios gaujos planšetę', {
    { name = 'gangid', help = 'Gaujos ID (nebūtina; tik admin)' },
}, false, function(source, args)
    giveUnofficialTabletCommand(source, args and args[1])
end)

RegisterNetEvent('mrp_gangs:server:inviteMember', function(targetId)
    local src = source
    if GangOrg and GangOrg.isOrgWriteBlocked and GangOrg.isOrgWriteBlocked(src) then
        return TriggerClientEvent('QBCore:Notify', src, GangOrg.writeBlockedMsg(), 'error')
    end
    local canManage, gang = canManageMembers(src)
    if not canManage then return TriggerClientEvent('QBCore:Notify', src, 'Reikia aukštesnio rango (3+).', 'error') end
    targetId = tonumber(targetId)
    local Target = targetId and QBCore.Functions.GetPlayer(targetId)
    if not Target then return TriggerClientEvent('QBCore:Notify', src, 'Žaidėjas neprisijungęs.', 'error') end
    local targetGang = MySQL.single.await('SELECT gang_id FROM fivempro_gang_members WHERE citizenid = ? LIMIT 1', { Target.PlayerData.citizenid })
    if targetGang then return TriggerClientEvent('QBCore:Notify', src, 'Žaidėjas jau gaujoje.', 'error') end
    MySQL.insert.await('INSERT INTO fivempro_gang_members (gang_id, citizenid, name, rank) VALUES (?, ?, ?, ?)', {
        gang.gang_id, Target.PlayerData.citizenid,
        (Target.PlayerData.charinfo.firstname or '') .. ' ' .. (Target.PlayerData.charinfo.lastname or ''),
        1
    })
    TriggerClientEvent('QBCore:Notify', src, 'Narys pridėtas.', 'success')
    TriggerClientEvent('QBCore:Notify', targetId, ('Priimtas į gaują %s.'):format(gang.name), 'success')
end)

RegisterNetEvent('mrp_gangs:server:setMemberRank', function(citizenid, rank)
    local src = source
    if GangOrg and GangOrg.isOrgWriteBlocked and GangOrg.isOrgWriteBlocked(src) then
        return TriggerClientEvent('QBCore:Notify', src, GangOrg.writeBlockedMsg(), 'error')
    end
    local canManage, gang = canManageMembers(src)
    if not canManage then return TriggerClientEvent('QBCore:Notify', src, 'Reikia aukštesnio rango (3+).', 'error') end
    if tostring(citizenid or '') == '' then return end
    local me = QBCore.Functions.GetPlayer(src)
    if me and tostring(citizenid) == tostring(me.PlayerData.citizenid) then
        return TriggerClientEvent('QBCore:Notify', src, 'Savo rango keisti negalima per šį veiksmą.', 'error')
    end
    rank = math.max(0, math.min(4, tonumber(rank) or 0))
    if rank >= 3 and not isGangBoss(src) then
        return TriggerClientEvent('QBCore:Notify', src, 'Tik boss gali suteikti 3+ rangą.', 'error')
    end
    MySQL.update.await('UPDATE fivempro_gang_members SET rank = ? WHERE gang_id = ? AND citizenid = ?', {
        rank, gang.gang_id, tostring(citizenid or '')
    })
    TriggerClientEvent('QBCore:Notify', src, 'Nario rangas pakeistas.', 'success')
end)

RegisterNetEvent('mrp_gangs:server:kickMember', function(citizenid)
    local src = source
    if GangOrg and GangOrg.isOrgWriteBlocked and GangOrg.isOrgWriteBlocked(src) then
        return TriggerClientEvent('QBCore:Notify', src, GangOrg.writeBlockedMsg(), 'error')
    end
    local canManage, gang = canManageMembers(src)
    if not canManage then return TriggerClientEvent('QBCore:Notify', src, 'Reikia aukštesnio rango (3+).', 'error') end
    local me = QBCore.Functions.GetPlayer(src)
    if me and tostring(citizenid) == tostring(me.PlayerData.citizenid) then
        return TriggerClientEvent('QBCore:Notify', src, 'Savęs išmesti negalima.', 'error')
    end
    MySQL.update.await('DELETE FROM fivempro_gang_members WHERE gang_id = ? AND citizenid = ? AND rank < 4', {
        gang.gang_id, tostring(citizenid or '')
    })
    TriggerClientEvent('QBCore:Notify', src, 'Narys pašalintas.', 'success')
end)

QBCore.Functions.CreateCallback('mrp_gangs:server:tryDrugSale', function(src, cb, turfId, npcNetId)
    local gang = getPlayerGang(src)
    if not gang then return cb({ ok = false, reason = 'Nepriklausai gaujai.' }) end

    local turf = MySQL.single.await('SELECT owner_gang_id, sales_count, total_profit FROM fivempro_gang_turfs WHERE turf_id = ? LIMIT 1', { tostring(turfId) })
    if not turf or tonumber(turf.owner_gang_id) ~= tonumber(gang.gang_id) then
        return cb({ ok = false, reason = 'Šis turf nepriklauso tavo gaujai.' })
    end

    if not playerInTurfServer(src, turfId) then
        return cb({ ok = false, reason = 'Turi būti tame turf teritorijoje.' })
    end

    local netId = tonumber(npcNetId) or 0
    if netId > 0 then
        local npcEnt = NetworkGetEntityFromNetworkId(netId)
        if npcEnt ~= 0 and DoesEntityExist(npcEnt) then
            local opp = GetEntityCoords(GetPlayerPed(src))
            local onp = GetEntityCoords(npcEnt)
            local maxPed = (tonumber(Config.DrugSell.maxDistanceToPed) or 3.0) + 1.25
            if #(opp - onp) > maxPed then
                return cb({ ok = false, reason = 'NPC per toli nuo tavęs.' })
            end
            if IsPedAPlayer(npcEnt) then
                return cb({ ok = false, reason = 'Netinkamas tikslas.' })
            end
        end
    end

    local Player = QBCore.Functions.GetPlayer(src)
    local chosen = nil
    for _, d in ipairs(Config.DrugSellItems or {}) do
        local it = Player.Functions.GetItemByName(d.item)
        if it and it.amount and it.amount > 0 then
            chosen = d
            break
        end
    end
    if not chosen then return cb({ ok = false, reason = 'Neturi tinkamų narkotikų pardavimui.' }) end

    if math.random(1, 100) <= 20 then
        return cb({ ok = false, refused = true, reason = 'NPC atsisakė pirkti.' })
    end

    Player.Functions.RemoveItem(chosen.item, 1)
    local price = math.floor((chosen.base or 100) * (1.0 + ((tonumber(gang.reputation) or 0) * (Config.DrugSell.reputationPriceFactor or 0.005))))
    local paid = false
    if GetResourceState('mrp_drugs') == 'started' then
        paid = exports['mrp_drugs']:GiveDrugSalePayout(src, price, 'gang-turf-sale')
    end
    if not paid then
        Player.Functions.AddMoney('cash', price, 'gang-turf-sale')
    end

    local salesCount = (tonumber(turf.sales_count) or 0) + 1
    local totalProfit = (tonumber(turf.total_profit) or 0) + price
    MySQL.update.await('UPDATE fivempro_gang_turfs SET sales_count = ?, total_profit = ? WHERE turf_id = ?', {
        salesCount, totalProfit, tostring(turfId)
    })
    MySQL.update.await('UPDATE fivempro_gangs SET reputation = reputation + 1 WHERE id = ?', { gang.gang_id })

    local infGain = tonumber(Config.TurfInfluence and Config.TurfInfluence.drugSaleInfluence) or 2
    if infGain > 0 then
        TriggerEvent('mrp_gangs:internal:addInfluence', src, turfId, 'drug_sale', infGain, true, true)
    end
    MySQL.insert.await('INSERT INTO fivempro_gang_sales_logs (gang_id, turf_id, item_name, amount, profit) VALUES (?, ?, ?, ?, ?)', {
        gang.gang_id, tostring(turfId), chosen.item, 1, price
    })

    local alertChance = (Config.DrugSell.policeAlertBase or 14) + math.min(18, math.floor(salesCount / 3))
    local alertPolice = math.random(1, 100) <= alertChance
    cb({ ok = true, item = chosen.item, price = price, alertPolice = alertPolice })
end)

QBCore.Functions.CreateCallback('mrp_gangs:server:getAdminSnapshot', function(src, cb)
    if not HasGangAdminPermission(src) then return cb({ ok = false, message = 'Nėra teisių.' }) end
    local gangs = fetchAdminGangs()
    for _, g in ipairs(gangs) do
        g.recent_warnings = getGangWarnings(g.id, 5)
    end
    local turfs = getTurfs()
    cb({ ok = true, gangs = gangs, turfs = turfs, maxWarnings = tonumber(Config.MaxGangWarnings) or 5 })
end)

RegisterNetEvent('mrp_gangs:server:adminSetGangStats', function(gangId, reputation)
    local src = source
    if not HasGangAdminPermission(src) then return end
    gangId = tonumber(gangId)
    if not gangId then return end
    MySQL.update.await('UPDATE fivempro_gangs SET reputation = ? WHERE id = ?', {
        tonumber(reputation) or 0,
        gangId,
    })
    TriggerClientEvent('QBCore:Notify', src, 'Gaujos statistika atnaujinta.', 'success')
end)

RegisterNetEvent('mrp_gangs:server:adminIssueWarning', function(gangId, reason)
    local src = source
    if not HasGangAdminPermission(src) then return end
    gangId = tonumber(gangId)
    if not gangId then return end
    local gang = getGangById(gangId)
    if not gang then
        return TriggerClientEvent('QBCore:Notify', src, 'Gauja nerasta.', 'error')
    end
    reason = tostring(reason or ''):sub(1, 255)
    if reason == '' then reason = 'Administracinis įspėjimas' end
    local maxW = tonumber(Config.MaxGangWarnings) or 5
    local current = tonumber(gang.warnings) or 0
    if current >= maxW then
        return TriggerClientEvent('QBCore:Notify', src, ('Gauja jau turi %d/%d įspėjimų.'):format(current, maxW), 'error')
    end
    local Admin = QBCore.Functions.GetPlayer(src)
    local adminName = Admin and ((Admin.PlayerData.charinfo.firstname or '') .. ' ' .. (Admin.PlayerData.charinfo.lastname or '')) or 'Admin'
    local adminCid = Admin and Admin.PlayerData.citizenid or nil
    MySQL.insert.await('INSERT INTO fivempro_gang_warnings (gang_id, reason, admin_citizenid, admin_name) VALUES (?, ?, ?, ?)', {
        gangId, reason, adminCid, adminName,
    })
    local nextCount = current + 1
    MySQL.update.await('UPDATE fivempro_gangs SET warnings = ? WHERE id = ?', { nextCount, gangId })
    local msg = ('Gauja „%s“ gavo įspėjimą (%d/%d): %s'):format(gang.name, nextCount, maxW, reason)
    TriggerClientEvent('QBCore:Notify', src, msg, 'success')
    notifyGangMembersOnline(gangId, ('⚠ Gaujos įspėjimas %d/%d: %s'):format(nextCount, maxW, reason), 'error', {
        gangId = gangId,
        warnings = nextCount,
        maxWarnings = maxW,
        reason = reason,
    })
    if nextCount >= maxW then
        notifyGangMembersOnline(gangId, ('⚠ Gauja pasiekė %d įspėjimų limitą — susisiek su administracija.'):format(maxW), 'error')
    end
end)

RegisterNetEvent('mrp_gangs:server:adminClearWarnings', function(gangId)
    local src = source
    if not HasGangAdminPermission(src) then return end
    gangId = tonumber(gangId)
    if not gangId then return end
    MySQL.update.await('UPDATE fivempro_gangs SET warnings = 0 WHERE id = ?', { gangId })
    TriggerClientEvent('QBCore:Notify', src, 'Gaujos įspėjimai nunulinti.', 'success')
    notifyGangMembersOnline(gangId, 'Gaujos įspėjimai buvo panaikinti administracijos.', 'success', { gangId = gangId, warnings = 0 })
end)

RegisterNetEvent('mrp_gangs:server:adminDeleteGang', function(gangId)
    local src = source
    if not HasGangAdminPermission(src) then return end
    gangId = tonumber(gangId)
    if not gangId then return end
    MySQL.update.await('UPDATE fivempro_gangs SET parent_gang_id = NULL WHERE parent_gang_id = ?', { gangId })
    MySQL.update.await('DELETE FROM fivempro_gang_tablets WHERE gang_id = ?', { gangId })
    MySQL.update.await('DELETE FROM fivempro_gang_members WHERE gang_id = ?', { gangId })
    MySQL.update.await('DELETE FROM fivempro_gang_warnings WHERE gang_id = ?', { gangId })
    MySQL.update.await('UPDATE fivempro_gang_turfs SET owner_gang_id = NULL, owner_name = NULL, progress = 0 WHERE owner_gang_id = ?', { gangId })
    MySQL.update.await('DELETE FROM fivempro_gang_sales_logs WHERE gang_id = ?', { gangId })
    MySQL.update.await('DELETE FROM fivempro_gangs WHERE id = ?', { gangId })
    TriggerClientEvent('QBCore:Notify', src, 'Gauja ištrinta.', 'success')
end)

RegisterNetEvent('mrp_gangs:server:adminSetAffiliate', function(childGangId, parentGangId)
    local src = source
    if not HasGangAdminPermission(src) then return end
    local ok, msg = setGangParent(childGangId, parentGangId)
    TriggerClientEvent('QBCore:Notify', src, tostring(msg), ok and 'success' or 'error')
end)

MySQL.ready(function()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `fivempro_gangs` (
            `id` INT NOT NULL AUTO_INCREMENT,
            `name` VARCHAR(64) NOT NULL,
            `gang_type` VARCHAR(32) NOT NULL,
            `color_hex` VARCHAR(16) NOT NULL DEFAULT '#FFFFFF',
            `secondary_color_hex` VARCHAR(16) NOT NULL DEFAULT '#FFFFFF',
            `owner_citizenid` VARCHAR(64) NULL,
            `parent_gang_id` INT NULL DEFAULT NULL,
            `reputation` INT NOT NULL DEFAULT 0,
            `heat` INT NOT NULL DEFAULT 0,
            `warnings` INT NOT NULL DEFAULT 0,
            `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`),
            UNIQUE KEY `ux_fivempro_gangs_name` (`name`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])
    -- Avoid information_schema checks (they create temp tables and fail hard when disk is full).
    -- No AFTER clauses — safer when older columns are also missing.
    safeAddColumn('fivempro_gangs', "`secondary_color_hex` VARCHAR(16) NOT NULL DEFAULT '#FFFFFF'")
    safeAddColumn('fivempro_gangs', '`owner_citizenid` VARCHAR(64) NULL')
    safeAddColumn('fivempro_gangs', '`parent_gang_id` INT NULL DEFAULT NULL')
    safeAddColumn('fivempro_gangs', '`warnings` INT NOT NULL DEFAULT 0')
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `fivempro_gang_tablets` (
            `id` INT NOT NULL AUTO_INCREMENT,
            `gang_id` INT NOT NULL,
            `registered_by` VARCHAR(64) NULL,
            `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`),
            KEY `idx_fivempro_gang_tablets_gang` (`gang_id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `fivempro_gang_warnings` (
            `id` INT NOT NULL AUTO_INCREMENT,
            `gang_id` INT NOT NULL,
            `reason` VARCHAR(255) NOT NULL DEFAULT '',
            `admin_citizenid` VARCHAR(64) NULL,
            `admin_name` VARCHAR(128) NULL,
            `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`),
            KEY `idx_fivempro_gang_warnings_gang` (`gang_id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `fivempro_gang_members` (
            `gang_id` INT NOT NULL,
            `citizenid` VARCHAR(64) NOT NULL,
            `name` VARCHAR(128) NOT NULL,
            `rank` INT NOT NULL DEFAULT 1,
            `joined_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`gang_id`, `citizenid`),
            KEY `idx_fivempro_gang_members_citizenid` (`citizenid`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `fivempro_gang_turfs` (
            `turf_id` VARCHAR(64) NOT NULL,
            `owner_gang_id` INT NULL,
            `owner_name` VARCHAR(64) NULL,
            `progress` INT NOT NULL DEFAULT 0,
            `heat` INT NOT NULL DEFAULT 0,
            `sales_count` INT NOT NULL DEFAULT 0,
            `total_profit` INT NOT NULL DEFAULT 0,
            PRIMARY KEY (`turf_id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])
    local addedInfluence = safeAddColumn('fivempro_gang_turfs', '`influence` INT NOT NULL DEFAULT 0')
    if addedInfluence then
        pcall(function()
            MySQL.query.await([[UPDATE `fivempro_gang_turfs` SET `influence` = `progress`]])
        end)
    end
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `fivempro_gang_sales_logs` (
            `id` BIGINT NOT NULL AUTO_INCREMENT,
            `gang_id` INT NOT NULL,
            `turf_id` VARCHAR(64) NOT NULL,
            `item_name` VARCHAR(64) NOT NULL,
            `amount` INT NOT NULL DEFAULT 1,
            `profit` INT NOT NULL DEFAULT 0,
            `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`),
            KEY `idx_fivempro_gang_sales_logs_gang` (`gang_id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])

    for turfId, _ in pairs(Config.TurfCells or Config.Turfs or {}) do
        MySQL.insert.await('INSERT IGNORE INTO fivempro_gang_turfs (turf_id) VALUES (?)', { turfId })
    end

    QBCore.Functions.CreateUseableItem(Config.TabletItem, function(source, item)
        item = GangOrg.ensureTabletBound(source, item) or item
        local info = item and item.info or {}
        local gangId = tonumber(info.gang_id)
        if not gangId then
            return TriggerClientEvent('QBCore:Notify', source, 'Ši planšetė neužregistruota jokiai gaujai. Pirk naują arba užregistruok per gaują.', 'error')
        end
        TriggerClientEvent('mrp_gangs:client:openTablet', source, {
            gangId = gangId,
            gangLabel = info.gang_label or info.gang_name,
            tabletId = tonumber(info.tablet_id),
        })
    end)

    QBCore.Functions.CreateUseableItem((Config.Graffiti and Config.Graffiti.item) or 'spray_can', function(source)
        TriggerClientEvent('mrp_gangs:client:useSprayCan', source)
    end)

    print('[^2mrp_gangs^7] DB paruošta, gang planšetė registruota.')
end)

exports('FindTurfAt', function(x, y)
    if Config.FindTurfAt then
        return Config.FindTurfAt(x, y)
    end
end)

--- Lengvas gaujos narystės patikrinimas kitiems resursams (pvz. mrp_drugs Dark Net).
--- Grąžina: isInGang(boolean), gangName(string|nil), gangRank(number|nil), gangId(number|nil)
--- Afiliacija (neoficiali ↔ oficiali) — naudoja org meniu / admin.
GangAffiliate = GangAffiliate or {}
GangAffiliate.setParent = setGangParent
GangAffiliate.get = getGangAffiliation
GangAffiliate.isUnofficial = isUnofficialGangRow

exports('IsInGang', function(src)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return false end
    local row = MySQL.single.await([[
        SELECT gm.gang_id, gm.rank, g.name
        FROM fivempro_gang_members gm
        JOIN fivempro_gangs g ON g.id = gm.gang_id
        WHERE gm.citizenid = ?
        LIMIT 1
    ]], { Player.PlayerData.citizenid })
    if not row then return false end
    return true, row.name, tonumber(row.rank), tonumber(row.gang_id)
end)

--- Ta pati patikra pagal citizenid (veikia ir offline).
exports('IsCitizenInGang', function(citizenid)
    if not citizenid then return false end
    local row = MySQL.scalar.await(
        'SELECT gang_id FROM fivempro_gang_members WHERE citizenid = ? LIMIT 1',
        { citizenid }
    )
    return row ~= nil
end)
