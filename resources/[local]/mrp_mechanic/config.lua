Config = {}

Config.JobName = 'mechanic'
Config.TargetDistance = 3.2

--- LS dokai — mechanikų bazė
Config.Base = vector4(153.8655, -3011.3054, 7.0409, 266.9864)

--- Viešas žemėlapio blipas (visiems)
Config.Blip = {
    sprite = 446,
    colour = 47,
    scale = 0.85,
    label = 'Mechanikų dirbtuvės',
    coords = vector3(128.5848, -3013.5708, 7.0409),
}

--- Vidiniai blipai — išjungta (naudok markerius / qb-target, ne žemėlapį)
Config.ShowMapBlips = false
Config.MapBlips = {
    { coords = vector3(125.9513, -3023.2095, 7.0409), sprite = 446, colour = 5, scale = 0.72, label = 'Tvarkymas / tuningas #1' },
    { coords = vector3(125.7720, -3034.8445, 7.0409), sprite = 446, colour = 5, scale = 0.72, label = 'Tvarkymas / tuningas #2' },
    { coords = vector3(126.1551, -3047.4792, 7.0409), sprite = 446, colour = 5, scale = 0.72, label = 'Tvarkymas / tuningas #3' },
    { coords = vector3(153.8655, -3011.3054, 7.0409), sprite = 366, colour = 47, scale = 0.7, label = 'Mechanikų persirengimas' },
    { coords = vector3(125.4779, -3007.6318, 7.8205), sprite = 521, colour = 46, scale = 0.72, label = 'Mechanikų vadovybė' },
    { coords = vector3(128.5848, -3013.5708, 7.0409), sprite = 478, colour = 47, scale = 0.72, label = 'Mechanikų sandėlis' },
    { coords = vector3(146.4569, -3007.8015, 7.0409), sprite = 587, colour = 46, scale = 0.72, label = 'Boso sandėlis' },
    { coords = vector3(138.9832, -3050.7783, 7.0409), sprite = 402, colour = 3, scale = 0.7, label = 'Tuningo dalių stalas' },
    { coords = vector3(134.7361, -3050.6108, 7.0409), sprite = 402, colour = 2, scale = 0.7, label = 'Montavimo rinkinių stalas' },
    { coords = vector3(141.4521, -3050.8920, 7.0409), sprite = 402, colour = 5, scale = 0.7, label = 'Taisymo rinkinių stalas' },
    { coords = vector3(130.8420, -3053.2180, 7.0409), sprite = 478, colour = 46, scale = 0.68, label = 'Žaliavų priėmimas' },
    { coords = vector3(154.5346, -3024.6370, 7.0409), sprite = 285, colour = 47, scale = 0.65, label = 'Garažo vartai #1' },
    { coords = vector3(154.3884, -3034.6260, 7.0409), sprite = 285, colour = 47, scale = 0.65, label = 'Garažo vartai #2' },
    { coords = vector3(154.6730, -3017.9270, 7.0430), sprite = 521, colour = 47, scale = 0.65, label = 'Įėjimo durys' },
}

--- Durų / vartų raktai (E arba qb-target) — tik mechanikams tarnyboje
Config.DoorToggleReach = 5.0
Config.DoorGroups = {
    {
        id = 'mech_garage_gate_1',
        label = 'Garažo vartai #1',
        doorType = 'garage_roll',
        interact = vector3(154.5346, -3024.6370, 7.0409),
        interactDist = 5.0,
        defaultLocked = true,
        entityScan = {
            center = vector3(154.5346, -3024.6370, 7.0409),
            radius = 5.5,
            maxCount = 2,
            models = {
                'denis3d_ts_gate',
                'po1_08_whouse_05',
                'prop_com_gar_door_01',
            },
        },
    },
    {
        id = 'mech_garage_gate_2',
        label = 'Garažo vartai #2',
        doorType = 'garage_roll',
        interact = vector3(154.3884, -3034.6260, 7.0409),
        interactDist = 5.0,
        defaultLocked = true,
        entityScan = {
            center = vector3(154.3884, -3034.6260, 7.0409),
            radius = 5.5,
            maxCount = 2,
            models = {
                'denis3d_ts_gate',
                'po1_08_whouse_05',
                'prop_com_gar_door_01',
            },
        },
    },
    {
        id = 'mech_entry_door',
        label = 'Įėjimo durys',
        doorType = 'entity',
        interact = vector3(154.6730, -3017.9270, 7.0430),
        interactDist = 4.0,
        defaultLocked = true,
        entityScan = {
            center = vector3(154.6730, -3017.9270, 7.0430),
            radius = 5.0,
            maxCount = 3,
            models = {
                'denis3d_ts_exteriorgate',
                'denis3d_ts_container_doors',
                'denis3d_ts_doorframe',
            },
        },
    },
}

