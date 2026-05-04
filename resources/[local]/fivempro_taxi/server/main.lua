local QBCore = exports['qb-core']:GetCoreObject()

local ActiveMeters = {}

local function nearCoords(src, coords, maxDist)
    maxDist = tonumber(maxDist) or 18.0
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end
    local p = GetEntityCoords(ped)
    local d = #(p - vector3(coords.x, coords.y, coords.z))
    return d <= maxDist
end

local function getTaxiPlayer(src)
    local P = QBCore.Functions.GetPlayer(src)
    if not P then return nil end
    local j = P.PlayerData.job
    if not j or j.name ~= Config.JobName or not j.onduty then
        return nil
    end
    return P
end

local function getGrade(src)
    local P = QBCore.Functions.GetPlayer(src)
    if not P then return -1 end
    return tonumber(P.PlayerData.job.grade.level) or 0
end

local function canBoss(src)
    local P = getTaxiPlayer(src)
    if not P then return false end
    if P.PlayerData.job.isboss then return true end
    return getGrade(src) >= (Config.Permissions.boss_menu or 2)
end

local function bossOutranks(bossSrc, targetGrade)
    local B = QBCore.Functions.GetPlayer(bossSrc)
    if not B then return false end
    if B.PlayerData.job.isboss then return true end
    return (tonumber(B.PlayerData.job.grade.level) or 0) > (tonumber(targetGrade) or 0)
end

local function isAllowedTaxiModel(model)
    model = tostring(model or ''):lower()
    return Config.AllowedTaxiModels and Config.AllowedTaxiModels[model] == true
end

