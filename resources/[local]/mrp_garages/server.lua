local QBCore = exports['qb-core']:GetCoreObject()

local function isPdGarageId(garageId)
    garageId = tostring(garageId or '')
    return garageId:sub(1, 3) == 'pd_'
end

local function isMechanicGarageId(garageId)
    garageId = tostring(garageId or '')
    return garageId:sub(1, 5) == 'mech_'
end

local function isEmsGarageId(garageId)
    garageId = tostring(garageId or '')
    return garageId:sub(1, 4) == 'ems_'
end

local function isTaxiGarageId(garageId)
    garageId = tostring(garageId or '')
    return garageId:sub(1, 5) == 'taxi_'
end

local function isRangerGarageId(garageId)
    garageId = tostring(garageId or '')
    return garageId:sub(1, 7) == 'ranger_'
end

local function isPoliceJobPlayer(Player)
    if not Player or not Player.PlayerData.job then return false end
    local j = Player.PlayerData.job
    if not j.onduty then return false end
    local n = j.name
    return n == 'police'
end

local function isPoliceVehicleModel(modelName)
    modelName = tostring(modelName or ''):lower()
    local t = Config.PoliceVehicleModels or {}
    return t[modelName] == true
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

local function isMechanicVehicleModel(modelName)
    modelName = tostring(modelName or ''):lower()
    local t = Config.MechanicVehicleModels or {}
    return t[modelName] == true
end

local function isEmsVehicleModel(modelName)
    modelName = tostring(modelName or ''):lower()
    local t = Config.EmsVehicleModels or {}
    return t[modelName] == true
end

local function isTaxiVehicleModel(modelName)
    modelName = tostring(modelName or ''):lower()
    local t = Config.TaxiVehicleModels or {}
    return t[modelName] == true
end

local function isRangerVehicleModel(modelName)
    modelName = tostring(modelName or ''):lower()
    local t = Config.RangerVehicleModels or {}
    return t[modelName] == true
end

local function getGarageConfig(garageId)
    for _, g in ipairs(Config.Garages or {}) do
        if g.id == garageId then return g end
    end
end

local function getGarageTypeFilter(garageId)
    local g = getGarageConfig(garageId)
    return g and g.garageType or nil
end

local function getVehicleDbType(modelName)
    modelName = tostring(modelName or ''):lower()
    local v = QBCore.Shared.Vehicles[modelName]
    if v and v.type then return tostring(v.type):lower() end
    return 'automobile'
end

local function matchesGarageType(garageType, vehicleType)
    if not garageType or garageType == '' then return true end
    garageType = tostring(garageType):lower()
    vehicleType = tostring(vehicleType or ''):lower()
    if garageType == 'heli' then return vehicleType == 'heli' end
    if garageType == 'boat' then return vehicleType == 'boat' end
    return vehicleType ~= 'heli' and vehicleType ~= 'boat' and vehicleType ~= 'plane'
end

local function garageTypeMismatchMessage(garageType)
    garageType = tostring(garageType or ''):lower()
    if garageType == 'heli' then return 'Čia galima tik malūnsparnius.' end
    if garageType == 'boat' then return 'Čia galima tik laivus.' end
    return 'Čia galima tik automobilius ir motociklus.'
end

QBCore.Functions.CreateCallback('mrp_garages:server:getPlayerVehicles', function(source, cb, garageId)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return cb({}) end

    garageId = tostring(garageId or '')
    local pdGarage = isPdGarageId(garageId)
    local mechGarage = isMechanicGarageId(garageId)
    local emsgGarage = isEmsGarageId(garageId)
    local taxiGarage = isTaxiGarageId(garageId)
    local rangerGarage = isRangerGarageId(garageId)
    local garageType = getGarageTypeFilter(garageId)
    if pdGarage and not isPoliceJobPlayer(Player) then
        return cb({})
    end
    if mechGarage and not isMechanicJobPlayer(Player) then
        return cb({})
    end
    if emsgGarage and not isEmsJobPlayer(Player) then
        return cb({})
    end
    if taxiGarage and not isTaxiJobPlayer(Player) then
        return cb({})
    end
    if rangerGarage and not isRangerJobPlayer(Player) then
        return cb({})
    end

    local rows = MySQL.query.await([[
        SELECT vehicle, plate, mods, state, garage, fuel
        FROM player_vehicles
        WHERE citizenid = ?
        ORDER BY state DESC, vehicle ASC
    ]], { Player.PlayerData.citizenid })

    local vehicles = {}
    for i = 1, #rows do
        local r = rows[i]
        local modelLower = tostring(r.vehicle or ''):lower()
        local include = true
        if pdGarage then
            --- Visos PD mašinos — tik PD garaže (net jei DB garage buvo viešas)
            include = isPoliceVehicleModel(modelLower)
        elseif mechGarage then
            include = isMechanicVehicleModel(modelLower) and tostring(r.garage or '') == garageId
        elseif emsgGarage then
            include = isEmsVehicleModel(modelLower) and tostring(r.garage or '') == garageId
        elseif taxiGarage then
            include = isTaxiVehicleModel(modelLower) and tostring(r.garage or '') == garageId
        elseif rangerGarage then
            include = isRangerVehicleModel(modelLower) and tostring(r.garage or '') == garageId
        else
            --- Viešas / tipinis garažas — be tarnybinių PD mašinų
            if isPoliceVehicleModel(modelLower) then
                include = false
            elseif garageType then
                include = matchesGarageType(garageType, getVehicleDbType(modelLower))
            end
        end
        if include then
            vehicles[#vehicles + 1] = {
                model = r.vehicle,
                plate = r.plate,
                state = tonumber(r.state) or 0,
                garage = r.garage,
                mods = r.mods,
                fuel = tonumber(r.fuel) or 0
            }
        end
    end

    cb(vehicles)
end)

