local QBCore = exports['qb-core']:GetCoreObject()

local playerCooldown = {}
local turfCooldown = {}
local progressBucket = {}
local activeMissions = {}
local pendingHackMission = {}

local function playerInTurfServer(src, turfId)
    turfId = tostring(turfId or '')
    local cfg = Config.Turfs and Config.Turfs[turfId]
    if not cfg or not cfg.center then return false end
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end
    local p = GetEntityCoords(ped)
    local c = cfg.center
    local r = tonumber(cfg.radius) or 180.0
    return #(p - vector3(c.x, c.y, c.z)) <= r + 5.0
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

local function hasGangAdminPermission(src)
    for _, perm in ipairs(Config.AdminPermissions or {}) do
        if QBCore.Functions.HasPermission(src, perm) then return true end
    end
    return false
end

local function missionAllowed(gangType, missionKey)
    local m = Config.MissionTypes and Config.MissionTypes[missionKey]
    if not m then return false end
    if not m.gangs then return true end
    return m.gangs[tostring(gangType or '')] == true
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

function ApplyGangTurfTask(src, turfId, taskType, opts)
    opts = opts or {}
    local gang = getPlayerGang(src)
    if not gang then return false, 'Nepriklausai gaujai.' end
    if not playerInTurfServer(src, turfId) and not opts.skipTurfCheck then
        return false, 'Turi būti turf zonoje.'
    end

    local reward = tonumber(opts.progress) or (Config.TaskReputation and Config.TaskReputation[tostring(taskType or '')]) or 0
    if reward <= 0 then return false, 'Nežinoma užduotis.' end

    local okRate, rateMsg = checkRateLimit(src)
    if not okRate and not opts.skipCooldown then return false, rateMsg end

    local turf = MySQL.single.await('SELECT turf_id, owner_gang_id, owner_name, progress, heat FROM fivempro_gang_turfs WHERE turf_id = ? LIMIT 1', { tostring(turfId) })
    if not turf then return false, 'Turf nerastas.' end

    if not canCaptureTurf(gang, turf) then
        return false, 'Šis turf jau priklauso tavo gaujai — naudok /gangsell.'
    end

    local cap = Config.TurfCapture or {}
    local tKey = turfCooldownKey(gang.gang_id, turfId)
    local now = os.time()
    if not opts.skipCooldown and turfCooldown[tKey] and turfCooldown[tKey] > now then
        return false, 'Šis turf neseniai bandytas — palauk cooldown.'
    end

    local progress = (tonumber(turf.progress) or 0) + reward
    local ownerGangId = turf.owner_gang_id
    local ownerName = turf.owner_name
    local threshold = tonumber(cap.claimThreshold) or tonumber(Config.TurfClaimThreshold) or 100
    local claimed = false

    if progress >= threshold then
        ownerGangId = gang.gang_id
        ownerName = gang.name
        progress = 0
        claimed = true
        turfCooldown[tKey] = now + (cap.turfCooldownSec or 300)
    end

    local heatAdd = tonumber(opts.heatAdd) or 0
    local newHeat = math.min(100, (tonumber(turf.heat) or 0) + heatAdd)

    MySQL.update.await([[
        UPDATE fivempro_gang_turfs
        SET progress = ?, owner_gang_id = ?, owner_name = ?, heat = ?
        WHERE turf_id = ?
    ]], { progress, ownerGangId, ownerName, newHeat, tostring(turfId) })

    MySQL.update.await('UPDATE fivempro_gangs SET reputation = reputation + ?, heat = LEAST(100, heat + ?) WHERE id = ?', {
        math.max(1, math.floor(reward / 2)),
        math.floor(reward / 10),
        gang.gang_id,
    })

    if not opts.skipCooldown then addRateProgress(src, reward) end

    local msg = claimed and ('Turf %s užimtas!'):format(tostring(turfId)) or ('Turf progresas +%s (%s/%s)'):format(reward, progress, threshold)
    TriggerClientEvent('QBCore:Notify', src, msg, claimed and 'success' or 'primary')
    TriggerClientEvent('fivempro_gangs:client:turfProgressUpdated', src, turfId, progress, threshold, claimed)
    print(('[fivempro_gangs] turf task %s gang=%s turf=%s +%s claimed=%s'):format(taskType, gang.gang_id, turfId, reward, tostring(claimed)))
    return true, msg, { progress = progress, claimed = claimed }
