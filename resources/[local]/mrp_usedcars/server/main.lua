local QBCore = exports['qb-core']:GetCoreObject()

local function notify(src, msg, nType)
    TriggerClientEvent('QBCore:Notify', src, msg, nType or 'primary')
end

local function normalizePlate(plate)
    return tostring(plate or ''):upper():gsub('^%s+', ''):gsub('%s+$', '')
end

local function isBlockedModel(model)
    model = tostring(model or ''):lower()
    if Config.BlockedModels[model] then return true end
    if model:match('^mrpd%d+$') or model:match('^ems%d+$') then return true end
    return false
end

local function hasEmergencyKit(modsJson)
    if not modsJson or modsJson == '' then return false end
    local ok, mods = pcall(json.decode, modsJson)
    if not ok or type(mods) ~= 'table' then return false end
    return mods.mrpPdKit == true or mods.mrpEmsKit == true
end

local function decodeMods(modsJson)
    if type(modsJson) == 'table' then return modsJson end
    if not modsJson or modsJson == '' then return {} end
    local ok, mods = pcall(json.decode, modsJson)
    if ok and type(mods) == 'table' then return mods end
    return {}
end

local function encodeMods(mods)
    if type(mods) == 'string' then return mods end
    return json.encode(mods or {})
end

local function vehicleLabel(model)
    model = tostring(model or '')
    local shared = QBCore.Shared.Vehicles and QBCore.Shared.Vehicles[model]
    if shared and shared.name then return shared.name end
    local lower = model:lower()
    shared = QBCore.Shared.Vehicles and QBCore.Shared.Vehicles[lower]
    if shared and shared.name then return shared.name end
    return model
end

local function buildTuneSummary(mods)
    mods = mods or {}
    local perf = 0
    local checks = {
        { key = 'modEngine', min = 0 },
        { key = 'modBrakes', min = 0 },
        { key = 'modTransmission', min = 0 },
        { key = 'modSuspension', min = 0 },
        { key = 'modArmor', min = 0 },
    }
    for i = 1, #checks do
        local v = tonumber(mods[checks[i].key])
        if v and v >= checks[i].min then perf = perf + 1 end
    end
    if mods.modTurbo == true or mods.modTurbo == 1 then perf = perf + 1 end

    local bodyCount = 0
    local bodyKeys = {
        'modSpoilers', 'modFrontBumper', 'modRearBumper', 'modSideSkirt',
        'modExhaust', 'modFrame', 'modGrille', 'modHood', 'modFender',
        'modRightFender', 'modRoof', 'modLivery', 'modHorns', 'modXenon',
        'modTrimA', 'modTrimB', 'modTank', 'modWindows', 'modDoorSpeaker',
    }
    for i = 1, #bodyKeys do
        local v = tonumber(mods[bodyKeys[i]])
        if v and v >= 0 then bodyCount = bodyCount + 1 end
    end

    local label = 'Stock'
    if perf >= 5 then
        label = 'Full tune'
    elseif perf >= 2 or bodyCount >= 3 then
        label = 'Partial tune'
    elseif bodyCount >= 1 then
        label = 'Cosmetic'
    end

    return {
        label = label,
        perfLevel = perf,
        bodyMods = bodyCount,
        turbo = mods.modTurbo == true or mods.modTurbo == 1,
        engine = tonumber(mods.modEngine) or -1,
        brakes = tonumber(mods.modBrakes) or -1,
        transmission = tonumber(mods.modTransmission) or -1,
        suspension = tonumber(mods.modSuspension) or -1,
        armor = tonumber(mods.modArmor) or -1,
    }
end

local function buildPerfSummary(model)
    local out = {
        maxKmh = nil,
        tier = nil,
        tierLabel = nil,
        category = nil,
    }
    if GetResourceState('mrp_vehicle_perf') ~= 'started' then return out end

    local shared = QBCore.Shared.Vehicles and (QBCore.Shared.Vehicles[model] or QBCore.Shared.Vehicles[tostring(model):lower()])
    local category = shared and shared.category or nil
    local ok, packed = pcall(function()
        local price, profile = exports['mrp_vehicle_perf']:CalculateVehiclePrice(model, category)
        return { price = price, profile = profile }
    end)
    if ok and type(packed) == 'table' and type(packed.profile) == 'table' then
        local profile = packed.profile
        out.maxKmh = profile.maxKmh
        out.tier = profile.tier
        out.category = profile.perfCategory or category
        local okLabel, label = pcall(function()
            return exports['mrp_vehicle_perf']:GetTierLabel(profile.tier)
        end)
        if okLabel then out.tierLabel = label end
        return out
    end

    local ok2, profile2 = pcall(function()
        return exports['mrp_vehicle_perf']:GetVehiclePerfProfile(model, category)
    end)
    if ok2 and type(profile2) == 'table' then
        out.maxKmh = profile2.maxKmh
        out.tier = profile2.tier
        out.tierLabel = profile2.tierLabel
        out.category = category
    end
    return out
