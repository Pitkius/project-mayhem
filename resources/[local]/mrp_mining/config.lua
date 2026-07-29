Config = {}

--[[
  Grandinė:
    1) Kasimas (karjeras) → žali (*_raw)
    2) Smėlio kasimas (paplūdimiai / dykuma, NE žolė) → sand_raw
    3) Nuvalymas (CleanCoords) → koncentratas / nuvalytas smėlis / šiukšlės→medžiagos|buteliai
    4) Išlydymas (SmeltCoords) → metalai / stiklas / plienas
]]

--- Karjero sienos — kasimas palei perimetrą
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

Config.MiningSites = {
    { coords = vector3(2954.0, 2794.0, 41.05), radius = 130.0, label = 'Karjeras — kasimas' },
}

--- Smėlio kasimas — tik smėlio plotai (ne žolė)
Config.SandDigSites = {
    { center = vector3(-1345.0, -1285.0, 4.2), length = 55.0, width = 28.0, heading = 30.0, minZ = 2.0, maxZ = 7.5, label = 'Vespucci paplūdimys' },
    { center = vector3(-1605.0, -1100.0, 4.0), length = 48.0, width = 22.0, heading = 50.0, minZ = 2.0, maxZ = 7.0, label = 'Del Perro paplūdimys' },
    { center = vector3(1865.0, 3600.0, 34.0), length = 40.0, width = 24.0, heading = 30.0, minZ = 32.0, maxZ = 37.0, label = 'Sandy paplūdimys' },
    { center = vector3(2450.0, 3770.0, 38.5), length = 35.0, width = 20.0, heading = 0.0, minZ = 36.0, maxZ = 41.0, label = 'Senora dykumos smėlis' },
}

Config.Minigame = {
    hits = 5,
    time = 12,
    speed = 0.88,
}

Config.MineAnimDuration = 3200
Config.SandAnimDuration = 2800
Config.MineCooldown = 8
Config.SandCooldown = 6
Config.SellAnimDuration = 2800
Config.TrashCooldown = 45
Config.TrashSearchDuration = 3500

--- Nuvalymas (Cypress Flats)
Config.CleanCoords = vector4(1087.67, -2004.92, 31.16, 54.20)
--- Išlydymas / krosnis (šalia)
Config.SmeltCoords = vector4(1112.35, -2005.85, 35.44, 145.0)

Config.SellPed = {
    coords = vector4(1098.42, -1995.88, 30.48, 235.0),
    model = `s_m_y_construct_01`,
    scenario = 'WORLD_HUMAN_CLIPBOARD',
}

Config.Blips = {
    mining = { sprite = 618, colour = 47, scale = 0.85, label = 'Karjeras — kasimas' },
    sand = { sprite = 164, colour = 5, scale = 0.7, label = 'Smėlio kasimas' },
    clean = { sprite = 566, colour = 47, scale = 0.82, label = 'Žaliavų nuvalymas' },
    smelt = { sprite = 436, colour = 1, scale = 0.82, label = 'Metalų išlydymas' },
    sell = { sprite = 500, colour = 2, scale = 0.82, label = 'Metalų supirkimas' },
}

--- Karjero drop (žalia)
Config.MineLoot = {
    { item = 'stone_raw', weight = 28 },
    { item = 'coal_raw', weight = 22 },
    { item = 'gravel_raw', weight = 18 },
    { item = 'iron_ore_raw', weight = 14 },
    { item = 'copper_ore_raw', weight = 10 },
    { item = 'aluminum_ore_raw', weight = 8 },
}

--- Smėlio drop
Config.SandLoot = {
    { item = 'sand_raw', weight = 100 },
}

--- Šiukšliadėžės / konteineriai — nešvarūs buteliai / skardinės / gumos atraižos
Config.TrashModels = {
    `prop_dumpster_01a`,
    `prop_dumpster_02a`,
    `prop_dumpster_02b`,
    `prop_dumpster_3a`,
    `prop_dumpster_4a`,
    `prop_dumpster_4b`,
    `prop_bin_01a`,
    `prop_bin_05a`,
    `prop_bin_06a`,
    `prop_bin_07a`,
    `prop_bin_07b`,
    `prop_bin_08a`,
    `prop_bin_08open`,
    `prop_recyclebin_01a`,
    `prop_recyclebin_02a`,
    `prop_recyclebin_02b`,
    `prop_recyclebin_02_c`,
    `prop_recyclebin_02_d`,
    `prop_rub_binbag_01`,
    `prop_rub_binbag_08`,
}

