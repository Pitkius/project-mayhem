local QBCore = exports['qb-core']:GetCoreObject()

local Ownership = {}

MySQL.ready(function()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `fivempro_property_ownership` (
            `property_id` VARCHAR(64) NOT NULL,
            `citizenid` VARCHAR(50) NOT NULL,
            `interior_key` VARCHAR(32) NOT NULL,
            `price_paid` INT NOT NULL DEFAULT 0,
            `locked` TINYINT(1) NOT NULL DEFAULT 1,
            `purchased_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`property_id`),
            KEY `idx_fpmho_citizenid` (`citizenid`)
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
        }
    end
    print(('[^2fivempro_housing^7] Loaded %s property owners'):format(#rows))
end)

local function broadcastOwnership()
    TriggerClientEvent('fivempro_housing:client:syncOwnership', -1, Ownership)
end

local function getCitizenId(src)
    local p = QBCore.Functions.GetPlayer(src)
    return p and p.PlayerData.citizenid or nil
end

local function countOwned(citizenid)
    local n = 0
    for _, o in pairs(Ownership) do
        if o.citizenid == citizenid then n = n + 1 end
    end
    return n
end

local function buildCatalogFor(src)
    local citizenid = getCitizenId(src)
    local list = {}
    for i = 1, #(Config.Properties or {}) do
        local prop = Config.Properties[i]
        local owner = Ownership[prop.id]
        local interiors = {}
        for _, key in ipairs(prop.allowedInteriors or {}) do
            local entry = FPMHousing.InteriorCatalogEntry(key, prop)
            if entry then interiors[#interiors + 1] = entry end
        end
        table.sort(interiors, function(a, b)
            if (a.tier or 0) ~= (b.tier or 0) then return (a.tier or 0) < (b.tier or 0) end
            return a.price < b.price
        end)
        local minPrice = interiors[1] and interiors[1].price or Config.BasePrice
        list[#list + 1] = {
            id = prop.id,
            label = prop.label,
            type = prop.type,
            district = prop.district,
            districtLabel = Config.Districts[prop.district] and Config.Districts[prop.district].label or prop.district,
            door = { x = prop.door.x, y = prop.door.y, z = prop.door.z },
            owned = owner ~= nil,
            ownedByMe = owner and owner.citizenid == citizenid or false,
            ownedInteriorKey = owner and owner.interior_key or nil,
            ownedInteriorLabel = owner and Config.Interiors[owner.interior_key] and Config.Interiors[owner.interior_key].label or nil,
            ownedQualityLabel = owner and Config.Interiors[owner.interior_key] and Config.Interiors[owner.interior_key].qualityLabel or nil,
            ownerName = nil,
            locked = owner and owner.locked or false,
            interiors = interiors,
            minPrice = minPrice,
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
    exports['qb-inventory']:AddItem(src, 'house_deed', 1, false, info, 'fivempro_housing:purchase')
end

RegisterNetEvent('fivempro_housing:server:requestOpenAgency', function()
    local src = source
    local catalog = buildCatalogFor(src)
    TriggerClientEvent('fivempro_housing:client:openAgency', src, {
        agencyLabel = Config.Agency.label,
        maxOwned = Config.MaxOwnedPerPlayer,
        furnished = Config.Furnished,
        properties = catalog,
        districts = Config.Districts,
        interiors = Config.Interiors,
    })
end)

QBCore.Functions.CreateCallback('fivempro_housing:server:getOwnership', function(_, cb)
    cb(Ownership)
end)

QBCore.Functions.CreateCallback('fivempro_housing:server:purchase', function(src, cb, propertyId, interiorKey)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return cb({ ok = false, msg = 'Žaidėjas nerastas.' }) end

    local prop, propIndex = FPMHousing.GetProperty(propertyId)
    if not prop then return cb({ ok = false, msg = 'Objektas nerastas.' }) end
    if Ownership[propertyId] then return cb({ ok = false, msg = 'Šis objektas jau parduotas.' }) end

    local allowed = false
    for _, k in ipairs(prop.allowedInteriors or {}) do
        if k == interiorKey then allowed = true break end
    end
    if not allowed or not Config.Interiors[interiorKey] then
        return cb({ ok = false, msg = 'Netinkamas interjeras.' })
    end

    local citizenid = Player.PlayerData.citizenid
    if countOwned(citizenid) >= (Config.MaxOwnedPerPlayer or 2) then
        return cb({ ok = false, msg = ('Galima turėti daugiausiai %s objektus.'):format(Config.MaxOwnedPerPlayer) })
    end

    local price = FPMHousing.CalculatePrice(prop, interiorKey)
    local account = Config.PaymentAccount or 'bank'
    local balance = Player.PlayerData.money[account] or 0
    if balance < price then
        return cb({ ok = false, msg = ('Nepakanka pinigų (%s). Reikia $%s.'):format(account, price) })
    end

    if not Player.Functions.RemoveMoney(account, price, 'fivempro_housing:purchase') then
        return cb({ ok = false, msg = 'Mokėjimas nepavyko.' })
    end

    MySQL.insert.await(
        'INSERT INTO fivempro_property_ownership (property_id, citizenid, interior_key, price_paid, locked) VALUES (?, ?, ?, ?, 1)',
        { propertyId, citizenid, interiorKey, price }
    )

    Ownership[propertyId] = {
        citizenid = citizenid,
        interior_key = interiorKey,
        price_paid = price,
        locked = true,
    }

    giveDeed(src, Player, prop, interiorKey, price)
    broadcastOwnership()

    cb({
        ok = true,
        msg = ('Nupirkote „%s“ už $%s.'):format(prop.label, price),
        catalog = buildCatalogFor(src),
    })
end)

RegisterNetEvent('fivempro_housing:server:toggleLock', function(propertyId)
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

RegisterNetEvent('fivempro_housing:server:enter', function(propertyId)
    local src = source
    local prop, propIndex = FPMHousing.GetProperty(propertyId)
    if not prop or not propIndex then return end

    local owner = Ownership[propertyId]
    if not owner then
        return TriggerClientEvent('QBCore:Notify', src, 'Šis objektas neparduotas.', 'error')
    end

    local citizenid = getCitizenId(src)
    if owner.citizenid ~= citizenid then
        if owner.locked then
            return TriggerClientEvent('QBCore:Notify', src, 'Durys užrakintos.', 'error')
        end
    end

    local interior = Config.Interiors[owner.interior_key]
    if not interior then return end

    local bucket = FPMHousing.RoutingBucket(propIndex)
    SetPlayerRoutingBucket(src, bucket)

    TriggerClientEvent('fivempro_housing:client:enterInterior', src, {
        propertyId = propertyId,
        propertyIndex = propIndex,
        interiorKey = owner.interior_key,
        door = { x = prop.door.x, y = prop.door.y, z = prop.door.z, w = prop.door.w },
        label = prop.label,
        isOwner = owner.citizenid == citizenid,
    })
end)

RegisterNetEvent('fivempro_housing:server:exit', function(propertyId, propertyIndex)
    local src = source
    SetPlayerRoutingBucket(src, 0)
end)

RegisterNetEvent('fivempro_housing:server:openStash', function(propertyId)
    local src = source
    local owner = Ownership[propertyId]
    local citizenid = getCitizenId(src)
    if not owner or owner.citizenid ~= citizenid then
        return TriggerClientEvent('QBCore:Notify', src, 'Tik savininkas gali naudoti sandėliuką.', 'error')
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

AddEventHandler('QBCore:Server:PlayerLoaded', function(Player)
    local src = Player.PlayerData.source
    TriggerClientEvent('fivempro_housing:client:syncOwnership', src, Ownership)
end)

AddEventHandler('onResourceStart', function(res)
    if res ~= GetCurrentResourceName() then return end
    Wait(500)
    broadcastOwnership()
end)
