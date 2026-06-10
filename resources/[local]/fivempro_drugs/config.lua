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
  Kiekvienas narkotikas: 1) žaliava (parduotuvė) → 2) apdorotas (gamybos stotis) → 3) supakuotas (pardavimas).
  stage = 'process' | 'pack' · sellBase > 0 tik supakuotiems.
]]
local function drugProcess(label, level, output, craftTimeMs, risk, minigame, fail, police, heat, failPct, lineOrder, outAmt)
    return {
        label = label,
        level = level,
        stage = 'process',
        lineOrder = lineOrder,
        output = output,
        outputAmount = outAmt or 1,
        craftTimeMs = craftTimeMs,
        risk = risk,
        minigame = minigame,
        failChance = fail,
        policeChance = police,
        heatGain = heat,
        failLosePercent = failPct,
        sellBase = 0,
    }
end

local function drugPack(label, level, output, sellBase, craftTimeMs, risk, minigame, fail, police, heat, failPct, lineOrder, outAmt)
    return {
        label = label,
        level = level,
        stage = 'pack',
        lineOrder = lineOrder,
        output = output,
        outputAmount = outAmt or 1,
        craftTimeMs = craftTimeMs,
        risk = risk,
        minigame = minigame,
        failChance = fail,
        policeChance = police,
        heatGain = heat,
        failLosePercent = failPct,
        sellBase = sellBase,
    }
end

Config.Products = {
    --- L1
    thc_process = drugProcess('THC · distiliacija', 1, 'weed_resin', 14000, 'low', 'progress', 5, 3, 1, 35, 1),
    thc_pack = drugPack('THC kronštainis · supakavimas', 1, 'thc_cart', 95, 12000, 'low', 'progress', 6, 4, 2, 35, 2),
    alcohol_process = drugProcess('Samagonas · distiliacija', 1, 'moonshine_spirit', 13000, 'low', 'progress', 4, 3, 1, 30, 3),
    alcohol_pack = drugPack('Nelegalus alkoholis · supakavimas', 1, 'illegal_alcohol', 75, 11000, 'low', 'progress', 5, 3, 2, 30, 4),
    vape_process = drugProcess('Vape · paruošimas', 1, 'vape_mix', 12000, 'low', 'progress', 4, 2, 1, 28, 5),
    vape_pack = drugPack('Vape skystis · supakavimas', 1, 'vape_liquid', 65, 10000, 'low', 'progress', 5, 3, 1, 28, 6, 2),
    --- L2
    weed_process = drugProcess('Žolė · džiovinimas', 2, 'weed_buds', 18000, 'medium', 'skill', 10, 6, 3, 45, 7),
    weed_pack = drugPack('Žolė · supakavimas', 2, 'weed_bag', 140, 15000, 'medium', 'skill', 12, 8, 4, 50, 8),
    heroin_process = drugProcess('Heroinas · virimas', 2, 'heroin_paste', 22000, 'medium', 'skill', 12, 8, 4, 50, 9),
    heroin_pack = drugPack('Heroinas · supakavimas', 2, 'heroin_bag', 220, 16000, 'medium', 'skill', 14, 10, 5, 55, 10),
    meth_process = drugProcess('Metas · kristalizacija', 2, 'meth_crystal', 26000, 'high', 'skill', 13, 10, 5, 55, 11),
    meth_pack = drugPack('Metas · supakavimas', 2, 'meth_bag', 260, 18000, 'high', 'skill', 15, 12, 6, 60, 12),
    pills_process = drugProcess('Tabletės · presavimas', 2, 'pill_tablets', 17000, 'medium', 'skill', 9, 6, 3, 40, 13, 2),
    pills_pack = drugPack('Tabletės · supakavimas', 2, 'pills_pack', 180, 14000, 'medium', 'skill', 11, 7, 4, 45, 14),
    mushroom_process = drugProcess('Grybai · džiovinimas', 2, 'mushroom_dried', 15000, 'medium', 'skill', 8, 5, 2, 38, 15),
    mushroom_pack = drugPack('Grybai · supakavimas', 2, 'mushroom_pack', 150, 13000, 'medium', 'skill', 10, 6, 3, 40, 16),
    --- L3
    cocaine_process = drugProcess('Kokainas · ekstrakcija', 3, 'cocaine_paste', 32000, 'high', 'advanced', 18, 12, 6, 65, 17),
    cocaine_pack = drugPack('Kokainas · supakavimas', 3, 'cocaine_bag', 420, 22000, 'high', 'advanced', 22, 16, 8, 70, 18),
    amp_process = drugProcess('Amfetaminas · sintezė', 3, 'amp_paste', 30000, 'high', 'advanced', 17, 11, 6, 60, 19),
    amp_pack = drugPack('Amfetaminas · supakavimas', 3, 'amphetamine_bag', 380, 20000, 'high', 'advanced', 20, 14, 7, 65, 20),
    cartel_process = drugProcess('Kartelio mišinys · virimas', 3, 'cartel_blend', 35000, 'extreme', 'advanced', 20, 15, 7, 70, 21),
    cartel_pack = drugPack('Kartelio mišinys · supakavimas', 3, 'cartel_pack', 520, 24000, 'extreme', 'advanced', 25, 20, 10, 75, 22),
}

