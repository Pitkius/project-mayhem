--- Server: įrangos DB (fivempro_drugs_equipment), sync, craft validacija.
--- Eksportuoja global `Equipment` — naudoja server/main.lua startCraftAtEquipment.
local QBCore = exports['qb-core']:GetCoreObject()

Equipment = Equipment or { byId = {}, nextFixedId = -1 }
-- Apsaugo vieno žaidėjo lygiagrečius placement eventus nuo vieno stalo limito apėjimo.
local placementLocks = {}

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

    -- Vienkartinių duomenų migracijų žymės neleidžia destruktyvaus valymo kartoti per kiekvieną restartą.
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `fivempro_drugs_equipment_migrations` (
        `migration_key` varchar(100) NOT NULL,
        `applied_at` datetime NOT NULL DEFAULT current_timestamp(),
        PRIMARY KEY (`migration_key`)
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
        -- Runtime laikmatis sąmoningai nesaugomas DB: po restarto prasideda naujos 10 min.
        lastActivityAt = GetGameTimer(),
        busy = false,
    }
end

function Equipment.get(id)
    return Equipment.byId[tonumber(id)]
end

function Equipment.list()
    local out = {}
    for _, e in pairs(Equipment.byId) do
        local row = {
            id = e.id,
            citizenid = e.citizenid,
            itemType = e.itemType,
            x = e.x,
            y = e.y,
            z = e.z,
            heading = e.heading,
            fixed = e.fixed == true,
            label = e.label,
            products = e.products,
            busy = e.busy == true,
        }
        local t = typeCfg(e.itemType)
        local idleTimeoutMs = tonumber(t and t.idleTimeoutMs)
        if not e.fixed and idleTimeoutMs and idleTimeoutMs > 0 then
            -- Klientas gauna serverio apskaičiuotą likutį, o ne pasirenka laiką pats.
            row.remainingMs = math.max(0, idleTimeoutMs - (GetGameTimer() - (e.lastActivityAt or GetGameTimer())))
        end
        out[#out + 1] = row
    end
    return out
end

function Equipment.syncAll(target)
    TriggerClientEvent('mrp_drugs:client:syncEquipment', target or -1, Equipment.list())
end

function Equipment.syncState(equipmentId, target)
    local e = Equipment.get(equipmentId)
    if not e then return end
    local t = typeCfg(e.itemType)
    local idleTimeoutMs = tonumber(t and t.idleTimeoutMs) or 0
    TriggerClientEvent('mrp_drugs:client:updateEquipmentState', target or -1, {
        id = e.id,
        busy = e.busy == true,
        remainingMs = math.max(0, idleTimeoutMs - (GetGameTimer() - (e.lastActivityAt or GetGameTimer()))),
    })
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

local function runMigrations()
    -- Ši migracija vieną kartą panaikina visus iki naujos Cayo sistemos žaidėjų padėtus stalus.
    -- migration_key užtikrina, kad po kitų restartų naujai padėti stalai nebebus trinami.
    local migrationKey = 'remove_legacy_portable_bagging_tables_v1'
    local applied = MySQL.scalar.await(
        'SELECT 1 FROM fivempro_drugs_equipment_migrations WHERE migration_key = ? LIMIT 1',
        { migrationKey }
    )
    if applied then return end

    -- DELETE ir žymė vykdomi vienoje transakcijoje: jei valymas nepavyksta, migracija nelieka pažymėta.
    local migrated = MySQL.transaction.await({
        {
            query = 'DELETE FROM fivempro_drugs_equipment WHERE item_type = ?',
            values = { 'bagging_table' },
        },
        {
            query = 'INSERT INTO fivempro_drugs_equipment_migrations (migration_key) VALUES (?)',
            values = { migrationKey },
        },
    })
    if not migrated then
        error('[mrp_drugs] Nepavyko vienkartinai išvalyti senų portable bagging_table.')
    end
end

local function countPlayerByType(citizenid, itemType)
    local n = 0
    for _, e in pairs(Equipment.byId) do
        if not e.fixed and e.citizenid == citizenid and e.itemType == itemType then
            n = n + 1
        end
    end
    return n
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

local function isInsideCayo(x, y, z)
    local placement = cfg().cayoPlacement or {}
    local center = placement.center or vector3(4840.57, -5174.42, 2.0)
    -- 1800 m sutampa su mrp_cayoperico MapRadius; mažesnis skaičius sumažintų leidžiamą zoną.
    local radius = tonumber(placement.radius) or 1800.0
    x, y, z = tonumber(x), tonumber(y), tonumber(z)
    if not x or not y or not z then return false end
    return #(vector3(x, y, z) - center) <= radius
end

function Equipment.isPlacementAllowed(eOrType, x, y, z)
    local e = type(eOrType) == 'table' and eOrType or nil
    local itemType = e and e.itemType or eOrType
    local t = typeCfg(itemType)
    if not t then return false end
    local checkX = e and e.x or x
    local checkY = e and e.y or y
    local checkZ = e and e.z or z
    if t.cayoOnly and not isInsideCayo(checkX, checkY, checkZ) then return false end
    return true
end

function Equipment.playerOwns(src, eOrId)
    local e = type(eOrId) == 'table' and eOrId or Equipment.get(eOrId)
    if not e or e.fixed then return false end
    local P = QBCore.Functions.GetPlayer(src)
    return P and P.PlayerData.citizenid == e.citizenid or false
end

function Equipment.canUse(src, eOrId)
    local e = type(eOrId) == 'table' and eOrId or Equipment.get(eOrId)
    if not e then return false end
    -- Fiksuotos kitų narkotikų laboratorijų vietos lieka viešos ir nepaveldėja portable savininko taisyklių.
    if e.fixed then return true end
    local t = typeCfg(e.itemType)
    if t and t.ownerOnly then
        return Equipment.playerOwns(src, e)
    end
    return true
end

function Equipment.setBusy(equipmentId, busy)
    local e = Equipment.get(equipmentId)
    if not e or e.fixed then return false end
    local t = typeCfg(e.itemType)
    if not t or not tonumber(t.idleTimeoutMs) then return false end

    -- Kiekviena naudojimo pradžia ir pabaiga iš naujo paleidžia pilną neveiklumo laiką.
    e.lastActivityAt = GetGameTimer()
    e.busy = busy == true
    Equipment.syncState(e.id)
    return true
end

function Equipment.isBusy(equipmentId)
    local e = Equipment.get(equipmentId)
    return e and e.busy == true or false
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
                products = loc.products,
            }
        end
    end
