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

RegisterNetEvent('mrp_mechanic:server:craftTuningPart', function(recipeKey, amount)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    local j = Player.PlayerData.job
    if j.name ~= Config.JobName or not j.onduty then
        return TriggerClientEvent('QBCore:Notify', src, 'Tik mechanikams tarnyboje.', 'error')
    end
    local recipe = Config.TuningRecipes and Config.TuningRecipes[tostring(recipeKey or '')]
    if not recipe then return end
    amount = math.max(1, math.min(10, tonumber(amount) or 1))

    for item, need in pairs(recipe.materials or {}) do
        local totalNeed = (tonumber(need) or 0) * amount
        if totalNeed > 0 and not hasItemCount(Player, item, totalNeed) then
            return TriggerClientEvent('QBCore:Notify', src, ('Trūksta medžiagų: %s x%s'):format(item, totalNeed), 'error')
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
