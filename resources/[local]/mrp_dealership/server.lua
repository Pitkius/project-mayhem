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

local CIVILIAN_CORE_BLOCKED = {
    rhino = true, khanjali = true, minitank = true, chernobog = true, barrage = true,
    insurgent = true, insurgent2 = true, insurgent3 = true,
    apc = true, scarab = true, scarab2 = true, scarab3 = true, halftrack = true,
    nightshark = true, menacer = true, oppressor = true, oppressor2 = true,
    deluxo = true, ruiner2 = true, ruiner3 = true, tank = true, wastelander = true,
    technical = true, technical2 = true, technical3 = true,
    vigilante = true, scramjet = true, toreador = true, stromberg = true,
    voltic2 = true, thruster = true, rcbandito = true, kuruma2 = true,
    tampa3 = true, caracara2 = true, dune3 = true, dune4 = true, dune5 = true,
    jb7002 = true, boxville5 = true, stockade4 = true, caracara3 = true,
    deathbike = true, deathbike2 = true, deathbike3 = true,
    baller5 = true, baller6 = true,
    issi4 = true, issi5 = true, issi6 = true,
    dominator4 = true, impaler2 = true, impaler3 = true, impaler4 = true,
    imperator = true, imperator2 = true, imperator3 = true,
    zr380 = true, zr3802 = true, zr3803 = true,
    bruiser = true, bruiser2 = true, bruiser3 = true,
    brutus = true, brutus2 = true, brutus3 = true,
    cerberus = true, cerberus2 = true, cerberus3 = true,
    slamvan4 = true, slamvan5 = true, slamvan6 = true,
}

local function civilianCategoryAllowed(cat)
    local t = Config.CivilianShopAllowedCategories
    if not t or not next(t) then return true end
    return t[cat] == true
end

local function mergeCivilianBlocked()
    local blocked = {}
    for k, v in pairs(CIVILIAN_CORE_BLOCKED) do
        blocked[k] = v
    end
    for k, v in pairs(Config.CivilianShopExtraBlockedModels or {}) do
        if v then blocked[k] = true end
    end
    return blocked
end

local function resolvePerformancePrice(model, category)
    if GetResourceState('mrp_vehicle_perf') ~= 'started' then
        return nil
    end
    local ok, price = pcall(function()
        return exports['mrp_vehicle_perf']:CalculateVehiclePrice(model, category)
    end)
    if ok and price and price > 0 then
        return price
    end
    return nil
end

local function resolvePrice(model, defaultPrice, category)
    if Config.ManualPriceOverrides and Config.ManualPriceOverrides[model] and Config.ManualPriceOverrides[model] > 0 then
        return Config.ManualPriceOverrides[model]
    end

    if Config.UsePerformancePricing ~= false then
        local perfPrice = resolvePerformancePrice(model, category)
        if perfPrice then
            return perfPrice
        end
    end

    local override = Config.PriceOverrides[model]
    if override and override > 0 then
        return override
    end

    local price = math.max(1, tonumber(defaultPrice) or 1)
    local bands = Config.CivilianPriceBands
    if bands then
        local cat = category or 'other'
        local b = bands[cat] or bands._default
        if b and b.min and b.max then
            price = math.max(tonumber(b.min) or 0, math.min(tonumber(b.max) or price, price))
        end
    end
    return price
end

local function resolveVehicleMeta(model, category)
    if GetResourceState('mrp_vehicle_perf') ~= 'started' then
        return nil
    end
    local ok, result = pcall(function()
        local price, profile = exports['mrp_vehicle_perf']:CalculateVehiclePrice(model, category)
        return { price = price, profile = profile }
    end)
    if ok and result and result.profile then
        return result.profile
    end
    return nil
end

local function resolveCategory(model, baseCategory)
    if model == 'regina' or model == 'stratum' then
        return 'wagons'
    end
    return baseCategory or 'other'
end

local civilianBlockedMerged = nil

local function getCivilianBlocked()
    if not civilianBlockedMerged then
        civilianBlockedMerged = mergeCivilianBlocked()
    end
    return civilianBlockedMerged
end

--- Perkrovus resursą – atnaujinti sujungtą blokų lentelę.
local function refreshCivilianBlocked()
    civilianBlockedMerged = mergeCivilianBlocked()
end

local function isModelBlockedForCivilianShop(model, baseCategory)
    model = string.lower(model or '')
    local cat = tostring(baseCategory or '')

    if not civilianCategoryAllowed(cat) then
        return true
    end
    if cat == 'military' or cat == 'trains' then
        return true
    end

    if getCivilianBlocked()[model] then
        return true
    end

    local lower = model
    if lower:find('armored', 1, true) or lower:find('armour', 1, true) then
        return true
    end
    if lower:find('weapon', 1, true) or lower:find('gun', 1, true) then
        return true
    end

    return false
