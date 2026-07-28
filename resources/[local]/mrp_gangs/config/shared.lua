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

-- Outdoor collect/search can be contested by rival gangs in the open world.
-- No global alerts/blips — rivals must find the site themselves; UI unlocks only in discoveryRadius.
Config.MissionContest = {
    enabled = true,
    radius = 55.0,
    discoveryRadius = 70.0,
    stealCashMultiplier = 0.65,
    stealReputation = 10,
    rivalDurationBonusMs = 2000,
    contestablePhaseTypes = {
        collect = true,
        search = true,
    },
}

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
        -- Easy: 1–2 melee thugs only (no gunfight army).
        threatBudget = 36,
        maxActiveNpc = 2,
        minNpc = 1,
        lootRolls = 2,
        setupCost = 0,
        minDurationSec = 180,
        dispatchChance = 8,
        meleeOnly = true,
    },
    medium = {
        label = 'Medium',
        recommendedMin = 2,
        recommendedMax = 4,
        rewardMultiplier = 1.45,
        threatBudget = 170,
        maxActiveNpc = 9,
        minNpc = 3,
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
        minNpc = 4,
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
        minNpc = 5,
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
    -- Fallback only; live spawns pick one gang pool per wave (never mixed).
    defaultModels = {
        'g_m_y_mexgoon_01',
        'g_m_y_mexgoon_02',
        'g_m_y_mexgoon_03',
    },
    -- One gang identity per encounter wave — all NPCs share the same pool.
    gangModelPools = {
        vagos = {
            'g_m_y_mexgoon_01',
            'g_m_y_mexgoon_02',
            'g_m_y_mexgoon_03',
        },
        ballas = {
            'g_m_y_ballaeast_01',
            'g_m_y_ballaorig_01',
            'g_m_y_ballasout_01',
        },
        families = {
            'g_m_y_famca_01',
            'g_m_y_famdnf_01',
            'g_m_y_famfor_01',
        },
    },
    archetypes = {
        -- Easy melee thugs (cold weapons only).
        thug = { cost = 14, armor = 0, weapon = 'WEAPON_BAT', accuracy = 18, melee = true },
        cutter = { cost = 16, armor = 0, weapon = 'WEAPON_KNIFE', accuracy = 22, melee = true },
        brawler = { cost = 18, armor = 0, weapon = 'WEAPON_BOTTLE', accuracy = 20, melee = true },
        -- Armed archetypes (medium+).
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
        { item = 'weapon_parts', weight = 15, min = 1, max = 1, fallbackCash = 700 },
    },
    rare = {
        { item = 'blueprint_fragment', weight = 45, min = 1, max = 1, fallbackCash = 900 },
        { item = 'weapon_parts', weight = 35, min = 1, max = 2, fallbackCash = 1000 },
        { item = 'crafting_recipe', weight = 20, min = 1, max = 1, fallbackCash = 1200 },
    },
}

-- Settlement / crate rewards: ONLY worn pistols or Tec-9 (never rifles/SMGs).
Config.RestrictedSupply = {
    pistol = {
        item = 'weapon_pistol',
        rollingDays = 7,
        globalCap = 3,
        hardChancePerTenThousand = 35,
        extremeChancePerTenThousand = 70,
        fallbackPool = 'rare',
        wornQuality = { min = 18, max = 48 },
    },
    combat_pistol = {
        item = 'weapon_combatpistol',
        rollingDays = 7,
        globalCap = 2,
        hardChancePerTenThousand = 18,
        extremeChancePerTenThousand = 40,
        fallbackPool = 'rare',
        wornQuality = { min = 15, max = 42 },
    },
    tec9 = {
        item = 'weapon_machinepistol',
        rollingDays = 10,
        globalCap = 1,
        hardChancePerTenThousand = 8,
        extremeChancePerTenThousand = 22,
        fallbackPool = 'rare',
        wornQuality = { min = 12, max = 38 },
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

-- Search dead mission NPCs ([E]). Automatic weapons are never lootable.
Config.CorpseLoot = {
    searchDurationMs = 3500,
    maxDistance = 2.4,
    -- Keep bodies searchable after the wave/phase clears.
    cleanupSec = 45,
    -- Delay auto-complete a bit so last corpses can be searched.
    clearGraceSec = 18,
    cashChance = { easy = 68, medium = 74, hard = 80, extreme = 86 },
    cashWorth = {
        easy = { min = 35, max = 95 },
        medium = { min = 55, max = 150 },
        hard = { min = 90, max = 240 },
        extreme = { min = 130, max = 360 },
    },
    ammoChance = { easy = 32, medium = 42, hard = 52, extreme = 62 },
    ammo = { item = 'pistol_ammo', min = 1, max = 3 },
    drugChance = { easy = 1, medium = 3, hard = 6, extreme = 9 },
    drugs = { 'weed_bag', 'cokebaggy', 'meth_bag', 'pills_pack', 'heroin_bag' },
    -- Only if the NPC's equipped weapon maps to a lootable pistol. ~5% on hard.
    pistolChance = { easy = 0, medium = 2, hard = 5, extreme = 8 },
    pistolQuality = {
        medium = { min = 22, max = 55 },
        hard = { min = 14, max = 42 },
        extreme = { min = 10, max = 38 },
    },
    -- Native weapon hash name -> inventory item (pistols / Tec-9 only).
    pistolWeapons = {
        WEAPON_PISTOL = 'weapon_pistol',
        WEAPON_COMBATPISTOL = 'weapon_combatpistol',
        WEAPON_APPISTOL = 'weapon_appistol',
        WEAPON_PISTOL50 = 'weapon_pistol50',
        WEAPON_SNSPISTOL = 'weapon_snspistol',
        WEAPON_HEAVYPISTOL = 'weapon_heavypistol',
        WEAPON_VINTAGEPISTOL = 'weapon_vintagepistol',
        WEAPON_CERAMICPISTOL = 'weapon_ceramicpistol',
        WEAPON_PISTOL_MK2 = 'weapon_pistol_mk2',
        WEAPON_SNSPISTOL_MK2 = 'weapon_snspistol_mk2',
        WEAPON_PISTOLXM3 = 'weapon_pistolxm3',
        WEAPON_MACHINEPISTOL = 'weapon_machinepistol', -- Tec-9
    },
}

Config.AdminPermissions = { 'admin', 'god' }
