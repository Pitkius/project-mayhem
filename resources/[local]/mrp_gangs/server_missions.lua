local QBCore = exports['qb-core']:GetCoreObject()

local playerCooldown = {}
local turfCooldown = {}
local progressBucket = {}
local activeMissions = {}
local pendingHackMission = {}

local function playerInTurfServer(src, turfId)
    return Config.PlayerInTurfCell and Config.PlayerInTurfCell(src, turfId) or false
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

local function pickMissionSite(missionType, near, sitePool)
    local poolKey = sitePool or missionType
    local pool = Config.MissionSites and Config.MissionSites[poolKey]
    if not pool or #pool == 0 then return nil end
    local best, bestDist
    for _, site in ipairs(pool) do
        local c = site.coords
        local d = #(vector3(c.x, c.y, c.z) - near)
        if not bestDist or d < bestDist then
            best = site
            bestDist = d
        end
    end
    return best
end

local function buildPatrolCheckpoints(turfId, count)
    local turfCfg = Config.GetTurfCell(turfId)
    if not turfCfg then return {} end
    local center = turfCfg.center
    count = math.max(2, tonumber(count) or 3)
    local w = (turfCfg.maxX - turfCfg.minX) * 0.35
    local h = (turfCfg.maxY - turfCfg.minY) * 0.35
    local points = {}
    for i = 1, count do
        local angle = ((i - 1) / count) * (2 * math.pi)
        points[#points + 1] = vector3(
            center.x + math.cos(angle) * w,
            center.y + math.sin(angle) * h,
            center.z
        )
    end
    return points
end

local function buildRaceCheckpoints(turfId, pickup, count)
    local turfCfg = Config.GetTurfCell(turfId)
    count = math.max(2, tonumber(count) or 3)
    local points = { pickup }
    if turfCfg then
        local center = turfCfg.center
        local w = (turfCfg.maxX - turfCfg.minX) * 0.4
        for i = 2, count do
            local angle = ((i - 1) / count) * (2 * math.pi)
            points[#points + 1] = vector3(
                center.x + math.cos(angle) * w,
                center.y + math.sin(angle) * w * 0.6,
                center.z
            )
        end
    end
    return points
end

local function resolvePickupCoords(missionType, turfId, mCfg)
    local turfCfg = Config.GetTurfCell(turfId)
    if not turfCfg then return nil end
    local center = turfCfg.center
    local archetype = mCfg and mCfg.archetype or 'delivery'

    if archetype == 'patrol' or archetype == 'hold' or archetype == 'graffiti' then
        return center, center, nil
    end

    local site = pickMissionSite(missionType, center, mCfg and mCfg.sitePool)
    if site and site.coords then
        local c = site.coords
        return vector3(c.x, c.y, c.z), center, site
    end
    if mCfg and mCfg.pickupOffset then
        local off = mCfg.pickupOffset
        return vector3(center.x + off.x, center.y + off.y, center.z + (off.z or 0.0)), center, nil
    end
    return center, center, nil
end

local function playerNearCoords(src, coords, maxDist)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end
    local p = GetEntityCoords(ped)
    local limit = maxDist or Config.MissionInteractDistance or 4.5
    local flat = #(vector2(p.x, p.y) - vector2(coords.x, coords.y))
    if flat <= limit then return true end
    return #(p - coords) <= limit
end

local function missionAllowed(gangType, missionKey)
    local m = Config.MissionTypes and Config.MissionTypes[missionKey]
    if not m then return false end
    if not m.gangs then return true end
    return m.gangs[tostring(gangType or '')] == true
end

local function getArchetype(mCfg)
    return mCfg and mCfg.archetype or 'delivery'
end

local function canCaptureTurf(gang, turf)
    local owner = tonumber(turf.owner_gang_id)
    if not owner or owner <= 0 then return true end
    return owner ~= tonumber(gang.gang_id)
end

local function turfCooldownKey(gangId, turfId)
    return ('%s:%s'):format(tonumber(gangId) or 0, tostring(turfId))
end

