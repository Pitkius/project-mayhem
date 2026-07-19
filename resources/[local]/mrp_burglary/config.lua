Config = Config or {}

Config.Burglary = {
    requireLockpick = true,
    lockpickItem = 'lockpick',
    advancedLockpickItem = 'advancedlockpick',
    drillItem = 'drill', --- seifui

    globalCooldownSeconds = 900,
    houseCooldownSeconds = 3600,

    policeAlertChance = 0.22,
    wakeAlertChance = 0.85,
    failLockpickAlertChance = 0.35,
    safeDrillWakeChance = 1.0, --- jei NPC gyvas — gręžiant seifą pabunda / puola

    routingBucketBase = 18000,

    --- Lockpick: visada progress bar + animacija (ne instant)
    lockpickProgress = {
        lockpick = { duration = 14000, label = 'Laužiate durų spyną…' },
        advancedlockpick = { duration = 9000, label = 'Laužiate duris (pažangus)…' },
    },
    lockpickAnim = {
        dict = 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@',
        clip = 'machinic_loop_mechandplayer',
        flag = 49,
    },

    drawerProgress = {
        duration = 6500,
        label = 'Apieškomi stalčiai…',
    },

    drawerMinigame = {
        mode = 'sequence',
        label = 'Atidaryk stalčių — rodyklės',
        length = 5,
    },

    --- Po progress bar — trumpas skill check (neprivalomas jei hacking down)
    lockpickMinigame = {
        lockpick = { mode = 'sequence', label = 'Paskutinis spynos žingsnis', length = 5 },
        advancedlockpick = { mode = 'sequence', label = 'Paskutinis spynos žingsnis', length = 4 },
    },

    --- Interjero props (šansas per sesiją)
    props = {
        tv = {
            chance = 0.45,
            model = 'prop_tv_flat_01',
            takeDuration = 12000,
            takeLabel = 'Nuimamas televizorius…',
            item = 'stolen_tv',
            anim = {
                dict = 'anim@heists@box_carry@',
                clip = 'idle',
                flag = 49,
            },
        },
        safe = {
            chance = 0.28,
            model = 'prop_ld_int_safe_01',
            drillDuration = 18000,
            drillLabel = 'Gręžiamas seifas…',
            emptyChance = 0.42, --- nieko viduje
            loot = {
                { item = 'rolex', weight = 14, min = 1, max = 1 },
                { item = 'goldchain', weight = 16, min = 1, max = 2 },
                { item = 'tenkgoldchain', weight = 6, min = 1, max = 1 },
                { item = 'gold_bracelet', weight = 12, min = 1, max = 1 },
                { item = 'pearl_necklace', weight = 10, min = 1, max = 1 },
                { item = 'diamond_ring', weight = 10, min = 1, max = 1 },
                { item = 'markedbills', weight = 18, min = 1, max = 1, worthMin = 500, worthMax = 2200 },
                { item = 'cash', weight = 14, min = 800, max = 3200 },
            },
        },
    },

    --- Pavogtų daiktų pardavimas
    fence = {
        enabled = true,
        coords = vector4(707.15, -966.55, 30.41, 200.0), --- šalia Lesterio
        pedModel = 'g_m_y_mexgoon_02',
        scenario = 'WORLD_HUMAN_SMOKING',
        label = 'Parduoti vogtus daiktus',
        prices = {
            stolen_tv = { min = 450, max = 900 },
            iphone = { min = 280, max = 520 },
            samsungphone = { min = 220, max = 450 },
            laptop = { min = 400, max = 850 },
            tablet = { min = 200, max = 420 },
            game_console = { min = 350, max = 700 },
            headphones = { min = 80, max = 180 },
            designer_perfume = { min = 60, max = 140 },
            leather_wallet = { min = 40, max = 90 },
            smartwatch = { min = 120, max = 260 },
            digital_camera = { min = 150, max = 320 },
            goldchain = { min = 350, max = 700 },
            tenkgoldchain = { min = 700, max = 1400 },
            silver_chain = { min = 120, max = 280 },
            gold_bracelet = { min = 200, max = 420 },
            silver_bracelet = { min = 90, max = 200 },
            pearl_necklace = { min = 180, max = 400 },
            silver_ring = { min = 50, max = 120 },
            diamond_ring = { min = 500, max = 1100 },
            rolex = { min = 800, max = 1600 },
            electronickit = { min = 70, max = 150 },
            plastic = { min = 5, max = 15 },
        },
    },

    tiers = {
        small = {
            label = 'Mažas butas',
            lootRolls = 2,
            cashMin = 120,
            cashMax = 420,
            tvChance = 0.30,
            safeChance = 0.12,
        },
        medium = {
            label = 'Vidutinis butas',
            lootRolls = 3,
            cashMin = 250,
            cashMax = 850,
            tvChance = 0.45,
            safeChance = 0.22,
        },
        large = {
            label = 'Namas',
            lootRolls = 4,
            cashMin = 450,
            cashMax = 1400,
            tvChance = 0.55,
            safeChance = 0.32,
        },
        mansion = {
            label = 'Vila',
            lootRolls = 5,
            cashMin = 800,
            cashMax = 2600,
            tvChance = 0.70,
            safeChance = 0.45,
        },
    },

    --- Stalčių loot (be metalscrap). weight = santykinis šansas
    lootTable = {
        --- Dažni / pigesni
        { item = 'plastic', weight = 14, min = 1, max = 4 },
        { item = 'leather_wallet', weight = 14, min = 1, max = 1 },
        { item = 'designer_perfume', weight = 12, min = 1, max = 1 },
        { item = 'headphones', weight = 11, min = 1, max = 1 },
        { item = 'silver_ring', weight = 10, min = 1, max = 1 },
        { item = 'silver_bracelet', weight = 10, min = 1, max = 1 },
        { item = 'silver_chain', weight = 9, min = 1, max = 1 },
        { item = 'smartwatch', weight = 9, min = 1, max = 1 },
        { item = 'electronickit', weight = 8, min = 1, max = 1 },
        --- Elektronika
        { item = 'samsungphone', weight = 8, min = 1, max = 1 },
        { item = 'iphone', weight = 6, min = 1, max = 1 },
        { item = 'tablet', weight = 5, min = 1, max = 1 },
        { item = 'digital_camera', weight = 5, min = 1, max = 1 },
        { item = 'laptop', weight = 4, min = 1, max = 1 },
        { item = 'game_console', weight = 3, min = 1, max = 1 },
        --- Papuošalai
        { item = 'gold_bracelet', weight = 7, min = 1, max = 1 },
        { item = 'pearl_necklace', weight = 6, min = 1, max = 1 },
        { item = 'goldchain', weight = 7, min = 1, max = 2 },
        { item = 'rolex', weight = 3, min = 1, max = 1 },
        { item = 'diamond_ring', weight = 2, min = 1, max = 1 },
        { item = 'tenkgoldchain', weight = 1, min = 1, max = 1 },
        --- Pinigai
        { item = 'markedbills', weight = 8, min = 1, max = 1, worthMin = 200, worthMax = 900 },
        --- Narkotikai (mažas šansas, jau supakuoti)
        { item = 'joint', weight = 3, min = 1, max = 2 },
        { item = 'weed_bag', weight = 2, min = 1, max = 1 },
        { item = 'cokebaggy', weight = 1, min = 1, max = 1 },
        { item = 'meth_bag', weight = 1, min = 1, max = 1 },
        { item = 'pills_pack', weight = 1, min = 1, max = 1 },
        { item = 'oxy', weight = 1, min = 1, max = 2 },
    },

    sleepingNpc = {
        model = 'a_m_y_bevhills_01',
        scenario = 'WORLD_HUMAN_BUM_SLUMPED',
    },

    houses = {
        {
            id = 'davis_small_1',
            tier = 'small',
            label = 'Davis — mažas butas',
            door = vector4(126.87, -1929.53, 21.38, 210.0),
            interior = {
                enter = vector4(266.17, -1007.52, -101.01, 0.0),
                exit = vector3(266.17, -1007.52, -101.01),
                sleeper = vector4(262.55, -1004.22, -99.01, 180.0),
                drawers = {
                    vector3(265.89, -999.42, -99.01),
                    vector3(259.73, -1003.95, -99.01),
                },
                tv = vector4(256.95, -995.85, -99.01, 180.0),
                safe = vector4(261.15, -1003.55, -99.01, 90.0),
            },
        },
        {
            id = 'strawberry_medium_1',
            tier = 'medium',
            label = 'Strawberry — vidutinis butas',
            door = vector4(114.25, -1961.19, 21.33, 200.0),
            interior = {
                enter = vector4(346.55, -1012.83, -99.20, 0.0),
                exit = vector3(346.55, -1012.83, -99.20),
                sleeper = vector4(349.82, -996.35, -99.20, 90.0),
                drawers = {
                    vector3(351.29, -998.84, -99.20),
                    vector3(350.62, -993.71, -99.20),
                    vector3(345.21, -1001.88, -99.20),
                },
                tv = vector4(340.85, -996.45, -99.20, 270.0),
                safe = vector4(350.15, -995.55, -99.20, 180.0),
            },
        },
        {
            id = 'vinewood_large_1',
            tier = 'large',
            label = 'Vinewood — namas',
            door = vector4(-784.72, 459.77, 100.39, 200.0),
            interior = {
                enter = vector4(-786.87, 315.76, 217.64, 0.0),
                exit = vector3(-786.87, 315.76, 217.64),
                sleeper = vector4(-797.14, 335.79, 220.44, 270.0),
                drawers = {
                    vector3(-796.11, 327.75, 217.04),
                    vector3(-797.74, 328.29, 220.44),
                    vector3(-781.55, 330.34, 217.04),
                    vector3(-782.66, 322.66, 217.04),
                },
                tv = vector4(-789.55, 323.15, 217.04, 90.0),
                safe = vector4(-795.25, 334.85, 220.44, 0.0),
            },
        },
        {
            id = 'rockford_mansion_1',
            tier = 'mansion',
            label = 'Rockford — vila',
            door = vector4(-174.28, 497.65, 137.67, 190.0),
            interior = {
                enter = vector4(-174.28, 497.65, 137.67, 190.0),
                exit = vector3(-174.28, 497.65, 137.67),
                sleeper = vector4(-167.47, 487.90, 133.84, 0.0),
                drawers = {
                    vector3(-169.88, 491.82, 130.04),
                    vector3(-167.47, 487.90, 133.84),
                    vector3(-170.40, 482.88, 137.24),
                    vector3(-175.55, 492.05, 130.04),
                    vector3(-163.20, 482.25, 133.84),
                },
                tv = vector4(-171.55, 489.25, 133.84, 270.0),
                safe = vector4(-166.15, 486.55, 133.84, 90.0),
            },
        },
    },
}