end

RegisterNetEvent('fivempro_gangs:server:completeTask', function(turfId, taskType)
    ApplyGangTurfTask(source, turfId, taskType)
end)

QBCore.Functions.CreateCallback('fivempro_gangs:server:startMission', function(src, cb, turfId, missionType)
    local gang = getPlayerGang(src)
    if not gang then return cb({ ok = false, reason = 'Nepriklausai gaujai.' }) end
    missionType = tostring(missionType or '')
    local mCfg = Config.MissionTypes and Config.MissionTypes[missionType]
    if not mCfg then return cb({ ok = false, reason = 'Nežinoma misija.' }) end
    if not missionAllowed(gang.gang_type, missionType) then
        return cb({ ok = false, reason = 'Ši misija neatitinka tavo gaujos tipo.' })
    end

    turfId = tostring(turfId or '')
    if turfId == '' or not Config.Turfs[turfId] then
        return cb({ ok = false, reason = 'Netinkamas turf.' })
    end

    local turf = MySQL.single.await('SELECT owner_gang_id, progress FROM fivempro_gang_turfs WHERE turf_id = ? LIMIT 1', { turfId })
    if not turf then return cb({ ok = false, reason = 'Turf nerastas.' }) end
    if not canCaptureTurf(gang, turf) then
        return cb({ ok = false, reason = 'Negalima užimti savo turf.' })
    end

    local okRate, rateMsg = checkRateLimit(src)
    if not okRate then return cb({ ok = false, reason = rateMsg }) end

    if activeMissions[src] then
        return cb({ ok = false, reason = 'Jau vykdoma misija.' })
    end

    local token = ('%s-%s-%s'):format(src, turfId, os.time())
    local turfCfg = Config.Turfs[turfId]
    local center = turfCfg.center
    local pickup = mCfg.pickupOffset and vector3(center.x + mCfg.pickupOffset.x, center.y + mCfg.pickupOffset.y, center.z + (mCfg.pickupOffset.z or 0.0)) or center

    activeMissions[src] = {
        token = token,
        turfId = turfId,
        missionType = missionType,
        step = 1,
        startedAt = os.time(),
    }

    if missionType == 'hacking' then
        pendingHackMission[src] = { turfId = turfId, token = token }
    end

    cb({
        ok = true,
        token = token,
        missionType = missionType,
        label = mCfg.label,
        turfId = turfId,
        pickup = { x = pickup.x, y = pickup.y, z = pickup.z },
        drop = { x = center.x, y = center.y, z = center.z },
        durationMs = mCfg.durationMs or 7000,
        requireVehicle = mCfg.requireVehicle == true,
        checkpointCount = mCfg.checkpointCount or 3,
    })
end)

QBCore.Functions.CreateCallback('fivempro_gangs:server:finishMissionStep', function(src, cb, token, step)
    local act = activeMissions[src]
    if not act or act.token ~= tostring(token or '') then
        return cb({ ok = false, reason = 'Misija neaktyvi.' })
    end
    step = tonumber(step) or 1
    local mCfg = Config.MissionTypes[act.missionType]
    if not mCfg then return cb({ ok = false }) end

    if step == 1 then
        act.step = 2
        return cb({ ok = true, nextStep = 2, needTurf = mCfg.dropInTurf == true })
    end

    if step == 2 then
        if mCfg.dropInTurf and not playerInTurfServer(src, act.turfId) then
            return cb({ ok = false, reason = 'Pristatymas turi būti target turf zonoje.' })
        end
        if mCfg.requireVehicle then
            local ped = GetPlayerPed(src)
            if not ped or ped == 0 or not IsPedInAnyVehicle(ped, false) then
                return cb({ ok = false, reason = 'Reikia transporto.' })
            end
        end
        local progress = mCfg.progress or (Config.TaskReputation[act.missionType] or 8)
        local ok, reason = ApplyGangTurfTask(src, act.turfId, act.missionType, { progress = progress, skipTurfCheck = mCfg.dropInTurf ~= true })
        activeMissions[src] = nil
        pendingHackMission[src] = nil
        return cb({ ok = ok, reason = reason, done = true })
    end

    cb({ ok = false, reason = 'Netinkamas žingsnis.' })
end)

