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

--- Seniems žaidėjams: cash_bundle inventoriuje → paprasti cash pinigai.
local function migrateCashBundleItems(src, player)
    if not player or not player.PlayerData then return end
    local total = 0
    local toRemove = {}
    for slot, item in pairs(player.PlayerData.items or {}) do
        if item and item.name == 'cash_bundle' and (tonumber(item.amount) or 0) > 0 then
            total = total + (tonumber(item.amount) or 0)
            toRemove[#toRemove + 1] = {
                slot = tonumber(item.slot) or tonumber(slot),
                amount = tonumber(item.amount) or 0,
            }
        end
    end
    if total <= 0 then return end
    for _, entry in ipairs(toRemove) do
        exports['qb-inventory']:RemoveItem(src, 'cash_bundle', entry.amount, entry.slot, 'cash-bundle-migrated-to-wallet')
    end
    local walletCash = math.max(0, math.floor(tonumber(player.PlayerData.money.cash) or 0))
    if walletCash < total then
        player.Functions.AddMoney('cash', total - walletCash, 'cash-bundle-migrated-to-wallet')
    end
end

AddEventHandler('QBCore:Server:PlayerLoaded', function(player)
    if player then migrateCashBundleItems(player.PlayerData.source, player) end
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
