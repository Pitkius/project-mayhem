--[[
  Mayhem credits — QBCore money type "credits".
  Rate: 1 EUR = 1 CR (Config.EurToCredits).

  Tebex package commands (no leading slash), examples:
    mrp_credits tebex {id} {price} {transaction}
    mrp_credits give {id} 1000 {transaction}

  {id}   = online server id (Tebex online delivery)
  {hexid}= steam:… (also accepted)
  {price}= package EUR price → credits = floor(price * EurToCredits)
  {transaction} = Tebex txn id (idempotent)
]]

local QBCore = exports['qb-core']:GetCoreObject()

CreateThread(function()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `mrp_credit_transactions` (
            `id` INT NOT NULL AUTO_INCREMENT,
            `txn_id` VARCHAR(64) NOT NULL,
            `citizenid` VARCHAR(50) NULL,
            `identifier` VARCHAR(80) NULL,
            `amount` INT NOT NULL,
            `eur` DECIMAL(12,2) NULL,
            `source` VARCHAR(32) NOT NULL DEFAULT 'tebex',
            `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`),
            UNIQUE KEY `uq_txn` (`txn_id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])
end)

local function normalizeIdentifier(raw)
    if type(raw) ~= 'string' then return tostring(raw or '') end
    raw = raw:gsub('^%s+', ''):gsub('%s+$', '')
    return raw
end

local function findPlayer(target)
    target = normalizeIdentifier(target)
    if target == '' then return nil end

    local asId = tonumber(target)
    if asId then
        return QBCore.Functions.GetPlayer(asId)
    end

    -- citizenid
    local byCid = QBCore.Functions.GetPlayerByCitizenId(target)
    if byCid then return byCid end

    -- license: / steam: / hexid
    local lower = target:lower()
    if not lower:find(':', 1, true) and #lower >= 10 then
        -- bare hex without prefix → try steam:
        target = 'steam:' .. lower
        lower = target
    end

    for _, pid in ipairs(GetPlayers()) do
        local src = tonumber(pid)
        for i = 0, GetNumPlayerIdentifiers(src) - 1 do
            local ident = GetPlayerIdentifier(src, i)
            if ident and ident:lower() == lower then
                return QBCore.Functions.GetPlayer(src)
            end
        end
    end
    return nil
end

local function getBalance(Player)
    if not Player then return 0 end
    local t = Config.MoneyType or 'credits'
    return tonumber(Player.PlayerData.money and Player.PlayerData.money[t]) or 0
end

local function discordLog(title, fields)
    local url = Config.DiscordWebhook
    if type(url) ~= 'string' or url == '' then return end
    local embeds = { {
        title = title,
        color = 10181046,
        fields = fields,
        footer = { text = 'mrp_credits' },
    } }
    PerformHttpRequest(url, function() end, 'POST', json.encode({ embeds = embeds }), {
        ['Content-Type'] = 'application/json',
    })
end

--- Idempotent grant. Returns ok, err|newBalance
local function grantCredits(Player, amount, opts)
    opts = opts or {}
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then return false, 'bad_amount' end
    if not Player then return false, 'offline' end

    local txn = opts.txnId and tostring(opts.txnId) or nil
    if txn and txn ~= '' and txn ~= '0' then
        local exists = MySQL.scalar.await('SELECT id FROM mrp_credit_transactions WHERE txn_id = ? LIMIT 1', { txn })
        if exists then
            return false, 'duplicate_txn'
        end
    end

    local moneyType = Config.MoneyType or 'credits'
    if Player.PlayerData.money[moneyType] == nil then
        Player.PlayerData.money[moneyType] = 0
    end
    Player.Functions.AddMoney(moneyType, amount, opts.reason or 'tebex-credits')

    local citizenid = Player.PlayerData.citizenid
    local license = Player.PlayerData.license
    if txn and txn ~= '' and txn ~= '0' then
        MySQL.insert.await(
            'INSERT INTO mrp_credit_transactions (txn_id, citizenid, identifier, amount, eur, source) VALUES (?, ?, ?, ?, ?, ?)',
            { txn, citizenid, license, amount, opts.eur, opts.source or 'tebex' }
        )
    else
        MySQL.insert.await(
            'INSERT INTO mrp_credit_transactions (txn_id, citizenid, identifier, amount, eur, source) VALUES (?, ?, ?, ?, ?, ?)',
            {
                ('manual-%s-%s'):format(citizenid or 'x', os.time()),
                citizenid,
                license,
                amount,
                opts.eur,
                opts.source or 'admin',
            }
        )
    end

    local bal = getBalance(Player)
    local src = Player.PlayerData.source
    if src then
        TriggerClientEvent('QBCore:Notify', src, ('Gavai %s kreditų (balansas: %s CR).'):format(amount, bal), 'success')
        TriggerClientEvent('mrp_credits:client:balance', src, bal)
    end

    discordLog('Kreditų papildymas', {
        { name = 'CitizenID', value = tostring(citizenid), inline = true },
        { name = 'Amount', value = tostring(amount) .. ' CR', inline = true },
        { name = 'EUR', value = tostring(opts.eur or '?'), inline = true },
        { name = 'Txn', value = tostring(txn or 'manual'), inline = false },
    })

    return true, bal
end

local function spendCredits(Player, amount, reason)
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then return false, 'bad_amount' end
    if not Player then return false, 'no_player' end
    local moneyType = Config.MoneyType or 'credits'
    local bal = getBalance(Player)
    if bal < amount then return false, 'insufficient' end
    local ok = Player.Functions.RemoveMoney(moneyType, amount, reason or 'premium-shop')
    if not ok then return false, 'remove_failed' end
    local src = Player.PlayerData.source
    if src then
        TriggerClientEvent('mrp_credits:client:balance', src, getBalance(Player))
    end
    return true, getBalance(Player)
end

--- Offline queue: store pending by license until player joins
local Pending = {}

local function queuePending(identifier, amount, opts)
    identifier = normalizeIdentifier(identifier):lower()
    Pending[identifier] = Pending[identifier] or {}
    Pending[identifier][#Pending[identifier] + 1] = {
        amount = amount,
        opts = opts,
    }
end

local function flushPending(Player)
    if not Player then return end
    local src = Player.PlayerData.source
    local keys = {}
    if Player.PlayerData.license then
        keys[#keys + 1] = Player.PlayerData.license:lower()
    end
    if src then
        for i = 0, GetNumPlayerIdentifiers(src) - 1 do
            local ident = GetPlayerIdentifier(src, i)
            if ident then keys[#keys + 1] = ident:lower() end
        end
    end
    for _, key in ipairs(keys) do
        local list = Pending[key]
        if list then
            Pending[key] = nil
            for _, row in ipairs(list) do
                grantCredits(Player, row.amount, row.opts)
            end
        end
    end
end

AddEventHandler('QBCore:Server:PlayerLoaded', function(Player)
    if not Player then return end
    local moneyType = Config.MoneyType or 'credits'
    if Player.PlayerData.money[moneyType] == nil then
        Player.PlayerData.money[moneyType] = 0
        Player.Functions.UpdatePlayerData('money', Player.PlayerData.money)
    end
    flushPending(Player)
end)

--- Resolve target: online player OR queue by license/hex
local function deliverToTarget(target, amount, opts)
    local Player = findPlayer(target)
    if Player then
        return grantCredits(Player, amount, opts)
    end

    -- Queue by license / steam for offline
    local ident = normalizeIdentifier(target)
    if tonumber(ident) then
        return false, 'offline_need_license'
    end
    if not ident:find(':', 1, true) then
        ident = 'steam:' .. ident:lower()
    end
    -- Prefer license if we only got steam — still queue under that key
    queuePending(ident, amount, opts)
    -- Also try to map steam→license later on join via all identifiers
    return true, 'queued'
end

-- ========== Console / Tebex ==========

--- mrp_credits tebex <id|hexid|license> <eurPrice> [transaction]
RegisterCommand('mrp_credits', function(src, args)
    if src ~= 0 then
        print('^1[mrp_credits]^7 Tik konsolė / Tebex.')
        return
    end

    local sub = (args[1] or ''):lower()
    if sub == 'tebex' or sub == 'tebex_eur' then
        local target = args[2]
        local eur = tonumber(args[3]) or 0
        local txn = args[4]
        local credits = math.floor(eur * (Config.EurToCredits or 1))
        if not target or credits <= 0 then
            print('^1[mrp_credits]^7 Naudojimas: mrp_credits tebex <id|hexid|license> <eurPrice> [txn]')
            return
        end
        local ok, res = deliverToTarget(target, credits, {
            txnId = txn,
            eur = eur,
            source = 'tebex',
            reason = 'tebex-purchase',
        })
        print(('[mrp_credits] tebex ok=%s res=%s target=%s cr=%s eur=%s txn=%s'):format(
            tostring(ok), tostring(res), tostring(target), credits, eur, tostring(txn)
        ))
        return
    end

    if sub == 'give' then
        local target = args[2]
        local amount = tonumber(args[3]) or 0
        local txn = args[4]
        local ok, res = deliverToTarget(target, amount, {
            txnId = txn,
            eur = amount / math.max(Config.EurToCredits or 1, 1),
            source = 'tebex',
            reason = 'tebex-give',
        })
        print(('[mrp_credits] give ok=%s res=%s'):format(tostring(ok), tostring(res)))
        return
    end

    print('^3[mrp_credits]^7 Komandos: tebex | give')
end, true)

-- Admin in-game helper
QBCore.Commands.Add('givecredits', 'Duoti kreditų (admin)', {
    { name = 'id', help = 'Server ID' },
    { name = 'amount', help = 'Kreditai' },
}, true, function(source, args)
    local target = tonumber(args[1])
    local amount = tonumber(args[2])
    local Player = target and QBCore.Functions.GetPlayer(target)
    if not Player or not amount then
        TriggerClientEvent('QBCore:Notify', source, 'Naudojimas: /givecredits [id] [amount]', 'error')
        return
    end
    local ok, res = grantCredits(Player, amount, { source = 'admin', reason = 'admin-givecredits' })
    TriggerClientEvent('QBCore:Notify', source, ok and ('OK · balansas %s'):format(res) or tostring(res), ok and 'success' or 'error')
end, 'admin')

-- ========== Exports ==========

exports('GetCredits', function(src)
    local Player = QBCore.Functions.GetPlayer(src)
    return getBalance(Player)
end)

exports('AddCredits', function(src, amount, reason)
    local Player = QBCore.Functions.GetPlayer(src)
    return grantCredits(Player, amount, { source = 'export', reason = reason or 'export' })
end)

exports('RemoveCredits', function(src, amount, reason)
    local Player = QBCore.Functions.GetPlayer(src)
    return spendCredits(Player, amount, reason)
end)

exports('GetStoreUrl', function()
    return Config.TebexStoreUrl
end)

-- Callbacks for dashboard
QBCore.Functions.CreateCallback('mrp_credits:getBalance', function(src, cb)
    local Player = QBCore.Functions.GetPlayer(src)
    cb(getBalance(Player), Config.TebexStoreUrl, Config.EurToCredits)
end)

print('^2[mrp_credits]^7 ready · 1 EUR = ' .. tostring(Config.EurToCredits) .. ' CR')
