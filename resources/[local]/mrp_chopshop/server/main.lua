local QBCore = exports['qb-core']:GetCoreObject()

local SCRAPPED_STATE = 3
local playerCooldownUntil = {}
local activeScraps = {}

local function getChopLocationById(locationId)
    for _, loc in ipairs((Config.ChopShop and Config.ChopShop.locations) or {}) do
        if loc.id == locationId then return loc end
    end
    return nil
end

local function playerNearChopLocation(src, locationId, extraRadius)
    local loc = getChopLocationById(locationId)
    if not loc then return false end
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end
    local p = GetEntityCoords(ped)
    local radius = (tonumber(loc.zoneRadius) or 15.0) + (extraRadius or 0.0)
    return #(p - loc.coords) <= radius
end

local function normalizePlate(plate)
    return QBCore.Shared.Trim and QBCore.Shared.Trim(tostring(plate or ''):upper()) or tostring(plate or ''):upper():gsub('^%s*(.-)%s*$', '%1')
end

local function resolveVehiclePrice(model)
    model = tostring(model or ''):lower()
    if model == '' then return 0 end

    if GetResourceState('mrp_vehicle_perf') == 'started' then
        local shared = QBCore.Shared.Vehicles[model]
        local ok, price = pcall(function()
            return exports['mrp_vehicle_perf']:CalculateVehiclePrice(model, shared and shared.category)
        end)
        if ok and price then return math.max(0, math.floor(tonumber(price) or 0)) end
    end

    local shared = QBCore.Shared.Vehicles[model]
    return math.max(0, math.floor(tonumber(shared and shared.price) or 0))
end

local function getPriceTier(price)
    price = tonumber(price) or 0
    for _, tier in ipairs((Config.ChopShop and Config.ChopShop.priceTiers) or {}) do
        if price >= (tonumber(tier.minPrice) or 0) and price <= (tonumber(tier.maxPrice) or 99999999) then
            return tier
        end
    end
    return ((Config.ChopShop and Config.ChopShop.priceTiers) or {})[1]
end

local function decodeMods(modsStr)
    if not modsStr or modsStr == '' then return {} end
    local ok, data = pcall(json.decode, modsStr)
    if ok and type(data) == 'table' then return data end
    return {}
end

local function encodeMods(mods)
    return json.encode(mods or {})
end

local function isServiceVehicle(mods)
    if type(mods) ~= 'table' then return false end
    return mods.pdKit == true or mods.emsKit == true or mods.serviceVehicle == true
end

local function addItem(src, Player, itemName, amount)
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then return true end
    local ok = Player.Functions.AddItem(itemName, amount)
    if not ok and GetResourceState('qb-inventory') == 'started' then
        ok = exports['qb-inventory']:AddItem(src, itemName, amount)
    end
    return ok
end

local function giveMarkedBills(src, Player, amount, reason)
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then return true end

    local itemName = tostring((Config.ChopShop or {}).payoutItem or 'markedbills'):lower()
    local shared = QBCore.Shared.Items[itemName]
    if not shared then
        Player.Functions.AddMoney('cash', amount, reason)
        return true
    end

    local ok = Player.Functions.AddItem(itemName, 1, false, { worth = amount })
    if not ok and GetResourceState('qb-inventory') == 'started' then
        ok = exports['qb-inventory']:AddItem(src, itemName, 1, nil, { worth = amount }, reason)
    end
    return ok
end