QBCore.Functions.CreateCallback('mrp_garages:server:spawnVehicle', function(source, cb, plate, garageId)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return cb({ ok = false, message = 'Žaidėjas nerastas' }) end

    garageId = tostring(garageId or '')
    if isPdGarageId(garageId) and not isPoliceJobPlayer(Player) then
        return cb({ ok = false, message = 'Tik policijai tarnyboje.' })
    end
    if isMechanicGarageId(garageId) and not isMechanicJobPlayer(Player) then
        return cb({ ok = false, message = 'Tik mechanikams tarnyboje.' })
    end
    if isEmsGarageId(garageId) and not isEmsJobPlayer(Player) then
        return cb({ ok = false, message = 'Tik EMS tarnyboje.' })
    end
    if isTaxiGarageId(garageId) and not isTaxiJobPlayer(Player) then
        return cb({ ok = false, message = 'Tik taksi tarnyboje.' })
    end
    if isRangerGarageId(garageId) and not isRangerJobPlayer(Player) then
        return cb({ ok = false, message = 'Tik gamtosaugininkams tarnyboje.' })
    end

    plate = tostring(plate or ''):upper()
    local row = MySQL.single.await([[
        SELECT vehicle, plate, mods, state, garage
        FROM player_vehicles
        WHERE citizenid = ? AND plate = ?
        LIMIT 1
    ]], { Player.PlayerData.citizenid, plate })

    if not row then
        return cb({ ok = false, message = 'Masina nerasta' })
    end

    if isPdGarageId(garageId) then
        if not isPoliceVehicleModel(row.vehicle) then
            return cb({ ok = false, message = 'Tai ne policijos transportas.' })
        end
        if GetResourceState('mrp_bossmenu') == 'started' then
            local allowed, reason
            local ok = pcall(function()
                allowed, reason = exports['mrp_bossmenu']:CanAccessPoliceFleetDetailed(source, row.vehicle, { forShop = false })
            end)
            if ok and allowed == false then
                return cb({ ok = false, message = reason or 'Neturi rango / divizijos teisių šiai mašinai.' })
            end
        end
        --- PD mašinas galima imti iš bet kurio PD garažo (perkeliam į šį)
    elseif isMechanicGarageId(garageId) then
        if not isMechanicVehicleModel(row.vehicle) then
            return cb({ ok = false, message = 'Tai ne mechanikų tarnybinis transportas.' })
        end
        if tostring(row.garage or '') ~= garageId then
            return cb({ ok = false, message = 'Masina saugoma kitame garaže.' })
        end
    elseif isEmsGarageId(garageId) then
        if not isEmsVehicleModel(row.vehicle) then
            return cb({ ok = false, message = 'Tai ne EMS transportas.' })
        end
        if tostring(row.garage or '') ~= garageId then
            return cb({ ok = false, message = 'Masina saugoma kitame garaže.' })
        end
    elseif isTaxiGarageId(garageId) then
        if not isTaxiVehicleModel(row.vehicle) then
            return cb({ ok = false, message = 'Tai ne taksi transportas.' })
        end
        if tostring(row.garage or '') ~= garageId then
            return cb({ ok = false, message = 'Masina saugoma kitame garaže.' })
        end
    elseif isRangerGarageId(garageId) then
        if not isRangerVehicleModel(row.vehicle) then
            return cb({ ok = false, message = 'Tai ne gamtos apsaugos transportas.' })
        end
        if tostring(row.garage or '') ~= garageId then
            return cb({ ok = false, message = 'Masina saugoma kitame garaže.' })
        end
    else
        if isPoliceVehicleModel(row.vehicle) then
            return cb({ ok = false, message = 'Policijos transportą imkite iš PD garažo.' })
        end
        local garageType = getGarageTypeFilter(garageId)
        if garageType and not matchesGarageType(garageType, getVehicleDbType(row.vehicle)) then
            return cb({ ok = false, message = garageTypeMismatchMessage(garageType) })
        end
        if tostring(row.garage or '') ~= garageId then
            return cb({ ok = false, message = 'Masina saugoma kitame garaže.' })
        end
    end

    if tonumber(row.state) ~= 1 then
        return cb({ ok = false, message = 'Masina turi buti pastatyta garaze' })
    end

    MySQL.update.await('UPDATE player_vehicles SET state = 0, garage = ? WHERE citizenid = ? AND plate = ?', {
        garageId,
        Player.PlayerData.citizenid,
        plate
    })

    local fuelPct = tonumber(row.fuel)
    if fuelPct == nil and row.mods and row.mods ~= '' then
        local ok, mods = pcall(json.decode, row.mods)
        if ok and mods and mods.fuelLevel ~= nil then
            fuelPct = tonumber(mods.fuelLevel)
        end
    end
    if fuelPct == nil then fuelPct = 100 end
    fuelPct = math.floor(math.max(0, math.min(100, fuelPct)) + 0.5)

    cb({
        ok = true,
        model = row.vehicle,
        plate = row.plate,
        mods = row.mods,
        fuel = fuelPct,
    })
end)

