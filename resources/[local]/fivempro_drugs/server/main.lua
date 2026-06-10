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

local function getStation(id)
    for _, st in ipairs(Config.Stations or {}) do
        if st.id == id then return st end
    end
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

local function buildRecipeStatus(Player, productId, st)
    local recipe = getRecipe(productId, st)
    local rows = {}
    for _, row in ipairs(recipe) do
        local it = Player.Functions.GetItemByName(row.item)
        local have = it and it.amount or 0
        rows[#rows + 1] = {
            item = row.item,
            label = QBCore.Shared.Items[row.item] and QBCore.Shared.Items[row.item].label or row.item,
            need = row.count,
            have = have,
            missing = math.max(0, row.count - have),
        }
    end
    return rows
end

local function hasAllIngredients(Player, productId, st)
    for _, row in ipairs(getRecipe(productId, st)) do
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
    TriggerClientEvent('fivempro_drugs:client:policeAlert', src, msg)
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
        if prod.level == st.level then
            products[#products + 1] = {
                id = pid,
                label = prod.label,
                level = prod.level,
                levelLabel = Config.LevelLabels[prod.level] or ('Lygis ' .. prod.level),
                risk = Config.RiskLabels[prod.risk] or prod.risk,
                craftTimeSec = math.floor((prod.craftTimeMs or 30000) / 1000),
                sellBase = (st.mode == 'weapon') and 0 or prod.sellBase,
                minigame = prod.minigame,
                ingredients = buildRecipeStatus(Player, pid, st),
                mode = st.mode or 'drugs',
            }
        end
    end
    table.sort(products, function(a, b) return a.label < b.label end)

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
    if not hasAllIngredients(Player, productId, st) then
        return cb({ ok = false, reason = 'Trūksta ingredientų.' })
    end

    local recipe = getRecipe(productId, st)
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
    }
    lastCraftAt[src] = now

    cb({
        ok = true,
        token = token,
        craftTimeMs = prod.craftTimeMs,
        minigame = prod.minigame,
        label = prod.label,
        failChance = prod.failChance,
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
        rollPolice((prod.policeChance or 8) + 6, src, 'craft_fail')
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
    rollPolice(prod.policeChance, src, 'craft_high')
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
        if p.output == itemName then prod = p break end
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
    if Config.EnableDrugTestNPC and Config.DevHub then
        local hub = Config.DevHub.center or Config.DevHub.blipCoords
        if hub and #(p - hub) <= 55.0 then
            return true
        end
    end
    local maxD = (Config.InteractDistance or 2.5) + 3.0
    for _, key in ipairs({ 'SupplyShopNPC', 'TestNPC' }) do
        local cfg = Config[key]
        if cfg and cfg.coords then
            local c = cfg.coords
            if #(p - vector3(c.x, c.y, c.z)) <= maxD then
                return true
            end
        end
    end
    return false
end

local function registerMaterialShop()
    if GetResourceState('qb-inventory') ~= 'started' then return false end
    local cfg = Config.MaterialShop
    if not cfg or not cfg.name or not cfg.items then return false end
    local validItems = {}
    for _, row in ipairs(cfg.items) do
        if QBCore.Shared.Items[row.name] or QBCore.Shared.Items[string.lower(row.name or '')] then
            validItems[#validItems + 1] = row
        else
            logAdmin(('MaterialShop praleidžia nežinomą item: %s'):format(tostring(row.name)))
        end
    end
    if #validItems == 0 then return false end
    exports['qb-inventory']:CreateShop({
        name = cfg.name,
        label = cfg.label or 'Reikmenys',
        slots = #validItems,
        items = validItems,
    })
    return true
end

CreateThread(function()
    Wait(1500)
    registerMaterialShop()
end)

local function tryOpenMaterialShop(src)
    if not Config.EnableDrugTestNPC then
        return false, 'Parduotuvė išjungta (production režimas).'
    end
    if not playerNearSupplyShop(src) then
        return false, 'Per toli nuo parduotuvės.'
    end
    if not registerMaterialShop() then
        return false, 'Parduotuvė nepasiekiama (qb-inventory).'
    end
    exports['qb-inventory']:OpenShop(src, Config.MaterialShop.name)
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

AddEventHandler('playerDropped', function()
    local src = source
    activeCrafts[src] = nil
    lastCraftAt[src] = nil
    lastSellAt[src] = nil
end)