local function rollParts(tierId, multiplier)
    multiplier = tonumber(multiplier) or 1.0
    local tableDef = (Config.ChopShop and Config.ChopShop.tierParts and Config.ChopShop.tierParts[tierId]) or {}
    local parts = {}
    for _, row in ipairs(tableDef) do
        local minC = math.floor((tonumber(row.min) or 1) * multiplier)
        local maxC = math.floor((tonumber(row.max) or minC) * multiplier)
        if maxC < minC then maxC = minC end
        local count = math.random(minC, maxC)
        if count > 0 then
            parts[#parts + 1] = { item = row.item, count = count }
        end
    end
    return parts
end

local function grantParts(src, Player, parts)
    for _, p in ipairs(parts or {}) do
        if not addItem(src, Player, p.item, p.count) then
            return false, ('Nepavyko duoti: %s'):format(p.item)
        end
    end
    return true
end

--- Eksportas KMA — ar mašina ardyta ir kiek liko lock
function GetScrapInfo(modsStr, depotprice)
    local mods = decodeMods(modsStr)
    local chop = mods._chopshop
    if not chop or not chop.scrappedAt then
        return nil
    end

    local lockSec = tonumber((Config.ChopShop or {}).recoveryLockSeconds) or (48 * 3600)
    local scrappedAt = tonumber(chop.scrappedAt) or 0
    local now = os.time()
    local elapsed = math.max(0, now - scrappedAt)
    local remaining = math.max(0, lockSec - elapsed)
    local fee = math.floor(tonumber(depotprice) or tonumber(chop.recoveryFee) or 0)

    return {
        scrappedAt = scrappedAt,
        vehicleValue = tonumber(chop.vehicleValue) or 0,
        recoveryFee = fee,
        lockRemaining = remaining,
        canRecover = remaining <= 0,
    }
end

exports('GetScrapInfo', GetScrapInfo)
exports('GetScrappedState', function() return SCRAPPED_STATE end)
exports('GetLocations', function()
    return (Config.ChopShop and Config.ChopShop.locations) or {}
end)

QBCore.Functions.CreateCallback('mrp_chopshop:server:canScrap', function(source, cb, plate, locationId, netId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return cb({ ok = false, message = 'Žaidėjas nerastas' }) end

    if not getChopLocationById(locationId) then
        return cb({ ok = false, message = 'Netinkama vieta' })
    end
    if not playerNearChopLocation(src, locationId, 4.0) then
        return cb({ ok = false, message = 'Per toli nuo ardymo zonos' })
    end

    local now = os.time()
    if (playerCooldownUntil[src] or 0) > now then
        local left = playerCooldownUntil[src] - now
        return cb({ ok = false, message = ('Palauk %ds prieš kitą ardymą'):format(left) })
    end

    if activeScraps[src] then
        return cb({ ok = false, message = 'Jau vyksta ardymas' })
    end

    plate = normalizePlate(plate)
    if plate == '' then
        return cb({ ok = false, message = 'Netinkamas numeris' })
    end

    local row = MySQL.single.await([[
        SELECT vehicle, plate, state, mods, citizenid
        FROM player_vehicles WHERE plate = ? LIMIT 1
    ]], { plate })

    local isOwned = row ~= nil
    local model = nil
    local vehicleValue = 0

    if isOwned then
        local state = tonumber(row.state) or 0
        if state == SCRAPPED_STATE then
            return cb({ ok = false, message = 'Ši mašina jau ardyta — savininkas gali atgauti per KMA' })
        end
        local mods = decodeMods(row.mods)
        if isServiceVehicle(mods) then
            return cb({ ok = false, message = 'Tarnybinės transporto priemonės negali būti ardomos' })
        end
        model = row.vehicle
        vehicleValue = resolveVehiclePrice(model)
    else
        -- NPC / nežinoma DB — modelį patvirtins client per callback arba naudos default tier
        model = nil
        vehicleValue = 25000
    end

    local tier = getPriceTier(vehicleValue)
    cb({
        ok = true,
        isOwned = isOwned,
        model = model,
        vehicleValue = vehicleValue,
        tierId = tier and tier.id or 'budget',
        tierLabel = tier and tier.label or 'Paprasta',
        scrapMs = tier and tier.scrapMs or 45000,
        plate = plate,
        netId = netId,
        locationId = locationId,
    })
end)

RegisterNetEvent('mrp_chopshop:server:completeScrap', function(payload)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    if type(payload) ~= 'table' then return end

    local locationId = payload.locationId
    local plate = normalizePlate(payload.plate)
    local netId = tonumber(payload.netId)
    local clientModel = tostring(payload.model or ''):lower()
    local clientValue = tonumber(payload.vehicleValue)

    if plate == '' or not getChopLocationById(locationId) then return end
    if not playerNearChopLocation(src, locationId, 6.0) then
        return TriggerClientEvent('QBCore:Notify', src, 'Per toli nuo ardymo zonos', 'error')
    end

    local scrapToken = activeScraps[src]
    if not scrapToken or scrapToken.plate ~= plate or scrapToken.locationId ~= locationId then
        return TriggerClientEvent('QBCore:Notify', src, 'Ardymas nebuvo pradėtas', 'error')
    end
    if (scrapToken.startedAt or 0) + math.floor((scrapToken.scrapMs or 45000) / 1000) - 2 > os.time() then
        return TriggerClientEvent('QBCore:Notify', src, 'Per greitai — ardymas dar nebaigtas', 'error')
    end

    activeScraps[src] = nil

    local row = MySQL.single.await([[
        SELECT id, vehicle, plate, state, mods, citizenid
        FROM player_vehicles WHERE plate = ? LIMIT 1
    ]], { plate })

    local isOwned = row ~= nil
    local model = isOwned and row.vehicle or clientModel
    if not model or model == '' then model = 'sultan' end

    local vehicleValue = isOwned and resolveVehiclePrice(model) or (clientValue or resolveVehiclePrice(model))
    local tier = getPriceTier(vehicleValue)
    local tierId = tier and tier.id or 'budget'
    local multiplier = isOwned and 1.0 or (tonumber((Config.ChopShop or {}).npcPartsMultiplier) or 0.55)

    if isOwned then
        local state = tonumber(row.state) or 0
        if state == SCRAPPED_STATE then
            return TriggerClientEvent('QBCore:Notify', src, 'Mašina jau ardyta', 'error')
        end
        local mods = decodeMods(row.mods)
        if isServiceVehicle(mods) then
            return TriggerClientEvent('QBCore:Notify', src, 'Tarnybinė transporto priemonė', 'error')
        end

        local recoveryPct = tonumber((Config.ChopShop or {}).recoveryFeePercent) or 0.30
        local recoveryFee = math.floor(vehicleValue * recoveryPct)
        mods._chopshop = {
            scrappedAt = os.time(),
            vehicleValue = vehicleValue,
            recoveryFee = recoveryFee,
            scrappedBy = Player.PlayerData.citizenid,
        }

        MySQL.update.await([[
            UPDATE player_vehicles
            SET state = ?, depotprice = ?, mods = ?
            WHERE plate = ?
        ]], { SCRAPPED_STATE, recoveryFee, encodeMods(mods), plate })
    end

    local parts = rollParts(tierId, multiplier)
    local ok, err = grantParts(src, Player, parts)
    if not ok then
        return TriggerClientEvent('QBCore:Notify', src, err or 'Inventorius pilnas', 'error')
    end

    TriggerClientEvent('mrp_chopshop:client:deleteVehicle', src, netId, plate)

    local cd = tonumber((Config.ChopShop or {}).playerCooldownSeconds) or 300
    playerCooldownUntil[src] = os.time() + cd

    local partSummary = {}
    for _, p in ipairs(parts) do
        partSummary[#partSummary + 1] = ('%sx %s'):format(p.count, p.item)
    end

    TriggerClientEvent('QBCore:Notify', src,
        isOwned and ('Mašina %s ardyta. Savininkas negali atgauti 48 val.'):format(plate)
            or ('NPC transportas ardytas: %s'):format(table.concat(partSummary, ', ')),
        'success')

    if isOwned and row.citizenid then
        local owner = QBCore.Functions.GetPlayerByCitizenId(row.citizenid)
        if owner then
            TriggerClientEvent('QBCore:Notify', owner.PlayerData.source,
                ('Tavo transportas %s buvo ardytas! Atgauti galėsi per KMA po 48 val.'):format(plate),
                'error', 12000)
        end
    end

    if (Config.ChopShop or {}).policeAlertEnabled and math.random() < (tonumber(Config.ChopShop.policeAlertChance) or 0) then
        TriggerEvent('mrp_dispatch:server:chopshopAlert', src, locationId, plate)
    end
end)

RegisterNetEvent('mrp_chopshop:server:beginScrap', function(payload)
    local src = source
    if type(payload) ~= 'table' then return end

    local locationId = payload.locationId
    local plate = normalizePlate(payload.plate)
    local scrapMs = tonumber(payload.scrapMs) or 45000

    if not getChopLocationById(locationId) or plate == '' then return end
    if not playerNearChopLocation(src, locationId, 4.0) then return end

    activeScraps[src] = {
        plate = plate,
        locationId = locationId,
        scrapMs = scrapMs,
        startedAt = os.time(),
    }
end)

RegisterNetEvent('mrp_chopshop:server:cancelScrap', function()
    activeScraps[source] = nil
end)

AddEventHandler('playerDropped', function()
    activeScraps[source] = nil
    playerCooldownUntil[source] = nil
end)

-- Dalių supirkėjas
QBCore.Functions.CreateCallback('mrp_chopshop:server:getSellInventory', function(source, cb)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return cb({ ok = false, message = 'Klaida' }) end

    local items = {}
    local total = 0
    for itemName, unitPrice in pairs((Config.ChopShop or {}).buyerPrices or {}) do
        unitPrice = tonumber(unitPrice) or 0
        if unitPrice > 0 then
            local data = Player.Functions.GetItemByName(itemName)
            local count = data and (data.amount or data.count or 0) or 0
            if count > 0 then
                local shared = QBCore.Shared.Items[itemName]
                local lineTotal = count * unitPrice
                total = total + lineTotal
                items[#items + 1] = {
                    item = itemName,
                    label = shared and shared.label or itemName,
                    count = count,
                    unitPrice = unitPrice,
                    lineTotal = lineTotal,
                }
            end
        end
    end
    table.sort(items, function(a, b) return a.label < b.label end)
    cb({ ok = true, items = items, grandTotal = total })
end)

RegisterNetEvent('mrp_chopshop:server:sellPart', function(itemName, locationId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    itemName = tostring(itemName or ''):lower()
    local unitPrice = tonumber((Config.ChopShop.buyerPrices or {})[itemName])
    if not unitPrice or unitPrice <= 0 then return end

    if locationId and not playerNearChopLocation(src, locationId, 25.0) then
        return TriggerClientEvent('QBCore:Notify', src, 'Per toli nuo supirkėjo', 'error')
    end

    local data = Player.Functions.GetItemByName(itemName)
    local count = data and (data.amount or data.count or 0) or 0
    if count <= 0 then
        return TriggerClientEvent('QBCore:Notify', src, 'Neturi šios dalies', 'error')
    end

    if not Player.Functions.RemoveItem(itemName, 1) then
        return TriggerClientEvent('QBCore:Notify', src, 'Nepavyko parduoti', 'error')
    end

    if not giveMarkedBills(src, Player, unitPrice, 'chopshop-sell-part') then
        Player.Functions.AddItem(itemName, 1)
        return TriggerClientEvent('QBCore:Notify', src, 'Inventorius pilnas', 'error')
    end

    TriggerClientEvent('QBCore:Notify', src, ('Parduota 1x %s už nešvarius pinigus ($%s)'):format(itemName, unitPrice), 'success')
end)

RegisterNetEvent('mrp_chopshop:server:sellAllParts', function(locationId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    if locationId and not playerNearChopLocation(src, locationId, 25.0) then
        return TriggerClientEvent('QBCore:Notify', src, 'Per toli nuo supirkėjo', 'error')
    end

    local total = 0
    local sold = {}

    for itemName, unitPrice in pairs((Config.ChopShop or {}).buyerPrices or {}) do
        unitPrice = tonumber(unitPrice) or 0
        if unitPrice > 0 then
            local data = Player.Functions.GetItemByName(itemName)
            local count = data and (data.amount or data.count or 0) or 0
            while count > 0 do
                if not Player.Functions.RemoveItem(itemName, 1) then break end
                total = total + unitPrice
                sold[itemName] = (sold[itemName] or 0) + 1
                count = count - 1
                data = Player.Functions.GetItemByName(itemName)
                count = data and (data.amount or data.count or 0) or 0
            end
        end
    end

    if total <= 0 then
        return TriggerClientEvent('QBCore:Notify', src, 'Neturi dalių pardavimui', 'error')
    end

    if not giveMarkedBills(src, Player, total, 'chopshop-sell-all') then
        for itemName, cnt in pairs(sold) do
            Player.Functions.AddItem(itemName, cnt)
        end
        return TriggerClientEvent('QBCore:Notify', src, 'Inventorius pilnas', 'error')
    end

    TriggerClientEvent('QBCore:Notify', src, ('Parduota dalių už $%s (nešvarūs pinigai)'):format(total), 'success')
end)
