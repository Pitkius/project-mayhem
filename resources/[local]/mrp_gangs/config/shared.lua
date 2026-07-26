Config = Config or {}

Config.Debug = false
Config.TabletItem = 'gang_tablet'
Config.MaxMissionParty = 6
Config.PartyInviteRadius = 25.0
Config.MissionStartRateLimitSec = 5
Config.ReconnectGraceSec = 180
Config.MissionReservationSec = 300
Config.MissionBucketBase = 31000
Config.MaxConcurrentMissionRuns = 8
Config.MaxConcurrentRunPerGang = 1

Config.GangTypes = {
    street = { label = 'Street Gang' },
    cartel = { label = 'Cartel' },
    mafia = { label = 'Mafia' },
    biker = { label = 'Biker Club' },
    racing = { label = 'Racing Crew' },
}

Config.MissionRoles = {
    leader = { label = 'Vadovas' },
    scout = { label = 'Žvalgas / Hackeris' },
    breacher = { label = 'Breacheris' },
    driver = { label = 'Vairuotojas' },
    muscle = { label = 'Kovotojas' },
    support = { label = 'Support' },
}

Config.Difficulties = {
    easy = {
        label = 'Easy',
        recommendedMin = 1,
        recommendedMax = 2,
        rewardMultiplier = 1.00,
        threatBudget = 100,
        maxActiveNpc = 6,
        lootRolls = 2,
        setupCost = 0,
        minDurationSec = 180,
        dispatchChance = 15,
    },
    medium = {
        label = 'Medium',
        recommendedMin = 2,
        recommendedMax = 4,
        rewardMultiplier = 1.45,
        threatBudget = 170,
        maxActiveNpc = 9,
        lootRolls = 3,
        setupCost = 500,
        minDurationSec = 360,
        dispatchChance = 32,
    },
    hard = {
        label = 'Hard',
        recommendedMin = 3,
        recommendedMax = 6,
        rewardMultiplier = 2.10,
        threatBudget = 260,
        maxActiveNpc = 12,
        lootRolls = 4,
        setupCost = 1500,
        minDurationSec = 600,
        dispatchChance = 55,
    },
    extreme = {
        label = 'Extreme',
        recommendedMin = 4,
        recommendedMax = 6,
        rewardMultiplier = 3.00,
        threatBudget = 380,
        maxActiveNpc = 12,
        lootRolls = 5,
        setupCost = 3500,
        minDurationSec = 900,
        dispatchChance = 80,
    },
}

Config.Reward = {
    partyGrowthPerMember = 0.22,
    maxPartyMultiplier = 2.10,
    crewShare = 0.70,
    gangTreasuryShare = 0.20,
    performanceShare = 0.10,
    minimumParticipation = 0.60,
    performanceMin = 0.75,
    performanceMax = 1.15,
    economyScalar = 1.0,
    economyScalarMin = 0.85,
    economyScalarMax = 1.15,
}

Config.Encounter = {
    healthMultiplierMax = 1.15,
    partyThreatGrowth = 0.42,
    threatMultiplierMax = 2.10,
    exteriorActiveNpcCap = 16,
    interiorActiveNpcCap = 12,
    reinforcementDelaySec = 20,
    corpseCleanupSec = 45,
    defaultModels = {
        'g_m_y_mexgoon_01',
        'g_m_y_mexgoon_02',
        'g_m_y_lost_01',
        'g_m_y_lost_02',
        'g_m_y_ballaeast_01',
        'g_m_y_famca_01',
    },
    archetypes = {
        lookout = { cost = 12, armor = 0, weapon = 'WEAPON_PISTOL', accuracy = 22 },
        patrol = { cost = 16, armor = 0, weapon = 'WEAPON_COMBATPISTOL', accuracy = 28 },
        guard = { cost = 22, armor = 20, weapon = 'WEAPON_MICROSMG', accuracy = 34 },
        rusher = { cost = 25, armor = 10, weapon = 'WEAPON_SAWNOFFSHOTGUN', accuracy = 30 },
        suppressor = { cost = 32, armor = 35, weapon = 'WEAPON_SMG', accuracy = 38 },
        marksman = { cost = 38, armor = 15, weapon = 'WEAPON_MARKSMANRIFLE', accuracy = 45 },
        armored = { cost = 44, armor = 75, weapon = 'WEAPON_COMBATPDW', accuracy = 40 },
        commander = { cost = 55, armor = 100, weapon = 'WEAPON_CARBINERIFLE', accuracy = 48 },
    },
}

Config.Loot = {
    common = {
        { item = 'metalscrap', weight = 28, min = 1, max = 3, fallbackCash = 120 },
        { item = 'plastic', weight = 25, min = 1, max = 3, fallbackCash = 100 },
        { item = 'steel', weight = 20, min = 1, max = 2, fallbackCash = 160 },
        { item = 'pistol_ammo', weight = 12, min = 1, max = 2, fallbackCash = 180 },
        { item = 'electronickit', weight = 10, min = 1, max = 1, fallbackCash = 250 },
        { money = 'markedbills', weight = 5, min = 250, max = 550 },
    },
    uncommon = {
        { item = 'lockpick', weight = 30, min = 1, max = 2, fallbackCash = 300 },
        { item = 'radio', weight = 15, min = 1, max = 1, fallbackCash = 500 },
        { item = 'armor', weight = 18, min = 1, max = 1, fallbackCash = 650 },
        { item = 'gunpowder', weight = 22, min = 1, max = 2, fallbackCash = 300 },
        { item = 'weapon_part', weight = 15, min = 1, max = 1, fallbackCash = 700 },
    },
    rare = {
        { item = 'blueprint_fragment', weight = 45, min = 1, max = 1, fallbackCash = 900 },
        { item = 'weapon_part', weight = 35, min = 1, max = 2, fallbackCash = 1000 },
        { item = 'crafting_recipe', weight = 20, min = 1, max = 1, fallbackCash = 1200 },
    },
}

Config.RestrictedSupply = {
    pistol = {
        item = 'weapon_pistol',
        rollingDays = 7,
        globalCap = 2,
        hardChancePerTenThousand = 20,
        extremeChancePerTenThousand = 50,
        fallbackPool = 'rare',
    },
    automatic_component = {
        item = 'blueprint_fragment',
        rollingDays = 14,
        globalCap = 3,
        hardChancePerTenThousand = 35,
        extremeChancePerTenThousand = 100,
        fallbackPool = 'rare',
    },
}

Config.AdminPermissions = { 'admin', 'god' }
