local QBCore = exports['qb-core']:GetCoreObject()

--- [property_id] = { citizenid, interior_key, price_paid, locked }
local Ownership = {}

--- [property_id] = { [citizenid] = true }
local Keys = {}

--- [src] = propertyId — kas šiuo metu namo interjere
local InsidePlayers = {}

local function safeAddColumn(tableName, columnName, definition)
    local exists = MySQL.single.await(
        ('SELECT COUNT(*) AS c FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ? AND COLUMN_NAME = ?'),
        { tableName, columnName }
    )
    if exists and tonumber(exists.c) and tonumber(exists.c) > 0 then return end
    MySQL.query.await(('ALTER TABLE `%s` ADD COLUMN `%s` %s'):format(tableName, columnName, definition))
end

MySQL.ready(function()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `fivempro_property_ownership` (
            `property_id` VARCHAR(64) NOT NULL,
            `citizenid` VARCHAR(50) NOT NULL,
            `interior_key` VARCHAR(32) NOT NULL,
            `price_paid` INT NOT NULL DEFAULT 0,
            `locked` TINYINT(1) NOT NULL DEFAULT 1,
            `furnished` TINYINT(1) NOT NULL DEFAULT 0,
            `purchased_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`property_id`),
            KEY `idx_fpmho_citizenid` (`citizenid`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])

    safeAddColumn('fivempro_property_ownership', 'furnished', 'TINYINT(1) NOT NULL DEFAULT 0')

    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `fivempro_property_keys` (
            `id` INT NOT NULL AUTO_INCREMENT,
            `property_id` VARCHAR(64) NOT NULL,
            `citizenid` VARCHAR(50) NOT NULL,
            `granted_by` VARCHAR(50) DEFAULT NULL,
            `granted_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`),
            UNIQUE KEY `uq_fpmhk_property_citizen` (`property_id`, `citizenid`),
            KEY `idx_fpmhk_citizenid` (`citizenid`),
            KEY `idx_fpmhk_property` (`property_id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])

    local rows = MySQL.query.await('SELECT * FROM fivempro_property_ownership', {}) or {}
    Ownership = {}
    for _, row in ipairs(rows) do
        Ownership[row.property_id] = {
            citizenid = row.citizenid,
            interior_key = row.interior_key,
            price_paid = row.price_paid,
            locked = tonumber(row.locked) == 1,
            furnished = tonumber(row.furnished) == 1,
        }
    end

    local keyRows = MySQL.query.await('SELECT property_id, citizenid FROM fivempro_property_keys', {}) or {}
    Keys = {}
    for _, row in ipairs(keyRows) do
        Keys[row.property_id] = Keys[row.property_id] or {}
        Keys[row.property_id][row.citizenid] = true
    end

    print(('[^2mrp_housing^7] Loaded %s owners, %s key rows'):format(#rows, #keyRows))
end)

local function broadcastOwnership()
    TriggerClientEvent('mrp_housing:client:syncOwnership', -1, Ownership)
end

local function broadcastKeys()
    TriggerClientEvent('mrp_housing:client:syncKeys', -1, Keys)
end

local function syncPlayer(src)
    TriggerClientEvent('mrp_housing:client:syncOwnership', src, Ownership)
    TriggerClientEvent('mrp_housing:client:syncKeys', src, Keys)
end

local function getCitizenId(src)
    local p = QBCore.Functions.GetPlayer(src)
    return p and p.PlayerData.citizenid or nil
end

local function getCharName(Player)
    if not Player then return 'Nežinomas' end
    local c = Player.PlayerData.charinfo or {}
    local first = c.firstname or ''
    local last = c.lastname or ''
    local name = (first .. ' ' .. last):gsub('^%s+', ''):gsub('%s+$', '')
    if name == '' then return GetPlayerName(Player.PlayerData.source) or 'Nežinomas' end
    return name
end

local function countOwned(citizenid)
    local n = 0
    for _, o in pairs(Ownership) do
        if o.citizenid == citizenid then n = n + 1 end
    end
    return n
end

local function hasKey(propertyId, citizenid)
    if not propertyId or not citizenid then return false end
    local set = Keys[propertyId]
    return set and set[citizenid] == true
end

local function isOwner(propertyId, citizenid)
    local owner = Ownership[propertyId]
    return owner and owner.citizenid == citizenid
end

--- Savininkas arba raktų turėtojas — įėjimas (užrakinta) + sandėlis
local function hasFullAccess(propertyId, citizenid)
    return isOwner(propertyId, citizenid) or hasKey(propertyId, citizenid)
end

local function forceExitPlayer(src, reason)
    local propertyId = InsidePlayers[src]
    if not propertyId then return end
    InsidePlayers[src] = nil
    SetPlayerRoutingBucket(src, 0)
    TriggerClientEvent('mrp_housing:client:forceExit', src, reason or 'Prieiga atšaukta.')
end

local function kickKeyHoldersFromProperty(propertyId, citizenid)
    for _, playerId in ipairs(QBCore.Functions.GetPlayers()) do
        local src = tonumber(playerId)
        if src and InsidePlayers[src] == propertyId then
            if getCitizenId(src) == citizenid then
                forceExitPlayer(src, 'Jūsų raktas buvo atšauktas.')
            end
        end
    end
end

local function buildCatalogFor(src)
    local citizenid = getCitizenId(src)
    local list = {}
    for i = 1, #(Config.Properties or {}) do
        local prop = Config.Properties[i]
        local owner = Ownership[prop.id]
        local pClass = FPMHousing.GetPropertyClass(prop)
        local interiors = {}
        for _, key in ipairs(FPMHousing.GetAllowedInteriorKeys(prop)) do
            local entry = FPMHousing.InteriorCatalogEntry(key, prop, false)
            if entry then interiors[#interiors + 1] = entry end
        end
        table.sort(interiors, function(a, b)
            if (a.tier or 0) ~= (b.tier or 0) then return (a.tier or 0) < (b.tier or 0) end
            return (a.priceUnfurnished or a.price) < (b.priceUnfurnished or b.price)
        end)
        local minPrice = interiors[1] and (interiors[1].priceUnfurnished or interiors[1].price) or Config.BasePrice
        list[#list + 1] = {
            id = prop.id,
            label = prop.label,
            type = prop.type,
            class = pClass,
            classLabel = (Config.ClassLabels and Config.ClassLabels[pClass]) or pClass,
            district = prop.district,
            districtLabel = Config.Districts[prop.district] and Config.Districts[prop.district].label or prop.district,
            door = { x = prop.door.x, y = prop.door.y, z = prop.door.z },
            owned = owner ~= nil,
            ownedByMe = owner and owner.citizenid == citizenid or false,
            ownedInteriorKey = owner and owner.interior_key or nil,
            ownedInteriorLabel = owner and Config.Interiors[owner.interior_key] and Config.Interiors[owner.interior_key].label or nil,
            ownedQualityLabel = owner and Config.Interiors[owner.interior_key] and Config.Interiors[owner.interior_key].qualityLabel or nil,
            ownedFurnished = owner and owner.furnished == true or false,
            ownerName = nil,
            locked = owner and owner.locked or false,
            hasKey = hasKey(prop.id, citizenid),
            interiors = interiors,
            minPrice = minPrice,
            furnishedMult = Config.FurnishedMult or 1.32,
            index = i,
        }
    end
    return list
end

local function giveDeed(src, Player, prop, interiorKey, price)
    if not QBCore.Shared.Items['house_deed'] then return end
    local info = {
        property_id = prop.id,
        label = prop.label,
        interior = Config.Interiors[interiorKey] and Config.Interiors[interiorKey].label or interiorKey,
        price = price,
        citizenid = Player.PlayerData.citizenid,
    }
    exports['qb-inventory']:AddItem(src, 'house_deed', 1, false, info, 'mrp_housing:purchase')
end

local function listKeyHolders(propertyId)
    local holders = {}
    local set = Keys[propertyId]
    if not set then return holders end
    for citizenid in pairs(set) do
        local name = citizenid
        local online = QBCore.Functions.GetPlayerByCitizenId(citizenid)
        if online then
            name = getCharName(online)
        else
            local row = MySQL.single.await('SELECT charinfo FROM players WHERE citizenid = ? LIMIT 1', { citizenid })
            if row and row.charinfo then
                local ok, info = pcall(json.decode, row.charinfo)
                if ok and type(info) == 'table' then
                    local n = ((info.firstname or '') .. ' ' .. (info.lastname or '')):gsub('^%s+', ''):gsub('%s+$', '')
                    if n ~= '' then name = n end
                end
            end
        end
        holders[#holders + 1] = {
            citizenid = citizenid,
            name = name,
            online = online ~= nil,
        }
    end
    table.sort(holders, function(a, b) return a.name < b.name end)
    return holders
end

RegisterNetEvent('mrp_housing:server:requestOpenAgency', function()
    local src = source
    local catalog = buildCatalogFor(src)
    TriggerClientEvent('mrp_housing:client:openAgency', src, {
        agencyLabel = Config.Agency.label,
        maxOwned = Config.MaxOwnedPerPlayer,
        properties = catalog,
        districts = Config.Districts,
        classLabels = Config.ClassLabels,
        furnishedMult = Config.FurnishedMult or 1.32,
    })
end)

QBCore.Functions.CreateCallback('mrp_housing:server:getOwnership', function(_, cb)
    cb(Ownership)
end)

QBCore.Functions.CreateCallback('mrp_housing:server:getKeys', function(_, cb)
    cb(Keys)
end)

QBCore.Functions.CreateCallback('mrp_housing:server:getKeyHolders', function(src, cb, propertyId)
    local citizenid = getCitizenId(src)
    if not isOwner(propertyId, citizenid) then
        return cb({})
    end
    cb(listKeyHolders(propertyId))
end)

QBCore.Functions.CreateCallback('mrp_housing:server:purchase', function(src, cb, propertyId, interiorKey, furnished)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return cb({ ok = false, msg = 'Žaidėjas nerastas.' }) end

    local prop = FPMHousing.GetProperty(propertyId)
    if not prop then return cb({ ok = false, msg = 'Objektas nerastas.' }) end
    if Ownership[propertyId] then return cb({ ok = false, msg = 'Šis objektas jau parduotas.' }) end

    local wantFurnished = furnished == true
    if not Config.Interiors[interiorKey]
        or not FPMHousing.InteriorAllowedForClass(interiorKey, FPMHousing.GetPropertyClass(prop)) then
        return cb({ ok = false, msg = 'Šis interjeras neleidžiamas šiai būsto klasei.' })
    end

    local citizenid = Player.PlayerData.citizenid
    if countOwned(citizenid) >= (Config.MaxOwnedPerPlayer or 2) then
        return cb({ ok = false, msg = ('Galima turėti daugiausiai %s objektus.'):format(Config.MaxOwnedPerPlayer) })
    end

    local price = FPMHousing.CalculatePrice(prop, interiorKey, wantFurnished)
    local account = Config.PaymentAccount or 'bank'
    local balance = Player.PlayerData.money[account] or 0
    if balance < price then
        return cb({ ok = false, msg = ('Nepakanka pinigų (%s). Reikia $%s.'):format(account, price) })
    end

    if not Player.Functions.RemoveMoney(account, price, 'mrp_housing:purchase') then
        return cb({ ok = false, msg = 'Mokėjimas nepavyko.' })
    end

    MySQL.insert.await(
        'INSERT INTO fivempro_property_ownership (property_id, citizenid, interior_key, price_paid, locked, furnished) VALUES (?, ?, ?, ?, 1, ?)',
        { propertyId, citizenid, interiorKey, price, wantFurnished and 1 or 0 }
    )

    Ownership[propertyId] = {
        citizenid = citizenid,
        interior_key = interiorKey,
        price_paid = price,
        locked = true,
        furnished = wantFurnished,
    }

    giveDeed(src, Player, prop, interiorKey, price)
    broadcastOwnership()

    if wantFurnished and GetResourceState('mrp_furniture') == 'started' then
        pcall(function()
            exports['mrp_furniture']:ApplyFurnishedPresets(propertyId, interiorKey)
        end)
    end

    local furnLabel = wantFurnished and 'su baldais' or 'be baldų'
    cb({
        ok = true,
        msg = ('Nupirkote „%s“ (%s) už $%s.'):format(prop.label, furnLabel, price),
        catalog = buildCatalogFor(src),
    })
end)

RegisterNetEvent('mrp_housing:server:toggleLock', function(propertyId)
    local src = source
    if type(propertyId) == 'table' then
        propertyId = propertyId.propertyId
    end
    local citizenid = getCitizenId(src)
    local owner = Ownership[propertyId]
    if not owner or owner.citizenid ~= citizenid then
        return TriggerClientEvent('QBCore:Notify', src, 'Tai ne jūsų nuosavybė.', 'error')
    end
    owner.locked = not owner.locked
    MySQL.update.await('UPDATE fivempro_property_ownership SET locked = ? WHERE property_id = ?', {
        owner.locked and 1 or 0,
        propertyId,
    })
    broadcastOwnership()
    TriggerClientEvent('QBCore:Notify', src, owner.locked and 'Durys užrakintos.' or 'Durys atrakintos.', 'success')
end)

RegisterNetEvent('mrp_housing:server:enter', function(propertyId)
    local src = source
    local prop, propIndex = FPMHousing.GetProperty(propertyId)
    if not prop or not propIndex then return end

    local owner = Ownership[propertyId]
    if not owner then
        return TriggerClientEvent('QBCore:Notify', src, 'Šis objektas neparduotas.', 'error')
    end

    local citizenid = getCitizenId(src)
    local fullAccess = hasFullAccess(propertyId, citizenid)
    if not fullAccess then
        if owner.locked then
            return TriggerClientEvent('QBCore:Notify', src, 'Durys užrakintos.', 'error')
        end
    end

    local interior = Config.Interiors[owner.interior_key]
    if not interior then return end

    local bucket = FPMHousing.RoutingBucket(propIndex)
    SetPlayerRoutingBucket(src, bucket)
    InsidePlayers[src] = propertyId

    TriggerClientEvent('mrp_housing:client:enterInterior', src, {
        propertyId = propertyId,
        propertyIndex = propIndex,
        interiorKey = owner.interior_key,
        furnished = owner.furnished == true,
        propertyClass = FPMHousing.GetPropertyClass(prop),
        door = { x = prop.door.x, y = prop.door.y, z = prop.door.z, w = prop.door.w },
        label = prop.label,
        isOwner = owner.citizenid == citizenid,
        canUseStash = fullAccess,
        hasKey = hasKey(propertyId, citizenid),
        canManageFurniture = fullAccess,
    })
end)

RegisterNetEvent('mrp_housing:server:exit', function(propertyId, propertyIndex)
    local src = source
    InsidePlayers[src] = nil
    SetPlayerRoutingBucket(src, 0)
    TriggerClientEvent('mrp_furniture:client:unloadProperty', src)
end)

--- Eksportai baldų / kitiems resursams
exports('HasFullAccess', function(src, propertyId)
    local citizenid = getCitizenId(src)
    return hasFullAccess(propertyId, citizenid)
end)

exports('GetOwnership', function(propertyId)
    return Ownership[propertyId]
end)

exports('GetInsidePropertyId', function(src)
    return InsidePlayers[src]
end)

exports('GetPropertyClass', function(propertyId)
    local prop = FPMHousing.GetProperty(propertyId)
    return prop and FPMHousing.GetPropertyClass(prop) or nil
end)

exports('GetInteriorEnter', function(interiorKey)
    return FPMHousing.GetInteriorEnter(interiorKey)
end)

RegisterNetEvent('mrp_housing:server:openStash', function(propertyId)
    local src = source
    local owner = Ownership[propertyId]
    local citizenid = getCitizenId(src)
    if not owner or not hasFullAccess(propertyId, citizenid) then
        return TriggerClientEvent('QBCore:Notify', src, 'Neturite prieigos prie sandėliuko.', 'error')
    end
    --- Jei žaidėjas viduje — turi būti būtent šiame objekte
    if InsidePlayers[src] and InsidePlayers[src] ~= propertyId then
        return TriggerClientEvent('QBCore:Notify', src, 'Neturite prieigos prie sandėliuko.', 'error')
    end
    local prop = FPMHousing.GetProperty(propertyId)
    local stashCfg = FPMHousing.GetInteriorStash(owner.interior_key)
    local stashId = ('property_%s'):format(propertyId)
    exports['qb-inventory']:OpenInventory(src, stashId, {
        label = prop and prop.label or 'Namai',
        maxweight = stashCfg.maxweight,
        slots = stashCfg.slots,
    })
end)

RegisterNetEvent('mrp_housing:server:giveKey', function(propertyId, targetServerId)
    local src = source
    local citizenid = getCitizenId(src)
    if not isOwner(propertyId, citizenid) then
        return TriggerClientEvent('QBCore:Notify', src, 'Tik savininkas gali dalinti raktus.', 'error')
    end

    local targetId = tonumber(targetServerId)
    if not targetId or targetId == src then
        return TriggerClientEvent('QBCore:Notify', src, 'Neteisingas žaidėjo ID.', 'error')
    end

    local Target = QBCore.Functions.GetPlayer(targetId)
    if not Target then
        return TriggerClientEvent('QBCore:Notify', src, 'Žaidėjas nerastas (neprisijungęs).', 'error')
    end

    local targetCid = Target.PlayerData.citizenid
    if targetCid == citizenid then
        return TriggerClientEvent('QBCore:Notify', src, 'Negalite duoti rakto sau.', 'error')
    end
    if hasKey(propertyId, targetCid) then
        return TriggerClientEvent('QBCore:Notify', src, 'Šis žaidėjas jau turi raktą.', 'error')
    end

    local maxDist = Config.KeyShareDistance or 3.0
    local srcPed = GetPlayerPed(src)
    local tgtPed = GetPlayerPed(targetId)
    if srcPed == 0 or tgtPed == 0 then
        return TriggerClientEvent('QBCore:Notify', src, 'Žaidėjas per toli.', 'error')
    end
    local dist = #(GetEntityCoords(srcPed) - GetEntityCoords(tgtPed))
    if dist > maxDist + 0.5 then
        return TriggerClientEvent('QBCore:Notify', src, 'Žaidėjas per toli.', 'error')
    end

    local ok = MySQL.insert.await(
        'INSERT INTO fivempro_property_keys (property_id, citizenid, granted_by) VALUES (?, ?, ?)',
        { propertyId, targetCid, citizenid }
    )
    if not ok then
        return TriggerClientEvent('QBCore:Notify', src, 'Nepavyko išsaugoti rakto.', 'error')
    end

    Keys[propertyId] = Keys[propertyId] or {}
    Keys[propertyId][targetCid] = true
    broadcastKeys()

    local prop = FPMHousing.GetProperty(propertyId)
    local label = prop and prop.label or propertyId
    local targetName = getCharName(Target)
    TriggerClientEvent('QBCore:Notify', src, ('Davėte raktą: %s (%s).'):format(targetName, label), 'success')
    TriggerClientEvent('QBCore:Notify', targetId, ('Gavote raktą: %s. Galite įeiti ir naudoti sandėliuką.'):format(label), 'success')
end)

RegisterNetEvent('mrp_housing:server:revokeKey', function(propertyId, targetCitizenId)
    local src = source
    local citizenid = getCitizenId(src)
    if not isOwner(propertyId, citizenid) then
        return TriggerClientEvent('QBCore:Notify', src, 'Tik savininkas gali atšaukti raktus.', 'error')
    end
    if type(targetCitizenId) ~= 'string' or targetCitizenId == '' then
        return TriggerClientEvent('QBCore:Notify', src, 'Neteisingas asmuo.', 'error')
    end
    if not hasKey(propertyId, targetCitizenId) then
        return TriggerClientEvent('QBCore:Notify', src, 'Šis asmuo neturi rakto.', 'error')
    end

    MySQL.update.await(
        'DELETE FROM fivempro_property_keys WHERE property_id = ? AND citizenid = ?',
        { propertyId, targetCitizenId }
    )

    if Keys[propertyId] then
        Keys[propertyId][targetCitizenId] = nil
        if next(Keys[propertyId]) == nil then
            Keys[propertyId] = nil
        end
    end
    broadcastKeys()
    kickKeyHoldersFromProperty(propertyId, targetCitizenId)

    local Target = QBCore.Functions.GetPlayerByCitizenId(targetCitizenId)
    local prop = FPMHousing.GetProperty(propertyId)
    local label = prop and prop.label or propertyId
    TriggerClientEvent('QBCore:Notify', src, ('Raktas atšauktas (%s).'):format(label), 'success')
    if Target then
        TriggerClientEvent('QBCore:Notify', Target.PlayerData.source, ('Jūsų raktas atšauktas: %s.'):format(label), 'error')
    end
end)

AddEventHandler('QBCore:Server:PlayerLoaded', function(Player)
    local src = Player.PlayerData.source
    syncPlayer(src)
end)

AddEventHandler('playerDropped', function()
    local src = source
    InsidePlayers[src] = nil
end)

AddEventHandler('onResourceStart', function(res)
    if res ~= GetCurrentResourceName() then return end
    Wait(500)
    broadcastOwnership()
    broadcastKeys()
end)