QBCore.Functions.CreateCallback('mrp_garages:server:parkVehicle', function(source, cb, plate, props, garageId)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return cb({ ok = false, message = 'Žaidėjas nerastas' }) end

    garageId = tostring(garageId or '')
    if isPdGarageId(garageId) then
        if not isPoliceJobPlayer(Player) then
            return cb({ ok = false, message = 'Tik policijai tarnyboje.' })
        end
    elseif isMechanicGarageId(garageId) then
        if not isMechanicJobPlayer(Player) then
            return cb({ ok = false, message = 'Tik mechanikams tarnyboje.' })
        end
    elseif isEmsGarageId(garageId) then
        if not isEmsJobPlayer(Player) then
            return cb({ ok = false, message = 'Tik EMS tarnyboje.' })
        end
    elseif isTaxiGarageId(garageId) then
        if not isTaxiJobPlayer(Player) then
            return cb({ ok = false, message = 'Tik taksi tarnyboje.' })
        end
    elseif isRangerGarageId(garageId) then
        if not isRangerJobPlayer(Player) then
            return cb({ ok = false, message = 'Tik gamtosaugininkams tarnyboje.' })
        end
    end

    plate = tostring(plate or ''):upper()
    local rowPark = MySQL.single.await('SELECT vehicle, mods FROM player_vehicles WHERE citizenid = ? AND plate = ? LIMIT 1', {
        Player.PlayerData.citizenid,
        plate
    })
    if not rowPark then
        return cb({ ok = false, message = 'Sita masina nepriklauso tau' })
    end

    if isPdGarageId(garageId) and not isPoliceVehicleModel(rowPark.vehicle) then
        return cb({ ok = false, message = 'Į PD garažą galima tik policijos transportą.' })
    end
    if not isPdGarageId(garageId) and isPoliceVehicleModel(rowPark.vehicle) then
        return cb({ ok = false, message = 'Policijos transportą statykite tik PD garaže.' })
    end
    if isMechanicGarageId(garageId) and not isMechanicVehicleModel(rowPark.vehicle) then
        return cb({ ok = false, message = 'Į šį garažą tik mechanikų tarnybinis transportas.' })
    end
    if isEmsGarageId(garageId) and not isEmsVehicleModel(rowPark.vehicle) then
        return cb({ ok = false, message = 'Į šį garažą tik EMS transportas.' })
    end
    if isTaxiGarageId(garageId) and not isTaxiVehicleModel(rowPark.vehicle) then
        return cb({ ok = false, message = 'Į šį garažą tik taksi transportas.' })
    end
    if isRangerGarageId(garageId) and not isRangerVehicleModel(rowPark.vehicle) then
        return cb({ ok = false, message = 'Į šį garažą tik gamtos apsaugos transportas.' })
    end

    local garageType = getGarageTypeFilter(garageId)
    if garageType and not matchesGarageType(garageType, getVehicleDbType(rowPark.vehicle)) then
        return cb({ ok = false, message = garageTypeMismatchMessage(garageType) })
    end

    local fuelPct = 100
    if props and props.fuelLevel ~= nil then
        fuelPct = math.floor(math.max(0, math.min(100, tonumber(props.fuelLevel) or 100)) + 0.5)
    end

    local saveProps = props or {}
    if rowPark and rowPark.mods and rowPark.mods ~= '' then
        local ok, existingMods = pcall(json.decode, rowPark.mods)
        if ok and type(existingMods) == 'table' then
            if saveProps.mrpPdKit ~= true and existingMods.mrpPdKit == true then
                saveProps.mrpPdKit = true
            end
            if saveProps.mrpEmsKit ~= true and existingMods.mrpEmsKit == true then
                saveProps.mrpEmsKit = true
            end
        end
    end

    MySQL.update.await([[
        UPDATE player_vehicles
        SET mods = ?, fuel = ?, state = 1, garage = ?
        WHERE citizenid = ? AND plate = ?
    ]], {
        json.encode(saveProps),
        fuelPct,
        garageId,
        Player.PlayerData.citizenid,
        plate
    })

    cb({ ok = true })
end)

