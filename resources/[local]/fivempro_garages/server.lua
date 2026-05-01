local QBCore = exports['qb-core']:GetCoreObject()

QBCore.Functions.CreateCallback('fivempro_garages:server:getPlayerVehicles', function(source, cb, garageId)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return cb({}) end

    local rows = MySQL.query.await([[
        SELECT vehicle, plate, mods, state, garage, fuel
        FROM player_vehicles
        WHERE citizenid = ?
        ORDER BY state DESC, vehicle ASC
    ]], { Player.PlayerData.citizenid })

    local vehicles = {}
    for i = 1, #rows do
        local r = rows[i]
        vehicles[#vehicles + 1] = {
            model = r.vehicle,
            plate = r.plate,
            state = tonumber(r.state) or 0,
            garage = r.garage,
            mods = r.mods,
            fuel = tonumber(r.fuel) or 0
        }
    end

    cb(vehicles)
end)

QBCore.Functions.CreateCallback('fivempro_garages:server:spawnVehicle', function(source, cb, plate, garageId)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return cb({ ok = false, message = 'Player not found' }) end

    plate = tostring(plate or ''):upper()
    local row = MySQL.single.await([[
        SELECT vehicle, plate, mods, state
        FROM player_vehicles
        WHERE citizenid = ? AND plate = ?
        LIMIT 1
    ]], { Player.PlayerData.citizenid, plate })

    if not row then
        return cb({ ok = false, message = 'Masina nerasta' })
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

    plate = tostring(plate or ''):upper()
    local exists = MySQL.scalar.await('SELECT plate FROM player_vehicles WHERE citizenid = ? AND plate = ? LIMIT 1', {
        Player.PlayerData.citizenid,
        plate
    })
    if not exists then
        return cb({ ok = false, message = 'Sita masina nepriklauso tau' })
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

