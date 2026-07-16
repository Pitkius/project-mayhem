local QBCore = exports['qb-core']:GetCoreObject()

local playerCooldownUntil = {}
local houseCooldownUntil = {}
local activeSessions = {}

local function getHouseById(houseId)
    for _, h in ipairs((Config.Burglary and Config.Burglary.houses) or {}) do
        if h.id == houseId then return h end
    end
end

local function weightedLootPick()
    local tableDef = (Config.Burglary and Config.Burglary.lootTable) or {}
    local total = 0
    for _, row in ipairs(tableDef) do
        total = total + (tonumber(row.weight) or 0)
    end
    if total <= 0 then return nil end

    local roll = math.random(1, total)
    local acc = 0
    for _, row in ipairs(tableDef) do
        acc = acc + (tonumber(row.weight) or 0)
        if roll <= acc then
            local count = math.random(tonumber(row.min) or 1, tonumber(row.max) or 1)
            local payload = { item = row.item, count = count }
            if row.item == 'markedbills' then
                payload.worth = math.random(tonumber(row.worthMin) or 200, tonumber(row.worthMax) or 900)
            end
            return payload
        end
    end
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
                        granted[#granted + 1] = { type = 'item', item = 'markedbills', count = dollars }
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

    activeSessions[src] = {
        houseId = houseId,
        tier = house.tier,
        bucket = bucket,
        searched = {},
        startedAt = now,
        alarmSent = false,
    }

    TriggerClientEvent('mrp_burglary:client:enterInterior', src, house)
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

RegisterNetEvent('mrp_burglary:server:triggerAlarm', function(houseId, reason)
    local src = source
    local session = activeSessions[src]
    if not session or session.houseId ~= houseId or session.alarmSent then return end
    session.alarmSent = true

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
