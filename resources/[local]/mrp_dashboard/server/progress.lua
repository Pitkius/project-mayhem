--[[
  Dashboard progress: playtime, daily/weekly crate gates, missions, leaderboards.

  Crate unlock = playtime + completed mission count (see shared/config.lua).
  Mission count sources: trucking, gang missions, mrp_jobs complete, export.
]]

local QBCore = exports['qb-core']:GetCoreObject()

local CratesCfg = (Config and Config.Crates) or {}
local MissionsCfg = (Config and Config.Missions) or {}

local CFG = {
    dailyPlayMinutes = tonumber(CratesCfg.dailyPlayMinutes) or 120,
    weeklyPlayMinutes = tonumber(CratesCfg.weeklyPlayMinutes) or 600,
    dailyMissionsRequired = tonumber(CratesCfg.dailyMissionsRequired) or 3,
    weeklyMissionsRequired = tonumber(CratesCfg.weeklyMissionsRequired) or 12,
    dailyMissionMoney = tonumber(MissionsCfg.dailyMoney) or 3000,
    weeklyMissionMoney = tonumber(MissionsCfg.weeklyMoney) or 25000,
    dailyMissionTitle = MissionsCfg.dailyTitle or 'Uždirbk $3,000 šiandien',
    weeklyMissionTitle = MissionsCfg.weeklyTitle or 'Uždirbk $25,000 šią savaitę',
}

local function todayKey()
    return os.date('!%Y-%m-%d')
end

local function weekKey()
    return os.date('!%G-W%V')
end

local function ensureBucket(meta, key, defaults)
    local bucket = meta[key]
    if type(bucket) ~= 'table' then
        bucket = {}
    end
    for k, v in pairs(defaults) do
        if bucket[k] == nil then bucket[k] = v end
    end
    meta[key] = bucket
    return bucket
end

local function getMeta(Player)
    return Player.PlayerData.metadata or {}
end

local function saveMeta(Player, meta)
    Player.Functions.SetMetaData('dashboard_playtime_minutes', meta.dashboard_playtime_minutes or 0)
    Player.Functions.SetMetaData('dashboard_missions_done', meta.dashboard_missions_done or 0)
    Player.Functions.SetMetaData('dashboard_events_won', meta.dashboard_events_won or 0)
    Player.Functions.SetMetaData('dashboard_xp', meta.dashboard_xp or 0)
    Player.Functions.SetMetaData('dashboard_daily', meta.dashboard_daily)
    Player.Functions.SetMetaData('dashboard_weekly', meta.dashboard_weekly)
end

local function refreshPeriods(Player)
    local meta = getMeta(Player)
    meta.dashboard_playtime_minutes = tonumber(meta.dashboard_playtime_minutes) or 0
    meta.dashboard_missions_done = tonumber(meta.dashboard_missions_done) or 0
    meta.dashboard_events_won = tonumber(meta.dashboard_events_won) or 0
    meta.dashboard_xp = tonumber(meta.dashboard_xp) or 0

    local rawDaily = meta.dashboard_daily
    local legacyDailyMoneyClaim =
        type(rawDaily) == 'table'
        and rawDaily.missionClaimed == true
        and rawDaily.moneyMissionClaimed == nil
        and rawDaily.missionsCompleted == nil

    local daily = ensureBucket(meta, 'dashboard_daily', {
        date = todayKey(),
        minutes = 0,
        moneyEarned = 0,
        missionsCompleted = 0,
        missionDone = false,
        missionClaimed = false,
        moneyMissionDone = false,
        moneyMissionClaimed = false,
        claimedCrate = false,
        streak = 0,
        day = 1,
    })
    daily.missionsCompleted = tonumber(daily.missionsCompleted) or 0
    if legacyDailyMoneyClaim then
        daily.moneyMissionClaimed = true
    end
    if daily.date ~= todayKey() then
        local yesterday = os.date('!%Y-%m-%d', os.time() - 86400)
        local streak = tonumber(daily.streak) or 0
        if daily.date == yesterday and daily.claimedCrate then
            streak = streak + 1
        elseif daily.date ~= yesterday then
            streak = daily.claimedCrate and 1 or 0
        end
        daily = {
            date = todayKey(),
            minutes = 0,
            moneyEarned = 0,
            missionsCompleted = 0,
            missionDone = false,
            missionClaimed = false,
            moneyMissionDone = false,
            moneyMissionClaimed = false,
            claimedCrate = false,
            streak = streak,
            day = math.min(7, (tonumber(daily.day) or 1) % 7 + 1),
        }
        meta.dashboard_daily = daily
    end

    local rawWeekly = meta.dashboard_weekly
    local legacyWeeklyMoneyClaim =
        type(rawWeekly) == 'table'
        and rawWeekly.missionClaimed == true
        and rawWeekly.moneyMissionClaimed == nil
        and rawWeekly.missionsCompleted == nil

    local weekly = ensureBucket(meta, 'dashboard_weekly', {
        week = weekKey(),
        minutes = 0,
        moneyEarned = 0,
        missionsCompleted = 0,
        missionDone = false,
        missionClaimed = false,
        moneyMissionDone = false,
        moneyMissionClaimed = false,
        claimedCrate = false,
    })
    weekly.missionsCompleted = tonumber(weekly.missionsCompleted) or 0
    if legacyWeeklyMoneyClaim then
        weekly.moneyMissionClaimed = true
    end
    if weekly.week ~= weekKey() then
        weekly = {
            week = weekKey(),
            minutes = 0,
            moneyEarned = 0,
            missionsCompleted = 0,
            missionDone = false,
            missionClaimed = false,
            moneyMissionDone = false,
            moneyMissionClaimed = false,
            claimedCrate = false,
        }
        meta.dashboard_weekly = weekly
    end

    return meta, daily, weekly
