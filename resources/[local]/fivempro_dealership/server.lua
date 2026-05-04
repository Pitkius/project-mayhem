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

local function buildPoliceCatalog()
    local pd = Config.PoliceDealership
    if not pd or not pd.vehicles then
        return { dealership = { label = 'PD' }, categories = {}, vehicles = {} }
    end
    local categories = {}
    local labels = pd.PoliceCategoryLabels or {}
    for _, v in ipairs(pd.vehicles) do
        local cat = v.category or 'patrol'
        if not categories[cat] then
            categories[cat] = labels[cat] or cat
        end
    end
    return {
        dealership = { label = pd.label or 'Policija' },
        categories = categories,
        vehicles = pd.vehicles,
    }
end

QBCore.Functions.CreateCallback('fivempro_dealership:server:getPoliceCatalog', function(_, cb)
    cb(buildPoliceCatalog())
end)

local function buildMechanicCatalog()
    local md = Config.MechanicDealership
    if not md or not md.vehicles then
        return { dealership = { label = 'Mechanikas' }, categories = {}, vehicles = {} }
    end
    local categories = {}
    local labels = md.MechanicCategoryLabels or {}
    for _, v in ipairs(md.vehicles) do
        local cat = v.category or 'tow'
        if not categories[cat] then
            categories[cat] = labels[cat] or cat
        end
    end
    return {
        dealership = { label = md.label or 'Mechanikas' },
        categories = categories,
        vehicles = md.vehicles,
    }
end

QBCore.Functions.CreateCallback('fivempro_dealership:server:getMechanicCatalog', function(_, cb)
    cb(buildMechanicCatalog())
end)

local function buildEmsCatalog()
    local ed = Config.EmsDealership
    if not ed or not ed.vehicles then
        return { dealership = { label = 'EMS' }, categories = {}, vehicles = {} }
    end
    local categories = {}
    local labels = ed.EmsCategoryLabels or {}
    for _, v in ipairs(ed.vehicles) do
        local cat = v.category or 'ems'
        if not categories[cat] then
            categories[cat] = labels[cat] or cat
        end
    end
    return {
        dealership = { label = ed.label or 'EMS' },
        categories = categories,
        vehicles = ed.vehicles,
    }
end

QBCore.Functions.CreateCallback('fivempro_dealership:server:getEmsCatalog', function(_, cb)
    cb(buildEmsCatalog())
end)

local function isPoliceJobPlayer(Player)
    if not Player or not Player.PlayerData.job then return false end
    local j = Player.PlayerData.job
    if not j.onduty then return false end
    local n = j.name
    return n == 'ltpd' or n == 'police'
end

local function isMechanicJobPlayer(Player)
    if not Player or not Player.PlayerData.job then return false end
    local j = Player.PlayerData.job
    return j.name == 'mechanic' and j.onduty
end

local function isEmsJobPlayer(Player)
    if not Player or not Player.PlayerData.job then return false end
    local j = Player.PlayerData.job
    return j.name == 'ambulance' and j.onduty
end

local function isTaxiJobPlayer(Player)
    if not Player or not Player.PlayerData.job then return false end
    local j = Player.PlayerData.job
    return j.name == 'taxi' and j.onduty
end

local function buildTaxiCatalog()
    local td = Config.TaxiDealership
    if not td or not td.vehicles then
        return { dealership = { label = 'Taxi' }, categories = {}, vehicles = {} }
    end
    local categories = {}
    local labels = td.TaxiCategoryLabels or {}
    for _, v in ipairs(td.vehicles) do
        local cat = v.category or 'taxi'
        if not categories[cat] then
            categories[cat] = labels[cat] or cat
        end
    end
    return {
        dealership = { label = td.label or 'Taxi' },
        categories = categories,
        vehicles = td.vehicles,
    }
end

QBCore.Functions.CreateCallback('fivempro_dealership:server:getTaxiCatalog', function(_, cb)
    cb(buildTaxiCatalog())
end)

