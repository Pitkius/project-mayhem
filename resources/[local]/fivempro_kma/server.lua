local QBCore = exports['qb-core']:GetCoreObject()

local function getKmaLocationById(locationId)
    local id = tostring(locationId or '')
    for _, loc in ipairs((Config.Kma and Config.Kma.locations) or {}) do
        if loc.id == id then
            return loc
        end
    end
    return ((Config.Kma and Config.Kma.locations) or {})[1]
end

QBCore.Functions.CreateCallback('fivempro_kma:server:getVehicles', function(source, cb)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return cb({}) end

    local rows = MySQL.query.await([[
        SELECT vehicle, plate, mods, state, garage, fuel
        FROM player_vehicles
        WHERE citizenid = ? AND state = 0
        ORDER BY vehicle ASC
    ]], { Player.PlayerData.citizenid })

    local vehicles = {}
    for i = 1, #(rows or {}) do
        local r = rows[i]
        vehicles[#vehicles + 1] = {
            model = r.vehicle,
            plate = r.plate,
            state = tonumber(r.state) or 0,
            garage = r.garage,
            mods = r.mods,
            fuel = tonumber(r.fuel) or 0,
        }
    end

    cb(vehicles)
end)

QBCore.Functions.CreateCallback('fivempro_kma:server:reclaim', function(source, cb, plate, locationId)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return cb({ ok = false, message = 'Zaidėjas nerastas' }) end

    plate = tostring(plate or ''):upper()
    local fee = tonumber(Config.Kma.fee) or 5000
    local location = getKmaLocationById(locationId)
    local garageId = tostring((location and location.defaultGarage) or 'pillboxgarage')

    local row = MySQL.single.await([[
        SELECT vehicle, plate, state
        FROM player_vehicles
        WHERE citizenid = ? AND plate = ?
        LIMIT 1
    ]], { Player.PlayerData.citizenid, plate })

    if not row then
        return cb({ ok = false, message = 'Masina nerasta' })
    end

    if tonumber(row.state) ~= 0 then
        return cb({ ok = false, message = 'Si masina jau garaze arba neatitinka KMA' })
    end

    local paidWith = nil
    if Player.Functions.RemoveMoney('cash', fee, 'fivempro-kma-reclaim') then
        paidWith = 'cash'
    elseif Player.Functions.RemoveMoney('bank', fee, 'fivempro-kma-reclaim') then
        paidWith = 'bank'
    else
        return cb({ ok = false, message = ('Nepakanka pinigu (%s)'):format(fee) })
    end

    MySQL.update.await([[
        UPDATE player_vehicles
        SET state = 1, garage = ?
        WHERE citizenid = ? AND plate = ? AND state = 0
    ]], { garageId, Player.PlayerData.citizenid, plate })

    local verify = MySQL.single.await([[
        SELECT state, garage FROM player_vehicles
        WHERE citizenid = ? AND plate = ?
        LIMIT 1
    ]], { Player.PlayerData.citizenid, plate })

    if not verify or tonumber(verify.state) ~= 1 or tostring(verify.garage or '') ~= garageId then
        Player.Functions.AddMoney(paidWith, fee, 'fivempro-kma-refund')
        return cb({ ok = false, message = 'Nepavyko atnaujinti masinos (bandyk dar karta)' })
    end

    cb({ ok = true, message = ('Sumoketa $%s - masina perkelta i garaza "%s".'):format(fee, garageId) })
end)
