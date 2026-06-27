local QBCore = exports['qb-core']:GetCoreObject()

local activeDeliveries = {}
local contractPool = {}
local poolGeneratedAt = 0
local playerContractBoards = {}
local CONTRACT_BOARD_SIZE = 10

local function decodeLicenses(raw)
    if not raw or raw == '' then return {} end
    local ok, data = pcall(json.decode, raw)
    if ok and type(data) == 'table' then return data end
    return {}
end

local function encodeLicenses(tbl)
    return json.encode(tbl or {})
end

--- Sutampa su `players.citizenid` net kai skirtingi utf8mb4 collation (MySQL 8.4 vs senesni).
local JOIN_CITIZENID = 'pl.citizenid COLLATE utf8mb4_bin = p.citizenid COLLATE utf8mb4_bin'

local function migrateCitizenidCollations()
    local alters = {
        'ALTER TABLE `fivempro_trucker_profiles` MODIFY `citizenid` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_uca1400_ai_ci NOT NULL',
        'ALTER TABLE `fivempro_trucker_companies` MODIFY `owner_citizenid` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_uca1400_ai_ci NOT NULL',
        'ALTER TABLE `fivempro_trucker_company_members` MODIFY `citizenid` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_uca1400_ai_ci NOT NULL',
        'ALTER TABLE `fivempro_trucker_delivery_log` MODIFY `citizenid` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_uca1400_ai_ci NOT NULL',
    }
    for _, sql in ipairs(alters) do
        pcall(function()
            MySQL.query.await(sql)
        end)
    end
end