end

local function healthPct(value)
    local n = tonumber(value)
    if n == nil then return 100 end
    if n > 100 then
        return math.floor(math.max(0, math.min(100, (n / 1000) * 100)) + 0.5)
    end
    return math.floor(math.max(0, math.min(100, n)) + 0.5)
end

local function listingPayload(row, pv)
    local mods = decodeMods(row.mods)
    local engine = pv and pv.engine or mods.engineHealth or 1000
    local body = pv and pv.body or mods.bodyHealth or 1000
    local fuel = pv and pv.fuel or mods.fuelLevel or 100
    return {
        id = row.id,
        plate = row.plate,
        model = row.model,
        label = vehicleLabel(row.model),
        price = tonumber(row.price) or 0,
        sellerCitizenId = row.seller_citizenid,
        slotIndex = tonumber(row.slot_index) or 0,
        listedAt = row.listed_at,
        mods = mods,
        engine = healthPct(engine),
        body = healthPct(body),
        fuel = healthPct(fuel),
        tune = buildTuneSummary(mods),
        perf = buildPerfSummary(row.model),
    }
end

local function fetchListings()
    local rows = MySQL.query.await([[
        SELECT l.id, l.plate, l.seller_citizenid, l.model, l.mods, l.price, l.listed_at, l.slot_index,
               pv.engine, pv.body, pv.fuel
        FROM mrp_usedcar_listings l
        LEFT JOIN player_vehicles pv ON pv.plate = l.plate
        ORDER BY l.listed_at ASC
    ]]) or {}

    local list = {}
    for i = 1, #rows do
        local r = rows[i]
        list[#list + 1] = listingPayload(r, {
            engine = r.engine,
            body = r.body,
            fuel = r.fuel,
        })
    end
    return list
end

local function broadcastListings()
    TriggerClientEvent('mrp_usedcars:client:setListings', -1, fetchListings())
end

local function countSellerListings(citizenid)
    local n = MySQL.scalar.await(
        'SELECT COUNT(*) FROM mrp_usedcar_listings WHERE seller_citizenid = ?',
        { citizenid }
    )
    return tonumber(n) or 0
end

local function findFreeSlot()
    local used = {}
    local rows = MySQL.query.await('SELECT slot_index FROM mrp_usedcar_listings') or {}
    for i = 1, #rows do
        used[tonumber(rows[i].slot_index) or -1] = true
    end
    for i = 1, #Config.Slots do
        local idx = i - 1
        if not used[idx] then return idx end
    end
    return nil
end

