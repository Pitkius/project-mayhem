local QBCore = exports['qb-core']:GetCoreObject()

local function getPlayerNearStation(src)
    local ped = GetPlayerPed(src)
    if ped == 0 then return false end
    local pos = GetEntityCoords(ped)
    local maxD = (tonumber(Config.MaxDistanceToPump) or 4.5) + 10.0
    for _, s in ipairs(Config.Stations or {}) do
        if #(pos - vector3(s.x, s.y, s.z)) <= maxD then return true end
    end
    return false
end

RegisterNetEvent('mrp_fuel:server:payTick', function(method)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player or not getPlayerNearStation(src) then
        TriggerClientEvent('mrp_fuel:client:payResult', src, { ok = false })
        return
    end

    local unitPrice = math.max(1, math.floor(tonumber(Config.PricePerLiter) or 7))
    local perTick = tonumber(Config.LitersPerTick) or 1.2
    local cost = math.ceil(perTick * unitPrice)
    method = method == 'bank' and 'bank' or 'cash'

    local money = Player.PlayerData.money or {}
    local balance = math.floor(tonumber(money[method]) or 0)
    if balance >= cost then
        if not Player.Functions.RemoveMoney(method, cost, 'fuel-pump') then
            TriggerClientEvent('mrp_fuel:client:payResult', src, { ok = false })
            return
        end
        TriggerClientEvent('mrp_fuel:client:payResult', src, { ok = true })
        return
    end
    TriggerClientEvent('mrp_fuel:client:payResult', src, { ok = false })
end)

RegisterNetEvent('mrp_fuel:server:finish', function(data)
    local src = source
    if type(data) ~= 'table' then return end
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    -- Mokėjimas jau nuskaičiuotas per payTick; čia tik audit log placeholder
end)