end

local function buildCatalog()
    refreshCivilianBlocked()
    local categories = {}
    local vehicles = {}
    for _, veh in pairs(QBCore.Shared.Vehicles) do
        if veh.model and veh.shop then
            local shops = normalizeShopValue(veh.shop)
            if shops.pdm or shops.luxury then
                local model = string.lower(veh.model)
                local category = resolveCategory(model, veh.category)
                if not isModelBlockedForCivilianShop(model, veh.category) then
                    local price = resolvePrice(model, veh.price, category)
                    local meta = resolveVehicleMeta(model, category)
                    categories[category] = Config.CategoryLabels[category] or category
                    vehicles[#vehicles + 1] = {
                        model = model,
                        name = veh.name or model,
                        brand = veh.brand or 'Unknown',
                        category = category,
                        price = price,
                        tier = meta and meta.tier or nil,
                        perf = meta and {
                            maxKmh = meta.maxKmh,
                            zeroTo100 = meta.zeroTo100,
                        } or nil,
                    }
                end
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

local function isPlateFree(plate)
    local r = MySQL.scalar.await('SELECT plate FROM player_vehicles WHERE plate = ? LIMIT 1', { plate })
    return not r
end

local function generatePlate()
    if GetResourceState('mrp_plates') == 'started' then
        return exports['mrp_plates']:GenerateText()
    end
    return (randomNumbers(1) .. randomLetters(2) .. randomNumbers(3) .. randomLetters(1)):upper()
end

local function getUniquePlate()
    if GetResourceState('mrp_plates') == 'started' then
        return exports['mrp_plates']:GenerateUnique()
    end
    for _ = 1, 25 do
        local p = generatePlate()
        if isPlateFree(p) then
            return p
        end
    end
    return generatePlate()
end

local function buildPurchaseProps(hash, plate, colorIdx)
    if GetResourceState('mrp_plates') == 'started' then
        return exports['mrp_plates']:BuildVehicleProps(hash, plate, colorIdx)
    end
    local props = {
        model = hash,
        plate = plate,
    }
    local c = tonumber(colorIdx)
    if c then
        props.color1 = c
        props.color2 = c
        props.pearlescentColor = 0
        props.wheelColor = 0
    end
    return props
end

