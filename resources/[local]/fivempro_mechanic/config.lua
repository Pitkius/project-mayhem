Config = {}

Config.JobName = 'mechanic'
Config.TargetDistance = 3.2

--- Blipas ir tarnybos taškas – prie garažo (6 nuotrauka)
Config.Base = vector4(-350.41, -117.01, 38.95, 246.37)

Config.Blip = {
    sprite = 446,
    colour = 47,
    scale = 0.85,
    label = 'Mechanikų dirbtuvės',
}

--- Sandėlis / įrankiai (5 nuotrauka)
Config.Stash = {
    coords = vector3(-319.45, -132.02, 38.98),
    heading = 260.38,
    stashId = 'fivempro_mechanic_ls',
    label = 'Mechanikų sandėlis',
    maxweight = 4000000,
    slots = 80,
}

--- Vadovybės meniu (4 nuotrauka)
Config.Management = {
    coords = vector3(-323.52, -129.54, 39.01),
    heading = 335.34,
}

--- Persirengimas / rūbinė (1 nuotrauka)
Config.Locker = {
    coords = vector3(-345.48, -122.90, 39.01),
    heading = 66.30,
}

--- Garažas + tarnybinio transporto pirkimas (6 nuotrauka)
Config.GarageHub = {
    coords = vector3(-350.41, -117.01, 38.95),
    heading = 246.37,
}

--- Remonto vietos (2 ir 3 nuotraukos)
Config.RepairBays = {
    { coords = vector3(-340.89, -128.34, 39.01), length = 5.2, width = 6.8, heading = 161.82 },
    { coords = vector3(-330.82, -131.43, 39.01), length = 5.2, width = 6.8, heading = 156.15 },
}

Config.Permissions = {
    boss_menu = 4,
}

Config.CraftingStations = {
    { coords = vector3(-325.52, -136.11, 39.01), heading = 159.0, length = 1.8, width = 1.8, label = 'Tuningo dalių staklės' },
}

Config.TuningRecipes = {
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

--- Tarnybinė apranga (komponentai mp freemode – keisk pagal odę)
Config.DutyOutfits = {
    {
        label = 'Darbinė kombinezonas 1',
        minGrade = 0,
        male = { [4] = 39, [6] = 25, [8] = 59, [11] = 56, [9] = 0 },
        female = { [4] = 39, [6] = 25, [8] = 36, [11] = 49, [9] = 0 },
    },
    {
        label = 'Darbinė kombinezonas 2 + pirštinės',
        minGrade = 1,
        male = { [4] = 39, [6] = 24, [8] = 59, [11] = 57, [9] = 0 },
        female = { [4] = 39, [6] = 24, [8] = 36, [11] = 50, [9] = 0 },
    },
}

--- Laikinas testavimo NPC: $1 rinkinys (žaliavos) + brangesnių kirtiklių meniu.
Config.DebugSandboxVendor = {
    enabled = true,
    pedModel = `s_m_y_construct_02`,
    coords = vector4(-334.94, -127.18, 39.02, 158.0),
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
    { item = 'mining_pickaxe', label = 'Kirtiklis I — pradinis', price = 320 },
    { item = 'mining_pickaxe_tier2', label = 'Kirtiklis II — patikimesnis', price = 980 },
    { item = 'mining_pickaxe_tier3', label = 'Kirtiklis III — darbo klase', price = 2650 },
    { item = 'mining_pickaxe_tier4', label = 'Kirtiklis IV — pramoninis', price = 6200 },
    { item = 'mining_pickaxe_tier5', label = 'Kirtiklis V — elitas', price = 14500 },
}
