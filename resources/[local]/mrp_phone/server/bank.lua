local QBCore = exports['qb-core']:GetCoreObject()

Bank = Bank or {}

local transferCooldown = {}
local dwCooldown = {}

local function parseAmount(data)
    if type(data) == 'number' or type(data) == 'string' then
        return math.floor(tonumber(data) or 0)
    end
    if type(data) == 'table' then
        return math.floor(tonumber(data.amount or data.value) or 0)
    end
    return 0
end

local function dwBusy(src, action)
    local now = os.time()
    dwCooldown[src] = dwCooldown[src] or {}
    local last = dwCooldown[src][action] or 0
    if now - last < 1 then return true end
    dwCooldown[src][action] = now
    return false
end

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
        if row.title then
            row.title = resolveTransactionTitle(row.title)
        end
    end
    return rows
end

local SHOP_REASON_LABELS = {
    ['fivempro-food'] = 'Maisto parduotuvė',
    ['fivempro-pharmacy'] = 'Vaistinė',
    ['fivempro-junk-shop'] = 'Ūkio turgelis',
    ['mrp_pd_supply'] = 'PD inventorius',
    ['mrp_ems_supply'] = 'EMS inventorius',
    ['mrp_ranger_supply'] = 'Gamtos apsaugos inventorius',
}

local EXACT_REASON_LABELS = {
    ['fivempro-dealership-buy'] = 'Simiono mašinų parduotuvė',
    ['fivempro-pd-dealership-buy'] = 'PD transporto pirkimas',
    ['fivempro-job-dealership-buy'] = 'Tarnybinio transporto pirkimas',
    ['mrp-dealership-special-buy'] = 'Automobilių parduotuvė',
    ['shop-purchase'] = 'Parduotuvė',
    ['shop-purchase-refund'] = 'Grąžinimas (parduotuvė)',
    ['clothing-shop'] = 'Drabužių parduotuvė',
    ['tattoo-shop'] = 'Tatuiruotės salonas',
    ['fuel-pump'] = 'Degalinė',
    ['car-washed'] = 'Automobilio plovimas',
    ['bike-rental'] = 'Dviračio nuoma',
    ['bike-rental-refund'] = 'Dviračio nuomos grąžinimas',
    ['driving-school-exam'] = 'Vairavimo mokykla',
    ['fivempro-kma-reclaim'] = 'Transporto išsievimas',
    ['fivempro-kma-refund'] = 'Transporto išsievimo grąžinimas',
    ['mrp_housing:purchase'] = 'Nekilnojamojo turto agentūra',
    ['fivempro-drugs-supply'] = 'Juodoji rinka',
    ['fivempro-drugs-supply-refund'] = 'Juodosios rinkos grąžinimas',
    ['gang-tablet-purchase'] = 'Gaujos planšetė',
    ['trucker-register'] = 'Krovininio transporto registracija',
    ['trucker-company-create'] = 'Krovininės įmonės steigimas',
    ['trucker-delivery'] = 'Krovininio transporto užmokestis',
    ['fivempro-taxi-fare'] = 'Taksi kelionė',
    ['fivempro-taxi-fare-income'] = 'Taksi uždarbis',
    ['ltpd-fine'] = 'Policijos bauda',
    ['ranger-fine'] = 'Gamtos apsaugos bauda',
    ['casino-chips-buy'] = 'Kazino žetonai',
    ['casino-chips-sell'] = 'Kazino išmoka',
    ['darknet-hack'] = 'Darknet paslauga',
    ['bank-to-crypto'] = 'Kriptovaliutos keitykla',
    ['fivempro-bank-deposit'] = 'Įnešimas į banką',
    ['fivempro-bank-withdraw'] = 'Išėmimas iš banko',
    ['fivempro-bank-transfer-out'] = 'Pervedimas',
    ['fivempro-bank-transfer-in'] = 'Gautas pervedimas',
    ['paycheck'] = 'Alga',
    ['outdoors-license-test'] = 'Medžioklės licencija',
    ['gang-interrog-kit-test'] = 'Interrogacijos rinkinys',
    ['debug-heist-item'] = 'Juodoji rinka',
    ['debug-heist-flash'] = 'Juodoji rinka',
    ['qb-weapons:server:RepairWeapon'] = 'Ginklų remontas',
}

local SERVICE_INVOICE_LABELS = {
    ems = 'EMS paslaugų sąskaita',
    mechanic = 'Mechanikų sąskaita',
}

local function looksLikeTechnicalReason(title)
    title = tostring(title or '')
    if title == '' then return false end
    if EXACT_REASON_LABELS[title] then return false end
    if title:find('^shop%-purchase:', 1, false) then return true end
    if title:find('^shop%-purchase%-refund:', 1, false) then return true end
    if title:find('fivempro', 1, true) then return true end
    if title:find('^mrp[_%-]', 1, false) then return true end
    if title:find('dealership', 1, true) then return true end
    if title == 'shop-purchase' or title == 'shop-purchase-refund' then return true end
    if title:find('^service%-invoice%-', 1, false) then return true end
    if title:find('^stripclub', 1, false) then return true end
    return title:find('%-', 1, true) ~= nil and not title:find(' ', 1, true)
end

