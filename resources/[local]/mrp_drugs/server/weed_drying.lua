local QBCore = exports['qb-core']:GetCoreObject()

local tableReady = false
local playerLocks = {}

local function cfg()
    return Config.WeedDrying or {}
end

local function ensureTable()
    if tableReady then return true end
    local ok = pcall(function()
        MySQL.query.await([[CREATE TABLE IF NOT EXISTS `fivempro_drugs_weed_drying` (
            `citizenid` varchar(50) NOT NULL,
            `quantity` int(11) NOT NULL,
            `started_at` bigint(20) NOT NULL,
            `duration_seconds` int(11) NOT NULL,
            PRIMARY KEY (`citizenid`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;]])
    end)
    tableReady = ok
    return ok
end

local function stationCoords()
    local c = cfg().coords or vector4(1144.5762, -1661.0204, 36.6147, 203.0073)
    return vector3(c.x, c.y, c.z)
end

local function playerNearStation(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end
    local distance = tonumber(cfg().interactDistance) or 4.0
    return #(GetEntityCoords(ped) - stationCoords()) <= distance
end

local function durationFor(quantity)
    local c = cfg()
    local secondsPerPlant = math.max(1, tonumber(c.secondsPerPlant) or 10)
    local every = math.max(1, tonumber(c.discountEvery) or 25)
    local percent = math.max(0, tonumber(c.discountPercent) or 2)
    local discount = math.floor(quantity / every) * percent
    local multiplier = math.max(0.10, 1.0 - discount / 100.0)
    return math.max(1, math.floor(quantity * secondsPerPlant * multiplier))
end

local function earlyReturnFor(quantity)
    local enteredQuantity = math.max(0, math.floor(tonumber(quantity) or 0))
    local refundPercent = math.min(100, math.max(0, tonumber(cfg().earlyReturnPercent) or 80))
    return math.floor(enteredQuantity * refundPercent / 100), refundPercent
end

local function sessionPayload(row)
    if not row then return nil end
    local startedAt = tonumber(row.started_at) or os.time()
    local durationSeconds = tonumber(row.duration_seconds) or 1
    local finishesAt = startedAt + durationSeconds
    return {
        quantity = tonumber(row.quantity) or 0,
        startedAt = startedAt,
        durationSeconds = durationSeconds,
        finishesAt = finishesAt,
        remainingSeconds = math.max(0, finishesAt - os.time()),
        ready = os.time() >= finishesAt,
    }
end

local function getSession(citizenid)
    if not ensureTable() then return nil end
    local row = MySQL.single.await(
        'SELECT citizenid, quantity, started_at, duration_seconds FROM fivempro_drugs_weed_drying WHERE citizenid = ?',
        { citizenid }
    )
    return sessionPayload(row)
end

local function notifyItem(src, itemName, action, amount)
    local shared = QBCore.Shared.Items[itemName]
    if shared then
        TriggerClientEvent('qb-inventory:client:ItemBox', src, shared, action, amount)
    end
end

local function countItemAmount(Player, itemName)
    local total = 0
    for _, item in pairs(Player.PlayerData.items or {}) do
        if item and item.name == itemName then
            total = total + (tonumber(item.amount) or 0)
        end
    end
    return total
end

local function removeItemAmount(Player, itemName, amount)
    local remaining = amount
    local removed = 0
    local stacks = {}
    for slot, item in pairs(Player.PlayerData.items or {}) do
        if item and item.name == itemName and (tonumber(item.amount) or 0) > 0 then
            stacks[#stacks + 1] = {
                slot = tonumber(item.slot) or tonumber(slot),
                amount = math.floor(tonumber(item.amount) or 0),
            }
        end
    end
    table.sort(stacks, function(a, b) return (a.slot or 0) < (b.slot or 0) end)
    for _, stack in ipairs(stacks) do
        if remaining <= 0 then break end
        local take = math.min(remaining, stack.amount)
        if Player.Functions.RemoveItem(itemName, take, stack.slot) then
            remaining = remaining - take
            removed = removed + take
        else
            break
        end
    end
    if remaining > 0 then
        if removed > 0 then Player.Functions.AddItem(itemName, removed) end
        return false
    end
    return true
end

QBCore.Functions.CreateCallback('mrp_drugs:server:getWeedDryingSession', function(src, cb)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return cb({ ok = false }) end
    cb({ ok = true, session = getSession(Player.PlayerData.citizenid) })
end)

QBCore.Functions.CreateCallback('mrp_drugs:server:startWeedDrying', function(src, cb, amount)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return cb({ ok = false, reason = 'Žaidėjas nerastas.' }) end
    if not playerNearStation(src) then
        return cb({ ok = false, reason = 'Per toli nuo džiovinimo vietos.' })
    end
    if not ensureTable() then
        return cb({ ok = false, reason = 'Džiovinimo duomenų bazė nepasiekiama.' })
    end

    amount = math.floor(tonumber(amount) or 0)
    local minimum = math.max(1, tonumber(cfg().minimumAmount) or 10)
    local maximum = math.max(minimum, tonumber(cfg().maximumAmount) or 500)
    if amount < minimum or amount > maximum then
        return cb({ ok = false, reason = ('Pasirink kiekį nuo %d iki %d.'):format(minimum, maximum) })
    end

    local citizenid = Player.PlayerData.citizenid
    if playerLocks[citizenid] then
        return cb({ ok = false, reason = 'Palaukite, džiovinimo duomenys atnaujinami.' })
    end
    playerLocks[citizenid] = true

    local function finish(response)
        playerLocks[citizenid] = nil
        cb(response)
    end

    if getSession(citizenid) then
        return finish({ ok = false, reason = 'Jau turite džiūstančią žolės partiją.' })
    end

    local inputItem = cfg().inputItem or 'weed_leaf'
    if countItemAmount(Player, inputItem) < amount then
        return finish({ ok = false, reason = ('Trūksta žolės lapų. Reikia %d.'):format(amount) })
    end
    if not removeItemAmount(Player, inputItem, amount) then
        return finish({ ok = false, reason = 'Nepavyko paimti žolės lapų.' })
    end

    local startedAt = os.time()
    local durationSeconds = durationFor(amount)
    local insertOk, inserted = pcall(function()
        return MySQL.insert.await(
            'INSERT INTO fivempro_drugs_weed_drying (citizenid, quantity, started_at, duration_seconds) VALUES (?, ?, ?, ?)',
            { citizenid, amount, startedAt, durationSeconds }
        )
    end)
    if not insertOk or not inserted then
        Player.Functions.AddItem(inputItem, amount)
        return finish({ ok = false, reason = 'Nepavyko išsaugoti džiovinimo. Lapai grąžinti.' })
    end

    notifyItem(src, inputItem, 'remove', amount)
    local session = sessionPayload({
        quantity = amount,
        started_at = startedAt,
        duration_seconds = durationSeconds,
    })
    TriggerClientEvent('mrp_drugs:client:setWeedDryingSession', src, session)
    finish({ ok = true, session = session })
end)

QBCore.Functions.CreateCallback('mrp_drugs:server:collectWeedDrying', function(src, cb)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return cb({ ok = false, reason = 'Žaidėjas nerastas.' }) end
    if not playerNearStation(src) then
        return cb({ ok = false, reason = 'Per toli nuo džiovinimo vietos.' })
    end

    local citizenid = Player.PlayerData.citizenid
    if playerLocks[citizenid] then
        return cb({ ok = false, reason = 'Palaukite, džiovinimo duomenys atnaujinami.' })
    end
    playerLocks[citizenid] = true

    local function finish(response)
        playerLocks[citizenid] = nil
        cb(response)
    end

    local session = getSession(citizenid)
    if not session then
        return finish({ ok = false, reason = 'Aktyvi džiovinimo partija nerasta.' })
    end

    local ready = session.ready == true
    local itemName
    local amount
    local refundPercent
    if ready then
        itemName = cfg().outputItem or 'weed_buds'
        amount = session.quantity
    else
        itemName = cfg().inputItem or 'weed_leaf'
        amount, refundPercent = earlyReturnFor(session.quantity)
    end

    if amount > 0 and GetResourceState('qb-inventory') == 'started' then
        local canAdd = exports['qb-inventory']:CanAddItem(src, itemName, amount)
        if not canAdd then
            return finish({ ok = false, reason = 'Inventoriuje nepakanka vietos.' })
        end
    end
    local deleted = MySQL.update.await(
        'DELETE FROM fivempro_drugs_weed_drying WHERE citizenid = ?',
        { citizenid }
    )
    if not deleted or deleted < 1 then
        return finish({ ok = false, reason = 'Nepavyko užbaigti džiovinimo sesijos.' })
    end

    if amount > 0 and not Player.Functions.AddItem(itemName, amount, false, {}) then
        local restored = MySQL.insert.await(
            'INSERT INTO fivempro_drugs_weed_drying (citizenid, quantity, started_at, duration_seconds) VALUES (?, ?, ?, ?)',
            { citizenid, session.quantity, session.startedAt, session.durationSeconds }
        )
        return finish({
            ok = false,
            reason = restored
                and 'Inventoriuje nepakanka vietos. Džiovinimo partija palikta.'
                or 'Kritinė inventoriaus klaida. Kreipkitės į administraciją.',
        })
    end

    if amount > 0 then notifyItem(src, itemName, 'add', amount) end
    TriggerClientEvent('mrp_drugs:client:setWeedDryingSession', src, nil)
    finish({
        ok = true,
        ready = ready,
        item = itemName,
        amount = amount,
        reason = ready
            and ('Pasiėmėte išdžiovintą žolę x%d.'):format(amount)
            or ('Džiovinimas nutrauktas. Grąžinta %d%% nuo įrašyto x%d kiekio: x%d.'):format(
                refundPercent,
                session.quantity,
                amount
            ),
    })
end)

CreateThread(function()
    ensureTable()
end)
