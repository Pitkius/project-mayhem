local QBCore = exports['qb-core']:GetCoreObject()

local function nearCoords(src, coords, maxDist)
    maxDist = tonumber(maxDist) or 18.0
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end
    local p = GetEntityCoords(ped)
    local d = #(p - vector3(coords.x, coords.y, coords.z))
    return d <= maxDist
end

RegisterNetEvent('mrp_mechanic:server:openStash', function()
    local src = source
    if GetResourceState('qb-inventory') ~= 'started' then
        return TriggerClientEvent('QBCore:Notify', src, 'qb-inventory neįjungtas.', 'error')
    end
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    local j = Player.PlayerData.job
    if j.name ~= Config.JobName or not j.onduty then
        return TriggerClientEvent('QBCore:Notify', src, 'Tik mechanikams tarnyboje.', 'error')
    end
    local st = Config.Stash
    if not nearCoords(src, st.coords, 22.0) then
        return TriggerClientEvent('QBCore:Notify', src, 'Per toli nuo sandėlio.', 'error')
    end
    exports['qb-inventory']:OpenInventory(src, st.stashId, {
        maxweight = st.maxweight,
        slots = st.slots,
        label = st.label,
    })
end)

RegisterNetEvent('mrp_mechanic:server:openBossStash', function()
    local src = source
    if GetResourceState('qb-inventory') ~= 'started' then
        return TriggerClientEvent('QBCore:Notify', src, 'qb-inventory neįjungtas.', 'error')
    end
    if not canBoss(src) then
        return TriggerClientEvent('QBCore:Notify', src, 'Tik vadovybei tarnyboje.', 'error')
    end
    local st = Config.BossStash
    if not st or not st.coords then
        return TriggerClientEvent('QBCore:Notify', src, 'Boso sandėlis nesukonfigūruotas.', 'error')
    end
    if not nearCoords(src, st.coords, 22.0) then
        return TriggerClientEvent('QBCore:Notify', src, 'Per toli nuo boso sandėlio.', 'error')
    end
    exports['qb-inventory']:OpenInventory(src, st.stashId, {
        maxweight = st.maxweight,
        slots = st.slots,
        label = st.label,
    })
end)

local function getGrade(src)
    local P = QBCore.Functions.GetPlayer(src)
    if not P then return -1 end
    return tonumber(P.PlayerData.job.grade.level) or 0
end

local function canBoss(src)
    local P = QBCore.Functions.GetPlayer(src)
    if not P then return false end
    local j = P.PlayerData.job
    if j.name ~= Config.JobName or not j.onduty then return false end
    if j.isboss then return true end
    return getGrade(src) >= (Config.Permissions.boss_menu or 4)
end

local function nearManagement(src)
    return nearCoords(src, Config.Management.coords, 18.0)
end

local function bossOutranks(bossSrc, targetGrade)
    local B = QBCore.Functions.GetPlayer(bossSrc)
    if not B then return false end
    if B.PlayerData.job.isboss then return true end
    local bg = getGrade(bossSrc)
    return bg > (tonumber(targetGrade) or 0)
end

RegisterNetEvent('mrp_mechanic:server:bossHire', function(targetId, grade)
    local src = source
    if not canBoss(src) or not nearManagement(src) then
        return TriggerClientEvent('QBCore:Notify', src, 'Negalima.', 'error')
    end
    targetId = tonumber(targetId)
    grade = tonumber(grade)
    if not targetId or grade == nil or grade < 0 or grade > 5 then return end
    if not bossOutranks(src, grade) then
        return TriggerClientEvent('QBCore:Notify', src, 'Negali skirti tokio rango.', 'error')
    end
    local T = QBCore.Functions.GetPlayer(targetId)
    if not T then
        return TriggerClientEvent('QBCore:Notify', src, 'Žaidėjas neprisijungęs.', 'error')
    end
    T.Functions.SetJob(Config.JobName, grade)
    T.Functions.SetJobDuty(true)
    TriggerClientEvent('QBCore:Notify', src, 'Įdarbinta.', 'success')
    TriggerClientEvent('QBCore:Notify', targetId, 'Priimta į mechanikus.', 'success')
end)

