local QBCore = exports['qb-core']:GetCoreObject()

local playerCooldownUntil = {}
local houseCooldownUntil = {}
local activeSessions = {}

local function getHouseById(houseId)
    for _, h in ipairs((Config.Burglary and Config.Burglary.houses) or {}) do
        if h.id == houseId then return h end
    end
end

local function weightedPick(tableDef)
    local total = 0
    for _, row in ipairs(tableDef or {}) do
        total = total + (tonumber(row.weight) or 0)
    end
    if total <= 0 then return nil end
    local roll = math.random(1, total)
    local acc = 0
    for _, row in ipairs(tableDef) do
        acc = acc + (tonumber(row.weight) or 0)
        if roll <= acc then return row end
    end
end

local function weightedLootPick()
    local row = weightedPick((Config.Burglary and Config.Burglary.lootTable) or {})
    if not row then return nil end
    local count = math.random(tonumber(row.min) or 1, tonumber(row.max) or 1)
    local payload = { item = row.item, count = count }
    if row.item == 'markedbills' then
        payload.worth = math.random(tonumber(row.worthMin) or 200, tonumber(row.worthMax) or 900)
    end
    return payload
end

local function grantLoot(src, Player, tierId)
    local tier = (Config.Burglary and Config.Burglary.tiers and Config.Burglary.tiers[tierId]) or {}
    local rolls = tonumber(tier.lootRolls) or 2
    local granted = {}

    local cashMin = tonumber(tier.cashMin) or 100
    local cashMax = tonumber(tier.cashMax) or 400
    local cash = math.random(cashMin, cashMax)
    Player.Functions.AddMoney('cash', cash, 'burglary-cash')
    granted[#granted + 1] = { type = 'cash', amount = cash }

    for _ = 1, rolls do
        local pick = weightedLootPick()
        if pick then
            if pick.item == 'markedbills' and pick.worth then
                local dollars = math.floor(tonumber(pick.worth) or 0)
                if dollars > 0 then
                    local ok = Player.Functions.AddItem('markedbills', dollars, false, {})
                    if ok then
                        granted[#granted + 1] = { type = 'item', item = 'markedbills', count = dollars, worth = dollars }
                    end
                end
            else
                local ok = Player.Functions.AddItem(pick.item, pick.count)
                if ok then
                    granted[#granted + 1] = { type = 'item', item = pick.item, count = pick.count }
                end
            end
        end
    end

    return granted
end

local function rollLayout(house)
    local tier = (Config.Burglary.tiers or {})[house.tier] or {}
    local props = Config.Burglary.props or {}
    local tvChance = tonumber(tier.tvChance) or tonumber(props.tv and props.tv.chance) or 0.4
    local safeChance = tonumber(tier.safeChance) or tonumber(props.safe and props.safe.chance) or 0.25
    return {
        hasTv = house.interior and house.interior.tv ~= nil and math.random() < tvChance,
        hasSafe = house.interior and house.interior.safe ~= nil and math.random() < safeChance,
    }
end

QBCore.Functions.CreateCallback('mrp_burglary:server:canStart', function(source, cb, houseId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return cb({ ok = false, message = 'Klaida' }) end

    local house = getHouseById(houseId)
    if not house then return cb({ ok = false, message = 'Nežinomas namas' }) end

    local now = os.time()
    if (playerCooldownUntil[src] or 0) > now then
        return cb({ ok = false, message = ('Palauk %ds'):format(playerCooldownUntil[src] - now) })
    end
    if (houseCooldownUntil[houseId] or 0) > now then
        return cb({ ok = false, message = 'Šis namas jau apiplėštas neseniai' })
    end

    if Config.Burglary.requireLockpick then
        local hasBasic = Player.Functions.GetItemByName(Config.Burglary.lockpickItem)
        local hasAdv = Player.Functions.GetItemByName(Config.Burglary.advancedLockpickItem)
        if (not hasBasic or (hasBasic.amount or 0) <= 0) and (not hasAdv or (hasAdv.amount or 0) <= 0) then
            return cb({ ok = false, message = 'Reikia visrakčio' })
        end
    end

    cb({ ok = true, tier = house.tier, label = house.label })
end)

RegisterNetEvent('mrp_burglary:server:beginSession', function(houseId, usedAdvanced)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local house = getHouseById(houseId)
    if not house then return end

    local now = os.time()
    if (playerCooldownUntil[src] or 0) > now or (houseCooldownUntil[houseId] or 0) > now then return end

    if Config.Burglary.requireLockpick then
        local item = usedAdvanced and Config.Burglary.advancedLockpickItem or Config.Burglary.lockpickItem
        if not Player.Functions.RemoveItem(item, 1) then
            return TriggerClientEvent('QBCore:Notify', src, 'Neturi visrakčio', 'error')
        end
    end

    local bucket = (Config.Burglary.routingBucketBase or 18000) + src
    SetPlayerRoutingBucket(src, bucket)

    local layout = rollLayout(house)
    activeSessions[src] = {
        houseId = houseId,
        tier = house.tier,
        bucket = bucket,
        searched = {},
        startedAt = now,
        alarmSent = false,
        layout = layout,
        tvTaken = false,
        safeOpened = false,
    }

    TriggerClientEvent('mrp_burglary:client:enterInterior', src, house, layout)
end)

RegisterNetEvent('mrp_burglary:server:searchDrawer', function(houseId, drawerIdx)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local session = activeSessions[src]
    if not Player or not session or session.houseId ~= houseId then return end

    drawerIdx = tonumber(drawerIdx)
    if not drawerIdx or session.searched[drawerIdx] then
        return TriggerClientEvent('QBCore:Notify', src, 'Jau apieškota', 'error')
    end

    session.searched[drawerIdx] = true
    local granted = grantLoot(src, Player, session.tier)
    TriggerClientEvent('mrp_burglary:client:drawerLooted', src, granted)
end)

RegisterNetEvent('mrp_burglary:server:takeTv', function(houseId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local session = activeSessions[src]
    if not Player or not session or session.houseId ~= houseId then return end
    if not session.layout or not session.layout.hasTv then return end
    if session.tvTaken then
        return TriggerClientEvent('QBCore:Notify', src, 'TV jau paimtas', 'error')
    end

    local itemName = ((Config.Burglary.props or {}).tv or {}).item or 'stolen_tv'
    if not Player.Functions.AddItem(itemName, 1) then
        return TriggerClientEvent('QBCore:Notify', src, 'Inventorius pilnas', 'error')
    end
    session.tvTaken = true
    TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[itemName], 'add', 1)
    TriggerClientEvent('mrp_burglary:client:tvTaken', src)
end)

RegisterNetEvent('mrp_burglary:server:drillSafe', function(houseId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local session = activeSessions[src]
    if not Player or not session or session.houseId ~= houseId then return end
    if not session.layout or not session.layout.hasSafe then return end
    if session.safeOpened then
        return TriggerClientEvent('QBCore:Notify', src, 'Seifas jau atidarytas', 'error')
    end

    local drill = Config.Burglary.drillItem or 'drill'
    if not Player.Functions.RemoveItem(drill, 1) then
        return TriggerClientEvent('QBCore:Notify', src, 'Reikia grąžto', 'error')
    end

    session.safeOpened = true
    local safeCfg = (Config.Burglary.props or {}).safe or {}
    if math.random() < (tonumber(safeCfg.emptyChance) or 0.4) then
        return TriggerClientEvent('mrp_burglary:client:safeEmpty', src)
    end

    local row = weightedPick(safeCfg.loot or {})
    local granted = {}
    if not row then
        return TriggerClientEvent('mrp_burglary:client:safeEmpty', src)
    end

    if row.item == 'cash' then
        local amount = math.random(tonumber(row.min) or 200, tonumber(row.max) or 1000)
        Player.Functions.AddMoney('cash', amount, 'burglary-safe')
        granted[#granted + 1] = { type = 'cash', amount = amount }
    elseif row.item == 'markedbills' then
        local worth = math.random(tonumber(row.worthMin) or 400, tonumber(row.worthMax) or 1500)
        Player.Functions.AddItem('markedbills', worth, false, {})
        granted[#granted + 1] = { type = 'item', item = 'markedbills', count = worth, worth = worth }
    else
        local count = math.random(tonumber(row.min) or 1, tonumber(row.max) or 1)
        Player.Functions.AddItem(row.item, count)
        granted[#granted + 1] = { type = 'item', item = row.item, count = count }
    end

    TriggerClientEvent('mrp_burglary:client:safeOpened', src, granted)
end)

RegisterNetEvent('mrp_burglary:server:sellStolen', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    local fence = Config.Burglary.fence or {}
    local prices = fence.prices or {}
    local total = 0
    local sold = 0

    for itemName, priceCfg in pairs(prices) do
        local item = Player.Functions.GetItemByName(itemName)
        while item and (item.amount or 0) > 0 do
            if not Player.Functions.RemoveItem(itemName, 1) then break end
            local pay = math.random(tonumber(priceCfg.min) or 100, tonumber(priceCfg.max) or 300)
            total = total + pay
            sold = sold + 1
            item = Player.Functions.GetItemByName(itemName)
        end
    end

    if sold <= 0 then
        return TriggerClientEvent('QBCore:Notify', src, 'Neturi ko parduoti.', 'error')
    end
    Player.Functions.AddMoney('cash', total, 'burglary-fence')
    TriggerClientEvent('QBCore:Notify', src, ('Parduota %d vnt. už $%s'):format(sold, total), 'success')
end)

RegisterNetEvent('mrp_burglary:server:triggerAlarm', function(houseId, reason)
    local src = source
    local session = activeSessions[src]
    --- Leisti PD ir be sesijos (pvz. fail lockpick prie durų) — bet be spam
    if session then
        if session.houseId ~= houseId then return end
        if session.alarmSent and reason ~= 'seifo gręžimas' then return end
        session.alarmSent = true
    end

    local house = getHouseById(houseId)
    local coords = house and house.door or nil
    if GetResourceState('mrp_dispatch') == 'started' and coords then
        TriggerEvent('mrp_dispatch:server:burglaryAlert', src,
            ('Galimas namų plėšimas (%s)'):format(reason or 'įtartinas triukšmas'),
            { x = coords.x, y = coords.y, z = coords.z })
    end
end)

RegisterNetEvent('mrp_burglary:server:exitSession', function(houseId)
    local src = source
    local session = activeSessions[src]
    if not session or session.houseId ~= houseId then return end

    SetPlayerRoutingBucket(src, 0)
    activeSessions[src] = nil

    local now = os.time()
    playerCooldownUntil[src] = now + (tonumber(Config.Burglary.globalCooldownSeconds) or 900)
    houseCooldownUntil[houseId] = now + (tonumber(Config.Burglary.houseCooldownSeconds) or 3600)
end)

AddEventHandler('playerDropped', function()
    local src = source
    if activeSessions[src] then
        SetPlayerRoutingBucket(src, 0)
        activeSessions[src] = nil
    end
    playerCooldownUntil[src] = nil
end)
