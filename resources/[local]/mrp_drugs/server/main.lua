local QBCore = exports['qb-core']:GetCoreObject()

local activeCrafts = {}
local activeStations = {}
local lastCraftAt = {}
local weedPackCooldownUntil = {}
local lastSellAt = {}
local zoneHeat = {}

local function logAdmin(msg)
    print(('[^3mrp_drugs^7] %s'):format(msg))
end

local function payoutItemLabel()
    local sellCfg = Config.Sell or {}
    local itemName = tostring(sellCfg.payoutItem or 'markedbills'):lower()
    local shared = QBCore.Shared.Items[itemName]
    return (shared and shared.label) or 'Nešvarūs pinigai'
end

--- Nešvarūs pinigai (markedbills) — 1 vnt. = $1, inventorius rodo x suma.
local function giveDrugSalePayout(src, Player, amount, reason)
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then return true end

    local sellCfg = Config.Sell or {}
    local itemName = tostring(sellCfg.payoutItem or 'markedbills'):lower()
    local shared = QBCore.Shared.Items[itemName]
    if not shared then
        Player.Functions.AddMoney('cash', amount, reason)
        return true
    end

    local ok = false
    if itemName == 'markedbills' and DrugPlayer and DrugPlayer.addDirty then
        ok = DrugPlayer.addDirty(src, Player, amount, reason)
    else
        ok = Player.Functions.AddItem(itemName, amount, false, {})
        if not ok and GetResourceState('qb-inventory') == 'started' then
            ok = exports['qb-inventory']:AddItem(src, itemName, amount, nil, {}, reason)
        end
    end

    if ok then
        TriggerClientEvent('qb-inventory:client:ItemBox', src, shared, 'add', amount)
        if GetResourceState('qb-inventory') == 'started' then
            exports['qb-inventory']:SaveInventory(src)
        end
        return true
    end

    if sellCfg.payoutFallbackCash ~= false then
        Player.Functions.AddMoney('cash', amount, reason .. '-fallback')
        return true
    end

    return false
end

exports('GiveDrugSalePayout', function(src, amount, reason)
    local Player = QBCore.Functions.GetPlayer(tonumber(src) or 0)
    if not Player then return false end
    return giveDrugSalePayout(Player.PlayerData.source, Player, amount, reason or 'drug-sale')
end)

local function getProduct(id)
    if Config.Products and Config.Products[id] then return Config.Products[id] end
    return Config.WeaponProducts and Config.WeaponProducts[id]
end

local function getStationProductPool(st)
    if st and st.mode == 'weapon' then
        return Config.WeaponProducts or {}
    end
    return Config.Products or {}
end

local function getRecipe(productId, st)
    if st and st.mode == 'weapon' then
        return (Config.WeaponRecipes or {})[productId] or {}
    end
    return (Config.Recipes or {})[productId] or {}
end

local function getAllStations()
    if Config.GetAllCraftStations then
        return Config.GetAllCraftStations()
    end
    return {}
end

local function stationProductAllowed(st, productId)
    if not st or not st.products or #st.products == 0 then return true end
    for _, pid in ipairs(st.products) do
        if pid == productId then return true end
    end
    return false
end

local function getStation(id)
    for _, st in ipairs(getAllStations()) do
        if st.id == id then return st end
    end
end

local PRINTER_PARTS = { gun_frame = true, gun_barrel = true }
local PROTOTYPE_ITEM = 'weapon_prototype'

local function resolveSharedItem(itemName)
    if not itemName then return nil end
    local key = tostring(itemName):lower()
    if QBCore.Shared.Items[key] then return QBCore.Shared.Items[key] end
    for _, info in pairs(QBCore.Shared.Items) do
        if type(info) == 'table' and info.name and string.lower(info.name) == key then
            return info
        end
    end
end

local function isPoliceOnDuty(src)
    local P = QBCore.Functions.GetPlayer(src)
    if not P or not P.PlayerData.job then return false end
    return P.PlayerData.job.name == 'police' and P.PlayerData.job.onduty == true
end

local function productUsesPrinter(productId, st)
    if not st or st.mode ~= 'weapon' then return false end
    for _, row in ipairs(getRecipe(productId, st)) do
        if PRINTER_PARTS[row.item] then return true end
    end
    return false
end