--- Bendras sandėlis
Config.Stash = {
    coords = vector3(128.5848, -3013.5708, 7.0409),
    heading = 178.1475,
    stashId = 'mrp_mechanic_ls',
    label = 'Mechanikų sandėlis',
    maxweight = 4000000,
    slots = 80,
}

--- Boso sandėlis
Config.BossStash = {
    coords = vector3(146.4569, -3007.8015, 7.0409),
    heading = 85.3863,
    stashId = 'mrp_mechanic_boss_ls',
    label = 'Boso sandėlis',
    maxweight = 6000000,
    slots = 100,
}

--- Vadovybės meniu
Config.Management = {
    coords = vector3(125.4779, -3007.6318, 7.8205),
    heading = 343.4840,
}

--- Persirengimas / rūbinė
Config.Locker = {
    coords = vector3(153.8655, -3011.3054, 7.0409),
    heading = 266.9864,
}

--- Garažas + tarnybinio transporto pirkimas
Config.GarageHub = {
    coords = vector3(128.5848, -3013.5708, 7.0409),
    heading = 178.1475,
}

--- Remonto / tuning vietos
Config.RepairBays = {
    { coords = vector3(125.9513, -3023.2095, 7.0409), length = 5.4, width = 7.0, heading = 87.3217 },
    { coords = vector3(125.7720, -3034.8445, 7.0409), length = 5.4, width = 7.0, heading = 93.2096 },
    { coords = vector3(126.1551, -3047.4792, 7.0409), length = 5.4, width = 7.0, heading = 87.9093 },
}

Config.Permissions = {
    boss_menu = 4,
}

Config.CraftingStations = {
    {
        coords = vector3(138.9832, -3050.7783, 7.0409),
        heading = 177.6345,
        length = 1.9,
        width = 1.9,
        label = 'Tuningo dalių stalas',
        craftKind = 'tuning',
    },
    {
        coords = vector3(134.7361, -3050.6108, 7.0409),
        heading = 183.3353,
        length = 1.9,
        width = 1.9,
        label = 'Montavimo rinkinių stalas',
        craftKind = 'kits',
    },
    {
        coords = vector3(141.4521, -3050.8920, 7.0409),
        heading = 178.0,
        length = 1.9,
        width = 1.9,
        label = 'Taisymo rinkinių stalas',
        craftKind = 'repair',
    },
}

--- Žaliavų priėmimas iš kasėjų / pardavimas mechanikams
Config.MaterialSupply = {
    coords = vector3(130.8420, -3053.2180, 7.0409),
    heading = 88.0,
    length = 2.2,
    width = 2.4,
    label = 'Žaliavų priėmimo punktas',
    ped = {
        model = `s_m_m_lathandy_01`,
        coords = vector4(130.8420, -3053.2180, 7.0409, 88.0),
        scenario = 'WORLD_HUMAN_CLIPBOARD',
    },
}

--- Itemai, kuriuos galima parduoti / pirkti žaliavų punkte
Config.MechanicSupplyItems = {
    'iron_ore', 'iron', 'copper_ore', 'copper', 'aluminum_ore', 'aluminum',
    'steel', 'coal', 'rubber', 'glass', 'gravel', 'stone',
    'silver_ore', 'gold_ore',
}

--- Kainos, kai kasėjas parduoda mechanikų sandėliui ($ / vnt.)
Config.MechanicMaterialBuyPrices = {
    iron_ore = 22,
    iron = 38,
    copper_ore = 18,
    copper = 30,
    aluminum_ore = 20,
    aluminum = 34,
    steel = 68,
    coal = 6,
    rubber = 32,
    glass = 20,
    gravel = 4,
    stone = 5,
    silver_ore = 75,
    gold_ore = 190,
}