end

local function tickMissionFlags(meta, daily, weekly)
    daily.missionsCompleted = tonumber(daily.missionsCompleted) or 0
    weekly.missionsCompleted = tonumber(weekly.missionsCompleted) or 0
    daily.missionDone = daily.missionsCompleted >= CFG.dailyMissionsRequired
    weekly.missionDone = weekly.missionsCompleted >= CFG.weeklyMissionsRequired
    daily.moneyMissionDone = (tonumber(daily.moneyEarned) or 0) >= CFG.dailyMissionMoney
    weekly.moneyMissionDone = (tonumber(weekly.moneyEarned) or 0) >= CFG.weeklyMissionMoney
    meta.dashboard_daily = daily
    meta.dashboard_weekly = weekly
end

--- Increment daily/weekly mission counters (activity missions for crate gates).
local function recordMissionComplete(src, sourceTag)
    src = tonumber(src)
    if not src then return false end
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return false end
    local meta, daily, weekly = refreshPeriods(Player)
    local wasDaily = daily.missionDone
    local wasWeekly = weekly.missionDone
    daily.missionsCompleted = (tonumber(daily.missionsCompleted) or 0) + 1
    weekly.missionsCompleted = (tonumber(weekly.missionsCompleted) or 0) + 1
    tickMissionFlags(meta, daily, weekly)
    meta.dashboard_missions_done = (tonumber(meta.dashboard_missions_done) or 0) + 1
    saveMeta(Player, meta)
    if daily.missionDone and not wasDaily then
        TriggerClientEvent('QBCore:Notify', src, 'Dienos misijų reikalavimas dėžei atliktas.', 'success')
    elseif weekly.missionDone and not wasWeekly then
        TriggerClientEvent('QBCore:Notify', src, 'Savaitės misijų reikalavimas dėžei atliktas.', 'success')
    end
    if GetResourceState('mrp_dashboard') == 'started' then
        -- refresh open dashboards quietly when payload builder exists
        pcall(function()
            local payload = BuildDashboardPayload(src)
            if payload then
                TriggerClientEvent('mrp_dashboard:client:setData', src, payload)
            end
        end)
    end
    return true, sourceTag
end

exports('RecordMissionComplete', recordMissionComplete)
AddEventHandler('mrp_dashboard:server:missionComplete', function(src, sourceTag)
    recordMissionComplete(src, sourceTag)
end)

local function addPlayMinute(Player)
    local meta, daily, weekly = refreshPeriods(Player)
    meta.dashboard_playtime_minutes = (tonumber(meta.dashboard_playtime_minutes) or 0) + 1
    daily.minutes = (tonumber(daily.minutes) or 0) + 1
    weekly.minutes = (tonumber(weekly.minutes) or 0) + 1
    tickMissionFlags(meta, daily, weekly)
    saveMeta(Player, meta)
end