Config.Recipes = {
    --- L1: žaliava → apdorota → supakuota
    thc_process = {
        { item = 'weed_leaf', count = 4 },
        { item = 'filter', count = 1 },
        { item = 'gloves', count = 1 },
    },
    thc_pack = {
        { item = 'weed_resin', count = 1 },
        { item = 'empty_cart', count = 1 },
        { item = 'packaging', count = 1 },
    },
    alcohol_process = {
        { item = 'alcohol_base', count = 3 },
        { item = 'filter', count = 1 },
    },
    alcohol_pack = {
        { item = 'moonshine_spirit', count = 1 },
        { item = 'empty_bottle', count = 1 },
        { item = 'packaging', count = 1 },
    },
    vape_process = {
        { item = 'vape_liquid_base', count = 2 },
        { item = 'filter', count = 1 },
    },
    vape_pack = {
        { item = 'vape_mix', count = 1 },
        { item = 'empty_bottle', count = 1 },
        { item = 'packaging', count = 1 },
    },
    --- L2
    weed_process = {
        { item = 'weed_leaf', count = 5 },
        { item = 'gloves', count = 1 },
    },
    weed_pack = {
        { item = 'weed_buds', count = 2 },
        { item = 'empty_bag', count = 1 },
        { item = 'scale', count = 1 },
        { item = 'packaging', count = 1 },
    },
    heroin_process = {
        { item = 'poppy_flower', count = 5 },
        { item = 'chemical_mix', count = 1 },
        { item = 'gloves', count = 1 },
    },
    heroin_pack = {
        { item = 'heroin_paste', count = 1 },
        { item = 'empty_bag', count = 1 },
        { item = 'scale', count = 1 },
        { item = 'packaging', count = 1 },
    },
    meth_process = {
        { item = 'meth_ingredient', count = 4 },
        { item = 'chemical_mix', count = 2 },
        { item = 'lab_kit', count = 1 },
        { item = 'burner', count = 1 },
    },
    meth_pack = {
        { item = 'meth_crystal', count = 1 },
        { item = 'empty_bag', count = 1 },
        { item = 'scale', count = 1 },
        { item = 'packaging', count = 1 },
    },
    pills_process = {
        { item = 'pill_powder', count = 4 },
        { item = 'lab_kit', count = 1 },
    },
    pills_pack = {
        { item = 'pill_tablets', count = 2 },
        { item = 'packaging', count = 2 },
        { item = 'empty_bag', count = 1 },
    },
    mushroom_process = {
        { item = 'mushroom_raw', count = 5 },
        { item = 'gloves', count = 1 },
    },
    mushroom_pack = {
        { item = 'mushroom_dried', count = 1 },
        { item = 'empty_bag', count = 1 },
        { item = 'packaging', count = 1 },
    },
    --- L3
    cocaine_process = {
        { item = 'coca_leaf', count = 6 },
        { item = 'chemical_mix', count = 2 },
        { item = 'burner', count = 1 },
    },
    cocaine_pack = {
        { item = 'cocaine_paste', count = 1 },
        { item = 'empty_bag', count = 1 },
        { item = 'scale', count = 1 },
        { item = 'packaging', count = 1 },
    },
    amp_process = {
        { item = 'amp_precursor', count = 4 },
        { item = 'chemical_mix', count = 2 },
        { item = 'lab_kit', count = 1 },
    },
    amp_pack = {
        { item = 'amp_paste', count = 1 },
        { item = 'empty_bag', count = 1 },
        { item = 'scale', count = 1 },
        { item = 'packaging', count = 1 },
    },
    cartel_process = {
        { item = 'cartel_raw', count = 4 },
        { item = 'chemical_mix', count = 3 },
        { item = 'lab_kit', count = 1 },
        { item = 'burner', count = 1 },
    },
    cartel_pack = {
        { item = 'cartel_blend', count = 1 },
        { item = 'packaging', count = 2 },
        { item = 'empty_bag', count = 1 },
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
    { id = 'weapon_bench_l1', label = '3D spausdintuvas · L1', level = 1, mode = 'weapon', coords = devRow(14.0), radius = 2.2, blip = false },
    { id = 'weapon_bench_l2', label = '3D spausdintuvas · L2', level = 2, mode = 'weapon', coords = devRow(15.5), radius = 2.2, blip = false },
    { id = 'weapon_bench_l3', label = '3D spausdintuvas · L3', level = 3, mode = 'weapon', coords = devRow(17.0), radius = 2.2, blip = false },
}

--- Ginklų 3D spausdintuvas: kelios fazės + animacijos (client). craftTimeMs = bazinis laikas prieš lygio daugiklį.
Config.WeaponCraft = {
    minPhaseMs = 9000,
    timeMultiplier = { [1] = 1.0, [2] = 1.3, [3] = 1.55 },
    minigameBonusMs = { progress = 0, skill = 14000, advanced = 20000 },
    phases = {
        {
            id = 'warmup',
            label = '3D spausdintuvo paruošimas…',
            weight = 0.14,
            anim = { dict = 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@', clip = 'machinic_loop_mechandplayer', flag = 1 },
        },
        {
            id = 'print',
            label = 'Spausdinamos ginklo dalys…',
            weight = 0.36,
            anim = { dict = 'amb@world_human_welding@male@base', clip = 'base', flag = 1 },
            prop = { model = 'prop_tool_blowtorch', bone = 28422, pos = vector3(0.0, 0.0, 0.0), rot = vector3(0.0, 0.0, 0.0) },
        },
        {
            id = 'assemble',
            label = 'Surenkamas ginklas…',
            weight = 0.28,
            anim = { dict = 'mini@repair', clip = 'fixing_a_player', flag = 16 },
        },
        {
            id = 'calibrate',
            label = 'Kalibruojamas užtaisas…',
            weight = 0.22,
            anim = { dict = 'missmechanic', clip = 'work2_base', flag = 1 },
        },
    },
}

--- Ginklų gamyba (atskira stotis, mode = weapon) — be NPC pardavimo kainos
local function wp(label, level, output, ammoItem, ammoCount, craftTimeMs, minigame, failChance, policeChance, heatGain, failLosePercent, risk)
    local row = {
        label = label,
        level = level,
        output = output,
        outputAmount = 1,
        craftTimeMs = craftTimeMs,
        risk = risk or 'high',
        minigame = minigame or 'skill',
        failChance = failChance,
        policeChance = 0,
        heatGain = heatGain,
        sellBase = 0,
        failLosePercent = failLosePercent,
    }
    if ammoItem and ammoCount and ammoCount > 0 then
        row.bonusItems = { { item = ammoItem, count = ammoCount } }
    end
    return row
end

Config.WeaponProducts = {
    --- L1 — pistoletai + šalti ginklai (bazinis laikas ~70–85 s + fazės)
    craft_pistol = wp('Pistoletas', 1, 'weapon_pistol', 'pistol_ammo', 60, 72000, 'progress', 12, 10, 3, 45, 'medium'),
    craft_combat_pistol = wp('Combat pistoletas', 1, 'weapon_combatpistol', 'pistol_ammo', 72, 78000, 'skill', 14, 12, 4, 50, 'medium'),
    craft_bat = wp('Beisbolo lazda', 1, 'weapon_bat', nil, 0, 65000, 'progress', 6, 4, 1, 30, 'low'),
    craft_switchblade = wp('Switchblade', 1, 'weapon_switchblade', nil, 0, 68000, 'progress', 8, 5, 2, 35, 'low'),
    --- L2 — SMG / .50 / shotgun (~95–120 s + minigame)
    craft_tec9 = wp('Tec-9', 2, 'weapon_machinepistol', 'pistol_ammo', 90, 92000, 'skill', 16, 14, 5, 52, 'high'),
    craft_mini_uzi = wp('Mini Uzi', 2, 'weapon_minismg', 'smg_ammo', 90, 96000, 'skill', 17, 15, 5, 54, 'high'),
    craft_smg = wp('SMG', 2, 'weapon_smg', 'smg_ammo', 120, 100000, 'skill', 18, 16, 6, 56, 'high'),
    craft_pistol50 = wp('Pistoletas .50', 2, 'weapon_pistol50', 'pistol_ammo', 48, 94000, 'skill', 15, 14, 5, 50, 'high'),
    craft_pumpshotgun = wp('Pump shotgun', 2, 'weapon_pumpshotgun', 'shotgun_ammo', 32, 108000, 'advanced', 19, 17, 6, 58, 'high'),
    --- L3 — karabinai (~120–150 s + minigame)
    craft_carbine = wp('Karabinas', 3, 'weapon_carbinerifle', 'rifle_ammo', 120, 118000, 'advanced', 20, 18, 7, 60, 'extreme'),
    craft_ak47 = wp('AK-47', 3, 'weapon_assaultrifle', 'rifle_ammo', 120, 125000, 'advanced', 21, 19, 8, 62, 'extreme'),
    craft_micro_draco = wp('Micro Draco', 3, 'weapon_compactrifle', 'rifle_ammo', 90, 120000, 'advanced', 20, 18, 7, 60, 'extreme'),
}

Config.WeaponRecipes = {
    craft_pistol = {
        { item = 'gun_frame', count = 1 },
        { item = 'gun_barrel', count = 1 },
        { item = 'gun_spring', count = 2 },
        { item = 'gun_trigger', count = 1 },
        { item = 'metal_scrap', count = 4 },
    },
    craft_combat_pistol = {
        { item = 'gun_frame', count = 1 },
        { item = 'gun_barrel', count = 1 },
        { item = 'gun_spring', count = 2 },
        { item = 'gun_trigger', count = 1 },
        { item = 'weapon_parts', count = 1 },
        { item = 'metal_scrap', count = 5 },
    },
    craft_bat = {
        { item = 'metal_scrap', count = 4 },
        { item = 'weapon_parts', count = 1 },
    },
    craft_switchblade = {
        { item = 'metal_scrap', count = 2 },
        { item = 'gun_spring', count = 1 },
        { item = 'weapon_parts', count = 1 },
    },
    craft_tec9 = {
        { item = 'gun_frame', count = 1 },
        { item = 'gun_barrel', count = 1 },
        { item = 'gun_spring', count = 3 },
        { item = 'gun_trigger', count = 1 },
        { item = 'weapon_parts', count = 2 },
        { item = 'metal_scrap', count = 6 },
    },
    craft_mini_uzi = {
        { item = 'gun_frame', count = 1 },
        { item = 'gun_barrel', count = 2 },
        { item = 'gun_spring', count = 3 },
        { item = 'gun_trigger', count = 1 },
        { item = 'weapon_parts', count = 2 },
        { item = 'metal_scrap', count = 7 },
    },
    craft_smg = {
        { item = 'gun_frame', count = 2 },
        { item = 'gun_barrel', count = 2 },
        { item = 'gun_spring', count = 4 },
        { item = 'gun_trigger', count = 2 },
        { item = 'weapon_parts', count = 3 },
        { item = 'metal_scrap', count = 8 },
    },
    craft_pistol50 = {
        { item = 'gun_frame', count = 1 },
        { item = 'gun_barrel', count = 1 },
        { item = 'gun_spring', count = 2 },
        { item = 'gun_trigger', count = 1 },
        { item = 'weapon_parts', count = 2 },
        { item = 'metal_scrap', count = 6 },
    },
    craft_pumpshotgun = {
        { item = 'gun_frame', count = 2 },
        { item = 'gun_barrel', count = 2 },
        { item = 'gun_spring', count = 2 },
        { item = 'gun_trigger', count = 1 },
        { item = 'weapon_parts', count = 3 },
        { item = 'metal_scrap', count = 8 },
    },
    craft_carbine = {
        { item = 'gun_frame', count = 2 },
        { item = 'gun_barrel', count = 2 },
        { item = 'gun_spring', count = 3 },
        { item = 'gun_trigger', count = 2 },
        { item = 'weapon_parts', count = 5 },
        { item = 'metal_scrap', count = 10 },
    },
    craft_ak47 = {
        { item = 'gun_frame', count = 2 },
        { item = 'gun_barrel', count = 2 },
        { item = 'gun_spring', count = 4 },
        { item = 'gun_trigger', count = 2 },
        { item = 'weapon_parts', count = 6 },
        { item = 'metal_scrap', count = 12 },
    },
    craft_micro_draco = {
        { item = 'gun_frame', count = 2 },
        { item = 'gun_barrel', count = 2 },
        { item = 'gun_spring', count = 3 },
        { item = 'gun_trigger', count = 2 },
        { item = 'weapon_parts', count = 4 },
        { item = 'metal_scrap', count = 9 },
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
        { name = 'amp_precursor', amount = 500, price = 38, slot = 29 },
        { name = 'cartel_raw', amount = 500, price = 52, slot = 30 },
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
        { name = 'shotgun_ammo', amount = 500, price = 20, slot = 28 },
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
    coords = vector4(DRUG_TEST_POS.x, DRUG_TEST_POS.y, DRUG_TEST_POS.z, DEV_ROW_H + 180.0),
    scenario = 'WORLD_HUMAN_STAND_MOBILE',
    label = 'Narkotikų gamyba',
    blip = false,
}

--- Ingredientų parduotuvė (qb-inventory shop UI) — šalia test NPC
Config.SupplyShopNPC = {
    model = 's_m_y_dealer_01',
    coords = vector4(SUPPLY_SHOP_POS.x, SUPPLY_SHOP_POS.y, SUPPLY_SHOP_POS.z, DEV_ROW_H + 180.0),
    scenario = 'WORLD_HUMAN_SMOKING',
    label = 'Nelegalūs reikmenys',
    blip = {
        enabled = true,
        sprite = 52,
        color = 27,
        scale = 0.8,
        label = 'Nelegalūs reikmenys',
    },
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
        amp_precursor = 20, cartel_raw = 15,
        lab_kit = 5, empty_bag = 15, scale = 5, packaging = 20, burner = 3,
    },
}
