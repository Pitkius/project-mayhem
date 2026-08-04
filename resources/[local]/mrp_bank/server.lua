local QBCore = exports['qb-core']:GetCoreObject()

MySQL.ready(function()
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `bank_transactions` (
        `id` INT NOT NULL AUTO_INCREMENT,
        `citizenid` VARCHAR(50) NOT NULL,
        `tx_type` VARCHAR(32) NOT NULL,
        `amount` INT NOT NULL DEFAULT 0,
        `balance_after` INT NOT NULL DEFAULT 0,
        `target_citizenid` VARCHAR(50) DEFAULT NULL,
        `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (`id`),
        KEY `idx_bank_tx_citizenid` (`citizenid`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;]])
end)

local SYNC_REASON = 'mrp-bank-cash-sync'
local CASH_ITEM = 'cash'
local syncingPlayers = {}

QBCore.Functions.CreateUseableItem(CASH_ITEM, function(source)
    TriggerClientEvent('QBCore:Notify', source, 'Pinigai automatiškai sinchronizuojami su inventoriaus kiekiu.', 'primary')
end)

local function getCashItemAmount(player)
    if not player or not player.PlayerData or not player.PlayerData.items then return 0 end
    local total = 0
    for _, item in pairs(player.PlayerData.items) do
        if item and item.name == CASH_ITEM then
            total = total + (tonumber(item.amount) or 0)
        end
    end
    return total
end

local function removeCashItemAmount(src, player, amount)
    local remaining = tonumber(amount) or 0
    if remaining <= 0 then return true end
    for slot, item in pairs(player.PlayerData.items or {}) do
        if remaining <= 0 then break end
        if item and item.name == CASH_ITEM and (tonumber(item.amount) or 0) > 0 then
            local take = math.min(tonumber(item.amount) or 0, remaining)
            local itemSlot = tonumber(item.slot) or tonumber(slot) or false
            if take > 0 and exports['qb-inventory']:RemoveItem(src, CASH_ITEM, take, itemSlot, SYNC_REASON) then
                remaining = remaining - take
            end
        end
    end
    return remaining <= 0
end

--- Senas cash_bundle inventoriuje → cash (1:1), be cash_bundle itemo shared sąraše.
local function migrateLegacyCashItems(src, player)
    if not player or not player.PlayerData then return end
    local items = player.PlayerData.items
    if not items then return end

    local legacyTotal = 0
    local changed = false
    for slot, item in pairs(items) do
        if item and item.name == 'cash_bundle' then
            local amount = tonumber(item.amount) or 0
            if amount > 0 then
                legacyTotal = legacyTotal + amount
            end
            items[slot] = nil
            changed = true
        end
    end
    if not changed or legacyTotal <= 0 then return end

    player.Functions.SetPlayerData('items', items)
    exports['qb-inventory']:AddItem(src, CASH_ITEM, legacyTotal, false, false, 'legacy-cash-migrate')
end

local function syncCashWithInventory(src, player)
    if not player or syncingPlayers[src] then return end
    local cash = math.max(0, math.floor(tonumber(player.PlayerData.money.cash) or 0))
    local itemCash = getCashItemAmount(player)
    if itemCash == cash then return end

    syncingPlayers[src] = true
    if itemCash < cash then
        exports['qb-inventory']:AddItem(src, CASH_ITEM, cash - itemCash, false, false, SYNC_REASON)
    else
        removeCashItemAmount(src, player, itemCash - cash)
    end
    syncingPlayers[src] = nil
end

local function syncMoneyFromInventory(src, player)
    if not player or syncingPlayers[src] then return end
    local itemCash = getCashItemAmount(player)
    if itemCash <= 0 then return end
    local cash = math.max(0, math.floor(tonumber(player.PlayerData.money.cash) or 0))
    if itemCash >= cash then return end

    syncingPlayers[src] = true
    player.Functions.SetMoney('cash', itemCash, SYNC_REASON)
    syncingPlayers[src] = nil
end

AddEventHandler('QBCore:Server:OnMoneyChange', function(source, moneytype, _amount, _action, reason)
    if moneytype ~= 'cash' or reason == SYNC_REASON then return end
    local player = QBCore.Functions.GetPlayer(source)
    if not player then return end
    syncCashWithInventory(source, player)
end)

AddEventHandler('QBCore:Server:PlayerLoaded', function(player)
    if not player then return end
    local src = player.PlayerData.source
    migrateLegacyCashItems(src, player)
    syncCashWithInventory(src, player)
end)

CreateThread(function()
    Wait(3000)
    for src, player in pairs(QBCore.Functions.GetQBPlayers()) do
        syncCashWithInventory(src, player)
    end
end)

CreateThread(function()
    while true do
        for src, player in pairs(QBCore.Functions.GetQBPlayers()) do
            syncMoneyFromInventory(src, player)
        end
        Wait(2500)
    end
end)

local function addHistory(citizenid, txType, amount, balanceAfter, targetCitizenid)
    MySQL.insert.await('INSERT INTO bank_transactions (citizenid, tx_type, amount, balance_after, target_citizenid) VALUES (?, ?, ?, ?, ?)', {
        citizenid,
        txType,
        amount,
        balanceAfter,
        targetCitizenid
    })
end

--- Server-side: player must be at a bank desk or near an ATM prop.
local function isNearBankOrAtm(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end
    local coords = GetEntityCoords(ped)
    local maxDist = tonumber(Config.TerminalMaxDistance) or 2.5

    for _, loc in ipairs(Config.BankLocations or {}) do
        if #(coords - loc) <= maxDist then
            return true
        end
    end

    for _, model in ipairs(Config.ATMModels or {}) do
        local hash = type(model) == 'string' and joaat(model) or model
        local obj = GetClosestObjectOfType(coords.x, coords.y, coords.z, maxDist, hash, false, false, false)
        if obj and obj ~= 0 then
            return true
        end
    end

    return false
end

local function requireNearTerminal(src)
    if isNearBankOrAtm(src) then return true end
    TriggerClientEvent('QBCore:Notify', src, 'Turite būti prie bankomato arba banko.', 'error')
    return false
end

exports('IsNearBankOrAtm', isNearBankOrAtm)

QBCore.Functions.CreateCallback('fivempro:bank:server:getSnapshot', function(source, cb)
    local player = QBCore.Functions.GetPlayer(source)
    if not player then
        cb(nil)
        return
    end
    cb({
        cash = player.PlayerData.money.cash or 0,
        bank = player.PlayerData.money.bank or 0
    })
end)

QBCore.Functions.CreateCallback('fivempro:bank:server:getHistory', function(source, cb)
    local player = QBCore.Functions.GetPlayer(source)
    if not player then
        cb({})
        return
    end
    local rows = MySQL.query.await('SELECT tx_type, amount, balance_after FROM bank_transactions WHERE citizenid = ? ORDER BY id DESC LIMIT 15', { player.PlayerData.citizenid })
    cb(rows or {})
end)

RegisterNetEvent('fivempro:bank:server:deposit', function(amount)
    local src = source
    if not requireNearTerminal(src) then return end
    local player = QBCore.Functions.GetPlayer(src)
    amount = math.floor(math.max(0, tonumber(amount) or 0))
    if not player or amount <= 0 then return end
    if player.PlayerData.money.cash < amount then
        TriggerClientEvent('QBCore:Notify', src, 'Nepakanka cash.', 'error')
        return
    end

    player.Functions.RemoveMoney('cash', amount, 'fivempro-bank-deposit')
    player.Functions.AddMoney('bank', amount, 'fivempro-bank-deposit')
    addHistory(player.PlayerData.citizenid, 'DEPOSIT', amount, player.PlayerData.money.bank, nil)
    TriggerClientEvent('QBCore:Notify', src, ('Inesta $%s i banka.'):format(amount), 'success')
end)

RegisterNetEvent('fivempro:bank:server:withdraw', function(amount)
    local src = source
    if not requireNearTerminal(src) then return end
    local player = QBCore.Functions.GetPlayer(src)
    amount = math.floor(math.max(0, tonumber(amount) or 0))
    if not player or amount <= 0 then return end
    if player.PlayerData.money.bank < amount then
        TriggerClientEvent('QBCore:Notify', src, 'Nepakanka lesu banke.', 'error')
        return
    end

    player.Functions.RemoveMoney('bank', amount, 'fivempro-bank-withdraw')
    player.Functions.AddMoney('cash', amount, 'fivempro-bank-withdraw')
    addHistory(player.PlayerData.citizenid, 'WITHDRAW', amount, player.PlayerData.money.bank, nil)
    TriggerClientEvent('QBCore:Notify', src, ('Issiimta grynais: $%s.'):format(amount), 'success')
end)

RegisterNetEvent('fivempro:bank:server:transfer', function(targetId, amount)
    local src = source
    if not requireNearTerminal(src) then return end
    local player = QBCore.Functions.GetPlayer(src)
    local tid = tonumber(targetId)
    local target = tid and QBCore.Functions.GetPlayer(tid)
    amount = math.floor(math.max(0, tonumber(amount) or 0))

    if not player or not target or amount <= 0 then
        TriggerClientEvent('QBCore:Notify', src, 'Neteisingi pervedimo duomenys.', 'error')
        return
    end
    if player.PlayerData.source == target.PlayerData.source then
        TriggerClientEvent('QBCore:Notify', src, 'Negalima pervesti sau.', 'error')
        return
    end
    if player.PlayerData.money.bank < amount then
        TriggerClientEvent('QBCore:Notify', src, 'Nepakanka lesu banke.', 'error')
        return
    end

    player.Functions.RemoveMoney('bank', amount, 'fivempro-bank-transfer-out')
    target.Functions.AddMoney('bank', amount, 'fivempro-bank-transfer-in')
    addHistory(player.PlayerData.citizenid, 'TRANSFER_OUT', amount, player.PlayerData.money.bank, target.PlayerData.citizenid)
    addHistory(target.PlayerData.citizenid, 'TRANSFER_IN', amount, target.PlayerData.money.bank, player.PlayerData.citizenid)

    TriggerClientEvent('QBCore:Notify', src, ('Pervesta $%s zaidejui %s.'):format(amount, targetId), 'success')
    TriggerClientEvent('QBCore:Notify', target.PlayerData.source, ('Gavai banko pervedima: $%s.'):format(amount), 'success')
end)
