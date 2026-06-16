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
    thc_pack = drugPack('Vape buteliukas · supakavimas', 1, 'thc_cart', 95, 12000, 'low', 'progress', 6, 4, 2, 35, 2),
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
    --- L3 — kokainas: lapai → nesupakuotas → supakuotas
    cocaine_process = drugProcess('Kokainas · virimas', 3, 'cartel_blend', 35000, 'high', 'advanced', 20, 15, 7, 65, 17),
    cocaine_pack = drugPack('Kokainas · supakavimas', 3, 'cartel_pack', 520, 24000, 'high', 'advanced', 25, 20, 10, 70, 18),
    amp_process = drugProcess('Amfetaminas · sintezė', 3, 'amp_paste', 30000, 'high', 'advanced', 17, 11, 6, 60, 19),
    amp_pack = drugPack('Amfetaminas · supakavimas', 3, 'amphetamine_bag', 380, 20000, 'high', 'advanced', 20, 14, 7, 65, 20),
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
        { item = 'empty_bottle', count = 1 },
        { item = 'empty_bag', count = 1 },
    },
    alcohol_process = {
        { item = 'alcohol_base', count = 3 },
        { item = 'filter', count = 1 },
    },
    alcohol_pack = {
        { item = 'moonshine_spirit', count = 1 },
        { item = 'empty_bottle', count = 1 },
        { item = 'empty_bag', count = 1 },
    },
    vape_process = {
        { item = 'vape_liquid_base', count = 2 },
        { item = 'filter', count = 1 },
    },
    vape_pack = {
        { item = 'vape_mix', count = 1 },
        { item = 'empty_bottle', count = 1 },
        { item = 'empty_bag', count = 1 },
    },
    --- L2
    weed_process = {
        { item = 'weed_leaf', count = 5 },
        { item = 'gloves', count = 1 },
    },
    weed_pack = {
        { item = 'weed_buds', count = 2 },
        { item = 'empty_bag', count = 2 },
        { item = 'scale', count = 1 },
    },
    heroin_process = {
        { item = 'poppy_flower', count = 5 },
        { item = 'chemical_mix', count = 1 },
        { item = 'gloves', count = 1 },
    },
    heroin_pack = {
        { item = 'heroin_paste', count = 1 },
        { item = 'empty_bag', count = 2 },
        { item = 'scale', count = 1 },
    },
    meth_process = {
        { item = 'meth_ingredient', count = 4 },
        { item = 'chemical_mix', count = 2 },
        { item = 'lab_kit', count = 1 },
        { item = 'burner', count = 1 },
    },
    meth_pack = {
        { item = 'meth_crystal', count = 1 },
        { item = 'empty_bag', count = 2 },
        { item = 'scale', count = 1 },
    },
    pills_process = {
        { item = 'pill_powder', count = 4 },
        { item = 'lab_kit', count = 1 },
    },
    pills_pack = {
        { item = 'pill_tablets', count = 2 },
        { item = 'empty_bag', count = 3 },
    },
    mushroom_process = {
        { item = 'mushroom_raw', count = 5 },
        { item = 'gloves', count = 1 },
    },
    mushroom_pack = {
        { item = 'mushroom_dried', count = 1 },
        { item = 'empty_bag', count = 2 },
    },
    --- L3 — kokainas
    cocaine_process = {
        { item = 'cartel_raw', count = 4 },
        { item = 'chemical_mix', count = 3 },
        { item = 'lab_kit', count = 1 },
        { item = 'burner', count = 1 },
    },
    cocaine_pack = {
        { item = 'cartel_blend', count = 1 },
        { item = 'empty_bag', count = 3 },
    },
    amp_process = {
        { item = 'amp_precursor', count = 4 },
        { item = 'chemical_mix', count = 2 },
        { item = 'lab_kit', count = 1 },
    },
    amp_pack = {
        { item = 'amp_paste', count = 1 },
        { item = 'empty_bag', count = 2 },
        { item = 'scale', count = 1 },
    },
}

