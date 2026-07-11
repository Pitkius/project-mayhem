--[[
  mrp_jobs — vaisiai + vaisinis vape (shared).
  Modulinis vaisių modelis: naują vaisių pridėti pakanka įrašo Config.Fruits ir
  Config.VapeFlavors. Rišasi su esamu mrp_drugs vape pipeline (vape_liquid_base).
]]

Config = Config or {}

-- ── Vaisių rūšys ──────────────────────────────────────────────────
Config.Fruits = {
    apple = {
        label = 'Obuolys',
        item = 'apple',
        harvestType = 'tree',                 -- medžių rinkimo animacija
        propModel = nil,                      -- nil = renkam nuo esamų world objektų / zonų
        minYield = 1,
        maxYield = 3,
        respawnTime = 300,                    -- sek. iki taško atsinaujinimo
        minigame = 'fruit_pick',              -- config/minigames.lua raktas
        boxItem = 'apple_crate',
        perBox = 12,                          -- kiek vaisių telpa į dėžę
        anim = { dict = 'amb@prop_human_movie_bulb@base', clip = 'base' },
        -- Rinkimo taškai (medžiai). Kiekvienas turi savo respawn būseną serveryje.
        locations = {
            vector3(2472.0, 4992.0, 46.6), vector3(2478.0, 4996.0, 46.6),
            vector3(2484.0, 5000.0, 46.6), vector3(2490.0, 5004.0, 46.6),
            vector3(2466.0, 4998.0, 46.6), vector3(2472.0, 5004.0, 46.6),
        },
        zoneRadius = 1.6,
    },
    strawberry = {
        label = 'Braškė',
        item = 'strawberry',
        harvestType = 'ground',               -- pritūpimo / rinkimo nuo žemės animacija
        propModel = nil,
        minYield = 1,
        maxYield = 4,
        respawnTime = 240,
        minigame = 'fruit_ground',
        boxItem = 'strawberry_crate',
        perBox = 16,
        anim = { dict = 'amb@world_human_gardener_plant@male@base', clip = 'base' },
        locations = {
            vector3(2455.0, 5010.0, 46.5), vector3(2459.0, 5014.0, 46.5),
            vector3(2463.0, 5018.0, 46.5), vector3(2451.0, 5014.0, 46.5),
            vector3(2455.0, 5018.0, 46.5), vector3(2459.0, 5022.0, 46.5),
        },
        zoneRadius = 1.3,
    },
}

-- ── Paprastas vape (be vaisių) ────────────────────────────────────
-- Trumpesnis, pigesnis kelias. Naudoja esamus mrp_drugs itemus.
Config.VapeSimple = {
    recipe = { { item = 'vape_liquid_base', count = 1 }, { item = 'empty_bottle', count = 1 } },
    output = 'vape_liquid',                   -- egzistuoja (mrp_drugs)
    outputAmount = 1,
    processTime = 7000,
    minigame = 'concentrate_wash',            -- lengvas, vienas etapas
    sellItem = 'vape_liquid',
}

-- ── Vaisinis vape ─────────────────────────────────────────────────
-- 1) Koncentrato gamyba iš vaisių (plovimas + spaudimas).
Config.Concentrates = {
    apple = {
        fruitItem = 'apple',
        fruitAmount = 5,
        output = 'apple_concentrate',
        steps = { 'concentrate_wash', 'concentrate_press' }, -- keli minigame etapai
        processTime = 10000,
    },
    strawberry = {
        fruitItem = 'strawberry',
        fruitAmount = 8,
        output = 'strawberry_concentrate',
        steps = { 'concentrate_wash', 'concentrate_press' },
        processTime = 12000,
    },
}

-- 2) Galutinis vaisinis vape skystis.
Config.VapeFlavors = {
    apple = {
        fruitItem = 'apple',
        fruitAmount = 5,
        concentrateItem = 'apple_concentrate',
        baseItem = 'vape_liquid_base',
        bottleItem = 'empty_bottle',
        finalItem = 'apple_vape_liquid',
        processTime = 12000,
        minigame = 'concentrate_press',
        valueMultiplier = 1.6,
    },
    strawberry = {
        fruitItem = 'strawberry',
        fruitAmount = 8,
        concentrateItem = 'strawberry_concentrate',
        baseItem = 'vape_liquid_base',
        bottleItem = 'empty_bottle',
        finalItem = 'strawberry_vape_liquid',
        processTime = 15000,
        minigame = 'concentrate_press',
        valueMultiplier = 1.8,
    },
}
