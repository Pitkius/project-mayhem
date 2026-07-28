Config = Config or {}

-- Optional GTA Online interiors (kept for hard/extreme or legacy). Prefer outdoor compounds.
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

-- Outdoor compounds: props + objective/enemy offsets relative to MissionWorldSites entry.
-- Players stay in the open world — no casino/strip-club teleport.
Config.MissionCompounds = {
    warehouse_yard = {
        label = 'Sandėlio kiemas',
        radius = 28.0,
        entryPrompt = 'Eik į vidų',
        entryOffset = vector4(0.0, 0.0, 0.0, 0.0),
        exitOffset = vector4(-6.0, 8.0, 0.0, 180.0),
        objective = {
            vector3(4.5, -3.0, 0.0),
            vector3(-5.0, -6.5, 0.0),
            vector3(8.0, 2.5, 0.0),
        },
        enemySpawns = {
            vector4(3.0, -8.0, 0.0, 0.0),
            vector4(-7.0, -2.0, 0.0, 90.0),
            vector4(6.0, 4.0, 0.0, 200.0),
            vector4(-2.0, 6.0, 0.0, 270.0),
        },
        props = {
            { model = 'prop_boxpile_07d', offset = vector3(3.5, -2.0, -0.95) },
            { model = 'prop_boxpile_02b', offset = vector3(5.2, -4.5, -0.95) },
            { model = 'prop_container_ld_d', offset = vector3(-8.0, -4.0, -1.0), heading = 90.0 },
            { model = 'prop_barrier_work05', offset = vector3(0.5, 6.0, -1.0), heading = 0.0 },
            { model = 'prop_toolchest_05', offset = vector3(2.0, 1.5, -1.0) },
            { model = 'prop_cs_cardbox_01', offset = vector3(4.0, -3.2, -0.4) },
        },
        maxNpc = 8,
    },
    street_stash = {
        label = 'Gatvės stash',
        radius = 22.0,
        entryPrompt = 'Eik į vidų',
        entryOffset = vector4(0.0, 0.0, 0.0, 0.0),
        exitOffset = vector4(5.0, 4.0, 0.0, 90.0),
        objective = {
            vector3(2.5, -2.0, 0.0),
            vector3(-3.0, -4.0, 0.0),
            vector3(1.0, 3.5, 0.0),
        },
        enemySpawns = {
            vector4(2.0, -5.0, 0.0, 20.0),
            vector4(-4.0, -1.5, 0.0, 110.0),
            vector4(3.5, 2.5, 0.0, 200.0),
        },
        props = {
            { model = 'prop_box_wood02a_pu', offset = vector3(2.0, -1.5, -0.95) },
            { model = 'prop_cs_duffel_01', offset = vector3(-2.5, -3.0, -0.95) },
            { model = 'prop_drug_package', offset = vector3(1.2, 2.8, -0.95) },
            { model = 'prop_barrel_02a', offset = vector3(-3.5, 1.0, -1.0) },
            { model = 'prop_bench_01a', offset = vector3(0.0, 4.0, -1.0), heading = 180.0 },
        },
        maxNpc = 6,
    },
    lab_yard = {
        label = 'Laboratorijos zona',
        radius = 26.0,
        entryPrompt = 'Eik į objektą',
        entryOffset = vector4(0.0, 0.0, 0.0, 0.0),
        exitOffset = vector4(-5.0, 7.0, 0.0, 180.0),
        objective = {
            vector3(3.0, -4.0, 0.0),
            vector3(-4.5, -2.0, 0.0),
            vector3(5.0, 3.0, 0.0),
        },
        enemySpawns = {
            vector4(4.0, -6.0, 0.0, 0.0),
            vector4(-5.0, -3.0, 0.0, 90.0),
            vector4(2.0, 5.0, 0.0, 220.0),
            vector4(-3.0, 4.0, 0.0, 270.0),
        },
        props = {
            { model = 'prop_barrel_exp_01a', offset = vector3(2.5, -3.0, -1.0) },
            { model = 'prop_barrel_exp_01b', offset = vector3(3.8, -4.2, -1.0) },
            { model = 'prop_generator_03b', offset = vector3(-4.0, -1.5, -1.0), heading = 45.0 },
            { model = 'prop_tool_bench02', offset = vector3(4.5, 2.0, -1.0) },
            { model = 'prop_gas_tank_01a', offset = vector3(-5.5, 2.5, -1.0) },
            { model = 'prop_crate_11e', offset = vector3(1.0, 3.5, -0.95) },
        },
        maxNpc = 8,
    },
    hangar_apron = {
        label = 'Hangaro aikštelė',
        radius = 32.0,
        entryPrompt = 'Eik į hangarą',
        entryOffset = vector4(0.0, 0.0, 0.0, 0.0),
        exitOffset = vector4(8.0, 10.0, 0.0, 180.0),
        objective = {
            vector3(6.0, -5.0, 0.0),
            vector3(-6.0, -4.0, 0.0),
            vector3(2.0, 6.0, 0.0),
        },
        enemySpawns = {
            vector4(5.0, -8.0, 0.0, 10.0),
            vector4(-7.0, -3.0, 0.0, 100.0),
            vector4(8.0, 4.0, 0.0, 200.0),
            vector4(-4.0, 7.0, 0.0, 280.0),
        },
        props = {
            { model = 'prop_air_trailer_1a', offset = vector3(-10.0, 0.0, -1.0), heading = 90.0 },
            { model = 'prop_boxpile_06a', offset = vector3(5.0, -4.0, -0.95) },
            { model = 'prop_boxpile_06b', offset = vector3(7.0, -5.5, -0.95) },
            { model = 'prop_toolchest_01', offset = vector3(3.0, 2.0, -1.0) },
            { model = 'prop_mb_cargo_03a', offset = vector3(-4.0, 5.0, -1.0), heading = 0.0 },
            { model = 'prop_barrier_work06a', offset = vector3(0.0, 9.0, -1.0) },
        },
        maxNpc = 8,
    },
    club_lot = {
        label = 'Klubo kiemas',
        radius = 24.0,
        entryPrompt = 'Eik į vidų',
        entryOffset = vector4(0.0, 0.0, 0.0, 0.0),
        exitOffset = vector4(4.0, 6.0, 0.0, 180.0),
        objective = {
            vector3(2.0, -3.0, 0.0),
            vector3(-3.5, -2.5, 0.0),
            vector3(1.5, 4.0, 0.0),
        },
        enemySpawns = {
            vector4(3.0, -5.0, 0.0, 0.0),
            vector4(-4.0, -2.0, 0.0, 90.0),
            vector4(4.0, 3.0, 0.0, 210.0),
        },
        props = {
            { model = 'prop_barrel_01a', offset = vector3(2.5, -2.0, -1.0) },
            { model = 'prop_table_03', offset = vector3(-2.0, -3.0, -1.0) },
            { model = 'prop_chair_01a', offset = vector3(-1.2, -2.2, -1.0) },
            { model = 'prop_box_ammo03a', offset = vector3(1.5, 3.0, -0.95) },
            { model = 'prop_roadcone02a', offset = vector3(0.0, 5.5, -1.0) },
        },
        maxNpc = 6,
    },
    garage_lot = {
        label = 'Garažo aikštelė',
        radius = 24.0,
        entryPrompt = 'Eik į garažą',
        entryOffset = vector4(0.0, 0.0, 0.0, 0.0),
        exitOffset = vector4(5.0, 5.0, 0.0, 180.0),
        objective = {
            vector3(3.0, -2.5, 0.0),
            vector3(-3.0, -3.0, 0.0),
            vector3(2.0, 3.5, 0.0),
        },
        enemySpawns = {
            vector4(4.0, -5.0, 0.0, 15.0),
            vector4(-4.5, -1.0, 0.0, 100.0),
            vector4(3.0, 4.0, 0.0, 220.0),
        },
        props = {
            { model = 'prop_car_engine_01', offset = vector3(2.5, -2.0, -0.9) },
            { model = 'prop_tool_box_04', offset = vector3(-2.5, -2.5, -1.0) },
            { model = 'prop_wheel_tyre', offset = vector3(3.5, 1.0, -1.0) },
            { model = 'prop_compressor_01', offset = vector3(-3.5, 2.0, -1.0) },
            { model = 'prop_oilcan_01a', offset = vector3(1.0, 3.0, -0.95) },
        },
        maxNpc = 6,
    },
}

