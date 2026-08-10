local QBCore = exports['qb-core']:GetCoreObject()

local supplyStock = {}

local function initSupplyStock()
    supplyStock = {}
    for item, count in pairs(Config.MaterialSupplySeedStock or {}) do
        supplyStock[item] = tonumber(count) or 0
    end
end

CreateThread(function()
    Wait(100)
    initSupplyStock()
end)

local function nearMaterialSupply(src)
    local cfg = Config.MaterialSupply
    if not cfg or not cfg.coords then return false end
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end
    local p = GetEntityCoords(ped)
    return #(p - cfg.coords) <= 18.0
end

local function isSupplyItem(itemName)
    itemName = tostring(itemName or '')
    if itemName == '' then return false end
    for _, name in ipairs(Config.MechanicSupplyItems or {}) do
        if name == itemName then return true end
    end
    return (Config.MechanicMaterialBuyPrices and Config.MechanicMaterialBuyPrices[itemName] ~= nil)
end

local function getPlayerItem(src, itemName)
    local Player = QBCore.Functions.GetPlayer(src)
    if Player and Player.Functions and Player.Functions.GetItemByName then
        return Player.Functions.GetItemByName(itemName)
    end
    if GetResourceState('qb-inventory') == 'started' then
        return exports['qb-inventory']:GetItemByName(src, itemName)
    end
end

local function itemAmount(itemData)
    return itemData and (itemData.amount or itemData.count or 0) or 0
end

local function getStock(itemName)
    return tonumber(supplyStock[itemName]) or 0
end

local function addStock(itemName, amount)
    amount = tonumber(amount) or 0
    if amount <= 0 then return end
    supplyStock[itemName] = getStock(itemName) + amount
end

local function removeStock(itemName, amount)
    amount = tonumber(amount) or 0
    if amount <= 0 then return false end
    local have = getStock(itemName)
    if have < amount then return false end
    supplyStock[itemName] = have - amount
    return true
end

QBCore.Functions.CreateCallback('mrp_mechanic:server:getMaterialSellList', function(source, cb)
    local src = source
    if not nearMaterialSupply(src) then
        return cb({ ok = false, message = 'Per toli nuo žaliavų punkto.' })
    end
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return cb({ ok = false, message = 'Žaidėjas nerastas.' }) end

    local items = {}
    local total = 0
    for _, itemName in ipairs(Config.MechanicSupplyItems or {}) do
        local price = tonumber(Config.MechanicMaterialBuyPrices and Config.MechanicMaterialBuyPrices[itemName]) or 0
        if price > 0 then
            local data = getPlayerItem(src, itemName)
            local count = itemAmount(data)
            if count > 0 then
                local shared = QBCore.Shared.Items[itemName]
                local rowTotal = price * count
                total = total + rowTotal
                items[#items + 1] = {
                    item = itemName,
                    label = shared and shared.label or itemName,
                    count = count,
                    price = price,
                    total = rowTotal,
                }
            end
        end
    end
    table.sort(items, function(a, b) return a.label < b.label end)
    cb({ ok = true, items = items, grandTotal = total })
end)

QBCore.Functions.CreateCallback('mrp_mechanic:server:getMaterialBuyList', function(source, cb)
    local src = source
    if not nearMaterialSupply(src) then
        return cb({ ok = false, message = 'Per toli nuo žaliavų punkto.' })
    end
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return cb({ ok = false, message = 'Žaidėjas nerastas.' }) end
    local j = Player.PlayerData.job
    if j.name ~= Config.JobName or not j.onduty then
        return cb({ ok = false, message = 'Tik mechanikams tarnyboje.' })
    end

    local items = {}
    for _, itemName in ipairs(Config.MechanicSupplyItems or {}) do
        local price = tonumber(Config.MechanicMaterialShopPrices and Config.MechanicMaterialShopPrices[itemName]) or 0
        local stock = getStock(itemName)
        if price > 0 and stock > 0 then
            local shared = QBCore.Shared.Items[itemName]
            items[#items + 1] = {
                item = itemName,
                label = shared and shared.label or itemName,
                stock = stock,
                price = price,
            }
        end
    end
    table.sort(items, function(a, b) return a.label < b.label end)
    cb({ ok = true, items = items })
end)

