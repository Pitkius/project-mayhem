Config = Config or {}

-- Mission interiors are isolated with a per-run routing bucket. Coordinates use
-- GTA Online interiors available in the base game; IPLs are requested client-side.
Config.MissionInteriors = {
    warehouse_large = {
        label = 'Didelis sandėlis',
        ipl = nil,
        entry = vector4(1026.86, -3101.62, -39.00, 90.0),
        exit = vector4(998.18, -3091.92, -39.00, 270.0),
        objective = {
            vector3(1012.22, -3104.48, -39.00),
            vector3(1050.14, -3100.66, -39.00),
            vector3(1072.34, -3102.28, -39.00),
        },
        enemySpawns = {
            vector4(1005.24, -3098.20, -39.00, 90.0),
            vector4(1037.86, -3107.24, -39.00, 180.0),
            vector4(1061.88, -3095.36, -39.00, 270.0),
            vector4(1080.48, -3103.88, -39.00, 180.0),
        },
        maxNpc = 12,
    },
    weed_lab = {
        label = 'Nelegali laboratorija',
        ipl = 'bkr_biker_interior_placement_interior_3_biker_dlc_int_ware02_milo',
        entry = vector4(1066.30, -3183.42, -39.16, 90.0),
        exit = vector4(1065.98, -3183.50, -39.16, 270.0),
        objective = {
            vector3(1044.14, -3194.84, -38.16),
            vector3(1033.02, -3205.74, -38.18),
            vector3(1058.42, -3197.68, -39.14),
        },
        enemySpawns = {
            vector4(1057.54, -3196.48, -39.14, 90.0),
            vector4(1041.66, -3199.50, -38.16, 0.0),
            vector4(1032.52, -3205.36, -38.18, 270.0),
            vector4(1048.36, -3191.84, -38.16, 180.0),
        },
        maxNpc = 10,
    },
    meth_lab = {
        label = 'Chemijos laboratorija',
        ipl = 'bkr_biker_interior_placement_interior_2_biker_dlc_int_ware01_milo',
        entry = vector4(996.82, -3200.68, -36.39, 270.0),
        exit = vector4(996.62, -3200.60, -36.39, 90.0),
        objective = {
            vector3(1005.76, -3200.36, -38.52),
            vector3(1014.58, -3195.94, -38.99),
            vector3(1012.08, -3205.18, -38.99),
        },
        enemySpawns = {
            vector4(1001.86, -3200.12, -38.52, 270.0),
            vector4(1011.62, -3195.86, -38.99, 180.0),
            vector4(1015.24, -3206.04, -38.99, 90.0),
            vector4(1007.36, -3194.74, -38.52, 0.0),
        },
        maxNpc = 10,
    },
    clubhouse = {
        label = 'Klubo patalpos',
        ipl = 'bkr_biker_interior_placement_interior_0_biker_dlc_int_01_milo',
        entry = vector4(1121.02, -3152.78, -37.06, 0.0),
        exit = vector4(1121.24, -3152.82, -37.06, 180.0),
        objective = {
            vector3(1112.86, -3146.78, -37.06),
            vector3(1102.48, -3158.18, -37.52),
            vector3(1110.34, -3164.24, -37.52),
        },
        enemySpawns = {
            vector4(1114.64, -3150.62, -37.06, 90.0),
            vector4(1104.14, -3157.80, -37.52, 0.0),
            vector4(1111.50, -3163.72, -37.52, 180.0),
            vector4(1120.02, -3159.24, -37.06, 270.0),
        },
        maxNpc = 10,
    },
}

Config.MissionWorldSites = {
    docks = {
        vector4(1204.92, -3115.86, 5.54, 90.0),
        vector4(896.04, -3199.26, 5.90, 180.0),
        vector4(-424.88, -2789.22, 6.00, 45.0),
    },
    industrial = {
        vector4(716.48, -962.12, 30.40, 0.0),
        vector4(982.18, -1805.72, 31.14, 175.0),
        vector4(1207.32, -1262.68, 35.23, 270.0),
    },
    rural = {
        vector4(1391.88, 3605.22, 34.98, 200.0),
        vector4(2554.22, 4672.88, 34.08, 45.0),
        vector4(2350.88, 3054.44, 48.15, 270.0),
    },
    city = {
        vector4(127.22, -1298.44, 29.23, 30.0),
        vector4(-706.88, -914.44, 19.22, 90.0),
        vector4(978.44, 18.22, 81.00, 240.0),
    },
    vehicle = {
        vector4(218.52, -768.24, 30.65, 160.0),
        vector4(-340.88, -874.22, 31.08, 0.0),
        vector4(1737.22, 3710.44, 34.14, 20.0),
    },
}