-- Logical open-world entries (no casino / strip club).
Config.MissionWorldSites = {
    docks = {
        vector4(1204.92, -3115.86, 5.54, 90.0),   -- Elysian docks warehouse
        vector4(896.04, -3199.26, 5.90, 180.0),   -- South docks crates
        vector4(-424.88, -2789.22, 6.00, 45.0),   -- Elysian Island industrial
    },
    industrial = {
        vector4(716.48, -962.12, 30.40, 0.0),     -- Textile City warehouse alley
        vector4(982.18, -1805.72, 31.14, 175.0),  -- Cypress Flats yards
        vector4(1207.32, -1262.68, 35.23, 270.0), -- Murrieta Heights industrial
    },
    rural = {
        vector4(1391.88, 3605.22, 34.98, 200.0),  -- Sandy / Grand Senora
        vector4(2554.22, 4672.88, 34.08, 45.0),   -- Grapeseed farm sheds
        vector4(1903.44, 4922.12, 48.88, 150.0),  -- Grapeseed barns
    },
    city = {
        vector4(114.42, -1961.18, 20.94, 20.0),   -- Grove / Forum residential
        vector4(312.88, -1755.44, 29.31, 50.0),   -- Davis / Carson Ave houses
        vector4(-148.22, -1623.66, 33.05, 140.0), -- Strawberry back lots
    },
    hangars = {
        vector4(-1145.88, -2864.44, 13.95, 150.0), -- LSIA hangar apron
        vector4(-1653.22, -3142.88, 13.99, 330.0), -- LSIA south hangars
        vector4(1737.88, 3288.44, 41.13, 15.0),    -- Sandy Shores airfield hangars
    },
    vehicle = {
        vector4(218.52, -768.24, 30.65, 160.0),   -- Pillbox / Legion parking
        vector4(-340.88, -874.22, 31.08, 0.0),    -- Little Seoul street lot
        vector4(1737.22, 3710.44, 34.14, 20.0),   -- Sandy motel lot
    },
}
