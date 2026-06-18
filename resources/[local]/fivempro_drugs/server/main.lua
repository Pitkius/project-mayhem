local QBCore = exports['qb-core']:GetCoreObject()

local activeCrafts = {}
local lastCraftAt = {}
local lastSellAt = {}
local zoneHeat = {}

local function logAdmin(msg)
    print(('[^3fivempro_drugs^7] %s'):format(msg))
end

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
    local list = {}
    for _, st in ipairs(Config.Stations or {}) do
        list[#list + 1] = st
    end
    local lab = Config.HeroinLab
    if lab and lab.stations then
        for _, st in ipairs(lab.stations) do
            list[#list + 1] = st
        end
    end
    local thcLab = Config.ThcLab
    if thcLab and thcLab.stations then
        for _, st in ipairs(thcLab.stations) do
            list[#list + 1] = st
        end
    end
    local weedCayo = Config.WeedCayoLab
    if weedCayo and weedCayo.stations then
        for _, st in ipairs(weedCayo.stations) do
            list[#list + 1] = st
        end
    end
    local methLab = Config.MethLab
    if methLab and methLab.stations then
        for _, st in ipairs(methLab.stations) do
            list[#list + 1] = st
        end
    end
    local pillsLab = Config.PillsLab
    if pillsLab and pillsLab.stations then
        for _, st in ipairs(pillsLab.stations) do
            list[#list + 1] = st
        end
    end
    local ampLab = Config.AmpMobileLab
    if ampLab and ampLab.packStation then
        list[#list + 1] = ampLab.packStation
    end
    local weaponL1 = Config.WeaponBenchL1
    if weaponL1 and weaponL1.stations then
        for _, st in ipairs(weaponL1.stations) do
            list[#list + 1] = st
        end
    end
    return list
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

local function productUsesPrinter(productId, st)
    if not st or st.mode ~= 'weapon' then return false end
    for _, row in ipairs(getRecipe(productId, st)) do
        if PRINTER_PARTS[row.item] then return true end
    end
    return false
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

local function removeItems(Player, list)
    for _, row in ipairs(list) do
        if not Player.Functions.RemoveItem(row.item, row.count) then
            return false
        end
    end
    return true
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

local function buildRecipeStatus(Player, productId, st, src)
    local recipe = getEffectiveRecipe(productId, st, src)
    local rows = {}
    for _, row in ipairs(recipe) do
        local it = Player.Functions.GetItemByName(row.item)
        local have = it and it.amount or 0
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
        if not countItem(Player, row.item, row.count) then
            return false
        end
    end
    return true
end

local function findTurfAtPlayer(src)
    if GetResourceState('fivempro_gangs') ~= 'started' then return nil end
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    local c = GetEntityCoords(ped)
    if exports['fivempro_gangs'] then
        local ok, tid = pcall(function()
            return exports['fivempro_gangs']:FindTurfAt(c.x, c.y)
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
    if GetResourceState('fivempro_dispatch') ~= 'started' then return end
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return end
    local c = GetEntityCoords(ped)
    local msg = (Config.PoliceAlerts and Config.PoliceAlerts[alertKey]) or 'Įtartina veikla'
    if extra then msg = msg .. ' — ' .. extra end
    pcall(function()
        exports['fivempro_dispatch']:CreateDispatchCall('police', 'drugs', { x = c.x, y = c.y, z = c.z }, msg, src)
    end)
end

local function rollPolice(chance, src, key)
    chance = tonumber(chance) or 0
    if chance <= 0 then return end
    if math.random(1, 100) <= chance then
        policeAlert(src, key)
    end
end

QBCore.Functions.CreateCallback('fivempro_drugs:server:getStationUi', function(src, cb, stationId)
    local st = getStation(stationId)
    if not st then return cb({ ok = false, reason = 'Stotis nerasta.' }) end
    if not playerNearStation(src, stationId) then
        return cb({ ok = false, reason = 'Per toli nuo gamybos vietos.' })
    end
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return cb({ ok = false }) end

    local products = {}
    local pool = getStationProductPool(st)
    for pid, prod in pairs(pool) do
        if prod.level == st.level and stationProductAllowed(st, pid) then
            local exclusive = Config.AmpExclusiveProducts and Config.AmpExclusiveProducts[pid]
            if not exclusive or (st.products and #st.products > 0) then
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
                }
            end
        end
    end
    table.sort(products, function(a, b)
        local pool = getStationProductPool(st)
        local orderA = pool[a.id] and pool[a.id].lineOrder or 99
        local orderB = pool[b.id] and pool[b.id].lineOrder or 99
        if orderA ~= orderB then return orderA < orderB end
        return a.label < b.label
    end)

    cb({
        ok = true,
        station = { id = st.id, label = st.label, level = st.level, mode = st.mode or 'drugs' },
        products = products,
    })
end)

QBCore.Functions.CreateCallback('fivempro_drugs:server:startCraft', function(src, cb, stationId, productId)
    local st = getStation(stationId)
    local prod = getProduct(productId)
    if not st or not prod then return cb({ ok = false, reason = 'Netinkami duomenys.' }) end
    if prod.level ~= st.level then
        return cb({ ok = false, reason = 'Ši stotis netinka šiam produktui.' })
    end
    if not stationProductAllowed(st, productId) then
        return cb({ ok = false, reason = 'Šiame punkte negalima gaminti šio produkto.' })
    end
    if not playerNearStation(src, stationId) then
        return cb({ ok = false, reason = 'Per toli nuo stoties.' })
    end

    local now = GetGameTimer()
    if (lastCraftAt[src] or 0) + (Config.CraftCooldownMs or 4500) > now then
        return cb({ ok = false, reason = 'Palauk prieš kitą gamybą.' })
    end
    if activeCrafts[src] then
        return cb({ ok = false, reason = 'Jau vyksta gamyba.' })
    end

    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return cb({ ok = false }) end
    if not hasAllIngredients(Player, productId, st, src) then
        return cb({ ok = false, reason = 'Trūksta ingredientų.' })
    end

    local recipe = getEffectiveRecipe(productId, st, src)
    if not removeItems(Player, recipe) then
        return cb({ ok = false, reason = 'Nepavyko paimti ingredientų.' })
    end

    local token = ('%s-%s-%s'):format(src, productId, now)
    activeCrafts[src] = {
        token = token,
        stationId = stationId,
        productId = productId,
        startedAt = now,
        recipe = recipe,
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

QBCore.Functions.CreateCallback('fivempro_drugs:server:finishCraft', function(src, cb, token, minigameSuccess)
    local active = activeCrafts[src]
    if not active or active.token ~= token then
        return cb({ ok = false, reason = 'Gamyba neaktyvi.' })
    end
    if not playerNearStation(src, active.stationId) then
        activeCrafts[src] = nil
        return cb({ ok = false, reason = 'Per toli nuo stoties.' })
    end

    local prod = getProduct(active.productId)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player or not prod then
        activeCrafts[src] = nil
        return cb({ ok = false })
    end

    activeCrafts[src] = nil

    local failed = false
    if minigameSuccess ~= true then
        failed = true
    elseif math.random(1, 100) <= (prod.failChance or 10) then
        failed = true
    end

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
    if not Player.Functions.AddItem(outItem, outAmt) then
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

    cb({
        ok = true,
        item = outItem,
        amount = outAmt,
        label = prod.label,
    })
end)

QBCore.Functions.CreateCallback('fivempro_drugs:server:tryNpcSell', function(src, cb, itemName, npcNetId)
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
    if not countItem(Player, itemName, 1) then
        return cb({ ok = false, reason = 'Neturi šio produkto.' })
    end

    local netId = tonumber(npcNetId) or 0
    if netId > 0 then
        local ent = NetworkGetEntityFromNetworkId(netId)
        if ent ~= 0 and DoesEntityExist(ent) then
            local p = GetEntityCoords(GetPlayerPed(src))
            local n = GetEntityCoords(ent)
            if #(p - n) > (sellCfg.maxDistanceToPed or 3.0) + 1.5 then
                return cb({ ok = false, reason = 'NPC per toli.' })
            end
            if IsPedAPlayer(ent) then
                return cb({ ok = false, reason = 'Netinkamas tikslas.' })
            end
        end
    end

    if math.random(1, 100) <= (sellCfg.refuseChance or 18) then
        return cb({ ok = false, refused = true, reason = 'NPC atsisakė pirkti.' })
    end

    if math.random(1, 100) <= (sellCfg.panicChance or 8) then
        rollPolice(85, src, 'npc_panic')
        return cb({ ok = false, panic = true, reason = 'NPC panikuoja ir bėga!' })
    end

    Player.Functions.RemoveItem(itemName, 1)

    local gang = getPlayerGang(src)
    local turfId = findTurfAtPlayer(src)
    local price = prod.sellBase or 100
    if gang then
        price = math.floor(price * (1.0 + ((tonumber(gang.reputation) or 0) * (sellCfg.reputationPriceFactor or 0.004))))
    end
    if turfId and zoneHeat[turfId] and zoneHeat[turfId] > 40 then
        price = math.floor(price * 1.08)
    end
    price = math.floor(price * (sellCfg.basePriceMultiplier or 1.0))
    Player.Functions.AddMoney('cash', price, 'fivempro-drugs-sale')
    lastSellAt[src] = now

    local alertPolice = false
    if math.random(1, 100) <= (sellCfg.policeCallChance or 12) then
        alertPolice = true
        rollPolice(100, src, 'npc_call')
    end

    if turfId then
        addTurfHeat(turfId, sellCfg.heatPerSale or 3)
        if gang and GetResourceState('fivempro_gangs') == 'started' then
            local inf = tonumber(sellCfg.influencePerSale) or 2
            local turf = MySQL.single.await('SELECT owner_gang_id, sales_count, total_profit FROM fivempro_gang_turfs WHERE turf_id = ? LIMIT 1', { turfId })
            if turf and tonumber(turf.owner_gang_id) == tonumber(gang.gang_id) then
                local salesCount = (tonumber(turf.sales_count) or 0) + 1
                local totalProfit = (tonumber(turf.total_profit) or 0) + price
                MySQL.update.await('UPDATE fivempro_gang_turfs SET sales_count = ?, total_profit = ? WHERE turf_id = ?', {
                    salesCount, totalProfit, turfId,
                })
                MySQL.insert.await('INSERT INTO fivempro_gang_sales_logs (gang_id, turf_id, item_name, amount, profit) VALUES (?, ?, ?, ?, ?)', {
                    gang.gang_id, turfId, itemName, 1, price,
                })
                exports['fivempro_gangs']:AddTurfInfluence(src, turfId, 'drug_sale', {
                    amount = inf,
                    skipTurfCheck = true,
                    allowOwnTurf = true,
                    skipCooldown = true,
                })
            elseif sellCfg.requireGangForInfluence then
                exports['fivempro_gangs']:AddTurfInfluence(src, turfId, 'drug_sale', {
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

    logAdmin(('SELL %s $%s cid=%s turf=%s'):format(itemName, price, Player.PlayerData.citizenid, tostring(turfId)))
    cb({
        ok = true,
        price = price,
        item = itemName,
        turfId = turfId,
        alertPolice = alertPolice,
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
    for _, key in ipairs({ 'TestSupplyShopNPC', 'TestNPC' }) do
        local cfg = Config[key]
        if cfg and cfg.coords then
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

RegisterNetEvent('fivempro_drugs:server:openMaterialShop', function()
    local src = source
    local ok, reason = tryOpenMaterialShop(src)
    if not ok then
        TriggerClientEvent('QBCore:Notify', src, reason or 'Parduotuvė neprieinama.', 'error')
    end
end)

QBCore.Functions.CreateCallback('fivempro_drugs:server:openMaterialShop', function(src, cb)
    local ok, reason = tryOpenMaterialShop(src)
    cb({ ok = ok, reason = reason })
end)

QBCore.Functions.CreateCallback('fivempro_drugs:server:buyMaterial', function(src, cb, itemName, amount)
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
    TriggerClientEvent('qb-inventory:client:updateInventory', src, items)
    cb({ ok = true, item = itemName, amount = amount, label = shared.label })
end)

RegisterNetEvent('fivempro_drugs:server:testGiveKit', function(kitKey)
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

RegisterNetEvent('fivempro_drugs:server:testTriggerAlert', function()
    if not Config.EnableDrugTestNPC then return end
    policeAlert(source, 'sell_burst', 'test')
    TriggerClientEvent('QBCore:Notify', source, 'Test policijos alert išsiųstas.', 'primary')
end)

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
    for itemName, price in pairs(prices) do
        local unit = tonumber(price) or 0
        if unit > 0 then
            local data = Player.Functions.GetItemByName(itemName)
            local amt = data and (tonumber(data.amount) or tonumber(data.count) or 0) or 0
            if amt > 0 and Player.Functions.RemoveItem(itemName, amt, false) then
                total = total + (unit * amt)
                sold = sold + amt
            end
        end
    end

    if total <= 0 then
        TriggerClientEvent('QBCore:Notify', src, 'Neturi produktų, kuriuos šis supirkėjas priima.', 'error')
        return
    end

    Player.Functions.AddMoney('cash', total, ('fivempro-drugs-buyer-%s'):format(buyerId))
    TriggerClientEvent('QBCore:Notify', src, ('Parduota %s vnt. už $%s'):format(sold, total), 'success')
end

RegisterNetEvent('fivempro_drugs:server:sellProductAll', function(buyerId)
    processProductSell(source, buyerId)
end)

RegisterNetEvent('fivempro_drugs:server:sellAlcoholAll', function()
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

RegisterNetEvent('fivempro_drugs:server:pickMushroom', function(fieldId, spawnIndex, px, py, pz)
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
    TriggerClientEvent('fivempro_drugs:client:mushroomDespawn', -1, fieldId, spawnIndex)

    SetTimeout(respawn * 1000, function()
        mushroomPicked[key] = nil
        TriggerClientEvent('fivempro_drugs:client:mushroomRespawn', -1, fieldId, spawnIndex)
    end)
end)

AddEventHandler('playerDropped', function()
    local src = source
    activeCrafts[src] = nil
    lastCraftAt[src] = nil
    lastSellAt[src] = nil
    mushroomPlayerCd[src] = nil
end)
