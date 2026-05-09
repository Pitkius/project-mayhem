local QBCore = exports['qb-core']:GetCoreObject()

local function hasGangAdminPermission(src)
    for _, perm in ipairs(Config.AdminPermissions or {}) do
        if QBCore.Functions.HasPermission(src, perm) then
            return true
        end
    end
    return false
end

local function getPlayerGang(src)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return nil end
    return MySQL.single.await([[
        SELECT gm.gang_id, gm.rank, g.name, g.gang_type, g.color_hex, g.reputation, g.heat
        FROM fivempro_gang_members gm
        JOIN fivempro_gangs g ON g.id = gm.gang_id
        WHERE gm.citizenid = ?
        LIMIT 1
    ]], { Player.PlayerData.citizenid })
end

local function isGangBoss(src)
    local g = getPlayerGang(src)
    return g and (tonumber(g.rank) or 0) >= 4, g
end

local function getGangById(gangId)
    return MySQL.single.await('SELECT * FROM fivempro_gangs WHERE id = ? LIMIT 1', { tonumber(gangId) })
end

local function getGangMembers(gangId)
    return MySQL.query.await('SELECT citizenid, name, rank FROM fivempro_gang_members WHERE gang_id = ? ORDER BY rank DESC, name ASC', { tonumber(gangId) }) or {}
end

local function getTurfs()
    return MySQL.query.await([[
        SELECT turf_id, owner_gang_id, owner_name, progress, heat, sales_count, total_profit
        FROM fivempro_gang_turfs
        ORDER BY turf_id ASC
    ]]) or {}
end

local function createGang(src, name, gangType, colorHex)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return false, 'Nerastas žaidėjas.' end
    if getPlayerGang(src) then return false, 'Jau priklausai gaujai.' end
    name = tostring(name or ''):sub(1, 42)
    if name == '' then return false, 'Neteisingas pavadinimas.' end
    if not Config.GangTypes[tostring(gangType)] then return false, 'Neteisingas tipas.' end
    colorHex = tostring(colorHex or '#FFFFFF'):upper()

    local exists = MySQL.single.await('SELECT id FROM fivempro_gangs WHERE name = ? LIMIT 1', { name })
    if exists then return false, 'Toks pavadinimas jau naudojamas.' end

    local gangId = MySQL.insert.await('INSERT INTO fivempro_gangs (name, gang_type, color_hex, owner_citizenid) VALUES (?, ?, ?, ?)', {
        name, gangType, colorHex, Player.PlayerData.citizenid
    })
    if not gangId then return false, 'Nepavyko sukurti gaujos.' end

    MySQL.insert.await('INSERT INTO fivempro_gang_members (gang_id, citizenid, name, rank) VALUES (?, ?, ?, ?)', {
        gangId, Player.PlayerData.citizenid,
        (Player.PlayerData.charinfo.firstname or '') .. ' ' .. (Player.PlayerData.charinfo.lastname or ''),
        4
    })
    return true, gangId
end

QBCore.Functions.CreateUseableItem(Config.TabletItem, function(source)
    TriggerClientEvent('fivempro_gangs:client:openTablet', source)
end)

QBCore.Functions.CreateCallback('fivempro_gangs:server:getTabletState', function(src, cb)
    local gang = getPlayerGang(src)
    if not gang then
        return cb({ ok = true, hasGang = false, gangTypes = Config.GangTypes, turfs = getTurfs() })
    end
    cb({
        ok = true,
        hasGang = true,
        gang = gang,
        members = getGangMembers(gang.gang_id),
        turfs = getTurfs(),
        gangTypes = Config.GangTypes,
    })
end)

RegisterNetEvent('fivempro_gangs:server:createGang', function(data)
    local src = source
    local ok, result = createGang(src, data and data.name, data and data.gangType, data and data.colorHex)
    if not ok then
        return TriggerClientEvent('QBCore:Notify', src, tostring(result), 'error')
    end
    TriggerClientEvent('QBCore:Notify', src, 'Gauja užregistruota.', 'success')
end)

