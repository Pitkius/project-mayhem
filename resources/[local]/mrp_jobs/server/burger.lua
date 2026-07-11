--[[
  mrp_jobs — Burger Joint: kepėjo gamyba, užsakymo užbaigimas, atlygio paskirstymas.
  + bendras 'burger' darbo handleris (visoms 3 pozicijoms).
  Pagaminti itemai rišami prie užsakymo per info.orderId — kaupti pardavimui neįmanoma.
]]

local QBCore = exports['qb-core']:GetCoreObject()

local RB = Config.Rewards.burger
local pendingProduce = {} -- [src] = { token, orderId, itemName, at }

-- Visų burgerio produktų sąrašas (naudojama valymui).
local PRODUCT_ITEMS = {}
for k in pairs(RB.perItem) do PRODUCT_ITEMS[k] = true end

local QSCORE = { poor = 0.25, normal = 0.55, good = 0.8, perfect = 1.0 }

-- ── Registruojam burgerinės produktus kaip "valgomus" (useable) ───
CreateThread(function()
    for item in pairs(PRODUCT_ITEMS) do
        QBCore.Functions.CreateUseableItem(item, function(source)
            local Player = QBCore.Functions.GetPlayer(source)
            if not Player then return end
            if Player.Functions.RemoveItem(item, 1) then
                TriggerClientEvent('mrp_jobs:client:eatFood', source, item)
            end
        end)
    end
    -- Vaisiai valgomi (apple/strawberry) — registruojama vape.lua? čia paprasčiau:
    for _, fr in pairs({ 'apple', 'strawberry' }) do
        QBCore.Functions.CreateUseableItem(fr, function(source)
            local Player = QBCore.Functions.GetPlayer(source)
            if not Player then return end
            if Player.Functions.RemoveItem(fr, 1) then
                TriggerClientEvent('mrp_jobs:client:eatFood', source, fr)
            end
        end)
    end
end)

-- ── Inventoriaus valymas: pašalina prie užsakymo pririštus itemus ─
local function removeOrderItems(src, orderId)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return 0 end
    local removed = 0
    for _, slot in pairs(Player.PlayerData.items or {}) do
        if slot and slot.info and slot.info.orderId == orderId then
            if Player.Functions.RemoveItem(slot.name, slot.amount, slot.slot) then
                removed = removed + slot.amount
            end
        end
    end
    return removed
end

local function purgeOrderBoundItems(src)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    for _, slot in pairs(Player.PlayerData.items or {}) do
        if slot and slot.info and slot.info.orderId and PRODUCT_ITEMS[slot.name] then
            Player.Functions.RemoveItem(slot.name, slot.amount, slot.slot)
        end
    end
end

-- ── 'burger' darbo handleris ──────────────────────────────────────
JobManager.registerHandler('burger', {
    canStart = function(Player, role, locationId)
        if not locationId or not Config.Locations.burger.joints[locationId] then return false, 'bad_joint' end
        if role == 'cleaner' then
            local left = Cooldowns.remaining(Player.PlayerData.source, Config.Jobs.burger.cooldownKey)
            if left > 0 then return false, 'cooldown' end
        end
        return true
    end,
    onStart = function(session, Player)
        if session.role == 'cleaner' and Cleaner then
            Cleaner.onStart(session)
        end
    end,
    onStop = function(session, Player, reason)
        if session.role == 'cleaner' and Cleaner then
            Cleaner.onStop(session, reason)
        end
        if session.role == 'cook' or session.role == 'cashier' then
            purgeOrderBoundItems(session.source)
            if BurgerOrders and BurgerOrders.purgeJointIfEmpty then
                -- atidedam, kad refreshJoint spėtų (darbuotojas jau pašalintas iš sesijų).
                local joint = session.locationId
                SetTimeout(50, function() BurgerOrders.purgeJointIfEmpty(joint) end)
            end
        end
    end,
    buildClientState = function(session)
        if session.role == 'cleaner' and Cleaner then
            return Cleaner.buildClientState(session)
        end
        return { burger = { role = session.role, jointId = session.locationId } }
    end,
})

-- ── Kepėjas pradeda gaminti vieną produktą ────────────────────────
QBCore.Functions.CreateCallback('mrp_jobs:server:burger:startProduce', function(src, cb, orderId, itemName)
    if not Security.rateLimit(src, 'burger_produce', 800) then return cb({ ok = false, reason = 'rate' }) end
    local s = JobManager.getBySource(src)
    if not s or s.jobType ~= 'burger' then return cb({ ok = false, reason = 'no_job' }) end
    if s.role ~= 'cook' and not (s.role == 'cashier' and Config.Jobs.burger.solo) then
        return cb({ ok = false, reason = 'bad_role' })
    end
    local o = BurgerOrders.get(orderId)
    if not o or o.jointId ~= s.locationId then return cb({ ok = false, reason = 'no_order' }) end
    if o.status ~= 'cooking' then return cb({ ok = false, reason = 'not_cooking' }) end
    if not o.items[itemName] then return cb({ ok = false, reason = 'not_needed' }) end
    if (o.produced[itemName] or 0) >= o.items[itemName] then return cb({ ok = false, reason = 'enough' }) end

    local token = ('%d-%d-%s'):format(src, GetGameTimer(), itemName)
    pendingProduce[src] = { token = token, orderId = o.id, itemName = itemName, at = GetGameTimer() }
    cb({ ok = true, token = token, minigame = 'burger_grill' })
end)