local function addEarnedMoney(Player, amount)
    amount = math.max(0, math.floor(tonumber(amount) or 0))
    if amount <= 0 then return end
    local meta, daily, weekly = refreshPeriods(Player)
    daily.moneyEarned = (tonumber(daily.moneyEarned) or 0) + amount
    weekly.moneyEarned = (tonumber(weekly.moneyEarned) or 0) + amount
    tickMissionFlags(meta, daily, weekly)
    saveMeta(Player, meta)
end

local function crateCatalog()
    local out = {}
    local order = { 'dienos_deze', 'savaites_deze', 'deze_legali', 'deze_exp', 'deze_nelegali' }
    local kindMap = {
        dienos_deze = 'daily',
        savaites_deze = 'weekly',
        deze_legali = 'legal',
        deze_exp = 'xp',
        deze_nelegali = 'illegal',
    }
    local prices = { deze_legali = 350, deze_exp = 400, deze_nelegali = 550 }
    for _, id in ipairs(order) do
        local def = MrpCrates.Get(id)
        if def then
            local lootPool = {}
            for i, e in ipairs(def.loot or {}) do
                local shared = e.item and QBCore.Shared.Items[e.item]
                lootPool[#lootPool + 1] = {
                    id = id .. '-' .. i,
                    name = e.label or (shared and shared.label) or e.item or 'XP',
                    rarity = e.rarity or 'common',
                    itemName = e.kind == 'xp' and 'xp' or (e.item or 'item'),
                    amount = e.amount or 1,
                    icon = e.icon or '🎁',
                    iconUrl = shared and shared.image and ('nui://qb-inventory/html/images/%s'):format(shared.image) or nil,
                }
            end
            local desc = def.description
            if id == 'dienos_deze' then
                desc = ('Nemokama: %d min playtime + %d misijos šiandien.'):format(
                    CFG.dailyPlayMinutes, CFG.dailyMissionsRequired
                )
            elseif id == 'savaites_deze' then
                desc = ('Nemokama: %d min playtime + %d misijos šią savaitę.'):format(
                    CFG.weeklyPlayMinutes, CFG.weeklyMissionsRequired
                )
            end
            out[#out + 1] = {
                id = id,
                kind = kindMap[id] or 'legal',
                label = def.label,
                description = desc,
                icon = def.icon,
                image = def.image,
                accent = def.accent,
                priceCredits = prices[id],
                lootPool = lootPool,
            }
        end
    end
    return out
end

local function buildMissions(daily, weekly)
    local dProg = math.min(CFG.dailyMissionMoney, tonumber(daily.moneyEarned) or 0)
    local wProg = math.min(CFG.weeklyMissionMoney, tonumber(weekly.moneyEarned) or 0)
    local dMoneyDone = daily.moneyMissionDone == true
        or (tonumber(daily.moneyEarned) or 0) >= CFG.dailyMissionMoney
    local wMoneyDone = weekly.moneyMissionDone == true
        or (tonumber(weekly.moneyEarned) or 0) >= CFG.weeklyMissionMoney
    local dStatus = daily.moneyMissionClaimed and 'claimed'
        or (dMoneyDone and 'completed')
        or 'active'
    local wStatus = weekly.moneyMissionClaimed and 'claimed'
        or (wMoneyDone and 'completed')
        or 'active'
    local dMissions = tonumber(daily.missionsCompleted) or 0
    local wMissions = tonumber(weekly.missionsCompleted) or 0
    local dCrateStatus = daily.missionDone and 'completed' or 'active'
    local wCrateStatus = weekly.missionDone and 'completed' or 'active'
    return {
        {
            id = 'daily_missions',
            period = 'daily',
            title = ('Užbaik %d misijas šiandien'):format(CFG.dailyMissionsRequired),
            progress = math.min(CFG.dailyMissionsRequired, dMissions),
            goal = CFG.dailyMissionsRequired,
            unit = 'mis.',
            rewardXp = 0,
            rewardMoney = 0,
            status = dCrateStatus,
        },
        {
            id = 'daily_earn',
            period = 'daily',
            title = CFG.dailyMissionTitle,
            progress = dProg,
            goal = CFG.dailyMissionMoney,
            unit = '$',
            rewardXp = 150,
            rewardMoney = 500,
            status = dStatus,
        },
        {
            id = 'weekly_missions',
            period = 'weekly',
            title = ('Užbaik %d misijas šią savaitę'):format(CFG.weeklyMissionsRequired),
            progress = math.min(CFG.weeklyMissionsRequired, wMissions),
            goal = CFG.weeklyMissionsRequired,
            unit = 'mis.',
            rewardXp = 0,
            rewardMoney = 0,
            status = wCrateStatus,
        },
        {
            id = 'weekly_earn',
            period = 'weekly',
            title = CFG.weeklyMissionTitle,
            progress = wProg,
            goal = CFG.weeklyMissionMoney,
            unit = '$',
            rewardXp = 500,
            rewardMoney = 2500,
            status = wStatus,
        },
    }