RegisterNetEvent('mrp_mechanic:server:bossFire', function(targetId)
    local src = source
    if not canBoss(src) or not nearManagement(src) then
        return TriggerClientEvent('QBCore:Notify', src, 'Negalima.', 'error')
    end
    targetId = tonumber(targetId)
    if not targetId then return end
    local T = QBCore.Functions.GetPlayer(targetId)
    if not T then return end
    if T.PlayerData.job.name ~= Config.JobName then return end
    local tg = tonumber(T.PlayerData.job.grade.level) or 0
    if not bossOutranks(src, tg) then
        return TriggerClientEvent('QBCore:Notify', src, 'Negali atleisti.', 'error')
    end
    T.Functions.SetJob('unemployed', 0)
    TriggerClientEvent('QBCore:Notify', src, 'Atleista.', 'success')
    TriggerClientEvent('QBCore:Notify', targetId, 'Atleistas iš mechanikų.', 'error')
end)

RegisterNetEvent('mrp_mechanic:server:bossSetGrade', function(targetId, grade)
    local src = source
    if not canBoss(src) or not nearManagement(src) then
        return TriggerClientEvent('QBCore:Notify', src, 'Negalima.', 'error')
    end
    targetId = tonumber(targetId)
    grade = tonumber(grade)
    if not targetId or grade == nil or grade < 0 or grade > 5 then return end
    local T = QBCore.Functions.GetPlayer(targetId)
    if not T or T.PlayerData.job.name ~= Config.JobName then return end
    local tg = tonumber(T.PlayerData.job.grade.level) or 0
    if not bossOutranks(src, tg) or not bossOutranks(src, grade) then
        return TriggerClientEvent('QBCore:Notify', src, 'Negali keisti.', 'error')
    end
    T.Functions.SetJob(Config.JobName, grade)
    TriggerClientEvent('QBCore:Notify', src, 'Rangas pakeistas.', 'success')
end)

local function nearRepairBay(src, bayIdx)
    bayIdx = tonumber(bayIdx)
    if not bayIdx or not Config.RepairBays or not Config.RepairBays[bayIdx] then
        return false
    end
    local bay = Config.RepairBays[bayIdx]
    local radius = math.max(tonumber(bay.length) or 6.0, tonumber(bay.width) or 6.0) * 0.55 + 14.0
    return nearCoords(src, bay.coords, radius)
end

local function hasItemCount(Player, item, amount)
    local it = Player.Functions.GetItemByName(item)
    return (it and it.amount or 0) >= (tonumber(amount) or 0)
end

local function removeItemCount(Player, item, amount)
    return Player.Functions.RemoveItem(item, tonumber(amount) or 0)
end

local PerfKitByModType = {
    [11] = 'engine_kit',
    [12] = 'brakes_kit',
    [13] = 'transmission_kit',
    [15] = 'suspension_kit',
    [16] = 'armor_kit',
}

local function requiredUpgradeItem(modType, targetLevel)
    modType = tonumber(modType)
    targetLevel = tonumber(targetLevel)
    if targetLevel == nil or targetLevel < 0 then return nil end

    local tiered = Config.TuningUpgradeItems and Config.TuningUpgradeItems[modType]
    if tiered then
        if tiered.item then return tiered.item end
        if tiered.prefix and tiered.maxLevel then
            local lvl = targetLevel + 1
            if lvl >= 1 and lvl <= tiered.maxLevel then
                return ('%s_%d'):format(tiered.prefix, lvl)
            end
        end
    end

    local legacy = PerfKitByModType[modType]
    if legacy and targetLevel >= 0 then return legacy end
    if modType == 18 and targetLevel >= 0 then return 'turbo_kit' end
    return nil