end

function Equipment.loadAll()
    ensureTable()
    runMigrations()
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

function Equipment.productAllowedAt(eOrType, productId)
    if not productId then return false end
    local e = type(eOrType) == 'table' and eOrType or nil
    local itemType = e and e.itemType or eOrType
    if e and e.products then
        for _, pid in ipairs(e.products) do
            if pid == productId then return true end
        end
        return false
    end
    local t = typeCfg(itemType)
    if not t then return false end
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

function Equipment.productsForEntity(e)
    if not e then return {} end
    if e.products then return e.products end
    return Equipment.productsForType(e.itemType)
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
    x, y, z, heading = tonumber(x), tonumber(y), tonumber(z), tonumber(heading) or 0.0
    if not x or not y or not z or x ~= x or y ~= y or z ~= z then return end
    if math.abs(x) > 10000 or math.abs(y) > 10000 or math.abs(z) > 2000 then return end
    -- Heading taip pat turi būti baigtinis; % 360 normalizuoja bet kokį teisėtą kampą į 0–359.99°.
    if heading ~= heading or math.abs(heading) == math.huge then return end
    heading = heading % 360.0
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return end
    local playerPos = GetEntityCoords(ped)
    local maxPlaceDistance = (tonumber(cfg().placeForwardM) or 1.35) + 2.0
    if #(playerPos - vector3(x, y, z)) > maxPlaceDistance then
        return TriggerClientEvent('QBCore:Notify', src, 'Įrangos vieta per toli.', 'error')
    end

    if not Equipment.isPlacementAllowed(itemType, x, y, z) then
        return TriggerClientEvent('QBCore:Notify', src, 'Šį stalą galima padėti tik Cayo Perico saloje.', 'error')
    end

    local typeLimit = tonumber(t.maxPerPlayer)
    if typeLimit and typeLimit > 0
        and countPlayerByType(P.PlayerData.citizenid, itemType) >= typeLimit then
        return TriggerClientEvent('QBCore:Notify', src, 'Jau turi pastatytą žolės džiovinimo stalą.', 'error')
    end

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

    local placementLockKey
    if typeLimit and typeLimit > 0 then
        placementLockKey = ('%s:%s'):format(P.PlayerData.citizenid, itemType)
        if placementLocks[placementLockKey] then
            return TriggerClientEvent('QBCore:Notify', src, 'Šis stalas jau statomas.', 'error')
        end
        placementLocks[placementLockKey] = true
    end

    if not exports['qb-inventory']:RemoveItem(src, itemType, 1, false, 'mrp_drugs:placeEquipment') then
        if placementLockKey then placementLocks[placementLockKey] = nil end
        return TriggerClientEvent('QBCore:Notify', src, 'Neturi įrangos.', 'error')
    end

    -- pcall užtikrina, kad DB išimtis nepaliktų sunaudoto itemo ir užrakinto placement.
    local insertOk, id = pcall(function()
        return MySQL.insert.await(
            'INSERT INTO fivempro_drugs_equipment (citizenid, item_type, x, y, z, heading) VALUES (?, ?, ?, ?, ?, ?)',
            { P.PlayerData.citizenid, itemType, x, y, z, heading }
        )
    end)
    if not insertOk or not id then
        -- Užraktas nuimamas prieš inventoriaus rollback, kad net jo klaida neužblokuotų kitų bandymų.
        if placementLockKey then placementLocks[placementLockKey] = nil end
        local refundOk, refunded = pcall(function()
            return exports['qb-inventory']:AddItem(
                src, itemType, 1, false, false, 'mrp_drugs:placeEquipment-rollback'
            )
        end)
        if not refundOk or not refunded then
            -- Po RemoveItem inventoriuje paprastai jau yra vietos; klaida aiškiai registruojama administracijai.
            print(('[mrp_drugs] KRITINĖ KLAIDA: nepavyko grąžinti %s žaidėjui %s po placement DB klaidos.')
                :format(itemType, P.PlayerData.citizenid))
            TriggerClientEvent(
                'QBCore:Notify',
                src,
                'Nepavyko grąžinti stalo po DB klaidos — kreipkitės į administraciją.',
                'error'
            )
        end
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
        -- Naujas stalas pradeda pilną 10 minučių serverio veikimo laikmatį.
        lastActivityAt = GetGameTimer(),
        busy = false,
    }
    Equipment.byId[e.id] = e
    if placementLockKey then placementLocks[placementLockKey] = nil end
    Equipment.syncAll()
    TriggerClientEvent('QBCore:Notify', src, ('Pastatyta: %s'):format(t.label or itemType), 'success')