end

local function buildDailyPayload(Player)
    local meta, daily, weekly = refreshPeriods(Player)
    tickMissionFlags(meta, daily, weekly)
    local crates = crateCatalog()
    local day = tonumber(daily.day) or 1
    local days = {}
    for i = 1, 7 do
        days[i] = {
            day = i,
            label = i == 7 and 'MEGA' or 'DĖŽĖ',
            claimed = i < day or (i == day and daily.claimedCrate),
            current = i == day,
            rarityHint = i == 7 and 'legendary' or (i >= 4 and 'rare' or 'common'),
        }
    end

    local dailyPlayOk = (tonumber(daily.minutes) or 0) >= CFG.dailyPlayMinutes
    local weeklyPlayOk = (tonumber(weekly.minutes) or 0) >= CFG.weeklyPlayMinutes
    local dailyMissions = tonumber(daily.missionsCompleted) or 0
    local weeklyMissions = tonumber(weekly.missionsCompleted) or 0
    local dailyMissionOk = dailyMissions >= CFG.dailyMissionsRequired
    local weeklyMissionOk = weeklyMissions >= CFG.weeklyMissionsRequired

    return {
        day = day,
        maxDays = 7,
        streak = tonumber(daily.streak) or 0,
        requiredMinutes = CFG.dailyPlayMinutes,
        playedMinutes = tonumber(daily.minutes) or 0,
        requiredMissions = CFG.dailyMissionsRequired,
        missionsCompleted = dailyMissions,
        canClaim = dailyPlayOk and dailyMissionOk and not daily.claimedCrate,
        claimedToday = daily.claimedCrate == true,
        crateItem = 'dienos_deze',
        crateLabel = 'Dienos dėžė',
        crates = crates,
        lootPool = (crates[1] and crates[1].lootPool) or {},
        days = days,
        weekly = {
            requiredMinutes = CFG.weeklyPlayMinutes,
            playedMinutes = tonumber(weekly.minutes) or 0,
            requiredMissions = CFG.weeklyMissionsRequired,
            missionsCompleted = weeklyMissions,
            missionDone = weeklyMissionOk,
            canClaim = weeklyPlayOk and weeklyMissionOk and not weekly.claimedCrate,
            claimed = weekly.claimedCrate == true,
            crateItem = 'savaites_deze',
            crateLabel = 'Savaitės dėžė',
        },
        requirements = {
            dailyPlay = dailyPlayOk,
            dailyMission = dailyMissionOk,
            weeklyPlay = weeklyPlayOk,
            weeklyMission = weeklyMissionOk,
        },
    }
end

local function formatMoney(n)
    n = math.floor(tonumber(n) or 0)
    if n >= 1000000 then
        return ('$%.1fM'):format(n / 1000000)
    end
    if n >= 1000 then
        return ('$%dK'):format(math.floor(n / 1000))
    end
    return ('$%d'):format(n)
end

local function formatHours(minutes)
    minutes = math.floor(tonumber(minutes) or 0)
    return ('%d H'):format(math.floor(minutes / 60))
end

--- Steam / FiveM display name (QB stores GetPlayerName in players.name). Never RP charinfo / citizenid.
local function steamNameFromRow(row, onlineByCid)
    local cid = row.citizenid
    local sid = cid and onlineByCid and onlineByCid[cid]
    if sid then
        local live = GetPlayerName(sid)
        if live and live ~= '' then return live end
    end
    local name = type(row.name) == 'string' and row.name:gsub('^%s+', ''):gsub('%s+$', '') or ''
    if name ~= '' then return name end
    return 'Žaidėjas'
end