--- Gamybos vietos — LS airport eilėje (žr. Config.DevHub)
Config.Stations = {
    { id = 'stash_grove', label = 'L1 · Sandėliukas', level = 1, coords = devRow(-10.5), radius = 2.2, blip = false },
    { id = 'garage_davis', label = 'L1 · Garažas', level = 1, coords = devRow(-7.0), radius = 2.2, blip = false },
    { id = 'trap_chamberlain', label = 'L2 · Trap house', level = 2, coords = devRow(-3.5), radius = 2.2, blip = false },
    { id = 'gang_base', label = 'L2 · Gaujos bazė', level = 2, coords = devRow(0.0), radius = 2.2, blip = false },
    { id = 'lab_sandy', label = 'L2 · Laboratorija', level = 2, coords = devRow(3.5), radius = 2.2, blip = false },
    { id = 'cartel_lab', label = 'L3 · Kokaino laboratorija', level = 3, coords = devRow(7.0), radius = 2.2, blip = false },
    { id = 'secret_humane', label = 'L3 · Slapta lab.', level = 3, coords = devRow(10.5), radius = 2.2, blip = false },
    { id = 'weapon_bench_l1', label = 'Ginklų dirbtuvė · L1', level = 1, mode = 'weapon', coords = devRow(14.0), radius = 2.2, blip = false },
    { id = 'weapon_bench_l2', label = 'Ginklų dirbtuvė · L2', level = 2, mode = 'weapon', coords = devRow(15.5), radius = 2.2, blip = false },
    { id = 'weapon_bench_l3', label = 'Ginklų dirbtuvė · L3', level = 3, mode = 'weapon', coords = devRow(17.0), radius = 2.2, blip = false },
}

--[[
  PLANNED — LSD tablet (turinys dar nežinomas).
  Kai turėsi vietą žaidime: /coords → įrašyk į coords žemiau.
  Blipas pasirodys žemėlapyje kai coords != nil ir showBlip = true.
]]
Config.PlannedSites = {
    lsd_tablet = {
        coords = nil, -- pvz. vector4(892.26, -960.85, 38.18, 0.0)
        label = 'LSD tablet (planuojama)',
        note = 'Čia bus LSD tablet susijęs content — mechanika ir NPC dar TBD.',
        showBlip = true,
        blip = {
            sprite = 606,
            color = 27,
            scale = 0.78,
            shortRange = true,
            label = 'LSD tablet (TBD)',
        },
    },
}

--- Nešiojamas 3D spausdintuvas (itemas · DB · spausdinimas)
Config.Printer3d = {
    item = '3d_printer',
    propModel = 'prop_printer_01',
    maxPerPlayer = 2,
    pickupDist = 2.8,
    interactDist = 2.4,
    products = {
        print_gun_frame = {
            label = 'Ginklo korpusas',
            output = { item = 'gun_frame', count = 1 },
            ingredients = {
                { item = 'metal_scrap', count = 5 },
                { item = 'plastic', count = 6 },
            },
            timeMs = 52000,
        },
        print_gun_barrel = {
            label = 'Vamzdis',
            output = { item = 'gun_barrel', count = 1 },
            ingredients = {
                { item = 'metal_scrap', count = 6 },
                { item = 'plastic', count = 5 },
            },
            timeMs = 56000,
        },
        print_gun_spring = {
            label = 'Spyruoklė',
            output = { item = 'gun_spring', count = 2 },
            ingredients = {
                { item = 'metal_scrap', count = 3 },
                { item = 'plastic', count = 3 },
            },
            timeMs = 35000,
        },
        print_gun_trigger = {
            label = 'Užtaisas',
            output = { item = 'gun_trigger', count = 1 },
            ingredients = {
                { item = 'metal_scrap', count = 3 },
                { item = 'plastic', count = 5 },
            },
            timeMs = 40000,
        },
        print_weapon_parts = {
            label = 'Ginklo komponentai',
            output = { item = 'weapon_parts', count = 1 },
            ingredients = {
                { item = 'metal_scrap', count = 8 },
                { item = 'plastic', count = 8 },
            },
            timeMs = 68000,
        },
    },
}

