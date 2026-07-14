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

QBCore.Functions.CreateCallback('mrp_kma:server:getVehicles', function(source, cb)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return cb({}) end

    local rows = MySQL.query.await([[
        SELECT vehicle, plate, mods, state, garage, fuel, depotprice
        FROM player_vehicles
        WHERE citizenid = ? AND state IN (0, 2, 3)
        ORDER BY state DESC, vehicle ASC
    ]], { Player.PlayerData.citizenid })

    local vehicles = {}
    for i = 1, #(rows or {}) do
        local r = rows[i]
        local state = tonumber(r.state) or 0
        local scrapInfo = nil
        if state == 3 and GetResourceState('mrp_chopshop') == 'started' then
            local ok, info = pcall(function()
                return exports['mrp_chopshop']:GetScrapInfo(r.mods, r.depotprice)
            end)
            if ok then scrapInfo = info end
        end
        vehicles[#vehicles + 1] = {
            model = r.vehicle,
            plate = r.plate,
            state = state,
            garage = r.garage,
            mods = r.mods,
            fuel = tonumber(r.fuel) or 0,
            depotprice = tonumber(r.depotprice) or 0,
            scrapInfo = scrapInfo,
        }
    end

    cb(vehicles)
end)

QBCore.Functions.CreateCallback('mrp_kma:server:reclaim', function(source, cb, plate, locationId)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return cb({ ok = false, message = 'Zaidėjas nerastas' }) end

    plate = tostring(plate or ''):upper()
    local fee = tonumber(Config.Kma.fee) or 5000
    local location = getKmaLocationById(locationId)
    local garageId = tostring((location and location.defaultGarage) or 'pillboxgarage')

    local row = MySQL.single.await([[
        SELECT vehicle, plate, state, mods, depotprice
        FROM player_vehicles
        WHERE citizenid = ? AND plate = ?
        LIMIT 1
    ]], { Player.PlayerData.citizenid, plate })

    if not row then
        return cb({ ok = false, message = 'Masina nerasta' })
    end

    local state = tonumber(row.state) or 0
    local scrapInfo = nil
    if state == 3 and GetResourceState('mrp_chopshop') == 'started' then
        local ok, info = pcall(function()
            return exports['mrp_chopshop']:GetScrapInfo(row.mods, row.depotprice)
        end)
        if ok then scrapInfo = info end
    end

    if state == 3 then
        if not scrapInfo or not scrapInfo.canRecover then
            local hrs = scrapInfo and math.ceil((scrapInfo.lockRemaining or 0) / 3600) or 48
            return cb({ ok = false, message = ('Mašina ardyta — atgauti galėsi po ~%dh'):format(hrs) })
        end
        fee = math.max(fee, tonumber(scrapInfo.recoveryFee) or tonumber(row.depotprice) or fee)
    elseif state ~= 0 and state ~= 2 then
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

    local modsStr = row.mods
    if state == 3 and modsStr and modsStr ~= '' then
        local ok, mods = pcall(json.decode, modsStr)
        if ok and type(mods) == 'table' then
            mods._chopshop = nil
            modsStr = json.encode(mods)
        end
    end

    MySQL.update.await([[
        UPDATE player_vehicles
        SET state = 0, garage = ?, depotprice = 0, mods = ?
        WHERE citizenid = ? AND plate = ? AND state IN (0, 2, 3)
    ]], { garageId, modsStr, Player.PlayerData.citizenid, plate })

    local verify = MySQL.single.await([[
        SELECT state, garage FROM player_vehicles
        WHERE citizenid = ? AND plate = ?
        LIMIT 1
    ]], { Player.PlayerData.citizenid, plate })

    if not verify or tonumber(verify.state) ~= 0 or tostring(verify.garage or '') ~= garageId then
        Player.Functions.AddMoney(paidWith, fee, 'fivempro-kma-refund')
        return cb({ ok = false, message = 'Nepavyko atnaujinti masinos (bandyk dar karta)' })
    end

    cb({
        ok = true,
        model = row.vehicle,
        plate = row.plate,
        mods = row.mods,
        message = ('Sumoketa $%s - masina paruosta atsiemimui.'):format(fee)
    })
end)
