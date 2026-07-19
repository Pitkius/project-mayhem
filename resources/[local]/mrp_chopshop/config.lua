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

    --- Kainų tier'ai (pagal mrp_vehicle_perf / QBCore kainą) — trukmė + drop šansas
    priceTiers = {
        { id = 'budget',  minPrice = 0,       maxPrice = 49999,  scrapMs = 45000, label = 'Paprasta', chanceBonus = 0.00 },
        { id = 'mid',     minPrice = 50000,   maxPrice = 149999, scrapMs = 60000, label = 'Vidutinė', chanceBonus = 0.08 },
        { id = 'premium', minPrice = 150000,  maxPrice = 399999, scrapMs = 75000, label = 'Premium',  chanceBonus = 0.15 },
        { id = 'luxury',  minPrice = 400000,  maxPrice = 99999999, scrapMs = 90000, label = 'Prabangi', chanceBonus = 0.22 },
    },

    --- Detalės iš ardymo (ne visi krenta kiekvieną kartą)
    --- chance 0–1; brangesnės dalys — mažesnis šansas, didesnė kaina
    scrapParts = {
        { item = 'scrap_tire',          chance = 0.90, min = 1, max = 4 },
        { item = 'scrap_rim',           chance = 0.55, min = 1, max = 4 },
        { item = 'scrap_seat',          chance = 0.70, min = 1, max = 2 },
        { item = 'scrap_door',          chance = 0.55, min = 1, max = 2 },
        { item = 'scrap_hood',          chance = 0.45, min = 1, max = 1 },
        { item = 'scrap_bumper',        chance = 0.50, min = 1, max = 2 },
        { item = 'scrap_headlight',     chance = 0.60, min = 1, max = 2 },
        { item = 'scrap_mirror',        chance = 0.65, min = 1, max = 2 },
        { item = 'scrap_battery',       chance = 0.55, min = 1, max = 1 },
        { item = 'scrap_radiator',      chance = 0.40, min = 1, max = 1 },
        { item = 'scrap_brakes',        chance = 0.45, min = 1, max = 2 },
        { item = 'scrap_exhaust',       chance = 0.35, min = 1, max = 1 },
        { item = 'scrap_transmission',  chance = 0.28, min = 1, max = 1 },
        { item = 'scrap_engine',        chance = 0.22, min = 1, max = 1 },
        { item = 'scrap_catalytic',     chance = 0.18, min = 1, max = 1 },
    },

    --- NPC mašinos — mažesnis drop šansas
    npcPartsMultiplier = 0.70,

    --- Supirkimo kainos už vnt. (nešvarūs pinigai) — pagal dalies vertę
    buyerPrices = {
        scrap_tire         = 140,
        scrap_rim          = 320,
        scrap_seat         = 260,
        scrap_door         = 480,
        scrap_hood         = 520,
        scrap_bumper       = 380,
        scrap_headlight    = 180,
        scrap_mirror       = 120,
        scrap_battery      = 290,
        scrap_radiator     = 410,
        scrap_brakes       = 350,
        scrap_exhaust      = 460,
        scrap_transmission = 1100,
        scrap_engine       = 1800,
        scrap_catalytic    = 2400,
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
                label = 'Dalių supirkėjas',
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
                label = 'Dalių supirkėjas',
            },
        },
    },
}