--- Ginklų dirbtuvė (client). 3D spausdintuvas — tik šaunamiesiems (recepte gun_frame / gun_barrel).
Config.WeaponCraft = {
    minPhaseMs = 9000,
    timeMultiplier = { [1] = 1.0, [2] = 1.3, [3] = 1.55 },
    minigameBonusMs = { progress = 0, skill = 14000, advanced = 20000 },
    -- Šaunamieji: spausdinimas + surinkimas + kalibravimas
    phases = {
        {
            id = 'warmup',
            label = '3D spausdintuvo paruošimas…',
            weight = 0.14,
            anim = { dict = 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@', clip = 'machinic_loop_mechandplayer', flag = 49 },
        },
        {
            id = 'print',
            label = 'Spausdinamos ginklo dalys…',
            weight = 0.36,
            anim = { dict = 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@', clip = 'machinic_loop_mechandplayer', flag = 49 },
            prop = { model = 'prop_tool_blowtorch', bone = 28422, pos = vector3(0.0, 0.0, 0.0), rot = vector3(0.0, 0.0, 0.0) },
        },
        {
            id = 'assemble',
            label = 'Surenkamas ginklas…',
            weight = 0.28,
            anim = { dict = 'mini@repair', clip = 'fixing_a_ped', flag = 49 },
        },
        {
            id = 'calibrate',
            label = 'Kalibruojamas užtaisas…',
            weight = 0.22,
            anim = { dict = 'missmechanic', clip = 'work2_base', flag = 49 },
        },
    },
    -- Šalti ginklai: rankinis surinkimas be 3D spausdintuvo
    benchPhases = {
        {
            id = 'prep',
            label = 'Apdorojamos dalys…',
            weight = 0.4,
            anim = { dict = 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@', clip = 'machinic_loop_mechandplayer', flag = 49 },
        },
        {
            id = 'finish',
            label = 'Baigiamas ginklas…',
            weight = 0.6,
            anim = { dict = 'mini@repair', clip = 'fixing_a_ped', flag = 49 },
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
    craft_pistol = wp('Pistoletas', 1, 'weapon_pistol', 'pistol_ammo', 60, 90000, 'progress', 12, 10, 3, 45, 'medium'),
    craft_combat_pistol = wp('Combat pistoletas', 1, 'weapon_combatpistol', 'pistol_ammo', 72, 98000, 'skill', 14, 12, 4, 50, 'medium'),
    craft_bat = wp('Beisbolo lazda', 1, 'weapon_bat', nil, 0, 82000, 'progress', 6, 4, 1, 30, 'low'),
    craft_switchblade = wp('Switchblade', 1, 'weapon_switchblade', nil, 0, 85000, 'progress', 8, 5, 2, 35, 'low'),
    --- L2 — SMG / .50 / shotgun (~95–120 s + minigame)
    craft_tec9 = wp('Tec-9', 2, 'weapon_machinepistol', 'pistol_ammo', 90, 115000, 'skill', 16, 14, 5, 52, 'high'),
    craft_mini_uzi = wp('Mini Uzi', 2, 'weapon_minismg', 'smg_ammo', 90, 120000, 'skill', 17, 15, 5, 54, 'high'),
    craft_smg = wp('SMG', 2, 'weapon_smg', 'smg_ammo', 120, 125000, 'skill', 18, 16, 6, 56, 'high'),
    craft_pistol50 = wp('Pistoletas .50', 2, 'weapon_pistol50', 'pistol_ammo', 48, 118000, 'skill', 15, 14, 5, 50, 'high'),
    craft_pumpshotgun = wp('Pump shotgun', 2, 'weapon_pumpshotgun', 'shotgun_ammo', 32, 135000, 'advanced', 19, 17, 6, 58, 'high'),
    --- L3 — karabinai (~120–150 s + minigame)
    craft_carbine = wp('Karabinas', 3, 'weapon_carbinerifle', 'rifle_ammo', 120, 148000, 'advanced', 20, 18, 7, 60, 'extreme'),
    craft_ak47 = wp('AK-47', 3, 'weapon_assaultrifle', 'rifle_ammo', 120, 156000, 'advanced', 21, 19, 8, 62, 'extreme'),
    craft_micro_draco = wp('Micro Draco', 3, 'weapon_compactrifle', 'rifle_ammo', 90, 150000, 'advanced', 20, 18, 7, 60, 'extreme'),
}

Config.WeaponRecipes = {
    craft_pistol = {
        { item = 'gun_frame', count = 2 },
        { item = 'gun_barrel', count = 2 },
        { item = 'gun_spring', count = 3 },
        { item = 'gun_trigger', count = 2 },
        { item = 'metal_scrap', count = 6 },
        { item = 'weapon_parts', count = 2 },
    },
    craft_combat_pistol = {
        { item = 'gun_frame', count = 2 },
        { item = 'gun_barrel', count = 2 },
        { item = 'gun_spring', count = 3 },
        { item = 'gun_trigger', count = 2 },
        { item = 'weapon_parts', count = 2 },
        { item = 'metal_scrap', count = 8 },
    },
    craft_bat = {
        { item = 'metal_scrap', count = 6 },
        { item = 'weapon_parts', count = 2 },
    },
    craft_switchblade = {
        { item = 'metal_scrap', count = 4 },
        { item = 'gun_spring', count = 2 },
        { item = 'weapon_parts', count = 2 },
    },
    craft_tec9 = {
        { item = 'gun_frame', count = 2 },
        { item = 'gun_barrel', count = 2 },
        { item = 'gun_spring', count = 5 },
        { item = 'gun_trigger', count = 2 },
        { item = 'weapon_parts', count = 3 },
        { item = 'metal_scrap', count = 9 },
    },
    craft_mini_uzi = {
        { item = 'gun_frame', count = 2 },
        { item = 'gun_barrel', count = 3 },
        { item = 'gun_spring', count = 5 },
        { item = 'gun_trigger', count = 2 },
        { item = 'weapon_parts', count = 3 },
        { item = 'metal_scrap', count = 11 },
    },
    craft_smg = {
        { item = 'gun_frame', count = 3 },
        { item = 'gun_barrel', count = 3 },
        { item = 'gun_spring', count = 6 },
        { item = 'gun_trigger', count = 3 },
        { item = 'weapon_parts', count = 5 },
        { item = 'metal_scrap', count = 12 },
    },
    craft_pistol50 = {
        { item = 'gun_frame', count = 2 },
        { item = 'gun_barrel', count = 2 },
        { item = 'gun_spring', count = 3 },
        { item = 'gun_trigger', count = 2 },
        { item = 'weapon_parts', count = 3 },
        { item = 'metal_scrap', count = 9 },
    },
    craft_pumpshotgun = {
        { item = 'gun_frame', count = 3 },
        { item = 'gun_barrel', count = 3 },
        { item = 'gun_spring', count = 3 },
        { item = 'gun_trigger', count = 2 },
        { item = 'weapon_parts', count = 5 },
        { item = 'metal_scrap', count = 12 },
    },
    craft_carbine = {
        { item = 'gun_frame', count = 3 },
        { item = 'gun_barrel', count = 3 },
        { item = 'gun_spring', count = 5 },
        { item = 'gun_trigger', count = 3 },
        { item = 'weapon_parts', count = 8 },
        { item = 'metal_scrap', count = 15 },
    },
    craft_ak47 = {
        { item = 'gun_frame', count = 3 },
        { item = 'gun_barrel', count = 3 },
        { item = 'gun_spring', count = 6 },
        { item = 'gun_trigger', count = 3 },
        { item = 'weapon_parts', count = 9 },
        { item = 'metal_scrap', count = 18 },
    },
    craft_micro_draco = {
        { item = 'gun_frame', count = 3 },
        { item = 'gun_barrel', count = 3 },
        { item = 'gun_spring', count = 5 },
        { item = 'gun_trigger', count = 3 },
        { item = 'weapon_parts', count = 6 },
        { item = 'metal_scrap', count = 14 },
    },
}

--- Parduotuvė: visi fivempro_drugs itemai (žaliava, apdorota, supakuota, reikmenys, ginklų dalys)
Config.MaterialShop = {
    name = 'fivempro-illegal-supply',
    label = 'Nelegalūs reikmenys',
    items = {
        -- Kiekvienas narkotikas: 1 → 2 → 3 etapas
        -- THC / vape buteliukas
        { name = 'weed_leaf', amount = 500, price = 22, slot = 1 },
        { name = 'weed_resin', amount = 300, price = 48, slot = 2 },
        { name = 'thc_cart', amount = 200, price = 75, slot = 3 },
        -- Samagonas
        { name = 'alcohol_base', amount = 500, price = 18, slot = 4 },
        { name = 'moonshine_spirit', amount = 300, price = 42, slot = 5 },
        { name = 'illegal_alcohol', amount = 200, price = 58, slot = 6 },
        -- Vape skystis
        { name = 'vape_liquid_base', amount = 500, price = 16, slot = 7 },
        { name = 'vape_mix', amount = 300, price = 38, slot = 8 },
        { name = 'vape_liquid', amount = 200, price = 52, slot = 9 },
        -- Žolė
        { name = 'weed_buds', amount = 300, price = 55, slot = 10 },
        { name = 'weed_bag', amount = 200, price = 110, slot = 11 },
        -- Heroinas
        { name = 'poppy_flower', amount = 500, price = 28, slot = 12 },
        { name = 'heroin_paste', amount = 300, price = 72, slot = 13 },
        { name = 'heroin_bag', amount = 200, price = 175, slot = 14 },
        -- Metas
        { name = 'meth_ingredient', amount = 500, price = 35, slot = 15 },
        { name = 'meth_crystal', amount = 300, price = 85, slot = 16 },
        { name = 'meth_bag', amount = 200, price = 195, slot = 17 },
        -- Tabletės
        { name = 'pill_powder', amount = 500, price = 30, slot = 18 },
        { name = 'pill_tablets', amount = 300, price = 58, slot = 19 },
        { name = 'pills_pack', amount = 200, price = 145, slot = 20 },
        -- Grybai
        { name = 'mushroom_raw', amount = 500, price = 24, slot = 21 },
        { name = 'mushroom_dried', amount = 300, price = 50, slot = 22 },
        { name = 'mushroom_pack', amount = 200, price = 125, slot = 23 },
        -- Kokainas (lapai → nesupakuotas → supakuotas)
        { name = 'cartel_raw', amount = 500, price = 52, slot = 24 },
        { name = 'cartel_blend', amount = 300, price = 105, slot = 25 },
        { name = 'cartel_pack', amount = 200, price = 320, slot = 26 },
        -- Amfetaminas
        { name = 'amp_precursor', amount = 500, price = 38, slot = 27 },
        { name = 'amp_paste', amount = 300, price = 88, slot = 28 },
        { name = 'amphetamine_bag', amount = 200, price = 250, slot = 29 },
        -- Ekstra: reagentai ir įrankiai
        { name = 'chemical_mix', amount = 500, price = 40, slot = 33 },
        { name = 'filter', amount = 500, price = 8, slot = 34 },
        { name = 'gloves', amount = 200, price = 25, slot = 35 },
        { name = 'scale', amount = 100, price = 85, slot = 36 },
        { name = 'lab_kit', amount = 50, price = 220, slot = 37 },
        { name = 'burner', amount = 100, price = 120, slot = 38 },
        { name = 'empty_cart', amount = 500, price = 12, slot = 39 },
        { name = 'empty_bottle', amount = 500, price = 10, slot = 40 },
        { name = 'empty_bag', amount = 500, price = 11, slot = 41 },
        -- Ginklų dalys
        { name = 'metal_scrap', amount = 500, price = 55, slot = 43 },
        { name = 'gun_frame', amount = 200, price = 220, slot = 44 },
        { name = 'gun_barrel', amount = 200, price = 260, slot = 45 },
        { name = 'gun_spring', amount = 500, price = 45, slot = 46 },
        { name = 'gun_trigger', amount = 300, price = 85, slot = 47 },
        { name = 'weapon_parts', amount = 300, price = 150, slot = 48 },
        { name = 'pistol_ammo', amount = 500, price = 18, slot = 49 },
        { name = 'smg_ammo', amount = 500, price = 28, slot = 50 },
        { name = 'rifle_ammo', amount = 500, price = 35, slot = 51 },
        { name = 'shotgun_ammo', amount = 500, price = 32, slot = 52 },
        { name = '3d_printer', amount = 25, price = 7500, slot = 53 },
        { name = 'plastic', amount = 500, price = 22, slot = 54 },
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

--- Ingredientų parduotuvė (production) — Grove
Config.SupplyShopNPC = {
    enabled = true,
    model = 's_m_y_dealer_01',
    coords = vector4(124.15, -1930.62, 21.38, 118.0),
    scenario = 'WORLD_HUMAN_SMOKING',
    label = 'Nelegalūs reikmenys',
    maxDistance = 3.5,
    targetIcon = 'fas fa-store',
    blip = {
        enabled = true,
        sprite = 52,
        color = 27,
        scale = 0.8,
        label = 'Nelegalūs reikmenys',
    },
}

--- Testų parduotuvė (tik kai EnableDrugTestNPC) — LS airport
Config.TestSupplyShopNPC = {
    model = 's_m_y_dealer_01',
    coords = vector4(SUPPLY_SHOP_POS.x, SUPPLY_SHOP_POS.y, SUPPLY_SHOP_POS.z, DEV_ROW_H + 180.0),
    scenario = 'WORLD_HUMAN_SMOKING',
    label = 'Nelegalūs reikmenys (test)',
}

--- Produktų supirkėjai (production) — NPC perka supakuotus / tarpinius produktus
Config.ProductBuyerNPCs = {
    alcohol = {
        enabled = true,
        model = 's_m_m_dockworker_01',
        coords = vector4(186.4651, -1273.1499, 29.1985, 81.7421),
        scenario = 'WORLD_HUMAN_SMOKING',
        label = 'Alkoholio supirkėjas',
        sellAllLabel = 'Parduoti visą alkoholį',
        targetIcon = 'fas fa-wine-bottle',
        maxDistance = 3.5,
        blip = { enabled = true, sprite = 93, color = 5, scale = 0.75, label = 'Alkoholio supirkėjas' },
        prices = {
            illegal_alcohol = 75,
            moonshine_spirit = 42,
        },
    },
    thc = {
        enabled = true,
        model = 's_m_y_dealer_01',
        coords = vector4(-1164.4401, -1567.7615, 4.4471, 30.6944),
        scenario = 'WORLD_HUMAN_SMOKING',
        label = 'THC supirkėjas',
        sellAllLabel = 'Parduoti visą THC',
        targetIcon = 'fas fa-cannabis',
        maxDistance = 3.5,
        blip = { enabled = true, sprite = 140, color = 25, scale = 0.75, label = 'THC supirkėjas' },
        prices = {
            thc_cart = 95,
            weed_resin = 52,
        },
    },
    vape = {
        enabled = true,
        model = 's_m_y_dealer_01',
        coords = vector4(-1724.6089, 234.1453, 58.4717, 23.0746),
        scenario = 'WORLD_HUMAN_SMOKING',
        label = 'Vape skysčių supirkėjas',
        sellAllLabel = 'Parduoti visus vape skysčius',
        targetIcon = 'fas fa-smoking',
        maxDistance = 3.5,
        blip = { enabled = true, sprite = 52, color = 27, scale = 0.75, label = 'Vape supirkėjas' },
        prices = {
            vape_liquid = 65,
            vape_mix = 38,
        },
    },
}

--- @deprecated naudok Config.ProductBuyerNPCs.alcohol
Config.AlcoholBuyerNPC = Config.ProductBuyerNPCs.alcohol

--- Production žemėlapio blipai — visi kuriami `client/main.lua` → setupStationBlips()
--- Grybų rinkimas · Žolės reikmenys · Nelegalūs reikmenys · Heroino lab. · Amfetamino lab. · Supirkėjai
--- Cayo Perico sala + garažai — `fivempro_cayoperico` ir `fivempro_garages`

--- Grybų rinkimo laukai — prop'ai atauga po surinkimo
Config.MushroomFields = {
    {
        id = 'chiliad_meadow',
        center = vector3(2145.9426, 6418.3452, 153.0742),
        radius = 42.0,
        spawnCount = 16,
        respawnSec = 100,
        item = 'mushroom_raw',
        amountMin = 1,
        amountMax = 2,
        pickDurationMs = 5200,
        pickDistance = 2.4,
        pickLabel = 'Rinkti grybus',
        zoneRadius = 1.05,
        prop = 'prop_stoneshroom2',
        blip = {
            enabled = true,
            sprite = 469,
            color = 2,
            scale = 0.78,
            label = 'Grybų rinkimas',
        },
    },
}

--- Kokainmedžio lapų rinkimas (Cayo Perico)
Config.CocaFields = {
    {
        id = 'cayo_coca_grove',
        center = vector3(4715.0337, -4529.3638, 26.8199),
        radius = 48.0,
        spawnCount = 18,
        respawnSec = 120,
        item = 'cartel_raw',
        amountMin = 1,
        amountMax = 3,
        pickDurationMs = 5400,
        pickDistance = 2.5,
        pickLabel = 'Rinkti kokainmedžio lapus',
        zoneRadius = 1.05,
        prop = 'prop_plant_paradise_b',
        propScale = 0.52,
        requireIsland = true,
        blip = {
            enabled = true,
            sprite = 140,
            color = 2,
            scale = 0.76,
            label = 'Kokainmedžio lapai (Cayo)',
        },
    },
}

--- Žolės džiovinimas — hid_weed_lab MLO (Davis / LS)
Config.WeedCayoLab = {
    blip = {
        enabled = true,
        coords = vector3(1144.82, -1659.86, 36.61),
        sprite = 140,
        color = 25,
        scale = 0.78,
        shortRange = true,
        label = 'Žolės džiovinimas',
    },
    stations = {
        {
            id = 'weed_dry_1',
            label = 'Žolė · džiovinimas',
            level = 2,
            coords = vector3(1144.3669, -1658.9980, 36.6147),
            heading = 292.0355,
            radius = 1.5,
            products = { 'weed_process' },
        },
        {
            id = 'weed_dry_2',
            label = 'Žolė · džiovinimas',
            level = 2,
            coords = vector3(1145.2770, -1660.7167, 36.6147),
            heading = 291.2983,
            radius = 1.5,
            products = { 'weed_process' },
        },
    },
}

--- Heroino laboratorija (production) — Paleto / Grapeseed zona
Config.HeroinLab = {
    blip = {
        enabled = true,
        coords = vector3(1953.0, 5180.0, 47.98),
        sprite = 499,
        color = 1,
        scale = 0.82,
        label = 'Heroino laboratorija',
    },
    stations = {
        {
            id = 'heroin_lab_process_1',
            label = 'Heroinas · virimas',
            level = 2,
            coords = vector3(1951.3479, 5179.1650, 47.9838),
            heading = 357.6904,
            radius = 1.4,
            products = { 'heroin_process' },
        },
        {
            id = 'heroin_lab_process_2',
            label = 'Heroinas · virimas',
            level = 2,
            coords = vector3(1953.2771, 5179.2207, 47.9838),
            heading = 9.3222,
            radius = 1.4,
            products = { 'heroin_process' },
        },
        {
            id = 'heroin_lab_process_3',
            label = 'Heroinas · virimas',
            level = 2,
            coords = vector3(1955.4858, 5179.1523, 47.9838),
            heading = 10.8591,
            radius = 1.4,
            products = { 'heroin_process' },
        },
        {
            id = 'heroin_lab_pack_1',
            label = 'Heroinas · supakavimas',
            level = 2,
            coords = vector3(1953.3029, 5180.7964, 47.9838),
            heading = 182.5970,
            radius = 1.4,
            products = { 'heroin_pack' },
        },
        {
            id = 'heroin_lab_pack_2',
            label = 'Heroinas · supakavimas',
            level = 2,
            coords = vector3(1951.2515, 5180.7446, 47.9838),
            heading = 168.0956,
            radius = 1.4,
            products = { 'heroin_pack' },
        },
        {
            id = 'heroin_lab_both',
            label = 'Heroino perdirbimas',
            level = 2,
            coords = vector3(1943.1868, 5182.9590, 47.9838),
            heading = 3.7185,
            radius = 1.6,
            products = { 'heroin_process', 'heroin_pack' },
        },
    },
}

--- Tablečių presavimas — 2 etapas (production) · ta pati lab. zona kaip heroinas
Config.PillsLab = {
    blip = {
        enabled = true,
        coords = vector3(1953.0, 5180.0, 47.9838),
        sprite = 499,
        color = 38,
        scale = 0.78,
        shortRange = true,
        label = 'Tablečių gamyba',
    },
    stations = {
        {
            id = 'pills_lab_process_1',
            label = 'Tabletės · presavimas',
            level = 2,
            coords = vector3(1951.2238, 5179.1294, 47.9838),
            heading = 5.9604,
            radius = 1.4,
            products = { 'pills_process' },
        },
        {
            id = 'pills_lab_process_2',
            label = 'Tabletės · presavimas',
            level = 2,
            coords = vector3(1955.4041, 5179.1353, 47.9838),
            heading = 359.5552,
            radius = 1.4,
            products = { 'pills_process' },
        },
        {
            id = 'pills_lab_process_3',
            label = 'Tabletės · presavimas',
            level = 2,
            coords = vector3(1951.1562, 5180.8154, 47.9838),
            heading = 172.7080,
            radius = 1.4,
            products = { 'pills_process' },
        },
        {
            id = 'pills_lab_process_4',
            label = 'Tabletės · presavimas',
            level = 2,
            coords = vector3(1955.4730, 5180.8521, 47.9838),
            heading = 176.3169,
            radius = 1.4,
            products = { 'pills_process' },
        },
        {
            id = 'pills_lab_process_5',
            label = 'Tabletės · presavimas',
            level = 2,
            coords = vector3(1943.0104, 5182.9053, 47.9838),
            heading = 3.1554,
            radius = 1.6,
            products = { 'pills_process' },
        },
    },
}

--- Metamfetamino laboratorija — supakavimo stalas (Grapeseed)
Config.MethLab = {
    blip = {
        enabled = true,
        coords = vector3(2709.0989, 5235.0547, 49.3645),
        sprite = 499,
        color = 3,
        scale = 0.82,
        label = 'Metamfetamino laboratorija',
    },
    stations = {
        {
            id = 'meth_lab_pack',
            label = 'Metas · supakavimas',
            level = 2,
            coords = vector3(2709.0989, 5235.0547, 49.3645),
            heading = 286.5156,
            radius = 1.5,
            products = { 'meth_pack' },
        },
    },
}

--- Amfetamino mobilioji laboratorija — Zirconium Journey + dykuma prie Grapeseed
Config.AmpExclusiveProducts = { amp_process = true, amp_pack = true }

Config.AmpMobileLab = {
    enabled = true,
    vehicleModels = { journey = true, journey2 = true },
    vehicleMaxDistance = 9.0,
    lab = {
        coords = vector3(1903.48, 4922.55, 48.86),
        radius = 14.0,
        label = 'Amfetamino laboratorija',
    },
    processDurationMs = 72000,
    questionCount = 3,
    outputItem = 'amp_paste',
    yieldByWrong = { [0] = 2, [1] = 1, [2] = 1, [3] = 0 },
    policeChance = 18,
    blip = {
        enabled = true,
        coords = vector3(1903.48, 4922.55, 48.86),
        sprite = 499,
        color = 5,
        scale = 0.82,
        label = 'Amfetamino laboratorija',
    },
    packStation = {
        id = 'amp_lab_pack',
        label = 'Amfetaminas · supakavimas',
        level = 3,
        coords = vector3(1908.20, 4926.80, 48.86),
        heading = 225.0,
        radius = 1.6,
        products = { 'amp_pack' },
    },
    recipe = {
        { item = 'amp_precursor', count = 4 },
        { item = 'chemical_mix', count = 2 },
        { item = 'lab_kit', count = 1 },
    },
    questions = {
        { q = 'Koks pH tinkamiausias precursoriaus neutralizavimui?', options = { '3–4 (rūgštus)', '7–8 (neutralus)', '11–12 (šarmus)' }, answer = 2 },
        { q = 'Kuris reagentas stabdo nepageidaujamą polimerizaciją?', options = { 'Eteris', 'Acetono inhibitorius', 'Druska' }, answer = 2 },
        { q = 'Kokia distiliacijos temperatūra saugiausia sintezei?', options = { '45–55 °C', '95–110 °C', '180–200 °C' }, answer = 2 },
        { q = 'Ką daryti, jei mišinys pradeda virpėti?', options = { 'Padidinti šilumą', 'Sumažinti temperatūrą ir maišyti', 'Nieko — tai normalu' }, answer = 2 },
        { q = 'Kuris indas tinka rūgštims ir solventams?', options = { 'Aliuminis', 'Stiklas ar PTFE', 'Plienas be dangos' }, answer = 2 },
        { q = 'Kada sustabdyti sintezę?', options = { 'Kai kvepuoja balta migla', 'Kai pasiekiamas stabilus kristalizacijos etapas', 'Kai išgaruoja visas vanduo' }, answer = 2 },
        { q = 'Koks ventiliacijos tikslas laboratorijoje?', options = { 'Sumažinti drėgmę', 'Pašalinti garus ir apsaugoti nuo sprogimo', 'Padidinti slėgį' }, answer = 2 },
        { q = 'Ką reiškia drumstumas mišinyje po neutralizacijos?', options = { 'Sėkmė', 'Per daug vandens', 'Netinkamas pH ar nešvarumai' }, answer = 3 },
    },
}

--- Test meniu — duoda itemus / atidaro UI
Config.TestKits = {
    level1 = {
        weed_leaf = 20, alcohol_base = 10, vape_liquid_base = 10,
        empty_cart = 10, empty_bottle = 10, filter = 10, empty_bag = 20,
    },
    level2 = {
        weed_leaf = 30, poppy_flower = 20, meth_ingredient = 15, pill_powder = 15,
        mushroom_raw = 15, chemical_mix = 15, empty_bag = 35, scale = 5,
        lab_kit = 3, gloves = 5,
    },
    level3 = {
        cartel_raw = 25, chemical_mix = 20, meth_ingredient = 10, pill_powder = 15,
        amp_precursor = 20,
        lab_kit = 5, empty_bag = 35, scale = 5, burner = 3,
    },
}
