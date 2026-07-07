Config = {}

--- Karjero sienos — kasimas palei perimetrą (box zonos, ne vienas didelis apskritimas)
Config.MiningWalls = {
    { center = vector3(2954.0, 2852.0, 42.5), length = 95.0, width = 7.5, heading = 90.0, minZ = 38.0, maxZ = 52.0, label = 'Šiaurinė siena' },
    { center = vector3(2954.0, 2736.0, 42.5), length = 95.0, width = 7.5, heading = 90.0, minZ = 38.0, maxZ = 52.0, label = 'Pietinė siena' },
    { center = vector3(3008.0, 2794.0, 42.5), length = 110.0, width = 7.5, heading = 0.0, minZ = 38.0, maxZ = 52.0, label = 'Rytinė siena' },
    { center = vector3(2900.0, 2794.0, 42.5), length = 110.0, width = 7.5, heading = 0.0, minZ = 38.0, maxZ = 52.0, label = 'Vakarų siena' },
    { center = vector3(2922.0, 2842.0, 44.0), length = 55.0, width = 7.0, heading = 135.0, minZ = 38.0, maxZ = 52.0, label = 'ŠV kampas' },
    { center = vector3(2986.0, 2842.0, 44.0), length = 55.0, width = 7.0, heading = 45.0, minZ = 38.0, maxZ = 52.0, label = 'ŠR kampas' },
    { center = vector3(2922.0, 2746.0, 44.0), length = 55.0, width = 7.0, heading = 45.0, minZ = 38.0, maxZ = 52.0, label = 'PV kampas' },
    { center = vector3(2986.0, 2746.0, 44.0), length = 55.0, width = 7.0, heading = 135.0, minZ = 38.0, maxZ = 52.0, label = 'PR kampas' },
}

--- Senos didelės zonos (palikta serverio validacijai / blipui)
Config.MiningSites = {
    { coords = vector3(2954.0, 2794.0, 41.05), radius = 130.0, label = 'Karjeras — kasimas' },
}

--- Minigame nustatymai
Config.Minigame = {
    hits = 5,
    time = 12,
    speed = 0.88,
}

--- Kasimo animacija po sėkmingo minigame (ms)
Config.MineAnimDuration = 3200
Config.ProcessCoords = vector4(1087.67, -2004.92, 31.16, 54.20)

--- Supirkėjas (NPC) — šalia pramonės / laužo (galima keisti)
Config.SellPed = {
    coords = vector4(1098.42, -1995.88, 30.48, 235.0),
    model = `s_m_y_construct_01`,
    scenario = 'WORLD_HUMAN_CLIPBOARD',
}

--- Blipai
Config.Blips = {
    mining = { sprite = 618, colour = 47, scale = 0.85, label = 'Karjeras — kasimas' },
    process = { sprite = 566, colour = 47, scale = 0.82, label = 'Rūdų perdirbimas' },
    sell = { sprite = 500, colour = 2, scale = 0.82, label = 'Metalų supirkimas' },
}

--- Kasimo laikas (ms), cooldown (s)
Config.MineDuration = 8500
Config.MineCooldown = 8
Config.SellAnimDuration = 2800

--- Drop šansai
Config.MineLoot = {
    { item = 'stone_raw', weight = 28 },
    { item = 'coal_raw', weight = 22 },
    { item = 'gravel_raw', weight = 18 },
    { item = 'iron_ore_raw', weight = 12 },
    { item = 'copper_ore_raw', weight = 8 },
    { item = 'aluminum_ore_raw', weight = 6 },
    { item = 'silver_ore_raw', weight = 3 },
    { item = 'gold_ore_raw', weight = 2 },
    { item = 'diamond_raw', weight = 0.45 },
    { item = 'emerald_raw', weight = 0.45 },
    { item = 'ruby_raw', weight = 0.45 },
    { item = 'sapphire_raw', weight = 0.45 },
    { item = 'mystery_ore_raw', weight = 0.35 },
    { item = 'artifact_raw', weight = 0.25 },
}

--- Žalia → švari (1:1)
Config.ProcessMap = {
    stone_raw = 'stone',
    coal_raw = 'coal',
    gravel_raw = 'gravel',
    iron_ore_raw = 'iron_ore',
    copper_ore_raw = 'copper_ore',
    aluminum_ore_raw = 'aluminum_ore',
    silver_ore_raw = 'silver_ore',
    gold_ore_raw = 'gold_ore',
    diamond_raw = 'diamond',
    emerald_raw = 'emerald',
    ruby_raw = 'ruby',
    sapphire_raw = 'sapphire',
    mystery_ore_raw = 'mystery_ore',
    artifact_raw = 'artifact',
}

--- Plienas: geležies rūda x2 + anglis x1 → plienas x1 (perdirbimo meniu)
Config.SteelRecipe = { iron = 'iron_ore', coal = 'coal', steel = 'steel', ironCount = 2, coalCount = 1 }

--- Kainos už vieną vienetą ($) — supirkėjas
Config.SellPrices = {
    stone = 3,
    coal = 4,
    gravel = 2,
    iron_ore = 18,
    copper_ore = 14,
    aluminum_ore = 16,
    silver_ore = 85,
    gold_ore = 220,
    diamond = 950,
    emerald = 620,
    ruby = 680,
    sapphire = 640,
    mystery_ore = 450,
    artifact = 520,
    steel = 55,
    rubber = 25,
    glass = 15,
    --- žaliavos (pigiau nei švarios)
    stone_raw = 1,
    coal_raw = 2,
    gravel_raw = 1,
    iron_ore_raw = 6,
    copper_ore_raw = 5,
    aluminum_ore_raw = 5,
    silver_ore_raw = 35,
    gold_ore_raw = 90,
    diamond_raw = 380,
    emerald_raw = 240,
    ruby_raw = 280,
    sapphire_raw = 260,
    mystery_ore_raw = 180,
    artifact_raw = 200,
}
