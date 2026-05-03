local QBCore = exports['qb-core']:GetCoreObject()

local mineCooldown = {}

local function nearMiningSite(src, siteIdx)
    siteIdx = tonumber(siteIdx)
    if not siteIdx or not Config.MiningSites[siteIdx] then return false end
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end
    local p = GetEntityCoords(ped)
    local s = Config.MiningSites[siteIdx]
    return #(p - s.coords) <= (tonumber(s.radius) or 80.0) + 12.0
end

local function nearProcess(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end
    local p = GetEntityCoords(ped)
    local c = Config.ProcessCoords
    return #(p - vector3(c.x, c.y, c.z)) <= 14.0
end

local function nearSell(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end
    local p = GetEntityCoords(ped)
    local c = Config.SellPed.coords
    return #(p - vector3(c.x, c.y, c.z)) <= 18.0
end

local function rollMineLoot()
    local total = 0.0
    for _, row in ipairs(Config.MineLoot or {}) do
        total = total + (tonumber(row.weight) or 0)
    end
    if total <= 0 then return 'stone_raw' end
    local r = math.random() * total
    local acc = 0.0
    for _, row in ipairs(Config.MineLoot or {}) do
        acc = acc + (tonumber(row.weight) or 0)
        if r <= acc then
            return row.item
        end
    end
    return Config.MineLoot[1].item
end

RegisterNetEvent('fivempro_mining:server:mineAttempt', function(siteIdx)
    local src = source
    siteIdx = tonumber(siteIdx)
    if not siteIdx or not nearMiningSite(src, siteIdx) then
        return TriggerClientEvent('QBCore:Notify', src, 'Netinkama vieta.', 'error')
    end
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    if not QBCore.Functions.HasItem(src, 'mining_pickaxe', 1) then
        return TriggerClientEvent('QBCore:Notify', src, 'Reikia kirtiklio inventoriuje.', 'error')
    end

    local now = os.time()
    if mineCooldown[src] and (now - mineCooldown[src]) < (Config.MineCooldown or 10) then
        return TriggerClientEvent('QBCore:Notify', src, 'Palaukite prieš kasdami dar kartą.', 'error')
    end

    local item = rollMineLoot()
    if Player.Functions.AddItem(item, 1, false) then
        mineCooldown[src] = now
        TriggerClientEvent('qb-inventory:client:ItemBox', src, QBCore.Shared.Items[item], 'add', 1)
        TriggerClientEvent('QBCore:Notify', src, ('Gavai: %s'):format(QBCore.Shared.Items[item].label), 'success')
    else
        TriggerClientEvent('QBCore:Notify', src, 'Inventorius pilnas.', 'error')
    end
end)

RegisterNetEvent('fivempro_mining:server:processBatch', function()
    local src = source
    if not nearProcess(src) then
        return TriggerClientEvent('QBCore:Notify', src, 'Per toli nuo perdirbimo.', 'error')
    end
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    local processed = 0
    for rawName, cleanName in pairs(Config.ProcessMap or {}) do
        local itemData = Player.Functions.GetItemByName(rawName)
        local amt = itemData and (itemData.amount or itemData.count or 0) or 0
        if amt and amt > 0 then
            if Player.Functions.RemoveItem(rawName, amt, false) then
                Player.Functions.AddItem(cleanName, amt, false)
                processed = processed + amt
            end
        end
    end
    if processed > 0 then
        TriggerClientEvent('QBCore:Notify', src, ('Perdirbta vienetų: %s'):format(processed), 'success')
    else
        TriggerClientEvent('QBCore:Notify', src, 'Neturi žalių rūdų.', 'error')
    end
end)

RegisterNetEvent('fivempro_mining:server:makeSteel', function()
    local src = source
    if not nearProcess(src) then
        return TriggerClientEvent('QBCore:Notify', src, 'Per toli nuo perdirbimo.', 'error')
    end
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    local R = Config.SteelRecipe
    if not R then return end
    local iron = Player.Functions.GetItemByName(R.iron)
    local coal = Player.Functions.GetItemByName(R.coal)
    local ic = iron and (iron.amount or iron.count or 0) or 0
    local cc = coal and (coal.amount or coal.count or 0) or 0
    local needI, needC = tonumber(R.ironCount) or 2, tonumber(R.coalCount) or 1
    if ic < needI or cc < needC then
        return TriggerClientEvent('QBCore:Notify', src, ('Reikia %sx geležies rūdos ir %sx anglies.'):format(needI, needC), 'error')
    end
    Player.Functions.RemoveItem(R.iron, needI, false)
    Player.Functions.RemoveItem(R.coal, needC, false)
    if Player.Functions.AddItem(R.steel, 1, false) then
        TriggerClientEvent('QBCore:Notify', src, 'Pagamintas plienas.', 'success')
    else
        Player.Functions.AddItem(R.iron, needI, false)
        Player.Functions.AddItem(R.coal, needC, false)
        TriggerClientEvent('QBCore:Notify', src, 'Inventorius pilnas.', 'error')
    end
end)

RegisterNetEvent('fivempro_mining:server:sellAll', function()
    local src = source
    if not nearSell(src) then
        return TriggerClientEvent('QBCore:Notify', src, 'Per toli nuo supirkėjo.', 'error')
    end
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    local total = 0
    for itemName, price in pairs(Config.SellPrices or {}) do
        local data = Player.Functions.GetItemByName(itemName)
        local amt = data and (data.amount or data.count or 0) or 0
        if amt and amt > 0 then
            local p = tonumber(price) or 0
            if p > 0 and Player.Functions.RemoveItem(itemName, amt, false) then
                total = total + (p * amt)
            end
        end
    end
    if total > 0 then
        Player.Functions.AddMoney('cash', total, 'mining-scrap-sell')
        TriggerClientEvent('QBCore:Notify', src, ('Parduota už $%s'):format(total), 'success')
    else
        TriggerClientEvent('QBCore:Notify', src, 'Neturi ko parduoti.', 'error')
    end
end)

QBCore.Functions.CreateUseableItem('mining_pickaxe', function(source, _)
    TriggerClientEvent('QBCore:Notify', source, 'Eik į karjerą (žemėlapyje „Karjeras — kasimas“) ir naudok qb-target.', 'primary', 6500)
end)
