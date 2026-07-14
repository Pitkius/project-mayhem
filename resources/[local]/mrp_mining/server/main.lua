local QBCore = exports['qb-core']:GetCoreObject()

local mineCooldown = {}

local PICKAXE_ITEM = 'mining_pickaxe'

local function getPlayerItem(src, itemName)
    if not src or not itemName then return nil end
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

local function playerHasMiningPickaxe(src)
    if not src then return false end
    return QBCore.Functions.HasItem(src, PICKAXE_ITEM, 1)
end

local function nearMiningWall(src, wallIdx)
    wallIdx = tonumber(wallIdx)
    local wall = wallIdx and Config.MiningWalls and Config.MiningWalls[wallIdx]
    if not wall then return false end
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end
    local p = GetEntityCoords(ped)
    local maxDist = math.max((tonumber(wall.length) or 40.0) * 0.55, (tonumber(wall.width) or 6.0) * 2.0) + 6.0
    return #(p - wall.center) <= maxDist
end

local function nearMiningSite(src, siteIdx)
    siteIdx = tonumber(siteIdx)
    if not siteIdx or not Config.MiningSites[siteIdx] then return false end
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end
    local p = GetEntityCoords(ped)
    local s = Config.MiningSites[siteIdx]
    return #(p - s.coords) <= (tonumber(s.radius) or 80.0) + 12.0
end

local function nearMiningArea(src, wallIdx)
    return nearMiningWall(src, wallIdx) or nearMiningSite(src, 1)
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

--- Seni lygiuoti kirtikliai → vienas `mining_pickaxe` (jei žaidėjas prisijungia)
local LEGACY_PICKAXES = {
    mining_pickaxe_tier2 = true,
    mining_pickaxe_tier3 = true,
    mining_pickaxe_tier4 = true,
    mining_pickaxe_tier5 = true,
}

local function migrateLegacyPickaxes(src)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    local converted = 0
    for itemName in pairs(LEGACY_PICKAXES) do
        local data = getPlayerItem(src, itemName)
        local amt = itemAmount(data)
        if amt and amt > 0 and Player.Functions.RemoveItem(itemName, amt, false) then
            converted = converted + amt
        end
    end
    if converted > 0 then
        Player.Functions.AddItem(PICKAXE_ITEM, converted, false)
        TriggerClientEvent('QBCore:Notify', src, ('Seni kirtikliai pakeisti į %sx Kirtiklis.'):format(converted), 'primary', 6000)
    end
end

AddEventHandler('QBCore:Server:PlayerLoaded', function(Player)
    local src = Player and Player.PlayerData and Player.PlayerData.source
    if not src then return end
    SetTimeout(1500, function()
        migrateLegacyPickaxes(src)
    end)
end)

