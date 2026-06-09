Config = {}

--- LS oro uostas — testų eilė statmena žaidėjo krypčiai (kairė–dešinė)
local DEV_CENTER = vector3(-886.92, -3208.01, 13.94)
local DEV_ROW_H = 239.51

local function devRow(offset)
    local h = math.rad(DEV_ROW_H)
    return vector3(
        DEV_CENTER.x + math.cos(h) * offset,
        DEV_CENTER.y + math.sin(h) * offset,
        DEV_CENTER.z
    )
end

--- Production: false. Test NPC + nemokami itemai tik testavimui.
Config.EnableDrugTestNPC = true

Config.DrawDistance = 28.0
Config.InteractDistance = 2.0

--- Vienas blipas visai testų zonai (ne po kiekvienos stoties)
Config.ShowStationBlips = true
Config.StationBlip = {
    sprite = 496,
    color = 27,
    scale = 0.85,
    shortRange = true,
    label = 'Test: LS oro uostas',
}

--- Visos stočių zonos vienoje eilėje (LS airport)
Config.DevHub = {
    center = DEV_CENTER,
    blipCoords = DEV_CENTER,
    rowHeading = DEV_ROW_H,
    spacing = 3.5,
}
Config.CraftCooldownMs = 4500
Config.SellCooldownMs = 6000

--- Minigame tipai: progress | skill | advanced
Config.LevelLabels = {
    [1] = '1 lygis — startas',
    [2] = '2 lygis — vidutinis',
    [3] = '3 lygis — aukštas',
}

Config.RiskLabels = {
    low = 'Žema',
    medium = 'Vidutinė',
    high = 'Aukšta',
    extreme = 'Labai aukšta',
}

--[[
  Produktai: output = item name, level = stoties lygis, recipe key = product id
]]
Config.Products = {
    thc_cart = {
        label = 'THC kronštainas',
        level = 1,
        output = 'thc_cart',
        outputAmount = 1,
        craftTimeMs = 25000,
        risk = 'low',
        minigame = 'progress',
        failChance = 6,
        policeChance = 4,
        heatGain = 2,
        sellBase = 95,
        failLosePercent = 40,
    },
    illegal_alcohol = {
        label = 'Nelegalus alkoholis',
        level = 1,
        output = 'illegal_alcohol',
        outputAmount = 1,
        craftTimeMs = 22000,
        risk = 'low',
        minigame = 'progress',
        failChance = 5,
        policeChance = 3,
        heatGain = 2,
        sellBase = 75,
        failLosePercent = 35,
    },
    vape_liquid = {
        label = 'Vape skystis',
        level = 1,
        output = 'vape_liquid',
        outputAmount = 2,
        craftTimeMs = 20000,
        risk = 'low',
        minigame = 'progress',
        failChance = 5,
        policeChance = 3,
        heatGain = 1,
        sellBase = 65,
        failLosePercent = 30,
    },
    weed_bag = {
        label = 'Žolės maišelis',
        level = 2,
        output = 'weed_bag',
        outputAmount = 1,
        craftTimeMs = 30000,
        risk = 'medium',
        minigame = 'skill',
        failChance = 12,
        policeChance = 8,
        heatGain = 4,
        sellBase = 140,
        failLosePercent = 50,
    },
    heroin_bag = {
        label = 'Heroino maišelis',
        level = 2,
        output = 'heroin_bag',
        outputAmount = 1,
        craftTimeMs = 35000,
        risk = 'medium',
        minigame = 'skill',
        failChance = 14,
        policeChance = 10,
        heatGain = 5,
        sellBase = 220,
        failLosePercent = 55,
    },
    meth_bag = {
        label = 'Metamfetamino maišelis',
        level = 2,
        output = 'meth_bag',
        outputAmount = 1,
        craftTimeMs = 40000,
        risk = 'high',
        minigame = 'skill',
        failChance = 15,
        policeChance = 12,
        heatGain = 6,
        sellBase = 260,
        failLosePercent = 60,
    },
    pills_pack = {
        label = 'Tablečių pakuotė',
        level = 2,
        output = 'pills_pack',
        outputAmount = 1,
        craftTimeMs = 28000,
        risk = 'medium',
        minigame = 'skill',
        failChance = 11,
        policeChance = 7,
        heatGain = 4,
        sellBase = 180,
        failLosePercent = 45,
    },
    mushroom_pack = {
        label = 'Grybų pakuotė',
        level = 2,
        output = 'mushroom_pack',
        outputAmount = 1,
        craftTimeMs = 26000,
        risk = 'medium',
        minigame = 'skill',
        failChance = 10,
        policeChance = 6,
        heatGain = 3,
        sellBase = 150,
        failLosePercent = 40,
    },
    cocaine_bag = {
        label = 'Kokaino maišelis',
        level = 3,
        output = 'cocaine_bag',
        outputAmount = 1,
        craftTimeMs = 50000,
        risk = 'high',
        minigame = 'advanced',
        failChance = 22,
        policeChance = 16,
        heatGain = 8,
        sellBase = 420,
        failLosePercent = 70,
    },
    amphetamine_bag = {
        label = 'Amfetamino maišelis',
        level = 3,
        output = 'amphetamine_bag',
        outputAmount = 1,
        craftTimeMs = 45000,
        risk = 'high',
        minigame = 'advanced',
        failChance = 20,
        policeChance = 14,
        heatGain = 7,
        sellBase = 380,
        failLosePercent = 65,
    },
    cartel_pack = {
        label = 'Kartelio specialus mišinys',
        level = 3,
        output = 'cartel_pack',
        outputAmount = 1,
        craftTimeMs = 55000,
        risk = 'extreme',
        minigame = 'advanced',
        failChance = 25,
        policeChance = 20,
        heatGain = 10,
        sellBase = 520,
        failLosePercent = 75,
    },
}