function resolveTransactionTitle(reason)
    reason = trim(reason)
    if reason == '' then return 'Operacija' end

    local exact = EXACT_REASON_LABELS[reason]
    if exact then return exact end

    local shopName = reason:match('^shop%-purchase:(.+)$')
        or reason:match('^shop%-purchase%-refund:(.+)$')
    if shopName then
        return SHOP_REASON_LABELS[shopName] or 'Parduotuvė'
    end

    local service = reason:match('^service%-invoice%-(.+)$')
    if service then
        return SERVICE_INVOICE_LABELS[service] or 'Paslaugų sąskaita'
    end

    if reason:find('^stripclub', 1, false) then
        return 'Striptizo klubas'
    end

    if reason:find('dealership', 1, true) then
        if reason:find('pd', 1, true) then return 'PD transporto pirkimas' end
        if reason:find('job', 1, true) then return 'Tarnybinio transporto pirkimas' end
        return 'Simiono mašinų parduotuvė'
    end

    if reason:find('fuel', 1, true) then return 'Degalinė' end
    if reason:find('taxi', 1, true) then
        if reason:find('income', 1, true) then return 'Taksi uždarbis' end
        return 'Taksi kelionė'
    end
    if reason:find('fine', 1, true) or reason:find('bauda', 1, true) then return 'Bauda' end
    if reason:find('housing', 1, true) then return 'Nekilnojamojo turto agentūra' end
    if reason:find('trucker', 1, true) then return 'Krovininis transportas' end
    if reason:find('clothing', 1, true) then return 'Drabužių parduotuvė' end
    if reason:find('tattoo', 1, true) then return 'Tatuiruotės salonas' end
    if reason:find('casino', 1, true) then return 'Kazino' end
    if reason:find('refund', 1, true) then return 'Grąžinimas' end

    if looksLikeTechnicalReason(reason) then
        return 'Mokėjimas'
    end

    return reason
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
    local title = resolveTransactionTitle(reason)

    if lower:find('paycheck', 1, true) or lower:find('alga', 1, true) or lower:find('salary', 1, true) then
        txType = 'salary'
        title = 'Alga'
    elseif lower:find('fine', 1, true) or lower:find('bauda', 1, true) then
        txType = 'fine'
        local fineTitle = resolveTransactionTitle(reason)
        title = (fineTitle ~= reason and fineTitle ~= 'Mokėjimas') and fineTitle or 'Bauda'
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
    if not P or not P.PlayerData then
        return 0, 0
    end
    if P.Functions and P.Functions.GetMoney then
        return math.floor(P.Functions.GetMoney('cash') or 0), math.floor(P.Functions.GetMoney('bank') or 0)
    end
    local money = P.PlayerData.money or {}
    return math.floor(tonumber(money.cash) or 0), math.floor(tonumber(money.bank) or 0)
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

--- Cash deposit/withdraw only at bank desk / ATM (mrp_bank export). Phone transfers stay remote.
local function requireNearBankTerminal(src)
    if GetResourceState('mrp_bank') ~= 'started' then
        return false, 'Banko terminalas nepasiekiamas.'
    end
    local ok, near = pcall(function()
        return exports['mrp_bank']:IsNearBankOrAtm(src)
    end)
    if not ok or not near then
        return false, 'Turite būti prie bankomato arba banko.'
    end
    return true
end

function Bank.Deposit(src, amount)
    if dwBusy(src, 'deposit') then return { ok = false, message = 'Palaukite akimirką.' } end
    local nearOk, nearMsg = requireNearBankTerminal(src)
    if not nearOk then return { ok = false, message = nearMsg } end
    local citizenid, P = citizenFromSrc(src)
    if not citizenid then return { ok = false, message = 'Žaidėjas nerastas.' } end
    amount = math.floor(tonumber(amount) or 0)
    local maxA = (cfg().maxDepositWithdraw) or 500000
    if amount < 1 then return { ok = false, message = 'Įveskite sumą.' } end
    if amount > maxA then return { ok = false, message = ('Maksimali suma: %s €'):format(maxA) } end
    local cash, _ = getBalances(P)
    if cash < amount then
        return { ok = false, message = ('Nepakanka grynais. Turite %s €.'):format(cash) }
    end

    local okRemove, removeMsg = removeMoneyFromPlayer(P, 'cash', amount, 'phone-bank-deposit')
    if not okRemove then return { ok = false, message = removeMsg } end
    P.Functions.AddMoney('bank', amount, 'phone-bank-deposit')

    Bank.LogTransaction(citizenid, 'deposit', amount, 'Įnešimas į banką', {})
    logAdmin('DEPOSIT', src, citizenid, ('amount=%s'):format(amount))

    local cash, bank = getBalances(P)
    return { ok = true, amount = amount, cash = cash, bank = bank }
end

function Bank.Withdraw(src, amount)
    if dwBusy(src, 'withdraw') then return { ok = false, message = 'Palaukite akimirką.' } end
    local nearOk, nearMsg = requireNearBankTerminal(src)
    if not nearOk then return { ok = false, message = nearMsg } end
    local citizenid, P = citizenFromSrc(src)
    if not citizenid then return { ok = false, message = 'Žaidėjas nerastas.' } end
    amount = math.floor(tonumber(amount) or 0)
    local maxA = (cfg().maxDepositWithdraw) or 500000
    if amount < 1 then return { ok = false, message = 'Įveskite sumą.' } end
    if amount > maxA then return { ok = false, message = ('Maksimali suma: %s €'):format(maxA) } end
    local _, bank = getBalances(P)
    if bank < amount then
        return { ok = false, message = ('Nepakanka banke. Turite %s €.'):format(bank) }
    end

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
    local res = Bank.Deposit(source, parseAmount(data))
    if res.ok then
        TriggerClientEvent('mrp_phone:client:refreshData', source)
    end
    cb(res)
end)

QBCore.Functions.CreateCallback('mrp_phone:server:bankWithdraw', function(source, cb, data)
    local res = Bank.Withdraw(source, parseAmount(data))
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
    local src = source
    transferCooldown[src] = nil
    dwCooldown[src] = nil
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
