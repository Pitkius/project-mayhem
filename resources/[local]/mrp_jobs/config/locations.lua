--[[
  mrp_jobs — visos koordinatės vienoje vietoje (shared).
  Koordinates galima laisvai koreguoti — architektūra jų nehardcodina.
]]

Config = Config or {}
Config.Locations = Config.Locations or {}

-- ── NAFTA ─────────────────────────────────────────────────────────
-- Gavybos laukas (Grand Senora Desert oil derricks) + Palmer-Taylor elektrinė.
Config.Locations.oil = {
    npc = {
        model = 's_m_y_construct_01',
        coords = vector4(1978.7, 3757.6, 32.18, 120.0),
        label = 'Naftos gavybos registracija',
        scenario = 'WORLD_HUMAN_CLIPBOARD',
    },
    vehicleSpawn = {
        coords = vector4(1985.5, 3771.0, 32.0, 30.0),
        model = 'flatbed',              -- darbo transportas (galima keisti į 'hauler'/'benson')
        loadOffsets = {                 -- kur ant transporto "guli" statinės (vietiniai offset'ai)
            vector3(0.0, -1.6, 1.1),
            vector3(0.0, -0.6, 1.1),
            vector3(0.0, 0.4, 1.1),
            vector3(0.0, 1.4, 1.1),
        },
        maxLoad = 4,                    -- kiek statinių telpa į vieną krovinį
    },
    -- Gavybos taškai (pumpjack). Kiekvienas turi minigame ir prop.
    pumps = {
        { id = 'pump_1', coords = vector4(2008.4, 3776.9, 32.18, 210.0), prop = 'prop_oiljack_01' },
        { id = 'pump_2', coords = vector4(1952.6, 3799.1, 32.35, 150.0), prop = 'prop_oiljack_01' },
        { id = 'pump_3', coords = vector4(1897.0, 3821.7, 33.30, 160.0), prop = 'prop_oiljack_01' },
        { id = 'pump_4', coords = vector4(2043.7, 3806.4, 46.60, 250.0), prop = 'prop_oiljack_01' },
    },
    barrelProp = 'prop_barrel_02a',     -- statinės prop pasaulyje / nešamas
    -- Pristatymas į elektrinę (Palmer-Taylor Power Station).
    delivery = {
        coords = vector4(2748.4, 1560.9, 24.5, 90.0),
        radius = 8.0,
        label = 'Elektrinės iškrovimas',
        requireVehicle = true,          -- ar pristatymui privalomas darbo transportas šalia
        vehicleRadius = 12.0,
    },
    blip = { sprite = 436, color = 5, scale = 0.8, name = 'Naftos gavyba' },
}

-- ── BURGER JOINT (2 vietos) ───────────────────────────────────────
-- burgershot_1 = uniqx_burgershot (Vespucci)
-- burgershot_2 = giant_burger (Little Seoul — Lucky Clucker)
Config.Locations.burger = {
    joints = {
        burgershot_1 = {
            label = 'Burger Shot · Vespucci',
            mlo = 'uniqx_burgershot',
            registerNpc = { model = 'a_m_m_hillbilly_01', coords = vector4(-1194.5, -890.9, 13.98, 130.0), scenario = 'WORLD_HUMAN_STAND_IMPATIENT' },
            -- Kasos / tray (y_burgershot Uniqx coords)
            registers = {
                { id = 'reg_1', coords = vector4(-1194.93, -893.3, 13.98, 34.0) },
            },
            -- Virtuvė ant MLO baldų (Uniqx cook / fry / burgers / drinks)
            kitchen = {
                { id = 'grill_1', type = 'grill', coords = vector4(-1195.02, -897.35, 13.98, 74.0) },
                { id = 'fryer_1', type = 'fryer', coords = vector4(-1196.08, -900.08, 13.50, 74.0) },
                { id = 'assembly_1', type = 'assembly', coords = vector4(-1195.29, -897.55, 13.80, 74.0) },
                { id = 'drinks_1', type = 'drinks', coords = vector4(-1191.0, -898.75, 13.89, 125.0) },
            },
            -- NPC eilė palei counter (ne per stalus)
            queue = {
                register = vector4(-1195.2, -892.9, 13.98, 214.0),
                anchor = vector4(-1195.9, -892.1, 13.98, 214.0),
                step = vector3(-0.55, 0.65, 0.0),
                spawn = vector4(-1199.0, -882.5, 13.98, 125.0),
                exit = vector4(-1201.0, -879.5, 13.98, 125.0),
                waypoints = {
                    vector3(-1199.0, -882.5, 13.98),
                    vector3(-1198.8, -887.5, 13.98),
                    vector3(-1197.2, -890.2, 13.98),
                    vector3(-1196.2, -891.8, 13.98),
                },
            },
            blip = { sprite = 106, color = 47, scale = 0.7, name = 'Burger Shot' },
        },
        burgershot_2 = {
            label = 'Burger Shot · Little Seoul',
            mlo = 'giant_burger',
            -- Įėjimas (forum / Lucky Clucker)
            registerNpc = { model = 'a_m_m_hillbilly_01', coords = vector4(-595.71, -861.46, 25.89, 270.0), scenario = 'WORLD_HUMAN_STAND_IMPATIENT' },
            registers = {
                -- Counter viduryje (dining šiaurėje y≈-871, virtuvė pietuose y≈-882)
                { id = 'reg_1', coords = vector4(-584.96, -874.0, 29.0, 0.0) },
            },
            kitchen = {
                { id = 'grill_1', type = 'grill', coords = vector4(-588.2, -882.0, 29.0, 180.0) },
                { id = 'fryer_1', type = 'fryer', coords = vector4(-590.6, -882.0, 29.0, 180.0) },
                { id = 'assembly_1', type = 'assembly', coords = vector4(-586.0, -881.6, 29.0, 180.0) },
                { id = 'drinks_1', type = 'drinks', coords = vector4(-580.2, -876.5, 29.0, 90.0) },
            },
            queue = {
                register = vector4(-585.0, -873.0, 29.0, 180.0),
                anchor = vector4(-585.0, -871.8, 29.0, 180.0),
                step = vector3(0.0, 0.75, 0.0),
                spawn = vector4(-595.71, -861.46, 25.89, 180.0),
                exit = vector4(-595.71, -855.0, 25.2, 0.0),
                waypoints = {
                    vector3(-595.71, -861.46, 25.89),
                    vector3(-590.0, -865.5, 26.2),
                    vector3(-585.5, -870.5, 28.9),
                    vector3(-585.0, -872.5, 29.0),
                },
            },
            blip = { sprite = 106, color = 47, scale = 0.7, name = 'Burger Shot' },
        },
    },
    -- Valymo zonų šablonai generuojami runtime pagal joint (žr. config/cleaning.lua nėra —
    -- šablonai serveryje). Čia tik patalpos "kotvė" progreso rodymui.
}

-- ── VAISIAI ───────────────────────────────────────────────────────
Config.Locations.fruit = {
    npc = {
        model = 'a_m_m_farmer_01',
        coords = vector4(2447.0, 4968.4, 46.8, 45.0),
        label = 'Vaisių ūkio registracija',
        scenario = 'WORLD_HUMAN_CLIPBOARD',
    },
    -- Supirkimas (dėžių pristatymas)
    delivery = {
        coords = vector4(2436.6, 4970.3, 46.8, 130.0),
        radius = 5.0,
        label = 'Vaisių supirkimas',
    },
    -- Vaisinio vape / koncentrato apdirbimo stotelė
    processing = {
        wash = { coords = vector4(2429.2, 4965.0, 46.8, 130.0), label = 'Vaisių plovimas / smulkinimas' },
        press = { coords = vector4(2426.4, 4962.0, 46.8, 130.0), label = 'Koncentrato spaudimas' },
        mix = { coords = vector4(2423.6, 4959.0, 46.8, 130.0), label = 'Vape skysčio maišymas' },
    },
    -- Vaisinio/paprasto vape supirkimas
    vapeBuyer = {
        coords = vector4(2419.0, 4955.0, 46.8, 130.0),
        radius = 4.0,
        label = 'Vape supirkimas',
    },
    blip = { sprite = 85, color = 2, scale = 0.7, name = 'Vaisių ūkis' },
}

-- ── KARJEROS SPECIALISTAS (bendras darbo meniu NPC) ──────────────
Config.Locations.career = {
    npc = {
        model = 'a_m_y_business_01',
        coords = vector4(-551.3856, -191.2355, 38.2193, 208.4912),
        label = 'Laurynas · Karjeros specialistas',
        scenario = 'WORLD_HUMAN_CLIPBOARD',
    },
    blip = { sprite = 480, color = 46, scale = 0.78, name = 'Karjeros centras' },
}