Config.Recipes = {
    thc_cart = {
        { item = 'weed_leaf', count = 2 },
        { item = 'empty_cart', count = 1 },
        { item = 'filter', count = 1 },
        { item = 'packaging', count = 1 },
    },
    illegal_alcohol = {
        { item = 'alcohol_base', count = 2 },
        { item = 'empty_bottle', count = 1 },
        { item = 'packaging', count = 1 },
    },
    vape_liquid = {
        { item = 'vape_liquid_base', count = 2 },
        { item = 'empty_bottle', count = 1 },
        { item = 'packaging', count = 1 },
    },
    weed_bag = {
        { item = 'weed_leaf', count = 5 },
        { item = 'empty_bag', count = 1 },
        { item = 'scale', count = 1 },
        { item = 'packaging', count = 1 },
    },
    heroin_bag = {
        { item = 'poppy_flower', count = 4 },
        { item = 'chemical_mix', count = 1 },
        { item = 'empty_bag', count = 1 },
        { item = 'scale', count = 1 },
    },
    meth_bag = {
        { item = 'meth_ingredient', count = 3 },
        { item = 'chemical_mix', count = 2 },
        { item = 'lab_kit', count = 1 },
        { item = 'empty_bag', count = 1 },
    },
    pills_pack = {
        { item = 'pill_powder', count = 3 },
        { item = 'packaging', count = 2 },
        { item = 'empty_bag', count = 1 },
    },
    mushroom_pack = {
        { item = 'mushroom_raw', count = 4 },
        { item = 'packaging', count = 1 },
        { item = 'empty_bag', count = 1 },
    },
    cocaine_bag = {
        { item = 'coca_leaf', count = 6 },
        { item = 'chemical_mix', count = 2 },
        { item = 'empty_bag', count = 1 },
        { item = 'scale', count = 1 },
    },
    amphetamine_bag = {
        { item = 'meth_ingredient', count = 2 },
        { item = 'pill_powder', count = 2 },
        { item = 'chemical_mix', count = 2 },
        { item = 'lab_kit', count = 1 },
        { item = 'empty_bag', count = 1 },
    },
    cartel_pack = {
        { item = 'coca_leaf', count = 4 },
        { item = 'pill_powder', count = 3 },
        { item = 'chemical_mix', count = 3 },
        { item = 'lab_kit', count = 1 },
        { item = 'packaging', count = 2 },
    },
}