RegisterNetEvent('fivempro_gangs:server:buyTablet', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    local price = tonumber(Config.TabletVendor and Config.TabletVendor.tabletPrice) or 5000
    local hasCash = (Player.PlayerData.money and Player.PlayerData.money.cash or 0) >= price
    local hasBank = (Player.PlayerData.money and Player.PlayerData.money.bank or 0) >= price
    if not hasCash and not hasBank then
        return TriggerClientEvent('QBCore:Notify', src, ('Reikia $%s gang planšetei.'):format(price), 'error')
    end
    if hasCash then
        Player.Functions.RemoveMoney('cash', price, 'gang-tablet-purchase')
    else
        Player.Functions.RemoveMoney('bank', price, 'gang-tablet-purchase')
    end
    Player.Functions.AddItem(Config.TabletItem, 1)
    TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[Config.TabletItem], 'add', 1)
    TriggerClientEvent('QBCore:Notify', src, ('Nupirkta gang planšetė už $%s.'):format(price), 'success')
end)

RegisterNetEvent('fivempro_gangs:server:inviteMember', function(targetId)
    local src = source
    local isBoss, gang = isGangBoss(src)
    if not isBoss then return TriggerClientEvent('QBCore:Notify', src, 'Reikia boss rango.', 'error') end
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

RegisterNetEvent('fivempro_gangs:server:setMemberRank', function(citizenid, rank)
    local src = source
    local isBoss, gang = isGangBoss(src)
    if not isBoss then return TriggerClientEvent('QBCore:Notify', src, 'Reikia boss rango.', 'error') end
    rank = math.max(0, math.min(4, tonumber(rank) or 0))
    MySQL.update.await('UPDATE fivempro_gang_members SET rank = ? WHERE gang_id = ? AND citizenid = ?', {
        rank, gang.gang_id, tostring(citizenid or '')
    })
    TriggerClientEvent('QBCore:Notify', src, 'Nario rangas pakeistas.', 'success')
end)

RegisterNetEvent('fivempro_gangs:server:kickMember', function(citizenid)
    local src = source
    local isBoss, gang = isGangBoss(src)
    if not isBoss then return TriggerClientEvent('QBCore:Notify', src, 'Reikia boss rango.', 'error') end
    MySQL.update.await('DELETE FROM fivempro_gang_members WHERE gang_id = ? AND citizenid = ? AND rank < 4', {
        gang.gang_id, tostring(citizenid or '')
    })
    TriggerClientEvent('QBCore:Notify', src, 'Narys pašalintas.', 'success')
end)

RegisterNetEvent('fivempro_gangs:server:completeTask', function(turfId, taskType)
    local src = source
    local gang = getPlayerGang(src)
    if not gang then return end
    local reward = (Config.TaskReputation and Config.TaskReputation[tostring(taskType or '')]) or 0
    if reward <= 0 then return end

    local turf = MySQL.single.await('SELECT turf_id, owner_gang_id, progress FROM fivempro_gang_turfs WHERE turf_id = ? LIMIT 1', { tostring(turfId) })
    if not turf then return end
    local progress = (tonumber(turf.progress) or 0) + reward
    local ownerGangId = turf.owner_gang_id
    local ownerName = nil

    if progress >= (tonumber(Config.TurfClaimThreshold) or 100) then
        ownerGangId = gang.gang_id
        ownerName = gang.name
        progress = 0
    end

    MySQL.update.await([[
        UPDATE fivempro_gang_turfs
        SET progress = ?, owner_gang_id = ?, owner_name = ?
        WHERE turf_id = ?
    ]], { progress, ownerGangId, ownerName, tostring(turfId) })
    MySQL.update.await('UPDATE fivempro_gangs SET reputation = reputation + ? WHERE id = ?', { math.floor(reward / 2), gang.gang_id })
    TriggerClientEvent('QBCore:Notify', src, 'Turf progresas atnaujintas.', 'success')
end)

QBCore.Functions.CreateCallback('fivempro_gangs:server:tryDrugSale', function(src, cb, turfId, npcNetId)
    local gang = getPlayerGang(src)
    if not gang then return cb({ ok = false, reason = 'Nepriklausai gaujai.' }) end

    local turf = MySQL.single.await('SELECT owner_gang_id, heat, sales_count, total_profit FROM fivempro_gang_turfs WHERE turf_id = ? LIMIT 1', { tostring(turfId) })
    if not turf or tonumber(turf.owner_gang_id) ~= tonumber(gang.gang_id) then
        return cb({ ok = false, reason = 'Šis turf nepriklauso tavo gaujai.' })
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
    Player.Functions.AddMoney('cash', price, 'gang-turf-sale')

    local heat = math.min(Config.DrugSell.maxHeat or 100, (tonumber(turf.heat) or 0) + math.random(2, 7))
    local salesCount = (tonumber(turf.sales_count) or 0) + 1
    local totalProfit = (tonumber(turf.total_profit) or 0) + price
    MySQL.update.await('UPDATE fivempro_gang_turfs SET heat = ?, sales_count = ?, total_profit = ? WHERE turf_id = ?', {
        heat, salesCount, totalProfit, tostring(turfId)
    })
    MySQL.update.await('UPDATE fivempro_gangs SET reputation = reputation + 1, heat = LEAST(100, heat + 1) WHERE id = ?', { gang.gang_id })
    MySQL.insert.await('INSERT INTO fivempro_gang_sales_logs (gang_id, turf_id, item_name, amount, profit) VALUES (?, ?, ?, ?, ?)', {
        gang.gang_id, tostring(turfId), chosen.item, 1, price
    })

    local alertChance = (Config.DrugSell.policeAlertBase or 12) + math.floor(heat * (Config.DrugSell.policeAlertHeatFactor or 0.35))
    local alertPolice = math.random(1, 100) <= alertChance
    cb({ ok = true, item = chosen.item, price = price, alertPolice = alertPolice })
end)

QBCore.Functions.CreateCallback('fivempro_gangs:server:getAdminSnapshot', function(src, cb)
    if not hasGangAdminPermission(src) then return cb({ ok = false }) end
    local gangs = MySQL.query.await('SELECT id, name, gang_type, color_hex, reputation, heat, created_at FROM fivempro_gangs ORDER BY id ASC') or {}
    local turfs = getTurfs()
    cb({ ok = true, gangs = gangs, turfs = turfs })
end)

RegisterNetEvent('fivempro_gangs:server:adminSetGangStats', function(gangId, reputation, heat)
    local src = source
    if not hasGangAdminPermission(src) then return end
    MySQL.update.await('UPDATE fivempro_gangs SET reputation = ?, heat = ? WHERE id = ?', {
        tonumber(reputation) or 0, tonumber(heat) or 0, tonumber(gangId)
    })
    TriggerClientEvent('QBCore:Notify', src, 'Gaujos statistika atnaujinta.', 'success')
end)

RegisterNetEvent('fivempro_gangs:server:adminDeleteGang', function(gangId)
    local src = source
    if not hasGangAdminPermission(src) then return end
    gangId = tonumber(gangId)
    if not gangId then return end
    MySQL.update.await('DELETE FROM fivempro_gang_members WHERE gang_id = ?', { gangId })
    MySQL.update.await('UPDATE fivempro_gang_turfs SET owner_gang_id = NULL, owner_name = NULL, progress = 0 WHERE owner_gang_id = ?', { gangId })
    MySQL.update.await('DELETE FROM fivempro_gang_sales_logs WHERE gang_id = ?', { gangId })
    MySQL.update.await('DELETE FROM fivempro_gangs WHERE id = ?', { gangId })
    TriggerClientEvent('QBCore:Notify', src, 'Gauja ištrinta.', 'success')
end)

MySQL.ready(function()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `fivempro_gangs` (
            `id` INT NOT NULL AUTO_INCREMENT,
            `name` VARCHAR(64) NOT NULL,
            `gang_type` VARCHAR(32) NOT NULL,
            `color_hex` VARCHAR(16) NOT NULL DEFAULT '#FFFFFF',
            `owner_citizenid` VARCHAR(64) NULL,
            `reputation` INT NOT NULL DEFAULT 0,
            `heat` INT NOT NULL DEFAULT 0,
            `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`),
            UNIQUE KEY `ux_fivempro_gangs_name` (`name`)
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

    for turfId, _ in pairs(Config.Turfs or {}) do
        MySQL.insert.await('INSERT IGNORE INTO fivempro_gang_turfs (turf_id) VALUES (?)', { turfId })
    end
end)
