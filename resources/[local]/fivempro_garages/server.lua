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

local function isPoliceJobPlayer(Player)
    if not Player or not Player.PlayerData.job then return false end
    local j = Player.PlayerData.job
    if not j.onduty then return false end
    local n = j.name
    return n == 'ltpd' or n == 'police'
end

local function isPoliceVehicleModel(modelName)
    modelName = tostring(modelName or ''):lower()
    local t = Config.PoliceVehicleModels or {}
    return t[modelName] == true
end

local function isMechanicJobPlayer(Player)
    if not Player or not Player.PlayerData.job then return false end
    local j = Player.PlayerData.job
    return j.name == 'fivempro_mechanic' and j.onduty
end

local function isEmsJobPlayer(Player)
    if not Player or not Player.PlayerData.job then return false end
    local j = Player.PlayerData.job
    return j.name == 'fivempro_ambulance' and j.onduty
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

QBCore.Functions.CreateCallback('fivempro_garages:server:getPlayerVehicles', function(source, cb, garageId)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return cb({}) end

    garageId = tostring(garageId or '')
    local pdGarage = isPdGarageId(garageId)
    local mechGarage = isMechanicGarageId(garageId)
    local emsgGarage = isEmsGarageId(garageId)
    if pdGarage and not isPoliceJobPlayer(Player) then
        return cb({})
    end
    if mechGarage and not isMechanicJobPlayer(Player) then
        return cb({})
    end
    if emsgGarage and not isEmsJobPlayer(Player) then
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
            include = isPoliceVehicleModel(modelLower) and tostring(r.garage or '') == garageId
        elseif mechGarage then
            include = isMechanicVehicleModel(modelLower) and tostring(r.garage or '') == garageId
        elseif emsgGarage then
            include = isEmsVehicleModel(modelLower) and tostring(r.garage or '') == garageId
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

QBCore.Functions.CreateCallback('fivempro_garages:server:spawnVehicle', function(source, cb, plate, garageId)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return cb({ ok = false, message = 'Player not found' }) end

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
        if tostring(row.garage or '') ~= garageId then
            return cb({ ok = false, message = 'Masina saugoma kitame garaže.' })
        end
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
    end

    if tonumber(row.state) ~= 1 then
        return cb({ ok = false, message = 'Masina turi buti pastatyta garaze' })
    end

    MySQL.update.await('UPDATE player_vehicles SET state = 0, garage = ? WHERE citizenid = ? AND plate = ?', {
        garageId,
        Player.PlayerData.citizenid,
        plate
    })

    cb({
        ok = true,
        model = row.vehicle,
        plate = row.plate,
        mods = row.mods
    })
end)

QBCore.Functions.CreateCallback('fivempro_garages:server:parkVehicle', function(source, cb, plate, props, garageId)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return cb({ ok = false, message = 'Player not found' }) end

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
    end

    plate = tostring(plate or ''):upper()
    local rowPark = MySQL.single.await('SELECT vehicle FROM player_vehicles WHERE citizenid = ? AND plate = ? LIMIT 1', {
        Player.PlayerData.citizenid,
        plate
    })
    if not rowPark then
        return cb({ ok = false, message = 'Sita masina nepriklauso tau' })
    end

    if isPdGarageId(garageId) and not isPoliceVehicleModel(rowPark.vehicle) then
        return cb({ ok = false, message = 'Į PD garažą galima tik policijos transportą.' })
    end
    if isMechanicGarageId(garageId) and not isMechanicVehicleModel(rowPark.vehicle) then
        return cb({ ok = false, message = 'Į šį garažą tik mechanikų tarnybinis transportas.' })
    end
    if isEmsGarageId(garageId) and not isEmsVehicleModel(rowPark.vehicle) then
        return cb({ ok = false, message = 'Į šį garažą tik EMS transportas.' })
    end

    MySQL.update.await([[
        UPDATE player_vehicles
        SET mods = ?, state = 1, garage = ?
        WHERE citizenid = ? AND plate = ?
    ]], {
        json.encode(props or {}),
        garageId,
        Player.PlayerData.citizenid,
        plate
    })

    cb({ ok = true })
end)