Config.TrashLoot = {
    { item = 'dirty_plastic_bottle', weight = 30 },
    { item = 'dirty_glass_bottle', weight = 26 },
    { item = 'dirty_tin_can', weight = 22 },
    { item = 'dirty_rubber_scrap', weight = 22 },
}

--- Nuvalymas: žalia → nuvalyta (1:1)
Config.CleanMap = {
    stone_raw = 'stone',
    coal_raw = 'coal',
    gravel_raw = 'gravel',
    iron_ore_raw = 'iron_ore',
    copper_ore_raw = 'copper_ore',
    aluminum_ore_raw = 'aluminum_ore',
    sand_raw = 'sand',
}

--- Nuvalymas: šiukšlės → perdirbtos medžiagos (be lydymo)
Config.TrashToMaterial = {
    dirty_plastic_bottle = 'plastic',
    dirty_glass_bottle = 'glass',
    dirty_tin_can = 'aluminum',
    dirty_rubber_scrap = 'rubber',
}

--- Nuvalymas: šiukšlės → švarūs buteliai (alkoholio / skysčių pakavimui)
Config.TrashToBottle = {
    dirty_plastic_bottle = 'empty_plastic_bottle',
    dirty_glass_bottle = 'empty_glass_bottle',
    --- skardinė / guma į butelį netinka — tik į medžiagas
}

--- Išlydymas (krosnis)
Config.SmeltRecipes = {
    {
        id = 'smelt_iron',
        label = 'Lydyti geležį',
        txt = '1× geležies koncentratas + 1× anglis → 1× geležis',
        inputs = { iron_ore = 1, coal = 1 },
        output = 'iron',
        count = 1,
    },
    {
        id = 'smelt_copper',
        label = 'Lydyti varį',
        txt = '1× vario koncentratas + 1× anglis → 1× varis',
        inputs = { copper_ore = 1, coal = 1 },
        output = 'copper',
        count = 1,
    },
    {
        id = 'smelt_aluminum',
        label = 'Lydyti aliuminį',
        txt = '1× aliuminio koncentratas + 1× anglis → 1× aliuminis',
        inputs = { aluminum_ore = 1, coal = 1 },
        output = 'aluminum',
        count = 1,
    },
    {
        id = 'smelt_steel',
        label = 'Lydyti plieną',
        txt = '2× geležies koncentratas + 1× anglis → 1× plienas',
        inputs = { iron_ore = 2, coal = 1 },
        output = 'steel',
        count = 1,
    },
    {
        id = 'smelt_glass',
        label = 'Lydyti stiklą iš smėlio',
        txt = '2× nuvalytas smėlis + 1× anglis → 1× stiklas',
        inputs = { sand = 2, coal = 1 },
        output = 'glass',
        count = 1,
    },
}

--- Supirkėjo kainos ($)
Config.SellPrices = {
    stone = 3,
    coal = 4,
    gravel = 2,
    sand = 2,
    iron_ore = 12,
    copper_ore = 10,
    aluminum_ore = 11,
    iron = 28,
    copper = 24,
    aluminum = 26,
    steel = 55,
    rubber = 25,
    glass = 22,
    plastic = 18,
    --- žaliavos pigiau
    stone_raw = 1,
    coal_raw = 2,
    gravel_raw = 1,
    sand_raw = 1,
    iron_ore_raw = 5,
    copper_ore_raw = 4,
    aluminum_ore_raw = 4,
}

--- Atgalinis suderinamumas (seni scriptai)
Config.ProcessCoords = Config.CleanCoords
Config.ProcessMap = Config.CleanMap
Config.SteelRecipe = { iron = 'iron_ore', coal = 'coal', steel = 'steel', ironCount = 2, coalCount = 1 }