--- Gamybos vietos — LS airport eilėje (žr. Config.DevHub)
Config.Stations = {
    { id = 'stash_grove', label = 'L1 · Sandėliukas', level = 1, coords = devRow(-10.5), radius = 2.2, blip = false },
    { id = 'garage_davis', label = 'L1 · Garažas', level = 1, coords = devRow(-7.0), radius = 2.2, blip = false },
    { id = 'trap_chamberlain', label = 'L2 · Trap house', level = 2, coords = devRow(-3.5), radius = 2.2, blip = false },
    { id = 'gang_base', label = 'L2 · Gaujos bazė', level = 2, coords = devRow(0.0), radius = 2.2, blip = false },
    { id = 'lab_sandy', label = 'L2 · Laboratorija', level = 2, coords = devRow(3.5), radius = 2.2, blip = false },
    { id = 'cartel_lab', label = 'L3 · Kartelis', level = 3, coords = devRow(7.0), radius = 2.2, blip = false },
    { id = 'secret_humane', label = 'L3 · Slapta lab.', level = 3, coords = devRow(10.5), radius = 2.2, blip = false },
    { id = 'weapon_bench', label = 'Ginklų dirbtuvė', level = 1, mode = 'weapon', coords = devRow(17.5), radius = 2.2, blip = false },
}

--- Ginklų gamyba (atskira stotis, mode = weapon)
Config.WeaponProducts = {
    craft_pistol = {
        label = 'Pistoletas',
        level = 1,
        output = 'weapon_pistol',
        outputAmount = 1,
        bonusItems = { { item = 'pistol_ammo', count = 60 } },
        craftTimeMs = 38000,
        risk = 'high',
        minigame = 'skill',
        failChance = 16,
        policeChance = 14,
        heatGain = 4,
        sellBase = 0,
        failLosePercent = 55,
    },
    craft_smg = {
        label = 'SMG',
        level = 1,
        output = 'weapon_smg',
        outputAmount = 1,
        bonusItems = { { item = 'smg_ammo', count = 90 } },
        craftTimeMs = 48000,
        risk = 'high',
        minigame = 'advanced',
        failChance = 20,
        policeChance = 18,
        heatGain = 6,
        sellBase = 0,
        failLosePercent = 60,
    },
    craft_rifle = {
        label = 'Karabinas',
        level = 1,
        output = 'weapon_carbinerifle',
        outputAmount = 1,
        bonusItems = { { item = 'rifle_ammo', count = 90 } },
        craftTimeMs = 55000,
        risk = 'extreme',
        minigame = 'advanced',
        failChance = 22,
        policeChance = 20,
        heatGain = 8,
        sellBase = 0,
        failLosePercent = 65,
    },
}

Config.WeaponRecipes = {
    craft_pistol = {
        { item = 'gun_frame', count = 1 },
        { item = 'gun_barrel', count = 1 },
        { item = 'gun_spring', count = 2 },
        { item = 'gun_trigger', count = 1 },
        { item = 'metal_scrap', count = 4 },
    },
    craft_smg = {
        { item = 'gun_frame', count = 2 },
        { item = 'gun_barrel', count = 2 },
        { item = 'gun_spring', count = 4 },
        { item = 'gun_trigger', count = 2 },
        { item = 'weapon_parts', count = 3 },
        { item = 'metal_scrap', count = 8 },
    },
    craft_rifle = {
        { item = 'gun_frame', count = 2 },
        { item = 'gun_barrel', count = 2 },
        { item = 'gun_spring', count = 3 },
        { item = 'gun_trigger', count = 2 },
        { item = 'weapon_parts', count = 5 },
        { item = 'metal_scrap', count = 10 },
    },
}

