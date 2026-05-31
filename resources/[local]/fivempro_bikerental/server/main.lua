local QBCore = exports['qb-core']:GetCoreObject()

local activeRentals = {}

local function getLocation(id)
    for _, loc in ipairs(Config.Locations) do
        if loc.id == id then return loc end
    end
end

local function getBikeCfg(model)
    model = string.lower(tostring(model or ''))
    for _, b in ipairs(Config.Bikes) do
        if string.lower(b.model) == model then return b end
    end
end

local function nearLocation(src, locationId, maxDist)
    maxDist = maxDist or 5.0
    local loc = getLocation(locationId)
    if not loc then return false end
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end
    local p = GetEntityCoords(ped)
    local c = loc.coords
    return #(p - vector3(c.x, c.y, c.z)) <= maxDist
end

local function makePlate()
    return ('BK%04d'):format(math.random(1000, 9999))
end

RegisterNetEvent('fivempro_bikerental:server:rent', function(locationId, model)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    if not nearLocation(src, locationId, 5.0) then
        return TriggerClientEvent('QBCore:Notify', src, 'Per toli nuo nuomos punkto.', 'error')
    end
    local bike = getBikeCfg(model)
    if not bike then return end
    local price = tonumber(bike.price) or 0
    if price > 0 then
        if Player.PlayerData.money.cash >= price then
            Player.Functions.RemoveMoney('cash', price, 'bike-rental')
        elseif Player.PlayerData.money.bank >= price then
            Player.Functions.RemoveMoney('bank', price, 'bike-rental')
        else
            return TriggerClientEvent('QBCore:Notify', src, 'Nepakanka pinigų.', 'error')
        end
    end
    local cid = Player.PlayerData.citizenid
    activeRentals[cid] = { model = bike.model, price = price, locationId = locationId }
    TriggerClientEvent('fivempro_bikerental:client:spawnBike', src, locationId, bike.model, makePlate())
end)

RegisterNetEvent('fivempro_bikerental:server:returnBike', function(locationId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    if not nearLocation(src, locationId, 8.0) then
        return TriggerClientEvent('QBCore:Notify', src, 'Grąžink dviratį nuomos punkte.', 'error')
    end
    local cid = Player.PlayerData.citizenid
    local rental = activeRentals[cid]
    if not rental then
        return TriggerClientEvent('QBCore:Notify', src, 'Neturi nuomoto dviračio.', 'error')
    end
    local refund = 0
    local pct = tonumber(Config.RefundPercent) or 0
    if pct > 0 and rental.price and rental.price > 0 then
        refund = math.floor(rental.price * (pct / 100))
        if refund > 0 then
            Player.Functions.AddMoney('cash', refund, 'bike-rental-refund')
        end
    end
    activeRentals[cid] = nil
    TriggerClientEvent('fivempro_bikerental:client:returnedBike', src, refund)
end)

AddEventHandler('playerDropped', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if Player and Player.PlayerData then
        activeRentals[Player.PlayerData.citizenid] = nil
    end
end)
