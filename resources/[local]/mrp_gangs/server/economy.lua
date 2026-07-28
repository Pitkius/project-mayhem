local QBCore = GangCore.QBCore

GangEconomy = GangEconomy or {}

local function weightedPick(pool)
    local total = 0
    for _, entry in ipairs(pool or {}) do
        total = total + math.max(0, tonumber(entry.weight) or 0)
    end
    if total <= 0 then return nil end

    local roll = math.random() * total
    local cursor = 0
    for _, entry in ipairs(pool) do
        cursor = cursor + math.max(0, tonumber(entry.weight) or 0)
        if roll <= cursor then return GangUtils.Copy(entry) end
    end
    return GangUtils.Copy(pool[#pool])
end

local function reserveQuota(quotaKey)
    local definition = Config.RestrictedSupply and Config.RestrictedSupply[quotaKey]
    if not definition then return false end

    MySQL.update.await([[
        UPDATE mrp_gang_supply_quota
        SET window_started_at = CURRENT_TIMESTAMP,
            window_days = ?,
            global_cap = ?,
            issued_count = 0
        WHERE quota_key = ?
          AND DATE_ADD(window_started_at, INTERVAL window_days DAY) <= CURRENT_TIMESTAMP
    ]], {
        tonumber(definition.rollingDays) or 7,
        tonumber(definition.globalCap) or 0,
        quotaKey,
    })

    local affected = MySQL.update.await([[
        UPDATE mrp_gang_supply_quota
        SET issued_count = issued_count + 1
        WHERE quota_key = ?
          AND issued_count < global_cap
          AND DATE_ADD(window_started_at, INTERVAL window_days DAY) > CURRENT_TIMESTAMP
    ]], { quotaKey })
    return (tonumber(affected) or 0) > 0
end

local function tierForRoll(difficulty)
    local roll = math.random(1, 1000)
    if difficulty == 'extreme' then
        if roll <= 95 then return 'rare' end
        if roll <= 450 then return 'uncommon' end
    elseif difficulty == 'hard' then
        if roll <= 58 then return 'rare' end
        if roll <= 340 then return 'uncommon' end
    elseif difficulty == 'medium' then
        if roll <= 20 then return 'rare' end
        if roll <= 250 then return 'uncommon' end
    else
        if roll <= 100 then return 'uncommon' end
    end
    return 'common'
end

local function wornQualityFor(definition, difficulty)
    local range = definition and definition.wornQuality
    if not range then
        range = (Config.CorpseLoot and Config.CorpseLoot.pistolQuality and Config.CorpseLoot.pistolQuality[difficulty])
            or { min = 15, max = 45 }
    end
    local lo = math.floor(tonumber(range.min) or 15)
    local hi = math.floor(tonumber(range.max) or 45)
    if hi < lo then hi = lo end
    return math.random(lo, hi) + 0.0
end

local function isWeaponItem(itemName)
    itemName = tostring(itemName or '')
    return itemName:find('^weapon_', 1) ~= nil
end

local function restrictedRoll(difficulty)
    if difficulty ~= 'hard' and difficulty ~= 'extreme' then return nil end
    for quotaKey, definition in pairs(Config.RestrictedSupply or {}) do
        local chanceKey = difficulty .. 'ChancePerTenThousand'
        local chance = tonumber(definition[chanceKey]) or 0
        if chance > 0 and math.random(1, 10000) <= chance then
            if reserveQuota(quotaKey) then
                local reward = {
                    item = definition.item,
                    amount = 1,
                    tier = 'restricted',
                    quotaKey = quotaKey,
                }
                if isWeaponItem(definition.item) then
                    reward.quality = wornQualityFor(definition, difficulty)
                end
                return reward
            end
            local substitute = weightedPick(Config.Loot[definition.fallbackPool or 'rare'])
            if substitute then
                substitute.amount = math.random(tonumber(substitute.min) or 1, tonumber(substitute.max) or 1)
                substitute.tier = 'quota_substitute'
                substitute.quotaKey = quotaKey
            end
            return substitute
        end
    end
    return nil
end

function GangEconomy.CalculateReward(mission, difficulty, partySize, performance)
    local difficultyConfig = Config.Difficulties[difficulty]
    if not difficultyConfig then return 0 end
    partySize = GangUtils.Clamp(partySize, 1, Config.MaxMissionParty or 6)
    performance = GangUtils.Clamp(
        performance or 1.0,
        Config.Reward.performanceMin or 0.75,
        Config.Reward.performanceMax or 1.15
    )
    local partyMultiplier = math.min(
        Config.Reward.maxPartyMultiplier or 2.10,
        1.0 + ((partySize - 1) * (Config.Reward.partyGrowthPerMember or 0.22))
    )
    local economyScalar = GangUtils.Clamp(
        Config.Reward.economyScalar or 1.0,
        Config.Reward.economyScalarMin or 0.85,
        Config.Reward.economyScalarMax or 1.15
    )
    return GangUtils.Round(
        (tonumber(mission.baseReward) or 0)
        * (tonumber(difficultyConfig.rewardMultiplier) or 1.0)
        * partyMultiplier
        * performance
        * economyScalar
    )
end

function GangEconomy.RollLoot(difficulty)
    local difficultyConfig = Config.Difficulties[difficulty]
    local rewards = {}
    for _ = 1, tonumber(difficultyConfig and difficultyConfig.lootRolls) or 2 do
        local tier = tierForRoll(difficulty)
        local entry = weightedPick(Config.Loot[tier])
        if entry then
            entry.amount = math.random(tonumber(entry.min) or 1, tonumber(entry.max) or 1)
            entry.tier = tier
            rewards[#rewards + 1] = entry
        end
    end
    local restricted = restrictedRoll(difficulty)
    if restricted then rewards[#rewards + 1] = restricted end
    return rewards
end

local function insertRewardLedger(run, settlementKey, recipientType, recipientId, rewardType, rewardKey, amount, metadata)
    local inserted = MySQL.insert.await([[
        INSERT IGNORE INTO mrp_gang_mission_rewards
            (run_id, settlement_key, recipient_type, recipient_id, reward_type, reward_key, amount, metadata_json)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    ]], {
        run.dbId,
        settlementKey,
        recipientType,
        tostring(recipientId),
        rewardType,
        tostring(rewardKey),
        tonumber(amount) or 0,
        metadata and json.encode(metadata) or nil,
    })
    return tonumber(inserted) or 0
end

local function markDelivered(rewardId)
    if tonumber(rewardId) and tonumber(rewardId) > 0 then
        MySQL.update.await('UPDATE mrp_gang_mission_rewards SET delivered_at = CURRENT_TIMESTAMP WHERE id = ?', {
            tonumber(rewardId),
        })
    end
end

local function grantCash(run, participant, amount, suffix)
    amount = math.max(0, GangUtils.Round(amount))
    if amount <= 0 then return false end
    local settlementKey = ('run:%s:player:%s:cash:%s'):format(run.dbId, participant.citizenid, suffix)
    local rewardId = insertRewardLedger(run, settlementKey, 'player', participant.citizenid, 'cash', 'cash', amount)
    if rewardId <= 0 then return false end
    local player = QBCore.Functions.GetPlayerByCitizenId(participant.citizenid)
    if player then
        player.Functions.AddMoney('cash', amount, ('gang-mission-%s'):format(run.token))
        markDelivered(rewardId)
    end
    return true
end

local function grantLoot(run, participant, reward, index)
    local amount = math.max(1, tonumber(reward.amount) or 1)
    local itemName = reward.item
    local settlementKey = ('run:%s:player:%s:loot:%s'):format(run.dbId, participant.citizenid, index)
    local player = QBCore.Functions.GetPlayerByCitizenId(participant.citizenid)
    local itemInfo = reward.info and GangUtils.Copy(reward.info) or nil

    if reward.money == 'markedbills' and QBCore.Shared.Items.markedbills then
        itemName = 'markedbills'
        itemInfo = { worth = tonumber(reward.amount) or 0 }
        amount = 1
    end

    if itemName and isWeaponItem(itemName) then
        itemInfo = itemInfo or {}
        if itemInfo.quality == nil then
            itemInfo.quality = tonumber(reward.quality) or wornQualityFor(nil, run.difficulty)
        end
    end

    if itemName and QBCore.Shared.Items[itemName] then
        local rewardType = reward.tier == 'quota_substitute' and 'substitute' or 'item'
        local rewardId = insertRewardLedger(run, settlementKey, 'player', participant.citizenid, rewardType, itemName, amount, {
            tier = reward.tier,
            quotaKey = reward.quotaKey,
            info = itemInfo,
        })
        if rewardId <= 0 then return false end
        if player then
            local added = player.Functions.AddItem(itemName, amount, false, itemInfo, ('gang-mission-%s'):format(run.token))
            if added then
                TriggerClientEvent('inventory:client:ItemBox', player.PlayerData.source, QBCore.Shared.Items[itemName], 'add', amount)
                markDelivered(rewardId)
                return true
            end
        end
        return true
    end

    local fallbackCash = tonumber(reward.fallbackCash) or math.max(150, amount * 100)
    return grantCash(run, participant, fallbackCash, ('loot-fallback-%s'):format(index))
end

local function chanceFor(tableOrNil, difficulty, defaultValue)
    if type(tableOrNil) ~= 'table' then return tonumber(defaultValue) or 0 end
    return tonumber(tableOrNil[difficulty] or tableOrNil.easy or defaultValue) or 0
end

function GangEconomy.RollCorpseLoot(difficulty, weaponName, archetype)
    local cfg = Config.CorpseLoot or {}
    difficulty = tostring(difficulty or 'easy')
    local drops = {}

    if math.random(1, 100) <= chanceFor(cfg.cashChance, difficulty, 70) then
        local band = (cfg.cashWorth and cfg.cashWorth[difficulty]) or { min = 40, max = 100 }
        local worth = math.random(tonumber(band.min) or 40, tonumber(band.max) or 100)
        drops[#drops + 1] = {
            money = 'markedbills',
            amount = worth,
            tier = 'corpse_cash',
        }
    end

    if math.random(1, 100) <= chanceFor(cfg.ammoChance, difficulty, 35) then
        local ammo = cfg.ammo or { item = 'pistol_ammo', min = 1, max = 2 }
        drops[#drops + 1] = {
            item = ammo.item or 'pistol_ammo',
            amount = math.random(tonumber(ammo.min) or 1, tonumber(ammo.max) or 2),
            tier = 'corpse_ammo',
            fallbackCash = 120,
        }
    end

    if math.random(1, 100) <= chanceFor(cfg.drugChance, difficulty, 2) then
        local pool = cfg.drugs or { 'weed_bag', 'cokebaggy' }
        local pick = pool[math.random(1, #pool)]
        if pick then
            drops[#drops + 1] = {
                item = pick,
                amount = 1,
                tier = 'corpse_drug',
                fallbackCash = 200,
            }
        end
    end

    local pistolMap = cfg.pistolWeapons or {}
    local weaponKey = tostring(weaponName or ''):upper()
    local pistolItem = pistolMap[weaponKey]
    if pistolItem and math.random(1, 100) <= chanceFor(cfg.pistolChance, difficulty, 0) then
        local q = (cfg.pistolQuality and cfg.pistolQuality[difficulty]) or { min = 15, max = 40 }
        drops[#drops + 1] = {
            item = pistolItem,
            amount = 1,
            tier = 'corpse_pistol',
            quality = math.random(tonumber(q.min) or 15, tonumber(q.max) or 40) + 0.0,
            fallbackCash = 400,
            archetype = archetype,
        }
    end

    if #drops == 0 then
        drops[1] = {
            money = 'markedbills',
            amount = math.random(20, 55),
            tier = 'corpse_empty',
        }
    end
    return drops
end

function GangEconomy.GrantCorpseLoot(source, run, drops)
    local player = QBCore.Functions.GetPlayer(source)
    if not player then return false, 'player_missing' end
    local granted = {}
    for index, reward in ipairs(drops or {}) do
        local amount = math.max(1, tonumber(reward.amount) or 1)
        local itemName = reward.item
        local itemInfo = reward.info and GangUtils.Copy(reward.info) or nil

        if reward.money == 'markedbills' and QBCore.Shared.Items.markedbills then
            itemName = 'markedbills'
            itemInfo = { worth = tonumber(reward.amount) or 0 }
            amount = 1
        elseif itemName and isWeaponItem(itemName) then
            itemInfo = itemInfo or {}
            itemInfo.quality = tonumber(reward.quality) or wornQualityFor(nil, run.difficulty)
        end

        if itemName and QBCore.Shared.Items[itemName] then
            local added = player.Functions.AddItem(itemName, amount, false, itemInfo, ('gang-corpse-%s'):format(run.token))
            if added then
                TriggerClientEvent('inventory:client:ItemBox', source, QBCore.Shared.Items[itemName], 'add', amount)
                granted[#granted + 1] = { item = itemName, amount = amount, quality = itemInfo and itemInfo.quality, worth = itemInfo and itemInfo.worth }
            end
        end
    end
    return true, granted
end

function GangEconomy.SettleMission(run, mission, participants, performance)
    if run.settled then return false, 'already_settled' end
    if #participants == 0 then return false, 'no_participants' end

    local totalReward = GangEconomy.CalculateReward(mission, run.difficulty, #participants, performance)
    local crewPool = GangUtils.Round(totalReward * (Config.Reward.crewShare or 0.70))
    local treasury = GangUtils.Round(totalReward * (Config.Reward.gangTreasuryShare or 0.20))
    local performancePool = math.max(0, totalReward - crewPool - treasury)
    local equalCash = math.floor(crewPool / #participants)

    local totalContribution = 0
    for _, participant in ipairs(participants) do
        participant.rewardWeight = math.max(1, tonumber(participant.objectiveActions) or 0)
        totalContribution = totalContribution + participant.rewardWeight
    end

    for _, participant in ipairs(participants) do
        local performanceCash = GangUtils.Round(performancePool * (participant.rewardWeight / totalContribution))
        grantCash(run, participant, equalCash + performanceCash, 'crew')
    end

    local treasuryKey = ('run:%s:gang:%s:treasury'):format(run.dbId, run.gangId)
    local treasuryRewardId = insertRewardLedger(run, treasuryKey, 'gang', run.gangId, 'treasury', 'treasury', treasury)
    if treasuryRewardId > 0 then
        MySQL.update.await('UPDATE mrp_gangs_v2 SET treasury = treasury + ? WHERE id = ?', { treasury, run.gangId })
        markDelivered(treasuryRewardId)
    end

    local reputation = GangUtils.Round((tonumber(mission.baseReputation) or 0) * (Config.Difficulties[run.difficulty].rewardMultiplier or 1.0))
    local reputationKey = ('run:%s:gang:%s:reputation'):format(run.dbId, run.gangId)
    local reputationRewardId = insertRewardLedger(run, reputationKey, 'gang', run.gangId, 'reputation', 'reputation', reputation)
    if reputationRewardId > 0 then
        if GangCore.AddReputation(run.gangId, reputation, 'mission_completed', 'mission_run', run.dbId, nil) then
            markDelivered(reputationRewardId)
        end
    end

    local loot = GangEconomy.RollLoot(run.difficulty)
    for index, reward in ipairs(loot) do
        local recipient = participants[((index - 1) % #participants) + 1]
        grantLoot(run, recipient, reward, index)
    end

    run.settled = true
    return true, {
        totalReward = totalReward,
        crewCashEach = equalCash,
        treasury = treasury,
        reputation = reputation,
        loot = loot,
    }
end

function GangEconomy.DeliverPending(source)
    local player = QBCore.Functions.GetPlayer(source)
    if not player then return 0 end
    local citizenid = player.PlayerData.citizenid
    local pending = MySQL.query.await([[
        SELECT id, reward_type, reward_key, amount, metadata_json
        FROM mrp_gang_mission_rewards
        WHERE recipient_type = 'player'
          AND recipient_id = ?
          AND delivered_at IS NULL
        ORDER BY id ASC
        LIMIT 50
    ]], { citizenid }) or {}

    local delivered = 0
    for _, reward in ipairs(pending) do
        local success = false
        if reward.reward_type == 'cash' then
            player.Functions.AddMoney('cash', tonumber(reward.amount) or 0, 'gang-mission-pending')
            success = true
        elseif (reward.reward_type == 'item' or reward.reward_type == 'substitute')
            and QBCore.Shared.Items[reward.reward_key] then
            local metadata = reward.metadata_json and json.decode(reward.metadata_json) or {}
            success = player.Functions.AddItem(
                reward.reward_key,
                tonumber(reward.amount) or 1,
                false,
                metadata and metadata.info or nil,
                'gang-mission-pending'
            )
            if success then
                TriggerClientEvent(
                    'inventory:client:ItemBox',
                    source,
                    QBCore.Shared.Items[reward.reward_key],
                    'add',
                    tonumber(reward.amount) or 1
                )
            end
        end
        if success then
            markDelivered(reward.id)
            delivered = delivered + 1
        end
    end
    return delivered
end

AddEventHandler('QBCore:Server:PlayerLoaded', function(player)
    local source = player and player.PlayerData and player.PlayerData.source
    if not source then return end
    SetTimeout(3000, function()
        local count = GangEconomy.DeliverPending(source)
        if count > 0 then GangCore.Notify(source, ('Pristatyti %s neatsiimti misijų apdovanojimai.'):format(count), 'success') end
    end)
end)