local function ensureTables()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `fivempro_trucker_profiles` (
            `citizenid` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_uca1400_ai_ci NOT NULL,
            `registered` tinyint(1) NOT NULL DEFAULT 0,
            `level` int NOT NULL DEFAULT 1,
            `xp` int NOT NULL DEFAULT 0,
            `reputation` int NOT NULL DEFAULT 0,
            `total_deliveries` int NOT NULL DEFAULT 0,
            `total_earned` bigint NOT NULL DEFAULT 0,
            `licenses` longtext DEFAULT NULL,
            `company_id` int DEFAULT NULL,
            `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (`citizenid`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `fivempro_trucker_companies` (
            `id` int NOT NULL AUTO_INCREMENT,
            `owner_citizenid` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_uca1400_ai_ci NOT NULL,
            `name` varchar(64) NOT NULL,
            `logo` varchar(32) DEFAULT 'default',
            `balance` bigint NOT NULL DEFAULT 0,
            `reputation` int NOT NULL DEFAULT 0,
            `total_deliveries` int NOT NULL DEFAULT 0,
            `total_revenue` bigint NOT NULL DEFAULT 0,
            `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`),
            UNIQUE KEY `uniq_company_name` (`name`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `fivempro_trucker_company_members` (
            `company_id` int NOT NULL,
            `citizenid` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_uca1400_ai_ci NOT NULL,
            `role` varchar(16) NOT NULL DEFAULT 'driver',
            `salary` int NOT NULL DEFAULT 0,
            `joined_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`company_id`, `citizenid`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `fivempro_trucker_fleet` (
            `id` int NOT NULL AUTO_INCREMENT,
            `company_id` int NOT NULL,
            `model` varchar(32) NOT NULL,
            `label` varchar(64) NOT NULL,
            `plate` varchar(12) NOT NULL,
            `condition_pct` int NOT NULL DEFAULT 100,
            `fuel_pct` int NOT NULL DEFAULT 100,
            `status` varchar(16) NOT NULL DEFAULT 'garage',
            PRIMARY KEY (`id`),
            KEY `idx_fleet_company` (`company_id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `fivempro_trucker_delivery_log` (
            `id` int NOT NULL AUTO_INCREMENT,
            `citizenid` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_uca1400_ai_ci NOT NULL,
            `company_id` int DEFAULT NULL,
            `cargo_type` varchar(32) NOT NULL,
            `pickup_hub` varchar(32) NOT NULL,
            `delivery_hub` varchar(32) NOT NULL,
            `pay` int NOT NULL DEFAULT 0,
            `condition_pct` int NOT NULL DEFAULT 100,
            `on_time` tinyint(1) NOT NULL DEFAULT 1,
            `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`),
            KEY `idx_delivery_citizen` (`citizenid`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])
end

MySQL.ready(function()
    ensureTables()
    migrateCitizenidCollations()
end)

local function isRegisteredDb(val)
    return val == 1 or val == true or val == '1'
end

local function getProfileRow(citizenid)
    return MySQL.single.await('SELECT * FROM fivempro_trucker_profiles WHERE citizenid = ? LIMIT 1', { citizenid })
end

local function buildProfile(row)
    if not row then
        return {
            registered = false,
            level = 1,
            xp = 0,
            reputation = 0,
            stars = 1,
            total_deliveries = 0,
            total_earned = 0,
            licenses = {},
            company_id = nil,
            xpNext = TruckingShared.XpForNextLevel(1),
        }
    end
    local licenses = decodeLicenses(row.licenses)
    local level = TruckingShared.LevelFromXp(row.xp or 0)
    if level >= (Config.Unlocks.heavy_truck_license or 5) then
        licenses.heavy_truck = true
    end
    return {
        registered = isRegisteredDb(row.registered),
        level = level,
        xp = row.xp or 0,
        reputation = row.reputation or 0,
        stars = TruckingShared.ReputationStars(row.reputation or 0),
        total_deliveries = row.total_deliveries or 0,
        total_earned = row.total_earned or 0,
        licenses = licenses,
        company_id = row.company_id,
        xpNext = TruckingShared.XpForNextLevel(level),
    }
end

local function ensureProfile(citizenid)
    local row = getProfileRow(citizenid)
    if row then return row end
    MySQL.insert.await('INSERT INTO fivempro_trucker_profiles (citizenid) VALUES (?)', { citizenid })
    return getProfileRow(citizenid)
end

local function saveProfile(citizenid, fields)
    local sets, vals = {}, {}
    for k, v in pairs(fields or {}) do
        sets[#sets + 1] = ('`%s` = ?'):format(k)
        vals[#vals + 1] = v
    end
    if #sets == 0 then return end
    vals[#vals + 1] = citizenid
    MySQL.update.await(('UPDATE fivempro_trucker_profiles SET %s WHERE citizenid = ?'):format(table.concat(sets, ', ')), vals)
end

local function getCompany(companyId)
    if not companyId then return nil end
    return MySQL.single.await('SELECT * FROM fivempro_trucker_companies WHERE id = ? LIMIT 1', { companyId })
end

local function getFleet(companyId)
    if not companyId then return {} end
    return MySQL.query.await('SELECT * FROM fivempro_trucker_fleet WHERE company_id = ? ORDER BY id ASC', { companyId }) or {}
end

local function getCompanyMembers(companyId)
    if not companyId then return {} end
    return MySQL.query.await('SELECT * FROM fivempro_trucker_company_members WHERE company_id = ? ORDER BY role DESC', { companyId }) or {}
end

local function hubList()
    local out = {}
    for id, hub in pairs(Config.Hubs or {}) do
        out[#out + 1] = {
            id = id,
            label = hub.label,
            region = hub.region,
            coords = { x = hub.coords.x, y = hub.coords.y, z = hub.coords.z },
        }
    end
    table.sort(out, function(a, b) return a.label < b.label end)
    return out
end

local function randomCargoForProfile(profile)
    local options = {}
    for id, cargo in pairs(Config.CargoTypes or {}) do
        if TruckingShared.PlayerCanAccessCargo(profile, id) then
            options[#options + 1] = id
        end
    end
    if #options == 0 then return 'food' end
    return options[math.random(#options)]
end

local function calcContractPay(cargoId, distanceKm)
    local cargo = TruckingShared.Cargo(cargoId) or {}
    local pay = (Config.Pay.base or 180) + distanceKm * (Config.Pay.perKm or 42)
    pay = math.floor(pay * (cargo.payMult or 1.0) + 0.5)
    if cargo.illegal then
        pay = math.floor(pay * (Config.IllegalPayMultiplier or 2.5) + 0.5)
    end
    return pay
end

local function nearestTerminalHub(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return 'ls_docks', nil end
    local coords = GetEntityCoords(ped)
    local bestTerm, bestDist
    for _, term in ipairs(Config.RegistrationTerminals or {}) do
        local d = #(coords - term.coords)
        if not bestDist or d < bestDist then
            bestTerm, bestDist = term, d
        end
    end
    if bestTerm and bestTerm.hubId and Config.Hubs[bestTerm.hubId] then
        return bestTerm.hubId, bestTerm
    end
    local bestHub, hubDist
    for id, hub in pairs(Config.Hubs or {}) do
        local d = #(coords - hub.coords)
        if not hubDist or d < hubDist then
            bestHub, hubDist = id, d
        end
    end
    return bestHub or 'ls_docks', bestTerm
end

local function hubIdsExcluding(...)
    local exclude = {}
    for i = 1, select('#', ...) do
        exclude[select(i, ...)] = true
    end
    local out = {}
    for id in pairs(Config.Hubs or {}) do
        if not exclude[id] then
            out[#out + 1] = id
        end
    end
    return out
end

local function pickRandomHubId(excludeIds)
    local candidates = hubIdsExcluding(table.unpack(excludeIds or {}))
    if #candidates == 0 then return nil end
    return candidates[math.random(#candidates)]
end

local function ensureDeliveryHub(contract, pickupId)
    pickupId = pickupId or contract.pickupId
    local deliveryId = contract.deliveryId
    if deliveryId == pickupId or deliveryId == (Config.DefaultStartHubId or 'ls_docks') then
        deliveryId = pickRandomHubId({ pickupId, Config.DefaultStartHubId or 'ls_docks' })
        if not deliveryId then return contract end
        local delivery = TruckingShared.Hub(deliveryId)
        if not delivery then return contract end
        contract.deliveryId = deliveryId
        contract.deliveryLabel = delivery.label
        contract.delivery = { x = delivery.coords.x, y = delivery.coords.y, z = delivery.coords.z }
    end
    return contract
end

local function applyPickupHub(contract, pickupId)
    local pickup = TruckingShared.Hub(pickupId)
    if not pickup then return contract end
    contract = ensureDeliveryHub(contract, pickupId)
    local delivery = TruckingShared.Hub(contract.deliveryId)
    if not delivery then return contract end
    local straightKm = TruckingShared.StraightDistanceKm(pickup.coords, delivery.coords)
    local distanceKm = TruckingShared.DistanceKm(pickup.coords, delivery.coords)
    contract.pickupId = pickupId
    contract.pickupLabel = pickup.label
    contract.pickup = { x = pickup.coords.x, y = pickup.coords.y, z = pickup.coords.z }
    contract.straightKm = math.floor(straightKm * 10) / 10
    contract.distanceKm = distanceKm
    contract.timeLimitMin = math.max(12, math.floor(distanceKm * 1.35 + 8))
    contract.pay = calcContractPay(contract.cargoId, distanceKm)
    return contract
end

local function finalizeContractDistance(contract, roadDistanceKm)
    if not contract or not contract.pickup or not contract.delivery then return contract end
    local straightKm = TruckingShared.StraightDistanceKm(contract.pickup, contract.delivery)
    contract.straightKm = math.floor(straightKm * 10) / 10
    if TruckingShared.ValidateRoadDistanceKm(straightKm, roadDistanceKm) then
        TruckingShared.ApplyDistanceMetrics(contract, roadDistanceKm)
        contract.pay = calcContractPay(contract.cargoId, contract.distanceKm)
    end
    return contract
end

local function generateContract(profile, seed, forcedPickupId)
    math.randomseed(seed or (os.time() + math.random(99999)))
    local hubIds = {}
    for id in pairs(Config.Hubs or {}) do hubIds[#hubIds + 1] = id end
    if #hubIds < 2 then return nil end
    local startHubId = Config.DefaultStartHubId or 'ls_docks'
    local pickupId = forcedPickupId or hubIds[math.random(#hubIds)]
    local deliveryCandidates = hubIdsExcluding(pickupId, startHubId)
    if #deliveryCandidates == 0 then
        deliveryCandidates = hubIdsExcluding(pickupId)
    end
    local deliveryId = deliveryCandidates[math.random(#deliveryCandidates)]
    local pickup = TruckingShared.Hub(pickupId)
    local delivery = TruckingShared.Hub(deliveryId)
    if not pickup or not delivery then return nil end
    local cargoId = randomCargoForProfile(profile)
    local cargo = TruckingShared.Cargo(cargoId) or {}
    local distanceKm = TruckingShared.DistanceKm(pickup.coords, delivery.coords)
    distanceKm = math.floor(distanceKm * 10) / 10
    local timeMin = math.max(12, math.floor(distanceKm * 1.35 + 8))
    local pay = calcContractPay(cargoId, distanceKm)
    local contract = {
        id = ('c_%s_%s_%s'):format(pickupId, deliveryId, cargoId),
        cargoId = cargoId,
        cargoLabel = cargo.label or cargoId,
        category = cargo.category or 'standard',
        risk = cargo.risk or 'low',
        illegal = cargo.illegal == true,
        pickupId = pickupId,
        pickupLabel = pickup.label,
        deliveryId = deliveryId,
        deliveryLabel = delivery.label,
        distanceKm = distanceKm,
        timeLimitMin = timeMin,
        pay = pay,
        minLevel = cargo.minLevel or 1,
        minReputation = cargo.minReputation or 1,
        pickup = { x = pickup.coords.x, y = pickup.coords.y, z = pickup.coords.z },
        delivery = { x = delivery.coords.x, y = delivery.coords.y, z = delivery.coords.z },
    }
    return TruckingShared.EnrichContractMission(profile, contract)
end

local function refreshContractPool()
    contractPool = {}
    poolGeneratedAt = os.time()
    for i = 1, 14 do
        local pseudoProfile = { level = 20, reputation = 999, licenses = { heavy_truck = true } }
        local c = generateContract(pseudoProfile, os.time() + i * 7919)
        if c then
            c.id = ('pool_%s'):format(i)
            contractPool[#contractPool + 1] = c
        end
    end
end

refreshContractPool()

CreateThread(function()
    while true do
        Wait((Config.ContractRefreshSec or 300) * 1000)
        refreshContractPool()
    end
end)

local function contractKey(c)
    return ('%s|%s|%s'):format(c.pickupId or '', c.deliveryId or '', c.cargoId or '')
end

local function contractTtlSec()
    return tonumber(Config.ContractTtlSec) or tonumber(Config.ContractRefreshSec) or 300
end

local function newContractId()
    return ('ctr_%d_%d'):format(os.time(), math.random(100000, 999999))
end

local function isContractExpired(c)
    local listedAt = tonumber(c and c.listedAt) or 0
    if listedAt <= 0 then return false end
    return (os.time() - listedAt) >= contractTtlSec()
end

local function profileCanAccessContract(profile, c)
    if not c then return false end
    if (profile.level or 1) < (c.minLevel or 1) then return false end
    if TruckingShared.ReputationStars(profile.reputation or 0) < (c.minReputation or 1) then return false end
    if isContractExpired(c) then return false end
    return true
end

local function prepareContractCopy(profile, c, startHubId)
    local copy = json.decode(json.encode(c))
    applyPickupHub(copy, startHubId)
    TruckingShared.EnrichContractMission(profile, copy)
    return copy
end

local function stampBoardContract(c)
    c.listedAt = os.time()
    c.id = newContractId()
    return c
end

local function addUniqueContractToBoard(board, profile, c, seen)
    if not c or not profileCanAccessContract(profile, c) then return false end
    local key = contractKey(c)
    if seen[key] then return false end
    seen[key] = true
    local copy = json.decode(json.encode(c))
    stampBoardContract(copy)
    TruckingShared.EnrichContractMission(profile, copy)
    board.contracts[#board.contracts + 1] = copy
    return true
end

local function fillPlayerContractBoard(profile, board)
    board.contracts = board.contracts or {}
    local startHubId = Config.DefaultStartHubId or 'ls_docks'
    local seen = {}

    for i = #board.contracts, 1, -1 do
        local c = board.contracts[i]
        if not tonumber(c.listedAt) or tonumber(c.listedAt) <= 0 then
            c.listedAt = os.time()
        end
        if not profileCanAccessContract(profile, c) then
            table.remove(board.contracts, i)
        else
            seen[contractKey(c)] = true
        end
    end

    for _, c in ipairs(contractPool) do
        if #board.contracts >= CONTRACT_BOARD_SIZE then break end
        addUniqueContractToBoard(board, profile, c, seen)
    end

    local seed = board.seed or (os.time() + (profile.level or 1) * 997)
    board.seed = seed
    local guard = 0
    while #board.contracts < CONTRACT_BOARD_SIZE and guard < 64 do
        guard = guard + 1
        local c = generateContract(profile, seed + guard * 1337, startHubId)
        if c then
            addUniqueContractToBoard(board, profile, c, seen)
        end
    end

    table.sort(board.contracts, function(a, b) return (a.pay or 0) > (b.pay or 0) end)
end

local function getPlayerContractBoard(profile, citizenid)
    local board = playerContractBoards[citizenid]
    if not board or board.poolAt ~= poolGeneratedAt then
        board = {
            contracts = {},
            poolAt = poolGeneratedAt,
            seed = os.time() + (profile.level or 1) * 997,
        }
        playerContractBoards[citizenid] = board
    end
    fillPlayerContractBoard(profile, board)
    return board
end

local function removeContractFromBoard(citizenid, contractId)
    local board = playerContractBoards[citizenid]
    if not board or not contractId then return false end
    for i, c in ipairs(board.contracts) do
        if c.id == contractId then
            table.remove(board.contracts, i)
            return true
        end
    end
    return false
end

local function replaceStaleContract(citizenid, profile, contractId)
    removeContractFromBoard(citizenid, contractId)
    local board = getPlayerContractBoard(profile, citizenid)
    fillPlayerContractBoard(profile, board)
end

local function contractsForPlayer(profile, src)
    local Player = QBCore.Functions.GetPlayer(src)
    local citizenid = Player and Player.PlayerData.citizenid
    if not citizenid then return {} end
    local board = getPlayerContractBoard(profile, citizenid)
    local startHubId = Config.DefaultStartHubId or 'ls_docks'
    local out = {}
    for _, c in ipairs(board.contracts) do
        out[#out + 1] = prepareContractCopy(profile, c, startHubId)
    end
    return out
end

local function findContractForPlayer(profile, contractId, src)
    local Player = QBCore.Functions.GetPlayer(src)
    local citizenid = Player and Player.PlayerData.citizenid
    if not citizenid or not contractId then return nil end
    local board = getPlayerContractBoard(profile, citizenid)
    local startHubId = Config.DefaultStartHubId or 'ls_docks'
    for _, c in ipairs(board.contracts) do
        if c.id == contractId and profileCanAccessContract(profile, c) then
            return prepareContractCopy(profile, c, startHubId)
        end
    end
    return nil
end

local function getLeaderboard()
    return MySQL.query.await([[
        SELECT c.id, c.name, c.balance, c.reputation, c.total_deliveries, c.total_revenue,
               (SELECT COUNT(*) FROM fivempro_trucker_company_members m WHERE m.company_id = c.id) AS members
        FROM fivempro_trucker_companies c
        ORDER BY c.total_revenue DESC, c.total_deliveries DESC
        LIMIT 10
    ]]) or {}
end

local function getDriverLeaderboard()
    local ok, rows = pcall(function()
        return MySQL.query.await([[
            SELECT p.citizenid, p.level, p.total_deliveries, p.total_earned, p.reputation,
                   JSON_UNQUOTE(JSON_EXTRACT(pl.charinfo, '$.firstname')) AS firstname,
                   JSON_UNQUOTE(JSON_EXTRACT(pl.charinfo, '$.lastname')) AS lastname
            FROM fivempro_trucker_profiles p
            LEFT JOIN players pl ON ]] .. JOIN_CITIZENID .. [[
            WHERE p.registered = 1
            ORDER BY p.total_deliveries DESC, p.total_earned DESC
            LIMIT 10
        ]])
    end)
    if not ok then
        print(('[mrp_trucking] driver leaderboard query failed: %s'):format(tostring(rows)))
        return {}
    end
    return rows or {}
end

local function getDeliveryHistory(citizenid)
    local rows = MySQL.query.await([[
        SELECT cargo_type, pickup_hub, delivery_hub, pay, condition_pct, on_time, created_at
        FROM fivempro_trucker_delivery_log
        WHERE citizenid = ?
        ORDER BY created_at DESC
        LIMIT 20
    ]], { citizenid }) or {}
    for _, row in ipairs(rows) do
        local pickup = TruckingShared.Hub(row.pickup_hub)
        local delivery = TruckingShared.Hub(row.delivery_hub)
        local cargo = TruckingShared.Cargo(row.cargo_type)
        row.pickupLabel = pickup and pickup.label or row.pickup_hub
        row.deliveryLabel = delivery and delivery.label or row.delivery_hub
        row.cargoLabel = cargo and cargo.label or row.cargo_type
    end
    return rows
end

local function buildDashboard(src)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return nil end
    local citizenid = Player.PlayerData.citizenid
    local row = ensureProfile(citizenid)
    local profile = buildProfile(row)
    local company = profile.company_id and getCompany(profile.company_id) or nil
    local charinfo = Player.PlayerData.charinfo or {}
    local name = ('%s %s'):format(charinfo.firstname or 'Vairuotojas', charinfo.lastname or '')
    local startHubId = Config.DefaultStartHubId or 'ls_docks'
    local startHub = TruckingShared.Hub(startHubId)
    return {
        profile = profile,
        playerName = name,
        contracts = contractsForPlayer(profile, src),
        startHubId = startHubId,
        startHubLabel = (startHub and startHub.label) or 'Logistikos centras',
        hubs = hubList(),
        company = company and {
            id = company.id,
            name = company.name,
            balance = company.balance or 0,
            reputation = company.reputation or 0,
            total_deliveries = company.total_deliveries or 0,
            total_revenue = company.total_revenue or 0,
            isOwner = company.owner_citizenid == citizenid,
        } or nil,
        fleet = company and getFleet(company.id) or {},
        members = company and getCompanyMembers(company.id) or {},
        leaderboard = getLeaderboard(),
        driverLeaderboard = getDriverLeaderboard(),
        deliveryHistory = getDeliveryHistory(citizenid),
        fleetShop = Config.FleetShop or {},
        vehicles = Config.Vehicles or {},
        activeDelivery = activeDeliveries[src],
        companyCreateCost = Config.CompanyCreateCost or 50000,
        companyMinLevel = Config.CompanyMinLevel or 5,
        map = Config.Map,
        serverTime = os.time(),
    }
end

QBCore.Functions.CreateCallback('mrp_trucking:server:getDashboard', function(src, cb)
    local ok, result = pcall(buildDashboard, src)
    if not ok then
        print(('[mrp_trucking] getDashboard error: %s'):format(tostring(result)))
        cb(nil)
        return
    end
    cb(result)
end)

QBCore.Functions.CreateCallback('mrp_trucking:server:isRegistered', function(src, cb)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return cb(false) end
    local row = getProfileRow(Player.PlayerData.citizenid)
    if not row then return cb(false) end
    if isRegisteredDb(row.registered) then return cb(true) end
    cb((tonumber(row.total_deliveries) or 0) > 0)
end)

QBCore.Functions.CreateCallback('mrp_trucking:server:register', function(src, cb)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then
        return cb({ ok = false, reason = 'Žaidėjas nerastas.' })
    end

    local ok, err = pcall(function()
        local citizenid = Player.PlayerData.citizenid
        local row = ensureProfile(citizenid)
        if isRegisteredDb(row.registered) then
            local dashboard = buildDashboard(src)
            if dashboard then
                return cb({ ok = true, dashboard = dashboard, alreadyRegistered = true })
            end
            return cb({ ok = false, reason = 'Jau registruotas.' })
        end
        local cost = tonumber(Config.RegisterCost) or 0
        if cost > 0 and Player.PlayerData.money.bank < cost then
            return cb({ ok = false, reason = ('Reikia $%s banke.'):format(cost) })
        end
        if cost > 0 and not Player.Functions.RemoveMoney('bank', cost, 'trucker-register') then
            return cb({ ok = false, reason = 'Nepavyko nuskaičiuoti pinigų.' })
        end
        saveProfile(citizenid, { registered = 1 })
        local dashboard = buildDashboard(src)
        if not dashboard then
            return cb({ ok = false, reason = 'Registracija išsaugota, bet panelės duomenų klaida.' })
        end
        cb({ ok = true, dashboard = dashboard })
    end)

    if not ok then
        print(('[mrp_trucking] register error: %s'):format(tostring(err)))
        cb({ ok = false, reason = 'Serverio klaida (DB). Paleisk mrp_trucking.sql arba restart resursą.' })
    end
end)

QBCore.Functions.CreateCallback('mrp_trucking:server:createCompany', function(src, cb, companyName)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return cb({ ok = false, reason = 'Klaida.' }) end
    companyName = tostring(companyName or ''):gsub('^%s+', ''):gsub('%s+$', '')
    if #companyName < 3 or #companyName > 48 then
        return cb({ ok = false, reason = 'Pavadinimas 3–48 simbolių.' })
    end
    local citizenid = Player.PlayerData.citizenid
    local row = ensureProfile(citizenid)
    local profile = buildProfile(row)
    if not profile.registered then return cb({ ok = false, reason = 'Pirmiausia registruokis.' }) end
    if profile.level < (Config.CompanyMinLevel or 5) then
        return cb({ ok = false, reason = ('Reikia %d lygio.'):format(Config.CompanyMinLevel or 5) })
    end
    if profile.company_id then return cb({ ok = false, reason = 'Jau priklausai įmonei.' }) end
    local cost = Config.CompanyCreateCost or 50000
    if Player.PlayerData.money.bank < cost then
        return cb({ ok = false, reason = 'Reikia $' .. cost })
    end
    local exists = MySQL.scalar.await('SELECT id FROM fivempro_trucker_companies WHERE name = ? LIMIT 1', { companyName })
    if exists then return cb({ ok = false, reason = 'Toks pavadinimas užimtas.' }) end
    Player.Functions.RemoveMoney('bank', cost, 'trucker-company-create')
    local companyId = MySQL.insert.await(
        'INSERT INTO fivempro_trucker_companies (owner_citizenid, name) VALUES (?, ?)',
        { citizenid, companyName }
    )
    MySQL.insert.await(
        'INSERT INTO fivempro_trucker_company_members (company_id, citizenid, role) VALUES (?, ?, ?)',
        { companyId, citizenid, 'owner' }
    )
    saveProfile(citizenid, { company_id = companyId })
    cb({ ok = true, dashboard = buildDashboard(src) })
end)

QBCore.Functions.CreateCallback('mrp_trucking:server:applyRoadQuotes', function(src, cb, quotes)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return cb({ ok = false }) end
    local citizenid = Player.PlayerData.citizenid
    local profile = buildProfile(ensureProfile(citizenid))
    local board = getPlayerContractBoard(profile, citizenid)
    local byId = {}
    for _, c in ipairs(board.contracts) do
        byId[c.id] = c
    end
    local out = {}
    for _, q in ipairs(quotes or {}) do
        local base = byId[q.id]
        if base then
            local copy = prepareContractCopy(profile, base, Config.DefaultStartHubId or 'ls_docks')
            copy = finalizeContractDistance(copy, q.distanceKm)
            base.distanceKm = copy.distanceKm
            base.timeLimitMin = copy.timeLimitMin
            base.pay = copy.pay
            base.straightKm = copy.straightKm
            out[#out + 1] = {
                id = copy.id,
                distanceKm = copy.distanceKm,
                timeLimitMin = copy.timeLimitMin,
                pay = copy.pay,
            }
        end
    end
    cb({ ok = true, quotes = out })
end)

QBCore.Functions.CreateCallback('mrp_trucking:server:acceptContract', function(src, cb, contractId, roadDistanceKm)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return cb({ ok = false }) end
    if activeDeliveries[src] then return cb({ ok = false, reason = 'Jau vykdomas kontraktas.' }) end
    local citizenid = Player.PlayerData.citizenid
    local row = ensureProfile(citizenid)
    local profile = buildProfile(row)
    if not profile.registered then return cb({ ok = false, reason = 'Registruokis kaip vairuotojas.' }) end
    local contract = findContractForPlayer(profile, contractId, src)
    if not contract then
        replaceStaleContract(citizenid, profile, contractId)
        return cb({
            ok = false,
            reason = 'Kontraktas nebegalioja — parinktas naujas.',
            refreshContracts = true,
            contracts = contractsForPlayer(profile, src),
        })
    end
    local startHubId = Config.DefaultStartHubId or 'ls_docks'
    contract = applyPickupHub(json.decode(json.encode(contract)), startHubId)
    contract = finalizeContractDistance(contract, roadDistanceKm)
    if not TruckingShared.PlayerCanAccessCargo(profile, contract.cargoId) then
        return cb({ ok = false, reason = 'Per žemas lygis ar reputacija.' })
    end
    local deadline = os.time() + (contract.timeLimitMin * 60)
    local boxesRequired = contract.boxesRequired or TruckingShared.CargoBoxCount(contract.cargoId)
    local truck = TruckingShared.ResolveMissionTruck(profile, contract.cargoId, boxesRequired)
    activeDeliveries[src] = {
        contract = contract,
        phase = 'loading',
        condition = 100,
        deadline = deadline,
        startedAt = os.time(),
        loaded = false,
        boxesRequired = boxesRequired,
        boxesLoaded = 0,
        truckModel = truck.model,
        truckLabel = truck.label,
        truckTier = truck.tier,
        trailerModel = truck.trailer,
    }
    TriggerClientEvent('mrp_trucking:client:startDelivery', src, activeDeliveries[src])
    removeContractFromBoard(citizenid, contractId)
    local board = playerContractBoards[citizenid]
    if board then
        fillPlayerContractBoard(profile, board)
    end
    cb({ ok = true, delivery = activeDeliveries[src] })
end)

QBCore.Functions.CreateCallback('mrp_trucking:server:loadBox', function(src, cb)
    local d = activeDeliveries[src]
    if not d or d.phase ~= 'loading' then
        return cb({ ok = false, reason = 'Nėra aktyvaus pakrovimo.' })
    end
    if (d.boxesLoaded or 0) >= (d.boxesRequired or 1) then
        return cb({ ok = false, reason = 'Transportas jau pilnas.' })
    end
    d.boxesLoaded = (d.boxesLoaded or 0) + 1
    local complete = d.boxesLoaded >= (d.boxesRequired or 1)
    if complete then
        d.loaded = true
        d.phase = 'delivery'
    end
    cb({
        ok = true,
        boxesLoaded = d.boxesLoaded,
        boxesRequired = d.boxesRequired,
        complete = complete,
        delivery = d,
    })
end)

QBCore.Functions.CreateCallback('mrp_trucking:server:loadCargo', function(src, cb)
    local d = activeDeliveries[src]
    if not d or d.phase ~= 'pickup' then return cb({ ok = false }) end
    d.loaded = true
    d.phase = 'delivery'
    cb({ ok = true, delivery = d })
end)

QBCore.Functions.CreateCallback('mrp_trucking:server:completeDelivery', function(src, cb, conditionPct)
    local Player = QBCore.Functions.GetPlayer(src)
    local d = activeDeliveries[src]
    if not Player or not d or d.phase ~= 'delivery' or not d.loaded then
        return cb({ ok = false, reason = 'Nėra aktyvaus pristatymo.' })
    end
    conditionPct = TruckingShared.Clamp(conditionPct or d.condition or 100, 0, 100)
    local contract = d.contract
    local secondsLeft = d.deadline - os.time()
    local totalSeconds = (contract.timeLimitMin or 20) * 60
    local timeMult = TruckingShared.TimePayMultiplier(secondsLeft, totalSeconds)
    local condMult = TruckingShared.ConditionPayMultiplier(conditionPct)
    local pay = math.floor((contract.pay or 0) * timeMult * condMult + 0.5)
    local citizenid = Player.PlayerData.citizenid
    local row = ensureProfile(citizenid)
    local profile = buildProfile(row)
    local company = profile.company_id and getCompany(profile.company_id) or nil
    if company then
        pay = math.floor(pay * (1.0 + (Config.Pay.companyBonus or 0.18)) + 0.5)
        MySQL.update.await(
            'UPDATE fivempro_trucker_companies SET balance = balance + ?, total_revenue = total_revenue + ?, total_deliveries = total_deliveries + 1 WHERE id = ?',
            { pay, pay, company.id }
        )
    end
    Player.Functions.AddMoney('bank', pay, 'trucker-delivery')
    local xpGain = math.random(Config.XpPerDelivery.min or 35, Config.XpPerDelivery.max or 120)
    local cargo = TruckingShared.Cargo(contract.cargoId) or {}
    xpGain = math.floor(xpGain * (cargo.xpMult or 1.0) + 0.5)
    local repGain = math.random(Config.RepPerDelivery.min or 4, Config.RepPerDelivery.max or 18)
    local newXp = (row.xp or 0) + xpGain
    local newRep = (row.reputation or 0) + repGain
    local newLevel = TruckingShared.LevelFromXp(newXp)
    local licenses = decodeLicenses(row.licenses)
    if newLevel >= (Config.Unlocks.heavy_truck_license or 5) then
        licenses.heavy_truck = true
    end
    saveProfile(citizenid, {
        xp = newXp,
        reputation = newRep,
        level = newLevel,
        total_deliveries = (row.total_deliveries or 0) + 1,
        total_earned = (row.total_earned or 0) + pay,
        licenses = encodeLicenses(licenses),
    })
    MySQL.insert.await([[
        INSERT INTO fivempro_trucker_delivery_log
        (citizenid, company_id, cargo_type, pickup_hub, delivery_hub, pay, condition_pct, on_time)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    ]], {
        citizenid,
        profile.company_id,
        contract.cargoId,
        contract.pickupId,
        contract.deliveryId,
        pay,
        conditionPct,
        timeMult >= 1.0 and 1 or 0,
    })
    activeDeliveries[src] = nil
    TriggerClientEvent('mrp_trucking:client:clearDelivery', src)
    cb({
        ok = true,
        pay = pay,
        xpGain = xpGain,
        repGain = repGain,
        timeMult = timeMult,
        condMult = condMult,
        dashboard = buildDashboard(src),
    })
end)

QBCore.Functions.CreateCallback('mrp_trucking:server:cancelDelivery', function(src, cb)
    activeDeliveries[src] = nil
    TriggerClientEvent('mrp_trucking:client:clearDelivery', src)
    cb({ ok = true })
end)

QBCore.Functions.CreateCallback('mrp_trucking:server:failDelivery', function(src, cb, reason)
    local Player = QBCore.Functions.GetPlayer(src)
    local d = activeDeliveries[src]
    if not Player or not d then
        return cb({ ok = false })
    end
    local citizenid = Player.PlayerData.citizenid
    local row = ensureProfile(citizenid)
    local repLoss = math.random(
        Config.RepPerFailedDelivery.min or 8,
        Config.RepPerFailedDelivery.max or 20
    )
    local newRep = math.max(0, (row.reputation or 0) - repLoss)
    saveProfile(citizenid, { reputation = newRep })
    activeDeliveries[src] = nil
    TriggerClientEvent('mrp_trucking:client:clearDelivery', src)
    cb({
        ok = true,
        reason = reason or 'Misija atšaukta.',
        repLoss = repLoss,
        reputation = newRep,
        stars = TruckingShared.ReputationStars(newRep),
    })
end)

QBCore.Functions.CreateCallback('mrp_trucking:server:buyFleetVehicle', function(src, cb, model)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return cb({ ok = false }) end
    local citizenid = Player.PlayerData.citizenid
    local row = ensureProfile(citizenid)
    local profile = buildProfile(row)
    if not profile.company_id then return cb({ ok = false, reason = 'Reikia įmonės.' }) end
    local company = getCompany(profile.company_id)
    if not company or company.owner_citizenid ~= citizenid then
        return cb({ ok = false, reason = 'Tik savininkas.' })
    end
    model = string.lower(tostring(model or ''))
    local vehCfg = TruckingShared.Vehicle(model)
    if not vehCfg then return cb({ ok = false, reason = 'Nežinomas modelis.' }) end
    local shopPrice
    for _, item in ipairs(Config.FleetShop or {}) do
        if item.model == model then shopPrice = item.price break end
    end
    if not shopPrice then return cb({ ok = false, reason = 'Neparduodama.' }) end
    if (company.balance or 0) < shopPrice then return cb({ ok = false, reason = 'Nepakanka įmonės balanso.' }) end
    local plate = ('TN%s'):format(math.random(100, 999))
    MySQL.update.await('UPDATE fivempro_trucker_companies SET balance = balance - ? WHERE id = ?', { shopPrice, company.id })
    MySQL.insert.await(
        'INSERT INTO fivempro_trucker_fleet (company_id, model, label, plate) VALUES (?, ?, ?, ?)',
        { company.id, model, vehCfg.label or model, plate }
    )
    cb({ ok = true, dashboard = buildDashboard(src) })
end)

RegisterNetEvent('mrp_trucking:server:updateCondition', function(conditionPct)
    local src = source
    if activeDeliveries[src] then
        activeDeliveries[src].condition = TruckingShared.Clamp(conditionPct, 0, 100)
    end
end)

AddEventHandler('playerDropped', function()
    activeDeliveries[source] = nil
end)

exports('GetTruckerProfile', function(src)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return nil end
    return buildProfile(ensureProfile(Player.PlayerData.citizenid))
end)

exports('OpenTruckNetForPlayer', function(src)
    if not src then return end
    TriggerClientEvent('mrp_trucking:client:openUI', src, { mode = 'full' })
end)
