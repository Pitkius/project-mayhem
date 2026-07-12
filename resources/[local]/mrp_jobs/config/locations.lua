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
-- burgershot_1 = uniqx_burgershot (Vespucci), burgershot_2 = antras Burger Shot.
Config.Locations.burger = {
    joints = {
        burgershot_1 = {
            label = 'Burger Shot · Vespucci',
            registerNpc = { model = 'a_m_m_hillbilly_01', coords = vector4(-1194.5, -890.9, 13.98, 130.0), scenario = 'WORLD_HUMAN_STAND_IMPATIENT' },
            -- Kasos (kasininkas + NPC pirkimas)
            registers = {
                { id = 'reg_1', coords = vector4(-1196.9, -892.6, 13.98, 34.0) },
            },
            -- Virtuvės gaminimo taškai (kepėjas)
            kitchen = {
                { id = 'grill_1', coords = vector4(-1200.3, -896.6, 13.98, 34.0) },
            },
            -- NPC klientų eilės kelias
            queue = {
                anchor = vector4(-1193.3, -889.9, 13.98, 214.0),   -- pirmas eilės taškas (prie kasos)
                step = vector3(0.0, 1.0, 0.0),                     -- kryptis tolyn nuo kasos
                spawn = vector4(-1188.0, -885.0, 13.98, 214.0),    -- kur NPC pasirodo/išnyksta
                exit = vector4(-1183.0, -880.0, 13.5, 30.0),
            },
            blip = { sprite = 106, color = 47, scale = 0.7, name = 'Burger Shot' },
        },
        burgershot_2 = {
            label = 'Burger Shot · Del Perro',
            registerNpc = { model = 'a_m_m_hillbilly_01', coords = vector4(-1476.9, -650.8, 29.5, 320.0), scenario = 'WORLD_HUMAN_STAND_IMPATIENT' },
            registers = {
                { id = 'reg_1', coords = vector4(-1478.9, -652.9, 29.5, 140.0) },
            },
            kitchen = {
                { id = 'grill_1', coords = vector4(-1482.4, -648.6, 29.5, 140.0) },
            },
            queue = {
                anchor = vector4(-1475.2, -648.0, 29.5, 45.0),
                step = vector3(0.7, 0.7, 0.0),
                spawn = vector4(-1470.0, -643.0, 29.5, 45.0),
                exit = vector4(-1465.0, -639.0, 29.5, 45.0),
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
