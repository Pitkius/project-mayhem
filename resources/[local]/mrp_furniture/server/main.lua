local QBCore = exports['qb-core']:GetCoreObject()

--- [property_id] = { { id, item_key, x, y, z, rx, ry, rz, meta }, ... }
local FurnitureByProperty = {}

MySQL.ready(function()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `fivempro_furniture` (
            `id` INT NOT NULL AUTO_INCREMENT,
            `property_id` VARCHAR(64) NOT NULL,
            `item_key` VARCHAR(64) NOT NULL,
            `x` FLOAT NOT NULL,
            `y` FLOAT NOT NULL,
            `z` FLOAT NOT NULL,
            `rx` FLOAT NOT NULL DEFAULT 0,
            `ry` FLOAT NOT NULL DEFAULT 0,
            `rz` FLOAT NOT NULL DEFAULT 0,
            `meta` LONGTEXT NULL,
            PRIMARY KEY (`id`),
            KEY `idx_fpmf_property` (`property_id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])

    local rows = MySQL.query.await('SELECT * FROM fivempro_furniture', {}) or {}
    FurnitureByProperty = {}
    for _, row in ipairs(rows) do
        local pid = row.property_id
        FurnitureByProperty[pid] = FurnitureByProperty[pid] or {}
        FurnitureByProperty[pid][#FurnitureByProperty[pid] + 1] = {
            id = row.id,
            item_key = row.item_key,
            x = row.x + 0.0,
            y = row.y + 0.0,
            z = row.z + 0.0,
            rx = row.rx + 0.0,
            ry = row.ry + 0.0,
            rz = row.rz + 0.0,
            meta = row.meta,
        }
    end
    print(('[^2mrp_furniture^7] Loaded %s furniture rows'):format(#rows))
end)

local function getCitizenId(src)
    local p = QBCore.Functions.GetPlayer(src)
    return p and p.PlayerData.citizenid or nil
end

local function hasAccess(src, propertyId)
    if GetResourceState('mrp_housing') ~= 'started' then return false end
    return exports['mrp_housing']:HasFullAccess(src, propertyId) == true
end

local function countFurniture(propertyId)
    local list = FurnitureByProperty[propertyId]
    return list and #list or 0
end

local function insertFurniture(propertyId, itemKey, x, y, z, rx, ry, rz, meta)
    local id = MySQL.insert.await(
        'INSERT INTO fivempro_furniture (property_id, item_key, x, y, z, rx, ry, rz, meta) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
        { propertyId, itemKey, x, y, z, rx or 0, ry or 0, rz or 0, meta and json.encode(meta) or nil }
    )
    if not id then return nil end
    local row = {
        id = id,
        item_key = itemKey,
        x = x, y = y, z = z,
        rx = rx or 0, ry = ry or 0, rz = rz or 0,
        meta = meta and json.encode(meta) or nil,
    }
    FurnitureByProperty[propertyId] = FurnitureByProperty[propertyId] or {}
    FurnitureByProperty[propertyId][#FurnitureByProperty[propertyId] + 1] = row
    return row
end

--- Furnished presets after purchase
exports('ApplyFurnishedPresets', function(propertyId, interiorKey)
    if not propertyId or not interiorKey then return false end
    local presets = Config.Presets and Config.Presets[interiorKey]
    if not presets then return false end

    local enterCoords = nil
    if GetResourceState('mrp_housing') == 'started' then
        local ok, result = pcall(function()
            return exports['mrp_housing']:GetInteriorEnter(interiorKey)
        end)
        if ok then enterCoords = result end
    end
    if not enterCoords then
        print(('[^3mrp_furniture^7] No enter coords for interior %s — presets skipped'):format(tostring(interiorKey)))
        return false
    end

    local ex, ey, ez = enterCoords.x, enterCoords.y, enterCoords.z
    local eh = enterCoords.w or 0.0
    local rad = math.rad(eh)

    for _, p in ipairs(presets) do
        if Config.Catalog[p.key] then
            local lx, ly = p.x or 0.0, p.y or 0.0
            local wx = ex + (lx * math.cos(rad) - ly * math.sin(rad))
            local wy = ey + (lx * math.sin(rad) + ly * math.cos(rad))
            local wz = ez + (p.z or 0.0)
            local wh = (eh + (p.h or 0.0)) % 360.0
            insertFurniture(propertyId, p.key, wx, wy, wz, 0.0, 0.0, wh, { preset = true })
        end
    end
    return true
end)

QBCore.Functions.CreateCallback('mrp_furniture:server:getPropertyFurniture', function(src, cb, propertyId)
    local inside = exports['mrp_housing']:GetInsidePropertyId(src)
    if inside ~= propertyId and not hasAccess(src, propertyId) then
        return cb({})
    end
    cb(FurnitureByProperty[propertyId] or {})
end)

RegisterNetEvent('mrp_furniture:server:place', function(propertyId, itemKey, coords, heading, slot)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    if type(propertyId) ~= 'string' or type(itemKey) ~= 'string' then return end
    if not hasAccess(src, propertyId) then
        return TriggerClientEvent('QBCore:Notify', src, 'Neturite teisės statyti baldų.', 'error')
    end
    local inside = exports['mrp_housing']:GetInsidePropertyId(src)
    if inside ~= propertyId then
        return TriggerClientEvent('QBCore:Notify', src, 'Baldus galima statyti tik name.', 'error')
    end
    local entry = FPMFurniture.GetEntry(itemKey)
    if not entry then
        return TriggerClientEvent('QBCore:Notify', src, 'Nežinomas baldas.', 'error')
    end

    local pClass = exports['mrp_housing']:GetPropertyClass(propertyId) or 'standard'
    local cap = FPMFurniture.GetCap(pClass)
    if countFurniture(propertyId) >= cap then
        return TriggerClientEvent('QBCore:Notify', src, ('Pasiektas baldų limitas (%s).'):format(cap), 'error')
    end

    local itemName = FPMFurniture.ItemName(itemKey)
    local removed = exports['qb-inventory']:RemoveItem(src, itemName, 1, slot, 'mrp_furniture:place')
    if not removed then
        return TriggerClientEvent('QBCore:Notify', src, 'Neturite šio baldo inventoriuje.', 'error')
    end

    local x = coords and coords.x
    local y = coords and coords.y
    local z = coords and coords.z
    if not x or not y or not z then
        exports['qb-inventory']:AddItem(src, itemName, 1, false, {}, 'mrp_furniture:place_refund')
        return
    end

    local row = insertFurniture(propertyId, itemKey, x, y, z, 0.0, 0.0, heading or 0.0, nil)
    if not row then
        exports['qb-inventory']:AddItem(src, itemName, 1, false, {}, 'mrp_furniture:place_refund')
        return TriggerClientEvent('QBCore:Notify', src, 'Nepavyko išsaugoti baldo.', 'error')
    end

    TriggerClientEvent('mrp_furniture:client:addPiece', -1, propertyId, row)
    TriggerClientEvent('QBCore:Notify', src, ('Pastatyta: %s'):format(entry.label), 'success')
end)

RegisterNetEvent('mrp_furniture:server:pickup', function(propertyId, furnitureId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    if not hasAccess(src, propertyId) then
        return TriggerClientEvent('QBCore:Notify', src, 'Neturite teisės paimti baldų.', 'error')
    end
    local inside = exports['mrp_housing']:GetInsidePropertyId(src)
    if inside ~= propertyId then
        return TriggerClientEvent('QBCore:Notify', src, 'Baldus galima paimti tik name.', 'error')
    end

    local list = FurnitureByProperty[propertyId]
    if not list then return end
    local idx, row = nil, nil
    for i, f in ipairs(list) do
        if f.id == furnitureId then
            idx, row = i, f
            break
        end
    end
    if not row then return end

    MySQL.update.await('DELETE FROM fivempro_furniture WHERE id = ?', { furnitureId })
    table.remove(list, idx)

    local itemName = FPMFurniture.ItemName(row.item_key)
    exports['qb-inventory']:AddItem(src, itemName, 1, false, {}, 'mrp_furniture:pickup')
    TriggerClientEvent('mrp_furniture:client:removePiece', -1, propertyId, furnitureId)
    TriggerClientEvent('QBCore:Notify', src, 'Baldas paimtas į inventorių.', 'success')
end)

RegisterNetEvent('mrp_furniture:server:openSafe', function(propertyId, furnitureId)
    local src = source
    if not hasAccess(src, propertyId) then
        return TriggerClientEvent('QBCore:Notify', src, 'Neturite prieigos prie seifo.', 'error')
    end
    local list = FurnitureByProperty[propertyId]
    if not list then return end
    local row = nil
    for _, f in ipairs(list) do
        if f.id == furnitureId then row = f break end
    end
    if not row then return end
    local entry = FPMFurniture.GetEntry(row.item_key)
    if not entry or entry.interact ~= 'safe' then return end

    local stashId = ('furn_safe_%s'):format(furnitureId)
    exports['qb-inventory']:OpenInventory(src, stashId, {
        label = entry.label or 'Seifas',
        maxweight = entry.stashWeight or 50000,
        slots = entry.stashSlots or 10,
    })
end)

--- Register useable furniture items
CreateThread(function()
    Wait(1000)
    for key in pairs(Config.Catalog or {}) do
        local itemName = FPMFurniture.ItemName(key)
        QBCore.Functions.CreateUseableItem(itemName, function(source, item)
            TriggerClientEvent('mrp_furniture:client:startPlace', source, key, item and item.slot)
        end)
    end
end)

--- Shop
CreateThread(function()
    Wait(1500)
    exports['qb-inventory']:CreateShop({
        name = 'mrp_furniture_shop',
        label = Config.Shop.label or 'Baldų parduotuvė',
        slots = 40,
        items = FPMFurniture.BuildShopItems(),
    })
end)

RegisterNetEvent('mrp_furniture:server:openShop', function()
    local src = source
    local ped = GetPlayerPed(src)
    if ped == 0 then return end
    local coords = GetEntityCoords(ped)
    local shop = Config.Shop.coords
    if #(coords - vector3(shop.x, shop.y, shop.z)) > 4.0 then
        return TriggerClientEvent('QBCore:Notify', src, 'Per toli nuo parduotuvės.', 'error')
    end
    exports['qb-inventory']:OpenShop(src, 'mrp_furniture_shop')
end)
