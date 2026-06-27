local QBCore = exports['qb-core']:GetCoreObject()

--- Ar žaidėjas vairuoja ir šalia kurios nors degalinės (serverio tikrinimas — nepasitikėti klientu)
local function getDriverVehicleNearStation(src)
    local ped = GetPlayerPed(src)
    if ped == 0 then return nil end
    local veh = GetVehiclePedIsIn(ped, false)
    if veh == 0 or GetPedInVehicleSeat(veh, -1) ~= ped then return nil end
    local pos = GetEntityCoords(veh)
    local vx, vy, vz = pos.x + 0.0, pos.y + 0.0, pos.z + 0.0
    local maxD = (tonumber(Config.MaxDistanceToPump) or 2.8) + 0.65
    for _, s in ipairs(Config.Stations or {}) do
        local sx, sy, sz = s.x + 0.0, s.y + 0.0, s.z + 0.0
        local d = math.sqrt((vx - sx) ^ 2 + (vy - sy) ^ 2 + (vz - sz) ^ 2)
        if d <= maxD then return veh end
    end
    return nil
end

RegisterNetEvent('mrp_fuel:server:payTick', function(_ignoredPriceFromClient)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then
        TriggerClientEvent('mrp_fuel:client:payResult', src, { ok = false })
        return
    end

    if not getDriverVehicleNearStation(src) then
        TriggerClientEvent('mrp_fuel:client:payResult', src, { ok = false })
        return
    end

    local unitPrice = math.max(1, math.floor(tonumber(Config.PricePerLiter) or 7))

    local bank = Player.PlayerData.money and Player.PlayerData.money.bank or 0
    local cash = Player.PlayerData.money and Player.PlayerData.money.cash or 0
    if cash >= unitPrice then
        Player.Functions.RemoveMoney('cash', unitPrice, 'fuel-pump')
        TriggerClientEvent('mrp_fuel:client:payResult', src, { ok = true })
        return
    end
    if bank >= unitPrice then
        Player.Functions.RemoveMoney('bank', unitPrice, 'fuel-pump')
        TriggerClientEvent('mrp_fuel:client:payResult', src, { ok = true })
        return
    end
    TriggerClientEvent('mrp_fuel:client:payResult', src, { ok = false })
end)
