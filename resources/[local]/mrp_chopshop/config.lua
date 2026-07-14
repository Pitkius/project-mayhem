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

    --- Dalių kiekiai pagal tier (brangesnė mašina = daugiau / geresnių dalių)
    tierParts = {
        budget = {
            { item = 'metalscrap', min = 3, max = 6 },
            { item = 'plastic',    min = 1, max = 3 },
            { item = 'rubber',     min = 1, max = 2 },
        },
        mid = {
            { item = 'metalscrap', min = 5, max = 9 },
            { item = 'aluminum',   min = 2, max = 4 },
            { item = 'plastic',    min = 2, max = 4 },
            { item = 'rubber',     min = 2, max = 3 },
        },
        premium = {
            { item = 'metalscrap', min = 7, max = 12 },
            { item = 'aluminum',   min = 4, max = 7 },
            { item = 'steel',      min = 2, max = 4 },
            { item = 'rubber',     min = 3, max = 5 },
        },
        luxury = {
            { item = 'metalscrap', min = 10, max = 16 },
            { item = 'aluminum',   min = 6, max = 10 },
            { item = 'steel',      min = 4, max = 8 },
            { item = 'rubber',     min = 4, max = 6 },
        },
    },

    --- NPC mašinos gauna mažiau dalių (multiplier)
    npcPartsMultiplier = 0.55,

    --- Dalių supirkėjas — kainos už vnt. (nešvarūs pinigai per markedbills)
    buyerPrices = {
        metalscrap = 85,
        aluminum   = 140,
        steel      = 220,
        plastic    = 60,
        rubber     = 75,
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
            buyer = {
                coords = vector4(2334.12, 3047.88, 48.15, 270.0),
                model = 's_m_y_construct_01',
                label = 'Laužo supirkėjas',
            },
        },
        {
            id = 'ls_docks',
            label = 'Ardymo aikštelė · LS dokai',
            coords = vector3(1175.55, -3196.67, 6.03),
            heading = 90.0,
            zoneRadius = 20.0,
            scrapCoords = vector3(1175.55, -3196.67, 6.03),
            buyer = {
                coords = vector4(1182.40, -3198.20, 6.03, 90.0),
                model = 's_m_y_construct_02',
                label = 'Laužo supirkėjas',
            },
        },
    },
}
