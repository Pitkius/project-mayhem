Config = Config or {}

Config.ChopShop = {
    --- 48 val. (sek.) — savininkas negali atgauti per KMA
    recoveryLockSeconds = 48 * 60 * 60,

    --- Atgavimo mokestis = vehicleValue * recoveryFeePercent
    recoveryFeePercent = 0.30,

    --- Cooldown tarp ardymų (sek.)
    playerCooldownSeconds = 300,

    --- Policijos perspėjimo tikimybė (0–1), jei įjungta
    policeAlertChance = 0.12,
    policeAlertEnabled = true,

    --- Nešvarūs pinigai dalims parduoti
    payoutItem = 'markedbills',
    payoutBillWorth = 0, -- 0 = vienas banknotas su visa suma

    targetDistance = 3.0,
    blipSprite = 643,
    blipColor = 1,
    blipScale = 0.85,

    --- Kainų tier'ai (pagal mrp_vehicle_perf / QBCore kainą)
    priceTiers = {
        { id = 'budget',  minPrice = 0,       maxPrice = 49999,  scrapMs = 45000, label = 'Paprasta' },
        { id = 'mid',     minPrice = 50000,   maxPrice = 149999, scrapMs = 60000, label = 'Vidutinė' },
        { id = 'premium', minPrice = 150000,  maxPrice = 399999, scrapMs = 75000, label = 'Premium' },
        { id = 'luxury',  minPrice = 400000,  maxPrice = 99999999, scrapMs = 90000, label = 'Prabangi' },
    },

    --- Dalių kiekiai pagal tier (padidintas loot + daugiau tipų)
    tierParts = {
        budget = {
            { item = 'metalscrap', min = 5,  max = 9 },
            { item = 'plastic',    min = 2,  max = 5 },
            { item = 'rubber',     min = 2,  max = 4 },
            { item = 'glass',      min = 1,  max = 3 },
            { item = 'iron',       min = 1,  max = 3 },
        },
        mid = {
            { item = 'metalscrap', min = 8,  max = 13 },
            { item = 'aluminum',   min = 3,  max = 6 },
            { item = 'plastic',    min = 3,  max = 6 },
            { item = 'rubber',     min = 3,  max = 5 },
            { item = 'glass',      min = 2,  max = 4 },
            { item = 'copper',     min = 1,  max = 3 },
            { item = 'iron',       min = 2,  max = 4 },
        },
        premium = {
            { item = 'metalscrap', min = 11, max = 17 },
            { item = 'aluminum',   min = 6,  max = 10 },
            { item = 'steel',      min = 3,  max = 6 },
            { item = 'rubber',     min = 4,  max = 7 },
            { item = 'glass',      min = 3,  max = 5 },
            { item = 'copper',     min = 2,  max = 5 },
            { item = 'iron',       min = 3,  max = 6 },
        },
        luxury = {
            { item = 'metalscrap', min = 14, max = 22 },
            { item = 'aluminum',   min = 8,  max = 14 },
            { item = 'steel',      min = 6,  max = 11 },
            { item = 'rubber',     min = 5,  max = 9 },
            { item = 'glass',      min = 4,  max = 7 },
            { item = 'copper',     min = 4,  max = 7 },
            { item = 'iron',       min = 4,  max = 8 },
        },
    },

    --- NPC mašinos gauna mažiau dalių (multiplier)
    npcPartsMultiplier = 0.65,

    --- Dalių supirkėjas — kainos už vnt. (~+20% nuo ankstesnių)
    buyerPrices = {
        metalscrap = 105,
        aluminum   = 170,
        steel      = 265,
        plastic    = 75,
        rubber     = 90,
        glass      = 80,
        copper     = 195,
        iron       = 125,
    },

    --- Dvi ardymo vietos
    locations = {
        {
            id = 'sandy',
            label = 'Ardymo aikštelė · Sandy Shores',
            coords = vector3(2340.84, 3053.54, 48.15),
            heading = 180.0,
            zoneRadius = 18.0,
            scrapCoords = vector3(2340.84, 3053.54, 48.15),
            --- NPC, kuris priima / išardo mašiną detalėms
            scrapNpc = {
                coords = vector4(2343.55, 3058.20, 48.15, 200.0),
                model = 's_m_y_xmech_02',
                label = 'Atiduoti mašiną detalėms',
                scenario = 'WORLD_HUMAN_CLIPBOARD',
            },
            --- NPC, kuris perka jau išardytas dalis
            buyer = {
                coords = vector4(2334.12, 3047.88, 48.15, 270.0),
                model = 's_m_y_construct_01',
                label = 'Laužo supirkėjas',
            },
        },
        {
            id = 'ls_docks',
            label = 'Ardymo aikštelė · LS dokai',
            coords = vector3(1204.1821, -3117.7207, 5.2528),
            heading = 177.8636,
            zoneRadius = 20.0,
            scrapCoords = vector3(1204.1821, -3117.7207, 5.2528),
            scrapNpc = {
                coords = vector4(1200.45, -3114.10, 5.54, 270.0),
                model = 's_m_y_xmech_01',
                label = 'Atiduoti mašiną detalėms',
                scenario = 'WORLD_HUMAN_CLIPBOARD',
            },
            buyer = {
                coords = vector4(1211.0321, -3119.2507, 5.2528, 90.0),
                model = 's_m_y_construct_02',
                label = 'Laužo supirkėjas',
            },
        },
    },
}