QBCore.Functions.CreateCallback('fivempro_dealership:server:buyPoliceVehicle', function(source, cb, model, stationId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return cb({ ok = false, message = 'Player not found' }) end
    if not isPoliceJobPlayer(Player) then
        return cb({ ok = false, message = 'Prieinama tik policijai tarnyboje.' })
    end

    model = string.lower(tostring(model or ''))
    stationId = tostring(stationId or 'ls_main')
    local pd = Config.PoliceDealership
    local garageId = pd.garageByStation and pd.garageByStation[stationId]
    local stSpawn = pd.stations and pd.stations[stationId]
    if not garageId or not stSpawn then
        return cb({ ok = false, message = 'Nežinoma policijos stotis.' })
    end

    local selectedVehicle = nil
    for _, v in ipairs(pd.vehicles or {}) do
        if v.model and string.lower(tostring(v.model)) == model then
            selectedVehicle = v
            break
        end
    end
    if not selectedVehicle then
        return cb({ ok = false, message = 'Modelis nerastas kataloge.' })
    end

    local price = tonumber(selectedVehicle.price) or 0
    local paid = false
    if price > 0 then
        if Player.PlayerData.money.bank >= price then
            paid = Player.Functions.RemoveMoney('bank', price, 'fivempro-pd-dealership-buy')
        elseif Player.PlayerData.money.cash >= price then
            paid = Player.Functions.RemoveMoney('cash', price, 'fivempro-pd-dealership-buy')
        end
        if not paid then
            return cb({ ok = false, message = 'Nepakanka pinigų.' })
        end
    else
        paid = true
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
        garageId,
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
        spawn = stSpawn.spawn,
    })
end)

local function buyFleetJobVehicle(Player, cb, model, stationId, cfg, jobCheckFn, errJob)
    if not Player then return cb({ ok = false, message = 'Player not found' }) end
    if not jobCheckFn(Player) then
        return cb({ ok = false, message = errJob })
    end

    model = string.lower(tostring(model or ''))
    stationId = tostring(stationId or '')
    local garageId = cfg.garageByStation and cfg.garageByStation[stationId]
    local stSpawn = cfg.stations and cfg.stations[stationId]
    if not garageId or not stSpawn then
        return cb({ ok = false, message = 'Nežinoma bazė.' })
    end

    local selectedVehicle = nil
    for _, v in ipairs(cfg.vehicles or {}) do
        if v.model and string.lower(tostring(v.model)) == model then
            selectedVehicle = v
            break
        end
    end
    if not selectedVehicle then
        return cb({ ok = false, message = 'Modelis nerastas kataloge.' })
    end

    local price = tonumber(selectedVehicle.price) or 0
    local paid = false
    if price > 0 then
        if Player.PlayerData.money.bank >= price then
            paid = Player.Functions.RemoveMoney('bank', price, 'fivempro-job-dealership-buy')
        elseif Player.PlayerData.money.cash >= price then
            paid = Player.Functions.RemoveMoney('cash', price, 'fivempro-job-dealership-buy')
        end
        if not paid then
            return cb({ ok = false, message = 'Nepakanka pinigų.' })
        end
    else
        paid = true
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
        garageId,
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
        spawn = stSpawn.spawn,
    })
end

QBCore.Functions.CreateCallback('fivempro_dealership:server:buyMechanicVehicle', function(source, cb, model, stationId)
    local Player = QBCore.Functions.GetPlayer(source)
    buyFleetJobVehicle(Player, cb, model, stationId or 'mech_ls', Config.MechanicDealership, isMechanicJobPlayer, 'Tik mechanikams tarnyboje.')
end)

QBCore.Functions.CreateCallback('fivempro_dealership:server:buyEmsVehicle', function(source, cb, model, stationId)
    local Player = QBCore.Functions.GetPlayer(source)
    buyFleetJobVehicle(Player, cb, model, stationId or 'ems_ls', Config.EmsDealership, isEmsJobPlayer, 'Tik EMS tarnyboje.')
end)

QBCore.Functions.CreateCallback('fivempro_dealership:server:buyTaxiVehicle', function(source, cb, model, stationId)
    local Player = QBCore.Functions.GetPlayer(source)
    buyFleetJobVehicle(Player, cb, model, stationId or 'taxi_ls', Config.TaxiDealership, isTaxiJobPlayer, 'Tik taksi tarnyboje.')
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

