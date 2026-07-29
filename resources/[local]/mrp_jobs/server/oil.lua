--[[
  mrp_jobs — NAFTOS darbas (serveris, autoritetingas).
  Statinės = serverio vienetai (ne inventoriaus itemas) — todėl neįmanoma
  dubliuoti. Atlygis mokamas TIK pristačius į elektrinę.

  Būsena session.data:
    carrying (bool) — ar neša statinę rankose
    loaded (int)    — kiek pakrauta į transportą (<= maxLoad)
    delivered (int) — kiek iš viso pristatyta
]]

local QBCore = exports['qb-core']:GetCoreObject()

local OIL = Config.Locations.oil
local R = Config.Rewards.oil

-- Laukiantys išgavimo tokenai: [src] = { token, pumpId, at }
local pending = {}

local function pumpById(id)
    for _, p in ipairs(OIL.pumps) do
        if p.id == id then return p end
    end
    return nil
end

-- ── Handleris ─────────────────────────────────────────────────────
JobManager.registerHandler('oil', {
    onStart = function(session)
        session.data.carrying = false
        session.data.loaded = 0
        session.data.delivered = 0
        session.data.maxLoad = OIL.vehicleSpawn.maxLoad or 4
    end,
    onStop = function(session)
        pending[session.source] = nil
    end,
    buildClientState = function(session)
        return { oil = {
            carrying = session.data.carrying == true,
            loaded = session.data.loaded or 0,
            maxLoad = session.data.maxLoad or 4,
            delivered = session.data.delivered or 0,
        } }
    end,
})