end)

RegisterNetEvent('mrp_drugs:server:pickupEquipment', function(equipmentId)
    local src = source
    local e = Equipment.get(equipmentId)
    if not e or e.fixed then return end
    if not Equipment.playerNear(src, equipmentId) then return end
    if not canPickup(src, e) then return end
    if e.busy then
        return TriggerClientEvent('QBCore:Notify', src, 'Negalima surinkti šiuo metu naudojamo stalo.', 'error')
    end

    local P = QBCore.Functions.GetPlayer(src)
    if not P then return end
    if GetResourceState('qb-inventory') == 'started' then
        local canAdd = exports['qb-inventory']:CanAddItem(src, e.itemType, 1)
        if not canAdd then
            return TriggerClientEvent('QBCore:Notify', src, 'Inventoriuje nėra vietos įrangai.', 'error')
        end
    end

    MySQL.update.await('DELETE FROM fivempro_drugs_equipment WHERE id = ?', { e.id })
    Equipment.byId[e.id] = nil
    if not exports['qb-inventory']:AddItem(src, e.itemType, 1, false, false, 'mrp_drugs:pickupEquipment') then
        local id = MySQL.insert.await(
            'INSERT INTO fivempro_drugs_equipment (citizenid, item_type, x, y, z, heading) VALUES (?, ?, ?, ?, ?, ?)',
            { e.citizenid, e.itemType, e.x, e.y, e.z, e.heading or 0.0 }
        )
        if id then
            e.id = tonumber(id)
            Equipment.byId[e.id] = e
        end
        Equipment.syncAll()
        return TriggerClientEvent('QBCore:Notify', src, 'Nepavyko paimti įrangos į inventorių.', 'error')
    end
    Equipment.syncAll()
    TriggerClientEvent('QBCore:Notify', src, 'Įranga surinkta.', 'success')
end)

