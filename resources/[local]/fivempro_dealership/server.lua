local QBCore = exports['qb-core']:GetCoreObject()

local function normalizeShopValue(shop)
    if type(shop) == 'string' then
        return { [shop] = true }
    end
    if type(shop) == 'table' then
        local t = {}
        for _, v in pairs(shop) do
            t[v] = true
        end
        return t
    end
    return {}
end

local function resolvePrice(model, defaultPrice)
    local override = Config.PriceOverrides[model]
    if override and override > 0 then
        return override
    end
    return math.max(1, tonumber(defaultPrice) or 1)
end

local function resolveCategory(model, baseCategory)
    if model == 'regina' or model == 'stratum' then
        return 'wagons'
    end
    return baseCategory or 'other'
end

local function buildCatalog()
    local categories = {}
    local vehicles = {}
    for _, veh in pairs(QBCore.Shared.Vehicles) do
        if veh.model and veh.shop then
            local shops = normalizeShopValue(veh.shop)
            if shops.pdm or shops.luxury then
                local model = string.lower(veh.model)
                local category = resolveCategory(model, veh.category)
                local price = resolvePrice(model, veh.price)

                categories[category] = Config.CategoryLabels[category] or category
                vehicles[#vehicles + 1] = {
                    model = model,
                    name = veh.name or model,
                    brand = veh.brand or 'Unknown',
                    category = category,
                    price = price
                }
            end
        end
    end

    table.sort(vehicles, function(a, b)
        if a.category == b.category then
            return a.name < b.name
        end
        return a.category < b.category
    end)

    return {
        dealership = Config.Dealership,
        categories = categories,
        vehicles = vehicles
    }
end

local function randomLetters(n)
    local s = ''
    for _ = 1, n do
        s = s .. string.char(math.random(65, 90))
    end
    return s
end

local function randomNumbers(n)
    local s = ''
    for _ = 1, n do
        s = s .. tostring(math.random(0, 9))
    end
    return s
end

local function generatePlate()
    return (randomNumbers(1) .. randomLetters(2) .. randomNumbers(3) .. randomLetters(1)):upper()
end

local function isPlateFree(plate)
    local r = MySQL.scalar.await('SELECT plate FROM player_vehicles WHERE plate = ? LIMIT 1', { plate })
    return not r
end

local function getUniquePlate()
    for _ = 1, 25 do
        local p = generatePlate()
        if isPlateFree(p) then
            return p
        end
    end
    return generatePlate()
end

CreateThread(function()
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `player_vehicles` (
          `id` int(11) NOT NULL AUTO_INCREMENT,
          `license` varchar(50) DEFAULT NULL,
          `citizenid` varchar(50) DEFAULT NULL,
          `vehicle` varchar(50) DEFAULT NULL,
          `hash` varchar(50) DEFAULT NULL,
          `mods` longtext DEFAULT NULL,
          `plate` varchar(50) NOT NULL,
          `garage` varchar(50) DEFAULT NULL,
          `state` int(11) DEFAULT 1,
          `fuel` int(11) DEFAULT 100,
          `engine` float DEFAULT 1000,
          `body` float DEFAULT 1000,
          `depotprice` int(11) DEFAULT 0,
          PRIMARY KEY (`id`),
          UNIQUE KEY `plate` (`plate`),
          KEY `citizenid` (`citizenid`),
          KEY `license` (`license`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])
end)

QBCore.Functions.CreateCallback('fivempro_dealership:server:getCatalog', function(_, cb)
    cb(buildCatalog())
end)

QBCore.Functions.CreateCallback('fivempro_dealership:server:buyVehicle', function(source, cb, model)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return cb({ ok = false, message = 'Player not found' }) end

    model = string.lower(tostring(model or ''))
    local selectedVehicle = nil
    for _, v in pairs(buildCatalog().vehicles) do
        if v.model == model then
            selectedVehicle = v
            break
        end
    end
    if not selectedVehicle then
        return cb({ ok = false, message = 'Vehicle not found in catalog' })
    end

    local price = selectedVehicle.price
    local paid = false
    if Player.PlayerData.money.bank >= price then
        paid = Player.Functions.RemoveMoney('bank', price, 'fivempro-dealership-buy')
    elseif Player.PlayerData.money.cash >= price then
        paid = Player.Functions.RemoveMoney('cash', price, 'fivempro-dealership-buy')
    end

    if not paid then
        return cb({ ok = false, message = 'Nepakanka pinigu' })
    end

    local plate = getUniquePlate()
    local hash = joaat(model)
    local props = {
        model = hash,
        plate = plate
    }

    MySQL.insert.await([[
        INSERT INTO player_vehicles
        (license, citizenid, vehicle, hash, mods, plate, garage, state, fuel, engine, body, depotprice)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]], {
        Player.PlayerData.license,
        Player.PlayerData.citizenid,
        model,
        tostring(hash),
        json.encode(props),
        plate,
        Config.Dealership.garage,
        0,
        100,
        1000,
        1000,
        0
    })

    cb({
        ok = true,
        plate = plate,
        model = model,
        spawn = Config.Dealership.spawn
    })
end)

