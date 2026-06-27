local QBCore = exports['qb-core']:GetCoreObject()

Printers3d = Printers3d or { byId = {} }
local pendingPrint = {}

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

local function cfg()
    return Config.Printer3d or {}
end

local function ensureTable()
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `fivempro_drugs_printers` (
        `id` int(11) NOT NULL AUTO_INCREMENT,
        `citizenid` varchar(50) NOT NULL,
        `x` double NOT NULL,
        `y` double NOT NULL,
        `z` double NOT NULL,
        `heading` float NOT NULL DEFAULT 0,
        `created_at` datetime NOT NULL DEFAULT current_timestamp(),
        PRIMARY KEY (`id`),
        KEY `citizenid` (`citizenid`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;]])
end

local function rowToPrinter(r)
    return {
        id = tonumber(r.id),
        citizenid = r.citizenid,
        x = r.x + 0.0,
        y = r.y + 0.0,
        z = r.z + 0.0,
        heading = r.heading + 0.0,
    }
end

function Printers3d.loadAll()
    ensureTable()
    Printers3d.byId = {}
    local rows = MySQL.query.await('SELECT id, citizenid, x, y, z, heading FROM fivempro_drugs_printers') or {}
    for _, r in ipairs(rows) do
        local p = rowToPrinter(r)
        Printers3d.byId[p.id] = p
    end
end

