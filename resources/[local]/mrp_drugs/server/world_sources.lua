--[[
  Server: pasaulio žaliavų NPC šaltiniai (ne Dark Net):
    · alcoholFarmer — alcohol_base
    · vapeChemist   — vape_liquid_base (juodosios rinkos kaina)
    · pillsContact  — pill_powder (tik naktį, juodosios rinkos kaina)

  Anti-spam: min. tarpas tarp gavimų GTA žaidimo minutėmis (NE realaus laiko cooldown).
  Aguonų laukas (poppy_flower) naudoja esamą harvest sistemą (server/main.lua pickMushroom).
]]

local QBCore = exports['qb-core']:GetCoreObject()

local lastGather = {} -- [citizenid] = { [sourceKey] = gtaMinuteAbs }
local busy = {}       -- apsauga nuo lygiagretaus dvigubo apdorojimo

local function gtaMinutesAbs()
    if GetResourceState('qb-weathersync') ~= 'started' then return 0 end
    local ok, mins = pcall(function()
        return exports['qb-weathersync']:getGameMinutes()
    end)
    return (ok and tonumber(mins)) or 0
end

local function sourceCfg(key)
    return (Config.WorldSources or {})[key]
end

local function nearCoords(src, coords, maxDist)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end
    local p = GetEntityCoords(ped)
    return #(p - vector3(coords.x, coords.y, coords.z)) <= (maxDist or 3.0)
end

QBCore.Functions.CreateCallback('mrp_drugs:server:worldGather', function(src, cb, sourceKey)
    sourceKey = tostring(sourceKey or '')
    local cfg = sourceCfg(sourceKey)
    if not cfg or cfg.enabled == false then return cb({ ok = false, reason = 'Nepasiekiama.' }) end

    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return cb({ ok = false }) end
    local citizenid = Player.PlayerData.citizenid

    if busy[citizenid] then return cb({ ok = false, reason = 'Palauk akimirką.' }) end

    if not nearCoords(src, cfg.coords, 3.5) then
        return cb({ ok = false, reason = 'Per toli.' })
    end

    if cfg.nightOnly and DrugDarkNetIsNight and not DrugDarkNetIsNight() then
        return cb({ ok = false, reason = 'Grįžk naktį.' })
    end

    -- GTA-laiko tarpas (anti-spam, ne realaus laiko cooldown).
    local gap = tonumber(Config.WorldSources.gatherGameMinuteGap) or 0
    if gap > 0 then
        local now = gtaMinutesAbs()
        lastGather[citizenid] = lastGather[citizenid] or {}
        local last = lastGather[citizenid][sourceKey]
        if last and (now - last) < gap and (now - last) >= 0 then
            return cb({ ok = false, reason = 'Dar ne laikas. Grįžk vėliau.' })
        end
    end

    busy[citizenid] = true

    -- Kaina (jei nurodyta).
    local cost = tonumber(cfg.costPerBatch) or 0
    if cost > 0 and not DrugPlayer.canAffordDirty(Player, cost) then
        busy[citizenid] = nil
        return cb({ ok = false, reason = 'Trūksta nešvarių pinigų.' })
    end

    local item = cfg.item
    local amount = math.random(tonumber(cfg.amountMin) or 1, tonumber(cfg.amountMax) or 1)

    if GetResourceState('qb-inventory') == 'started' then
        local canAdd = exports['qb-inventory']:CanAddItem(src, item, amount)
        if not canAdd then
            busy[citizenid] = nil
            return cb({ ok = false, reason = 'Inventorius pilnas.' })
        end
    end

    if cost > 0 and not DrugPlayer.chargeDirty(src, Player, cost, 'mrp_drugs:world-' .. sourceKey) then
        busy[citizenid] = nil
        return cb({ ok = false, reason = 'Nepavyko nurašyti pinigų.' })
    end

    if not Player.Functions.AddItem(item, amount, false) then
        if cost > 0 then Player.Functions.AddItem('markedbills', 1, false, { worth = cost }) end
        busy[citizenid] = nil
        return cb({ ok = false, reason = 'Inventorius pilnas.' })
    end

    lastGather[citizenid] = lastGather[citizenid] or {}
    lastGather[citizenid][sourceKey] = gtaMinutesAbs()

    busy[citizenid] = nil

    local shared = QBCore.Shared.Items[item]
    if shared then
        TriggerClientEvent('inventory:client:ItemBox', src, shared, 'add', amount)
    end
    cb({ ok = true, item = item, amount = amount, label = shared and shared.label or item })
end)
