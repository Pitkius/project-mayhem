--[[
  Server: Dark Net — nelegalus telefonas, naktiniai užsakymai, dead drop, PIN.

  Užsakymo būsenos (status):
    'pending'   = pateikta dieną, laukia naktinio pristatymo (20:00 GTA)
    'active'    = dead drop paliktas, galima atsiimti (iki 08:00 GTA)
    'done'      = atsiimta
    'expired'   = neatsiimta iki ryto
    'cancelled' = atšaukta žaidėjo

  Aktyvus = 'pending' arba 'active' (vienu metu tik vienas vienam veikėjui).
  Visa svarbi logika tikrinama serverio pusėje.
]]

local QBCore = exports['qb-core']:GetCoreObject()

local activeOrders = {} -- [citizenid] = orderRow (pending/active cache)

-- Apsauga nuo lygiagretaus dvigubo apdorojimo (race exploit) pinigų/atsiėmimo operacijoms.
local busy = {}
local function guard(citizenid, cb, fn)
    if not citizenid then return cb({ ok = false }) end
    if busy[citizenid] then return cb({ ok = false, reason = 'Palauk akimirką.' }) end
    busy[citizenid] = true
    local ok, res = pcall(fn)
    busy[citizenid] = nil
    if not ok then
        print(('[mrp_drugs] darknet guard error: %s'):format(tostring(res)))
        return cb({ ok = false, reason = 'Serverio klaida.' })
    end
    cb(res or { ok = false })
end

-- ── GTA laikas (serverio pusėje, per qb-weathersync) ───────────────
local function gtaHour()
    if GetResourceState('qb-weathersync') ~= 'started' then return 12 end
    local ok, hour = pcall(function()
        return exports['qb-weathersync']:getTime()
    end)
    if ok and hour then return tonumber(hour) or 12 end
    return 12
end

local function gtaMinutesAbs()
    if GetResourceState('qb-weathersync') ~= 'started' then return 0 end
    local ok, mins = pcall(function()
        return exports['qb-weathersync']:getGameMinutes()
    end)
    if ok and mins then return tonumber(mins) or 0 end
    return 0
end

local function isNightNow()
    local cfg = Config.DarkNet
    local h = gtaHour()
    local s = tonumber(cfg.nightStartHour) or 20
    local e = tonumber(cfg.nightEndHour) or 8
    if s <= e then
        return h >= s and h < e
    end
    -- Langas per vidurnaktį (pvz. 20 → 8).
    return h >= s or h < e
end
DrugDarkNetIsNight = isNightNow

