local QBCore = exports['qb-core']:GetCoreObject()

local statsCache = {}
local blackjackSessions = {}

CreateThread(function()
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `casino_player_stats` (
        `citizenid` VARCHAR(50) NOT NULL,
        `day_key` VARCHAR(10) NOT NULL DEFAULT '',
        `daily_wins` INT NOT NULL DEFAULT 0,
        `banned_until` VARCHAR(10) NOT NULL DEFAULT '',
        `wheel_at` BIGINT NOT NULL DEFAULT 0,
        PRIMARY KEY (`citizenid`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])
end)

local RED_NUMBERS = {
    [1] = true, [3] = true, [5] = true, [7] = true, [9] = true,
    [12] = true, [14] = true, [16] = true, [18] = true, [19] = true,
    [21] = true, [23] = true, [25] = true, [27] = true, [30] = true,
    [32] = true, [34] = true, [36] = true,
}

local function limits()
    return Config.Limits or {}
end

local function dayKey()
    return os.date('%Y-%m-%d')
end

local function notify(src, msg, ntype)
    TriggerClientEvent('QBCore:Notify', src, msg, ntype or 'primary')
end

local function getPlayer(src)
    return QBCore.Functions.GetPlayer(src)
end

local function playerCash(Player)
    return tonumber(Player.PlayerData.money and Player.PlayerData.money.cash) or 0
end