local function checkRateLimit(src)
    local now = os.time()
    local cap = Config.TurfCapture or {}
    local last = playerCooldown[src] or 0
    if now - last < (cap.playerCooldownSec or 90) then
        return false, 'Palauk prieš kitą misiją.'
    end
    local bucket = progressBucket[src]
    if bucket and bucket.windowStart and (now - bucket.windowStart) < 60 then
        if (bucket.amount or 0) >= (cap.maxProgressPerMinute or 45) then
            return false, 'Per daug turf progreso per minutę.'
        end
    else
        progressBucket[src] = { windowStart = now, amount = 0 }
    end
    return true
end

local function addRateProgress(src, amount)
    local now = os.time()
    local bucket = progressBucket[src]
    if not bucket or (now - (bucket.windowStart or 0)) >= 60 then
        progressBucket[src] = { windowStart = now, amount = 0 }
        bucket = progressBucket[src]
    end
    bucket.amount = (bucket.amount or 0) + (tonumber(amount) or 0)
    playerCooldown[src] = now
end

local function rollRandomEvent()
    local pool = Config.MissionRandomEvents or {}
    local roll = math.random(1, 100)
    local cumulative = 0
    for _, ev in ipairs(pool) do
        cumulative = cumulative + (tonumber(ev.chance) or 0)
        if roll <= cumulative then
            return ev
        end
    end
    return nil
end