--- Mechanikų pirkimo kainos iš sandėlio ($ / vnt.)
Config.MechanicMaterialShopPrices = {
    iron_ore = 28,
    iron = 46,
    copper_ore = 24,
    copper = 36,
    aluminum_ore = 26,
    aluminum = 40,
    steel = 82,
    coal = 9,
    rubber = 38,
    glass = 24,
    gravel = 6,
    stone = 7,
    silver_ore = 90,
    gold_ore = 220,
}

--- Pradinis sandėlio likutis (kol kasėjai pradeda parduoti)
Config.MaterialSupplySeedStock = {
    iron = 12,
    copper = 10,
    aluminum = 8,
    steel = 15,
    rubber = 10,
    glass = 8,
    coal = 20,
    iron_ore = 16,
    copper_ore = 12,
    aluminum_ore = 10,
}

--- GTA mod lygis (0-based) -> item engine_upgrade_1 .. engine_upgrade_4
Config.TuningUpgradeItems = {
    [11] = { prefix = 'engine_upgrade', maxLevel = 4 },
    [12] = { prefix = 'brakes_upgrade', maxLevel = 3 },
    [13] = { prefix = 'transmission_upgrade', maxLevel = 3 },
    [15] = { prefix = 'suspension_upgrade', maxLevel = 4 },
    [16] = { prefix = 'armor_upgrade', maxLevel = 5 },
    [18] = { item = 'turbo_kit' },
}

