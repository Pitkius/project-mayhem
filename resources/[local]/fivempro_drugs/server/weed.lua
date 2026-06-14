local QBCore = exports['qb-core']:GetCoreObject()

WeedPlants = WeedPlants or { byId = {} }

local function growCfg()
    return Config.WeedGrow or {}
end

local function shopCfg()
    return Config.WeedGrowShop or {}
end

local function shopItemsCfg()
    return Config.WeedGrowShopItems or {}
end

local function isSeedItem(name)
    local seeds = growCfg().seedItems or {}
    return seeds[tostring(name or '')] == true
end

local function ensureTable()
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `fivempro_drugs_weed_plants` (
        `id` int(11) NOT NULL AUTO_INCREMENT,
        `citizenid` varchar(50) NOT NULL,
        `x` double NOT NULL,
        `y` double NOT NULL,
        `z` double NOT NULL,
        `heading` float NOT NULL DEFAULT 0,
        `growth` float NOT NULL DEFAULT 0,
        `fed_ticks` int(11) NOT NULL DEFAULT 0,
        `planted_at` datetime NOT NULL DEFAULT current_timestamp(),
        PRIMARY KEY (`id`),
        KEY `citizenid` (`citizenid`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;]])
end

local function rowToPlant(r)
    return {
        id = tonumber(r.id),
        citizenid = r.citizenid,
        x = r.x + 0.0,
        y = r.y + 0.0,
        z = r.z + 0.0,
        heading = r.heading + 0.0,
        growth = tonumber(r.growth) or 0.0,
        fed_ticks = tonumber(r.fed_ticks) or 0,
    }
end

function WeedPlants.loadAll()
    ensureTable()
    WeedPlants.byId = {}
    local rows = MySQL.query.await('SELECT id, citizenid, x, y, z, heading, growth, fed_ticks FROM fivempro_drugs_weed_plants') or {}
    for _, r in ipairs(rows) do
        local p = rowToPlant(r)
        WeedPlants.byId[p.id] = p
    end
end