local function ensureSchema()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `mrp_usedcar_listings` (
          `id` INT NOT NULL AUTO_INCREMENT,
          `plate` VARCHAR(16) NOT NULL,
          `seller_citizenid` VARCHAR(64) NOT NULL,
          `model` VARCHAR(64) NOT NULL,
          `mods` LONGTEXT NULL,
          `price` INT NOT NULL,
          `listed_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
          `slot_index` INT NOT NULL DEFAULT 0,
          PRIMARY KEY (`id`),
          UNIQUE KEY `uniq_plate` (`plate`),
          KEY `idx_seller` (`seller_citizenid`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])
end

CreateThread(function()
    ensureSchema()
    Wait(500)
    broadcastListings()
end)

AddEventHandler('QBCore:Server:PlayerLoaded', function(Player)
    if not Player or not Player.PlayerData then return end
    TriggerClientEvent('mrp_usedcars:client:setListings', Player.PlayerData.source, fetchListings())
end)

QBCore.Functions.CreateCallback('mrp_usedcars:server:getListings', function(_, cb)
    cb(fetchListings())
end)

QBCore.Functions.CreateCallback('mrp_usedcars:server:getMyListings', function(source, cb)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return cb({}) end
    local rows = MySQL.query.await([[
        SELECT l.id, l.plate, l.seller_citizenid, l.model, l.mods, l.price, l.listed_at, l.slot_index,
               pv.engine, pv.body, pv.fuel
        FROM mrp_usedcar_listings l
        LEFT JOIN player_vehicles pv ON pv.plate = l.plate
        WHERE l.seller_citizenid = ?
        ORDER BY l.listed_at DESC
    ]], { Player.PlayerData.citizenid }) or {}

    local list = {}
    for i = 1, #rows do
        local r = rows[i]
        list[#list + 1] = listingPayload(r, {
            engine = r.engine,
            body = r.body,
            fuel = r.fuel,
        })
    end
    cb(list)
end)

QBCore.Functions.CreateCallback('mrp_usedcars:server:listVehicle', function(source, cb, data)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return cb({ ok = false, message = 'Žaidėjas nerastas' }) end

    data = data or {}
    local plate = normalizePlate(data.plate)
    local price = math.floor(tonumber(data.price) or 0)
    local props = data.props
    local netId = tonumber(data.netId)

    if plate == '' then
        return cb({ ok = false, message = 'Nerasta numerių lentelė' })
    end
    if price < Config.MinPrice or price > Config.MaxPrice then
        return cb({
            ok = false,
            message = ('Kaina turi būti tarp $%s ir $%s'):format(Config.MinPrice, Config.MaxPrice),
        })
    end
    if countSellerListings(Player.PlayerData.citizenid) >= Config.MaxListingsPerPlayer then
        return cb({
            ok = false,
            message = ('Maksimaliai %s skelbimai vienu metu'):format(Config.MaxListingsPerPlayer),
        })
    end

    local slotIndex = findFreeSlot()
    if slotIndex == nil then
        return cb({ ok = false, message = 'Aikštelėje nėra laisvų vietų' })
    end

    local row = MySQL.single.await([[
        SELECT vehicle, plate, mods, state, garage, fuel, engine, body
        FROM player_vehicles
        WHERE citizenid = ? AND plate = ?
        LIMIT 1
    ]], { Player.PlayerData.citizenid, plate })

    if not row then
        return cb({ ok = false, message = 'Ši mašina nepriklauso tau' })
    end

    local model = tostring(row.vehicle or '')
    if isBlockedModel(model) then
        return cb({ ok = false, message = 'Tarnybinio transporto parduoti negalima' })
    end

    local modsJson = encodeMods(props or decodeMods(row.mods))
    if hasEmergencyKit(modsJson) then
        return cb({ ok = false, message = 'Transportas su avariniais rinkiniais negalimas' })
    end

    local existing = MySQL.scalar.await('SELECT id FROM mrp_usedcar_listings WHERE plate = ? LIMIT 1', { plate })
    if existing then
        return cb({ ok = false, message = 'Ši mašina jau parduodama' })
    end

    local state = tonumber(row.state) or 0
    if state == 3 or tostring(row.garage or '') == Config.GarageId then
        return cb({ ok = false, message = 'Mašina jau aikštelėje' })
    end
    if state == 2 then
        return cb({ ok = false, message = 'Impoundinta mašina negalima listuoti' })
    end

    MySQL.insert.await([[
        INSERT INTO mrp_usedcar_listings (plate, seller_citizenid, model, mods, price, slot_index)
        VALUES (?, ?, ?, ?, ?, ?)
    ]], {
        plate,
        Player.PlayerData.citizenid,
        model,
        modsJson,
        price,
        slotIndex,
    })

    MySQL.update.await([[
        UPDATE player_vehicles
        SET garage = ?, state = 3, mods = ?, fuel = ?
        WHERE citizenid = ? AND plate = ?
    ]], {
        Config.GarageId,
        modsJson,
        tonumber((props and props.fuelLevel) or row.fuel) or 100,
        Player.PlayerData.citizenid,
        plate,
    })

    if netId then
        local ent = NetworkGetEntityFromNetworkId(netId)
        if ent and ent ~= 0 and DoesEntityExist(ent) then
            DeleteEntity(ent)
        end
    end

    broadcastListings()
    cb({ ok = true, message = 'Mašina pastatyta parduoti', slotIndex = slotIndex })
end)

QBCore.Functions.CreateCallback('mrp_usedcars:server:cancelListing', function(source, cb, listingId)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return cb({ ok = false, message = 'Žaidėjas nerastas' }) end

    listingId = tonumber(listingId)
    if not listingId then return cb({ ok = false, message = 'Neteisingas skelbimas' }) end

    local row = MySQL.single.await(
        'SELECT id, plate, seller_citizenid FROM mrp_usedcar_listings WHERE id = ? LIMIT 1',
        { listingId }
    )
    if not row then
        return cb({ ok = false, message = 'Skelbimas nerastas' })
    end
    if row.seller_citizenid ~= Player.PlayerData.citizenid then
        return cb({ ok = false, message = 'Tai ne tavo skelbimas' })
    end

    MySQL.update.await(
        'DELETE FROM mrp_usedcar_listings WHERE id = ?',
        { listingId }
    )
    MySQL.update.await([[
        UPDATE player_vehicles
        SET garage = ?, state = 1
        WHERE citizenid = ? AND plate = ? AND state = 3
    ]], {
        Config.ReturnGarage,
        Player.PlayerData.citizenid,
        normalizePlate(row.plate),
    })

    broadcastListings()
    cb({ ok = true, message = ('Mašina grąžinta į garažą (%s)'):format(Config.ReturnGarage) })
end)

QBCore.Functions.CreateCallback('mrp_usedcars:server:buyListing', function(source, cb, listingId)
    local Buyer = QBCore.Functions.GetPlayer(source)
    if not Buyer then return cb({ ok = false, message = 'Žaidėjas nerastas' }) end

    listingId = tonumber(listingId)
    if not listingId then return cb({ ok = false, message = 'Neteisingas skelbimas' }) end

    local listing = MySQL.single.await(
        'SELECT * FROM mrp_usedcar_listings WHERE id = ? LIMIT 1',
        { listingId }
    )
    if not listing then
        return cb({ ok = false, message = 'Skelbimas nebegalioja' })
    end

    local plate = normalizePlate(listing.plate)
    if listing.seller_citizenid == Buyer.PlayerData.citizenid then
        return cb({ ok = false, message = 'Negali pirkti savo mašinos' })
    end

    local price = math.floor(tonumber(listing.price) or 0)
    if price <= 0 then
        return cb({ ok = false, message = 'Neteisinga kaina' })
    end

    local paidWith = nil
    if (Buyer.PlayerData.money.bank or 0) >= price then
        if Buyer.Functions.RemoveMoney('bank', price, 'mrp-usedcars-buy') then
            paidWith = 'bank'
        end
    elseif (Buyer.PlayerData.money.cash or 0) >= price then
        if Buyer.Functions.RemoveMoney('cash', price, 'mrp-usedcars-buy') then
            paidWith = 'cash'
        end
    end

    if not paidWith then
        return cb({ ok = false, message = 'Nepakanka pinigų' })
    end

    local fee = math.floor(price * Config.FeePercent + 0.5)
    local sellerGets = price - fee
    if sellerGets < 0 then sellerGets = 0 end

    local Seller = QBCore.Functions.GetPlayerByCitizenId(listing.seller_citizenid)
    if Seller then
        Seller.Functions.AddMoney('bank', sellerGets, 'mrp-usedcars-sell')
        notify(Seller.PlayerData.source, ('Parduota %s už $%s (po mokesčio)'):format(plate, sellerGets), 'success')
    else
        local moneyRow = MySQL.single.await('SELECT money FROM players WHERE citizenid = ? LIMIT 1', {
            listing.seller_citizenid,
        })
        if moneyRow and moneyRow.money then
            local okMoney, money = pcall(json.decode, moneyRow.money)
            if okMoney and type(money) == 'table' then
                money.bank = math.floor((tonumber(money.bank) or 0) + sellerGets)
                MySQL.update.await('UPDATE players SET money = ? WHERE citizenid = ?', {
                    json.encode(money),
                    listing.seller_citizenid,
                })
            end
        end
    end

    local affected = MySQL.update.await([[
        UPDATE player_vehicles
        SET license = ?, citizenid = ?, garage = ?, state = 0
        WHERE plate = ? AND citizenid = ? AND state = 3 AND garage = ?
    ]], {
        Buyer.PlayerData.license,
        Buyer.PlayerData.citizenid,
        Config.ReturnGarage,
        plate,
        listing.seller_citizenid,
        Config.GarageId,
    })

    if not affected or affected < 1 then
        Buyer.Functions.AddMoney(paidWith, price, 'mrp-usedcars-refund')
        return cb({ ok = false, message = 'Nuosavybės perkėlimas nepavyko' })
    end

    MySQL.update.await('DELETE FROM mrp_usedcar_listings WHERE id = ?', { listingId })
    broadcastListings()

    cb({
        ok = true,
        message = 'Pirkimas sėkmingas',
        plate = plate,
        model = listing.model,
        mods = listing.mods,
        spawn = {
            x = Config.BuySpawn.x,
            y = Config.BuySpawn.y,
            z = Config.BuySpawn.z,
            w = Config.BuySpawn.w,
        },
        sellerPayout = sellerGets,
        fee = fee,
    })
end)

RegisterNetEvent('mrp_usedcars:server:requestSync', function()
    local src = source
    TriggerClientEvent('mrp_usedcars:client:setListings', src, fetchListings())
end)