Config.TuningRecipes = {
    engine_upgrade_1 = { label = 'Variklis I', output = 'engine_upgrade_1', count = 1, materials = { iron = 12, steel = 8, aluminum = 6, copper = 4, rubber = 2, glass = 1 } },
    engine_upgrade_2 = { label = 'Variklis II', output = 'engine_upgrade_2', count = 1, materials = { iron = 18, steel = 12, aluminum = 10, copper = 6, rubber = 4, glass = 1 } },
    engine_upgrade_3 = { label = 'Variklis III', output = 'engine_upgrade_3', count = 1, materials = { iron = 22, steel = 16, aluminum = 14, copper = 10, rubber = 6, glass = 2 } },
    engine_upgrade_4 = { label = 'Variklis IV', output = 'engine_upgrade_4', count = 1, materials = { iron = 28, steel = 20, aluminum = 18, copper = 12, rubber = 8, glass = 2 } },
    brakes_upgrade_1 = { label = 'Stabdžiai I', output = 'brakes_upgrade_1', count = 1, materials = { iron = 8, steel = 10, aluminum = 5, copper = 3, rubber = 10, glass = 1 } },
    brakes_upgrade_2 = { label = 'Stabdžiai II', output = 'brakes_upgrade_2', count = 1, materials = { iron = 12, steel = 14, aluminum = 8, copper = 4, rubber = 14, glass = 1 } },
    brakes_upgrade_3 = { label = 'Stabdžiai III', output = 'brakes_upgrade_3', count = 1, materials = { iron = 16, steel = 18, aluminum = 10, copper = 5, rubber = 18, glass = 2 } },
    transmission_upgrade_1 = { label = 'Pavaros I', output = 'transmission_upgrade_1', count = 1, materials = { iron = 10, steel = 12, aluminum = 8, copper = 5, rubber = 4, glass = 0 } },
    transmission_upgrade_2 = { label = 'Pavaros II', output = 'transmission_upgrade_2', count = 1, materials = { iron = 16, steel = 16, aluminum = 12, copper = 7, rubber = 6, glass = 1 } },
    transmission_upgrade_3 = { label = 'Pavaros III', output = 'transmission_upgrade_3', count = 1, materials = { iron = 22, steel = 20, aluminum = 14, copper = 9, rubber = 8, glass = 1 } },
    suspension_upgrade_1 = { label = 'Pakaba I', output = 'suspension_upgrade_1', count = 1, materials = { iron = 8, steel = 7, aluminum = 5, copper = 2, rubber = 12, glass = 0 } },
    suspension_upgrade_2 = { label = 'Pakaba II', output = 'suspension_upgrade_2', count = 1, materials = { iron = 12, steel = 10, aluminum = 8, copper = 3, rubber = 16, glass = 0 } },
    suspension_upgrade_3 = { label = 'Pakaba III', output = 'suspension_upgrade_3', count = 1, materials = { iron = 15, steel = 12, aluminum = 10, copper = 3, rubber = 18, glass = 0 } },
    suspension_upgrade_4 = { label = 'Pakaba IV', output = 'suspension_upgrade_4', count = 1, materials = { iron = 18, steel = 14, aluminum = 12, copper = 4, rubber = 20, glass = 0 } },
    armor_upgrade_1 = { label = 'Šarvai I', output = 'armor_upgrade_1', count = 1, materials = { iron = 15, steel = 14, aluminum = 6, copper = 2, rubber = 4, glass = 0 } },
    armor_upgrade_2 = { label = 'Šarvai II', output = 'armor_upgrade_2', count = 1, materials = { iron = 20, steel = 18, aluminum = 8, copper = 3, rubber = 6, glass = 0 } },
    armor_upgrade_3 = { label = 'Šarvai III', output = 'armor_upgrade_3', count = 1, materials = { iron = 25, steel = 22, aluminum = 10, copper = 4, rubber = 8, glass = 0 } },
    armor_upgrade_4 = { label = 'Šarvai IV', output = 'armor_upgrade_4', count = 1, materials = { iron = 28, steel = 26, aluminum = 12, copper = 4, rubber = 10, glass = 0 } },
    armor_upgrade_5 = { label = 'Šarvai V', output = 'armor_upgrade_5', count = 1, materials = { iron = 32, steel = 30, aluminum = 14, copper = 5, rubber = 12, glass = 0 } },
    engine_kit = {
        label = 'Variklio rinkinys',
        output = 'engine_kit',
        count = 1,
        materials = { iron = 25, steel = 18, aluminum = 15, copper = 12, rubber = 8, glass = 2 },
    },
    brakes_kit = {
        label = 'Stabdžių rinkinys',
        output = 'brakes_kit',
        count = 1,
        materials = { iron = 14, steel = 18, aluminum = 10, copper = 5, rubber = 15, glass = 2 },
    },
    transmission_kit = {
        label = 'Pavarų dėžės rinkinys',
        output = 'transmission_kit',
        count = 1,
        materials = { iron = 20, steel = 20, aluminum = 14, copper = 8, rubber = 8, glass = 1 },
    },
    suspension_kit = {
        label = 'Pakabos rinkinys',
        output = 'suspension_kit',
        count = 1,
        materials = { iron = 15, steel = 14, aluminum = 10, copper = 3, rubber = 18, glass = 0 },
    },
    armor_kit = {
        label = 'Šarvų rinkinys',
        output = 'armor_kit',
        count = 1,
        materials = { iron = 30, steel = 28, aluminum = 12, copper = 4, rubber = 10, glass = 0 },
    },
    turbo_kit = {
        label = 'Turbo rinkinys',
        output = 'turbo_kit',
        count = 1,
        materials = { iron = 15, steel = 16, aluminum = 14, copper = 16, rubber = 7, glass = 2 },
    },
}

--- Crafting UI kategorijų aprašymai (tik sąsajai — jokio level / XP)
Config.CraftCategoryMeta = {
    engine = { label = 'Variklis', desc = 'Padidina automobilio galią ir pagreitėjimą.' },
    turbo = { label = 'Turbina', desc = 'Suteikia automobiliui turbo galią.' },
    transmission = { label = 'Pavarų dėžė', desc = 'Pagerina pavarų perjungimą ir pagreitėjimą.' },
    suspension = { label = 'Pakaba', desc = 'Pakeičia automobilio pakabos lygį.' },
    brakes = { label = 'Stabdžiai', desc = 'Pagerina automobilio stabdymą.' },
    armor = { label = 'Šarvai', desc = 'Padidina transporto priemonės atsparumą.' },
    repair_kits = { label = 'Taisymo rinkiniai', desc = 'Remonto ir padangų taisymo rinkiniai.' },
}

Config.CraftMaxBatch = 10