local function isInCasino(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end
    local c = GetEntityCoords(ped)
    local casino = Config.Casino or {}
    local center = casino.center
    if not center then return false end
    return #(vector3(c.x, c.y, c.z) - vector3(center.x, center.y, center.z)) <= (casino.radius or 90.0)
end

local function defaultStats()
    return {
        day_key = dayKey(),
        daily_wins = 0,
        banned_until = '',
        wheel_at = 0,
    }
end

local function loadStats(citizenid, cb)
    if statsCache[citizenid] then
        return cb(statsCache[citizenid])
    end
    MySQL.single('SELECT day_key, daily_wins, banned_until, wheel_at FROM casino_player_stats WHERE citizenid = ?', { citizenid }, function(row)
        local stats = defaultStats()
        if row then
            stats.day_key = row.day_key or stats.day_key
            stats.daily_wins = tonumber(row.daily_wins) or 0
            stats.banned_until = row.banned_until or ''
            stats.wheel_at = tonumber(row.wheel_at) or 0
        end
        if stats.day_key ~= dayKey() then
            stats.day_key = dayKey()
            stats.daily_wins = 0
            if stats.banned_until ~= '' and stats.banned_until < dayKey() then
                stats.banned_until = ''
            end
        end
        statsCache[citizenid] = stats
        cb(stats)
    end)
end

local function saveStats(citizenid, stats)
    statsCache[citizenid] = stats
    MySQL.insert([[
        INSERT INTO casino_player_stats (citizenid, day_key, daily_wins, banned_until, wheel_at)
        VALUES (?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE
            day_key = VALUES(day_key),
            daily_wins = VALUES(daily_wins),
            banned_until = VALUES(banned_until),
            wheel_at = VALUES(wheel_at)
    ]], {
        citizenid,
        stats.day_key,
        stats.daily_wins,
        stats.banned_until,
        stats.wheel_at,
    })
end

local function isCasinoBanned(stats)
    local today = dayKey()
    if stats.banned_until ~= '' and stats.banned_until >= today then
        return true
    end
    if stats.day_key == today and stats.daily_wins >= (limits().maxDailyWin or 50000) then
        stats.banned_until = today
        return true
    end
    return false
end

local function clampBet(amount)
    local lim = limits()
    amount = math.floor(tonumber(amount) or 0)
    if amount < (lim.minBet or 50) then return nil, 'minimalus statymas $' .. (lim.minBet or 50) end
    if amount > (lim.maxBet or 50000) then return nil, 'maksimalus statymas $' .. (lim.maxBet or 50000) end
    return amount
end

local function remainingDailyWin(stats)
    return math.max(0, (limits().maxDailyWin or 50000) - (stats.daily_wins or 0))
end

local function applyCasinoWin(src, Player, stats, rawWin, countsTowardLimit)
    rawWin = math.floor(tonumber(rawWin) or 0)
    if rawWin <= 0 then return 0 end

    local maxSingle = limits().maxSingleWin or 50000
    rawWin = math.min(rawWin, maxSingle)

    local payout = rawWin
    if countsTowardLimit then
        local room = remainingDailyWin(stats)
        if room <= 0 then
            stats.banned_until = dayKey()
            saveStats(Player.PlayerData.citizenid, stats)
            TriggerClientEvent('fivempro_casino:client:casinoBanned', src, stats.banned_until)
            return 0
        end
        payout = math.min(rawWin, room)
        stats.daily_wins = (stats.daily_wins or 0) + payout
        if stats.daily_wins >= (limits().maxDailyWin or 50000) then
            stats.banned_until = dayKey()
            TriggerClientEvent('fivempro_casino:client:casinoBanned', src, stats.banned_until)
        end
        saveStats(Player.PlayerData.citizenid, stats)
    end

    if payout > 0 then
        Player.Functions.AddMoney('cash', payout, 'casino-win')
    end
    return payout
end

local function validateCasinoPlay(src, cb)
    local Player = getPlayer(src)
    if not Player then return cb(false, 'Klaida.') end
    if not isInCasino(src) then return cb(false, 'Turite būti kazino.') end

    loadStats(Player.PlayerData.citizenid, function(stats)
        if isCasinoBanned(stats) then
            TriggerClientEvent('fivempro_casino:client:casinoBanned', src, stats.banned_until)
            return cb(false, 'Pasiekėte dienos laimėjimų limitą ($50,000). Grįžkite rytoj.')
        end
        cb(true, Player, stats)
    end)
end

local function takeBet(Player, amount)
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then return false, 'Netinkamas statymas.' end
    if playerCash(Player) < amount then return false, 'Nepakanka grynujų.' end
    Player.Functions.RemoveMoney('cash', amount, 'casino-bet')
    return true
end

-- Blackjack helpers
local function newDeck()
    local deck = {}
    for v = 1, 13 do
        for _ = 1, 4 do
            deck[#deck + 1] = v
        end
    end
    for i = #deck, 2, -1 do
        local j = math.random(i)
        deck[i], deck[j] = deck[j], deck[i]
    end
    return deck
end

local function drawCard(deck)
    if #deck == 0 then deck = newDeck() end
    return table.remove(deck), deck
end

local function cardLabel(v)
    if v == 1 then return 'A' end
    if v == 11 then return 'J' end
    if v == 12 then return 'Q' end
    if v == 13 then return 'K' end
    return tostring(v)
end

local function handValue(cards)
    local total, aces = 0, 0
    for _, v in ipairs(cards) do
        if v == 1 then
            aces = aces + 1
            total = total + 11
        elseif v >= 10 then
            total = total + 10
        else
            total = total + v
        end
    end
    while total > 21 and aces > 0 do
        total = total - 10
        aces = aces - 1
    end
    return total
end

local function formatHand(cards)
    local parts = {}
    for _, v in ipairs(cards) do parts[#parts + 1] = cardLabel(v) end
    return table.concat(parts, ' ')
end

local function pickWeightedPrize(prizes)
    local total = 0
    for _, p in ipairs(prizes) do total = total + (p.weight or 1) end
    local roll = math.random(total)
    local acc = 0
    for _, p in ipairs(prizes) do
        acc = acc + (p.weight or 1)
        if roll <= acc then return p end
    end
    return prizes[1]
end

local function rouletteColor(n)
    if n == 0 then return 'green' end
    if RED_NUMBERS[n] then return 'red' end
    return 'black'
end

local function rouletteWin(betType, betValue, result)
    local payouts = Config.RoulettePayouts or {}
    if betType == 'number' then
        if tonumber(betValue) == result then
            return (payouts.number or 36)
        end
        return 0
    end
    if result == 0 then return 0 end
    if betType == 'red' and rouletteColor(result) == 'red' then return payouts.red or 2 end
    if betType == 'black' and rouletteColor(result) == 'black' then return payouts.black or 2 end
    if betType == 'odd' and result % 2 == 1 then return payouts.odd or 2 end
    if betType == 'even' and result % 2 == 0 then return payouts.even or 2 end
    if betType == 'low' and result >= 1 and result <= 18 then return payouts.low or 2 end
    if betType == 'high' and result >= 19 and result <= 36 then return payouts.high or 2 end
    return 0
end

local function spinSlots()
    local symbols = Config.SlotSymbols or { '7', 'BAR', 'CH' }
    local a = symbols[math.random(#symbols)]
    local b = symbols[math.random(#symbols)]
    local c = symbols[math.random(#symbols)]
    return a, b, c
end

local function slotMultiplier(a, b, c)
    local key = ('%s-%s-%s'):format(a, b, c)
    local payouts = Config.SlotPayouts or {}
    if payouts[key] then return payouts[key] end
    if a == b or b == c or a == c then return payouts.pair or 2 end
    return 0
end

-- Callbacks / events
QBCore.Functions.CreateCallback('fivempro_casino:server:getStatus', function(src, cb)
    local Player = getPlayer(src)
    if not Player then return cb(nil) end
    loadStats(Player.PlayerData.citizenid, function(stats)
        cb({
            dailyWins = stats.daily_wins,
            maxDailyWin = limits().maxDailyWin or 50000,
            remaining = remainingDailyWin(stats),
            banned = isCasinoBanned(stats),
            bannedUntil = stats.banned_until,
            wheelCooldown = stats.wheel_at,
        })
    end)
end)

QBCore.Functions.CreateCallback('fivempro_casino:server:spinWheel', function(src, cb)
    local Player = getPlayer(src)
    if not Player then return cb({ ok = false, msg = 'Klaida.' }) end
    if not isInCasino(src) then return cb({ ok = false, msg = 'Turite būti prie laimės rato.' }) end

    loadStats(Player.PlayerData.citizenid, function(stats)
        if isCasinoBanned(stats) then
            TriggerClientEvent('fivempro_casino:client:casinoBanned', src, stats.banned_until)
            return cb({ ok = false, msg = 'Pasiekėte dienos limitą. Ratas neprieinamas.' })
        end

        local now = os.time()
        local cooldown = (Config.Wheel and Config.Wheel.cooldownHours or 24) * 3600
        if stats.wheel_at > 0 and (now - stats.wheel_at) < cooldown then
            local left = cooldown - (now - stats.wheel_at)
            local hrs = math.ceil(left / 3600)
            return cb({ ok = false, msg = ('Ratas galimas po %s val.'):format(hrs) })
        end

        local prize = pickWeightedPrize(Config.Wheel and Config.Wheel.prizes or {})
        stats.wheel_at = now
        saveStats(Player.PlayerData.citizenid, stats)

        local paid = 0
        if prize.type == 'cash' and prize.amount > 0 then
            Player.Functions.AddMoney('cash', prize.amount, 'casino-wheel')
            paid = prize.amount
        elseif prize.type == 'chips' and prize.amount > 0 then
            Player.Functions.AddItem('casinochips', prize.amount)
            paid = prize.amount
        end

        cb({
            ok = true,
            label = prize.label,
            type = prize.type,
            amount = prize.amount,
            paid = paid,
        })
    end)
end)

QBCore.Functions.CreateCallback('fivempro_casino:server:startBlackjack', function(src, cb, bet)
    validateCasinoPlay(src, function(ok, Player, stats)
        if not ok then return cb({ ok = false, msg = Player }) end
        local amount, err = clampBet(bet)
        if not amount then return cb({ ok = false, msg = err }) end
        local paid, perr = takeBet(Player, amount)
        if not paid then return cb({ ok = false, msg = perr }) end

        local deck = newDeck()
        local player = {}
        local dealer = {}
        player[1], deck = drawCard(deck)
        dealer[1], deck = drawCard(deck)
        player[2], deck = drawCard(deck)
        dealer[2], deck = drawCard(deck)

        blackjackSessions[src] = {
            bet = amount,
            deck = deck,
            player = player,
            dealer = dealer,
            done = false,
        }

        local pVal = handValue(player)
        local dVal = handValue({ dealer[1] })
        if pVal == 21 then
            local win = math.floor(amount * 2.5)
            win = math.min(win, limits().maxSingleWin or 50000)
            local payout = applyCasinoWin(src, Player, stats, win, true)
            blackjackSessions[src] = nil
            return cb({
                ok = true,
                finished = true,
                playerHand = formatHand(player),
                dealerHand = formatHand(dealer),
                playerValue = pVal,
                dealerValue = handValue(dealer),
                result = 'blackjack',
                payout = payout,
            })
        end

        cb({
            ok = true,
            finished = false,
            playerHand = formatHand(player),
            dealerHand = cardLabel(dealer[1]) .. ' ?',
            playerValue = pVal,
            dealerValue = dVal,
            canDouble = #player == 2 and playerCash(Player) >= amount,
        })
    end)
end)

QBCore.Functions.CreateCallback('fivempro_casino:server:blackjackAction', function(src, cb, action)
    local session = blackjackSessions[src]
    if not session or session.done then return cb({ ok = false, msg = 'Nėra aktyvaus žaidimo.' }) end

    local Player = getPlayer(src)
    if not Player then return cb({ ok = false, msg = 'Klaida.' }) end
    if not isInCasino(src) then
        blackjackSessions[src] = nil
        return cb({ ok = false, msg = 'Palikote kazino.' })
    end

    loadStats(Player.PlayerData.citizenid, function(stats)
        local deck = session.deck
        local player = session.player
        local dealer = session.dealer
        local bet = session.bet

        if action == 'hit' then
            player[#player + 1], deck = drawCard(deck)
        elseif action == 'double' then
            if #player ~= 2 then return cb({ ok = false, msg = 'Double negalimas.' }) end
            if playerCash(Player) < bet then return cb({ ok = false, msg = 'Nepakanka pinigų double.' }) end
            Player.Functions.RemoveMoney('cash', bet, 'casino-bj-double')
            bet = bet * 2
            session.bet = bet
            player[#player + 1], deck = drawCard(deck)
            action = 'stand'
        end

        local pVal = handValue(player)
        if action == 'hit' and pVal <= 21 then
            session.deck = deck
            return cb({
                ok = true,
                finished = false,
                playerHand = formatHand(player),
                dealerHand = cardLabel(dealer[1]) .. ' ?',
                playerValue = pVal,
                canDouble = false,
            })
        end

        while handValue(dealer) < 17 do
            dealer[#dealer + 1], deck = drawCard(deck)
        end

        local dVal = handValue(dealer)
        local payout = 0
        local result = 'lose'
        if pVal > 21 then
            result = 'bust'
        elseif dVal > 21 or pVal > dVal then
            result = 'win'
            payout = applyCasinoWin(src, Player, stats, bet * 2, true)
        elseif pVal == dVal then
            result = 'push'
            Player.Functions.AddMoney('cash', bet, 'casino-bj-push')
            payout = bet
        end

        blackjackSessions[src] = nil
        cb({
            ok = true,
            finished = true,
            playerHand = formatHand(player),
            dealerHand = formatHand(dealer),
            playerValue = pVal,
            dealerValue = dVal,
            result = result,
            payout = payout,
        })
    end)
end)

QBCore.Functions.CreateCallback('fivempro_casino:server:playRoulette', function(src, cb, bet, betType, betValue)
    validateCasinoPlay(src, function(ok, Player, stats)
        if not ok then return cb({ ok = false, msg = Player }) end
        local amount, err = clampBet(bet)
        if not amount then return cb({ ok = false, msg = err }) end
        local paid, perr = takeBet(Player, amount)
        if not paid then return cb({ ok = false, msg = perr }) end

        local result = math.random(0, 36)
        local mult = rouletteWin(betType, betValue, result)
        local gross = mult > 0 and (amount * mult) or 0
        local payout = mult > 0 and applyCasinoWin(src, Player, stats, gross, true) or 0

        cb({
            ok = true,
            result = result,
            color = rouletteColor(result),
            payout = payout,
            won = payout > 0,
        })
    end)
end)

QBCore.Functions.CreateCallback('fivempro_casino:server:playSlots', function(src, cb, bet)
    validateCasinoPlay(src, function(ok, Player, stats)
        if not ok then return cb({ ok = false, msg = Player }) end
        local amount, err = clampBet(bet)
        if not amount then return cb({ ok = false, msg = err }) end
        local paid, perr = takeBet(Player, amount)
        if not paid then return cb({ ok = false, msg = perr }) end

        local a, b, c = spinSlots()
        local mult = slotMultiplier(a, b, c)
        local gross = mult > 0 and (amount * mult) or 0
        local payout = mult > 0 and applyCasinoWin(src, Player, stats, gross, true) or 0

        cb({
            ok = true,
            reels = { a, b, c },
            multiplier = mult,
            payout = payout,
            won = payout > 0,
        })
    end)
end)

RegisterNetEvent('fivempro_casino:server:rollDice', function(count, sides)
    local src = source
    count = math.floor(tonumber(count) or 1)
    sides = math.floor(tonumber(sides) or 6)
    local diceCfg = Config.Dice or {}
    count = math.max(1, math.min(count, diceCfg.maxDice or 3))
    sides = math.max(2, math.min(sides, diceCfg.maxSides or 20))

    local rolls = {}
    local total = 0
    for _ = 1, count do
        local r = math.random(1, sides)
        rolls[#rolls + 1] = r
        total = total + r
    end

    local ped = GetPlayerPed(src)
    local coords = GetEntityCoords(ped)
    local radius = diceCfg.syncRadius or 35.0
    for _, playerId in ipairs(GetPlayers()) do
        local tid = tonumber(playerId)
        local tped = GetPlayerPed(tid)
        if tped and tped ~= 0 then
            local tc = GetEntityCoords(tped)
            if #(coords - tc) <= radius then
                TriggerClientEvent('fivempro_casino:client:showDiceRoll', tid, src, rolls, sides, total)
            end
        end
    end
end)

AddEventHandler('playerDropped', function()
    blackjackSessions[source] = nil
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    blackjackSessions = {}
end)
