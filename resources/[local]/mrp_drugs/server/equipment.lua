--- Server: įrangos DB (fivempro_drugs_equipment), sync, craft validacija.
--- Eksportuoja global `Equipment` — naudoja server/main.lua startCraftAtEquipment.
local QBCore = exports['qb-core']:GetCoreObject()

Equipment = Equipment or { byId = {}, nextFixedId = -1 }

local function cfg()
    return Config.DrugEquipment or {}
end

local function typeCfg(itemType)
    local t = cfg().types or {}
    return t[itemType]
end

local function ensureTable()
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `fivempro_drugs_equipment` (
        `id` int(11) NOT NULL AUTO_INCREMENT,
        `citizenid` varchar(50) NOT NULL,
        `item_type` varchar(64) NOT NULL,
        `x` double NOT NULL,
        `y` double NOT NULL,
        `z` double NOT NULL,
        `heading` float NOT NULL DEFAULT 0,
        `created_at` datetime NOT NULL DEFAULT current_timestamp(),
        PRIMARY KEY (`id`),
        KEY `citizenid` (`citizenid`),
        KEY `item_type` (`item_type`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;]])
end

local function rowToEquip(r)
    return {
        id = tonumber(r.id),
        citizenid = r.citizenid,
        itemType = r.item_type,
        x = r.x + 0.0,
        y = r.y + 0.0,
        z = r.z + 0.0,
        heading = r.heading + 0.0,
        fixed = false,
    }
end

function Equipment.get(id)
    return Equipment.byId[tonumber(id)]
end