Config.RepairKitRecipes = {
    repairkit = {
        label = 'Remonto rinkinys',
        output = 'repairkit',
        count = 1,
        materials = { iron = 4, steel = 2, rubber = 3, glass = 1 },
    },
    tirerepairkit = {
        label = 'Padangų remonto rinkinys',
        output = 'tirerepairkit',
        count = 1,
        materials = { rubber = 6, steel = 1, iron = 2 },
    },
    advancedrepairkit = {
        label = 'Pažangus remonto rinkinys',
        output = 'advancedrepairkit',
        count = 1,
        materials = { iron = 8, steel = 6, aluminum = 4, copper = 3, rubber = 5, glass = 2 },
    },
}

--- Tarnybinė apranga — kategorijos atskirai (viršus / kelnės)
Config.DutyOutfits = {
    {
        label = 'Kombinezonas 1 — viršus',
        description = 'Darbinė striukė',
        category = 'uniform_top',
        minGrade = 0,
        male = { components = { [8] = 59, [11] = 56 } },
        female = { components = { [8] = 36, [11] = 49 } },
    },
    {
        label = 'Kombinezonas 1 — kelnės',
        description = 'Darbinės kelnės ir batai',
        category = 'uniform_pants',
        minGrade = 0,
        male = { components = { [4] = 39, [6] = 25 } },
        female = { components = { [4] = 39, [6] = 25 } },
    },
    {
        label = 'Kombinezonas 2 — viršus',
        description = 'Darbinė striukė + pirštinės',
        category = 'uniform_top',
        minGrade = 1,
        male = { components = { [8] = 59, [11] = 57 } },
        female = { components = { [8] = 36, [11] = 50 } },
    },
    {
        label = 'Kombinezonas 2 — kelnės',
        description = 'Darbinės kelnės ir batai',
        category = 'uniform_pants',
        minGrade = 1,
        male = { components = { [4] = 39, [6] = 24 } },
        female = { components = { [4] = 39, [6] = 24 } },
    },
}

--- Laikinas testavimo NPC: $1 rinkinys (žaliavos) + brangesnių kirtiklių meniu.
Config.DebugSandboxVendor = {
    enabled = false,
    pedModel = `s_m_y_construct_02`,
    coords = vector4(132.0, -3018.0, 7.04, 178.0),
    scenario = 'WORLD_HUMAN_CLIPBOARD',
    bundlePrice = 1,
}

--- item -> kiek (stack vienam pirkiniui — testams)
Config.DebugSandboxBundleItems = {
    { item = 'stone_raw', amount = 20 }, { item = 'stone', amount = 20 },
    { item = 'coal_raw', amount = 20 }, { item = 'coal', amount = 20 },
    { item = 'gravel_raw', amount = 20 }, { item = 'gravel', amount = 20 },
    { item = 'iron_ore_raw', amount = 20 }, { item = 'iron_ore', amount = 20 },
    { item = 'copper_ore_raw', amount = 20 }, { item = 'copper_ore', amount = 20 },
    { item = 'aluminum_ore_raw', amount = 20 }, { item = 'aluminum_ore', amount = 20 },
    { item = 'silver_ore_raw', amount = 10 }, { item = 'silver_ore', amount = 10 },
    { item = 'gold_ore_raw', amount = 10 }, { item = 'gold_ore', amount = 10 },
    { item = 'diamond_raw', amount = 3 }, { item = 'diamond', amount = 3 },
    { item = 'emerald_raw', amount = 3 }, { item = 'emerald', amount = 3 },
    { item = 'ruby_raw', amount = 3 }, { item = 'ruby', amount = 3 },
    { item = 'sapphire_raw', amount = 3 }, { item = 'sapphire', amount = 3 },
    { item = 'mystery_ore_raw', amount = 5 }, { item = 'mystery_ore', amount = 5 },
    { item = 'artifact_raw', amount = 5 }, { item = 'artifact', amount = 5 },
    { item = 'steel', amount = 25 }, { item = 'rubber', amount = 25 }, { item = 'glass', amount = 25 },
}

Config.DebugPickaxeOffers = {
    { item = 'mining_pickaxe', label = 'Kirtiklis', price = 320 },
}

Config.DebugSandboxSupplyShop = {
    name = 'mrp_mech_debug_supplies',
    label = 'Sandbox: zaliavu test shop',
}

Config.DebugSandboxPickaxeShop = {
    name = 'mrp_mech_debug_pickaxes',
    label = 'Sandbox: kirtikliu test shop',
}