-- ── DB ─────────────────────────────────────────────────────────────
local function ensureTable()
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `fivempro_drugs_darknet_orders` (
        `id` int(11) NOT NULL AUTO_INCREMENT,
        `citizenid` varchar(60) NOT NULL,
        `status` varchar(20) NOT NULL DEFAULT 'pending',
        `items` longtext NOT NULL,
        `total` int(11) NOT NULL DEFAULT 0,
        `pin` varchar(12) DEFAULT NULL,
        `drop_x` double DEFAULT NULL,
        `drop_y` double DEFAULT NULL,
        `drop_z` double DEFAULT NULL,
        `radius` float NOT NULL DEFAULT 70,
        `created_gmin` int(11) NOT NULL DEFAULT 0,
        `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
        PRIMARY KEY (`id`),
        KEY `citizenid` (`citizenid`),
        KEY `status` (`status`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;]])
end

local function decodeItems(order)
    if type(order.items) == 'table' then return order.items end
    local ok, decoded = pcall(json.decode, order.items or '[]')
    return (ok and decoded) or {}
end

-- ── Konfigūracijos pagalbininkai ───────────────────────────────────
local function getDarknetProduct(id)
    for _, p in ipairs((Config.DarkNet and Config.DarkNet.products) or {}) do
        if p.id == id then return p end
    end
end

local function genPin()
    local len = tonumber(Config.DarkNet.pinLength) or 4
    local pin = ''
    for _ = 1, len do
        pin = pin .. tostring(math.random(0, 9))
    end
    return pin
end

local function randomDropLocation()
    local locs = (Config.DarkNet and Config.DarkNet.deadDropLocations) or {}
    if #locs == 0 then return nil end
    return locs[math.random(1, #locs)]
end

-- ── Užsakymo būsenos siuntimas klientui ────────────────────────────
local function orderPublic(order)
    if not order then return nil end
    return {
        id = order.id,
        status = order.status,
        items = decodeItems(order),
        total = order.total,
        radius = order.radius,
        hasDrop = order.drop_x ~= nil,
        pin = order.pin, -- rodomas tik savininkui savo UI/SMS
    }
end

local function notifyOwnerOrder(src, order)
    if not src then return end
    TriggerClientEvent('mrp_drugs:client:darknetOrderSync', src, orderPublic(order))
end

local function spawnDropForOwner(src, order)
    if not src or not order or order.drop_x == nil then return end
    TriggerClientEvent('mrp_drugs:client:darknetDropActive', src, {
        id = order.id,
        drop = vector3(order.drop_x + 0.0, order.drop_y + 0.0, order.drop_z + 0.0),
        radius = order.radius,
        prop = Config.DarkNet.dropProp,
    })
end

local function clearDropForOwner(src, orderId)
    if not src then return end
    TriggerClientEvent('mrp_drugs:client:darknetDropClear', src, orderId)
end

-- ── Užsakymo aktyvavimas (dead drop paliekamas) ────────────────────
local function activateOrder(order)
    local drop = randomDropLocation()
    if not drop then return end
    order.status = 'active'
    order.pin = order.pin or genPin()
    order.drop_x, order.drop_y, order.drop_z = drop.x, drop.y, drop.z
    order.radius = (Config.DarkNet.searchRadius or 70.0)

    MySQL.update.await([[
        UPDATE fivempro_drugs_darknet_orders
        SET status = 'active', pin = ?, drop_x = ?, drop_y = ?, drop_z = ?, radius = ?
        WHERE id = ?
    ]], { order.pin, order.drop_x, order.drop_y, order.drop_z, order.radius, order.id })

    activeOrders[order.citizenid] = order

    local msg = (Config.DarkNet.sms.dropReady or 'Siunta palikta. PIN: %s'):format(order.pin)
    DrugPlayer.sendSms(order.citizenid, msg)

    local Player = QBCore.Functions.GetPlayerByCitizenId(order.citizenid)
    if Player then
        local psrc = Player.PlayerData.source
        notifyOwnerOrder(psrc, order)
        spawnDropForOwner(psrc, order)
    end
end

local function expireOrder(order)
    order.status = 'expired'
    MySQL.update.await("UPDATE fivempro_drugs_darknet_orders SET status = 'expired' WHERE id = ?", { order.id })
    activeOrders[order.citizenid] = nil
    DrugPlayer.sendSms(order.citizenid, Config.DarkNet.sms.orderExpired or 'Siunta pradingo.')
    local Player = QBCore.Functions.GetPlayerByCitizenId(order.citizenid)
    if Player then
        local psrc = Player.PlayerData.source
        clearDropForOwner(psrc, order.id)
        notifyOwnerOrder(psrc, nil)
    end
end

-- ── Aktyvaus užsakymo užkrovimas ───────────────────────────────────
local function loadActiveOrder(citizenid)
    if not citizenid then return nil end
    local row = MySQL.single.await([[
        SELECT * FROM fivempro_drugs_darknet_orders
        WHERE citizenid = ? AND status IN ('pending','active')
        ORDER BY id DESC LIMIT 1
    ]], { citizenid })
    activeOrders[citizenid] = row or nil
    return row
end

local function getActiveOrder(citizenid)
    if activeOrders[citizenid] then return activeOrders[citizenid] end
    return loadActiveOrder(citizenid)
end
DrugDarkNetGetActiveOrder = getActiveOrder

-- ═══════════════════════════════════════════════════════════════════
--  CALLBACK: Dark Net būsena (asortimentas + esamas užsakymas + prieiga)
-- ═══════════════════════════════════════════════════════════════════
QBCore.Functions.CreateCallback('mrp_drugs:server:darknetGetState', function(src, cb)
    if not (Config.DarkNet and Config.DarkNet.enabled) then
        return cb({ ok = false, reason = 'Dark Net išjungtas.' })
    end
    if not DrugPlayer.hasDarknetAccess(src) then
        return cb({ ok = false, reason = 'Nėra prieigos.' })
    end
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return cb({ ok = false }) end

    local state = DrugPlayer.buildClientState(src)
    local citizenid = Player.PlayerData.citizenid

    local products = {}
    for _, p in ipairs(Config.DarkNet.products or {}) do
        products[#products + 1] = {
            id = p.id,
            item = p.item,
            label = p.label,
            level = p.level,
            pricePerUnit = p.pricePerUnit,
            minAmount = p.minAmount,
            maxAmount = p.maxAmount,
            defaultAmount = p.defaultAmount,
            locked = not DrugPlayer.levelUnlocked(src, p.level),
        }
    end

    cb({
        ok = true,
        products = products,
        order = orderPublic(getActiveOrder(citizenid)),
        levelUnlocked = state.levelUnlocked,
        isNight = isNightNow(),
        nightStart = Config.DarkNet.nightStartHour,
        nightEnd = Config.DarkNet.nightEndHour,
    })
end)

-- ═══════════════════════════════════════════════════════════════════
--  CALLBACK: pateikti užsakymą
-- ═══════════════════════════════════════════════════════════════════
QBCore.Functions.CreateCallback('mrp_drugs:server:darknetPlaceOrder', function(src, cb, cart)
    if not (Config.DarkNet and Config.DarkNet.enabled) then
        return cb({ ok = false, reason = 'Dark Net išjungtas.' })
    end
    if not DrugPlayer.hasDarknetAccess(src) then
        return cb({ ok = false, reason = 'Nėra prieigos.' })
    end
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return cb({ ok = false }) end
    local citizenid = Player.PlayerData.citizenid

    guard(citizenid, cb, function()
        if getActiveOrder(citizenid) then
            return { ok = false, reason = 'Jau turi aktyvų užsakymą.' }
        end
        if type(cart) ~= 'table' then
            return { ok = false, reason = 'Netinkamas užsakymas.' }
        end

        -- Sudarom patikrintą krepšelį (kainos ir kiekiai iš serverio konfigūracijos).
        local items = {}
        local total = 0
        for _, line in ipairs(cart) do
            local product = getDarknetProduct(tostring(line.id or ''))
            if product then
                if not DrugPlayer.levelUnlocked(src, product.level) then
                    return { ok = false, reason = 'Neatrakintas reikalingas lygis.' }
                end
                local amount = math.floor(tonumber(line.amount) or 0)
                amount = math.max(product.minAmount or 1, math.min(product.maxAmount or 100, amount))
                local cost = amount * (product.pricePerUnit or 0)
                items[#items + 1] = { id = product.id, item = product.item, amount = amount, unit = product.pricePerUnit }
                total = total + cost
            end
        end

        if #items == 0 or total <= 0 then
            return { ok = false, reason = 'Tuščias arba netinkamas užsakymas.' }
        end
        if total > (Config.DarkNet.maxOrderValue or 250000) then
            return { ok = false, reason = 'Per didelis užsakymas.' }
        end

        if not DrugPlayer.canAffordDirty(Player, total) then
            return { ok = false, reason = 'Trūksta nešvarių pinigų.' }
        end
        if not DrugPlayer.chargeDirty(src, Player, total, 'mrp_drugs:darknet-order') then
            return { ok = false, reason = 'Nepavyko nurašyti pinigų.' }
        end

        local nightNow = isNightNow()
        local status = nightNow and 'active' or 'pending'
        local pin = nightNow and genPin() or nil
        local drop = nightNow and randomDropLocation() or nil
        local radius = Config.DarkNet.searchRadius or 70.0
        local gmin = gtaMinutesAbs()

        local orderId = MySQL.insert.await([[
            INSERT INTO fivempro_drugs_darknet_orders
            (citizenid, status, items, total, pin, drop_x, drop_y, drop_z, radius, created_gmin)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ]], {
            citizenid, status, json.encode(items), total, pin,
            drop and drop.x or nil, drop and drop.y or nil, drop and drop.z or nil,
            radius, gmin,
        })

        if not orderId then
            -- Grąžinam pinigus, jei nepavyko išsaugoti.
            Player.Functions.AddItem('markedbills', 1, false, { worth = total })
            return { ok = false, reason = 'Serverio klaida — pinigai grąžinti.' }
        end

        local order = {
            id = orderId, citizenid = citizenid, status = status,
            items = items, total = total, pin = pin,
            drop_x = drop and drop.x or nil, drop_y = drop and drop.y or nil, drop_z = drop and drop.z or nil,
            radius = radius, created_gmin = gmin,
        }
        activeOrders[citizenid] = order

        if nightNow then
            local msg = (Config.DarkNet.sms.dropReady or 'Siunta palikta. PIN: %s'):format(pin)
            DrugPlayer.sendSms(citizenid, msg)
            spawnDropForOwner(src, order)
        else
            DrugPlayer.sendSms(citizenid, Config.DarkNet.sms.orderAcceptedDay or 'Užsakymas priimtas.')
        end

        notifyOwnerOrder(src, order)
        return { ok = true, order = orderPublic(order), night = nightNow }
    end)
end)

-- ═══════════════════════════════════════════════════════════════════
--  CALLBACK: atšaukti užsakymą (pinigai negrąžinami — kaip aprašyta)
-- ═══════════════════════════════════════════════════════════════════
QBCore.Functions.CreateCallback('mrp_drugs:server:darknetCancelOrder', function(src, cb)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return cb({ ok = false }) end
    local citizenid = Player.PlayerData.citizenid
    local order = getActiveOrder(citizenid)
    if not order then return cb({ ok = false, reason = 'Nėra aktyvaus užsakymo.' }) end

    order.status = 'cancelled'
    MySQL.update.await("UPDATE fivempro_drugs_darknet_orders SET status = 'cancelled' WHERE id = ?", { order.id })
    activeOrders[citizenid] = nil
    clearDropForOwner(src, order.id)
    notifyOwnerOrder(src, nil)
    cb({ ok = true })
end)

-- ═══════════════════════════════════════════════════════════════════
--  CALLBACK: atsiimti siuntą (PIN patikra serverio pusėje)
-- ═══════════════════════════════════════════════════════════════════
QBCore.Functions.CreateCallback('mrp_drugs:server:darknetCollect', function(src, cb, orderId, pin)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return cb({ ok = false }) end
    local citizenid = Player.PlayerData.citizenid

    guard(citizenid, cb, function()
        local order = getActiveOrder(citizenid)

        if not order or tonumber(order.id) ~= tonumber(orderId) then
            return { ok = false, reason = 'Užsakymas nerastas.' }
        end
        if order.status ~= 'active' or order.drop_x == nil then
            return { ok = false, reason = 'Siunta dar nepristatyta.' }
        end
        if not isNightNow() then
            return { ok = false, reason = 'Per vėlu — siunta jau dingo.' }
        end
        if tostring(pin or '') ~= tostring(order.pin or '') then
            return { ok = false, reason = 'Neteisingas PIN.' }
        end

        -- Ar žaidėjas tikrai prie dead drop (serverio pusės koordinatės).
        local ped = GetPlayerPed(src)
        local pcoords = GetEntityCoords(ped)
        local dropPos = vector3(order.drop_x + 0.0, order.drop_y + 0.0, order.drop_z + 0.0)
        local maxDist = (Config.DarkNet.interactDist or 2.0) + 2.0
        if #(pcoords - dropPos) > maxDist then
            return { ok = false, reason = 'Per toli nuo siuntos.' }
        end

        local items = decodeItems(order)

        -- Patikrinam ar tilps į inventorių.
        if GetResourceState('qb-inventory') == 'started' then
            for _, it in ipairs(items) do
                local canAdd = exports['qb-inventory']:CanAddItem(src, it.item, it.amount)
                if not canAdd then
                    return { ok = false, reason = 'Inventorius pilnas — atsilaisvink ir bandyk vėl.' }
                end
            end
        end

        -- Sinchroniškai užrakinam užsakymą (kad lygiagretus atsiėmimas negautų dublikatų).
        order.status = 'done'

        for _, it in ipairs(items) do
            Player.Functions.AddItem(it.item, it.amount, false)
            local shared = QBCore.Shared.Items[it.item]
            if shared then
                TriggerClientEvent('inventory:client:ItemBox', src, shared, 'add', it.amount)
            end
        end

        MySQL.update.await("UPDATE fivempro_drugs_darknet_orders SET status = 'done' WHERE id = ?", { order.id })
        activeOrders[citizenid] = nil

        clearDropForOwner(src, order.id)
        notifyOwnerOrder(src, nil)
        DrugPlayer.sendSms(citizenid, Config.DarkNet.sms.orderCollected or 'Malonu dirbti.')
        return { ok = true }
    end)
end)

-- ═══════════════════════════════════════════════════════════════════
--  CALLBACK: pirkti Dark Net telefoną
-- ═══════════════════════════════════════════════════════════════════
QBCore.Functions.CreateCallback('mrp_drugs:server:darknetBuyPhone', function(src, cb)
    if not (Config.DarkNet and Config.DarkNet.enabled) then
        return cb({ ok = false, reason = 'Dark Net išjungtas.' })
    end
    if not DrugPlayer.hasDarknetAccess(src) then
        return cb({ ok = false, reason = 'Neturi prieigos prie šio pardavėjo.' })
    end
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return cb({ ok = false }) end
    local citizenid = Player.PlayerData.citizenid

    guard(citizenid, cb, function()
        local phoneItem = Config.DarkNet.phoneItem or 'darknet_phone'
        local price = tonumber(Config.DarkNet.phonePrice) or 3500

        if GetResourceState('qb-inventory') == 'started' then
            local canAdd = exports['qb-inventory']:CanAddItem(src, phoneItem, 1)
            if not canAdd then return { ok = false, reason = 'Inventorius pilnas.' } end
        end
        if not DrugPlayer.canAffordDirty(Player, price) then
            return { ok = false, reason = 'Trūksta nešvarių pinigų.' }
        end
        if not DrugPlayer.chargeDirty(src, Player, price, 'mrp_drugs:darknet-phone') then
            return { ok = false, reason = 'Nepavyko nurašyti pinigų.' }
        end
        Player.Functions.AddItem(phoneItem, 1, false)
        local shared = QBCore.Shared.Items[phoneItem]
        if shared then TriggerClientEvent('inventory:client:ItemBox', src, shared, 'add', 1) end
        return { ok = true }
    end)
end)

-- ═══════════════════════════════════════════════════════════════════
--  NAKTINIS PLANUOKLIS (saugus intervalas, ne 0ms loop)
-- ═══════════════════════════════════════════════════════════════════
local function runScheduler()
    local night = isNightNow()

    local rows = MySQL.query.await([[
        SELECT * FROM fivempro_drugs_darknet_orders WHERE status IN ('pending','active')
    ]]) or {}

    for _, order in ipairs(rows) do
        activeOrders[order.citizenid] = order
        if night and order.status == 'pending' then
            activateOrder(order)
        elseif (not night) and order.status == 'active' then
            expireOrder(order)
        end
    end
end

CreateThread(function()
    ensureTable()
    Wait(3000)
    while true do
        pcall(runScheduler)
        Wait((tonumber(Config.DarkNet.schedulerIntervalSec) or 30) * 1000)
    end
end)

-- ── Aktyvaus užsakymo atkūrimas prisijungus / įkėlus ───────────────
local function resyncPlayer(src)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    local citizenid = Player.PlayerData.citizenid
    local order = loadActiveOrder(citizenid)
    notifyOwnerOrder(src, order)
    if order and order.status == 'active' and order.drop_x ~= nil and isNightNow() then
        spawnDropForOwner(src, order)
    end
end

RegisterNetEvent('QBCore:Server:OnPlayerLoaded', function()
    local src = source
    SetTimeout(4000, function()
        if QBCore.Functions.GetPlayer(src) then resyncPlayer(src) end
    end)
end)

RegisterNetEvent('mrp_drugs:server:darknetRequestSync', function()
    resyncPlayer(source)
end)

-- ── Telefono itemo naudojimas ──────────────────────────────────────
local function buildDarknetOpenPayload(src)
    local products = {}
    for _, p in ipairs((Config.DarkNet and Config.DarkNet.products) or {}) do
        products[#products + 1] = {
            id = p.id, item = p.item, label = p.label, level = p.level,
            pricePerUnit = p.pricePerUnit, minAmount = p.minAmount,
            maxAmount = p.maxAmount, defaultAmount = p.defaultAmount,
            locked = not DrugPlayer.levelUnlocked(src, p.level),
        }
    end
    local Player = QBCore.Functions.GetPlayer(src)
    local citizenid = Player and Player.PlayerData.citizenid
    local state = DrugPlayer.buildClientState(src)
    return {
        products = products,
        order = orderPublic(citizenid and getActiveOrder(citizenid) or nil),
        isNight = isNightNow(),
        nightStart = Config.DarkNet.nightStartHour,
        nightEnd = Config.DarkNet.nightEndHour,
        levelUnlocked = state.levelUnlocked,
    }
end

CreateThread(function()
    Wait(1200)
    if not (Config.DarkNet and Config.DarkNet.enabled) then return end
    --- darknet_phone open handled by mrp_phone (PhoneID shell). Market data via exports.
    print('[mrp_drugs] DarkNet phone item opens via mrp_phone.')
end)

exports('DarkNetHasAccess', function(src)
    return DrugPlayer.hasDarknetAccess(src) == true
end)

exports('DarkNetBuildMarketPayload', function(src)
    return buildDarknetOpenPayload(src)
end)

exports('DarkNetIsNight', function()
    return isNightNow()
end)
