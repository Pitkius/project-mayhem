--[[
  mrp_jobs — VAISIŲ rinkėjas (serveris, autoritetingas).
  Vaisiai = inventoriaus itemai. Dėžės kuriamos TIK iš surinktų vaisių,
  atlygis mokamas TIK pristačius dėžes — negalima parduoti nesurinkus.
]]

local QBCore = exports['qb-core']:GetCoreObject()

local FL = Config.Locations.fruit
local RF = Config.Rewards.fruit

-- Taškų atsinaujinimas (globalus, ne per sesiją): [fruitId][index] = nextReadyUnix
local respawn = {}
local pendingPick = {} -- [src] = { token, fruitId, index, at }

local function fruitDef(id) return Config.Fruits[id] end

JobManager.registerHandler('fruit', {
    onStart = function(session)
        session.data.fruit = true
    end,
    onStop = function(session)
        pendingPick[session.source] = nil
    end,
    buildClientState = function(session)
        return { fruit = { active = true } }
    end,
})

-- ── Rinkimo pradžia ───────────────────────────────────────────────
QBCore.Functions.CreateCallback('mrp_jobs:server:fruit:startPick', function(src, cb, fruitId, index)
    if not Security.rateLimit(src, 'fruit_pick', 800) then return cb({ ok = false, reason = 'rate' }) end
    local s = JobManager.getBySource(src)
    if not s or s.jobType ~= 'fruit' then return cb({ ok = false, reason = 'no_job' }) end
    local fr = fruitDef(fruitId)
    if not fr then return cb({ ok = false, reason = 'bad_fruit' }) end
    local loc = fr.locations[tonumber(index)]
    if not loc then return cb({ ok = false, reason = 'bad_loc' }) end
    if not Security.isNear(src, loc, (fr.zoneRadius or 1.5) + 1.5) then return cb({ ok = false, reason = 'too_far' }) end

    respawn[fruitId] = respawn[fruitId] or {}
    local ready = respawn[fruitId][index] or 0
    if os.time() < ready then return cb({ ok = false, reason = 'not_ready', wait = ready - os.time() }) end

    local token = ('%d-%d'):format(src, GetGameTimer())
    pendingPick[src] = { token = token, fruitId = fruitId, index = tonumber(index), at = GetGameTimer() }
    cb({ ok = true, token = token, minigame = fr.minigame, harvestType = fr.harvestType, anim = fr.anim })
end)

-- ── Rinkimo pabaiga ───────────────────────────────────────────────
QBCore.Functions.CreateCallback('mrp_jobs:server:fruit:finishPick', function(src, cb, token, success)
    local p = pendingPick[src]
    pendingPick[src] = nil
    if not p or p.token ~= token then return cb({ ok = false, reason = 'bad_token' }) end
    if GetGameTimer() - p.at > 60000 then return cb({ ok = false, reason = 'expired' }) end
    local s = JobManager.getBySource(src)
    if not s or s.jobType ~= 'fruit' then return cb({ ok = false, reason = 'no_job' }) end
    local fr = fruitDef(p.fruitId)
    if not fr then return cb({ ok = false, reason = 'bad_fruit' }) end
    local loc = fr.locations[p.index]
    if not loc or not Security.isNear(src, loc, (fr.zoneRadius or 1.5) + 2.0) then return cb({ ok = false, reason = 'too_far' }) end
    if success ~= true then return cb({ ok = false, reason = 'failed' }) end

    local yield = Utils.randInt(fr.minYield or 1, fr.maxYield or 2)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return cb({ ok = false, reason = 'no_player' }) end
    if not Player.Functions.AddItem(fr.item, yield, false, nil, 'fruit-pick') then
        return cb({ ok = false, reason = 'inv_full' })
    end

    respawn[p.fruitId][p.index] = os.time() + (fr.respawnTime or 300)
    cb({ ok = true, item = fr.item, amount = yield, respawn = fr.respawnTime or 300 })
end)

-- ── Pakavimas į dėžę ──────────────────────────────────────────────
QBCore.Functions.CreateCallback('mrp_jobs:server:fruit:pack', function(src, cb, fruitId)
    if not Security.rateLimit(src, 'fruit_pack', 900) then return cb({ ok = false, reason = 'rate' }) end
    local s = JobManager.getBySource(src)
    if not s or s.jobType ~= 'fruit' then return cb({ ok = false, reason = 'no_job' }) end
    local fr = fruitDef(fruitId)
    if not fr then return cb({ ok = false, reason = 'bad_fruit' }) end
    if not Security.isNear(src, FL.delivery.coords, (FL.delivery.radius or 5.0) + 2.0) then return cb({ ok = false, reason = 'too_far' }) end

    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return cb({ ok = false, reason = 'no_player' }) end
    local need = fr.perBox or 12
    local have = Player.Functions.GetItemByName(fr.item)
    if not have or have.amount < need then return cb({ ok = false, reason = 'not_enough', need = need }) end
    if not Player.Functions.RemoveItem(fr.item, need, nil, 'fruit-pack') then return cb({ ok = false, reason = 'remove_fail' }) end
    if not Player.Functions.AddItem(fr.boxItem, 1, false, nil, 'fruit-pack') then
        Player.Functions.AddItem(fr.item, need, false, nil, 'fruit-pack-refund')
        return cb({ ok = false, reason = 'inv_full' })
    end
    cb({ ok = true, crate = fr.boxItem })
end)

-- ── Pristatymas (atlygis) ─────────────────────────────────────────
QBCore.Functions.CreateCallback('mrp_jobs:server:fruit:deliver', function(src, cb)
    if not Security.rateLimit(src, 'fruit_deliver', 1200) then return cb({ ok = false, reason = 'rate' }) end
    local s = JobManager.getBySource(src)
    if not s or s.jobType ~= 'fruit' then return cb({ ok = false, reason = 'no_job' }) end
    if not Security.isNear(src, FL.delivery.coords, FL.delivery.radius or 5.0) then return cb({ ok = false, reason = 'too_far' }) end

    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return cb({ ok = false, reason = 'no_player' }) end

    local total, crates = 0, 0
    for crateItem, price in pairs(RF.cratePrice) do
        local have = Player.Functions.GetItemByName(crateItem)
        if have and have.amount > 0 then
            local n = have.amount
            if Player.Functions.RemoveItem(crateItem, n, nil, 'fruit-deliver') then
                total = total + price * n
                crates = crates + n
            end
        end
    end
    if crates <= 0 then return cb({ ok = false, reason = 'no_crates' }) end

    Rewards.pay(src, total, RF.account or 'cash', 'fruit-delivery', { crates = crates })
    cb({ ok = true, pay = total, crates = crates })
end)