QBCore.Functions.CreateCallback('mrp_drugs:server:getEquipmentMenu', function(src, cb, equipmentId)
    local e = Equipment.get(equipmentId)
    if not e then return cb({ ok = false, reason = 'Įranga nerasta.' }) end
    if not Equipment.playerNear(src, equipmentId) then
        return cb({ ok = false, reason = 'Per toli nuo įrangos.' })
    end
    if not Equipment.canUse(src, e) then
        return cb({ ok = false, reason = 'Šis stalas priklauso kitam žaidėjui.' })
    end
    if e.busy then
        return cb({ ok = false, reason = 'Šis stalas šiuo metu naudojamas.' })
    end
    if not e.fixed and not Equipment.isPlacementAllowed(e, e.x, e.y, e.z) then
        return cb({ ok = false, reason = 'Stalas nėra Cayo Perico saloje.' })
    end
    local P = QBCore.Functions.GetPlayer(src)
    if not P then return cb({ ok = false }) end

    local rows = {}
    for _, productId in ipairs(Equipment.productsForEntity(e)) do
        local prod = Config.Products and Config.Products[productId]
        if prod and prod.minigame == 'schedule' and productId ~= 'amp_process' then
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

local function notifyEquipmentOwner(e, message)
    if not e or not e.citizenid then return end
    for _, playerSource in ipairs(GetPlayers()) do
        local P = QBCore.Functions.GetPlayer(tonumber(playerSource))
        if P and P.PlayerData.citizenid == e.citizenid then
            TriggerClientEvent('QBCore:Notify', tonumber(playerSource), message, 'error')
            return
        end
    end
end

CreateThread(function()
    while true do
        -- 1 sek. tikrinimas leidžia MM:SS hologramai ir subyrėjimui neatsilikti pastebimai.
        Wait(1000)
        local now = GetGameTimer()
        local expired = {}
        for id, e in pairs(Equipment.byId) do
            local t = not e.fixed and typeCfg(e.itemType) or nil
            local timeoutMs = tonumber(t and t.idleTimeoutMs)
            if timeoutMs and timeoutMs > 0 and not e.busy
                and now - (e.lastActivityAt or now) >= timeoutMs then
                -- Užrakiname prieš DB await, kad tuo pačiu metu nebeprasidėtų gamyba.
                e.busy = true
                e.expiring = true
                expired[#expired + 1] = { id = id, equipment = e }
            end
        end

        for _, entry in ipairs(expired) do
            local e = entry.equipment
            local affected = MySQL.update.await(
                'DELETE FROM fivempro_drugs_equipment WHERE id = ? AND item_type = ?',
                { e.id, e.itemType }
            )
            if affected and affected > 0 and Equipment.byId[entry.id] == e then
                Equipment.byId[entry.id] = nil
                TriggerClientEvent('mrp_drugs:client:removeEquipment', -1, entry.id)
                -- Subyrėjęs stalas itemo negrąžina; prisijungęs savininkas gauna pranešimą.
                notifyEquipmentOwner(e, 'Jūsų stalas subyrėjo.')
            elseif Equipment.byId[entry.id] == e then
                e.busy = false
                e.expiring = nil
                e.lastActivityAt = GetGameTimer()
                Equipment.syncState(e.id)
            end
        end
    end
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