end

QBCore.Functions.CreateCallback('mrp_mechanic:server:canInstallUpgrade', function(src, cb, modType, targetLevel, bayIdx)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return cb({ ok = false, reason = 'Nerastas žaidėjas.' }) end
    local j = Player.PlayerData.job
    if j.name ~= Config.JobName or not j.onduty then
        return cb({ ok = false, reason = 'Tik mechanikams tarnyboje.' })
    end
    if not nearRepairBay(src, bayIdx) then
        return cb({ ok = false, reason = 'Per toli nuo remonto zonos.' })
    end

    targetLevel = tonumber(targetLevel) or -1
    if targetLevel < 0 then
        return cb({ ok = true })
    end

    local item = requiredUpgradeItem(modType, targetLevel)
    if not item then
        return cb({ ok = true })
    end

    if not hasItemCount(Player, item, 1) then
        return cb({ ok = false, reason = ('Reikia detalės: %s'):format(item), requiredItem = item })
    end
    cb({ ok = true, requiredItem = item })
end)

--- Performance UI: inventoriaus kiekiai montavimo panelėje
QBCore.Functions.CreateCallback('mrp_mechanic:server:getPerformanceUiData', function(src, cb, bayIdx)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return cb(nil) end
    local j = Player.PlayerData.job
    if j.name ~= Config.JobName or not j.onduty then
        return cb(nil)
    end
    if not nearRepairBay(src, bayIdx) then
        return cb(nil)
    end

    local inventory = {}
    local function addCount(itemName)
        if not itemName or itemName == '' then return end
        local it = Player.Functions.GetItemByName(itemName)
        inventory[itemName] = (it and it.amount) or 0
    end

    for modType, tiered in pairs(Config.TuningUpgradeItems or {}) do
        if tiered.item then
            addCount(tiered.item)
        elseif tiered.prefix and tiered.maxLevel then
            for lvl = 1, tiered.maxLevel do
                addCount(('%s_%d'):format(tiered.prefix, lvl))
            end
        end
        local legacy = PerfKitByModType[modType]
        if legacy then addCount(legacy) end
    end

    local labels = {}
    for itemName, count in pairs(inventory) do
        local shared = QBCore.Shared.Items[itemName]
        labels[itemName] = {
            label = shared and shared.label or itemName,
            image = shared and shared.image or 'box.png',
        }
    end

    cb({ inventory = inventory, labels = labels })
end)

RegisterNetEvent('mrp_mechanic:server:consumeUpgradeItem', function(itemName)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    local j = Player.PlayerData.job
    if j.name ~= Config.JobName or not j.onduty then return end
    itemName = tostring(itemName or '')
    if itemName == '' then return end
    if hasItemCount(Player, itemName, 1) then
        removeItemCount(Player, itemName, 1)
    end
end)

local function recipeCategoryId(key)
    key = tostring(key or '')
    if key:find('^engine_') then return 'engine' end
    if key:find('^brakes_') then return 'brakes' end
    if key:find('^transmission_') then return 'transmission' end
    if key:find('^suspension_') then return 'suspension' end
    if key:find('^armor_') then return 'armor' end
    if key == 'turbo_kit' then return 'turbo' end
    if key == 'repairkit' or key == 'tirerepairkit' or key == 'advancedrepairkit' then return 'repair_kits' end
    return 'other'
end

local function recipePoolForKind(craftKind)
    local pool = {}
    craftKind = tostring(craftKind or 'tuning')
    if craftKind == 'repair' then
        return Config.RepairKitRecipes or {}
    end
    for key, recipe in pairs(Config.TuningRecipes or {}) do
        local isKit = key:sub(-4) == '_kit' or key == 'turbo_kit'
        if craftKind == 'kits' and isKit then
            pool[key] = recipe
        elseif craftKind == 'tuning' and not isKit then
            pool[key] = recipe
        end
    end
    return pool