function WeedPlants.list()
    local out = {}
    for _, p in pairs(WeedPlants.byId) do
        out[#out + 1] = p
    end
    return out
end

function WeedPlants.get(id)
    return WeedPlants.byId[tonumber(id)]
end

function WeedPlants.syncAll(target)
    TriggerClientEvent('fivempro_drugs:client:syncWeedPlants', target or -1, WeedPlants.list())
end

local function countPlantsFor(citizenid)
    local n = 0
    for _, p in pairs(WeedPlants.byId) do
        if p.citizenid == citizenid then
            n = n + 1
        end
    end
    return n
end

local function tooCloseToOtherPlant(x, y, z, ignoreId)
    local minD = tonumber(growCfg().minPlantDistance) or 2.8
    for id, p in pairs(WeedPlants.byId) do
        if id ~= ignoreId then
            if #(vector3(x, y, z) - vector3(p.x, p.y, p.z)) < minD then
                return true
            end
        end
    end
    return false
end

local function playerNearPlant(src, plant, extra)
    if not plant then return false end
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end
    local c = GetEntityCoords(ped)
    local dist = (growCfg().interactDistance or 2.4) + (extra or 0.0)
    return #(c - vector3(plant.x, plant.y, plant.z)) <= dist
end

local function playerNearWeedGrowShop(src)
    local cfg = shopCfg()
    if not cfg or cfg.enabled == false or not cfg.coords then return false end
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end
    local p = GetEntityCoords(ped)
    local c = cfg.coords
    return #(p - vector3(c.x, c.y, c.z)) <= (cfg.maxDistance or 3.5) + 1.0
end

local function registerWeedGrowShop()
    if GetResourceState('qb-inventory') ~= 'started' then return false end
    local cfg = shopItemsCfg()
    if not cfg.name or not cfg.items then return false end
    local validItems = {}
    for _, row in ipairs(cfg.items) do
        if QBCore.Shared.Items[row.name] then
            validItems[#validItems + 1] = row
        end
    end
    if #validItems == 0 then return false end
    exports['qb-inventory']:CreateShop({
        name = cfg.name,
        label = cfg.label or 'Žolės reikmenys',
        slots = #validItems,
        items = validItems,
    })
    return true
end

local function tryOpenWeedGrowShop(src)
    if not playerNearWeedGrowShop(src) then
        return false, 'Per toli nuo parduotuvės.'
    end
    if GetResourceState('qb-inventory') ~= 'started' then
        return false, 'Inventoriaus sistema nepasiekiama.'
    end
    if not registerWeedGrowShop() then
        return false, 'Parduotuvė nepasiekiama.'
    end
    local opened = exports['qb-inventory']:OpenShop(src, shopItemsCfg().name)
    if not opened then
        return false, 'Nepavyko atidaryti parduotuvės.'
    end
    return true
end

QBCore.Functions.CreateCallback('fivempro_drugs:server:openWeedGrowShop', function(src, cb)
    local ok, reason = tryOpenWeedGrowShop(src)
    cb({ ok = ok, reason = reason })
end)

RegisterNetEvent('fivempro_drugs:server:placeWeedPlant', function(x, y, z, heading, seedItem)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    seedItem = tostring(seedItem or 'weed_seed')
    if not isSeedItem(seedItem) then return end

    x, y, z = tonumber(x), tonumber(y), tonumber(z)
    heading = tonumber(heading) or 0.0
    if not x or not y or not z then return end

    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return end
    local pcoords = GetEntityCoords(ped)
    if #(pcoords - vector3(x, y, z)) > 4.0 then
        TriggerClientEvent('QBCore:Notify', src, 'Per toli nuo sodinimo vietos.', 'error')
        return
    end

    local citizenid = Player.PlayerData.citizenid
    local maxPlants = tonumber(growCfg().maxPlantsPerPlayer) or 10
    if countPlantsFor(citizenid) >= maxPlants then
        TriggerClientEvent('QBCore:Notify', src, ('Galima turėti ne daugiau %s augalų.'):format(maxPlants), 'error')
        return
    end

    if tooCloseToOtherPlant(x, y, z) then
        TriggerClientEvent('QBCore:Notify', src, 'Per arti kito augalo.', 'error')
        return
    end

    if not Player.Functions.RemoveItem(seedItem, 1) then
        TriggerClientEvent('QBCore:Notify', src, 'Neturi sėklos.', 'error')
        return
    end

    local id = MySQL.insert.await(
        'INSERT INTO fivempro_drugs_weed_plants (citizenid, x, y, z, heading, growth, fed_ticks) VALUES (?, ?, ?, ?, ?, 0, 0)',
        { citizenid, x, y, z, heading }
    )
    if not id then
        Player.Functions.AddItem(seedItem, 1)
        TriggerClientEvent('QBCore:Notify', src, 'Nepavyko pasodinti.', 'error')
        return
    end

    local plant = {
        id = tonumber(id),
        citizenid = citizenid,
        x = x,
        y = y,
        z = z,
        heading = heading,
        growth = 0.0,
        fed_ticks = 0,
    }
    WeedPlants.byId[plant.id] = plant
    WeedPlants.syncAll()
    TriggerClientEvent('QBCore:Notify', src, 'Sėkla pasodinta.', 'success')
end)

RegisterNetEvent('fivempro_drugs:server:feedWeedPlant', function(plantId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    plantId = tonumber(plantId)
    local plant = WeedPlants.get(plantId)
    if not plant then return end
    if not playerNearPlant(src, plant, 1.0) then
        TriggerClientEvent('QBCore:Notify', src, 'Per toli nuo augalo.', 'error')
        return
    end

    if plant.growth >= (growCfg().harvestAt or 100) then
        TriggerClientEvent('QBCore:Notify', src, 'Augalas jau subrendęs — skink.', 'error')
        return
    end

    if not Player.Functions.RemoveItem('weed_nutrition', 1) then
        TriggerClientEvent('QBCore:Notify', src, 'Reikia augalų trąšų.', 'error')
        return
    end

    plant.fed_ticks = tonumber(growCfg().nutritionBoostTicks) or 6
    MySQL.update.await('UPDATE fivempro_drugs_weed_plants SET fed_ticks = ? WHERE id = ?', { plant.fed_ticks, plantId })
    WeedPlants.syncAll()
    TriggerClientEvent('QBCore:Notify', src, 'Augalas patręštas.', 'success')
end)

RegisterNetEvent('fivempro_drugs:server:harvestWeedPlant', function(plantId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    plantId = tonumber(plantId)
    local plant = WeedPlants.get(plantId)
    if not plant then return end
    if not playerNearPlant(src, plant, 1.0) then
        TriggerClientEvent('QBCore:Notify', src, 'Per toli nuo augalo.', 'error')
        return
    end

    if plant.growth < (growCfg().harvestAt or 100) then
        TriggerClientEvent('QBCore:Notify', src, ('Augalas dar auga (%s%%).'):format(math.floor(plant.growth)), 'error')
        return
    end

    local item = growCfg().harvestItem or 'weed_leaf'
    local amtMin = math.max(1, tonumber(growCfg().harvestMin) or 2)
    local amtMax = math.max(amtMin, tonumber(growCfg().harvestMax) or 5)
    local amount = math.random(amtMin, amtMax)

    if not Player.Functions.AddItem(item, amount) then
        TriggerClientEvent('QBCore:Notify', src, 'Inventorius pilnas.', 'error')
        return
    end

    MySQL.query.await('DELETE FROM fivempro_drugs_weed_plants WHERE id = ?', { plantId })
    WeedPlants.byId[plantId] = nil

    local itemData = QBCore.Shared.Items[item]
    TriggerClientEvent('inventory:client:ItemBox', src, itemData, 'add', amount)
    TriggerClientEvent('QBCore:Notify', src, ('Nuskinta %sx %s'):format(amount, itemData and itemData.label or item), 'success')
    WeedPlants.syncAll()
end)

local function growthLoop()
    local cfg = growCfg()
    local tickSec = math.max(15, tonumber(cfg.growthTickSec) or 60)
    local base = tonumber(cfg.growthPerTick) or 4
    local fed = tonumber(cfg.growthPerTickFed) or 7
    local harvestAt = tonumber(cfg.harvestAt) or 100

    while true do
        Wait(tickSec * 1000)
        local changed = false
        for id, plant in pairs(WeedPlants.byId) do
            if plant.growth < harvestAt then
                local add = base
                if (plant.fed_ticks or 0) > 0 then
                    add = fed
                    plant.fed_ticks = plant.fed_ticks - 1
                end
                plant.growth = math.min(harvestAt, plant.growth + add)
                MySQL.update.await(
                    'UPDATE fivempro_drugs_weed_plants SET growth = ?, fed_ticks = ? WHERE id = ?',
                    { plant.growth, plant.fed_ticks or 0, id }
                )
                changed = true
            end
        end
        if changed then
            WeedPlants.syncAll()
        end
    end
end

CreateThread(function()
    Wait(500)
    WeedPlants.loadAll()
    WeedPlants.syncAll()
    registerWeedGrowShop()
    CreateThread(growthLoop)
end)

AddEventHandler('onResourceStart', function(res)
    if res ~= GetCurrentResourceName() and res ~= 'qb-inventory' then return end
    CreateThread(function()
        Wait(800)
        if res == GetCurrentResourceName() then
            WeedPlants.loadAll()
            WeedPlants.syncAll()
        end
        registerWeedGrowShop()
    end)
end)

AddEventHandler('QBCore:Server:PlayerLoaded', function(Player)
    local src = Player and Player.PlayerData and Player.PlayerData.source
    if src then WeedPlants.syncAll(src) end
end)

CreateThread(function()
    Wait(900)
    for seedName in pairs(growCfg().seedItems or { weed_seed = true }) do
        QBCore.Functions.CreateUseableItem(seedName, function(source)
            TriggerClientEvent('fivempro_drugs:client:startPlaceWeed', source, seedName)
        end)
    end
end)