RegisterNetEvent('mrp_mechanic:server:sellMaterialToSupply', function(itemName, amount)
    local src = source
    if not nearMaterialSupply(src) then
        return TriggerClientEvent('QBCore:Notify', src, 'Per toli nuo žaliavų punkto.', 'error')
    end
    itemName = tostring(itemName or '')
    amount = math.max(1, math.min(100, tonumber(amount) or 1))
    if not isSupplyItem(itemName) then return end

    local price = tonumber(Config.MechanicMaterialBuyPrices and Config.MechanicMaterialBuyPrices[itemName]) or 0
    if price <= 0 then return end

    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    local data = getPlayerItem(src, itemName)
    local have = itemAmount(data)
    if have < amount then
        return TriggerClientEvent('QBCore:Notify', src, 'Neturi pakankamai.', 'error')
    end
    if not Player.Functions.RemoveItem(itemName, amount, false) then return end

    addStock(itemName, amount)
    local payout = price * amount
    Player.Functions.AddMoney('cash', payout, 'mechanic-material-supply-sell')
    TriggerClientEvent('QBCore:Notify', src, ('Parduota mechanikams: %s x%s ($%s)'):format(itemName, amount, payout), 'success')
end)

RegisterNetEvent('mrp_mechanic:server:sellAllMaterialsToSupply', function()
    local src = source
    if not nearMaterialSupply(src) then
        return TriggerClientEvent('QBCore:Notify', src, 'Per toli nuo žaliavų punkto.', 'error')
    end
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local total = 0
    local soldAny = false
    for _, itemName in ipairs(Config.MechanicSupplyItems or {}) do
        local price = tonumber(Config.MechanicMaterialBuyPrices and Config.MechanicMaterialBuyPrices[itemName]) or 0
        if price > 0 then
            local data = getPlayerItem(src, itemName)
            local amt = itemAmount(data)
            if amt > 0 and Player.Functions.RemoveItem(itemName, amt, false) then
                addStock(itemName, amt)
                total = total + (price * amt)
                soldAny = true
            end
        end
    end

    if soldAny and total > 0 then
        Player.Functions.AddMoney('cash', total, 'mechanic-material-supply-sell')
        TriggerClientEvent('QBCore:Notify', src, ('Parduota mechanikams už $%s'):format(total), 'success')
    else
        TriggerClientEvent('QBCore:Notify', src, 'Neturi ko parduoti.', 'error')
    end
end)

RegisterNetEvent('mrp_mechanic:server:buyMaterialFromSupply', function(itemName, amount)
    local src = source
    if not nearMaterialSupply(src) then
        return TriggerClientEvent('QBCore:Notify', src, 'Per toli nuo žaliavų punkto.', 'error')
    end
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    local j = Player.PlayerData.job
    if j.name ~= Config.JobName or not j.onduty then
        return TriggerClientEvent('QBCore:Notify', src, 'Tik mechanikams tarnyboje.', 'error')
    end

    itemName = tostring(itemName or '')
    amount = math.max(1, math.min(50, tonumber(amount) or 1))
    if not isSupplyItem(itemName) then return end

    local price = tonumber(Config.MechanicMaterialShopPrices and Config.MechanicMaterialShopPrices[itemName]) or 0
    if price <= 0 then return end
    if getStock(itemName) < amount then
        return TriggerClientEvent('QBCore:Notify', src, 'Sandėlyje trūksta žaliavų. Laukite kasėjų pristatymo.', 'error')
    end

    local cost = price * amount
    if Player.PlayerData.money.cash < cost and Player.PlayerData.money.bank < cost then
        return TriggerClientEvent('QBCore:Notify', src, ('Reikia $%s'):format(cost), 'error')
    end

    if not removeStock(itemName, amount) then
        return TriggerClientEvent('QBCore:Notify', src, 'Sandėlyje trūksta žaliavų.', 'error')
    end

    if not Player.Functions.AddItem(itemName, amount, false) then
        addStock(itemName, amount)
        return TriggerClientEvent('QBCore:Notify', src, 'Inventorius pilnas.', 'error')
    end

    if Player.PlayerData.money.cash >= cost then
        Player.Functions.RemoveMoney('cash', cost, 'mechanic-material-supply-buy')
    else
        Player.Functions.RemoveMoney('bank', cost, 'mechanic-material-supply-buy')
    end

    local shared = QBCore.Shared.Items[itemName]
    TriggerClientEvent('inventory:client:ItemBox', src, shared, 'add', amount)
    TriggerClientEvent('QBCore:Notify', src, ('Nupirkta: %s x%s ($%s)'):format(shared and shared.label or itemName, amount, cost), 'success')
end)