end

local function craftHeaderForKind(craftKind)
    craftKind = tostring(craftKind or 'tuning')
    if craftKind == 'kits' then return 'Montavimo rinkinių gamyba' end
    if craftKind == 'repair' then return 'Taisymo rinkinių gamyba' end
    return 'Performance dalių gamyba'
end

local function craftSubtitleForKind(craftKind)
    craftKind = tostring(craftKind or 'tuning')
    if craftKind == 'repair' then return 'Gaminami remonto ir padangų rinkiniai iš inventoriaus medžiagų.' end
    if craftKind == 'kits' then return 'Gaminami montavimo rinkiniai transporto modifikacijoms.' end
    return 'Tobulink transportą — gamink performance dalis iš turimų medžiagų.'
end

local function maxCraftAmount(Player, recipe)
    local cap = tonumber(Config.CraftMaxBatch) or 10
    local maxAmt = cap
    for item, need in pairs(recipe.materials or {}) do
        local per = tonumber(need) or 0
        if per > 0 then
            local it = Player.Functions.GetItemByName(item)
            local have = (it and it.amount) or 0
            local possible = math.floor(have / per)
            if possible < maxAmt then maxAmt = possible end
        end
    end
    return math.max(0, maxAmt)
end

local function performCraft(src, recipeKey, amount)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return false, 'Nerastas žaidėjas.' end
    local j = Player.PlayerData.job
    if j.name ~= Config.JobName or not j.onduty then
        return false, 'Tik mechanikams tarnyboje.'
    end
    recipeKey = tostring(recipeKey or '')
    local recipe = (Config.TuningRecipes and Config.TuningRecipes[recipeKey])
        or (Config.RepairKitRecipes and Config.RepairKitRecipes[recipeKey])
    if not recipe then return false, 'Receptas nerastas.' end
    local cap = tonumber(Config.CraftMaxBatch) or 10
    amount = math.max(1, math.min(cap, tonumber(amount) or 1))

    for item, need in pairs(recipe.materials or {}) do
        local totalNeed = (tonumber(need) or 0) * amount
        if totalNeed > 0 and not hasItemCount(Player, item, totalNeed) then
            return false, ('Trūksta medžiagų: %s x%s'):format(item, totalNeed)
        end
    end

    for item, need in pairs(recipe.materials or {}) do
        local totalNeed = (tonumber(need) or 0) * amount
        if totalNeed > 0 then
            removeItemCount(Player, item, totalNeed)
        end
    end

    local outCount = (tonumber(recipe.count) or 1) * amount
    Player.Functions.AddItem(recipe.output, outCount)
    TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[recipe.output], 'add', outCount)
    TriggerClientEvent('QBCore:Notify', src, ('Pagaminta: %s x%s'):format(recipe.label or recipe.output, outCount), 'success')
    return true, nil, recipe.label or recipe.output, outCount
end

local function buildCraftInventory(Player, recipePool)
    local inventory = {}
    local labels = {}
    local function track(itemName)
        if not itemName or itemName == '' then return end
        if inventory[itemName] ~= nil then return end
        local it = Player.Functions.GetItemByName(itemName)
        inventory[itemName] = (it and it.amount) or 0
        local shared = QBCore.Shared.Items[itemName]
        labels[itemName] = {
            label = shared and shared.label or itemName,
            image = shared and shared.image or 'box.png',
            description = shared and shared.description or '',
        }
    end
    for _, recipe in pairs(recipePool) do
        track(recipe.output)
        for item, _ in pairs(recipe.materials or {}) do
            track(item)
        end
    end
    return inventory, labels
end