CreateThread(function()
    MySQL.query.await([[
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

QBCore.Functions.CreateCallback('mrp_dealership:server:getCatalog', function(_, cb)
    cb(buildCatalog())
end)

CreateThread(function()
    Wait(3000)
    local rehExpected = Config.RehModels and #Config.RehModels or 0
    if rehExpected == 0 then return end

    local rehSet = {}
    for _, model in ipairs(Config.RehModels) do
        rehSet[string.lower(model)] = true
    end

    local catalog = buildCatalog()
    local rehInCatalog = 0
    for _, veh in ipairs(catalog.vehicles) do
        if rehSet[veh.model] then
            rehInCatalog = rehInCatalog + 1
        end
    end

    print(('[mrp_dealership] Simion catalog: %d vehicles, REH addon: %d / %d expected'):format(
        #catalog.vehicles, rehInCatalog, rehExpected
    ))

    if rehInCatalog == 0 then
        print('^1[mrp_dealership] WARNING: no REH addon cars in catalog — restart qb-core after vehicles_reh.lua changes')
    elseif rehInCatalog < rehExpected then
        print(('^3[mrp_dealership] WARNING: %d REH models missing from catalog (blocked or shop != pdm)'):format(rehExpected - rehInCatalog))
    end
end)

local function playerCanAccessPdFleet(src, model, forShop)
    if GetResourceState('mrp_bossmenu') ~= 'started' then
        --- Fallback į config jei bossmenu dar neup
        local pd = Config.PoliceDealership
        model = string.lower(tostring(model or ''))
        for _, v in ipairs((pd and pd.vehicles) or {}) do
            if v.model and string.lower(tostring(v.model)) == model then
                if forShop and v.shopEnabled == false then
                    return false, 'Šis modelis tik importui.'
                end
                local Player = QBCore.Functions.GetPlayer(src)
                if not Player then return false, 'Žaidėjas nerastas.' end
                local grade = tonumber(Player.PlayerData.job.grade and Player.PlayerData.job.grade.level) or 0
                local minG = tonumber(v.minGrade) or 0
                if v.arasOrGrade then
                    --- be bossmenu ARO check — tik rangas
                    if grade >= minG then return true end
                    return false, ('Reikia rango ≥ %d (arba ARO).'):format(minG)
                end
                if grade < minG then
                    return false, ('Reikia rango ≥ %d.'):format(minG)
                end
                return true
            end
        end
        return false, 'Modelis nerastas.'
    end
    return exports['mrp_bossmenu']:CanAccessPoliceFleetDetailed(src, model, { forShop = forShop ~= false })
end

local function buildPoliceCatalog(src)
    local pd = Config.PoliceDealership
    if not pd or not pd.vehicles then
        return { dealership = { label = 'PD' }, categories = {}, vehicles = {} }
    end
    local categories = {}
    local labels = pd.PoliceCategoryLabels or {}
    local vehicles = {}
    for _, v in ipairs(pd.vehicles) do
        local model = v.model and string.lower(tostring(v.model)) or ''
        if model ~= '' then
            local ok = playerCanAccessPdFleet(src, model, true)
            if ok then
                local cat = v.category or 'patrol'
                if not categories[cat] then
                    categories[cat] = labels[cat] or cat
                end
                vehicles[#vehicles + 1] = v
            end
        end
    end
    return {
        dealership = { label = pd.label or 'Policija' },
        categories = categories,
        vehicles = vehicles,
    }
end

QBCore.Functions.CreateCallback('mrp_dealership:server:getPoliceCatalog', function(source, cb)
    cb(buildPoliceCatalog(source))
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

QBCore.Functions.CreateCallback('mrp_dealership:server:getMechanicCatalog', function(_, cb)
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

QBCore.Functions.CreateCallback('mrp_dealership:server:getEmsCatalog', function(_, cb)
    cb(buildEmsCatalog())
end)

local function isPoliceJobPlayer(Player)
    if not Player or not Player.PlayerData.job then return false end
    local j = Player.PlayerData.job
    if not j.onduty then return false end
    local n = j.name
    return n == 'police'
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

local function isRangerJobPlayer(Player)
    if not Player or not Player.PlayerData.job then return false end
    local j = Player.PlayerData.job
    return j.name == 'ranger' and j.onduty
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

QBCore.Functions.CreateCallback('mrp_dealership:server:getTaxiCatalog', function(_, cb)
    cb(buildTaxiCatalog())
end)

local function buildRangerCatalog()
    local rd = Config.RangerDealership
    if not rd or not rd.vehicles then
        return { dealership = { label = 'Gamtos apsauga' }, categories = {}, vehicles = {} }
    end
    local categories = {}
    local labels = rd.RangerCategoryLabels or {}
    for _, v in ipairs(rd.vehicles) do
        local cat = v.category or 'patrol'
        if not categories[cat] then
            categories[cat] = labels[cat] or cat
        end
    end
    return {
        dealership = { label = rd.label or 'Gamtos apsauga' },
        categories = categories,
        vehicles = rd.vehicles,
    }
end

QBCore.Functions.CreateCallback('mrp_dealership:server:getRangerCatalog', function(_, cb)
    cb(buildRangerCatalog())
end)

local function buildSpecialDealershipCatalog(cfg)
    if not cfg or not cfg.vehicles then
        return { dealership = { label = 'Salonas' }, categories = {}, vehicles = {} }
    end
    local categories = {}
    local labels = cfg.CategoryLabels or {}
    for _, v in ipairs(cfg.vehicles) do
        local cat = v.category or 'other'
        if not categories[cat] then
            categories[cat] = labels[cat] or cat
        end
    end
    return {
        dealership = { label = cfg.label or 'Salonas' },
        categories = categories,
        vehicles = cfg.vehicles,
    }
end

local function buildBoatCatalog()
    return buildSpecialDealershipCatalog(Config.BoatDealership)
end

local function buildHeliCatalog()
    return buildSpecialDealershipCatalog(Config.HeliDealership)
end

QBCore.Functions.CreateCallback('mrp_dealership:server:getBoatCatalog', function(_, cb)
    cb(buildBoatCatalog())
end)

QBCore.Functions.CreateCallback('mrp_dealership:server:getHeliCatalog', function(_, cb)
    cb(buildHeliCatalog())
end)

local function buyCivilianSpecialVehicle(Player, cb, model, stationId, cfg, colorIdx, moneyReason)
    if not Player then return cb({ ok = false, message = 'Žaidėjas nerastas' }) end

    model = string.lower(tostring(model or ''))
    stationId = tostring(stationId or '')
    local garageId = cfg.garageByStation and cfg.garageByStation[stationId]
    local stSpawn = cfg.stations and cfg.stations[stationId]
    if not garageId or not stSpawn then
        return cb({ ok = false, message = 'Nežinoma stotis.' })
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
    local reason = moneyReason or 'mrp-dealership-special-buy'
    if price > 0 then
        if Player.PlayerData.money.bank >= price then
            paid = Player.Functions.RemoveMoney('bank', price, reason)
        elseif Player.PlayerData.money.cash >= price then
            paid = Player.Functions.RemoveMoney('cash', price, reason)
        end
        if not paid then
            return cb({ ok = false, message = 'Nepakanka pinigų.' })
        end
    else
        paid = true
    end

    local plate = getUniquePlate()
    local hash = joaat(model)
    local props = buildPurchaseProps(hash, plate, colorIdx)

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

QBCore.Functions.CreateCallback('mrp_dealership:server:buyPoliceVehicle', function(source, cb, model, stationId, colorIdx)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return cb({ ok = false, message = 'Žaidėjas nerastas' }) end
    if not isPoliceJobPlayer(Player) then
        return cb({ ok = false, message = 'Prieinama tik policijai tarnyboje.' })
    end

    model = string.lower(tostring(model or ''))
    stationId = tostring(stationId or 'sandy')
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

    local allowed, denyReason = playerCanAccessPdFleet(src, model, true)
    if not allowed then
        return cb({ ok = false, message = denyReason or 'Neturi teisės į šią mašiną.' })
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
    local props = buildPurchaseProps(hash, plate, colorIdx)

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

local function buyFleetJobVehicle(Player, cb, model, stationId, cfg, jobCheckFn, errJob, colorIdx)
    if not Player then return cb({ ok = false, message = 'Žaidėjas nerastas' }) end
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
    local props = buildPurchaseProps(hash, plate, colorIdx)

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

QBCore.Functions.CreateCallback('mrp_dealership:server:buyMechanicVehicle', function(source, cb, model, stationId, colorIdx)
    local Player = QBCore.Functions.GetPlayer(source)
    buyFleetJobVehicle(Player, cb, model, stationId or 'mech_ls', Config.MechanicDealership, isMechanicJobPlayer, 'Tik mechanikams tarnyboje.', colorIdx)
end)

QBCore.Functions.CreateCallback('mrp_dealership:server:buyEmsVehicle', function(source, cb, model, stationId, colorIdx)
    local Player = QBCore.Functions.GetPlayer(source)
    buyFleetJobVehicle(Player, cb, model, stationId or 'ems_ls', Config.EmsDealership, isEmsJobPlayer, 'Tik EMS tarnyboje.', colorIdx)
end)

QBCore.Functions.CreateCallback('mrp_dealership:server:buyTaxiVehicle', function(source, cb, model, stationId, colorIdx)
    local Player = QBCore.Functions.GetPlayer(source)
    buyFleetJobVehicle(Player, cb, model, stationId or 'taxi_ls', Config.TaxiDealership, isTaxiJobPlayer, 'Tik taksi tarnyboje.', colorIdx)
end)

QBCore.Functions.CreateCallback('mrp_dealership:server:buyRangerVehicle', function(source, cb, model, stationId, colorIdx)
    local Player = QBCore.Functions.GetPlayer(source)
    buyFleetJobVehicle(Player, cb, model, stationId or 'ranger_main', Config.RangerDealership, isRangerJobPlayer, 'Tik gamtosaugininkams tarnyboje.', colorIdx)
end)

QBCore.Functions.CreateCallback('mrp_dealership:server:buyBoatVehicle', function(source, cb, model, stationId, colorIdx)
    local Player = QBCore.Functions.GetPlayer(source)
    buyCivilianSpecialVehicle(Player, cb, model, stationId or 'ls', Config.BoatDealership, colorIdx, 'mrp-boat-dealership-buy')
end)

QBCore.Functions.CreateCallback('mrp_dealership:server:buyHeliVehicle', function(source, cb, model, stationId, colorIdx)
    local Player = QBCore.Functions.GetPlayer(source)
    buyCivilianSpecialVehicle(Player, cb, model, stationId or 'ls', Config.HeliDealership, colorIdx, 'mrp-heli-dealership-buy')
end)

QBCore.Functions.CreateCallback('mrp_dealership:server:buyVehicle', function(source, cb, model, colorIdx)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return cb({ ok = false, message = 'Žaidėjas nerastas' }) end

    model = string.lower(tostring(model or ''))
    local selectedVehicle = nil
    for _, v in pairs(buildCatalog().vehicles) do
        if v.model == model then
            selectedVehicle = v
            break
        end
    end
    if not selectedVehicle then
        return cb({ ok = false, message = 'Transportas nerastas kataloge' })
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
    local props = buildPurchaseProps(hash, plate, colorIdx)

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

