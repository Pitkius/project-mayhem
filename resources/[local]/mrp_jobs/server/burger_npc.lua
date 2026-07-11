--[[
  mrp_jobs — Burger Joint užsakymų branduolys + NPC klientai + kasininkas + self-service.
  Užsakymų turinį generuoja SERVERIS (klientas nediktuoja). Užsakymai saugomi
  serverio atmintyje pagal burgerinę.
]]

local QBCore = exports['qb-core']:GetCoreObject()

BurgerOrders = BurgerOrders or {}

local orders = {}      -- [orderId] = order
local seq = 0

local BN = Config.BurgerNpc
local RB = Config.Rewards.burger
local SS = Config.Rewards.burgerNpcSelfService

-- ── Pagalbininkai ─────────────────────────────────────────────────
local function jointExists(jointId)
    return Config.Locations.burger.joints[jointId] ~= nil
end

local function ordersForJoint(jointId, statusFilter)
    local out = {}
    for _, o in pairs(orders) do
        if o.jointId == jointId and (not statusFilter or o.status == statusFilter) then
            out[#out + 1] = o
        end
    end
    return out
end

local function activeCountForJoint(jointId)
    local n = 0
    for _, o in pairs(orders) do
        if o.jointId == jointId and o.status ~= 'served' then n = n + 1 end
    end
    return n
end

-- Viešas API (naudoja ir server/burger.lua kepėjo logika).
function BurgerOrders.get(id) return orders[tonumber(id)] end

function BurgerOrders.remove(id)
    orders[tonumber(id)] = nil
end

-- Serializuoja užsakymą klientui (be jautrių serverio laukų).
local function orderView(o)
    return {
        id = o.id, jointId = o.jointId, menuId = o.menuId, label = o.label,
        line = o.line, items = o.items, produced = o.produced,
        status = o.status, createdAt = o.createdAt, waitSec = os.time() - o.createdAt,
        paid = o.paid == true,
    }
end

-- Atnaujina kasos ir virtuvės UI visiems burgerinės darbuotojams.
function BurgerOrders.refreshJoint(jointId)
    local cashiers = JobManager.findWorkers('burger', 'cashier', jointId)
    local cooks = JobManager.findWorkers('burger', 'cook', jointId)

    local all = {}
    for _, o in ipairs(ordersForJoint(jointId)) do all[#all + 1] = orderView(o) end
    for _, s in ipairs(cashiers) do
        TriggerClientEvent('mrp_jobs:client:burger:orders', s.source, all)
    end

    local cooking = {}
    for _, o in ipairs(ordersForJoint(jointId)) do
        if o.status == 'cooking' or o.status == 'ready' then cooking[#cooking + 1] = orderView(o) end
    end
    for _, s in ipairs(cooks) do
        TriggerClientEvent('mrp_jobs:client:burger:kitchen', s.source, cooking)
    end
    -- Solo: jei nėra kepėjo, kasininkas mato ir virtuvę.
    if #cooks == 0 and (Config.Jobs.burger.solo) then
        for _, s in ipairs(cashiers) do
            TriggerClientEvent('mrp_jobs:client:burger:kitchen', s.source, cooking)
        end
    end
end

-- ── NPC atvyko prie kasos → serveris sukuria užsakymą ─────────────
QBCore.Functions.CreateCallback('mrp_jobs:server:burger:npcArrived', function(src, cb, jointId, npcNet)
    if not Security.rateLimit(src, 'burger_npc', Config.RateLimit.order) then return cb(false) end
    local s = JobManager.getBySource(src)
    if not s or s.jobType ~= 'burger' or s.role ~= 'cashier' or s.locationId ~= jointId then return cb(false) end
    if not jointExists(jointId) then return cb(false) end
    if activeCountForJoint(jointId) >= (BN.queue.maxActive or 5) then return cb(false) end

    local menu = Config.RandomBurgerOrder()
    seq = seq + 1
    local o = {
        id = seq, jointId = jointId, menuId = menu.id, label = menu.label,
        line = BN.voice.lines[menu.id] or menu.label,
        items = {}, produced = {},
        status = 'pending', createdAt = os.time(),
        cashier = src, cook = nil, npcNet = npcNet, paid = false,
    }
    for k, v in pairs(menu.items) do o.items[k] = v; o.produced[k] = 0 end
    orders[seq] = o

    BurgerOrders.refreshJoint(jointId)
    cb({ ok = true, orderId = seq, menuId = menu.id, label = menu.label, line = o.line, items = o.items })
end)

-- ── Kasininkas patvirtina užsakymą → į virtuvę ────────────────────
RegisterNetEvent('mrp_jobs:server:burger:confirmOrder', function(orderId)
    local src = source
    if not Security.rateLimit(src, 'burger_confirm', Config.RateLimit.order) then return end
    local o = orders[tonumber(orderId)]
    if not o then return end
    local s = JobManager.getBySource(src)
    if not s or s.jobType ~= 'burger' or s.role ~= 'cashier' or s.locationId ~= o.jointId then return end
    if o.status ~= 'pending' then return end
    o.status = 'cooking'
    BurgerOrders.refreshJoint(o.jointId)
end)

-- ── NPC išeina nesulaukęs (kasininko klientas praneša) ─────────────
RegisterNetEvent('mrp_jobs:server:burger:npcLeft', function(orderId)
    local src = source
    local o = orders[tonumber(orderId)]
    if not o then return end
    local s = JobManager.getBySource(src)
    if not s or s.locationId ~= o.jointId then return end
    -- Tik jei dar nepradėta gaminti / nebaigta.
    if o.status == 'pending' then
        BurgerOrders.remove(orderId)
        BurgerOrders.refreshJoint(o.jointId)
    end
end)

-- ── Self-service: pirkti maistą iš NPC (kai nedirba kasininkas) ────
QBCore.Functions.CreateCallback('mrp_jobs:server:burger:buyFood', function(src, cb, jointId, itemKey)
    if not SS.enabled then return cb({ ok = false, reason = 'disabled' }) end
    if not Security.rateLimit(src, 'burger_buy', 800) then return cb({ ok = false, reason = 'rate' }) end
    if not jointExists(jointId) then return cb({ ok = false, reason = 'bad_joint' }) end
    -- Darbuotojai turi pirmenybę: jei dirba kasininkas — self-service išjungtas.
    if JobManager.hasWorker('burger', 'cashier', jointId) then return cb({ ok = false, reason = 'staffed' }) end

    local price = SS.prices[itemKey]
    if not price then return cb({ ok = false, reason = 'bad_item' }) end

    local joint = Config.Locations.burger.joints[jointId]
    local reg = joint.registers[1]
    if reg and not Security.isNear(src, reg.coords, 3.0) then return cb({ ok = false, reason = 'too_far' }) end

    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return cb({ ok = false, reason = 'no_player' }) end
    if (Player.PlayerData.money.cash or 0) < price then return cb({ ok = false, reason = 'no_money' }) end
    if not Player.Functions.RemoveMoney('cash', price, 'burger-selfservice') then
        return cb({ ok = false, reason = 'no_money' })
    end
    if not Player.Functions.AddItem(itemKey, 1, false, nil, 'burger-selfservice') then
        Player.Functions.AddMoney('cash', price, 'burger-selfservice-refund')
        return cb({ ok = false, reason = 'inv_full' })
    end
    cb({ ok = true, item = itemKey, price = price })
end)

-- Kasos/virtuvės UI duomenų užklausa (atidarant NUI).
QBCore.Functions.CreateCallback('mrp_jobs:server:burger:getBoard', function(src, cb)
    local s = JobManager.getBySource(src)
    if not s or s.jobType ~= 'burger' then return cb(false) end
    local list = {}
    for _, o in ipairs(ordersForJoint(s.locationId)) do list[#list + 1] = orderView(o) end
    cb({ role = s.role, jointId = s.locationId, orders = list })
end)

-- Valymas: nutraukus darbą, pašalinam to darbuotojo (kasininko) neapmokėtus užsakymus.
local function purgeJointIfEmpty(jointId)
    if not JobManager.hasWorker('burger', 'cashier', jointId)
    and not JobManager.hasWorker('burger', 'cook', jointId) then
        for id, o in pairs(orders) do
            if o.jointId == jointId and o.status ~= 'served' then orders[id] = nil end
        end
    end
end
BurgerOrders.purgeJointIfEmpty = purgeJointIfEmpty