function Printers3d.list()
    local out = {}
    for _, p in pairs(Printers3d.byId) do
        out[#out + 1] = p
    end
    return out
end

function Printers3d.get(id)
    return Printers3d.byId[tonumber(id)]
end

function Printers3d.syncAll(target)
    TriggerClientEvent('mrp_drugs:client:syncPrinters', target or -1, Printers3d.list())
end

local function isAdmin(src)
    return QBCore.Functions.HasPermission(src, 'admin') or QBCore.Functions.HasPermission(src, 'god')
end

local function canPickup(src, printer)
    if not printer then return false end
    local P = QBCore.Functions.GetPlayer(src)
    if not P then return false end
    if isAdmin(src) then return true end
    return P.PlayerData.citizenid == printer.citizenid
end

local function playerNearPrinter(src, printer, extra)
    if not printer then return false end
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end
    local c = GetEntityCoords(ped)
    local dist = ((cfg().pickupDist) or 2.8) + (extra or 0.0)
    return #(c - vector3(printer.x, printer.y, printer.z)) <= dist
end

local function countOwned(citizenid)
    local n = 0
    for _, p in pairs(Printers3d.byId) do
        if p.citizenid == citizenid then
            n = n + 1
        end
    end
    return n
end

local function getProduct(id)
    local products = cfg().products or {}
    return products[id]
end

local function hasIngredients(Player, product)
    for _, row in ipairs(product.ingredients or {}) do
        local it = Player.Functions.GetItemByName(row.item)
        if not it or (it.amount or 0) < row.count then
            return false
        end
    end
    return true
end

local function removeIngredients(Player, product)
    for _, row in ipairs(product.ingredients or {}) do
        if not Player.Functions.RemoveItem(row.item, row.count) then
            return false
        end
    end
    return true
end

local function refundIngredients(src, product)
    local P = QBCore.Functions.GetPlayer(src)
    if not P or not product then return end
    for _, row in ipairs(product.ingredients or {}) do
        P.Functions.AddItem(row.item, row.count)
        local shared = resolveSharedItem(row.item)
        if shared then
            TriggerClientEvent('qb-inventory:client:ItemBox', src, shared, 'add', row.count)
        end
    end
end

local function buildProductRows(Player)
    local rows = {}
    for id, prod in pairs(cfg().products or {}) do
        local ing = {}
        local canCraft = true
        for _, row in ipairs(prod.ingredients or {}) do
            local it = Player.Functions.GetItemByName(row.item)
            local have = it and it.amount or 0
            local missing = math.max(0, row.count - have)
            if missing > 0 then canCraft = false end
            local label = (resolveSharedItem(row.item) or {}).label or row.item
            ing[#ing + 1] = ('%s %d/%d'):format(label, have, row.count)
        end
        local out = prod.output or {}
        local outLabel = (resolveSharedItem(out.item) or {}).label or out.item
        rows[#rows + 1] = {
            id = id,
            label = prod.label or id,
            outputLabel = outLabel,
            outputCount = out.count or 1,
            timeSec = math.ceil((tonumber(prod.timeMs) or 30000) / 1000),
            ingredients = ing,
            canCraft = canCraft,
        }
    end
    table.sort(rows, function(a, b) return a.label < b.label end)
    return rows
end

RegisterNetEvent('mrp_drugs:server:placePrinter', function(x, y, z, heading)
    local src = source
    local c = cfg()
    local item = c.item or 'printer_3d'
    local P = QBCore.Functions.GetPlayer(src)
    if not P then return end
    if not P.Functions.GetItemByName(item) then
        return TriggerClientEvent('QBCore:Notify', src, 'Neturi 3D spausdintuvo.', 'error')
    end
    x, y, z, heading = tonumber(x), tonumber(y), tonumber(z), tonumber(heading)
    if not x or not y or not z then return end

    local maxN = tonumber(c.maxPerPlayer) or 2
    if countOwned(P.PlayerData.citizenid) >= maxN then
        return TriggerClientEvent('QBCore:Notify', src, ('Galima turėti ne daugiau nei %d spausdintuvus išdėstytus.'):format(maxN), 'error')
    end

    if not P.Functions.RemoveItem(item, 1) then
        return TriggerClientEvent('QBCore:Notify', src, 'Nepavyko paimti itemo.', 'error')
    end
    local shared = resolveSharedItem(item)
    if shared then
        TriggerClientEvent('qb-inventory:client:ItemBox', src, shared, 'remove', 1)
    end

    local id = MySQL.insert.await(
        'INSERT INTO fivempro_drugs_printers (citizenid, x, y, z, heading) VALUES (?, ?, ?, ?, ?)',
        { P.PlayerData.citizenid, x, y, z, heading or 0.0 }
    )
    local printer = {
        id = id,
        citizenid = P.PlayerData.citizenid,
        x = x, y = y, z = z,
        heading = heading or 0.0,
    }
    Printers3d.byId[id] = printer
    Printers3d.syncAll()
    TriggerClientEvent('QBCore:Notify', src, '3D spausdintuvas padėtas.', 'success')
end)

RegisterNetEvent('mrp_drugs:server:pickupPrinter', function(printerId)
    local src = source
    printerId = tonumber(printerId)
    local printer = Printers3d.get(printerId)
    if not printer then
        return TriggerClientEvent('QBCore:Notify', src, 'Spausdintuvas nerastas.', 'error')
    end
    if not canPickup(src, printer) then
        return TriggerClientEvent('QBCore:Notify', src, 'Gali surinkti tik savo spausdintuvą arba admin.', 'error')
    end
    if not playerNearPrinter(src, printer, 1.2) then
        return TriggerClientEvent('QBCore:Notify', src, 'Per toli.', 'error')
    end

    MySQL.query.await('DELETE FROM fivempro_drugs_printers WHERE id = ?', { printerId })
    Printers3d.byId[printerId] = nil
    local P = QBCore.Functions.GetPlayer(src)
    if P then
        local item = cfg().item or 'printer_3d'
        P.Functions.AddItem(item, 1)
        local shared = resolveSharedItem(item)
        if shared then
            TriggerClientEvent('qb-inventory:client:ItemBox', src, shared, 'add', 1)
        end
    end
    Printers3d.syncAll()
    TriggerClientEvent('QBCore:Notify', src, '3D spausdintuvas surinktas.', 'success')
end)

QBCore.Functions.CreateCallback('mrp_drugs:server:getPrinterMenu', function(src, cb, printerId)
    local P = QBCore.Functions.GetPlayer(src)
    if not P then return cb(nil) end
    local printer = Printers3d.get(printerId)
    if not printer or not playerNearPrinter(src, printer, 0.5) then
        return cb(nil)
    end
    cb(buildProductRows(P))
end)

RegisterNetEvent('mrp_drugs:server:startPrinterCraft', function(printerId, productId)
    local src = source
    if pendingPrint[src] then return end
    printerId = tonumber(printerId)
    productId = tostring(productId or '')
    local printer = Printers3d.get(printerId)
    local product = getProduct(productId)
    local P = QBCore.Functions.GetPlayer(src)
    if not P or not printer or not product then
        return TriggerClientEvent('QBCore:Notify', src, 'Netinkamas spausdinimas.', 'error')
    end
    if not playerNearPrinter(src, printer, 0.5) then
        return TriggerClientEvent('QBCore:Notify', src, 'Per toli nuo spausdintuvo.', 'error')
    end
    if not hasIngredients(P, product) then
        return TriggerClientEvent('QBCore:Notify', src, 'Trūksta medžiagų.', 'error')
    end
    if not removeIngredients(P, product) then
        return TriggerClientEvent('QBCore:Notify', src, 'Nepavyko paimti medžiagų.', 'error')
    end
    for _, row in ipairs(product.ingredients or {}) do
        local shared = resolveSharedItem(row.item)
        if shared then
            TriggerClientEvent('qb-inventory:client:ItemBox', src, shared, 'remove', row.count)
        end
    end
    pendingPrint[src] = {
        printerId = printerId,
        productId = productId,
        started = os.time(),
        timeMs = tonumber(product.timeMs) or 30000,
    }
    TriggerClientEvent('mrp_drugs:client:printerCraftStarted', src, printerId, productId, pendingPrint[src].timeMs)
end)

RegisterNetEvent('mrp_drugs:server:cancelPrinterCraft', function()
    local src = source
    local pend = pendingPrint[src]
    if not pend then return end
    pendingPrint[src] = nil
    refundIngredients(src, getProduct(pend.productId))
    TriggerClientEvent('QBCore:Notify', src, 'Spausdinimas atšauktas.', 'error')
end)

RegisterNetEvent('mrp_drugs:server:finishPrinterCraft', function(printerId, productId)
    local src = source
    local pend = pendingPrint[src]
    if not pend or pend.printerId ~= tonumber(printerId) or pend.productId ~= tostring(productId or '') then
        return TriggerClientEvent('QBCore:Notify', src, 'Spausdinimas negalioja.', 'error')
    end
    pendingPrint[src] = nil

    local printer = Printers3d.get(printerId)
    local product = getProduct(productId)
    local P = QBCore.Functions.GetPlayer(src)
    if not P or not printer or not product then return end
    if not playerNearPrinter(src, printer, 0.5) then
        refundIngredients(src, product)
        return TriggerClientEvent('QBCore:Notify', src, 'Per toli — medžiagos grąžintos.', 'error')
    end

    local elapsed = (os.time() - (pend.started or os.time())) * 1000
    local need = math.floor((tonumber(product.timeMs) or 30000) * 0.85)
    if elapsed < need then
        refundIngredients(src, product)
        return TriggerClientEvent('QBCore:Notify', src, 'Spausdinimas per greitas.', 'error')
    end

    local out = product.output or {}
    local count = tonumber(out.count) or 1
    local item = out.item
    if not item or not P.Functions.AddItem(item, count) then
        refundIngredients(src, product)
        return TriggerClientEvent('QBCore:Notify', src, 'Inventorius pilnas.', 'error')
    end
    local shared = resolveSharedItem(item)
    if shared then
        TriggerClientEvent('qb-inventory:client:ItemBox', src, shared, 'add', count)
    end
    TriggerClientEvent('QBCore:Notify', src, ('Atspausdinta: %s'):format(shared and shared.label or item), 'success')
end)

AddEventHandler('playerDropped', function()
    pendingPrint[source] = nil
end)

CreateThread(function()
    Wait(500)
    Printers3d.loadAll()
    Printers3d.syncAll()
end)

AddEventHandler('onResourceStart', function(res)
    if res ~= GetCurrentResourceName() then return end
    Printers3d.loadAll()
    Printers3d.syncAll()
end)

AddEventHandler('QBCore:Server:PlayerLoaded', function(Player)
    local src = Player and Player.PlayerData and Player.PlayerData.source
    if src then Printers3d.syncAll(src) end
end)

CreateThread(function()
    Wait(800)
    local item = cfg().item or 'printer_3d'
    QBCore.Functions.CreateUseableItem(item, function(source)
        TriggerClientEvent('mrp_drugs:client:startPlacePrinter', source)
    end)
end)
