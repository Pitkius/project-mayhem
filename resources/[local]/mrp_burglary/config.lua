Config = Config or {}

Config.Burglary = {
    requireLockpick = true,
    lockpickItem = 'lockpick',
    advancedLockpickItem = 'advancedlockpick',

    globalCooldownSeconds = 900,
    houseCooldownSeconds = 3600,

    policeAlertChance = 0.22,
    wakeAlertChance = 0.85,
    failLockpickAlertChance = 0.35,

    routingBucketBase = 18000,

    drawerMinigame = {
        mode = 'sequence',
        label = 'Atidaryk stalčių — rodyklės',
        length = 4,
    },

    lockpickMinigame = {
        lockpick = { mode = 'sequence', label = 'Laužiate duris — rodyklės', length = 4 },
        advancedlockpick = { mode = 'sequence', label = 'Pažangus atrakinimas — rodyklės', length = 3 },
    },

    --- 4 dydžių kategorijos
    tiers = {
        small = {
            label = 'Mažas butas',
            lootRolls = 2,
            cashMin = 120,
            cashMax = 420,
        },
        medium = {
            label = 'Vidutinis butas',
            lootRolls = 3,
            cashMin = 250,
            cashMax = 850,
        },
        large = {
            label = 'Namas',
            lootRolls = 4,
            cashMin = 450,
            cashMax = 1400,
        },
        mansion = {
            label = 'Vila',
            lootRolls = 5,
            cashMin = 800,
            cashMax = 2600,
        },
    },

    lootTable = {
        { item = 'goldchain', weight = 18, min = 1, max = 2 },
        { item = 'rolex', weight = 8, min = 1, max = 1 },
        { item = 'diamond_ring', weight = 5, min = 1, max = 1 },
        { item = 'electronickit', weight = 10, min = 1, max = 1 },
        { item = 'plastic', weight = 22, min = 2, max = 5 },
        { item = 'metalscrap', weight = 20, min = 2, max = 6 },
        { item = 'markedbills', weight = 12, min = 1, max = 1, worthMin = 200, worthMax = 900 },
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
            },
        },
    },
}