-- ── Išgavimo pradžia (išduoda tokeną minigame'ui) ─────────────────
QBCore.Functions.CreateCallback('mrp_jobs:server:oil:startExtract', function(src, cb, pumpId)
    if not Security.rateLimit(src, 'oil_extract', 900) then return cb({ ok = false, reason = 'rate' }) end
    local s = JobManager.getBySource(src)
    if not s or s.jobType ~= 'oil' then return cb({ ok = false, reason = 'no_job' }) end
    if s.data.carrying then return cb({ ok = false, reason = 'carrying' }) end
    if (s.data.loaded or 0) >= (s.data.maxLoad or 4) then return cb({ ok = false, reason = 'full_load' }) end

    local pump = pumpById(pumpId)
    if not pump then return cb({ ok = false, reason = 'bad_pump' }) end
    if not Security.isNear(src, pump.coords, 3.5) then return cb({ ok = false, reason = 'too_far' }) end

    local token = ('%d-%d'):format(src, GetGameTimer())
    pending[src] = { token = token, pumpId = pumpId, at = GetGameTimer() }
    cb({ ok = true, token = token })
end)

-- ── Išgavimo pabaiga (patikrina minigame rezultatą vieną kartą) ───
QBCore.Functions.CreateCallback('mrp_jobs:server:oil:finishExtract', function(src, cb, token, success)
    local p = pending[src]
    pending[src] = nil
    if not p or p.token ~= token then return cb({ ok = false, reason = 'bad_token' }) end
    if GetGameTimer() - p.at > 60000 then return cb({ ok = false, reason = 'expired' }) end

    local s = JobManager.getBySource(src)
    if not s or s.jobType ~= 'oil' then return cb({ ok = false, reason = 'no_job' }) end
    if s.data.carrying then return cb({ ok = false, reason = 'carrying' }) end

    local pump = pumpById(p.pumpId)
    if not pump or not Security.isNear(src, pump.coords, 4.0) then return cb({ ok = false, reason = 'too_far' }) end

    if success ~= true then return cb({ ok = false, reason = 'failed' }) end
    s.data.carrying = true
    JobManager.pushState(s)
    cb({ ok = true, barrelProp = OIL.barrelProp })
end)

-- ── Statinės pakrovimas į transportą ──────────────────────────────
QBCore.Functions.CreateCallback('mrp_jobs:server:oil:loadBarrel', function(src, cb)
    if not Security.rateLimit(src, 'oil_load', 700) then return cb({ ok = false, reason = 'rate' }) end
    local s = JobManager.getBySource(src)
    if not s or s.jobType ~= 'oil' then return cb({ ok = false, reason = 'no_job' }) end
    if not s.data.carrying then return cb({ ok = false, reason = 'no_barrel' }) end
    local maxLoad = s.data.maxLoad or 4
    if (s.data.loaded or 0) >= maxLoad then return cb({ ok = false, reason = 'full_load' }) end

    s.data.carrying = false
    s.data.loaded = (s.data.loaded or 0) + 1
    JobManager.pushState(s)
    cb({ ok = true, slot = s.data.loaded, loaded = s.data.loaded, maxLoad = maxLoad })
end)

-- ── Pristatymas į elektrinę (atlygis) ─────────────────────────────
QBCore.Functions.CreateCallback('mrp_jobs:server:oil:deliver', function(src, cb, engineHealth)
    if not Security.rateLimit(src, 'oil_deliver', 1500) then return cb({ ok = false, reason = 'rate' }) end
    local s = JobManager.getBySource(src)
    if not s or s.jobType ~= 'oil' then return cb({ ok = false, reason = 'no_job' }) end
    local loaded = s.data.loaded or 0
    if loaded <= 0 then return cb({ ok = false, reason = 'empty' }) end

    if not Security.isNear(src, OIL.delivery.coords, OIL.delivery.radius or 8.0) then
        return cb({ ok = false, reason = 'too_far' })
    end

    -- Atlygio skaičiavimas (serveris).
    local maxLoad = s.data.maxLoad or 4
    local pay = R.perBarrel * loaded
    if loaded >= maxLoad then pay = pay + (R.fullLoadBonus or 0) end
    pay = pay + (R.safeDeliveryBonus or 0)

    -- Sugadinimo bauda pagal kliento praneštą variklio būklę (clamp; tik mažina).
    local hp = Utils.clamp(tonumber(engineHealth) or 1000, 0, 1000)
    local penalty = (R.damagePenaltyMax or 0) * (1 - hp / 1000)
    pay = math.floor(pay * (1 - penalty))
    if pay < 1 then pay = 1 end

    s.data.loaded = 0
    s.data.delivered = (s.data.delivered or 0) + loaded
    Rewards.pay(src, pay, R.account or 'bank', 'oil-delivery', { barrels = loaded })

    local Player = QBCore.Functions.GetPlayer(src)
    local residueItem = R.residueItem or 'oil_residue'
    local residueEach = math.max(0, tonumber(R.residuePerBarrel) or 1)
    local residueGive = residueEach * loaded
    local residueGot = 0
    if Player and residueGive > 0 then
        if Player.Functions.AddItem(residueItem, residueGive, false) then
            residueGot = residueGive
            local shared = QBCore.Shared.Items[residueItem]
            if shared then
                TriggerClientEvent('qb-inventory:client:ItemBox', src, shared, 'add', residueGive)
            end
        end
    end

    JobManager.pushState(s)
    cb({ ok = true, pay = pay, barrels = loaded, residue = residueGot, residueItem = residueItem })
end)

-- ── Sintetinė guma iš naftos likučių (be anglies) ─────────────────
QBCore.Functions.CreateCallback('mrp_jobs:server:oil:processRubber', function(src, cb)
    if not Security.rateLimit(src, 'oil_rubber', 1200) then return cb({ ok = false, reason = 'rate' }) end

    local process = OIL.rubberProcess
    if not process or not process.coords then
        return cb({ ok = false, reason = 'no_station' })
    end
    if not Security.isNear(src, process.coords, (process.radius or 2.4) + 2.0) then
        return cb({ ok = false, reason = 'too_far' })
    end

    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return cb({ ok = false, reason = 'no_player' }) end

    local residueItem = R.residueItem or 'oil_residue'
    local need = math.max(1, tonumber(R.rubberInput) or 1)
    local outPer = math.max(1, tonumber(R.rubberOutput) or 1)
    local outItem = R.rubberOutputItem or 'rubber'

    local haveData = Player.Functions.GetItemByName(residueItem)
    local have = haveData and (haveData.amount or 0) or 0
    if have < need then
        return cb({ ok = false, reason = 'no_residue', need = need })
    end

    local crafts = math.floor(have / need)
    local take = crafts * need
    local give = crafts * outPer
    if take < 1 or give < 1 then
        return cb({ ok = false, reason = 'no_residue', need = need })
    end

    if not Player.Functions.RemoveItem(residueItem, take, false) then
        return cb({ ok = false, reason = 'remove_fail' })
    end
    if not Player.Functions.AddItem(outItem, give, false) then
        Player.Functions.AddItem(residueItem, take, false)
        return cb({ ok = false, reason = 'inv_full' })
    end

    local sharedOut = QBCore.Shared.Items[outItem]
    if sharedOut then
        TriggerClientEvent('qb-inventory:client:ItemBox', src, sharedOut, 'add', give)
    end
    cb({ ok = true, used = take, produced = give, item = outItem })
end)