-- ── Kepėjas baigia gaminti (patikra + itemas su orderId metadata) ─
QBCore.Functions.CreateCallback('mrp_jobs:server:burger:finishProduce', function(src, cb, token, success, quality)
    local p = pendingProduce[src]
    pendingProduce[src] = nil
    if not p or p.token ~= token then return cb({ ok = false, reason = 'bad_token' }) end
    if GetGameTimer() - p.at > 60000 then return cb({ ok = false, reason = 'expired' }) end

    local s = JobManager.getBySource(src)
    if not s or s.jobType ~= 'burger' then return cb({ ok = false, reason = 'no_job' }) end
    local o = BurgerOrders.get(p.orderId)
    if not o or o.status ~= 'cooking' then return cb({ ok = false, reason = 'no_order' }) end
    if (o.produced[p.itemName] or 0) >= o.items[p.itemName] then return cb({ ok = false, reason = 'enough' }) end
    if success ~= true then return cb({ ok = false, reason = 'failed' }) end

    -- Kokybė (validuojam iš serverio pusės pagal leidžiamas reikšmes).
    local q = quality
    if not QSCORE[q] then q = 'normal' end

    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return cb({ ok = false, reason = 'no_player' }) end
    if not Player.Functions.AddItem(p.itemName, 1, false, { orderId = o.id, quality = q }, 'burger-cook') then
        return cb({ ok = false, reason = 'inv_full' })
    end

    o.produced[p.itemName] = (o.produced[p.itemName] or 0) + 1
    o.cook = src
    o.qualitySum = (o.qualitySum or 0) + QSCORE[q]
    o.qualityCount = (o.qualityCount or 0) + 1

    -- Ar visi produktai pagaminti?
    local allDone = true
    for item, need in pairs(o.items) do
        if (o.produced[item] or 0) < need then allDone = false break end
    end
    if allDone then o.status = 'ready' end

    BurgerOrders.refreshJoint(o.jointId)
    cb({ ok = true, ready = o.status == 'ready' })
end)

-- ── Užsakymo pridavimas NPC (atlygis) ─────────────────────────────
QBCore.Functions.CreateCallback('mrp_jobs:server:burger:serve', function(src, cb, orderId)
    if not Security.rateLimit(src, 'burger_serve', 900) then return cb({ ok = false, reason = 'rate' }) end
    local s = JobManager.getBySource(src)
    if not s or s.jobType ~= 'burger' then return cb({ ok = false, reason = 'no_job' }) end
    local o = BurgerOrders.get(orderId)
    if not o or o.jointId ~= s.locationId then return cb({ ok = false, reason = 'no_order' }) end
    if o.status ~= 'ready' then return cb({ ok = false, reason = 'not_ready' }) end
    if o.paid then return cb({ ok = false, reason = 'already_paid' }) end

    -- Patikra: pagaminti itemai realiai egzistuoja kepėjo inventoriuje.
    local cookSrc = o.cook or src
    local removed = removeOrderItems(cookSrc, o.id)
    local needed = 0
    for _, n in pairs(o.items) do needed = needed + n end
    if removed < needed then
        return cb({ ok = false, reason = 'items_missing' })
    end

    -- Atlygio skaičiavimas (serveris).
    local base = RB.orderBaseBonus or 0
    for item, count in pairs(o.items) do
        base = base + (RB.perItem[item] or 0) * count
    end
    local avgScore = o.qualityCount and o.qualityCount > 0 and (o.qualitySum / o.qualityCount) or 0.55
    local qtier = Utils.scoreToQuality(avgScore, { normal = 0.4, good = 0.7, perfect = 0.95 })
    local total = Rewards.applyQuality(base, qtier, Config.Rewards.qualityMult)

    -- Paskirstymas kasininkui / kepėjui.
    o.paid = true
    o.status = 'served'
    local account = RB.account or 'cash'

    local cashiers = JobManager.findWorkers('burger', 'cashier', o.jointId)
    local cashierSrc = (cashiers[1] and cashiers[1].source) or o.cashier
    local twoRoles = cashierSrc and cookSrc and cashierSrc ~= cookSrc
        and JobManager.getBySource(cashierSrc) and JobManager.getBySource(cookSrc)

    if twoRoles then
        local cashierCut = math.floor(total * (RB.split.cashier or 0.35))
        local cookCut = total - cashierCut
        Rewards.pay(cashierSrc, cashierCut, account, 'burger-order-cashier', { orderId = o.id })
        Rewards.pay(cookSrc, cookCut, account, 'burger-order-cook', { orderId = o.id })
    else
        -- Solo: viską gauna dirbantis (pirmiausia kasininkas, kitu atveju kepėjas).
        local payTo = (cashierSrc and JobManager.getBySource(cashierSrc)) and cashierSrc or cookSrc
        Rewards.pay(payTo, total, account, 'burger-order-solo', { orderId = o.id })
    end

    -- Praneša kasininkui atlaisvinti NPC.
    if cashierSrc then TriggerClientEvent('mrp_jobs:client:burger:orderServed', cashierSrc, o.id) end

    BurgerOrders.refreshJoint(o.jointId)
    SetTimeout(1500, function()
        BurgerOrders.remove(o.id)
        BurgerOrders.refreshJoint(o.jointId)
    end)
    cb({ ok = true, total = total })
end)