RegisterNetEvent('mrp_mining:server:mineAttempt', function(wallIdx)
    local src = source
    wallIdx = tonumber(wallIdx)
    if not wallIdx or not nearMiningArea(src, wallIdx) then
        return TriggerClientEvent('QBCore:Notify', src, 'Netinkama vieta.', 'error')
    end
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    if not playerHasMiningPickaxe(src) then
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

RegisterNetEvent('mrp_mining:server:processBatch', function()
    local src = source
    if not nearProcess(src) then
        return TriggerClientEvent('QBCore:Notify', src, 'Per toli nuo perdirbimo.', 'error')
    end
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    local processed = 0
    for rawName, cleanName in pairs(Config.ProcessMap or {}) do
        local itemData = getPlayerItem(src, rawName)
        local amt = itemAmount(itemData)
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

local function runSteelRecipe(src, Player)
    local R = Config.SteelRecipe
    if not R then return false, 'Receptas nerastas.' end
    local iron = getPlayerItem(src, R.iron)
    local coal = getPlayerItem(src, R.coal)
    local ic = itemAmount(iron)
    local cc = itemAmount(coal)
    local needI, needC = tonumber(R.ironCount) or 2, tonumber(R.coalCount) or 1
    if ic < needI or cc < needC then
        return false, ('Reikia %sx geležies rūdos ir %sx anglies.'):format(needI, needC)
    end
    Player.Functions.RemoveItem(R.iron, needI, false)
    Player.Functions.RemoveItem(R.coal, needC, false)
    if Player.Functions.AddItem(R.steel, 1, false) then
        return true, 'Pagamintas plienas.'
    end
    Player.Functions.AddItem(R.iron, needI, false)
    Player.Functions.AddItem(R.coal, needC, false)
    return false, 'Inventorius pilnas.'
end

local function runSmeltRecipe(src, Player, key)
    local R = Config.SmeltingRecipes and Config.SmeltingRecipes[key]
    if not R then return false, 'Receptas nerastas.' end
    local inputItem = getPlayerItem(src, R.input)
    local need = tonumber(R.inputCount) or 1
    local have = itemAmount(inputItem)
    if have < need then
        return false, ('Reikia %sx %s.'):format(need, R.input)
    end
    Player.Functions.RemoveItem(R.input, need, false)
    local outCount = tonumber(R.outputCount) or 1
    if Player.Functions.AddItem(R.output, outCount, false) then
        return true, ('Pagaminta: %s x%s'):format(R.output, outCount)
    end
    Player.Functions.AddItem(R.input, need, false)
    return false, 'Inventorius pilnas.'
end

local function runRubberRecipe(src, Player)
    local R = Config.RubberRecipe
    if not R then return false, 'Receptas nerastas.' end
    local gravel = getPlayerItem(src, R.gravel)
    local coal = getPlayerItem(src, R.coal)
    local gc = itemAmount(gravel)
    local cc = itemAmount(coal)
    local needG, needC = tonumber(R.gravelCount) or 3, tonumber(R.coalCount) or 1
    if gc < needG or cc < needC then
        return false, ('Reikia %sx žvyro ir %sx anglies.'):format(needG, needC)
    end
    Player.Functions.RemoveItem(R.gravel, needG, false)
    Player.Functions.RemoveItem(R.coal, needC, false)
    if Player.Functions.AddItem(R.output, tonumber(R.outputCount) or 1, false) then
        return true, 'Pagaminta guma.'
    end
    Player.Functions.AddItem(R.gravel, needG, false)
    Player.Functions.AddItem(R.coal, needC, false)
    return false, 'Inventorius pilnas.'
end

local function runGlassRecipe(src, Player)
    local R = Config.GlassRecipe
    if not R then return false, 'Receptas nerastas.' end
    local stone = getPlayerItem(src, R.stone)
    local gravel = getPlayerItem(src, R.gravel)
    local sc = itemAmount(stone)
    local gc = itemAmount(gravel)
    local needS, needG = tonumber(R.stoneCount) or 2, tonumber(R.gravelCount) or 1
    if sc < needS or gc < needG then
        return false, ('Reikia %sx akmens ir %sx žvyro.'):format(needS, needG)
    end
    Player.Functions.RemoveItem(R.stone, needS, false)
    Player.Functions.RemoveItem(R.gravel, needG, false)
    if Player.Functions.AddItem(R.output, tonumber(R.outputCount) or 1, false) then
        return true, 'Pagamintas stiklas.'
    end
    Player.Functions.AddItem(R.stone, needS, false)
    Player.Functions.AddItem(R.gravel, needG, false)
    return false, 'Inventorius pilnas.'
end

RegisterNetEvent('mrp_mining:server:processRecipe', function(recipeKey)
    local src = source
    if not nearProcess(src) then
        return TriggerClientEvent('QBCore:Notify', src, 'Per toli nuo perdirbimo.', 'error')
    end
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local ok, msg = false, 'Nežinomas receptas.'
    recipeKey = tostring(recipeKey or '')
    if recipeKey == 'steel' then
        ok, msg = runSteelRecipe(src, Player)
    elseif Config.SmeltingRecipes and Config.SmeltingRecipes[recipeKey] then
        ok, msg = runSmeltRecipe(src, Player, recipeKey)
    elseif recipeKey == 'rubber' then
        ok, msg = runRubberRecipe(src, Player)
    elseif recipeKey == 'glass' then
        ok, msg = runGlassRecipe(src, Player)
    end

    if ok then
        TriggerClientEvent('QBCore:Notify', src, msg, 'success')
    else
        TriggerClientEvent('QBCore:Notify', src, msg or 'Nepavyko.', 'error')
    end
end)

RegisterNetEvent('mrp_mining:server:makeSteel', function()
    local src = source
    if not nearProcess(src) then
        return TriggerClientEvent('QBCore:Notify', src, 'Per toli nuo perdirbimo.', 'error')
    end
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    local ok, msg = runSteelRecipe(src, Player)
    TriggerClientEvent('QBCore:Notify', src, msg, ok and 'success' or 'error')
end)

QBCore.Functions.CreateCallback('mrp_mining:server:getSellInventory', function(source, cb)
    local src = source
    if not nearSell(src) then
        return cb({ ok = false, message = 'Per toli nuo supirkėjo.' })
    end
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return cb({ ok = false, message = 'Žaidėjas nerastas.' }) end

    local items = {}
    local total = 0
    for itemName, price in pairs(Config.SellPrices or {}) do
        local data = getPlayerItem(src, itemName)
        local count = itemAmount(data)
        local p = tonumber(price) or 0
        if p > 0 and count > 0 then
            local it = QBCore.Shared.Items[itemName]
            local rowTotal = p * count
            total = total + rowTotal
            items[#items + 1] = {
                item = itemName,
                label = it and it.label or itemName,
                count = count,
                price = p,
                total = rowTotal,
            }
        end
    end
    table.sort(items, function(a, b) return a.label < b.label end)
    cb({ ok = true, items = items, grandTotal = total })
end)

RegisterNetEvent('mrp_mining:server:sellItem', function(itemName)
    local src = source
    if not nearSell(src) then
        return TriggerClientEvent('QBCore:Notify', src, 'Per toli nuo supirkėjo.', 'error')
    end
    itemName = tostring(itemName or '')
    local price = tonumber(Config.SellPrices and Config.SellPrices[itemName]) or 0
    if price <= 0 then return end
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    local data = getPlayerItem(src, itemName)
    local amt = itemAmount(data)
    if amt < 1 then
        return TriggerClientEvent('QBCore:Notify', src, 'Neturi šio daikto.', 'error')
    end
    if Player.Functions.RemoveItem(itemName, amt, false) then
        local total = price * amt
        Player.Functions.AddMoney('cash', total, 'mining-scrap-sell')
        TriggerClientEvent('QBCore:Notify', src, ('Parduota už $%s'):format(total), 'success')
    end
end)

RegisterNetEvent('mrp_mining:server:sellAll', function()
    local src = source
    if not nearSell(src) then
        return TriggerClientEvent('QBCore:Notify', src, 'Per toli nuo supirkėjo.', 'error')
    end
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    local total = 0
    for itemName, price in pairs(Config.SellPrices or {}) do
        local data = getPlayerItem(src, itemName)
        local amt = itemAmount(data)
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

QBCore.Functions.CreateUseableItem(PICKAXE_ITEM, function(source, _)
    local hint = Config.MechanicSupplyHint or ''
    TriggerClientEvent('QBCore:Notify', source, 'Eik į karjerą ir kasinėk. Perdirbk rūdas, tada gali parduoti mechanikams LS dokuose.', 'primary', 7500)
end)
