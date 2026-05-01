local QBCore = exports['qb-core']:GetCoreObject()

QBCore.Functions.CreateUseableItem('cash_bundle', function(source, item)
    TriggerClientEvent('QBCore:Notify', source, 'Cash yra automatiskai sinchronizuojamas su inventory. Naudoti nereikia.', 'primary')
end)

local function getCashBundleAmount(player)
    if not player or not player.PlayerData or not player.PlayerData.items then return 0 end
    local total = 0
    for _, item in pairs(player.PlayerData.items) do
        if item and item.name == 'cash_bundle' then
            total = total + (tonumber(item.amount) or 0)
        end
    end
    return total
end

local function removeCashBundleAmount(src, player, amount)
    local remaining = tonumber(amount) or 0
    if remaining <= 0 then return true end
    for slot, item in pairs(player.PlayerData.items or {}) do
        if remaining <= 0 then break end
        if item and item.name == 'cash_bundle' and (tonumber(item.amount) or 0) > 0 then
            local take = math.min(tonumber(item.amount) or 0, remaining)
            local itemSlot = tonumber(item.slot) or tonumber(slot) or false
            if take > 0 and exports['qb-inventory']:RemoveItem(src, 'cash_bundle', take, itemSlot, 'fivempro-bank-sync-cash-bundle') then
                remaining = remaining - take
            end
        end
    end
    return remaining <= 0
end

local function syncCashWithInventory(src, player)
    if not player then return end
    local cash = math.max(0, math.floor(tonumber(player.PlayerData.money.cash) or 0))
    local bundle = getCashBundleAmount(player)
    if bundle == cash then return end

    if bundle < cash then
        local addAmount = cash - bundle
        exports['qb-inventory']:AddItem(src, 'cash_bundle', addAmount, false, false, 'fivempro-bank-sync-cash-add')
    else
        local removeAmount = bundle - cash
        removeCashBundleAmount(src, player, removeAmount)
    end
end

AddEventHandler('QBCore:Server:OnMoneyChange', function(source, moneytype)
    if moneytype ~= 'cash' then return end
    local player = QBCore.Functions.GetPlayer(source)
    if not player then return end
    syncCashWithInventory(source, player)
end)

AddEventHandler('QBCore:Server:PlayerLoaded', function(player)
    if not player then return end
    syncCashWithInventory(player.PlayerData.source, player)
end)

local function syncMoneyFromInventory(src, player)
    if not player then return end
    local bundle = getCashBundleAmount(player)
    local cash = math.max(0, math.floor(tonumber(player.PlayerData.money.cash) or 0))
    if bundle ~= cash then
        player.Functions.SetMoney('cash', bundle, 'fivempro-bank-sync-money-from-inventory')
    end
end

CreateThread(function()
    Wait(3000)
    local players = QBCore.Functions.GetQBPlayers()
    for src, player in pairs(players) do
        syncCashWithInventory(src, player)
    end
end)

-- Keep DB cash aligned with physical cash item (cash_bundle) in inventory.
-- This fixes cases where players drop/split cash items and wallet cash must follow.
CreateThread(function()
    while true do
        local players = QBCore.Functions.GetQBPlayers()
        for src, player in pairs(players) do
            syncMoneyFromInventory(src, player)
        end
        Wait(2500)
    end
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
    player.Functions.AddMoney('cash', amount, 'fivempro-bank-withdraw')
    addHistory(player.PlayerData.citizenid, 'WITHDRAW', amount, player.PlayerData.money.bank, nil)
    TriggerClientEvent('QBCore:Notify', src, ('Issiimta grynais: $%s.'):format(amount), 'success')
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