local function buildRankings(src)
    local Player = QBCore.Functions.GetPlayer(src)
    local selfCid = Player and Player.PlayerData.citizenid or ''

    local onlineByCid = {}
    for _, pid in ipairs(GetPlayers()) do
        local sid = tonumber(pid)
        local P = sid and QBCore.Functions.GetPlayer(sid)
        if P and P.PlayerData and P.PlayerData.citizenid then
            onlineByCid[P.PlayerData.citizenid] = sid
        end
    end

    local rows = MySQL.query.await([[
        SELECT citizenid, name, money, metadata
        FROM players
        LIMIT 500
    ]]) or {}

    local playtime, money, missions, rppass, events = {}, {}, {}, {}, {}

    for _, row in ipairs(rows) do
        local okM, moneyT = pcall(json.decode, row.money or '{}')
        local okD, meta = pcall(json.decode, row.metadata or '{}')
        moneyT = okM and moneyT or {}
        meta = okD and meta or {}
        local name = steamNameFromRow(row, onlineByCid)
        local cid = row.citizenid
        local cash = tonumber(moneyT.cash) or 0
        local bank = tonumber(moneyT.bank) or 0
        local totalMoney = cash + bank
        local mins = tonumber(meta.dashboard_playtime_minutes) or 0
        local missionsDone = tonumber(meta.dashboard_missions_done) or 0
        local xp = tonumber(meta.dashboard_xp) or 0
        local level = math.min(100, 1 + math.floor(xp / 1000))
        local wins = tonumber(meta.dashboard_events_won) or 0
        local isSelf = cid == selfCid

        playtime[#playtime + 1] = { cid = cid, name = name, sort = mins, value = formatHours(mins), isSelf = isSelf }
        money[#money + 1] = { cid = cid, name = name, sort = totalMoney, value = formatMoney(totalMoney), isSelf = isSelf }
        missions[#missions + 1] = { cid = cid, name = name, sort = missionsDone, value = tostring(missionsDone), isSelf = isSelf }
        rppass[#rppass + 1] = { cid = cid, name = name, sort = level, value = ('LVL %d'):format(level), isSelf = isSelf }
        events[#events + 1] = { cid = cid, name = name, sort = wins, value = ('%d wins'):format(wins), isSelf = isSelf }
    end

    local function finalize(list)
        table.sort(list, function(a, b)
            if a.sort == b.sort then return tostring(a.name) < tostring(b.name) end
            return a.sort > b.sort
        end)
        local selfEntry = nil
        local selfRank = nil
        for i, e in ipairs(list) do
            e.rank = i
            if e.isSelf then
                selfRank = i
                selfEntry = {
                    rank = i,
                    name = e.name,
                    value = e.value,
                    isSelf = true,
                }
            end
        end
        local top = {}
        for i = 1, math.min(10, #list) do
            local e = list[i]
            top[i] = {
                rank = e.rank,
                name = e.name,
                value = e.value,
                isSelf = e.isSelf,
            }
        end
        if selfEntry and selfRank and selfRank > 10 then
            top[#top + 1] = {
                rank = selfEntry.rank,
                name = selfEntry.name,
                value = selfEntry.value,
                isSelf = true,
            }
        end
        return top
    end

    local function ensureSelf(list, valueFn, sortFn)
        if not Player then return end
        for _, e in ipairs(list) do
            if e.isSelf then return end
        end
        local meta = getMeta(Player)
        local name = GetPlayerName(src) or 'Žaidėjas'
        local sort = sortFn(meta, Player)
        list[#list + 1] = {
            cid = selfCid,
            name = name,
            sort = sort,
            value = valueFn(sort, meta, Player),
            isSelf = true,
        }
    end

    ensureSelf(playtime, function(sort) return formatHours(sort) end, function(meta)
        return tonumber(meta.dashboard_playtime_minutes) or 0
    end)
    ensureSelf(money, function(sort) return formatMoney(sort) end, function(_, P)
        local m = P.PlayerData.money or {}
        return (tonumber(m.cash) or 0) + (tonumber(m.bank) or 0)
    end)
    ensureSelf(missions, function(sort) return tostring(sort) end, function(meta)
        return tonumber(meta.dashboard_missions_done) or 0
    end)
    ensureSelf(rppass, function(sort) return ('LVL %d'):format(sort) end, function(meta)
        local xp = tonumber(meta.dashboard_xp) or 0
        return math.min(100, 1 + math.floor(xp / 1000))
    end)
    ensureSelf(events, function(sort) return ('%d wins'):format(sort) end, function(meta)
        return tonumber(meta.dashboard_events_won) or 0
    end)

    return {
        playtime = finalize(playtime),
        money = finalize(money),
        missions = finalize(missions),
        rppass = finalize(rppass),
        events = finalize(events),
    }
end

local function buildPlayerPatch(src, Player)
    local meta = getMeta(Player)
    local totalMin = tonumber(meta.dashboard_playtime_minutes) or 0
    local ci = Player.PlayerData.charinfo or {}
    local name = ((ci.firstname or '') .. ' ' .. (ci.lastname or '')):gsub('^%s+', ''):gsub('%s+$', '')
    local job = Player.PlayerData.job and Player.PlayerData.job.label or 'Civilian'
    local money = Player.PlayerData.money or {}
    local vip = tostring(meta.dashboard_vip or 'NONE'):upper()
    if vip ~= 'SILVER' and vip ~= 'GOLD' and vip ~= 'DIAMOND' then vip = 'NONE' end
    return {
        steamName = GetPlayerName(src) or name,
        characterName = name ~= '' and name or (GetPlayerName(src) or 'Žaidėjas'),
        id = src,
        citizenid = Player.PlayerData.citizenid,
        credits = tonumber(money.credits) or 0,
        cash = tonumber(money.cash) or 0,
        bank = tonumber(money.bank) or 0,
        job = job,
        vip = vip,
        vipDays = tonumber(meta.dashboard_vip_days) or 0,
        playtimeHours = math.floor(totalMin / 60),
        playtimeMinutes = totalMin % 60,
        memberSince = tostring(ci.birthdate or '—'),
    }
end

function BuildDashboardPayload(src)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return nil end
    local meta, daily, weekly = refreshPeriods(Player)
    tickMissionFlags(meta, daily, weekly)
    saveMeta(Player, meta)

    local serverPlayers = #GetPlayers()
    local maxPlayers = GetConvarInt('sv_maxclients', 128)

    return {
        player = buildPlayerPatch(src, Player),
        server = {
            online = true,
            players = serverPlayers,
            maxPlayers = maxPlayers,
            police = 0,
            ems = 0,
            uptime = '—',
        },
        missions = buildMissions(daily, weekly),
        daily = buildDailyPayload(Player),
        rankings = buildRankings(src),
    }
end

QBCore.Functions.CreateCallback('mrp_dashboard:server:getData', function(source, cb)
    cb(BuildDashboardPayload(source) or {})
end)

RegisterNetEvent('mrp_dashboard:server:claimDailyCrate', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    local meta, daily = refreshPeriods(Player)
    tickMissionFlags(meta, daily, meta.dashboard_weekly)
    if daily.claimedCrate then
        TriggerClientEvent('QBCore:Notify', src, 'Šiandienos dėžę jau pasiėmei.', 'error')
        return
    end
    if (tonumber(daily.minutes) or 0) < CFG.dailyPlayMinutes then
        TriggerClientEvent('QBCore:Notify', src, ('Reikia %d min playtime.'):format(CFG.dailyPlayMinutes), 'error')
        return
    end
    local dailyMissions = tonumber(daily.missionsCompleted) or 0
    if dailyMissions < CFG.dailyMissionsRequired then
        TriggerClientEvent(
            'QBCore:Notify',
            src,
            ('Reikia %d/%d misijų šiandien.'):format(dailyMissions, CFG.dailyMissionsRequired),
            'error'
        )
        return
    end
    if not Player.Functions.AddItem('dienos_deze', 1) then
        TriggerClientEvent('QBCore:Notify', src, 'Inventorius pilnas.', 'error')
        return
    end
    daily.claimedCrate = true
    meta.dashboard_daily = daily
    saveMeta(Player, meta)
    TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items['dienos_deze'], 'add')
    TriggerClientEvent('QBCore:Notify', src, 'Gavai Dienos dėžę. Atidaryk inventoriuje.', 'success')
    TriggerClientEvent('mrp_dashboard:client:setData', src, BuildDashboardPayload(src))
end)

RegisterNetEvent('mrp_dashboard:server:claimWeeklyCrate', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    local meta, _, weekly = refreshPeriods(Player)
    tickMissionFlags(meta, meta.dashboard_daily, weekly)
    if weekly.claimedCrate then
        TriggerClientEvent('QBCore:Notify', src, 'Šios savaitės dėžę jau pasiėmei.', 'error')
        return
    end
    if (tonumber(weekly.minutes) or 0) < CFG.weeklyPlayMinutes then
        TriggerClientEvent('QBCore:Notify', src, ('Reikia %d min savaitės playtime.'):format(CFG.weeklyPlayMinutes), 'error')
        return
    end
    local weeklyMissions = tonumber(weekly.missionsCompleted) or 0
    if weeklyMissions < CFG.weeklyMissionsRequired then
        TriggerClientEvent(
            'QBCore:Notify',
            src,
            ('Reikia %d/%d misijų šią savaitę.'):format(weeklyMissions, CFG.weeklyMissionsRequired),
            'error'
        )
        return
    end
    if not Player.Functions.AddItem('savaites_deze', 1) then
        TriggerClientEvent('QBCore:Notify', src, 'Inventorius pilnas.', 'error')
        return
    end
    weekly.claimedCrate = true
    meta.dashboard_weekly = weekly
    saveMeta(Player, meta)
    TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items['savaites_deze'], 'add')
    TriggerClientEvent('QBCore:Notify', src, 'Gavai Savaitės dėžę. Atidaryk inventoriuje.', 'success')
    TriggerClientEvent('mrp_dashboard:client:setData', src, BuildDashboardPayload(src))
end)

RegisterNetEvent('mrp_dashboard:server:claimMission', function(missionId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    missionId = tostring(missionId or '')
    local meta, daily, weekly = refreshPeriods(Player)
    tickMissionFlags(meta, daily, weekly)

    local rewardXp, rewardMoney = 0, 0
    if missionId == 'daily_earn' then
        local done = daily.moneyMissionDone == true
            or (tonumber(daily.moneyEarned) or 0) >= CFG.dailyMissionMoney
        if not done or daily.moneyMissionClaimed then
            TriggerClientEvent('QBCore:Notify', src, 'Misija dar nebaigta arba jau atsiimta.', 'error')
            return
        end
        daily.moneyMissionClaimed = true
        daily.missionClaimed = true
        rewardXp, rewardMoney = 150, 500
        meta.dashboard_daily = daily
    elseif missionId == 'weekly_earn' then
        local done = weekly.moneyMissionDone == true
            or (tonumber(weekly.moneyEarned) or 0) >= CFG.weeklyMissionMoney
        if not done or weekly.moneyMissionClaimed then
            TriggerClientEvent('QBCore:Notify', src, 'Misija dar nebaigta arba jau atsiimta.', 'error')
            return
        end
        weekly.moneyMissionClaimed = true
        weekly.missionClaimed = true
        rewardXp, rewardMoney = 500, 2500
        meta.dashboard_weekly = weekly
    elseif missionId == 'daily_missions' or missionId == 'weekly_missions' then
        TriggerClientEvent('QBCore:Notify', src, 'Ši misija atrakiną dėžę — claim nereikalingas.', 'primary')
        return
    else
        return
    end

    meta.dashboard_xp = (tonumber(meta.dashboard_xp) or 0) + rewardXp
    saveMeta(Player, meta)
    if rewardMoney > 0 then
        Player.Functions.AddMoney('cash', rewardMoney, 'dashboard-mission')
    end
    TriggerClientEvent('QBCore:Notify', src, ('Misija: +%d XP, +$%d'):format(rewardXp, rewardMoney), 'success')
    TriggerClientEvent('mrp_dashboard:client:setData', src, BuildDashboardPayload(src))
end)

AddEventHandler('QBCore:Server:OnMoneyChange', function(src, moneytype, amount, action)
    if action ~= 'add' then return end
    if moneytype ~= 'cash' and moneytype ~= 'bank' then return end
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    addEarnedMoney(Player, amount)
end)

CreateThread(function()
    while true do
        Wait(60000)
        for _, id in ipairs(GetPlayers()) do
            local src = tonumber(id)
            local Player = src and QBCore.Functions.GetPlayer(src)
            if Player then
                addPlayMinute(Player)
            end
        end
    end
end)

-- Remove free claim stub from crates.lua path — handled here
print('^2[mrp_dashboard]^7 progress + rankings ready')