QBCore.Functions.CreateCallback('mrp_mechanic:server:getCraftUiData', function(src, cb, craftKind)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return cb({ ok = false }) end
    local j = Player.PlayerData.job
    if j.name ~= Config.JobName or not j.onduty then
        return cb({ ok = false, message = 'Tik mechanikams tarnyboje.' })
    end

    craftKind = tostring(craftKind or 'tuning')
    local recipePool = recipePoolForKind(craftKind)
    if not next(recipePool) then
        return cb({ ok = false, message = 'Nėra receptų šiam stalui.' })
    end

    local inventory, labels = buildCraftInventory(Player, recipePool)
    local recipes = {}
    local categorySet = {}

    for key, recipe in pairs(recipePool) do
        local catId = recipeCategoryId(key)
        categorySet[catId] = true
        local sharedOut = QBCore.Shared.Items[recipe.output]
        local level = tonumber(key:match('_(%d+)$'))
        local isKit = key:sub(-4) == '_kit' or (key == 'turbo_kit' and craftKind == 'kits')
        local materials = {}
        for item, need in pairs(recipe.materials or {}) do
            local n = tonumber(need) or 0
            if n > 0 then
                materials[#materials + 1] = { item = item, need = n }
            end
        end
        table.sort(materials, function(a, b) return a.item < b.item end)
        recipes[#recipes + 1] = {
            key = key,
            label = recipe.label or key,
            output = recipe.output,
            categoryId = catId,
            level = level,
            isKit = isKit,
            materials = materials,
            maxAmount = maxCraftAmount(Player, recipe),
            description = sharedOut and sharedOut.description or '',
            image = sharedOut and sharedOut.image or 'box.png',
        }
    end

    table.sort(recipes, function(a, b)
        if a.categoryId ~= b.categoryId then return a.categoryId < b.categoryId end
        if (a.level or 0) ~= (b.level or 0) then return (a.level or 0) < (b.level or 0) end
        return a.label < b.label
    end)

    local categories = {}
    local order = { 'engine', 'turbo', 'transmission', 'suspension', 'brakes', 'armor', 'repair_kits', 'other' }
    for _, id in ipairs(order) do
        if categorySet[id] then
            local meta = (Config.CraftCategoryMeta and Config.CraftCategoryMeta[id]) or {}
            categories[#categories + 1] = {
                id = id,
                label = meta.label or id,
                desc = meta.desc or '',
            }
        end
    end

    cb({
        ok = true,
        craftKind = craftKind,
        title = craftHeaderForKind(craftKind),
        subtitle = craftSubtitleForKind(craftKind),
        maxBatch = tonumber(Config.CraftMaxBatch) or 10,
        categories = categories,
        recipes = recipes,
        inventory = inventory,
        labels = labels,
    })
end)

QBCore.Functions.CreateCallback('mrp_mechanic:server:craftPart', function(src, cb, recipeKey, amount)
    local ok, err = performCraft(src, recipeKey, amount)
    if not ok then
        return cb({ ok = false, message = err or 'Nepavyko pagaminti.' })
    end
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return cb({ ok = true }) end
    local recipe = (Config.TuningRecipes and Config.TuningRecipes[recipeKey])
        or (Config.RepairKitRecipes and Config.RepairKitRecipes[recipeKey])
    local pool = {}
    if recipe then pool[recipeKey] = recipe end
    local inventory, labels = buildCraftInventory(Player, pool)
    cb({
        ok = true,
        inventory = inventory,
        labels = labels,
        maxAmount = recipe and maxCraftAmount(Player, recipe) or 0,
        recipeKey = recipeKey,
    })
end)

RegisterNetEvent('mrp_mechanic:server:craftTuningPart', function(recipeKey, amount)
    local src = source
    performCraft(src, recipeKey, amount)
end)

RegisterNetEvent('mrp_mechanic:server:saveBayVehicleTune', function(bayIdx, props)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    local j = Player.PlayerData.job
    if j.name ~= Config.JobName or not j.onduty then
        return TriggerClientEvent('QBCore:Notify', src, 'Tik mechanikams tarnyboje.', 'error')
    end
    if not nearRepairBay(src, bayIdx) then
        return TriggerClientEvent('QBCore:Notify', src, 'Per toli nuo remonto zonos.', 'error')
    end
    if type(props) ~= 'table' then return end
    local plate = props.plate and tostring(props.plate):upper():gsub('%s+', '')
    if not plate or plate == '' then
        return TriggerClientEvent('QBCore:Notify', src, 'Nėra numerių.', 'error')
    end
    local row = MySQL.single.await('SELECT plate FROM player_vehicles WHERE plate = ? LIMIT 1', { plate })
    if not row then
        return TriggerClientEvent('QBCore:Notify', src, 'Šis transportas neregistruotas sistemoje.', 'error')
    end
    MySQL.update.await('UPDATE player_vehicles SET mods = ? WHERE plate = ?', {
        json.encode(props),
        plate,
    })
    TriggerClientEvent('QBCore:Notify', src, 'Modifikacijos išsaugotos duomenų bazėje.', 'success')
end)

local function nearSandboxVendor(src)
    local v = Config.DebugSandboxVendor or {}
    if not v.coords then return false end
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end
    local p = GetEntityCoords(ped)
    local c = v.coords
    return #(p - vector3(c.x, c.y, c.z)) <= 22.0
end

local function buildDebugSupplyShopItems()
    local out = {}
    for i, row in ipairs(Config.DebugSandboxBundleItems or {}) do
        if row and row.item and QBCore.Shared.Items[row.item] then
            out[#out + 1] = {
                name = row.item,
                amount = 99999,
                price = math.max(1, tonumber(row.price) or 1),
                slot = i,
            }
        end
    end
    return out
end

local function buildDebugPickaxeShopItems()
    local out = {}
    for i, row in ipairs(Config.DebugPickaxeOffers or {}) do
        if row and row.item and QBCore.Shared.Items[row.item] then
            out[#out + 1] = {
                name = row.item,
                amount = 99999,
                price = math.max(1, tonumber(row.price) or 1),
                slot = i,
            }
        end
    end
    return out
end

local function registerDebugShops()
    if GetResourceState('qb-inventory') ~= 'started' then return end
    local supply = Config.DebugSandboxSupplyShop or {}
    local pickaxe = Config.DebugSandboxPickaxeShop or {}
    exports['qb-inventory']:CreateShop({
        name = supply.name or 'mrp_mech_debug_supplies',
        label = supply.label or 'Sandbox: zaliavu test shop',
        slots = math.max(1, #(Config.DebugSandboxBundleItems or {})),
        items = buildDebugSupplyShopItems(),
    })
    exports['qb-inventory']:CreateShop({
        name = pickaxe.name or 'mrp_mech_debug_pickaxes',
        label = pickaxe.label or 'Sandbox: kirtikliu test shop',
        slots = math.max(1, #(Config.DebugPickaxeOffers or {})),
        items = buildDebugPickaxeShopItems(),
    })
end

CreateThread(function()
    Wait(700)
    registerDebugShops()
end)

RegisterNetEvent('mrp_mechanic:server:debugOpenSupplyShop', function()
    local src = source
    local cfg = Config.DebugSandboxVendor or {}
    if cfg.enabled ~= true then return end
    if not nearSandboxVendor(src) then
        return TriggerClientEvent('QBCore:Notify', src, 'Per toli nuo sandbox pardavėjo.', 'error')
    end
    registerDebugShops()
    local supply = Config.DebugSandboxSupplyShop or {}
    exports['qb-inventory']:OpenShop(src, supply.name or 'mrp_mech_debug_supplies')
end)

RegisterNetEvent('mrp_mechanic:server:debugOpenPickaxeShop', function()
    local src = source
    local cfg = Config.DebugSandboxVendor or {}
    if cfg.enabled ~= true then return end
    if not nearSandboxVendor(src) then
        return TriggerClientEvent('QBCore:Notify', src, 'Per toli nuo sandbox pardavėjo.', 'error')
    end
    registerDebugShops()
    local pickaxe = Config.DebugSandboxPickaxeShop or {}
    exports['qb-inventory']:OpenShop(src, pickaxe.name or 'mrp_mech_debug_pickaxes')
end)

local function isMechanicOnDuty(src)
    local P = QBCore.Functions.GetPlayer(src)
    if not P then return false end
    local j = P.PlayerData.job
    return j and j.name == Config.JobName and j.onduty == true
end

local function nearVehicleNet(src, netId, maxDist)
    netId = tonumber(netId)
    if not netId then return false, nil end
    local veh = NetworkGetEntityFromNetworkId(netId)
    if not veh or veh == 0 or not DoesEntityExist(veh) then return false, nil end
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false, nil end
    local d = #(GetEntityCoords(ped) - GetEntityCoords(veh))
    if d > (maxDist or 4.5) then return false, nil end
    return true, veh
end

QBCore.Functions.CreateCallback('mrp_mechanic:server:canFieldRepair', function(src, cb, netId)
    if not isMechanicOnDuty(src) then
        return cb(false, 'Tik mechanikams tarnyboje.')
    end
    local ok = nearVehicleNet(src, netId, (Config.FieldRepair and Config.FieldRepair.maxDistance or 4.0) + 0.75)
    if not ok then
        return cb(false, 'Per toli nuo transporto.')
    end
    local cfg = Config.FieldRepair or {}
    local need = cfg.requireItem
    if need and need ~= '' then
        local P = QBCore.Functions.GetPlayer(src)
        if not P or not P.Functions.GetItemByName(need) then
            local label = (QBCore.Shared.Items[need] and QBCore.Shared.Items[need].label) or need
            return cb(false, ('Reikia: %s'):format(label))
        end
    end
    cb(true)
end)

RegisterNetEvent('mrp_mechanic:server:fieldRepair', function(netId)
    local src = source
    if not isMechanicOnDuty(src) then return end
    local maxDist = (Config.FieldRepair and Config.FieldRepair.maxDistance) or 4.0
    local near = nearVehicleNet(src, netId, maxDist + 1.0)
    if not near then
        return TriggerClientEvent('QBCore:Notify', src, 'Per toli.', 'error')
    end
    local cfg = Config.FieldRepair or {}
    local need = cfg.requireItem
    if need and need ~= '' and cfg.consumeItem ~= false then
        local P = QBCore.Functions.GetPlayer(src)
        if not P or not P.Functions.RemoveItem(need, 1) then
            return TriggerClientEvent('QBCore:Notify', src, 'Neturite remonto rinkinio.', 'error')
        end
        TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[need], 'remove')
    end
    TriggerClientEvent('mrp_mechanic:client:doFieldRepair', src, netId)
end)

RegisterNetEvent('mrp_mechanic:server:fieldClean', function(netId)
    local src = source
    if not isMechanicOnDuty(src) then return end
    local maxDist = (Config.FieldRepair and Config.FieldRepair.maxDistance) or 4.0
    if not nearVehicleNet(src, netId, maxDist + 1.0) then
        return TriggerClientEvent('QBCore:Notify', src, 'Per toli.', 'error')
    end
    TriggerClientEvent('mrp_mechanic:client:doFieldClean', src, netId)
end)

RegisterNetEvent('mrp_mechanic:server:fieldFlip', function(netId)
    local src = source
    if not isMechanicOnDuty(src) then return end
    local maxDist = (Config.FieldRepair and Config.FieldRepair.maxDistance) or 4.0
    if not nearVehicleNet(src, netId, maxDist + 1.0) then
        return TriggerClientEvent('QBCore:Notify', src, 'Per toli.', 'error')
    end
    TriggerClientEvent('mrp_mechanic:client:doFieldFlip', src, netId)
end)