local function getEffectiveRecipe(productId, st, src)
    local recipe = getRecipe(productId, st)
    if not src or isPoliceOnDuty(src) or not productUsesPrinter(productId, st) then
        return recipe
    end
    for _, row in ipairs(recipe) do
        if row.item == PROTOTYPE_ITEM then return recipe end
    end
    local out = {}
    for i, row in ipairs(recipe) do
        out[i] = row
    end
    out[#out + 1] = { item = PROTOTYPE_ITEM, count = 1 }
    return out
end

local function estimateWeaponCraftSec(prod, usesPrinter)
    if not prod then return 0 end
    local wc = Config.WeaponCraft or {}
    local level = tonumber(prod.level) or 1
    local mult = (wc.timeMultiplier and wc.timeMultiplier[level]) or 1.0
    local ms = math.floor((tonumber(prod.craftTimeMs) or 60000) * mult)
    local mg = tostring(prod.minigame or 'progress')
    if mg ~= 'progress' and wc.minigameBonusMs then
        ms = ms + (tonumber(wc.minigameBonusMs[mg]) or 0)
    end
    return math.floor(ms / 1000)
end

local function playerNearStation(src, stationId)
    local st = getStation(stationId)
    if not st or not st.coords then return false end
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end
    local p = GetEntityCoords(ped)
    if Config.EnableDrugTestNPC and Config.DevHub then
        local hub = Config.DevHub.center or Config.DevHub.blipCoords
        if hub and #(p - hub) <= 55.0 then
            return true
        end
    end
    return #(p - st.coords) <= (st.radius or 2.5) + 1.5
end

local function countItem(Player, item, amount)
    local it = Player.Functions.GetItemByName(item)
    if not it or not it.amount then return false end
    return it.amount >= amount
end

local function countItemAmount(Player, item)
    local total = 0
    local byName = Player.Functions.GetItemsByName and Player.Functions.GetItemsByName(item)
    if type(byName) == 'table' and #byName > 0 then
        for _, it in ipairs(byName) do
            total = total + (tonumber(it.amount) or 0)
        end
        return total
    end
    for _, it in pairs(Player.PlayerData.items or {}) do
        if it and it.name == item then
            total = total + (tonumber(it.amount) or 0)
        end
    end
    return total
end

local function recipeRowSatisfied(Player, row, st)
    if st and st.equipmentType and row.item == st.equipmentType then
        return true
    end
    if st and st.equipmentId and Equipment and Equipment.rowSatisfiedByNearby(st.equipmentId, row.item) then
        return true
    end
    return countItem(Player, row.item, row.count)
end

local function skipRecipeConsumable(row, st)
    if st and st.equipmentType and row.item == st.equipmentType then
        return true
    end
    if st and st.equipmentId and Equipment and Equipment.rowSatisfiedByNearby(st.equipmentId, row.item) then
        return true
    end
    return false
end

local function addItems(Player, list)
    for _, row in ipairs(list or {}) do
        Player.Functions.AddItem(row.item, row.count)
    end
end

local function removeItems(Player, list, st)
    local consumed = {}
    for _, row in ipairs(list) do
        if skipRecipeConsumable(row, st) then
            goto continue
        end
        if not Player.Functions.RemoveItem(row.item, row.count) then
            addItems(Player, consumed)
            return false, {}
        end
        consumed[#consumed + 1] = { item = row.item, count = row.count }
        ::continue::
    end
    return true, consumed
end

local function refundPartial(Player, list, percent)
    percent = math.max(0, math.min(100, tonumber(percent) or 0))
    if percent <= 0 then return end
    for _, row in ipairs(list) do
        local give = math.floor(row.count * (percent / 100))
        if give > 0 then
            Player.Functions.AddItem(row.item, give)
        end
    end
end

local function craftLockKey(stationId, equipmentId)
    if equipmentId then return ('equipment:%s'):format(equipmentId) end
    return ('station:%s'):format(stationId)
end

local function releaseCraft(src)
    local active = activeCrafts[src]
    if active and active.lockKey and activeStations[active.lockKey] == src then
        activeStations[active.lockKey] = nil
    end
    activeCrafts[src] = nil
    return active
end

local function minimumCraftDuration(prod)
    local duration = tonumber(prod and prod.craftTimeMs) or 10000
    local minRatio = (prod and prod.minigame == 'schedule') and 0.20 or 0.85
    return math.max(1000, math.floor(duration * minRatio))
end

local WEED_STAGE_SEQUENCES = {
    weed_process = {
        { name = 'sorted', minMs = 3000 },
        { name = 'dried', minMs = 8500 },
    },
    weed_pack = {
        -- PAKAVIMAS: serverio etapų seka. bag_ready po pirmo maišelio (min 300 ms), packed_five po 5 vnt. (min 2500 ms).
        { name = 'bag_ready', minMs = 300 },
        { name = 'packed_five', minMs = 2500 },
    },
}

local function createWeedStageState(productId, now)
    local sequence = WEED_STAGE_SEQUENCES[productId]
    if not sequence then return nil end
    return {
        sequence = sequence,
        index = 0,
        lastStageAt = now,
    }
end

local function levelUnlocked(src, prod, st)
    if st and st.mode == 'weapon' then
        if not DrugPlayer or not DrugPlayer.weaponProductUnlocked then return true end
        return DrugPlayer.weaponProductUnlocked(src, prod and prod.level or 1)
    end
    if not Config.DrugProgression or Config.DrugProgression.enabled == false then return true end
    if not DrugPlayer or not DrugPlayer.levelUnlocked then return true end
    return DrugPlayer.levelUnlocked(src, prod and prod.level or 1)
end

local function weaponUnlockHint(src, prodLevel)
    local cfg = Config.WeaponPrintProgression or {}
    local prints = DrugPlayer and DrugPlayer.getWeaponPrints and DrugPlayer.getWeaponPrints(src) or 0
    local need = prodLevel >= 2 and (tonumber(cfg.unlockL2At) or 15) or (tonumber(cfg.unlockL1At) or 10)
    return ('Reikia %d/%d 3D spausdinimų'):format(prints, need)
end

local function buildRecipeStatus(Player, productId, st, src)
    local recipe = getEffectiveRecipe(productId, st, src)
    local rows = {}
    for _, row in ipairs(recipe) do
        local have
        if skipRecipeConsumable(row, st) then
            have = row.count
        else
            local it = Player.Functions.GetItemByName(row.item)
            have = it and it.amount or 0
        end
        rows[#rows + 1] = {
            item = row.item,
            label = (resolveSharedItem(row.item) or {}).label or row.item,
            need = row.count,
            have = have,
            missing = math.max(0, row.count - have),
        }
    end
    return rows
end

local function hasAllIngredients(Player, productId, st, src)
    for _, row in ipairs(getEffectiveRecipe(productId, st, src)) do
        if not recipeRowSatisfied(Player, row, st) then
            return false
        end
    end
    return true
end

local function findTurfAtPlayer(src)
    if GetResourceState('mrp_gangs') ~= 'started' then return nil end
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    local c = GetEntityCoords(ped)
    if exports['mrp_gangs'] then
        local ok, tid = pcall(function()
            return exports['mrp_gangs']:FindTurfAt(c.x, c.y)
        end)
        if ok then return tid end
    end
    return nil
end

local function getPlayerGang(src)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return nil end
    return MySQL.single.await([[
        SELECT gm.gang_id, gm.rank, g.name, g.reputation, g.heat
        FROM fivempro_gang_members gm
        JOIN fivempro_gangs g ON g.id = gm.gang_id
        WHERE gm.citizenid = ?
        LIMIT 1
    ]], { Player.PlayerData.citizenid })
end

local function addTurfHeat(turfId, amount)
    if not turfId then return end
    zoneHeat[turfId] = math.min(100, (zoneHeat[turfId] or 0) + (amount or 1))
    MySQL.update.await('UPDATE fivempro_gang_turfs SET heat = LEAST(100, heat + ?) WHERE turf_id = ?', {
        tonumber(amount) or 1,
        tostring(turfId),
    })
end

local function policeAlert(src, alertKey, extra)
    if GetResourceState('mrp_dispatch') ~= 'started' then return end
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return end
    local c = GetEntityCoords(ped)
    local msg = (Config.PoliceAlerts and Config.PoliceAlerts[alertKey]) or 'Įtartina veikla'
    if extra then msg = msg .. ' — ' .. extra end
    pcall(function()
        exports['mrp_dispatch']:CreateDispatchCall('police', 'drugs', { x = c.x, y = c.y, z = c.z }, msg, src)
    end)
end

local function rollPolice(chance, src, key)
    chance = tonumber(chance) or 0
    if chance <= 0 then return end
    if math.random(1, 100) <= chance then
        policeAlert(src, key)
    end
end

QBCore.Functions.CreateCallback('mrp_drugs:server:getStationUi', function(src, cb, stationId)
    local st = getStation(stationId)
    if not st then return cb({ ok = false, reason = 'Stotis nerasta.' }) end
    if not playerNearStation(src, stationId) then
        return cb({ ok = false, reason = 'Per toli nuo gamybos vietos.' })
    end
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return cb({ ok = false }) end

    local products = {}
    local pool = getStationProductPool(st)
    local weaponTier = (st.mode == 'weapon' and DrugPlayer and DrugPlayer.getWeaponCraftTier)
        and DrugPlayer.getWeaponCraftTier(src)
        or nil
    local weaponPrints = (st.mode == 'weapon' and DrugPlayer and DrugPlayer.getWeaponPrints)
        and DrugPlayer.getWeaponPrints(src)
        or 0

    for pid, prod in pairs(pool) do
        local levelOk = (st.mode == 'weapon') or (prod.level == st.level)
        if levelOk and stationProductAllowed(st, pid) then
            local exclusive = Config.AmpExclusiveProducts and Config.AmpExclusiveProducts[pid]
            if not exclusive or (st.products and #st.products > 0) then
                local unlocked = levelUnlocked(src, prod, st)
                products[#products + 1] = {
                    id = pid,
                    label = prod.label,
                    level = prod.level,
                    stage = prod.stage,
                    stageLabel = prod.stage == 'pack' and '3 · Supakuota' or '2 · Apdorojimas',
                    levelLabel = Config.LevelLabels[prod.level] or ('Lygis ' .. prod.level),
                    risk = Config.RiskLabels[prod.risk] or prod.risk,
                    craftTimeSec = (st.mode == 'weapon') and estimateWeaponCraftSec(prod) or math.floor((prod.craftTimeMs or 30000) / 1000),
                    sellBase = (st.mode == 'weapon') and 0 or prod.sellBase,
                    minigame = prod.minigame,
                    usesPrinter = productUsesPrinter(pid, st),
                    ingredients = buildRecipeStatus(Player, pid, st, src),
                    mode = st.mode or 'drugs',
                    locked = not unlocked,
                    lockReason = (not unlocked and st.mode == 'weapon') and weaponUnlockHint(src, prod.level) or nil,
                }
            end
        end
    end
    table.sort(products, function(a, b)
        local pool = getStationProductPool(st)
        local orderA = pool[a.id] and pool[a.id].lineOrder or 99
        local orderB = pool[b.id] and pool[b.id].lineOrder or 99
        if orderA ~= orderB then return orderA < orderB end
        if (a.locked and not b.locked) then return false end
        if (b.locked and not a.locked) then return true end
        return a.label < b.label
    end)

    local stationPayload = { id = st.id, label = st.label, level = st.level, mode = st.mode or 'drugs' }
    if st.mode == 'weapon' then
        local cfg = Config.WeaponPrintProgression or {}
        stationPayload.weaponPrints = weaponPrints
        stationPayload.weaponTier = weaponTier or 0
        stationPayload.unlockL1At = tonumber(cfg.unlockL1At) or 10
        stationPayload.unlockL2At = tonumber(cfg.unlockL2At) or 15
    end

    cb({
        ok = true,
        station = stationPayload,
        products = products,
    })
end)

QBCore.Functions.CreateCallback('mrp_drugs:server:startCraft', function(src, cb, stationId, productId)
    local st = getStation(stationId)
    local prod = getProduct(productId)
    if not st or not prod then return cb({ ok = false, reason = 'Netinkami duomenys.' }) end
    if st.mode ~= 'weapon' and prod.level ~= st.level then
        return cb({ ok = false, reason = 'Ši stotis netinka šiam produktui.' })
    end
    if not stationProductAllowed(st, productId) then
        return cb({ ok = false, reason = 'Šiame punkte negalima gaminti šio produkto.' })
    end
    if not levelUnlocked(src, prod, st) then
        local reason = 'Šis gamybos lygis dar neatrakintas.'
        if st.mode == 'weapon' then
            reason = weaponUnlockHint(src, prod.level) .. '.'
        end
        return cb({ ok = false, reason = reason })
    end
    if not playerNearStation(src, stationId) then
        return cb({ ok = false, reason = 'Per toli nuo stoties.' })
    end

    local now = GetGameTimer()
    if productId == 'weed_pack' and (weedPackCooldownUntil[src] or 0) > now then
        local seconds = math.ceil(((weedPackCooldownUntil[src] or 0) - now) / 1000)
        return cb({ ok = false, reason = ('Palauk %d sek. prieš kitą 5 vnt. pakavimą.'):format(seconds) })
    end
    if (lastCraftAt[src] or 0) + (Config.CraftCooldownMs or 4500) > now then
        return cb({ ok = false, reason = 'Palauk prieš kitą gamybą.' })
    end
    if activeCrafts[src] then
        return cb({ ok = false, reason = 'Jau vyksta gamyba.' })
    end
    local lockKey = craftLockKey(stationId)
    if activeStations[lockKey] then
        return cb({ ok = false, reason = 'Šia stotimi jau naudojasi kitas žaidėjas.' })
    end

    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return cb({ ok = false }) end
    if not hasAllIngredients(Player, productId, st, src) then
        return cb({ ok = false, reason = 'Trūksta ingredientų.' })
    end

    local recipe = getEffectiveRecipe(productId, st, src)
    local removed, consumed = removeItems(Player, recipe, st)
    if not removed then
        return cb({ ok = false, reason = 'Nepavyko paimti ingredientų.' })
    end

    local token = ('%s-%s-%s'):format(src, productId, now)
    activeStations[lockKey] = src
    activeCrafts[src] = {
        token = token,
        lockKey = lockKey,
        stationId = stationId,
        productId = productId,
        startedAt = now,
        minDurationMs = minimumCraftDuration(prod),
        recipe = consumed,
        weedStages = createWeedStageState(productId, now),
        isWeapon = st.mode == 'weapon',
    }
    lastCraftAt[src] = now

    cb({
        ok = true,
        token = token,
        craftTimeMs = prod.craftTimeMs,
        minigame = prod.minigame,
        label = prod.label,
        failChance = prod.failChance,
        level = prod.level,
        isWeapon = st.mode == 'weapon',
        usesPrinter = productUsesPrinter(productId, st),
    })
end)

local function equipmentVirtualStation(e, prod)
    return {
        id = ('eq_%s'):format(e.id),
        label = Equipment and Equipment.labelFor(e) or 'Įranga',
        level = prod and prod.level or 1,
        coords = vector3(e.x, e.y, e.z),
        radius = (Config.DrugEquipment and Config.DrugEquipment.interactDist) or 2.5,
        mode = 'drugs',
        equipmentType = e.itemType,
        equipmentId = e.id,
    }
end

QBCore.Functions.CreateCallback('mrp_drugs:server:startCraftAtEquipment', function(src, cb, equipmentId, productId)
    if not Equipment or not Config.DrugEquipment or not Config.DrugEquipment.enabled then
        return cb({ ok = false, reason = 'Įrangos režimas išjungtas.' })
    end
    local e = Equipment.get(equipmentId)
    local prod = getProduct(productId)
    if not e or not prod then return cb({ ok = false, reason = 'Netinkami duomenys.' }) end
    if productId == 'amp_process' then
        return cb({ ok = false, reason = 'Amfetamino sintezė vykdoma tik mobilioje Journey laboratorijoje.' })
    end
    if not Equipment.playerNear(src, equipmentId) then
        return cb({ ok = false, reason = 'Per toli nuo įrangos.' })
    end
    if not Equipment.productAllowedAt(e, productId) then
        return cb({ ok = false, reason = 'Ši įranga netinka šiam receptui.' })
    end

    local st = equipmentVirtualStation(e, prod)
    if prod.level ~= st.level then
        return cb({ ok = false, reason = 'Netinkamas lygis.' })
    end
    if not levelUnlocked(src, prod, st) then
        return cb({ ok = false, reason = 'Šis gamybos lygis dar neatrakintas.' })
    end

    local now = GetGameTimer()
    if productId == 'weed_pack' and (weedPackCooldownUntil[src] or 0) > now then
        local seconds = math.ceil(((weedPackCooldownUntil[src] or 0) - now) / 1000)
        return cb({ ok = false, reason = ('Palauk %d sek. prieš kitą 5 vnt. pakavimą.'):format(seconds) })
    end
    if (lastCraftAt[src] or 0) + (Config.CraftCooldownMs or 4500) > now then
        return cb({ ok = false, reason = 'Palauk prieš kitą gamybą.' })
    end
    if activeCrafts[src] then
        return cb({ ok = false, reason = 'Jau vyksta gamyba.' })
    end
    local lockKey = craftLockKey(nil, equipmentId)
    if activeStations[lockKey] then
        return cb({ ok = false, reason = 'Šia įranga jau naudojasi kitas žaidėjas.' })
    end

    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return cb({ ok = false }) end
    if not hasAllIngredients(Player, productId, st, src) then
        return cb({ ok = false, reason = 'Trūksta ingredientų.' })
    end

    local recipe = getEffectiveRecipe(productId, st, src)
    local removed, consumed = removeItems(Player, recipe, st)
    if not removed then
        return cb({ ok = false, reason = 'Nepavyko paimti ingredientų.' })
    end

    local token = ('%s-eq-%s-%s'):format(src, equipmentId, now)
    activeStations[lockKey] = src
    activeCrafts[src] = {
        token = token,
        lockKey = lockKey,
        stationId = st.id,
        productId = productId,
        startedAt = now,
        minDurationMs = minimumCraftDuration(prod),
        recipe = consumed,
        weedStages = createWeedStageState(productId, now),
        isWeapon = false,
        equipmentId = equipmentId,
        virtualStation = st,
    }
    lastCraftAt[src] = now

    cb({
        ok = true,
        token = token,
        craftTimeMs = prod.craftTimeMs,
        minigame = prod.minigame,
        label = prod.label,
        failChance = prod.failChance,
        level = prod.level,
        isWeapon = false,
        usesPrinter = false,
        equipmentCraft = true,
    })
end)

-- ── Kokybės sistema ──────────────────────────────────────────────────────
-- Serveris pats išveda kokybę iš minigame score (0..100). Kliento atsiųsta
-- 'quality' eilutė NEnaudojama (nepasitikima) — tik score, kuris apkarpomas.
-- Kokybė rašoma į item.info.quality metadata (item struktūra NEkeičiama).
-- Pardavime kokybė veikia kainą per daugiklį; seni daiktai be kokybės = 1.0.
local QUALITY_TIERS = {
    { key = 'poor', label = 'Prasta', min = 0, mult = 0.72 },
    { key = 'medium', label = 'Vidutinė', min = 40, mult = 0.92 },
    { key = 'good', label = 'Gera', min = 65, mult = 1.12 },
    { key = 'excellent', label = 'Puiki', min = 85, mult = 1.35 },
}

local function qualityFromScore(score)
    if type(score) ~= 'number' then return nil end
    local s = math.max(0, math.min(100, math.floor(score)))
    local chosen = QUALITY_TIERS[1]
    for _, t in ipairs(QUALITY_TIERS) do
        if s >= t.min then chosen = t end
    end
    return chosen, s
end

local function qualityMult(key)
    if not key then return 1.0 end
    for _, t in ipairs(QUALITY_TIERS) do
        if t.key == key then return t.mult end
    end
    return 1.0
end

local function findItemSlot(Player, itemName)
    for _, it in pairs(Player.PlayerData.items or {}) do
        if it and it.name == itemName and (it.amount or 0) > 0 then
            return it
        end
    end
    return nil
end

local function removeSellItems(Player, itemName, amount)
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then return 0, nil end
    local removed = 0
    local sellQuality = nil
    while removed < amount do
        local slot = findItemSlot(Player, itemName)
        if not slot or not slot.slot then break end
        local avail = math.floor(tonumber(slot.amount) or 0)
        if avail <= 0 then break end
        local take = math.min(amount - removed, avail)
        if not sellQuality and slot.info and slot.info.quality ~= nil then
            sellQuality = slot.info.quality
        end
        if not Player.Functions.RemoveItem(itemName, take, slot.slot) then
            break
        end
        removed = removed + take
    end
    return removed, sellQuality
end

--- Gatvės NPC: po vieno pirkimo nebegali pirkti iš nieko (visiems žaidėjams).
local soldStreetNpcs = {}

local function isStreetNpcSold(netId)
    netId = tonumber(netId) or 0
    if netId <= 0 then return false end
    if soldStreetNpcs[netId] then
        local ent = NetworkGetEntityFromNetworkId(netId)
        if ent == 0 or not DoesEntityExist(ent) then
            soldStreetNpcs[netId] = nil
            return false
        end
        return true
    end
    local ent = NetworkGetEntityFromNetworkId(netId)
    if ent ~= 0 and DoesEntityExist(ent) then
        local st = Entity(ent).state
        if st and st.mrpDrugSold then
            soldStreetNpcs[netId] = true
            return true
        end
    end
    return false
end

local function markStreetNpcSold(netId)
    netId = tonumber(netId) or 0
    if netId <= 0 then return end
    soldStreetNpcs[netId] = true
    local ent = NetworkGetEntityFromNetworkId(netId)
    if ent ~= 0 and DoesEntityExist(ent) then
        pcall(function()
            Entity(ent).state:set('mrpDrugSold', true, true)
        end)
    end
    TriggerClientEvent('mrp_drugs:client:markNpcSold', -1, netId)
end

QBCore.Functions.CreateCallback('mrp_drugs:server:weedProductionStage', function(src, cb, token, stageName)
    local active = activeCrafts[src]
    if not active or active.token ~= token or not active.weedStages then
        return cb({ ok = false, reason = 'Žolės gamybos sesija neaktyvi.' })
    end
    local state = active.weedStages
    local expected = state.sequence[state.index + 1]
    if not expected or expected.name ~= tostring(stageName) then
        logAdmin(('REJECT weed stage=%s product=%s src=%s'):format(tostring(stageName), active.productId, src))
        return cb({ ok = false, reason = 'Netinkama žolės gamybos etapų seka.' })
    end
    local now = GetGameTimer()
    local elapsed = now - (state.lastStageAt or active.startedAt or now)
    if elapsed < expected.minMs then
        logAdmin(('REJECT fast weed stage=%s elapsed=%d src=%s'):format(expected.name, elapsed, src))
        return cb({ ok = false, reason = 'Žolės gamybos etapas atliktas per greitai.' })
    end
    state.index = state.index + 1
    state.lastStageAt = now
    cb({ ok = true, index = state.index, total = #state.sequence })
end)

RegisterNetEvent('mrp_drugs:server:cancelCraft', function(token, reason)
    local src = source
    local active = activeCrafts[src]
    if not active or active.token ~= token then return end
    releaseCraft(src)
    local Player = QBCore.Functions.GetPlayer(src)
    if Player then refundPartial(Player, active.recipe, 50) end
    logAdmin(('CANCEL craft %s reason=%s src=%s'):format(active.productId, tostring(reason or 'client_cleanup'), src))
end)

QBCore.Functions.CreateCallback('mrp_drugs:server:finishCraft', function(src, cb, token, minigameSuccess, extra)
    local active = activeCrafts[src]
    if not active or active.token ~= token then
        return cb({ ok = false, reason = 'Gamyba neaktyvi.' })
    end
    if active.equipmentId then
        if not Equipment or not Equipment.playerNear(src, active.equipmentId) then
            releaseCraft(src)
            local Player = QBCore.Functions.GetPlayer(src)
            if Player then refundPartial(Player, active.recipe, 100) end
            return cb({ ok = false, reason = 'Per toli nuo įrangos.' })
        end
    elseif not playerNearStation(src, active.stationId) then
        releaseCraft(src)
        local Player = QBCore.Functions.GetPlayer(src)
        if Player then refundPartial(Player, active.recipe, 100) end
        return cb({ ok = false, reason = 'Per toli nuo stoties.' })
    end

    local prod = getProduct(active.productId)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player or not prod then
        releaseCraft(src)
        return cb({ ok = false })
    end

    local elapsed = GetGameTimer() - active.startedAt
    if minigameSuccess == true and elapsed < (active.minDurationMs or 1000) then
        releaseCraft(src)
        refundPartial(Player, active.recipe, 100)
        logAdmin(('REJECT fast craft %s elapsed=%d cid=%s'):format(active.productId, elapsed, Player.PlayerData.citizenid))
        return cb({ ok = false, reason = 'Gamyba užbaigta per greitai.', failed = true })
    end
    if minigameSuccess == true and active.weedStages
        and active.weedStages.index < #active.weedStages.sequence then
        releaseCraft(src)
        refundPartial(Player, active.recipe, 50)
        logAdmin(('REJECT incomplete weed stages %s cid=%s'):format(active.productId, Player.PlayerData.citizenid))
        return cb({ ok = false, reason = 'Neužbaigti visi žolės gamybos etapai.', failed = true })
    end

    releaseCraft(src)

    local failed = minigameSuccess ~= true

    if failed then
        refundPartial(Player, active.recipe, 100 - (prod.failLosePercent or 50))
        local turfId = findTurfAtPlayer(src)
        if turfId then addTurfHeat(turfId, prod.heatGain or 3) end
        if not active.isWeapon then
            rollPolice((prod.policeChance or 8) + 6, src, 'craft_fail')
        end
        logAdmin(('FAIL craft %s cid=%s'):format(active.productId, Player.PlayerData.citizenid))
        return cb({ ok = false, reason = 'Gamyba nepavyko — dalis medžiagų prarasta.', failed = true })
    end

    local outItem = prod.output
    local outAmt = prod.outputAmount or 1

    -- Kokybė iš minigame score (serverio autoritetas, apkarpyta 0..100).
    local qTier, qScore = qualityFromScore(extra and extra.score)
    local addInfo = false
    local qualityLabel = nil
    if qTier and Config.UseQuality ~= false then
        addInfo = { quality = qTier.key, quality_score = qScore }
        qualityLabel = qTier.label
        logAdmin(('QUALITY %s=%s score=%d cid=%s'):format(outItem, qTier.key, qScore or 0, Player.PlayerData.citizenid))
    end

    if not Player.Functions.AddItem(outItem, outAmt, false, addInfo) then
        refundPartial(Player, active.recipe, 80)
        return cb({ ok = false, reason = 'Inventorius pilnas.' })
    end

    if prod.bonusItems then
        for _, bonus in ipairs(prod.bonusItems) do
            if bonus.item and bonus.count and bonus.count > 0 then
                Player.Functions.AddItem(bonus.item, bonus.count)
            end
        end
    end

    local turfId = findTurfAtPlayer(src)
    if turfId then addTurfHeat(turfId, math.max(1, math.floor((prod.heatGain or 2) / 2))) end
    if not active.isWeapon then
        rollPolice(prod.policeChance, src, 'craft_high')
    end
    logAdmin(('OK craft %s x%d cid=%s'):format(outItem, outAmt, Player.PlayerData.citizenid))
    if active.productId == 'weed_pack' then
        weedPackCooldownUntil[src] = GetGameTimer() + (Config.WeedPackCooldownMs or 10000)
    end

    cb({
        ok = true,
        item = outItem,
        amount = outAmt,
        label = prod.label,
        quality = qTier and qTier.key or nil,
        qualityLabel = qualityLabel,
    })
end)

QBCore.Functions.CreateCallback('mrp_drugs:server:tryNpcSell', function(src, cb, itemName, npcNetId)
    local sellCfg = Config.Sell or {}
    local prod
    for pid, p in pairs(Config.Products or {}) do
        if p.output == itemName and (p.sellBase or 0) > 0 then
            prod = p
            break
        end
    end
    if not prod then return cb({ ok = false, reason = 'Šio daikto negalima parduoti čia.' }) end

    local now = GetGameTimer()
    if (lastSellAt[src] or 0) + (Config.SellCooldownMs or 6000) > now then
        return cb({ ok = false, reason = 'Palauk prieš kitą pardavimą.' })
    end

    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return cb({ ok = false }) end

    local netId = tonumber(npcNetId) or 0
    if netId <= 0 then
        return cb({ ok = false, reason = 'Netinkamas NPC.' })
    end
    if isStreetNpcSold(netId) then
        return cb({ ok = false, reason = 'Šis asmuo jau nusipirko — daugiau neparduos.', alreadySold = true })
    end

    local ent = NetworkGetEntityFromNetworkId(netId)
    if ent == 0 or not DoesEntityExist(ent) then
        return cb({ ok = false, reason = 'NPC nebepasiekiamas.' })
    end
    local p = GetEntityCoords(GetPlayerPed(src))
    local n = GetEntityCoords(ent)
    if #(p - n) > (sellCfg.maxDistanceToPed or 3.0) + 1.5 then
        return cb({ ok = false, reason = 'NPC per toli.' })
    end
    if IsPedAPlayer(ent) then
        return cb({ ok = false, reason = 'Netinkamas tikslas.' })
    end

    local have = countItemAmount(Player, itemName)
    local minBuy = math.max(1, math.floor(tonumber(sellCfg.minUnitsPerNpc) or 1))
    local maxBuy = math.max(minBuy, math.floor(tonumber(sellCfg.maxUnitsPerNpc) or 5))
    if have < minBuy then
        return cb({ ok = false, reason = 'Neturi šio produkto.' })
    end
    local qty = math.random(minBuy, math.min(maxBuy, have))

    if math.random(1, 100) <= (sellCfg.refuseChance or 18) then
        markStreetNpcSold(netId)
        return cb({ ok = false, refused = true, reason = 'NPC atsisakė pirkti.' })
    end

    if math.random(1, 100) <= (sellCfg.panicChance or 8) then
        markStreetNpcSold(netId)
        rollPolice(85, src, 'npc_panic')
        return cb({ ok = false, panic = true, reason = 'NPC panikuoja ir bėga!' })
    end

    local removed, sellQuality = removeSellItems(Player, itemName, qty)
    if removed < qty then
        if removed > 0 then
            Player.Functions.AddItem(itemName, removed)
        end
        return cb({ ok = false, reason = 'Nepavyko paimti produkto iš inventoriaus.' })
    end

    local gang = getPlayerGang(src)
    local turfId = findTurfAtPlayer(src)
    local unitPrice = prod.sellBase or 100
    unitPrice = math.floor(unitPrice * qualityMult(sellQuality))
    if gang then
        unitPrice = math.floor(unitPrice * (1.0 + ((tonumber(gang.reputation) or 0) * (sellCfg.reputationPriceFactor or 0.004))))
    end
    if turfId and zoneHeat[turfId] and zoneHeat[turfId] > 40 then
        unitPrice = math.floor(unitPrice * 1.08)
    end
    unitPrice = math.floor(unitPrice * (sellCfg.basePriceMultiplier or 1.0))
    local price = unitPrice * qty
    if not giveDrugSalePayout(src, Player, price, 'fivempro-drugs-sale') then
        Player.Functions.AddItem(itemName, qty)
        return cb({ ok = false, reason = 'Inventorius pilnas — nėra vietos nešvariems pinigams.' })
    end
    lastSellAt[src] = now
    markStreetNpcSold(netId)

    local alertPolice = false
    if math.random(1, 100) <= (sellCfg.policeCallChance or 12) then
        alertPolice = true
        rollPolice(100, src, 'npc_call')
    end

    if turfId then
        addTurfHeat(turfId, sellCfg.heatPerSale or 3)
        if gang and GetResourceState('mrp_gangs') == 'started' then
            local inf = tonumber(sellCfg.influencePerSale) or 2
            local turf = MySQL.single.await('SELECT owner_gang_id, sales_count, total_profit FROM fivempro_gang_turfs WHERE turf_id = ? LIMIT 1', { turfId })
            if turf and tonumber(turf.owner_gang_id) == tonumber(gang.gang_id) then
                local salesCount = (tonumber(turf.sales_count) or 0) + 1
                local totalProfit = (tonumber(turf.total_profit) or 0) + price
                MySQL.update.await('UPDATE fivempro_gang_turfs SET sales_count = ?, total_profit = ? WHERE turf_id = ?', {
                    salesCount, totalProfit, turfId,
                })
                MySQL.insert.await('INSERT INTO fivempro_gang_sales_logs (gang_id, turf_id, item_name, amount, profit) VALUES (?, ?, ?, ?, ?)', {
                    gang.gang_id, turfId, itemName, qty, price,
                })
                exports['mrp_gangs']:AddTurfInfluence(src, turfId, 'drug_sale', {
                    amount = inf,
                    skipTurfCheck = true,
                    allowOwnTurf = true,
                    skipCooldown = true,
                })
            elseif sellCfg.requireGangForInfluence then
                exports['mrp_gangs']:AddTurfInfluence(src, turfId, 'drug_sale', {
                    amount = math.max(1, math.floor(inf / 2)),
                    skipTurfCheck = false,
                    allowOwnTurf = false,
                    skipCooldown = false,
                })
            end
            if zoneHeat[turfId] and zoneHeat[turfId] >= 55 then
                rollPolice(35, src, 'heat_spike')
            end
        end
    end

    if gang then
        MySQL.update.await('UPDATE fivempro_gangs SET reputation = reputation + 1 WHERE id = ?', { gang.gang_id })
    end

    if DrugPlayer then DrugPlayer.addSale(src, itemName, qty) end

    logAdmin(('SELL %sx%d $%s cid=%s turf=%s'):format(itemName, qty, price, Player.PlayerData.citizenid, tostring(turfId)))
    cb({
        ok = true,
        price = price,
        amount = qty,
        item = itemName,
        turfId = turfId,
        alertPolice = alertPolice,
        payoutLabel = payoutItemLabel(),
    })
end)

local function playerNearSupplyShop(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end
    local p = GetEntityCoords(ped)
    local maxD = (Config.InteractDistance or 2.5) + 3.0

    local prodShop = Config.SupplyShopNPC
    if prodShop and prodShop.enabled ~= false and prodShop.coords then
        local c = prodShop.coords
        if #(p - vector3(c.x, c.y, c.z)) <= (prodShop.maxDistance or maxD) then
            return true
        end
    end

    if Config.EnableDrugTestNPC and Config.DevHub then
        local hub = Config.DevHub.center or Config.DevHub.blipCoords
        if hub and #(p - hub) <= 55.0 then
            return true
        end
    end
    for _, key in ipairs({ 'TestSupplyShopNPC', 'TestNPC', 'FreeDrugShopNPC' }) do
        local cfg = Config[key]
        if cfg and cfg.coords and cfg.enabled ~= false then
            local c = cfg.coords
            if #(p - vector3(c.x, c.y, c.z)) <= maxD then
                return true
            end
        end
    end
    for _, st in ipairs(Config.Stations or {}) do
        if st.mode == 'weapon' and st.coords then
            if #(p - st.coords) <= (st.radius or 2.5) + 2.5 then
                return true
            end
        end
    end
    return false
end

local function getProductBuyer(buyerId)
    buyerId = tostring(buyerId or '')
    local cfg = Config.ProductBuyerNPCs and Config.ProductBuyerNPCs[buyerId]
    if not cfg or cfg.enabled == false then return nil end
    return cfg
end

local function playerNearProductBuyer(src, buyerId)
    local cfg = getProductBuyer(buyerId)
    if not cfg or not cfg.coords then return false end
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end
    local p = GetEntityCoords(ped)
    local c = cfg.coords
    return #(p - vector3(c.x, c.y, c.z)) <= (cfg.maxDistance or 3.5) + 1.0
end

local function findMaterialShopRow(itemName)
    itemName = tostring(itemName or ''):lower()
    for _, row in ipairs((Config.MaterialShop and Config.MaterialShop.items) or {}) do
        if row.name and row.name:lower() == itemName then
            return row
        end
    end
end

local function registerMaterialShop()
    if GetResourceState('qb-inventory') ~= 'started' then return false end
    local cfg = Config.MaterialShop
    if not cfg or not cfg.name or not cfg.items then return false end
    local validItems = {}
    for _, row in ipairs(cfg.items) do
        if resolveSharedItem(row.name) then
            validItems[#validItems + 1] = row
        else
            logAdmin(('MaterialShop praleidžia nežinomą item: %s'):format(tostring(row.name)))
        end
    end
    if #validItems == 0 then return false end
    local maxSlot = 0
    for _, row in ipairs(validItems) do
        maxSlot = math.max(maxSlot, tonumber(row.slot) or 0)
    end
    exports['qb-inventory']:CreateShop({
        name = cfg.name,
        label = cfg.label or 'Reikmenys',
        slots = math.max(maxSlot, #validItems),
        items = validItems,
    })
    return true
end

CreateThread(function()
    Wait(1500)
    registerMaterialShop()
end)

AddEventHandler('onResourceStart', function(res)
    if res ~= 'qb-inventory' and res ~= GetCurrentResourceName() then return end
    CreateThread(function()
        Wait(800)
        registerMaterialShop()
    end)
end)

local function tryOpenMaterialShop(src)
    if not playerNearSupplyShop(src) then
        return false, 'Per toli nuo parduotuvės.'
    end
    if GetResourceState('qb-inventory') ~= 'started' then
        return false, 'Inventoriaus sistema nepasiekiama.'
    end
    if not registerMaterialShop() then
        return false, 'Parduotuvė nepasiekiama (prekės neįkeltos).'
    end
    local opened = exports['qb-inventory']:OpenShop(src, Config.MaterialShop.name)
    if not opened then
        return false, 'Nepavyko atidaryti parduotuvės.'
    end
    return true
end

RegisterNetEvent('mrp_drugs:server:openMaterialShop', function()
    local src = source
    local ok, reason = tryOpenMaterialShop(src)
    if not ok then
        TriggerClientEvent('QBCore:Notify', src, reason or 'Parduotuvė neprieinama.', 'error')
    end
end)

QBCore.Functions.CreateCallback('mrp_drugs:server:openMaterialShop', function(src, cb)
    local ok, reason = tryOpenMaterialShop(src)
    cb({ ok = ok, reason = reason })
end)

QBCore.Functions.CreateCallback('mrp_drugs:server:buyMaterial', function(src, cb, itemName, amount)
    if not playerNearSupplyShop(src) then
        return cb({ ok = false, reason = 'Per toli nuo parduotuvės.' })
    end

    amount = math.max(1, math.min(50, math.floor(tonumber(amount) or 1)))
    itemName = tostring(itemName or ''):lower()
    local row = findMaterialShopRow(itemName)
    if not row then
        return cb({ ok = false, reason = 'Prekė nerasta.' })
    end

    local shared = resolveSharedItem(itemName)
    if not shared then
        return cb({ ok = false, reason = 'Daiktas neįregistruotas serveryje.' })
    end

    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return cb({ ok = false }) end

    local canAdd, reason = exports['qb-inventory']:CanAddItem(src, itemName, amount)
    if not canAdd then
        local msg = 'Negali pasiimti daikto.'
        if reason == 'weight' then
            msg = 'Per sunku inventoriui.'
        elseif reason == 'slots' then
            msg = 'Inventorius pilnas.'
        end
        return cb({ ok = false, reason = msg })
    end

    local price = (tonumber(row.price) or 0) * amount
    if price <= 0 then
        return cb({ ok = false, reason = 'Netinkama kaina.' })
    end

    local cash = Player.PlayerData.money.cash or 0
    local bank = Player.PlayerData.money.bank or 0
    local paidWith
    if cash >= price then
        paidWith = 'cash'
        Player.Functions.RemoveMoney('cash', price, 'fivempro-drugs-supply')
    elseif bank >= price then
        paidWith = 'bank'
        Player.Functions.RemoveMoney('bank', price, 'fivempro-drugs-supply')
    else
        return cb({ ok = false, reason = 'Nepakanka pinigų (grynieji arba bankas).' })
    end

    local added = exports['qb-inventory']:AddItem(src, itemName, amount, nil, {}, 'fivempro-drugs-supply')
    if not added then
        Player.Functions.AddMoney(paidWith, price, 'fivempro-drugs-supply-refund')
        return cb({ ok = false, reason = 'Nepavyko pridėti į inventorių.' })
    end

    exports['qb-inventory']:SaveInventory(src)
    local refreshed = QBCore.Functions.GetPlayer(src)
    local items = refreshed and refreshed.PlayerData.items or Player.PlayerData.items

    TriggerClientEvent('qb-inventory:client:ItemBox', src, shared, 'add', amount)
    cb({ ok = true, item = itemName, amount = amount, label = shared.label })
end)

RegisterNetEvent('mrp_drugs:server:testGiveKit', function(kitKey)
    if not Config.EnableDrugTestNPC then return end
    local src = source
    local kit = Config.TestKits and Config.TestKits[kitKey]
    if not kit then return end
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    for item, amount in pairs(kit) do
        if not Player.Functions.AddItem(item, amount) then
            return TriggerClientEvent('QBCore:Notify', src, 'Nepavyko duoti: ' .. item, 'error')
        end
    end
    TriggerClientEvent('QBCore:Notify', src, 'Test rinkinys išduotas.', 'success')
end)

RegisterNetEvent('mrp_drugs:server:testTriggerAlert', function()
    if not Config.EnableDrugTestNPC then return end
    policeAlert(source, 'sell_burst', 'test')
    TriggerClientEvent('QBCore:Notify', source, 'Test policijos alert išsiųstas.', 'primary')
end)

--- Taiko konfigūruojamą kainų svyravimą bazinei kainai (serverio pusėje).
local function applyPriceFluctuation(base)
    base = tonumber(base) or 0
    local f = Config.Economy and Config.Economy.priceFluctuation
    if not f or f.enabled == false or base <= 0 then return base end
    local minPct = tonumber(f.minPct) or 100
    local maxPct = tonumber(f.maxPct) or 100
    if maxPct < minPct then minPct, maxPct = maxPct, minPct end
    local pct = math.random(minPct, maxPct)
    local price = base * (pct / 100.0)
    local roundTo = tonumber(f.roundTo) or 1
    if roundTo > 1 then
        price = math.floor((price / roundTo) + 0.5) * roundTo
    else
        price = math.floor(price + 0.5)
    end
    return math.max(1, price)
end

local function processProductSell(src, buyerId)
    buyerId = tostring(buyerId or '')
    if not playerNearProductBuyer(src, buyerId) then
        TriggerClientEvent('QBCore:Notify', src, 'Per toli nuo supirkėjo.', 'error')
        return
    end
    local cfg = getProductBuyer(buyerId)
    if not cfg then return end
    local prices = cfg.prices or {}
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local total = 0
    local sold = 0
    local toSell = {}
    for itemName, price in pairs(prices) do
        itemName = tostring(itemName or ''):lower()
        local base = tonumber(price) or 0
        if base > 0 and Config.IsPackagedDrugItem(itemName) then
            local data = Player.Functions.GetItemByName(itemName)
            local amt = data and (tonumber(data.amount) or tonumber(data.count) or 0) or 0
            if amt > 0 then
                -- Svyravimas vienam vienetui (bendra suma × dabartinė rinkos kaina).
                local unit = applyPriceFluctuation(base)
                toSell[#toSell + 1] = { name = itemName, amount = amt }
                total = total + (unit * amt)
                sold = sold + amt
            end
        end
    end

    if total <= 0 then
        TriggerClientEvent('QBCore:Notify', src, 'Neturi supakuotų produktų, kuriuos šis supirkėjas priima.', 'error')
        return
    end

    local payoutItem = tostring((Config.Sell or {}).payoutItem or 'markedbills'):lower()
    if (Config.Sell or {}).payoutFallbackCash == false and GetResourceState('qb-inventory') == 'started' then
        local canAdd = exports['qb-inventory']:CanAddItem(src, payoutItem, 1)
        if not canAdd then
            TriggerClientEvent('QBCore:Notify', src, 'Inventorius pilnas — nėra vietos nešvariems pinigams.', 'error')
            return
        end
    end

    for _, row in ipairs(toSell) do
        if not Player.Functions.RemoveItem(row.name, row.amount, false) then
            TriggerClientEvent('QBCore:Notify', src, 'Nepavyko paimti produktų iš inventoriaus.', 'error')
            return
        end
    end

    if not giveDrugSalePayout(src, Player, total, ('fivempro-drugs-buyer-%s'):format(buyerId)) then
        for _, row in ipairs(toSell) do
            Player.Functions.AddItem(row.name, row.amount)
        end
        TriggerClientEvent('QBCore:Notify', src, 'Inventorius pilnas — nėra vietos nešvariems pinigams.', 'error')
        return
    end

    -- Narkotikų progresija: realus parduotų galutinių produktų kiekis (visi vnt.).
    if DrugPlayer then
        for _, row in ipairs(toSell) do
            DrugPlayer.addSale(src, row.name, row.amount)
        end
    end

    TriggerClientEvent('QBCore:Notify', src, ('Parduota %s vnt. · $%s (%s)'):format(sold, total, payoutItemLabel()), 'success')
end

RegisterNetEvent('mrp_drugs:server:sellProductAll', function(buyerId)
    processProductSell(source, buyerId)
end)

RegisterNetEvent('mrp_drugs:server:sellAlcoholAll', function()
    processProductSell(source, 'alcohol')
end)

local mushroomPicked = {}
local mushroomPlayerCd = {}

local function getMushroomField(id)
    for _, field in ipairs(Config.MushroomFields or {}) do
        if field.id == id then return field end
    end
    for _, field in ipairs(Config.CocaFields or {}) do
        if field.id == id then return field end
    end
    for _, field in ipairs(Config.PoppyFields or {}) do
        if field.id == id then return field end
    end
end

local function mushroomSpawnCoord(field, index)
    local total = math.max(1, tonumber(field.spawnCount) or 12)
    local radius = tonumber(field.radius) or 35.0
    local angle = ((index - 1) / total) * (math.pi * 2.0)
    local ring = 0.32 + (((index - 1) % 4) * 0.16)
    local dist = radius * ring
    local x = field.center.x + math.cos(angle) * dist
    local y = field.center.y + math.sin(angle) * dist
    return vector3(x, y, field.center.z)
end

RegisterNetEvent('mrp_drugs:server:pickMushroom', function(fieldId, spawnIndex, px, py, pz)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    fieldId = tostring(fieldId or '')
    spawnIndex = tonumber(spawnIndex)
    if fieldId == '' or not spawnIndex then return end

    local field = getMushroomField(fieldId)
    if not field then return end

    local key = ('%s:%s'):format(fieldId, spawnIndex)
    local now = os.time()
    if mushroomPicked[key] and mushroomPicked[key] > now then
        TriggerClientEvent('QBCore:Notify', src, 'Čia jau nieko nėra.', 'error')
        return
    end

    local pcoords = vector3(tonumber(px) or 0.0, tonumber(py) or 0.0, tonumber(pz) or 0.0)
    local spawnCoords = mushroomSpawnCoord(field, spawnIndex)
    local maxDist = (tonumber(field.pickDistance) or 2.4) + 1.5
    if #(pcoords - spawnCoords) > maxDist then
        TriggerClientEvent('QBCore:Notify', src, 'Per toli.', 'error')
        return
    end

    if #(pcoords - field.center) > (tonumber(field.radius) or 40.0) + 5.0 then
        TriggerClientEvent('QBCore:Notify', src, 'Ne rinkimo zonoje.', 'error')
        return
    end

    local playerCd = tonumber(field.playerCooldownSec) or 3
    if mushroomPlayerCd[src] and (now - mushroomPlayerCd[src]) < playerCd then return end
    mushroomPlayerCd[src] = now

    local item = field.item or 'mushroom_raw'
    local amtMin = math.max(1, tonumber(field.amountMin) or 1)
    local amtMax = math.max(amtMin, tonumber(field.amountMax) or 2)
    local amount = math.random(amtMin, amtMax)

    if not Player.Functions.AddItem(item, amount) then
        TriggerClientEvent('QBCore:Notify', src, 'Inventorius pilnas.', 'error')
        return
    end

    local respawn = math.max(30, tonumber(field.respawnSec) or 100)
    mushroomPicked[key] = now + respawn

    local itemData = QBCore.Shared.Items[item]
    TriggerClientEvent('inventory:client:ItemBox', src, itemData, 'add', amount)
    TriggerClientEvent('QBCore:Notify', src, ('Surinkta %sx %s'):format(amount, itemData and itemData.label or item), 'success')
    TriggerClientEvent('mrp_drugs:client:mushroomDespawn', -1, fieldId, spawnIndex)

    SetTimeout(respawn * 1000, function()
        mushroomPicked[key] = nil
        TriggerClientEvent('mrp_drugs:client:mushroomRespawn', -1, fieldId, spawnIndex)
    end)
end)

-- Kanapių auginimas — žaidėjo pastatyti vazonai (dinaminės koordinatės)
local weedPlants = {}
local weedPlayerCd = {}
local weedPlantSeq = 0

local function weedGrowCfg()
    return Config.WeedGrow or {}
end

local function clampQuality(cfg, value)
    cfg = cfg or weedGrowCfg()
    local minQ = tonumber(cfg.qualityMin) or 20
    local maxQ = tonumber(cfg.qualityMax) or 100
    return math.max(minQ, math.min(maxQ, math.floor(tonumber(value) or minQ)))
end

local function computePlantMoisture(cfg, plant)
    if not plant or not plant.plantedAt then return 0 end
    cfg = cfg or weedGrowCfg()
    local moisture = tonumber(plant.moisture)
    if moisture == nil then moisture = tonumber(cfg.moistureStart) or 48 end
    local elapsed = os.time() - (tonumber(plant.lastWaterAt) or tonumber(plant.plantedAt) or os.time())
    local decay = math.floor(elapsed / 90)
    return math.max(0, math.min(100, moisture - decay))
end

local function computeWeedStage(cfg, plant)
    if not plant or not plant.plantedAt then return 0 end
    local bonus = (tonumber(plant.watered) or 0) * (tonumber(cfg.waterBonusSec) or 40)
    local elapsed = os.time() - tonumber(plant.plantedAt) + bonus
    if elapsed >= (tonumber(cfg.stage3Sec) or 240) then return 3 end
    if elapsed >= (tonumber(cfg.stage2Sec) or 90) then return 2 end
    return 1
end

local function computePlantStatus(cfg, plant)
    if not plant then return 'empty' end
    if not plant.soiled then return 'empty' end
    if not plant.plantedAt then return 'soiled' end
    local stage = computeWeedStage(cfg, plant)
    if stage >= 3 then return 'ready' end
    local moisture = computePlantMoisture(cfg, plant)
    local dryThreshold = tonumber(cfg.moistureDryThreshold) or 28
    if moisture < dryThreshold then return 'dry_needed' end
    return 'growing'
end

local function plantStatusLabel(status)
    local labels = {
        empty = 'Tuščia',
        soiled = 'Paruošta sodinimui',
        growing = 'Auga',
        dry_needed = 'Reikia laistyti',
        ready = 'Paruošta derliui',
    }
    return labels[status] or status
end

local function newWeedPlantId()
    weedPlantSeq = weedPlantSeq + 1
    return ('wp_%s_%s'):format(weedPlantSeq, os.time())
end

local function weedCoords(entry)
    return vector3(tonumber(entry.x) or 0.0, tonumber(entry.y) or 0.0, tonumber(entry.z) or 0.0)
end

local function weedGrowthRemaining(cfg, plant)
    if not plant or not plant.plantedAt then return 0 end
    local bonus = (tonumber(plant.watered) or 0) * (tonumber(cfg.waterBonusSec) or 40)
    local elapsed = os.time() - tonumber(plant.plantedAt) + bonus
    return math.max(0, (tonumber(cfg.stage3Sec) or 240) - elapsed)
end

local function canWaterPlantNow(cfg, plant)
    if not plant or not plant.plantedAt then return false, 0 end
    if (plant.watered or 0) >= (tonumber(cfg.maxWaters) or 4) then return false, 0 end
    local cd = tonumber(cfg.waterCooldownSec) or 120
    local last = tonumber(plant.lastWaterAt) or 0
    local left = math.max(0, (last + cd) - os.time())
    return left <= 0, left
end

local function findWateringCan(Player)
    local itemName = (weedGrowCfg().waterCanItem or 'watering_can')
    for slot, item in pairs(Player.PlayerData.items or {}) do
        if item and item.name == itemName then
            return item, slot
        end
    end
end

local function getCanWater(item, cfg)
    cfg = cfg or weedGrowCfg()
    local cap = tonumber(cfg.waterCanCapacity) or 100
    local w = item.info and item.info.water
    if w == nil then w = item.water end
    if w == nil then return cap end
    return math.max(0, math.min(cap, tonumber(w) or 0))
end

local function setCanWater(src, slot, amount, cfg)
    cfg = cfg or weedGrowCfg()
    local cap = tonumber(cfg.waterCanCapacity) or 100
    amount = math.max(0, math.min(cap, math.floor(tonumber(amount) or 0)))
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player or not slot then return amount end
    local item = Player.PlayerData.items[tonumber(slot)]
    if not item then return amount end
    item.info = item.info or {}
    item.info.water = amount
    item.info.description = ('Vanduo: %d/%d'):format(amount, cap)
    Player.PlayerData.items[item.slot] = item
    Player.Functions.SetPlayerData('items', Player.PlayerData.items)
    TriggerClientEvent('qb-inventory:client:updateInventory', src, Player.PlayerData.items)
    return amount
end

local function canUseWaterFromCan(Player)
    local cfg = weedGrowCfg()
    local item = findWateringCan(Player)
    if not item then return false, 'Reikia laistytuvo.' end
    local need = tonumber(cfg.waterPerUse) or 8
    local current = getCanWater(item, cfg)
    if current < need then
        return false, ('Laistytuve liko %d/%d vandens — papildyk prie ežero ar jūros.'):format(current, cfg.waterCanCapacity or 100)
    end
    return true
end

local function useWaterFromCan(src, Player)
    local ok, err = canUseWaterFromCan(Player)
    if not ok then return false, err end
    local cfg = weedGrowCfg()
    local item, slot = findWateringCan(Player)
    local need = tonumber(cfg.waterPerUse) or 8
    local current = getCanWater(item, cfg)
    setCanWater(src, slot, current - need, cfg)
    return true
end

local function plantPayload(cfg, plant)
    local canW, waterCd = canWaterPlantNow(cfg, plant)
    local remaining = weedGrowthRemaining(cfg, plant)
    local status = computePlantStatus(cfg, plant)
    local quality = clampQuality(cfg, plant.quality or cfg.qualityStart or 72)
    local moisture = computePlantMoisture(cfg, plant)
    return {
        x = plant.x,
        y = plant.y,
        z = plant.z,
        heading = plant.heading or 0.0,
        soiled = plant.soiled == true,
        soilLevel = tonumber(plant.soilLevel) or 0,
        plantedAt = plant.plantedAt,
        watered = plant.watered or 0,
        lastWaterAt = plant.lastWaterAt or 0,
        stage = computeWeedStage(cfg, plant),
        growRemaining = remaining,
        canWater = canW,
        waterCooldownLeft = waterCd,
        watersLeft = math.max(0, (tonumber(cfg.maxWaters) or 4) - (plant.watered or 0)),
        quality = quality,
        moisture = moisture,
        status = status,
        statusLabel = plantStatusLabel(status),
    }
end

local function countPlayerWeedPots(citizenid)
    local count = 0
    for _, plant in pairs(weedPlants) do
        if plant.owner == citizenid then
            count = count + 1
        end
    end
    return count
end

local function playerNearWeedPlant(src, plant, px, py, pz)
    local ped = GetPlayerPed(src)
    if ped == 0 then return false end
    local cfg = weedGrowCfg()
    local pcoords = vector3(tonumber(px) or 0.0, tonumber(py) or 0.0, tonumber(pz) or 0.0)
    if #(pcoords - vector3(0.0, 0.0, 0.0)) < 0.01 then
        pcoords = GetEntityCoords(ped)
    end
    local maxDist = (tonumber(cfg.pickDistance) or 2.2) + 1.8
    return #(pcoords - weedCoords(plant)) <= maxDist
end

local function canPlacePotAt(x, y, z, ignoreId)
    local cfg = weedGrowCfg()
    local pos = vector3(x, y, z)
    local minDist = tonumber(cfg.minPotDistance) or 2.0
    for id, plant in pairs(weedPlants) do
        if id ~= ignoreId and #(pos - weedCoords(plant)) < minDist then
            return false
        end
    end
    return true
end

QBCore.Functions.CreateCallback('mrp_drugs:server:syncWeedPlants', function(_, cb)
    local cfg = weedGrowCfg()
    local out = {}
    for id, plant in pairs(weedPlants) do
        out[id] = plantPayload(cfg, plant)
    end
    cb(out)
end)

QBCore.Functions.CreateCallback('mrp_drugs:server:canAddSoilWeed', function(src, cb, plantId)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return cb(false, 'Klaida.') end
    plantId = tostring(plantId or '')
    local plant = weedPlants[plantId]
    if not plant then return cb(false, 'Vazonas nerastas.') end
    if plant.soiled then return cb(false, 'Žemė jau supilta.') end
    if plant.plantedAt then return cb(false, 'Čia jau auga.') end
    local cfg = weedGrowCfg()
    local soilItem = cfg.soilItem or 'weed_nutrition'
    local soil = Player.Functions.GetItemByName(soilItem)
    if not soil or (soil.amount or 0) < 1 then
        return cb(false, 'Reikia substrato maišo (trąšos).')
    end
    if not playerNearWeedPlant(src, plant) then
        return cb(false, 'Per toli.')
    end
    cb(true)
end)

QBCore.Functions.CreateCallback('mrp_drugs:server:canPlantWeed', function(src, cb, plantId)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return cb(false, 'Klaida.') end
    plantId = tostring(plantId or '')
    local plant = weedPlants[plantId]
    if not plant then return cb(false, 'Vazonas nerastas.') end
    if not plant.soiled then return cb(false, 'Pirma supilk substratą.') end
    if plant.plantedAt then return cb(false, 'Čia jau auga.') end
    local cfg = weedGrowCfg()
    local seedItem = cfg.seedItem or 'weed_seed'
    local seed = Player.Functions.GetItemByName(seedItem)
    if not seed or (seed.amount or 0) < 1 then
        return cb(false, 'Reikia kanapių sėklos.')
    end
    if not playerNearWeedPlant(src, plant) then
        return cb(false, 'Per toli.')
    end
    cb(true)
end)

QBCore.Functions.CreateCallback('mrp_drugs:server:canHarvestWeed', function(src, cb, plantId)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return cb(false, 'Klaida.') end
    plantId = tostring(plantId or '')
    local plant = weedPlants[plantId]
    if not plant or not plant.plantedAt then return cb(false, 'Čia nieko neauga.') end
    local cfg = weedGrowCfg()
    if computeWeedStage(cfg, plant) < 3 then
        return cb(false, 'Augalas dar nebrandus.')
    end
    local scissors = cfg.scissorsItem or 'trimming_scissors'
    local gloves = cfg.glovesItem or 'gloves'
    if not Player.Functions.GetItemByName(scissors) then
        return cb(false, 'Reikia lapų kirpimo žirklčių.')
    end
    if not Player.Functions.GetItemByName(gloves) then
        return cb(false, 'Reikia pirštinių.')
    end
    if not playerNearWeedPlant(src, plant) then
        return cb(false, 'Per toli.')
    end
    cb(true)
end)

QBCore.Functions.CreateCallback('mrp_drugs:server:canWaterWeed', function(src, cb, plantId)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return cb(false, 'Klaida.') end
    plantId = tostring(plantId or '')
    local plant = weedPlants[plantId]
    local cfg = weedGrowCfg()
    if not plant or not plant.plantedAt then return cb(false, 'Čia nieko neauga.') end
    if computeWeedStage(cfg, plant) >= 3 then
        return cb(false, 'Augalas jau brandus — skink lapus.')
    end
    if (plant.watered or 0) >= (tonumber(cfg.maxWaters) or 4) then
        return cb(false, 'Augalas jau pakankamai palaistas.')
    end
    local canW, cdLeft = canWaterPlantNow(cfg, plant)
    if not canW then
        return cb(false, ('Palauk %s s prieš kitą laistymą.'):format(cdLeft))
    end
    if not playerNearWeedPlant(src, plant) then
        return cb(false, 'Per toli.')
    end
    local ok, err = canUseWaterFromCan(Player)
    if not ok then return cb(false, err) end
    cb(true)
end)

QBCore.Functions.CreateCallback('mrp_drugs:server:canRefillWateringCan', function(src, cb)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return cb(false, 'Klaida.') end
    local cfg = weedGrowCfg()
    local canItem = findWateringCan(Player)
    if not canItem then
        return cb(false, 'Reikia laistytuvo inventoriuje.')
    end
    local cap = tonumber(cfg.waterCanCapacity) or 100
    local current = getCanWater(canItem, cfg)
    if current >= cap then
        return cb(false, ('Laistytuvas jau pilnas (%d/%d).'):format(current, cap))
    end
    cb(true)
end)

RegisterNetEvent('mrp_drugs:server:placeWeedPot', function(x, y, z, heading)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    local cfg = weedGrowCfg()
    x, y, z = tonumber(x), tonumber(y), tonumber(z)
    heading = tonumber(heading) or 0.0
    if not x or not y or not z then return end

    local ped = GetPlayerPed(src)
    if ped == 0 then return end
    if #(vector3(x, y, z) - GetEntityCoords(ped)) > 4.0 then
        return TriggerClientEvent('QBCore:Notify', src, 'Per toli.', 'error')
    end

    local potItem = cfg.potItem or 'grow_pot'
    if not exports['qb-inventory']:RemoveItem(src, potItem, 1, false, 'mrp_drugs:placeWeedPot') then
        return TriggerClientEvent('QBCore:Notify', src, 'Reikia augimo vazono.', 'error')
    end

    local citizenid = Player.PlayerData.citizenid
    if countPlayerWeedPots(citizenid) >= (tonumber(cfg.maxPotsPerPlayer) or 8) then
        exports['qb-inventory']:AddItem(src, potItem, 1, false, false, 'mrp_drugs:placeWeedPot-rollback')
        return TriggerClientEvent('QBCore:Notify', src, 'Per daug tavo vazonų.', 'error')
    end

    local total = 0
    for _ in pairs(weedPlants) do total = total + 1 end
    if total >= (tonumber(cfg.maxPotsGlobal) or 250) then
        exports['qb-inventory']:AddItem(src, potItem, 1, false, false, 'mrp_drugs:placeWeedPot-rollback')
        return TriggerClientEvent('QBCore:Notify', src, 'Serveryje per daug vazonų.', 'error')
    end

    if not canPlacePotAt(x, y, z) then
        exports['qb-inventory']:AddItem(src, potItem, 1, false, false, 'mrp_drugs:placeWeedPot-rollback')
        return TriggerClientEvent('QBCore:Notify', src, 'Per arti kito vazono.', 'error')
    end

    local plantId = newWeedPlantId()
    weedPlants[plantId] = {
        x = x, y = y, z = z,
        heading = heading,
        owner = citizenid,
        soiled = false,
        soilLevel = 0,
        quality = tonumber(cfg.qualityStart) or 72,
        moisture = tonumber(cfg.moistureStart) or 48,
        watered = 0,
        lastWaterAt = 0,
    }
    TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[potItem], 'remove', 1)
    TriggerClientEvent('QBCore:Notify', src, 'Vazonas pastatytas — supilk substratą.', 'success')
    TriggerClientEvent('mrp_drugs:client:weedPlantUpdate', -1, plantId, plantPayload(cfg, weedPlants[plantId]))
end)

RegisterNetEvent('mrp_drugs:server:addSoilWeed', function(plantId, soilScore)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    plantId = tostring(plantId or '')
    local plant = weedPlants[plantId]
    local cfg = weedGrowCfg()
    if not plant or plant.soiled or plant.plantedAt then return end
    if not playerNearWeedPlant(src, plant) then
        return TriggerClientEvent('QBCore:Notify', src, 'Per toli.', 'error')
    end
    local soilItem = cfg.soilItem or 'weed_nutrition'
    if not exports['qb-inventory']:RemoveItem(src, soilItem, 1, false, 'mrp_drugs:addSoilWeed') then
        return TriggerClientEvent('QBCore:Notify', src, 'Reikia substrato maišo.', 'error')
    end
    local score = math.max(0, math.min(100, tonumber(soilScore) or 70))
    plant.soiled = true
    plant.soilLevel = score
    local bonus = math.floor((score - 70) / 4)
    plant.quality = clampQuality(cfg, (plant.quality or cfg.qualityStart or 72) + bonus)
    TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[soilItem], 'remove', 1)
    TriggerClientEvent('QBCore:Notify', src, 'Substratas supiltas — sodink sėklas.', 'success')
    TriggerClientEvent('mrp_drugs:client:weedPlantUpdate', -1, plantId, plantPayload(cfg, plant))
end)

RegisterNetEvent('mrp_drugs:server:plantWeed', function(plantId, px, py, pz, seedScore)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    plantId = tostring(plantId or '')
    local plant = weedPlants[plantId]
    local cfg = weedGrowCfg()
    if not plant or plant.plantedAt then return end
    if not plant.soiled then
        return TriggerClientEvent('QBCore:Notify', src, 'Pirma supilk substratą.', 'error')
    end
    if not playerNearWeedPlant(src, plant, px, py, pz) then
        return TriggerClientEvent('QBCore:Notify', src, 'Per toli.', 'error')
    end
    local seedItem = cfg.seedItem or 'weed_seed'
    if not exports['qb-inventory']:RemoveItem(src, seedItem, 1, false, 'mrp_drugs:plantWeed') then
        return TriggerClientEvent('QBCore:Notify', src, 'Reikia kanapių sėklos.', 'error')
    end
    local score = math.max(0, math.min(100, tonumber(seedScore) or 75))
    plant.plantedAt = os.time()
    plant.watered = 0
    plant.lastWaterAt = 0
    plant.moisture = tonumber(cfg.moistureStart) or 48
    local bonus = math.floor((score - 75) / 5)
    plant.quality = clampQuality(cfg, (plant.quality or cfg.qualityStart or 72) + bonus)
    TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[seedItem], 'remove', 1)
    TriggerClientEvent('QBCore:Notify', src, 'Sėkla pasodinta — laistyklės laistytuvu.', 'success')
    TriggerClientEvent('mrp_drugs:client:weedPlantUpdate', -1, plantId, plantPayload(cfg, plant))
end)

RegisterNetEvent('mrp_drugs:server:waterWeed', function(plantId, moistureHit, waterScore)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    plantId = tostring(plantId or '')
    local plant = weedPlants[plantId]
    local cfg = weedGrowCfg()
    if not plant or not plant.plantedAt then return end
    if computeWeedStage(cfg, plant) >= 3 then
        return TriggerClientEvent('QBCore:Notify', src, 'Augalas jau brandus — skink lapus.', 'primary')
    end
    if (plant.watered or 0) >= (tonumber(cfg.maxWaters) or 4) then
        return TriggerClientEvent('QBCore:Notify', src, 'Augalas jau pakankamai palaistas.', 'error')
    end
    local canW, cdLeft = canWaterPlantNow(cfg, plant)
    if not canW then
        return TriggerClientEvent('QBCore:Notify', src, ('Palauk %s s prieš kitą laistymą.'):format(cdLeft), 'error')
    end
    if not playerNearWeedPlant(src, plant) then
        return TriggerClientEvent('QBCore:Notify', src, 'Per toli.', 'error')
    end
    local ok, err = useWaterFromCan(src, Player)
    if not ok then
        return TriggerClientEvent('QBCore:Notify', src, err or 'Nepakanka vandens.', 'error')
    end
    local hit = math.max(0, math.min(100, tonumber(moistureHit) or 55))
    local optMin = tonumber(cfg.moistureOptimalMin) or 42
    local optMax = tonumber(cfg.moistureOptimalMax) or 68
    local quality = plant.quality or tonumber(cfg.qualityStart) or 72
    if hit >= optMin and hit <= optMax then
        quality = quality + 4
    elseif hit < optMin then
        quality = quality - 2
    else
        quality = quality - 5
    end
    local score = tonumber(waterScore)
    if score then
        quality = quality + math.floor((score - 70) / 8)
    end
    plant.quality = clampQuality(cfg, quality)
    plant.moisture = hit
    plant.watered = (plant.watered or 0) + 1
    plant.lastWaterAt = os.time()
    TriggerClientEvent('QBCore:Notify', src, ('Augalas palaistas · drėgmė %d%% · kokybė %d%%'):format(hit, plant.quality), 'success')
    TriggerClientEvent('mrp_drugs:client:weedPlantUpdate', -1, plantId, plantPayload(cfg, plant))
end)

local function refillWateringCanFromNatural(src)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    local cfg = weedGrowCfg()
    local canItem, canSlot = findWateringCan(Player)
    if not canItem or not canSlot then
        return TriggerClientEvent('QBCore:Notify', src, 'Reikia laistytuvo inventoriuje.', 'error')
    end
    local cap = tonumber(cfg.waterCanCapacity) or 100
    local current = getCanWater(canItem, cfg)
    if current >= cap then
        return TriggerClientEvent('QBCore:Notify', src, ('Laistytuvas jau pilnas (%d/%d).'):format(current, cap), 'error')
    end
    setCanWater(src, canSlot, cap, cfg)
    TriggerClientEvent('QBCore:Notify', src, ('Laistytuvas pripildytas: %d/%d vandens.'):format(cap, cap), 'success')
end

RegisterNetEvent('mrp_drugs:server:refillWateringCanFromWater', function()
    refillWateringCanFromNatural(source)
end)

RegisterNetEvent('mrp_drugs:server:harvestWeed', function(plantId, px, py, pz, harvestScore)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    plantId = tostring(plantId or '')
    local plant = weedPlants[plantId]
    local cfg = weedGrowCfg()
    if not plant or not plant.plantedAt then return end
    if computeWeedStage(cfg, plant) < 3 then
        return TriggerClientEvent('QBCore:Notify', src, 'Augalas dar nebrandus.', 'error')
    end
    if not playerNearWeedPlant(src, plant, px, py, pz) then
        return TriggerClientEvent('QBCore:Notify', src, 'Per toli.', 'error')
    end
    local scissors = cfg.scissorsItem or 'trimming_scissors'
    local gloves = cfg.glovesItem or 'gloves'
    if not Player.Functions.GetItemByName(scissors) then
        return TriggerClientEvent('QBCore:Notify', src, 'Reikia lapų kirpimo žirklčių.', 'error')
    end
    if not Player.Functions.GetItemByName(gloves) then
        return TriggerClientEvent('QBCore:Notify', src, 'Reikia pirštinių.', 'error')
    end
    local cd = tonumber(cfg.playerCooldownSec) or 3
    local now = os.time()
    if weedPlayerCd[src] and (now - weedPlayerCd[src]) < cd then return end
    weedPlayerCd[src] = now

    local item = cfg.harvestItem or 'weed_leaf'
    local quality = clampQuality(cfg, plant.quality or tonumber(cfg.qualityStart) or 72)
    local score = math.max(0, math.min(100, tonumber(harvestScore) or 75))
    local amtMin = math.max(1, tonumber(cfg.harvestMin) or 2)
    local amtMax = math.max(amtMin, tonumber(cfg.harvestMax) or 5)
    local qualityFactor = quality / 100
    local scoreFactor = score / 100
    local amount = math.floor(amtMin + (amtMax - amtMin) * qualityFactor * scoreFactor + 0.5)
    amount = math.max(amtMin, math.min(amtMax + 2, amount))

    if not Player.Functions.AddItem(item, amount) then
        return TriggerClientEvent('QBCore:Notify', src, 'Inventorius pilnas.', 'error')
    end

    weedPlants[plantId] = nil
    local itemData = QBCore.Shared.Items[item]
    TriggerClientEvent('inventory:client:ItemBox', src, itemData, 'add', amount)
    TriggerClientEvent('QBCore:Notify', src, ('Nuskinta %sx %s · kokybė %d%%'):format(amount, itemData and itemData.label or item, quality), 'success')
    TriggerClientEvent('mrp_drugs:client:weedPlantClear', -1, plantId)
end)

local function findWeedSupplyShopRow(itemName)
    itemName = tostring(itemName or ''):lower()
    for _, row in ipairs((Config.WeedSupplyShop and Config.WeedSupplyShop.items) or {}) do
        if row.name and row.name:lower() == itemName then
            return row
        end
    end
end

local function registerWeedSupplyShop()
    if GetResourceState('qb-inventory') ~= 'started' then return false end
    local cfg = Config.WeedSupplyShop
    if not cfg or not cfg.name or not cfg.items then return false end
    local validItems = {}
    for _, row in ipairs(cfg.items) do
        if resolveSharedItem(row.name) then
            validItems[#validItems + 1] = row
        else
            logAdmin(('WeedSupplyShop praleidžia nežinomą item: %s'):format(tostring(row.name)))
        end
    end
    if #validItems == 0 then return false end
    local maxSlot = 0
    for _, row in ipairs(validItems) do
        maxSlot = math.max(maxSlot, tonumber(row.slot) or 0)
    end
    exports['qb-inventory']:CreateShop({
        name = cfg.name,
        label = cfg.label or 'Kanapių reikmenys',
        slots = math.max(maxSlot, #validItems),
        items = validItems,
    })
    return true
end

local function playerNearWeedSupplyShop(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end
    local p = GetEntityCoords(ped)
    local cfg = Config.WeedSupplyShopNPC
    if not cfg or cfg.enabled == false or not cfg.coords then return false end
    local c = cfg.coords
    return #(p - vector3(c.x, c.y, c.z)) <= (cfg.maxDistance or (Config.InteractDistance or 2.5) + 3.0)
end

local function tryOpenWeedSupplyShop(src)
    if not playerNearWeedSupplyShop(src) then
        return false, 'Per toli nuo parduotuvės.'
    end
    if GetResourceState('qb-inventory') ~= 'started' then
        return false, 'Inventoriaus sistema nepasiekiama.'
    end
    if not registerWeedSupplyShop() then
        return false, 'Parduotuvė nepasiekiama (prekės neįkeltos).'
    end
    local opened = exports['qb-inventory']:OpenShop(src, Config.WeedSupplyShop.name)
    if not opened then
        return false, 'Nepavyko atidaryti parduotuvės.'
    end
    return true
end

RegisterNetEvent('mrp_drugs:server:openWeedSupplyShop', function()
    local src = source
    local ok, reason = tryOpenWeedSupplyShop(src)
    if not ok then
        TriggerClientEvent('QBCore:Notify', src, reason or 'Parduotuvė neprieinama.', 'error')
    end
end)

QBCore.Functions.CreateCallback('mrp_drugs:server:openWeedSupplyShop', function(src, cb)
    local ok, reason = tryOpenWeedSupplyShop(src)
    cb({ ok = ok, reason = reason })
end)

local function registerPrinterShop()
    if GetResourceState('qb-inventory') ~= 'started' then return false end
    local cfg = Config.PrinterShop
    if not cfg or not cfg.name or not cfg.items then return false end
    local validItems = {}
    for _, row in ipairs(cfg.items) do
        if resolveSharedItem(row.name) then
            validItems[#validItems + 1] = row
        else
            logAdmin(('PrinterShop praleidžia nežinomą item: %s'):format(tostring(row.name)))
        end
    end
    if #validItems == 0 then return false end
    local maxSlot = 0
    for _, row in ipairs(validItems) do
        maxSlot = math.max(maxSlot, tonumber(row.slot) or 0)
    end
    exports['qb-inventory']:CreateShop({
        name = cfg.name,
        label = cfg.label or '3D spausdintuvas',
        slots = math.max(maxSlot, #validItems),
        items = validItems,
    })
    return true
end

local function playerNearPrinterShop(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end
    local p = GetEntityCoords(ped)
    local cfg = Config.PrinterShopNPC
    if not cfg or cfg.enabled == false or not cfg.coords then return false end
    local c = cfg.coords
    return #(p - vector3(c.x, c.y, c.z)) <= (cfg.maxDistance or (Config.InteractDistance or 2.5) + 3.0)
end

local function tryOpenPrinterShop(src)
    if not playerNearPrinterShop(src) then
        return false, 'Per toli nuo parduotuvės.'
    end
    if GetResourceState('qb-inventory') ~= 'started' then
        return false, 'Inventoriaus sistema nepasiekiama.'
    end
    if not registerPrinterShop() then
        return false, 'Parduotuvė nepasiekiama (prekės neįkeltos).'
    end
    local opened = exports['qb-inventory']:OpenShop(src, Config.PrinterShop.name)
    if not opened then
        return false, 'Nepavyko atidaryti parduotuvės.'
    end
    return true
end

RegisterNetEvent('mrp_drugs:server:openPrinterShop', function()
    local src = source
    local ok, reason = tryOpenPrinterShop(src)
    if not ok then
        TriggerClientEvent('QBCore:Notify', src, reason or 'Parduotuvė neprieinama.', 'error')
    end
end)

QBCore.Functions.CreateCallback('mrp_drugs:server:openPrinterShop', function(src, cb)
    local ok, reason = tryOpenPrinterShop(src)
    cb({ ok = ok, reason = reason })
end)

local function registerFreeDrugShop()
    if GetResourceState('qb-inventory') ~= 'started' then return false end
    local cfg = Config.FreeDrugShop
    local npc = Config.FreeDrugShopNPC
    if not cfg or not cfg.name or not cfg.items or not npc or npc.enabled == false then return false end
    local validItems = {}
    for _, row in ipairs(cfg.items) do
        if resolveSharedItem(row.name) then
            validItems[#validItems + 1] = row
        else
            logAdmin(('FreeDrugShop praleidžia nežinomą item: %s'):format(tostring(row.name)))
        end
    end
    if #validItems == 0 then return false end
    local maxSlot = 0
    for _, row in ipairs(validItems) do
        maxSlot = math.max(maxSlot, tonumber(row.slot) or 0)
    end
    local shopCoords = npc.coords and vector3(npc.coords.x, npc.coords.y, npc.coords.z) or nil
    exports['qb-inventory']:CreateShop({
        name = cfg.name,
        label = cfg.label or 'Nemokami narkotikai (test)',
        coords = shopCoords,
        slots = math.max(maxSlot, #validItems),
        items = validItems,
    })
    return true
end

local function playerNearFreeDrugShop(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end
    local p = GetEntityCoords(ped)
    local cfg = Config.FreeDrugShopNPC
    if not cfg or cfg.enabled == false or not cfg.coords then return false end
    local c = cfg.coords
    return #(p - vector3(c.x, c.y, c.z)) <= (cfg.maxDistance or (Config.InteractDistance or 2.5) + 3.0)
end

local function tryOpenFreeDrugShop(src)
    if not playerNearFreeDrugShop(src) then
        return false, 'Per toli nuo parduotuvės.'
    end
    local npc = Config.FreeDrugShopNPC
    if npc and npc.unlockAllLevels and DrugPlayer and DrugPlayer.unlockAllLevels then
        local ok, changed = DrugPlayer.unlockAllLevels(src, 3)
        if ok and changed then
            TriggerClientEvent('QBCore:Notify', src, 'Test režimas: atrakinti visi gamybos lygiai (L1–L3).', 'success')
        end
    end
    if GetResourceState('qb-inventory') ~= 'started' then
        return false, 'Inventoriaus sistema nepasiekiama.'
    end
    if not registerFreeDrugShop() then
        return false, 'Parduotuvė nepasiekiama (prekės neįkeltos).'
    end
    local opened = exports['qb-inventory']:OpenShop(src, Config.FreeDrugShop.name)
    if not opened then
        return false, 'Nepavyko atidaryti parduotuvės.'
    end
    return true
end

RegisterNetEvent('mrp_drugs:server:openFreeDrugShop', function()
    local src = source
    local ok, reason = tryOpenFreeDrugShop(src)
    if not ok then
        TriggerClientEvent('QBCore:Notify', src, reason or 'Parduotuvė neprieinama.', 'error')
    end
end)

QBCore.Functions.CreateCallback('mrp_drugs:server:openFreeDrugShop', function(src, cb)
    local ok, reason = tryOpenFreeDrugShop(src)
    cb({ ok = ok, reason = reason })
end)

CreateThread(function()
    Wait(1700)
    registerWeedSupplyShop()
    registerFreeDrugShop()
    registerPrinterShop()
end)

AddEventHandler('onResourceStart', function(res)
    if res ~= 'qb-inventory' and res ~= GetCurrentResourceName() then return end
    CreateThread(function()
        Wait(900)
        registerWeedSupplyShop()
        registerFreeDrugShop()
        registerPrinterShop()
    end)
end)

QBCore.Functions.CreateUseableItem('grow_pot', function(source)
    TriggerClientEvent('mrp_drugs:client:placeGrowPot', source)
end)

QBCore.Functions.CreateUseableItem('watering_can', function(source)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return end
    local cfg = weedGrowCfg()
    local item, slot = findWateringCan(Player)
    if not item or not slot then return end
    local cap = tonumber(cfg.waterCanCapacity) or 100
    local w = getCanWater(item, cfg)
    setCanWater(source, slot, w, cfg)
    TriggerClientEvent('QBCore:Notify', source, ('Laistytuvas: %d/%d vandens. Papildyk prie ežero ar jūros.'):format(w, cap), 'primary')
end)

AddEventHandler('playerDropped', function()
    local src = source
    local active = releaseCraft(src)
    local Player = QBCore.Functions.GetPlayer(src)
    if active and Player then
        refundPartial(Player, active.recipe, 100)
    end
    lastCraftAt[src] = nil
    weedPackCooldownUntil[src] = nil
    lastSellAt[src] = nil
    mushroomPlayerCd[src] = nil
    weedPlayerCd[src] = nil
end)

CreateThread(function()
    while true do
        Wait(30000)
        local now = GetGameTimer()
        local expired = {}
        for src, active in pairs(activeCrafts) do
            if now - (active.startedAt or now) > 600000 then
                expired[#expired + 1] = src
            end
        end
        for _, src in ipairs(expired) do
            local active = releaseCraft(src)
            local Player = QBCore.Functions.GetPlayer(src)
            if active and Player then
                refundPartial(Player, active.recipe, 100)
                TriggerClientEvent('mrp_drugs:client:forceCloseUi', src)
                TriggerClientEvent('QBCore:Notify', src, 'Gamybos sesija baigėsi — ingredientai grąžinti.', 'error')
            end
        end
    end
end)