RegisterNetEvent('fivempro_gangs:server:cancelMission', function()
    local src = source
    activeMissions[src] = nil
    pendingHackMission[src] = nil
end)

exports('ApplyGangTurfTask', ApplyGangTurfTask)

exports('OnHackSuccess', function(src, tierId, coords)
    local gang = getPlayerGang(src)
    if not gang then return end
    local rep = (Config.HackGangRep and Config.HackGangRep[tostring(tierId or 'atm')]) or 2
    MySQL.update.await('UPDATE fivempro_gangs SET reputation = reputation + ? WHERE id = ?', { rep, gang.gang_id })

    local pending = pendingHackMission[src]
    if pending and pending.turfId then
        ApplyGangTurfTask(src, pending.turfId, 'hacking', { progress = Config.MissionTypes.hacking and Config.MissionTypes.hacking.progress or 12 })
        pendingHackMission[src] = nil
        activeMissions[src] = nil
    end
end)

exports('OnHackFailed', function(src, tierId, coords)
    local gang = getPlayerGang(src)
    if not gang then return end
    local heat = Config.HackFailHeat or 5
    MySQL.update.await('UPDATE fivempro_gangs SET heat = LEAST(100, heat + ?) WHERE id = ?', { heat, gang.gang_id })

    local turfId = nil
    local ped = GetPlayerPed(src)
    if ped and ped ~= 0 then
        local p = GetEntityCoords(ped)
        for id, turf in pairs(Config.Turfs or {}) do
            if #(p - vector3(turf.center.x, turf.center.y, turf.center.z)) <= (turf.radius or 180.0) then
                turfId = id
                break
            end
        end
    end
    if turfId then
        local turf = MySQL.single.await('SELECT heat FROM fivempro_gang_turfs WHERE turf_id = ? LIMIT 1', { turfId })
        if turf and canCaptureTurf(gang, turf) then
            MySQL.update.await('UPDATE fivempro_gang_turfs SET heat = LEAST(100, heat + ?) WHERE turf_id = ?', { heat * 2, turfId })
        end
    end
    pendingHackMission[src] = nil
    activeMissions[src] = nil
end)

RegisterNetEvent('fivempro_gangs:server:adminResetTurf', function(turfId)
    local src = source
    if not hasGangAdminPermission(src) then return end
    turfId = tostring(turfId or '')
    MySQL.update.await('UPDATE fivempro_gang_turfs SET owner_gang_id = NULL, owner_name = NULL, progress = 0, heat = 0 WHERE turf_id = ?', { turfId })
    TriggerClientEvent('QBCore:Notify', src, ('Turf %s reset.'):format(turfId), 'success')
end)

RegisterNetEvent('fivempro_gangs:server:adminSetTurfOwner', function(turfId, gangId)
    local src = source
    if not hasGangAdminPermission(src) then return end
    turfId = tostring(turfId or '')
    gangId = tonumber(gangId)
    local ownerName = nil
    if gangId and gangId > 0 then
        local g = MySQL.single.await('SELECT name FROM fivempro_gangs WHERE id = ? LIMIT 1', { gangId })
        ownerName = g and g.name or nil
    end
    MySQL.update.await('UPDATE fivempro_gang_turfs SET owner_gang_id = ?, owner_name = ?, progress = 0 WHERE turf_id = ?', {
        gangId, ownerName, turfId
    })
    TriggerClientEvent('QBCore:Notify', src, 'Turf savininkas pakeistas.', 'success')
end)

RegisterNetEvent('fivempro_gangs:server:adminSetTurfProgress', function(turfId, progress)
    local src = source
    if not hasGangAdminPermission(src) then return end
    MySQL.update.await('UPDATE fivempro_gang_turfs SET progress = ? WHERE turf_id = ?', { math.max(0, math.min(100, tonumber(progress) or 0)), tostring(turfId) })
    TriggerClientEvent('QBCore:Notify', src, 'Turf progresas nustatytas.', 'success')
end)

AddEventHandler('playerDropped', function()
    local src = source
    activeMissions[src] = nil
    pendingHackMission[src] = nil
    playerCooldown[src] = nil
    progressBucket[src] = nil
end)