function Equipment.list()
    local out = {}
    for _, e in pairs(Equipment.byId) do
        out[#out + 1] = e
    end
    return out
end

function Equipment.syncAll(target)
    TriggerClientEvent('mrp_drugs:client:syncEquipment', target or -1, Equipment.list())
end

function Equipment.playerNear(src, id)
    local e = Equipment.get(id)
    if not e then return false end
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end
    local p = GetEntityCoords(ped)
    local dist = cfg().interactDist or 2.5
    return #(p - vector3(e.x, e.y, e.z)) <= dist + 1.0
end

function Equipment.labelFor(e)
    if not e then return 'Įranga' end
    if e.label then return e.label end
    local t = typeCfg(e.itemType)
    return (t and t.label) or e.itemType or 'Įranga'
end

local function countPlayer(citizenid)
    local n = 0
    for _, e in pairs(Equipment.byId) do
        if not e.fixed and e.citizenid == citizenid then
            n = n + 1
        end
    end
    return n
end

local function countGlobal()
    local n = 0
    for _, e in pairs(Equipment.byId) do
        if not e.fixed then n = n + 1 end
    end
    return n
end

local function tooClose(x, y, z)
    local minD = cfg().minPlaceDist or 2.0
    for _, e in pairs(Equipment.byId) do
        if #(vector3(x, y, z) - vector3(e.x, e.y, e.z)) < minD then
            return true
        end
    end
    return false
end

function Equipment.loadFixed()
    local locs = cfg().fixedLocations or {}
    for i, loc in ipairs(locs) do
        local itemType = loc.itemType
        if itemType and typeCfg(itemType) and loc.coords then
            local c = loc.coords
            Equipment.nextFixedId = Equipment.nextFixedId - 1
            local id = Equipment.nextFixedId
            Equipment.byId[id] = {
                id = id,
                citizenid = 'world',
                itemType = itemType,
                x = c.x + 0.0,
                y = c.y + 0.0,
                z = c.z + 0.0,
                heading = c.w or 0.0,
                fixed = true,
                label = loc.label,
            }
        end
    end
end

function Equipment.loadAll()
    ensureTable()
    Equipment.byId = {}
    Equipment.nextFixedId = -1
    local rows = MySQL.query.await('SELECT id, citizenid, item_type, x, y, z, heading FROM fivempro_drugs_equipment') or {}
    for _, r in ipairs(rows) do
        local e = rowToEquip(r)
        Equipment.byId[e.id] = e
    end
    Equipment.loadFixed()
end

local function isAdmin(src)
    return QBCore.Functions.HasPermission(src, 'admin') or QBCore.Functions.HasPermission(src, 'god')
end

local function canPickup(src, e)
    if not e or e.fixed then return false end
    local P = QBCore.Functions.GetPlayer(src)
    if not P then return false end
    if isAdmin(src) then return true end
    return P.PlayerData.citizenid == e.citizenid
end

function Equipment.isEquipmentItem(itemType)
    return typeCfg(itemType) ~= nil
end

function Equipment.assistRadius()
    local r = tonumber(cfg().labAssistRadius)
    if r and r > 0 then return r end
    return 5.0
end

function Equipment.nearbyTypeAt(x, y, z, itemType, maxDist)
    if not itemType or not Equipment.isEquipmentItem(itemType) then return false end
    maxDist = maxDist or Equipment.assistRadius()
    local pos = vector3(x + 0.0, y + 0.0, z + 0.0)
    for _, e in pairs(Equipment.byId) do
        if e.itemType == itemType then
            if #(pos - vector3(e.x, e.y, e.z)) <= maxDist then
                return true, e
            end
        end
    end
    return false
end

function Equipment.rowSatisfiedByNearby(primaryId, itemType)
    local primary = Equipment.get(primaryId)
    if not primary or not itemType then return false end
    if primary.itemType == itemType then return true end
    if not Equipment.isEquipmentItem(itemType) then return false end
    return Equipment.nearbyTypeAt(primary.x, primary.y, primary.z, itemType, Equipment.assistRadius())
end

function Equipment.productAllowedAt(itemType, productId)
    local t = typeCfg(itemType)
    if not t or not productId then return false end
    if t.packOnly then
        for _, pid in ipairs(t.products or {}) do
            if pid == productId then return true end
        end
        return false
    end
    return Equipment.recipeNeedsType(productId, itemType)
end

function Equipment.productsForType(itemType)
    local t = typeCfg(itemType)
    if not t or not t.products then return {} end
    local out = {}
    for _, pid in ipairs(t.products) do
        if t.packOnly or Equipment.recipeNeedsType(pid, itemType) then
            out[#out + 1] = pid
        end
    end
    return out
end

function Equipment.canCraftProduct(Player, equipmentId, productId)
    local e = Equipment.get(equipmentId)
    if not e or not Player then return false, {} end
    local recipe = Config.Recipes and Config.Recipes[productId] or {}
    local missing = {}
    for _, row in ipairs(recipe) do
        local ok = false
        if row.item == e.itemType or Equipment.rowSatisfiedByNearby(equipmentId, row.item) then
            ok = true
        else
            local it = Player.Functions.GetItemByName(row.item)
            ok = (it and it.amount or 0) >= (row.count or 0)
        end
        if not ok then missing[#missing + 1] = row.item end
    end
    return #missing == 0, missing
end

function Equipment.recipeNeedsType(productId, itemType)
    local recipe = Config.Recipes and Config.Recipes[productId]
    if not recipe or not itemType then return false end
    for _, row in ipairs(recipe) do
        if row.item == itemType and (row.count or 0) > 0 then
            return true
        end
    end
    return false
end

RegisterNetEvent('mrp_drugs:server:placeEquipment', function(itemType, x, y, z, heading)
    local src = source
    if not cfg().enabled then return end
    local t = typeCfg(itemType)
    if not t then return end
    local P = QBCore.Functions.GetPlayer(src)
    if not P then return end

    local maxP = cfg().maxPerPlayer or 3
    if countPlayer(P.PlayerData.citizenid) >= maxP then
        return TriggerClientEvent('QBCore:Notify', src, 'Per daug pastatytos įrangos.', 'error')
    end
    if countGlobal() >= (cfg().maxGlobal or 120) then
        return TriggerClientEvent('QBCore:Notify', src, 'Serverio įrangos limitas.', 'error')
    end
    if tooClose(x, y, z) then
        return TriggerClientEvent('QBCore:Notify', src, 'Per arti kitos įrangos.', 'error')
    end

    if not exports['qb-inventory']:RemoveItem(src, itemType, 1, false, 'mrp_drugs:placeEquipment') then
        return TriggerClientEvent('QBCore:Notify', src, 'Neturi įrangos.', 'error')
    end

    local id = MySQL.insert.await(
        'INSERT INTO fivempro_drugs_equipment (citizenid, item_type, x, y, z, heading) VALUES (?, ?, ?, ?, ?, ?)',
        { P.PlayerData.citizenid, itemType, x, y, z, heading or 0.0 }
    )
    if not id then
        exports['qb-inventory']:AddItem(src, itemType, 1, false, false, 'mrp_drugs:placeEquipment-rollback')
        return TriggerClientEvent('QBCore:Notify', src, 'Nepavyko išsaugoti.', 'error')
    end

    local e = {
        id = tonumber(id),
        citizenid = P.PlayerData.citizenid,
        itemType = itemType,
        x = x + 0.0,
        y = y + 0.0,
        z = z + 0.0,
        heading = heading or 0.0,
        fixed = false,
    }
    Equipment.byId[e.id] = e
    Equipment.syncAll()
    TriggerClientEvent('QBCore:Notify', src, ('Pastatyta: %s'):format(t.label or itemType), 'success')
end)

RegisterNetEvent('mrp_drugs:server:pickupEquipment', function(equipmentId)
    local src = source
    local e = Equipment.get(equipmentId)
    if not e or e.fixed then return end
    if not Equipment.playerNear(src, equipmentId) then return end
    if not canPickup(src, e) then return end

    local P = QBCore.Functions.GetPlayer(src)
    if not P then return end

    MySQL.update.await('DELETE FROM fivempro_drugs_equipment WHERE id = ?', { e.id })
    Equipment.byId[e.id] = nil
    exports['qb-inventory']:AddItem(src, e.itemType, 1, false, false, 'mrp_drugs:pickupEquipment')
    Equipment.syncAll()
    TriggerClientEvent('QBCore:Notify', src, 'Įranga surinkta.', 'success')
end)

QBCore.Functions.CreateCallback('mrp_drugs:server:getEquipmentMenu', function(src, cb, equipmentId)
    local e = Equipment.get(equipmentId)
    if not e then return cb({ ok = false, reason = 'Įranga nerasta.' }) end
    if not Equipment.playerNear(src, equipmentId) then
        return cb({ ok = false, reason = 'Per toli nuo įrangos.' })
    end
    local P = QBCore.Functions.GetPlayer(src)
    if not P then return cb({ ok = false }) end

    local rows = {}
    for _, productId in ipairs(Equipment.productsForType(e.itemType)) do
        local prod = Config.Products and Config.Products[productId]
        if prod and prod.minigame == 'schedule' then
            local can, missing = Equipment.canCraftProduct(P, equipmentId, productId)
            rows[#rows + 1] = {
                id = productId,
                label = prod.label,
                level = prod.level,
                canCraft = can,
                missing = missing,
            }
        end
    end

    table.sort(rows, function(a, b) return a.label < b.label end)
    cb({
        ok = true,
        equipment = {
            id = e.id,
            itemType = e.itemType,
            label = Equipment.labelFor(e),
            fixed = e.fixed == true,
        },
        products = rows,
    })
end)

CreateThread(function()
    Wait(500)
    Equipment.loadAll()
    Equipment.syncAll()
end)

AddEventHandler('onResourceStart', function(res)
    if res ~= GetCurrentResourceName() then return end
    CreateThread(function()
        Wait(800)
        Equipment.loadAll()
        Equipment.syncAll()
    end)
end)

AddEventHandler('playerJoining', function()
    local src = source
    CreateThread(function()
        Wait(4000)
        Equipment.syncAll(src)
    end)
end)

RegisterNetEvent('mrp_drugs:server:requestEquipmentSync', function()
    Equipment.syncAll(source)
end)

CreateThread(function()
    Wait(1200)
    if not cfg().enabled then return end
    for itemType in pairs(cfg().types or {}) do
        QBCore.Functions.CreateUseableItem(itemType, function(source)
            TriggerClientEvent('mrp_drugs:client:startPlaceEquipment', source, itemType)
        end)
    end
end)

return Equipment
