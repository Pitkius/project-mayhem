local QBCore = exports['qb-core']:GetCoreObject()

QBCore.Functions.CreateUseableItem('cash_bundle', function(source, item)
    local player = QBCore.Functions.GetPlayer(source)
    if not player then return end

    local amount = tonumber(item and item.amount) or 0
    if amount <= 0 then
        TriggerClientEvent('QBCore:Notify', source, 'Netinkamas pinigu paketas.', 'error')
        return
    end

    local removed = exports['qb-inventory']:RemoveItem(source, 'cash_bundle', amount, item.slot, 'fivempro-bank-open-cash-bundle')
    if not removed then return end

    player.Functions.AddMoney('cash', amount, 'fivempro-bank-open-cash-bundle')
    TriggerClientEvent('qb-inventory:client:ItemBox', source, QBCore.Shared.Items.cash_bundle, 'remove')
    TriggerClientEvent('QBCore:Notify', source, ('Issikeitei grynus: $%s'):format(amount), 'success')
end)

local function addHistory(citizenid, txType, amount, balanceAfter, targetCitizenid)
    MySQL.insert('INSERT INTO bank_transactions (citizenid, tx_type, amount, balance_after, target_citizenid) VALUES (?, ?, ?, ?, ?)', {
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
    amount = tonumber(amount) or 0
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
    amount = tonumber(amount) or 0
    if not player or amount <= 0 then return end
    if player.PlayerData.money.bank < amount then
        TriggerClientEvent('QBCore:Notify', src, 'Nepakanka lesu banke.', 'error')
        return
    end

    player.Functions.RemoveMoney('bank', amount, 'fivempro-bank-withdraw')
    local added = exports['qb-inventory']:AddItem(src, 'cash_bundle', amount, false, false, 'fivempro-bank-withdraw')
    if not added then
        -- Fail-safe rollback if inventory is full.
        player.Functions.AddMoney('bank', amount, 'fivempro-bank-withdraw-rollback')
        TriggerClientEvent('QBCore:Notify', src, 'Inventory pilnas, pinigu paketo ideti nepavyko.', 'error')
        return
    end
    TriggerClientEvent('qb-inventory:client:ItemBox', src, QBCore.Shared.Items.cash_bundle, 'add')
    addHistory(player.PlayerData.citizenid, 'WITHDRAW', amount, player.PlayerData.money.bank, nil)
    TriggerClientEvent('QBCore:Notify', src, ('Issiimtas pinigu paketas uz $%s.'):format(amount), 'success')
end)

RegisterNetEvent('fivempro:bank:server:transfer', function(targetId, amount)
    local src = source
    local player = QBCore.Functions.GetPlayer(src)
    local target = QBCore.Functions.GetPlayer(tonumber(targetId))
    amount = tonumber(amount) or 0

    if not player or not target or amount <= 0 then
        TriggerClientEvent('QBCore:Notify', src, 'Neteisingi pervedimo duomenys.', 'error')
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
