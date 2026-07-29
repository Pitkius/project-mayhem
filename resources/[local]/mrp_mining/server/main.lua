local QBCore = exports['qb-core']:GetCoreObject()

local mineCooldown = {}
local sandCooldown = {}
local trashCooldown = {} --- [src] = { [key] = unix }

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

local function giveItemNotify(src, Player, item, count)
    count = tonumber(count) or 1
    if not Player.Functions.AddItem(item, count, false) then
        return false
    end
    local shared = QBCore.Shared.Items[item]
    if shared then
        TriggerClientEvent('qb-inventory:client:ItemBox', src, shared, 'add', count)
    end
    return true
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

local function nearSandSite(src, sandIdx)
    sandIdx = tonumber(sandIdx)
    local site = sandIdx and Config.SandDigSites and Config.SandDigSites[sandIdx]
    if not site then return false end
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end
    local p = GetEntityCoords(ped)
    local maxDist = math.max((tonumber(site.length) or 30.0) * 0.6, (tonumber(site.width) or 20.0) * 0.6) + 8.0
    return #(p - site.center) <= maxDist
end

local function nearClean(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end
    local p = GetEntityCoords(ped)
    local c = Config.CleanCoords or Config.ProcessCoords
    if not c then return false end
    return #(p - vector3(c.x, c.y, c.z)) <= 14.0
end

local function nearSmelt(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end
    local p = GetEntityCoords(ped)
    local c = Config.SmeltCoords
    if not c then return false end
    return #(p - vector3(c.x, c.y, c.z)) <= 14.0
end

local function nearSell(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end
    local p = GetEntityCoords(ped)
    local c = Config.SellPed.coords
    return #(p - vector3(c.x, c.y, c.z)) <= 18.0
end

local function rollWeighted(list, fallback)
    local total = 0.0
    for _, row in ipairs(list or {}) do
        total = total + (tonumber(row.weight) or 0)
    end
    if total <= 0 then return fallback end
    local r = math.random() * total
    local acc = 0.0
    for _, row in ipairs(list or {}) do
        acc = acc + (tonumber(row.weight) or 0)
        if r <= acc then
            return row.item
        end
    end
    return list[1] and list[1].item or fallback
end

local function rollMineLoot()
    return rollWeighted(Config.MineLoot, 'stone_raw')
end

local function rollSandLoot()
    return rollWeighted(Config.SandLoot, 'sand_raw')
end

local function rollTrashLoot()
    return rollWeighted(Config.TrashLoot, 'dirty_plastic_bottle')
end

local function findSmeltRecipe(id)
    for _, r in ipairs(Config.SmeltRecipes or {}) do
        if r.id == id then return r end
    end
end

local function convertMapBatch(src, Player, map)
    local processed = 0
    for rawName, cleanName in pairs(map or {}) do
        local itemData = getPlayerItem(src, rawName)
        local amt = itemAmount(itemData)
        if amt and amt > 0 then
            if Player.Functions.RemoveItem(rawName, amt, false) then
                if Player.Functions.AddItem(cleanName, amt, false) then
                    processed = processed + amt
                    local shared = QBCore.Shared.Items[cleanName]
                    if shared then
                        TriggerClientEvent('qb-inventory:client:ItemBox', src, shared, 'add', amt)
                    end
                else
                    Player.Functions.AddItem(rawName, amt, false)
                    TriggerClientEvent('QBCore:Notify', src, 'Inventorius pilnas.', 'error')
                    return processed
                end
            end
        end
    end
    return processed
end

--- Seni lygiuoti kirtikliai → vienas `mining_pickaxe`
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
    if giveItemNotify(src, Player, item, 1) then
        mineCooldown[src] = now
        local shared = QBCore.Shared.Items[item]
        TriggerClientEvent('QBCore:Notify', src, ('Gavai: %s'):format(shared and shared.label or item), 'success')
    else
        TriggerClientEvent('QBCore:Notify', src, 'Inventorius pilnas.', 'error')
    end
end)

RegisterNetEvent('mrp_mining:server:sandAttempt', function(sandIdx)
    local src = source
    sandIdx = tonumber(sandIdx)
    if not sandIdx or not nearSandSite(src, sandIdx) then
        return TriggerClientEvent('QBCore:Notify', src, 'Netinkama smėlio vieta.', 'error')
    end
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local now = os.time()
    if sandCooldown[src] and (now - sandCooldown[src]) < (Config.SandCooldown or 6) then
        return TriggerClientEvent('QBCore:Notify', src, 'Palaukite prieš kasdami smėlį.', 'error')
    end

    local item = rollSandLoot()
    if giveItemNotify(src, Player, item, 1) then
        sandCooldown[src] = now
        local shared = QBCore.Shared.Items[item]
        TriggerClientEvent('QBCore:Notify', src, ('Gavai: %s'):format(shared and shared.label or item), 'success')
    else
        TriggerClientEvent('QBCore:Notify', src, 'Inventorius pilnas.', 'error')
    end
end)

RegisterNetEvent('mrp_mining:server:trashSearch', function(netId)
    local src = source
    netId = tonumber(netId)
    if not netId then
        return TriggerClientEvent('QBCore:Notify', src, 'Konteineris nerastas.', 'error')
    end
    local ent = NetworkGetEntityFromNetworkId(netId)
    if not ent or ent == 0 or not DoesEntityExist(ent) then
        return TriggerClientEvent('QBCore:Notify', src, 'Konteineris nerastas.', 'error')
    end

    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return end
    local p = GetEntityCoords(ped)
    local e = GetEntityCoords(ent)
    if #(p - e) > 4.0 then
        return TriggerClientEvent('QBCore:Notify', src, 'Per toli nuo konteinerio.', 'error')
    end

    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local now = os.time()
    local key = ('%.1f_%.1f_%.1f'):format(e.x, e.y, e.z)
    trashCooldown[src] = trashCooldown[src] or {}
    local last = trashCooldown[src][key]
    if last and (now - last) < (Config.TrashCooldown or 45) then
        return TriggerClientEvent('QBCore:Notify', src, 'Šis konteineris jau išnaršytas. Palauk.', 'error')
    end

    local item = rollTrashLoot()
    if giveItemNotify(src, Player, item, 1) then
        trashCooldown[src][key] = now
        local shared = QBCore.Shared.Items[item]
        TriggerClientEvent('QBCore:Notify', src, ('Radai: %s'):format(shared and shared.label or item), 'success')
    else
        TriggerClientEvent('QBCore:Notify', src, 'Inventorius pilnas.', 'error')
    end
end)

RegisterNetEvent('mrp_mining:server:cleanBatch', function()
    local src = source
    if not nearClean(src) then
        return TriggerClientEvent('QBCore:Notify', src, 'Per toli nuo nuvalymo vietos.', 'error')
    end
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    local map = Config.CleanMap or Config.ProcessMap or {}
    local processed = convertMapBatch(src, Player, map)
    if processed > 0 then
        TriggerClientEvent('QBCore:Notify', src, ('Nuvalyta vienetų: %s'):format(processed), 'success')
    else
        TriggerClientEvent('QBCore:Notify', src, 'Neturi žalių žaliavų nuvalymui.', 'error')
    end
end)

RegisterNetEvent('mrp_mining:server:cleanTrashMaterials', function()
    local src = source
    if not nearClean(src) then
        return TriggerClientEvent('QBCore:Notify', src, 'Per toli nuo nuvalymo vietos.', 'error')
    end
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    local processed = convertMapBatch(src, Player, Config.TrashToMaterial or {})
    if processed > 0 then
        TriggerClientEvent('QBCore:Notify', src, ('Perdirbta į medžiagas: %s'):format(processed), 'success')
    else
        TriggerClientEvent('QBCore:Notify', src, 'Neturi nešvarių butelių / skardinių / gumos.', 'error')
    end
end)

RegisterNetEvent('mrp_mining:server:cleanTrashBottles', function()
    local src = source
    if not nearClean(src) then
        return TriggerClientEvent('QBCore:Notify', src, 'Per toli nuo nuvalymo vietos.', 'error')
    end
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    local processed = convertMapBatch(src, Player, Config.TrashToBottle or {})
    if processed > 0 then
        TriggerClientEvent('QBCore:Notify', src, ('Nuvalyta butelių pakavimui: %s'):format(processed), 'success')
    else
        TriggerClientEvent('QBCore:Notify', src, 'Neturi nešvarių butelių.', 'error')
    end
end)

--- Atgalinis suderinamumas (senas perdirbimas = nuvalymas)
RegisterNetEvent('mrp_mining:server:processBatch', function()
    local src = source
    if not nearClean(src) then
        return TriggerClientEvent('QBCore:Notify', src, 'Per toli nuo nuvalymo vietos.', 'error')
    end
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    local processed = convertMapBatch(src, Player, Config.CleanMap or Config.ProcessMap or {})
    if processed > 0 then
        TriggerClientEvent('QBCore:Notify', src, ('Nuvalyta vienetų: %s'):format(processed), 'success')
    else
        TriggerClientEvent('QBCore:Notify', src, 'Neturi žalių žaliavų nuvalymui.', 'error')
    end
end)

RegisterNetEvent('mrp_mining:server:smelt', function(recipeId)
    local src = source
    if not nearSmelt(src) then
        return TriggerClientEvent('QBCore:Notify', src, 'Per toli nuo krosnies.', 'error')
    end
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    local recipe = findSmeltRecipe(tostring(recipeId or ''))
    if not recipe then
        return TriggerClientEvent('QBCore:Notify', src, 'Nežinomas receptas.', 'error')
    end

    for itemName, need in pairs(recipe.inputs or {}) do
        local have = itemAmount(getPlayerItem(src, itemName))
        if have < (tonumber(need) or 0) then
            local label = (QBCore.Shared.Items[itemName] and QBCore.Shared.Items[itemName].label) or itemName
            return TriggerClientEvent('QBCore:Notify', src, ('Trūksta: %sx %s'):format(need, label), 'error')
        end
    end

    local removed = {}
    for itemName, need in pairs(recipe.inputs or {}) do
        need = tonumber(need) or 0
        if need > 0 then
            if not Player.Functions.RemoveItem(itemName, need, false) then
                for _, r in ipairs(removed) do
                    Player.Functions.AddItem(r.item, r.count, false)
                end
                return TriggerClientEvent('QBCore:Notify', src, 'Nepavyko paimti žaliavų.', 'error')
            end
            removed[#removed + 1] = { item = itemName, count = need }
        end
    end

    local outCount = tonumber(recipe.count) or 1
    if giveItemNotify(src, Player, recipe.output, outCount) then
        TriggerClientEvent('QBCore:Notify', src, ('Išlydyta: %s'):format(recipe.label or recipe.output), 'success')
    else
        for _, r in ipairs(removed) do
            Player.Functions.AddItem(r.item, r.count, false)
        end
        TriggerClientEvent('QBCore:Notify', src, 'Inventorius pilnas.', 'error')
    end
end)

RegisterNetEvent('mrp_mining:server:makeSteel', function()
    local src = source
    if not nearSmelt(src) then
        return TriggerClientEvent('QBCore:Notify', src, 'Plieną lydyk prie krosnies.', 'error')
    end
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    local recipe = findSmeltRecipe('smelt_steel')
    if not recipe then return end

    for itemName, need in pairs(recipe.inputs or {}) do
        local have = itemAmount(getPlayerItem(src, itemName))
        if have < (tonumber(need) or 0) then
            return TriggerClientEvent('QBCore:Notify', src, 'Trūksta žaliavų plienui.', 'error')
        end
    end

    local removed = {}
    for itemName, need in pairs(recipe.inputs or {}) do
        need = tonumber(need) or 0
        if need > 0 then
            if not Player.Functions.RemoveItem(itemName, need, false) then
                for _, r in ipairs(removed) do Player.Functions.AddItem(r.item, r.count, false) end
                return TriggerClientEvent('QBCore:Notify', src, 'Nepavyko paimti žaliavų.', 'error')
            end
            removed[#removed + 1] = { item = itemName, count = need }
        end
    end

    if not giveItemNotify(src, Player, recipe.output, recipe.count or 1) then
        for _, r in ipairs(removed) do Player.Functions.AddItem(r.item, r.count, false) end
        TriggerClientEvent('QBCore:Notify', src, 'Inventorius pilnas.', 'error')
    end
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
    TriggerClientEvent('QBCore:Notify', source, 'Eik į karjerą (žemėlapyje „Karjeras — kasimas“) ir naudok qb-target.', 'primary', 6500)
end)