local function rollBonusItems(Player, mCfg)
    if not Player then return {} end
    local granted = {}
    local pools = { 'common', 'uncommon', 'rare' }
    if mCfg and mCfg.bonusItemPool then
        pools = { mCfg.bonusItemPool, 'common' }
    end
    for _, poolName in ipairs(pools) do
        local pool = Config.MissionBonusItems and Config.MissionBonusItems[poolName]
        if pool then
            for _, entry in ipairs(pool) do
                if math.random(1, 100) <= (tonumber(entry.chance) or 0) then
                    local amount = math.random(tonumber(entry.min) or 1, tonumber(entry.max) or 1)
                    local item = entry.item
                    if item and QBCore.Shared.Items[item] then
                        Player.Functions.AddItem(item, amount)
                        TriggerClientEvent('inventory:client:ItemBox', Player.PlayerData.source, QBCore.Shared.Items[item], 'add', amount)
                        granted[#granted + 1] = { item = item, amount = amount }
                    end
                end
            end
        end
    end
    return granted
end

function AddTurfInfluence(src, turfId, taskType, opts)
    opts = opts or {}
    local gang = getPlayerGang(src)
    if not gang then return false, 'Nepriklausai gaujai.' end
    if not playerInTurfServer(src, turfId) and not opts.skipTurfCheck then
        return false, 'Turi būti turf zonoje.'
    end

    local reward = tonumber(opts.amount) or tonumber(opts.progress) or (Config.TurfInfluence and Config.TurfInfluence[taskType]) or 0
    if reward <= 0 then return false, 'Nežinoma užduotis.' end

    local okRate, rateMsg = checkRateLimit(src)
    if not okRate and not opts.skipCooldown then return false, rateMsg end

    local turf = MySQL.single.await('SELECT turf_id, owner_gang_id, owner_name, progress, influence, heat FROM fivempro_gang_turfs WHERE turf_id = ? LIMIT 1', { tostring(turfId) })
    if not turf then return false, 'Turf nerastas.' end

    if not canCaptureTurf(gang, turf) and not opts.allowOwnTurf then
        return false, 'Šis turf jau priklauso tavo gaujai.'
    end

    local cap = Config.TurfCapture or {}
    local tKey = turfCooldownKey(gang.gang_id, turfId)
    local now = os.time()
    if not opts.skipCooldown and turfCooldown[tKey] and turfCooldown[tKey] > now then
        return false, 'Šis turf neseniai bandytas — palauk cooldown.'
    end

    local influence = (tonumber(turf.influence) or tonumber(turf.progress) or 0) + reward
    local ownerGangId = turf.owner_gang_id
    local ownerName = turf.owner_name
    local threshold = tonumber(cap.claimThreshold) or tonumber(Config.TurfClaimThreshold) or 100
    local claimed = false

    if influence >= threshold then
        ownerGangId = gang.gang_id
        ownerName = gang.name
        influence = threshold
        claimed = true
        turfCooldown[tKey] = now + (cap.turfCooldownSec or 300)
    end

    MySQL.update.await([[
        UPDATE fivempro_gang_turfs
        SET influence = ?, progress = ?, owner_gang_id = ?, owner_name = ?
        WHERE turf_id = ?
    ]], { influence, influence, ownerGangId, ownerName, tostring(turfId) })

    MySQL.update.await('UPDATE fivempro_gangs SET reputation = reputation + ? WHERE id = ?', {
        math.max(1, math.floor(reward / 2)),
        gang.gang_id,
    })

    if not opts.skipCooldown then addRateProgress(src, reward) end

    local msg = claimed and ('Turf %s kontroliuojamas!'):format(tostring(turfId)) or ('Turf įtaka +%s (%s/%s)'):format(reward, influence, threshold)
    if not opts.quiet then
        TriggerClientEvent('QBCore:Notify', src, msg, claimed and 'success' or 'primary')
    end
    TriggerClientEvent('mrp_gangs:client:turfInfluenceUpdated', src, turfId, influence, threshold, claimed)
    return true, msg, { influence = influence, claimed = claimed, reward = reward }
end

function ApplyGangTurfTask(src, turfId, taskType, opts)
    opts = opts or {}
    opts.amount = opts.amount or opts.progress
    return AddTurfInfluence(src, turfId, taskType, opts)
end

function CompleteGangMission(src, missionType, opts)
    opts = opts or {}
    local gang = getPlayerGang(src)
    if not gang then return false, 'Nepriklausai gaujai.' end
    local mCfg = Config.MissionTypes and Config.MissionTypes[missionType]
    if not mCfg then return false, 'Nežinoma misija.' end

    local okRate, rateMsg = checkRateLimit(src)
    if not okRate and not opts.skipCooldown then return false, rateMsg end

    local rep = tonumber(mCfg.reputationReward) or 8
    local money = tonumber(mCfg.moneyReward) or 0
    local inf = tonumber(mCfg.influenceReward) or 0
    if opts.bonusInfluence then
        inf = inf + tonumber(opts.bonusInfluence) or 0
    end

    MySQL.update.await('UPDATE fivempro_gangs SET reputation = reputation + ? WHERE id = ?', {
        rep, gang.gang_id,
    })

    local Player = QBCore.Functions.GetPlayer(src)
    if Player and money > 0 then
        Player.Functions.AddMoney('cash', money, 'gang-mission')
    end

    local influenceResult = nil
    if inf > 0 and opts.turfId then
        local okInf = AddTurfInfluence(src, opts.turfId, missionType, {
            amount = inf,
            skipTurfCheck = opts.skipTurfCheck == true,
            skipCooldown = true,
            allowOwnTurf = true,
        })
        if okInf then influenceResult = inf end
    end

    local bonusItems = rollBonusItems(Player, mCfg)

    if not opts.skipCooldown then addRateProgress(src, rep + (influenceResult or 0)) end

    local infText = influenceResult and (' · Įtaka +%s'):format(influenceResult) or ''
    TriggerClientEvent('QBCore:Notify', src, ('Misija baigta · Rep +%s%s%s'):format(
        rep,
        money > 0 and (' · $' .. money) or '',
        infText
    ), 'success')

    TriggerClientEvent('mrp_gangs:client:refreshTablet', src)
    TriggerClientEvent('mrp_gangs:client:missionComplete', src, {
        reputation = rep,
        money = money,
        influence = influenceResult or 0,
        missionType = missionType,
        bonusItems = bonusItems,
    })
    return true, 'ok'
end

local function finalizeMission(src, act, opts)
    opts = opts or {}
    local mCfg = Config.MissionTypes[act.missionType]
    local ok, reason = CompleteGangMission(src, act.missionType, {
        turfId = act.turfId,
        skipTurfCheck = mCfg and mCfg.dropInTurf ~= true or opts.skipTurfCheck,
        bonusInfluence = act.bonusInfluence,
    })
    activeMissions[src] = nil
    pendingHackMission[src] = nil
    return ok, reason
end

RegisterNetEvent('mrp_gangs:internal:addInfluence', function(src, turfId, taskType, amount, skipTurfCheck, skipCooldown)
    AddTurfInfluence(src, turfId, taskType, {
        amount = amount,
        skipTurfCheck = skipTurfCheck == true,
        skipCooldown = skipCooldown == true,
    })
end)

RegisterNetEvent('mrp_gangs:server:completeTask', function(turfId, taskType)
    AddTurfInfluence(source, turfId, taskType, {
        amount = Config.TurfInfluence and Config.TurfInfluence.graffiti or 6,
        allowOwnTurf = true,
    })
end)

QBCore.Functions.CreateCallback('mrp_gangs:server:startMission', function(src, cb, turfId, missionType)
    local gang = getPlayerGang(src)
    if not gang then return cb({ ok = false, reason = 'Nepriklausai gaujai.' }) end
    missionType = tostring(missionType or '')
    local mCfg = Config.MissionTypes and Config.MissionTypes[missionType]
    if not mCfg then return cb({ ok = false, reason = 'Nežinoma misija.' }) end
    if not missionAllowed(gang.gang_type, missionType) then
        return cb({ ok = false, reason = 'Ši misija neatitinka tavo gaujos tipo.' })
    end

    turfId = tostring(turfId or '')
    if turfId == '' or not Config.GetTurfCell(turfId) then
        local ped = GetPlayerPed(src)
        if ped and ped ~= 0 then
            local p = GetEntityCoords(ped)
            turfId = Config.FindTurfAt(p.x, p.y) or ''
        end
    end
    if turfId == '' or not Config.GetTurfCell(turfId) then
        return cb({ ok = false, reason = 'Pasirink turf arba stovėk zonoje.' })
    end

    local okRate, rateMsg = checkRateLimit(src)
    if not okRate then return cb({ ok = false, reason = rateMsg }) end

    if activeMissions[src] then
        return cb({ ok = false, reason = 'Jau vykdoma misija.' })
    end

    local token = ('%s-%s-%s'):format(src, turfId, os.time())
    local pickup, center, site = resolvePickupCoords(missionType, turfId, mCfg)
    if not pickup or not center then
        return cb({ ok = false, reason = 'Turf nerastas.' })
    end

    local archetype = getArchetype(mCfg)
    local checkpoints = nil
    if archetype == 'patrol' then
        checkpoints = buildPatrolCheckpoints(turfId, mCfg.checkpointCount or 4)
    elseif archetype == 'racing' then
        checkpoints = buildRaceCheckpoints(turfId, pickup, mCfg.checkpointCount or 3)
    end

    local randomEvent = rollRandomEvent()
    local bonusInfluence = 0
    local extraDuration = 0
    if randomEvent then
        if randomEvent.bonusInfluence then bonusInfluence = tonumber(randomEvent.bonusInfluence) or 0 end
        if randomEvent.extraMs then extraDuration = tonumber(randomEvent.extraMs) or 0 end
        if randomEvent.relocate and site and site.coords then
            local alt = pickMissionSite(missionType, center, mCfg.sitePool)
            if alt and alt.coords then
                local c = alt.coords
                pickup = vector3(c.x, c.y, c.z)
                site = alt
            end
        end
        if randomEvent.dispatch then
            local ped = GetPlayerPed(src)
            if ped and ped ~= 0 and GetResourceState('mrp_dispatch') == 'started' then
                local c = GetEntityCoords(ped)
                pcall(function()
                    exports['mrp_dispatch']:CreateCall({
                        callType = 'gang_activity',
                        callTypeLabel = 'Gaujų veikla rajone',
                        x = c.x, y = c.y, z = c.z,
                        priority = 1,
                    })
                end)
            end
        end
    end

    activeMissions[src] = {
        token = token,
        turfId = turfId,
        missionType = missionType,
        archetype = archetype,
        pickup = pickup,
        drop = center,
        step = 1,
        checkpointIdx = 0,
        checkpoints = checkpoints,
        holdStarted = nil,
        startedAt = os.time(),
        bonusInfluence = bonusInfluence,
        randomEvent = randomEvent and randomEvent.id or nil,
    }

    local cpOut = {}
    if checkpoints then
        for i, pt in ipairs(checkpoints) do
            cpOut[i] = { x = pt.x, y = pt.y, z = pt.z }
        end
    end

    cb({
        ok = true,
        token = token,
        missionType = missionType,
        label = mCfg.label,
        archetype = archetype,
        turfId = turfId,
        siteLabel = site and site.label or nil,
        siteVehicle = site and site.vehicle or nil,
        heading = site and site.coords and site.coords.w or 0.0,
        pickup = { x = pickup.x, y = pickup.y, z = pickup.z },
        drop = { x = center.x, y = center.y, z = center.z },
        durationMs = (mCfg.durationMs or 7000) + extraDuration,
        requireVehicle = mCfg.requireVehicle == true,
        spawnVehicle = mCfg.spawnVehicle or (site and site.vehicle) or nil,
        dropInTurf = mCfg.dropInTurf ~= false,
        pickupLabel = mCfg.pickupLabel,
        dropLabel = mCfg.dropLabel,
        checkpointCount = mCfg.checkpointCount or 3,
        checkpoints = cpOut,
        holdSeconds = mCfg.holdSeconds or 60,
        holdRadius = mCfg.holdRadius or 80,
        visualKey = mCfg.visual,
        randomEvent = randomEvent,
    })
end)

QBCore.Functions.CreateCallback('mrp_gangs:server:advanceMissionCheckpoint', function(src, cb, token, index)
    local act = activeMissions[src]
    if not act or act.token ~= tostring(token or '') then
        return cb({ ok = false, reason = 'Misija neaktyvi.' })
    end
    local archetype = act.archetype
    if archetype ~= 'patrol' and archetype ~= 'racing' then
        return cb({ ok = false, reason = 'Netinkamas tipas.' })
    end
    index = tonumber(index) or 0
    local cps = act.checkpoints or {}
    if index < 1 or index > #cps then
        return cb({ ok = false, reason = 'Netinkamas checkpoint.' })
    end
    if not playerNearCoords(src, cps[index], Config.MissionCheckpointDistance or 12.0) then
        return cb({ ok = false, reason = 'Per toli nuo checkpoint.' })
    end
    if archetype == 'racing' then
        local ped = GetPlayerPed(src)
        if not ped or ped == 0 or not IsPedInAnyVehicle(ped, false) then
            return cb({ ok = false, reason = 'Reikia transporto.' })
        end
    end
    if not playerInTurfServer(src, act.turfId) and archetype == 'patrol' then
        return cb({ ok = false, reason = 'Turi būti turf zonoje.' })
    end

    act.checkpointIdx = index
    if index >= #cps then
        local ok, reason = finalizeMission(src, act)
        return cb({ ok = ok, reason = reason, done = true })
    end
    cb({ ok = true, nextIndex = index + 1 })
end)

QBCore.Functions.CreateCallback('mrp_gangs:server:completeHoldMission', function(src, cb, token)
    local act = activeMissions[src]
    if not act or act.token ~= tostring(token or '') then
        return cb({ ok = false, reason = 'Misija neaktyvi.' })
    end
    if act.archetype ~= 'hold' then
        return cb({ ok = false, reason = 'Netinkamas tipas.' })
    end
    if not playerInTurfServer(src, act.turfId) then
        return cb({ ok = false, reason = 'Turi būti turf zonoje.' })
    end
    local mCfg = Config.MissionTypes[act.missionType]
    local holdSec = tonumber(mCfg and mCfg.holdSeconds) or 60
    if not act.holdStarted or (os.time() - act.holdStarted) < holdSec then
        return cb({ ok = false, reason = 'Dar nebaigtas laikymas.' })
    end
    local ok, reason = finalizeMission(src, act)
    cb({ ok = ok, reason = reason, done = true })
end)

QBCore.Functions.CreateCallback('mrp_gangs:server:finishMissionStep', function(src, cb, token, step)
    local act = activeMissions[src]
    if not act or act.token ~= tostring(token or '') then
        return cb({ ok = false, reason = 'Misija neaktyvi.' })
    end
    step = tonumber(step) or 1
    local mCfg = Config.MissionTypes[act.missionType]
    if not mCfg then return cb({ ok = false }) end
    local archetype = getArchetype(mCfg)

    if archetype == 'graffiti' and step == 1 then
        if not playerInTurfServer(src, act.turfId) then
            return cb({ ok = false, reason = 'Turi būti turf zonoje.' })
        end
        local ok, reason = finalizeMission(src, act)
        return cb({ ok = ok, reason = reason, done = true })
    end

    if archetype == 'extortion' and step == 1 then
        if not act.pickup or not playerNearCoords(src, act.pickup, Config.MissionInteractDistance) then
            return cb({ ok = false, reason = 'Per toli nuo taško.' })
        end
        if mCfg.dropInTurf == false then
            local ok, reason = finalizeMission(src, act)
            return cb({ ok = ok, reason = reason, done = true })
        end
        act.step = 2
        return cb({ ok = true, nextStep = 2, phase = 'drop' })
    end

    if step == 1 then
        if not act.pickup or not playerNearCoords(src, act.pickup, Config.MissionInteractDistance) then
            return cb({ ok = false, reason = 'Per toli nuo paėmimo taško.' })
        end
        if mCfg.requireVehicle then
            local ped = GetPlayerPed(src)
            if not ped or ped == 0 or not IsPedInAnyVehicle(ped, false) then
                return cb({ ok = false, reason = 'Reikia transporto.' })
            end
        end
        if mCfg.spawnVehicle then
            act.step = 2
            return cb({ ok = true, nextStep = 2, phase = 'trunk' })
        end
        act.step = 2
        return cb({ ok = true, nextStep = 2, phase = 'drop' })
    end

    if step == 2 then
        if mCfg.spawnVehicle then
            if not act.pickup or not playerNearCoords(src, act.pickup, 150.0) then
                return cb({ ok = false, reason = 'Per toli nuo furgono.' })
            end
            act.step = 3
            return cb({ ok = true, nextStep = 3, phase = 'drop' })
        end
        if mCfg.dropInTurf and not playerInTurfServer(src, act.turfId) then
            return cb({ ok = false, reason = 'Pristatymas turi būti target turf zonoje.' })
        end
        if mCfg.dropInTurf and act.drop and not playerNearCoords(src, act.drop, Config.MissionDropDistance or 15.0) then
            return cb({ ok = false, reason = 'Eik arčiau pristatymo taško turf zonoje.' })
        end
        if mCfg.requireVehicle then
            local ped = GetPlayerPed(src)
            if not ped or ped == 0 or not IsPedInAnyVehicle(ped, false) then
                return cb({ ok = false, reason = 'Reikia transporto.' })
            end
        end
        local ok, reason = finalizeMission(src, act)
        return cb({ ok = ok, reason = reason, done = true })
    end

    if step == 3 then
        if not mCfg.spawnVehicle then
            return cb({ ok = false, reason = 'Netinkamas žingsnis.' })
        end
        if mCfg.dropInTurf and not playerInTurfServer(src, act.turfId) then
            return cb({ ok = false, reason = 'Pristatymas turi būti target turf zonoje.' })
        end
        if mCfg.dropInTurf and act.drop and not playerNearCoords(src, act.drop, Config.MissionDropDistance or 15.0) then
            return cb({ ok = false, reason = 'Eik arčiau pristatymo taško turf zonoje.' })
        end
        local ok, reason = finalizeMission(src, act)
        return cb({ ok = ok, reason = reason, done = true })
    end

    cb({ ok = false, reason = 'Netinkamas žingsnis.' })
end)

RegisterNetEvent('mrp_gangs:server:holdMissionStarted', function(token)
    local src = source
    local act = activeMissions[src]
    if not act or act.token ~= tostring(token or '') or act.archetype ~= 'hold' then return end
    if act.holdStarted then return end
    act.holdStarted = os.time()
end)

RegisterNetEvent('mrp_gangs:server:cancelMission', function()
    local src = source
    activeMissions[src] = nil
    pendingHackMission[src] = nil
end)

exports('ApplyGangTurfTask', ApplyGangTurfTask)
exports('AddTurfInfluence', AddTurfInfluence)
exports('CompleteGangMission', CompleteGangMission)

RegisterNetEvent('mrp_gangs:server:placeGraffiti', function(turfId)
    local src = source
    local gang = getPlayerGang(src)
    if not gang then return end
    local cfg = Config.Graffiti or {}
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    if Player.Functions.GetItemByName(cfg.item or 'spray_can') == nil then
        return TriggerClientEvent('QBCore:Notify', src, 'Reikia spray_can.', 'error')
    end
    if not playerInTurfServer(src, turfId) then
        return TriggerClientEvent('QBCore:Notify', src, 'Turi būti turf zonoje.', 'error')
    end
    Player.Functions.RemoveItem(cfg.item or 'spray_can', 1)
    local gain = tonumber(cfg.influenceGain) or (Config.TurfInfluence and Config.TurfInfluence.graffiti) or 6
    AddTurfInfluence(src, turfId, 'graffiti', { amount = gain, allowOwnTurf = true })
    if math.random(1, 100) <= (cfg.policeAlertChance or 18) then
        local ped = GetPlayerPed(src)
        local c = GetEntityCoords(ped)
        if GetResourceState('mrp_dispatch') == 'started' then
            pcall(function()
                exports['mrp_dispatch']:CreateCall({
                    callType = 'graffiti',
                    callTypeLabel = 'Graffiti / vandalizmas',
                    x = c.x, y = c.y, z = c.z,
                    priority = 1,
                })
            end)
        end
    end
end)

RegisterNetEvent('mrp_gangs:server:requestTabletRefresh', function()
    local src = source
    TriggerClientEvent('mrp_gangs:client:refreshTablet', src)
end)

RegisterNetEvent('mrp_gangs:server:adminResetTurf', function(turfId)
    local src = source
    if not HasGangAdminPermission(src) then return end
    turfId = tostring(turfId or '')
    MySQL.update.await('UPDATE fivempro_gang_turfs SET owner_gang_id = NULL, owner_name = NULL, progress = 0, influence = 0, heat = 0 WHERE turf_id = ?', { turfId })
    TriggerClientEvent('QBCore:Notify', src, ('Turf %s reset.'):format(turfId), 'success')
end)

RegisterNetEvent('mrp_gangs:server:adminSetTurfOwner', function(turfId, gangId)
    local src = source
    if not HasGangAdminPermission(src) then return end
    turfId = tostring(turfId or '')
    gangId = tonumber(gangId)
    local ownerName = nil
    local ownerId = nil
    if gangId and gangId > 0 then
        local g = MySQL.single.await('SELECT name FROM fivempro_gangs WHERE id = ? LIMIT 1', { gangId })
        if g then
            ownerName = g.name
            ownerId = gangId
        end
    end
    MySQL.update.await('UPDATE fivempro_gang_turfs SET owner_gang_id = ?, owner_name = ?, progress = 0, influence = 0 WHERE turf_id = ?', {
        ownerId, ownerName, turfId
    })
    TriggerClientEvent('QBCore:Notify', src, 'Turf savininkas pakeistas.', 'success')
end)

RegisterNetEvent('mrp_gangs:server:adminSetTurfProgress', function(turfId, progress)
    local src = source
    if not HasGangAdminPermission(src) then return end
    local val = math.max(0, math.min(100, tonumber(progress) or 0))
    MySQL.update.await('UPDATE fivempro_gang_turfs SET progress = ?, influence = ? WHERE turf_id = ?', { val, val, tostring(turfId) })
    TriggerClientEvent('QBCore:Notify', src, 'Turf progresas nustatytas.', 'success')
end)

exports('OnHackSuccess', function(src, tierId, coords)
    local gang = getPlayerGang(src)
    if not gang then return end
    local rep = (Config.HackGangRep and Config.HackGangRep[tostring(tierId or 'atm')]) or 2
    MySQL.update.await('UPDATE fivempro_gangs SET reputation = reputation + ? WHERE id = ?', { rep, gang.gang_id })
end)

exports('OnHackFailed', function() end)

--- Gaujos narių buvimas rajone → turf įtaka
CreateThread(function()
    local tickMs = 60000
    while true do
        Wait(tickMs)
        local gain = tonumber(Config.TurfInfluence and Config.TurfInfluence.presencePerMinute) or 1
        if gain <= 0 then goto continue end
        for _, playerId in ipairs(QBCore.Functions.GetPlayers()) do
            local src = tonumber(playerId)
            if src then
                local gang = getPlayerGang(src)
                if gang then
                    local ped = GetPlayerPed(src)
                    if ped and ped ~= 0 then
                        local p = GetEntityCoords(ped)
                        local turfId = Config.FindTurfAt and Config.FindTurfAt(p.x, p.y)
                        if turfId then
                            AddTurfInfluence(src, turfId, 'presence', {
                                amount = gain,
                                allowOwnTurf = true,
                                skipCooldown = true,
                                quiet = true,
                            })
                        end
                    end
                end
            end
        end
        ::continue::
    end
end)

AddEventHandler('playerDropped', function()
    local src = source
    activeMissions[src] = nil
    pendingHackMission[src] = nil
    playerCooldown[src] = nil
    progressBucket[src] = nil
end)