local function getVehicleOccupants(vehicle)
    local list = {}
    if not vehicle or vehicle == 0 then return list end
    local players = QBCore.Functions.GetQBPlayers()
    local function sourceFromPed(pedEntity)
        for sid, _ in pairs(players) do
            if GetPlayerPed(sid) == pedEntity then
                return sid
            end
        end
        return nil
    end
    local maxP = GetVehicleMaxNumberOfPassengers(vehicle)
    for seat = -1, maxP - 1 do
        local ped = GetPedInVehicleSeat(vehicle, seat)
        if ped and ped ~= 0 then
            local src = sourceFromPed(ped)
            if src and src > 0 then
                list[#list + 1] = { src = src, seat = seat }
            end
        end
    end
    return list
end

local function collectPassengerIds(driverSrc, vehicle)
    local ids = {}
    local occupants = getVehicleOccupants(vehicle)
    for i = 1, #occupants do
        local o = occupants[i]
        if o.src ~= driverSrc and o.seat ~= -1 then
            ids[o.src] = true
        end
    end
    return ids
end

local function countMap(map)
    local c = 0
    for _ in pairs(map or {}) do
        c = c + 1
    end
    return c
end

local function chargePlayerAny(player, amount, reason)
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then return 0 end
    if player.PlayerData.money.bank >= amount then
        if player.Functions.RemoveMoney('bank', amount, reason) then return amount end
    end
    if player.PlayerData.money.cash >= amount then
        if player.Functions.RemoveMoney('cash', amount, reason) then return amount end
    end
    local total = (player.PlayerData.money.bank or 0) + (player.PlayerData.money.cash or 0)
    local partial = math.max(0, math.min(amount, total))
    if partial <= 0 then return 0 end
    local fromBank = math.min(player.PlayerData.money.bank or 0, partial)
    if fromBank > 0 then
        player.Functions.RemoveMoney('bank', fromBank, reason)
    end
    local rest = partial - fromBank
    if rest > 0 then
        player.Functions.RemoveMoney('cash', rest, reason)
    end
    return partial
end

local function chargePendingFare(driverSrc, meter, forcedPassengerMap)
    local pending = math.floor(tonumber(meter.pendingFare) or 0)
    if pending <= 0 then return 0 end

    local pMap = forcedPassengerMap or meter.lastPassengers or {}
    local ids = {}
    for sid in pairs(pMap) do
        ids[#ids + 1] = tonumber(sid)
    end
    if #ids == 0 then return 0 end

    local share = math.max(1, math.floor(pending / #ids))
    local chargedTotal = 0
    for i = 1, #ids do
        local targetSrc = ids[i]
        local target = QBCore.Functions.GetPlayer(targetSrc)
        if target and targetSrc ~= driverSrc then
            local charged = chargePlayerAny(target, share, 'fivempro-taxi-fare')
            chargedTotal = chargedTotal + charged
            if charged > 0 then
                TriggerClientEvent('QBCore:Notify', targetSrc, ('Taksi mokestis: €%s'):format(charged), 'primary')
            end
        end
    end

    if chargedTotal > 0 then
        local driver = QBCore.Functions.GetPlayer(driverSrc)
        if driver then
            driver.Functions.AddMoney('bank', chargedTotal, 'fivempro-taxi-fare-income')
            TriggerClientEvent('QBCore:Notify', driverSrc, ('Taxometras nuskaitė €%s'):format(chargedTotal), 'success')
        end
    end

    meter.pendingFare = math.max(0, pending - chargedTotal)
    return chargedTotal
end

local function sendMeterState(src, meter)
    TriggerClientEvent('fivempro_taxi:client:meterState', src, {
        active = true,
        fare = meter.fare,
        distanceKm = meter.distanceKm,
        waitingMin = meter.waitingMinutes,
        passengers = countMap(meter.lastPassengers),
    })
end

local function stopMeter(src, notify)
    local meter = ActiveMeters[src]
    if not meter then return end
    local tripSeconds = math.floor((GetGameTimer() - meter.startedAt) / 1000)
    local canCharge = tripSeconds >= (Config.Taximeter.minTripSecondsToCharge or 35)
        and meter.distanceKm >= (Config.Taximeter.minTripDistanceKmToCharge or 0.15)

    if canCharge then
        chargePendingFare(src, meter)
    else
        meter.pendingFare = 0
    end

    ActiveMeters[src] = nil
    TriggerClientEvent('fivempro_taxi:client:meterState', src, { active = false })
    if notify then
        if canCharge then
            TriggerClientEvent('QBCore:Notify', src, ('Važiavimas baigtas. Taxometras: €%s'):format(meter.fare), 'success')
        else
            TriggerClientEvent('QBCore:Notify', src, 'Važiavimas per trumpas apmokestinimui.', 'error')
        end
    end
end

RegisterNetEvent('fivempro_taxi:server:openStash', function()
    local src = source
    if GetResourceState('qb-inventory') ~= 'started' then
        return TriggerClientEvent('QBCore:Notify', src, 'qb-inventory neįjungtas.', 'error')
    end
    local Player = getTaxiPlayer(src)
    if not Player then
        return TriggerClientEvent('QBCore:Notify', src, 'Tik taksi tarnyboje.', 'error')
    end
    local st = Config.Stash
    if not nearCoords(src, st.coords, 22.0) then
        return TriggerClientEvent('QBCore:Notify', src, 'Per toli nuo sandėlio.', 'error')
    end
    exports['qb-inventory']:OpenInventory(src, st.stashId, {
        maxweight = st.maxweight,
        slots = st.slots,
        label = st.label,
    })
end)

RegisterNetEvent('fivempro_taxi:server:bossHire', function(targetId, grade)
    local src = source
    if not canBoss(src) or not nearCoords(src, Config.Management.coords, 18.0) then
        return TriggerClientEvent('QBCore:Notify', src, 'Negalima.', 'error')
    end
    targetId = tonumber(targetId)
    grade = tonumber(grade)
    if not targetId or grade == nil or grade < 0 or grade > (Config.MaxGrade or 2) then return end
    if not bossOutranks(src, grade) then
        return TriggerClientEvent('QBCore:Notify', src, 'Negali skirti tokio rango.', 'error')
    end
    local T = QBCore.Functions.GetPlayer(targetId)
    if not T then
        return TriggerClientEvent('QBCore:Notify', src, 'Žaidėjas neprisijungęs.', 'error')
    end
    T.Functions.SetJob(Config.JobName, grade)
    T.Functions.SetJobDuty(true)
    TriggerClientEvent('QBCore:Notify', src, 'Įdarbinta.', 'success')
    TriggerClientEvent('QBCore:Notify', targetId, 'Priimtas į taksi darbą.', 'success')
end)

RegisterNetEvent('fivempro_taxi:server:bossFire', function(targetId)
    local src = source
    if not canBoss(src) or not nearCoords(src, Config.Management.coords, 18.0) then
        return TriggerClientEvent('QBCore:Notify', src, 'Negalima.', 'error')
    end
    targetId = tonumber(targetId)
    if not targetId then return end
    local T = QBCore.Functions.GetPlayer(targetId)
    if not T or T.PlayerData.job.name ~= Config.JobName then return end
    local tg = tonumber(T.PlayerData.job.grade.level) or 0
    if not bossOutranks(src, tg) then
        return TriggerClientEvent('QBCore:Notify', src, 'Negali atleisti.', 'error')
    end
    T.Functions.SetJob('unemployed', 0)
    TriggerClientEvent('QBCore:Notify', src, 'Atleista.', 'success')
    TriggerClientEvent('QBCore:Notify', targetId, 'Atleistas iš taksi darbo.', 'error')
end)

RegisterNetEvent('fivempro_taxi:server:bossSetGrade', function(targetId, grade)
    local src = source
    if not canBoss(src) or not nearCoords(src, Config.Management.coords, 18.0) then
        return TriggerClientEvent('QBCore:Notify', src, 'Negalima.', 'error')
    end
    targetId = tonumber(targetId)
    grade = tonumber(grade)
    if not targetId or grade == nil or grade < 0 or grade > (Config.MaxGrade or 2) then return end
    local T = QBCore.Functions.GetPlayer(targetId)
    if not T or T.PlayerData.job.name ~= Config.JobName then return end
    local tg = tonumber(T.PlayerData.job.grade.level) or 0
    if not bossOutranks(src, tg) or not bossOutranks(src, grade) then
        return TriggerClientEvent('QBCore:Notify', src, 'Negali keisti.', 'error')
    end
    T.Functions.SetJob(Config.JobName, grade)
    TriggerClientEvent('QBCore:Notify', src, 'Rangas pakeistas.', 'success')
end)

RegisterNetEvent('fivempro_taxi:server:meterStart', function()
    local src = source
    local Player = getTaxiPlayer(src)
    if not Player then
        return TriggerClientEvent('QBCore:Notify', src, 'Tik taksi tarnyboje.', 'error')
    end
    if ActiveMeters[src] then
        return TriggerClientEvent('QBCore:Notify', src, 'Taxometras jau įjungtas.', 'error')
    end

    local ped = GetPlayerPed(src)
    local veh = GetVehiclePedIsIn(ped, false)
    if not veh or veh == 0 then
        return TriggerClientEvent('QBCore:Notify', src, 'Turi būti automobilyje.', 'error')
    end
    if GetPedInVehicleSeat(veh, -1) ~= ped then
        return TriggerClientEvent('QBCore:Notify', src, 'Turi būti vairuotojas.', 'error')
    end
    local model = string.lower(tostring(GetDisplayNameFromVehicleModel(GetEntityModel(veh)) or ''))
    if not isAllowedTaxiModel(model) then
        return TriggerClientEvent('QBCore:Notify', src, 'Leidžiamos tik taksi mašinos.', 'error')
    end

    local pos = GetEntityCoords(ped)
    ActiveMeters[src] = {
        vehicle = veh,
        vehicleModel = model,
        startedAt = GetGameTimer(),
        lastTick = GetGameTimer(),
        lastPos = pos,
        distanceKm = 0.0,
        waitingMinutes = 0.0,
        fare = math.floor(Config.Taximeter.baseFare or 0),
        pendingFare = 0,
        accountedFare = math.floor(Config.Taximeter.baseFare or 0),
        lastPassengers = {},
    }
    TriggerClientEvent('QBCore:Notify', src, 'Taxometras įjungtas.', 'success')
    sendMeterState(src, ActiveMeters[src])
end)

RegisterNetEvent('fivempro_taxi:server:meterStop', function()
    stopMeter(source, true)
end)

AddEventHandler('playerDropped', function()
    stopMeter(source, false)
end)

CreateThread(function()
    while true do
        local now = GetGameTimer()
        for src, meter in pairs(ActiveMeters) do
            local Player = getTaxiPlayer(src)
            if not Player then
                stopMeter(src, false)
            else
                local ped = GetPlayerPed(src)
                local veh = GetVehiclePedIsIn(ped, false)
                if not veh or veh == 0 or GetPedInVehicleSeat(veh, -1) ~= ped then
                    stopMeter(src, true)
                else
                    local model = string.lower(tostring(GetDisplayNameFromVehicleModel(GetEntityModel(veh)) or ''))
                    if not isAllowedTaxiModel(model) then
                        stopMeter(src, true)
                    else
                        local dt = math.max(0.1, (now - meter.lastTick) / 1000.0)
                        local pos = GetEntityCoords(ped)
                        local movedM = #(pos - meter.lastPos)
                        meter.lastPos = pos
                        meter.lastTick = now

                        movedM = math.max(0.0, math.min(movedM, Config.Taximeter.maxDistancePerTickM or 120.0))
                        local passengerMap = collectPassengerIds(src, veh)
                        meter.lastPassengers = passengerMap

                        if countMap(passengerMap) > 0 then
                            meter.distanceKm = meter.distanceKm + (movedM / 1000.0)
                            local kmh = (movedM / dt) * 3.6
                            if kmh < (Config.Taximeter.waitSpeedThresholdKmh or 8.0) then
                                meter.waitingMinutes = meter.waitingMinutes + (dt / 60.0)
                            end
                        end

                        local c = Config.Taximeter
                        local fair = (c.baseFare or 0)
                            + (meter.distanceKm * (c.perKm or 0))
                            + (meter.waitingMinutes * (c.perMinuteWait or 0))
                        meter.fare = math.floor(math.max(0, math.min(fair, c.maxFarePerTrip or 2500)))

                        local delta = math.max(0, meter.fare - meter.accountedFare)
                        if delta > 0 then
                            meter.pendingFare = meter.pendingFare + delta
                            meter.accountedFare = meter.fare
                        end

                        if meter.pendingFare >= (c.autoBillStep or 40) and countMap(passengerMap) > 0 then
                            chargePendingFare(src, meter, passengerMap)
                        end

                        sendMeterState(src, meter)
                    end
                end
            end
        end
        Wait(1000)
    end
end)