--- Parduotuvė: visi craft ingredientai (qb-inventory shop)
Config.MaterialShop = {
    name = 'fivempro-illegal-supply',
    label = 'Nelegalūs reikmenys',
    items = {
        -- L1 narkotikai
        { name = 'weed_leaf', amount = 500, price = 22, slot = 1 },
        { name = 'alcohol_base', amount = 500, price = 18, slot = 2 },
        { name = 'vape_liquid_base', amount = 500, price = 16, slot = 3 },
        { name = 'empty_cart', amount = 500, price = 12, slot = 4 },
        { name = 'empty_bottle', amount = 500, price = 10, slot = 5 },
        { name = 'filter', amount = 500, price = 8, slot = 6 },
        { name = 'packaging', amount = 500, price = 9, slot = 7 },
        -- L2 narkotikai
        { name = 'poppy_flower', amount = 500, price = 28, slot = 8 },
        { name = 'meth_ingredient', amount = 500, price = 35, slot = 9 },
        { name = 'pill_powder', amount = 500, price = 30, slot = 10 },
        { name = 'mushroom_raw', amount = 500, price = 24, slot = 11 },
        { name = 'chemical_mix', amount = 500, price = 40, slot = 12 },
        { name = 'empty_bag', amount = 500, price = 11, slot = 13 },
        { name = 'scale', amount = 100, price = 85, slot = 14 },
        { name = 'lab_kit', amount = 50, price = 220, slot = 15 },
        { name = 'gloves', amount = 200, price = 25, slot = 16 },
        -- L3 narkotikai
        { name = 'coca_leaf', amount = 500, price = 45, slot = 17 },
        { name = 'burner', amount = 100, price = 120, slot = 18 },
        -- Ginklų dalys
        { name = 'metal_scrap', amount = 500, price = 35, slot = 19 },
        { name = 'gun_frame', amount = 200, price = 140, slot = 20 },
        { name = 'gun_barrel', amount = 200, price = 165, slot = 21 },
        { name = 'gun_spring', amount = 500, price = 28, slot = 22 },
        { name = 'gun_trigger', amount = 300, price = 55, slot = 23 },
        { name = 'weapon_parts', amount = 300, price = 95, slot = 24 },
        -- Kulkos (papildomai)
        { name = 'pistol_ammo', amount = 500, price = 12, slot = 25 },
        { name = 'smg_ammo', amount = 500, price = 18, slot = 26 },
        { name = 'rifle_ammo', amount = 500, price = 22, slot = 27 },
    },
}

Config.Sell = {
    maxDistanceToPed = 3.0,
    refuseChance = 18,
    panicChance = 8,
    policeCallChance = 12,
    reputationPriceFactor = 0.004,
    influencePerSale = 2,
    heatPerSale = 3,
    requireGangForInfluence = true,
    allowSellWithoutGang = true,
    basePriceMultiplier = 1.0,
}

Config.PoliceAlerts = {
    craft_fail = 'Įtartinas cheminis kvapas rajone',
    craft_high = 'Galima nelegali laboratorija',
    npc_call = 'Civilis pranešė apie nelegalią veiklą',
    npc_panic = 'Galimas narkotikų pardavimas',
    heat_spike = 'Per daug narkotikų sandorių zonoje',
    sell_burst = 'Įtartina narkotikų veikla',
}

local DRUG_TEST_POS = devRow(-14.0)
local SUPPLY_SHOP_POS = devRow(-17.5)

Config.TestNPC = {
    model = 's_m_y_dealer_01',
    coords = vector4(DRUG_TEST_POS.x, DRUG_TEST_POS.y, DRUG_TEST_POS.z, 149.51),
    scenario = 'WORLD_HUMAN_STAND_MOBILE',
    label = 'Narkotikų gamyba',
    blip = false,
}

--- Ingredientų parduotuvė (qb-inventory shop UI)
Config.SupplyShopNPC = {
    model = 's_m_m_linecook',
    coords = vector4(SUPPLY_SHOP_POS.x, SUPPLY_SHOP_POS.y, SUPPLY_SHOP_POS.z, 149.51),
    scenario = 'WORLD_HUMAN_STAND_MOBILE',
    label = 'Nelegalūs reikmenys',
    blip = false,
}

--- Test meniu — duoda itemus / atidaro UI
Config.TestKits = {
    level1 = {
        weed_leaf = 20, alcohol_base = 10, vape_liquid_base = 10,
        empty_cart = 10, empty_bottle = 10, filter = 10, packaging = 20,
    },
    level2 = {
        weed_leaf = 30, poppy_flower = 20, meth_ingredient = 15, pill_powder = 15,
        mushroom_raw = 15, chemical_mix = 15, empty_bag = 15, scale = 5,
        lab_kit = 3, packaging = 20, gloves = 5,
    },
    level3 = {
        coca_leaf = 25, chemical_mix = 20, meth_ingredient = 10, pill_powder = 15,
        lab_kit = 5, empty_bag = 15, scale = 5, packaging = 20, burner = 3,
    },
}
