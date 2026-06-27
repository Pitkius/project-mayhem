local QBCore = exports['qb-core']:GetCoreObject()

Bank = Bank or {}

local transferCooldown = {}

local function cfg()
    return Config.Bank or {}
end

local function trim(s)
    return tostring(s or ''):gsub('^%s+', ''):gsub('%s+$', '')
end

local function clampStr(s, maxLen)
    s = trim(s)
    if #s > maxLen then s = s:sub(1, maxLen) end
    return s
end

local function normalizeAccountQuery(q)
    q = trim(q):upper()
    q = q:gsub('%s+', '')
    return q
end

local function citizenFromSrc(src)
    local P = QBCore.Functions.GetPlayer(src)
    if not P then return nil, nil end
    return P.PlayerData.citizenid, P
end

local function playerNameFromCharinfo(charinfo)
    if type(charinfo) ~= 'table' then return 'Žaidėjas' end
    local first = trim(charinfo.firstname or '')
    local last = trim(charinfo.lastname or '')
    local full = trim((first .. ' ' .. last))
    return full ~= '' and full or 'Žaidėjas'
end

local function accountDigits(citizenid)
    local sum = 0
    for i = 1, #citizenid do
        sum = sum + string.byte(citizenid, i)
    end
    local a = 1000 + (sum % 9000)
    local b = 1000 + ((sum * 13 + #citizenid * 7) % 9000)
    return a, b
end

function Bank.EnsureAccount(citizenid)
    citizenid = tostring(citizenid or '')
    if citizenid == '' then return nil end
    local row = MySQL.single.await([[
        SELECT citizenid, account_number, card_last4
        FROM fivempro_phone_bank_accounts WHERE citizenid = ? LIMIT 1
    ]], { citizenid })
    if row then return row end
    local a, b = accountDigits(citizenid)
    local accountNumber = ('LT-%04d-%04d'):format(a, b)
    local cardLast4 = ('%04d'):format((a + b) % 10000)
    MySQL.insert.await([[
        INSERT INTO fivempro_phone_bank_accounts (citizenid, account_number, card_last4)
        VALUES (?, ?, ?)
    ]], { citizenid, accountNumber, cardLast4 })
    return {
        citizenid = citizenid,
        account_number = accountNumber,
        card_last4 = cardLast4,
    }
end

local function logAdmin(action, src, citizenid, details)
    local name = '—'
    local P = QBCore.Functions.GetPlayer(src)
    if P and P.PlayerData and P.PlayerData.charinfo then
        name = playerNameFromCharinfo(P.PlayerData.charinfo)
    end
    print(('[mrp_phone:bank] %s | src=%s cid=%s name=%s | %s'):format(
        action, tostring(src), tostring(citizenid), name, tostring(details or '')
    ))
end

local function normalizeTransactions(rows)
    if type(rows) ~= 'table' then return {} end
    for i = 1, #rows do
        local row = rows[i]
        if row.created_at ~= nil then
            row.created_at = tostring(row.created_at)
        end
        if row.status == nil or row.status == '' then
            row.status = 'completed'
        end
    end
    return rows
end

local function classifyMoneyChange(moneyType, action, amount, reason)
    reason = tostring(reason or '')
    local lower = reason:lower()
    local delta = math.floor(tonumber(amount) or 0)
    if action == 'remove' then
        delta = -math.abs(delta)
    elseif action == 'add' then
        delta = math.abs(delta)
    else
        return nil
    end
    if delta == 0 then return nil end

    local txType = 'other'
    local title = reason ~= '' and reason or 'Operacija'

    if lower:find('paycheck', 1, true) or lower:find('alga', 1, true) or lower:find('salary', 1, true) then
        txType = 'salary'
        title = 'Alga'
    elseif lower:find('fine', 1, true) or lower:find('bauda', 1, true) then
        txType = 'fine'
        title = 'Bauda'
    elseif lower:find('deposit', 1, true) or lower:find('įneš', 1, true) or lower:find('ines', 1, true) then
        txType = 'deposit'
        title = 'Įnešimas į banką'
    elseif lower:find('transfer', 1, true) or lower:find('perved', 1, true) then
        if delta > 0 then
            txType = 'transfer_in'
            title = 'Gautas pervedimas'
        else
            txType = 'transfer_out'
            title = 'Pervedimas'
        end
    elseif moneyType == 'bank' and delta < 0 then
        txType = 'payment'
        title = title ~= '' and title or 'Mokėjimas'
    elseif moneyType == 'bank' and delta > 0 then
        txType = 'transfer_in'
        title = title ~= '' and title or 'Įskaitymas'
    end

    return txType, delta, title
end

local function shouldSkipMoneyLog(reason)
    reason = tostring(reason or '')
    if reason == '' then return false end
    if reason:find('^phone%-bank', 1, false) then return true end
    return false
end

function Bank.LogTransaction(citizenid, txType, amount, title, opts)
    opts = opts or {}
    citizenid = tostring(citizenid or '')
    if citizenid == '' then return end
    MySQL.insert.await([[
        INSERT INTO fivempro_phone_bank_transactions
        (citizenid, tx_type, amount, title, counterparty, counterparty_citizenid, purpose, status)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    ]], {
        citizenid,
        tostring(txType or 'other'),
        math.floor(tonumber(amount) or 0),
        clampStr(title or 'Operacija', 80),
        clampStr(opts.counterparty or '', 64),
        opts.counterpartyCitizenid and tostring(opts.counterpartyCitizenid) or nil,
        clampStr(opts.purpose or '', 120),
        clampStr(opts.status or 'completed', 16),
    })
end

local function getBalances(P)
    if not P or not P.PlayerData or not P.PlayerData.money then
        return 0, 0
    end
    return tonumber(P.PlayerData.money.cash) or 0, tonumber(P.PlayerData.money.bank) or 0
end

local function resolveRecipient(query)
    query = trim(query)
    if query == '' then return nil, 'Įveskite gavėjo ID arba sąskaitą.' end

    local norm = normalizeAccountQuery(query)
    if norm:find('^LT%-') then
        local row = MySQL.single.await([[
            SELECT ba.citizenid, ba.account_number, p.charinfo
            FROM fivempro_phone_bank_accounts ba
            LEFT JOIN players p ON p.citizenid = ba.citizenid
            WHERE ba.account_number = ?
            LIMIT 1
        ]], { norm })
        if row then
            local charinfo = row.charinfo and json.decode(row.charinfo) or {}
            return {
                citizenid = row.citizenid,
                accountNumber = row.account_number,
                name = playerNameFromCharinfo(charinfo),
            }
        end
    end

    local cid = query:upper()
    local online = QBCore.Functions.GetPlayerByCitizenId(cid)
    if online then
        return {
            citizenid = cid,
            accountNumber = Bank.EnsureAccount(cid).account_number,
            name = playerNameFromCharinfo(online.PlayerData.charinfo),
            online = true,
            source = online.PlayerData.source,
        }
    end

    local row = MySQL.single.await('SELECT citizenid, charinfo FROM players WHERE citizenid = ? LIMIT 1', { cid })
    if row then
        local charinfo = row.charinfo and json.decode(row.charinfo) or {}
        Bank.EnsureAccount(row.citizenid)
        local acc = MySQL.single.await('SELECT account_number FROM fivempro_phone_bank_accounts WHERE citizenid = ? LIMIT 1', { row.citizenid })
        return {
            citizenid = row.citizenid,
            accountNumber = acc and acc.account_number or '',
            name = playerNameFromCharinfo(charinfo),
            online = false,
        }
    end

    return nil, 'Gavėjas nerastas.'
end

local function addMoneyToCitizen(citizenid, moneyType, amount, reason)
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then return false end
    local online = QBCore.Functions.GetPlayerByCitizenId(citizenid)
    if online then
        online.Functions.AddMoney(moneyType, amount, reason or 'phone-bank')
        return true
    end
    local row = MySQL.single.await('SELECT money FROM players WHERE citizenid = ? LIMIT 1', { citizenid })
    if not row or not row.money then return false end
    local money = json.decode(row.money) or {}
    money[moneyType] = (tonumber(money[moneyType]) or 0) + amount
    MySQL.update.await('UPDATE players SET money = ? WHERE citizenid = ?', { json.encode(money), citizenid })
    return true
end

local function removeMoneyFromPlayer(P, moneyType, amount, reason)
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then return false, 'Netinkama suma.' end
    if not P.Functions.RemoveMoney(moneyType, amount, reason or 'phone-bank') then
        return false, 'Nepakanka lėšų.'
    end
    return true
end

function Bank.GetState(src)
    local citizenid, P = citizenFromSrc(src)
    if not citizenid then return { ok = false, message = 'Žaidėjas nerastas.' } end

    local acc = Bank.EnsureAccount(citizenid)
    local cash, bank = getBalances(P)
    local fullname = playerNameFromCharinfo(P.PlayerData.charinfo)

    local limit = (cfg().recentTransactionLimit) or 8
    local txs = MySQL.query.await([[
        SELECT id, tx_type, amount, title, counterparty, purpose, status, created_at
        FROM fivempro_phone_bank_transactions
        WHERE citizenid = ?
        ORDER BY id DESC
        LIMIT ?
    ]], { citizenid, limit }) or {}

    return {
        ok = true,
        bankName = cfg().name or 'BANKAS',
        holderName = fullname,
        citizenid = citizenid,
        accountNumber = acc.account_number,
        cardLast4 = acc.card_last4,
        cash = cash,
        bank = bank,
        transactions = normalizeTransactions(txs),
    }
end

function Bank.LookupRecipient(src, query)
    local citizenid = citizenFromSrc(src)
    if not citizenid then return { ok = false, message = 'Žaidėjas nerastas.' } end
    local recipient, err = resolveRecipient(query)
    if not recipient then return { ok = false, message = err or 'Gavėjas nerastas.' } end
    if recipient.citizenid == citizenid then
        return { ok = false, message = 'Negalima pervesti sau.' }
    end
    return {
        ok = true,
        recipient = {
            citizenid = recipient.citizenid,
            name = recipient.name,
            accountNumber = recipient.accountNumber,
        },
    }
end

function Bank.Transfer(src, data)
    local citizenid, P = citizenFromSrc(src)
    if not citizenid then return { ok = false, message = 'Žaidėjas nerastas.' } end

    local bcfg = cfg()
    local now = os.time()
    local last = transferCooldown[src] or 0
    if now - last < (bcfg.transferCooldownSec or 5) then
        return { ok = false, message = 'Palauk prieš kitą pervedimą.' }
    end

    local amount = math.floor(tonumber(data and data.amount) or 0)
    local minA = bcfg.minTransferAmount or 1
    local maxA = bcfg.maxTransferAmount or 500000
    if amount < minA then return { ok = false, message = ('Minimali suma: %s €'):format(minA) } end
    if amount > maxA then return { ok = false, message = ('Maksimali suma: %s €'):format(maxA) } end

    local recipient, err = resolveRecipient(data and data.recipient or data and data.query or '')
    if not recipient then return { ok = false, message = err or 'Gavėjas nerastas.' } end
    if recipient.citizenid == citizenid then return { ok = false, message = 'Negalima pervesti sau.' } end

    local purpose = clampStr(data and data.purpose or '', bcfg.maxPurposeLength or 80)
    local senderName = playerNameFromCharinfo(P.PlayerData.charinfo)

    local okRemove, removeMsg = removeMoneyFromPlayer(P, 'bank', amount, 'phone-bank-transfer')
    if not okRemove then return { ok = false, message = removeMsg } end

    if not addMoneyToCitizen(recipient.citizenid, 'bank', amount, 'phone-bank-transfer-in') then
        P.Functions.AddMoney('bank', amount, 'phone-bank-transfer-refund')
        return { ok = false, message = 'Nepavyko įskaityti gavėjui.' }
    end

    transferCooldown[src] = now

    Bank.LogTransaction(citizenid, 'transfer_out', -amount, ('Pervedimas · %s'):format(recipient.name), {
        counterparty = recipient.name,
        counterpartyCitizenid = recipient.citizenid,
        purpose = purpose,
    })
    Bank.LogTransaction(recipient.citizenid, 'transfer_in', amount, ('Gauta · %s'):format(senderName), {
        counterparty = senderName,
        counterpartyCitizenid = citizenid,
        purpose = purpose,
    })

    logAdmin('TRANSFER', src, citizenid, ('to=%s amount=%s purpose=%s'):format(recipient.citizenid, amount, purpose))

    if recipient.source then
        TriggerClientEvent('QBCore:Notify', recipient.source, ('Gauta %s € nuo %s'):format(amount, senderName), 'success')
        TriggerClientEvent('mrp_phone:client:refreshData', recipient.source)
    end

    local cash, bank = getBalances(P)
    return {
        ok = true,
        amount = amount,
        recipientName = recipient.name,
        recipientCitizenid = recipient.citizenid,
        cash = cash,
        bank = bank,
        txId = ('BNK%s'):format(os.time()),
    }
end

function Bank.Deposit(src, amount)
    local citizenid, P = citizenFromSrc(src)
    if not citizenid then return { ok = false, message = 'Žaidėjas nerastas.' } end
    amount = math.floor(tonumber(amount) or 0)
    local maxA = (cfg().maxDepositWithdraw) or 500000
    if amount < 1 then return { ok = false, message = 'Įveskite sumą.' } end
    if amount > maxA then return { ok = false, message = ('Maksimali suma: %s €'):format(maxA) } end

    local okRemove, removeMsg = removeMoneyFromPlayer(P, 'cash', amount, 'phone-bank-deposit')
    if not okRemove then return { ok = false, message = removeMsg } end
    P.Functions.AddMoney('bank', amount, 'phone-bank-deposit')

    Bank.LogTransaction(citizenid, 'deposit', amount, 'Įnešimas į banką', {})
    logAdmin('DEPOSIT', src, citizenid, ('amount=%s'):format(amount))

    local cash, bank = getBalances(P)
    return { ok = true, amount = amount, cash = cash, bank = bank }
end

function Bank.Withdraw(src, amount)
    local citizenid, P = citizenFromSrc(src)
    if not citizenid then return { ok = false, message = 'Žaidėjas nerastas.' } end
    amount = math.floor(tonumber(amount) or 0)
    local maxA = (cfg().maxDepositWithdraw) or 500000
    if amount < 1 then return { ok = false, message = 'Įveskite sumą.' } end
    if amount > maxA then return { ok = false, message = ('Maksimali suma: %s €'):format(maxA) } end

    local okRemove, removeMsg = removeMoneyFromPlayer(P, 'bank', amount, 'phone-bank-withdraw')
    if not okRemove then return { ok = false, message = removeMsg } end
    P.Functions.AddMoney('cash', amount, 'phone-bank-withdraw')

    Bank.LogTransaction(citizenid, 'withdraw', -amount, 'Išėmimas iš banko', {})
    logAdmin('WITHDRAW', src, citizenid, ('amount=%s'):format(amount))

    local cash, bank = getBalances(P)
    return { ok = true, amount = amount, cash = cash, bank = bank }
end

function Bank.GetHistory(src, filter)
    local citizenid = citizenFromSrc(src)
    if not citizenid then return { ok = false, message = 'Žaidėjas nerastas.' } end
    filter = tostring(filter or 'all')
    local limit = (cfg().historyLimit) or 50
    local rows
    if filter == 'all' then
        rows = MySQL.query.await([[
            SELECT id, tx_type, amount, title, counterparty, purpose, status, created_at
            FROM fivempro_phone_bank_transactions
            WHERE citizenid = ?
            ORDER BY id DESC LIMIT ?
        ]], { citizenid, limit }) or {}
    else
        rows = MySQL.query.await([[
            SELECT id, tx_type, amount, title, counterparty, purpose, status, created_at
            FROM fivempro_phone_bank_transactions
            WHERE citizenid = ? AND tx_type = ?
            ORDER BY id DESC LIMIT ?
        ]], { citizenid, filter, limit }) or {}
    end
    return { ok = true, transactions = normalizeTransactions(rows) }
end

QBCore.Functions.CreateCallback('mrp_phone:server:bankGetState', function(source, cb)
    cb(Bank.GetState(source))
end)

QBCore.Functions.CreateCallback('mrp_phone:server:bankLookupRecipient', function(source, cb, data)
    cb(Bank.LookupRecipient(source, data and data.query))
end)

QBCore.Functions.CreateCallback('mrp_phone:server:bankTransfer', function(source, cb, data)
    local res = Bank.Transfer(source, data)
    if res.ok then
        TriggerClientEvent('mrp_phone:client:refreshData', source)
    end
    cb(res)
end)

QBCore.Functions.CreateCallback('mrp_phone:server:bankDeposit', function(source, cb, data)
    local res = Bank.Deposit(source, data and data.amount)
    if res.ok then
        TriggerClientEvent('mrp_phone:client:refreshData', source)
    end
    cb(res)
end)

QBCore.Functions.CreateCallback('mrp_phone:server:bankWithdraw', function(source, cb, data)
    local res = Bank.Withdraw(source, data and data.amount)
    if res.ok then
        TriggerClientEvent('mrp_phone:client:refreshData', source)
    end
    cb(res)
end)

QBCore.Functions.CreateCallback('mrp_phone:server:bankGetHistory', function(source, cb, data)
    cb(Bank.GetHistory(source, data and data.filter))
end)

exports('LogBankTransaction', function(citizenid, txType, amount, title, opts)
    Bank.LogTransaction(citizenid, txType, amount, title, opts or {})
end)

AddEventHandler('QBCore:Server:OnMoneyChange', function(src, moneyType, amount, action, reason)
    if moneyType ~= 'bank' then return end
    if shouldSkipMoneyLog(reason) then return end

    local citizenid = citizenFromSrc(src)
    if not citizenid then return end

    Bank.EnsureAccount(citizenid)

    local txType, delta, title = classifyMoneyChange(moneyType, action, amount, reason)
    if not txType or not delta then return end

    Bank.LogTransaction(citizenid, txType, delta, title, { status = 'completed' })
end)

AddEventHandler('playerDropped', function()
    transferCooldown[source] = nil
end)

CreateThread(function()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `fivempro_phone_bank_accounts` (
          `citizenid` varchar(60) NOT NULL,
          `account_number` varchar(24) NOT NULL,
          `card_last4` varchar(4) NOT NULL,
          `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
          PRIMARY KEY (`citizenid`),
          UNIQUE KEY `uniq_bank_account` (`account_number`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `fivempro_phone_bank_transactions` (
          `id` int NOT NULL AUTO_INCREMENT,
          `citizenid` varchar(60) NOT NULL,
          `tx_type` varchar(24) NOT NULL DEFAULT 'other',
          `amount` int NOT NULL DEFAULT 0,
          `title` varchar(80) NOT NULL DEFAULT '',
          `counterparty` varchar(64) NULL,
          `counterparty_citizenid` varchar(60) NULL,
          `purpose` varchar(120) NULL,
          `status` varchar(16) NOT NULL DEFAULT 'completed',
          `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
          PRIMARY KEY (`id`),
          KEY `idx_bank_tx_cid` (`citizenid`),
          KEY `idx_bank_tx_created` (`created_at`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])
end)
