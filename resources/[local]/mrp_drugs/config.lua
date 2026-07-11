Config = {}

--[[
  mrp_drugs — pagrindinė konfigūracija.

  Architektūra:
    · Config.Products / Config.Recipes — 3 etapai: process → pack → pardavimas
    · Config.Stations + lab MLO — klasikinė gamyba stotyje
    · config_equipment.lua — tk_drugs stiliaus prop įranga (portable + fixed)
    · html/mg-*.js — Schedule minigame moduliai per narkotiko liniją
    · shared/minigame_registry.lua — productId → minigame profilis

  Test režimas: Config.EnableDrugTestNPC + Config.DevHub (LS airport eilė)
]]

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
Config.EnableDrugTestNPC = false

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

-- Laikinai išjungta, kol serverio etapų protokolas galės autoritetingai
-- patvirtinti score. Kliento atsiųstas score vienas pats nėra patikimas.
Config.UseQuality = false

--- Minigame tipai: progress | skill | advanced | schedule
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
    thc_process = drugProcess('THC · distiliacija', 1, 'thc_resin', 14000, 'low', 'schedule', 5, 3, 1, 35, 1),
    thc_pack = drugPack('THC kasetė · supakavimas', 1, 'thc_cart', 95, 12000, 'low', 'schedule', 6, 4, 2, 35, 2),
    alcohol_process = drugProcess('Samagonas · distiliacija', 1, 'moonshine_spirit', 13000, 'low', 'schedule', 4, 3, 1, 30, 3),
    alcohol_pack = drugPack('Nelegalus alkoholis · supakavimas', 1, 'illegal_alcohol', 75, 11000, 'low', 'schedule', 5, 3, 2, 30, 4),
    vape_process = drugProcess('Vape · paruošimas', 1, 'vape_mix', 12000, 'low', 'schedule', 4, 2, 1, 28, 5),
    vape_pack = drugPack('Vape skystis · supakavimas', 1, 'vape_liquid', 65, 10000, 'low', 'schedule', 5, 3, 1, 28, 6, 2),
    --- L2
    weed_process = drugProcess('Žolė · džiovinimas', 2, 'weed_buds', 18000, 'medium', 'schedule', 10, 6, 3, 45, 7),
    weed_pack = drugPack('Žolė · supakavimas', 2, 'weed_bag', 140, 15000, 'medium', 'schedule', 12, 8, 4, 50, 8),
    heroin_process = drugProcess('Heroinas · virimas', 2, 'heroin_paste', 22000, 'medium', 'schedule', 12, 8, 4, 50, 9),
    heroin_pack = drugPack('Heroinas · supakavimas', 2, 'heroin_bag', 220, 16000, 'medium', 'schedule', 14, 10, 5, 55, 10),
    meth_process = drugProcess('Metas · kristalizacija', 2, 'meth_crystal', 26000, 'high', 'schedule', 13, 10, 5, 55, 11),
    meth_pack = drugPack('Metas · supakavimas', 2, 'meth_bag', 260, 18000, 'high', 'schedule', 15, 12, 6, 60, 12),
    pills_process = drugProcess('Tabletės · presavimas', 2, 'pill_tablets', 17000, 'medium', 'schedule', 9, 6, 3, 40, 13, 2),
    pills_pack = drugPack('Tabletės · supakavimas', 2, 'pills_pack', 180, 14000, 'medium', 'schedule', 11, 7, 4, 45, 14),
    mushroom_process = drugProcess('Grybai · džiovinimas', 2, 'mushroom_dried', 15000, 'medium', 'schedule', 8, 5, 2, 38, 15),
    mushroom_pack = drugPack('Grybai · supakavimas', 2, 'mushroom_pack', 150, 13000, 'medium', 'schedule', 10, 6, 3, 40, 16),
    --- L3 — kokainas: lapai → nesupakuotas → supakuotas
    cocaine_process = drugProcess('Kokainas · virimas', 3, 'cartel_blend', 35000, 'high', 'schedule', 20, 15, 7, 65, 17),
    cocaine_pack = drugPack('Kokainas · supakavimas', 3, 'cartel_pack', 520, 24000, 'high', 'schedule', 25, 20, 10, 70, 18),
    amp_process = drugProcess('Amfetaminas · sintezė', 3, 'amp_paste', 30000, 'high', 'schedule', 17, 11, 6, 60, 19),
    amp_pack = drugPack('Amfetaminas · supakavimas', 3, 'amphetamine_bag', 380, 20000, 'high', 'schedule', 20, 14, 7, 65, 20),
}

Config.Recipes = {
    --- L1: žaliava → apdorota → supakuota
    thc_process = {
        { item = 'hemp_trim', count = 5 },
        { item = 'filter', count = 1 },
        { item = 'gloves', count = 1 },
    },
    thc_pack = {
        { item = 'thc_resin', count = 1 },
        { item = 'empty_cart', count = 1 },
        { item = 'empty_bottle', count = 1 },
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
        { item = 'weed_leaf', count = 2 },
    },
    weed_pack = {
        { item = 'weed_buds', count = 1 },
        { item = 'empty_bag', count = 1 },
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
        { item = 'pill_press', count = 1 },
        { item = 'lab_kit', count = 1 },
    },
    pills_pack = {
        { item = 'pill_tablets', count = 2 },
        { item = 'empty_bag', count = 3 },
    },
    mushroom_process = {
        { item = 'mushroom_raw', count = 5 },
        { item = 'trimming_scissors', count = 1 },
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
    item = 'printer_3d',
    propModel = 'prop_printer_01',
    maxPerPlayer = 2,
    pickupDist = 2.8,
    interactDist = 2.4,
    products = {
        print_gun_frame = {
            label = 'Ginklo korpusas',
            output = { item = 'gun_frame', count = 1 },
            ingredients = {
                { item = 'weapon_prototype', count = 1 },
                { item = 'metal_scrap', count = 5 },
                { item = 'plastic', count = 6 },
            },
            timeMs = 52000,
        },
        print_gun_barrel = {
            label = 'Vamzdis',
            output = { item = 'gun_barrel', count = 1 },
            ingredients = {
                { item = 'weapon_prototype', count = 1 },
                { item = 'metal_scrap', count = 6 },
                { item = 'plastic', count = 5 },
            },
            timeMs = 56000,
        },
        print_gun_spring = {
            label = 'Spyruoklė',
            output = { item = 'gun_spring', count = 2 },
            ingredients = {
                { item = 'weapon_prototype', count = 1 },
                { item = 'metal_scrap', count = 3 },
                { item = 'plastic', count = 3 },
            },
            timeMs = 35000,
        },
        print_gun_trigger = {
            label = 'Užtaisas',
            output = { item = 'gun_trigger', count = 1 },
            ingredients = {
                { item = 'weapon_prototype', count = 1 },
                { item = 'metal_scrap', count = 3 },
                { item = 'plastic', count = 5 },
            },
            timeMs = 40000,
        },
        print_weapon_parts = {
            label = 'Ginklo komponentai',
            output = { item = 'weapon_parts', count = 1 },
            ingredients = {
                { item = 'weapon_prototype', count = 1 },
                { item = 'metal_scrap', count = 8 },
                { item = 'plastic', count = 8 },
            },
            timeMs = 68000,
        },
        print_ziptie = {
            label = 'Plastikiniai dirželiai',
            output = { item = 'ziptie', count = 3 },
            ingredients = {
                { item = 'plastic', count = 4 },
                { item = 'metal_scrap', count = 1 },
            },
            timeMs = 22000,
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
    craft_armor_light = wp('Lengva šarvų liemenė', 1, 'armor_light', nil, 0, 72000, 'progress', 10, 6, 2, 40, 'medium'),
    craft_bat = wp('Beisbolo lazda', 1, 'weapon_bat', nil, 0, 82000, 'progress', 6, 4, 1, 30, 'low'),
    craft_switchblade = wp('Switchblade', 1, 'weapon_switchblade', nil, 0, 85000, 'progress', 8, 5, 2, 35, 'low'),
    --- L2 — SMG / .50 / shotgun (~95–120 s + minigame)
    craft_tec9 = wp('Tec-9', 2, 'weapon_machinepistol', 'pistol_ammo', 90, 115000, 'skill', 16, 14, 5, 52, 'high'),
    craft_mini_uzi = wp('Mini Uzi', 2, 'weapon_minismg', 'smg_ammo', 90, 120000, 'skill', 17, 15, 5, 54, 'high'),
    craft_smg = wp('SMG', 2, 'weapon_smg', 'smg_ammo', 120, 125000, 'skill', 18, 16, 6, 56, 'high'),
    craft_fgc9 = wp('FGC-9', 2, 'weapon_fgc9', 'pistol_ammo', 90, 128000, 'skill', 17, 15, 5, 54, 'high'),
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
    craft_armor_light = {
        { item = 'metal_scrap', count = 8 },
        { item = 'plastic', count = 5 },
        { item = 'weapon_parts', count = 2 },
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
    craft_fgc9 = {
        { item = 'gun_frame', count = 3 },
        { item = 'gun_barrel', count = 2 },
        { item = 'gun_spring', count = 5 },
        { item = 'gun_trigger', count = 2 },
        { item = 'weapon_parts', count = 4 },
        { item = 'weapon_prototype', count = 1 },
        { item = 'plastic', count = 10 },
        { item = 'metal_scrap', count = 8 },
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

--- Parduotuvė: visi mrp_drugs itemai (žaliava, apdorota, supakuota, reikmenys, ginklų dalys)
Config.MaterialShop = {
    name = 'fivempro-illegal-supply',
    label = 'Nelegalūs reikmenys',
    --[[
      SVARBU (žaliavų gavimo principas):
        · MaterialShop parduoda TIK bendrus gamybos reikmenis (maišeliai, filtrai,
          pirštinės, svarstyklės, buteliai, kasetės, lab įranga).
        · NARKOTIKŲ ŽALIAVOS, apdoroti ir galutiniai produktai ČIA NEPARDUODAMI.
          Žaliavos gaunamos: pasaulyje (auginimas, rinkimas, aguonų laukas),
          per NPC (alkoholio fermentacija, vape chemikas, tablečių kontaktas)
          arba per Dark Net (hemp_trim, meth precursor, amp precursor, chemical_mix).
        · Žr. config_darknet.lua → Config.WorldSources ir Config.DarkNet.products.
    ]]
    items = {
        -- Bendri pakavimo / gamybos reikmenys
        { name = 'trimming_scissors', amount = 200, price = 110, slot = 1 },
        { name = 'gloves', amount = 200, price = 30, slot = 2 },
        { name = 'empty_bag', amount = 500, price = 14, slot = 3 },
        { name = 'empty_cart', amount = 500, price = 15, slot = 4 },
        { name = 'empty_bottle', amount = 500, price = 13, slot = 5 },
        { name = 'filter', amount = 500, price = 10, slot = 6 },
        { name = 'scale', amount = 100, price = 95, slot = 7 },
        { name = 'lab_kit', amount = 50, price = 260, slot = 8 },
        { name = 'burner', amount = 100, price = 140, slot = 9 },
        { name = 'pill_press', amount = 100, price = 320, slot = 10 },
        { name = 'bagging_table', amount = 80, price = 220, slot = 11 },
        -- 3D spausdinimas (atskira ginklų sistema — ne narkotikai)
        { name = 'weapon_prototype', amount = 200, price = 380, slot = 12 },
        { name = 'printer_3d', amount = 25, price = 7500, slot = 13 },
        { name = 'plastic', amount = 500, price = 22, slot = 14 },
        -- Ginklų dalys (atskira ginklų sistema — ne narkotikai)
        { name = 'metal_scrap', amount = 500, price = 55, slot = 15 },
        { name = 'gun_frame', amount = 200, price = 220, slot = 16 },
        { name = 'gun_barrel', amount = 200, price = 260, slot = 17 },
        { name = 'gun_spring', amount = 500, price = 45, slot = 18 },
        { name = 'gun_trigger', amount = 300, price = 85, slot = 19 },
        { name = 'weapon_parts', amount = 300, price = 150, slot = 20 },
        { name = 'pistol_ammo', amount = 500, price = 18, slot = 21 },
        { name = 'smg_ammo', amount = 500, price = 28, slot = 22 },
        { name = 'rifle_ammo', amount = 500, price = 35, slot = 23 },
        { name = 'shotgun_ammo', amount = 500, price = 32, slot = 24 },
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
    --- Pardavimo atlygis inventoriaus item (nešvarūs pinigai), ne grynieji cash.
    payoutItem = 'markedbills',
    --- 0 = vienas item su visa suma info.worth; >0 = skaidyti į kelis banknotus.
    payoutBillWorth = 0,
    --- Jei inventoriuje vietos nėra — ar leisti grynuosius kaip atsarginį variantą.
    payoutFallbackCash = true,
}

--- Gatvės / NPC pardavimo animacija (rankų perdavimas)
Config.SellAnim = {
    label = 'Sandoris su pirkėju...',
    durationMs = 2800,
    faceMs = 550,
    player = { dict = 'mp_common', clip = 'givetake1_a', flag = 49 },
    npc = { dict = 'mp_common', clip = 'givetake1_b', flag = 49 },
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

--- Produktų supirkėjai (production) — NPC perka tik supakuotus galutinius produktus
Config.ProductBuyerNPCs = {
    alcohol = {
        enabled = true,
        model = 's_m_m_dockwork_01',
        coords = vector4(186.4651, -1273.1499, 29.1985, 81.7421),
        scenario = 'WORLD_HUMAN_SMOKING',
        label = 'Alkoholio supirkėjas',
        sellAllLabel = 'Parduoti supakuotą alkoholį',
        targetIcon = 'fas fa-wine-bottle',
        maxDistance = 3.5,
        blip = { enabled = true, sprite = 93, color = 5, scale = 0.75, label = 'Alkoholio supirkėjas' },
        prices = {
            illegal_alcohol = 120,
        },
    },
    thc = {
        enabled = true,
        model = 's_m_y_dealer_01',
        coords = vector4(-1164.4401, -1567.7615, 4.4471, 30.6944),
        scenario = 'WORLD_HUMAN_SMOKING',
        label = 'THC supirkėjas',
        sellAllLabel = 'Parduoti supakuotą THC',
        targetIcon = 'fas fa-cannabis',
        maxDistance = 3.5,
        blip = { enabled = true, sprite = 140, color = 25, scale = 0.75, label = 'THC supirkėjas' },
        prices = {
            thc_cart = 170,
        },
    },
    vape = {
        enabled = true,
        model = 's_m_y_dealer_01',
        coords = vector4(-1724.6089, 234.1453, 58.4717, 23.0746),
        scenario = 'WORLD_HUMAN_SMOKING',
        label = 'Vape skysčių supirkėjas',
        sellAllLabel = 'Parduoti supakuotus vape skysčius',
        targetIcon = 'fas fa-smoking',
        maxDistance = 3.5,
        blip = { enabled = true, sprite = 52, color = 27, scale = 0.75, label = 'Vape supirkėjas' },
        prices = {
            vape_liquid = 190,
        },
    },
    weed = {
        enabled = true,
        model = 's_m_y_barman_01',
        coords = vector4(-3.4450, -1820.9264, 29.5432, 230.3047),
        scenario = 'WORLD_HUMAN_SMOKING',
        label = 'Žolės supirkėjas',
        sellAllLabel = 'Parduoti supakuotą žolę',
        targetIcon = 'fas fa-cannabis',
        maxDistance = 3.5,
        blip = { enabled = true, sprite = 140, color = 2, scale = 0.75, label = 'Žolės supirkėjas' },
        prices = {
            weed_bag = 260,
        },
    },
    cocaine = {
        enabled = true,
        model = 's_m_y_dealer_01',
        coords = vector4(5587.6470, -5220.6377, 14.6235, 57.1762),
        scenario = 'WORLD_HUMAN_SMOKING',
        label = 'Kokaino supirkėjas',
        sellAllLabel = 'Parduoti supakuotą kokainą',
        targetIcon = 'fas fa-snowflake',
        maxDistance = 3.5,
        blip = { enabled = true, sprite = 501, color = 0, scale = 0.75, label = 'Kokaino supirkėjas' },
        prices = {
            cartel_pack = 620,
        },
    },
    heroin = {
        enabled = true,
        model = 's_m_y_dealer_01',
        coords = vector4(357.24, -2055.82, 22.09, 140.0),
        scenario = 'WORLD_HUMAN_SMOKING',
        label = 'Heroino supirkėjas',
        sellAllLabel = 'Parduoti supakuotą heroiną',
        targetIcon = 'fas fa-syringe',
        maxDistance = 3.5,
        blip = { enabled = true, sprite = 51, color = 1, scale = 0.75, label = 'Heroino supirkėjas' },
        prices = { heroin_bag = 320 },
    },
    meth = {
        enabled = true,
        model = 's_m_y_dealer_01',
        coords = vector4(1981.52, 5177.18, 47.98, 270.0),
        scenario = 'WORLD_HUMAN_SMOKING',
        label = 'Metamfetamino supirkėjas',
        sellAllLabel = 'Parduoti supakuotą metą',
        targetIcon = 'fas fa-flask',
        maxDistance = 3.5,
        blip = { enabled = true, sprite = 499, color = 3, scale = 0.75, label = 'Metamfetamino supirkėjas' },
        prices = { meth_bag = 420 },
    },
    pills = {
        enabled = true,
        model = 's_m_m_dockwork_01',
        coords = vector4(-661.18, -857.82, 24.48, 0.0),
        scenario = 'WORLD_HUMAN_SMOKING',
        label = 'Tablečių supirkėjas',
        sellAllLabel = 'Parduoti supakuotas tabletes',
        targetIcon = 'fas fa-pills',
        maxDistance = 3.5,
        blip = { enabled = true, sprite = 51, color = 17, scale = 0.75, label = 'Tablečių supirkėjas' },
        prices = { pills_pack = 300 },
    },
    mushroom = {
        enabled = true,
        model = 's_m_y_barman_01',
        coords = vector4(-103.52, 6346.18, 31.48, 45.0),
        scenario = 'WORLD_HUMAN_SMOKING',
        label = 'Grybų supirkėjas',
        sellAllLabel = 'Parduoti supakuotus grybus',
        targetIcon = 'fas fa-seedling',
        maxDistance = 3.5,
        blip = { enabled = true, sprite = 469, color = 7, scale = 0.75, label = 'Grybų supirkėjas' },
        prices = { mushroom_pack = 250 },
    },
    amp = {
        enabled = true,
        model = 's_m_y_dealer_01',
        coords = vector4(1905.02, 4918.04, 48.86, 225.0),
        scenario = 'WORLD_HUMAN_SMOKING',
        label = 'Amfetamino supirkėjas',
        sellAllLabel = 'Parduoti supakuotą amfetaminą',
        targetIcon = 'fas fa-bolt',
        maxDistance = 3.5,
        blip = { enabled = true, sprite = 499, color = 5, scale = 0.75, label = 'Amfetamino supirkėjas' },
        prices = { amphetamine_bag = 700 },
    },
}

--- @deprecated naudok Config.ProductBuyerNPCs.alcohol
Config.AlcoholBuyerNPC = Config.ProductBuyerNPCs.alcohol

--- Production žemėlapio blipai — visi kuriami `client/main.lua` → setupStationBlips()
--- Grybų rinkimas · Žolės reikmenys · Nelegalūs reikmenys · Heroino lab. · Amfetamino lab. · Supirkėjai
--- Cayo Perico sala + garažai — `mrp_cayoperico` ir `mrp_garages`

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
        zoneRadius = 1.2,
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
        propScale = 0.7,
        requireIsland = true,
        blip = {
            enabled = true,
            sprite = 140,
            color = 2,
            scale = 0.5,
            label = 'Kokainmedžio lapai 1 (Cayo)',
        },
    }
}    

--- Kanapių auginimo reikmenys — Grapeseed kalnai (sėklos, vazonai; ne paruošta žolė)
Config.WeedSupplyShop = {
    name = 'fivempro-weed-supply',
    label = 'Kanapių auginimo reikmenys',
    items = {
        { name = 'weed_seed', amount = 500, price = 18, slot = 1 },
        { name = 'grow_pot', amount = 300, price = 42, slot = 2 },
        { name = 'weed_nutrition', amount = 400, price = 22, slot = 3 },
        { name = 'trimming_scissors', amount = 200, price = 95, slot = 4 },
        { name = 'gloves', amount = 200, price = 25, slot = 5 },
        { name = 'scale', amount = 100, price = 85, slot = 6 },
        { name = 'bagging_table', amount = 80, price = 175, slot = 8 },
        { name = 'watering_can', amount = 150, price = 65, slot = 7, info = { water = 100 } },
        { name = 'empty_bag', amount = 500, price = 11, slot = 9 },
    },
}

Config.WeedSupplyShopNPC = {
    enabled = true,
    model = 's_m_y_dealer_01',
    coords = vector4(2221.8557, 5614.7979, 54.9016, 107.1460),
    scenario = 'WORLD_HUMAN_SMOKING',
    label = 'Kanapių auginimo reikmenys',
    maxDistance = 3.5,
    targetIcon = 'fas fa-cannabis',
    blip = {
        enabled = true,
        sprite = 469,
        color = 25,
        scale = 0.78,
        label = 'Kanapių reikmenys',
    },
}

--- Kanapių auginimas — grow_pot + weed_nutrition (substratas) + sėklos + mini-game etapai
Config.WeedGrow = {
    seedItem = 'weed_seed',
    potItem = 'grow_pot',
    potItems = { 'grow_pot' },
    soilItem = 'weed_nutrition',
    harvestItem = 'weed_leaf',
    waterCanItem = 'watering_can',
    waterCanCapacity = 100,
    waterPerUse = 8,
    waterNaturalRefillMs = 6000,
    waterNaturalMaxDistance = 4.0,
    scissorsItem = 'trimming_scissors',
    glovesItem = 'gloves',
    harvestMin = 2,
    harvestMax = 6,
    qualityStart = 72,
    qualityMin = 20,
    qualityMax = 100,
    moistureStart = 48,
    moistureOptimalMin = 42,
    moistureOptimalMax = 68,
    moistureDryThreshold = 28,
    stage2Sec = 180,
    stage3Sec = 480,
    waterBonusSec = 55,
    waterCooldownSec = 120,
    maxWaters = 4,
    pickDistance = 2.2,
    zoneRadius = 0.95,
    loadDistance = 140.0,
    minPotDistance = 2.0,
    maxPotsPerPlayer = 8,
    maxPotsGlobal = 250,
    playerCooldownSec = 3,
    placeForwardM = 1.15,
    placeGhostAlpha = 160,
    soilLabel = 'Supilti žemę',
    plantLabel = 'Sodinti sėklas',
    waterLabel = 'Laistyti laistytuvu',
    harvestLabel = 'Skinti žirklėmis',
    pickupLabel = 'Surinkti dėžę',
    potModel = 'bkr_prop_weed_bucket_01a',
    potScale = 0.92,
    plantAttachZ = { stage1 = 0.20, stage2 = 0.26, stage3 = 0.32 },
    plantProps = {
        stage1 = 'prop_weed_02',
        stage2 = 'bkr_prop_weed_med_01a',
        stage3 = 'bkr_prop_weed_lrg_01a',
    },
    plantScale = { stage1 = 0.28, stage2 = 0.48, stage3 = 0.78 },
}

--- Senas fiksuotų laukų režimas — išjungta (naudok Config.WeedGrow + grow_pot)
Config.WeedGrowFields = {}

--- THC distiliacija — 2 etapas (production) · Sandy Shores laboratorija
Config.ThcLab = {
    blip = {
        enabled = true,
        coords = vector3(1391.13, 3603.61, 38.94),
        sprite = 140,
        color = 25,
        scale = 0.78,
        shortRange = true,
        label = 'THC laboratorija',
    },
    stations = {
        {
            id = 'thc_lab_process_1',
            label = 'THC · distiliacija',
            level = 1,
            coords = vector3(1389.0527, 3605.6160, 38.9419),
            heading = 292.4335,
            radius = 1.5,
            products = { 'thc_process' },
        },
        {
            id = 'thc_lab_process_2',
            label = 'THC · distiliacija',
            level = 1,
            coords = vector3(1389.8134, 3603.4443, 38.9419),
            heading = 290.9305,
            radius = 1.5,
            products = { 'thc_process' },
        },
        {
            id = 'thc_lab_process_3',
            label = 'THC · distiliacija',
            level = 1,
            coords = vector3(1394.5112, 3601.7563, 38.9419),
            heading = 201.5253,
            radius = 1.5,
            products = { 'thc_process' },
        },
        {
            id = 'thc_lab_pack_1',
            label = 'THC · supakavimas',
            level = 1,
            coords = vector3(1393.85, 3601.20, 38.9419),
            heading = 200.0,
            radius = 1.5,
            products = { 'thc_pack' },
        },
    },
}

--- Ginklų dirbtuvė · L1 — šarvai ir pistoletai (Mount Chiliad)
Config.WeaponBenchL1 = {
    blip = {
        enabled = true,
        coords = vector3(-1142.7271, 4941.6255, 222.3038),
        sprite = 110,
        color = 1,
        scale = 0.78,
        shortRange = true,
        label = 'Ginklų dirbtuvė · L1',
    },
    stations = {
        {
            id = 'weapon_bench_l1_chiliad',
            label = 'Ginklų dirbtuvė · L1',
            level = 1,
            mode = 'weapon',
            coords = vector3(-1142.7271, 4941.6255, 222.3038),
            heading = 162.4606,
            radius = 2.0,
            products = {
                'craft_pistol',
                'craft_combat_pistol',
                'craft_armor_light',
            },
        },
    },
}

--- Žolės džiovinimas (Davis) + supakavimas (Cayo Perico)
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
    packBlip = {
        enabled = true,
        requireIsland = true,
        coords = vector3(5195.83, -5134.91, 3.35),
        sprite = 140,
        color = 2,
        scale = 0.78,
        shortRange = true,
        label = 'Žolės supakavimas',
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
    packStations = {
        {
            id = 'weed_pack_cayo_1',
            label = 'Žolė · supakavimas',
            level = 2,
            coords = vector3(5196.0693, -5133.6929, 3.3579),
            heading = 255.6201,
            radius = 1.5,
            products = { 'weed_pack' },
        },
        {
            id = 'weed_pack_cayo_2',
            label = 'Žolė · supakavimas',
            level = 2,
            coords = vector3(5195.5938, -5136.1323, 3.3498),
            heading = 269.6169,
            radius = 1.5,
            products = { 'weed_pack' },
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

--- Tablečių presavimas — 2 etapas (production) · Davis (atskirai nuo heroino)
Config.PillsLab = {
    blip = {
        enabled = true,
        coords = vector3(348.50, -2062.00, 21.24),
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
            coords = vector3(346.80, -2063.50, 21.24),
            heading = 140.0,
            radius = 1.4,
            products = { 'pills_process' },
        },
        {
            id = 'pills_lab_process_2',
            label = 'Tabletės · presavimas',
            level = 2,
            coords = vector3(348.50, -2062.00, 21.24),
            heading = 140.0,
            radius = 1.4,
            products = { 'pills_process' },
        },
        {
            id = 'pills_lab_process_3',
            label = 'Tabletės · presavimas',
            level = 2,
            coords = vector3(350.20, -2060.50, 21.24),
            heading = 140.0,
            radius = 1.4,
            products = { 'pills_process' },
        },
        {
            id = 'pills_lab_pack_1',
            label = 'Tabletės · supakavimas',
            level = 2,
            coords = vector3(351.20, -2058.40, 21.24),
            heading = 140.0,
            radius = 1.4,
            products = { 'pills_pack' },
        },
        {
            id = 'pills_lab_pack_2',
            label = 'Tabletės · supakavimas',
            level = 2,
            coords = vector3(353.00, -2056.80, 21.24),
            heading = 140.0,
            radius = 1.4,
            products = { 'pills_pack' },
        },
    },
}

--- Metamfetamino laboratorija — kristalizacija + supakavimas (Grapeseed)
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
            id = 'meth_lab_process',
            label = 'Metas · kristalizacija',
            level = 2,
            coords = vector3(2712.4521, 5238.1844, 49.3645),
            heading = 286.5156,
            radius = 1.5,
            products = { 'meth_process' },
        },
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

--- Samagono distiliatorius — Paleto Bay šiaurė (L1)
Config.AlcoholLab = {
    blip = {
        enabled = true,
        coords = vector3(2381.75, 4953.01, 42.93),
        sprite = 93,
        color = 46,
        scale = 0.8,
        label = 'Samagono distiliatorius',
    },
    stations = {
        {
            id = 'alcohol_lab_process',
            label = 'Samagonas · distiliacija',
            level = 1,
            coords = vector3(2381.75, 4953.01, 42.93),
            heading = 45.0,
            radius = 1.6,
            products = { 'alcohol_process' },
        },
        {
            id = 'alcohol_lab_pack',
            label = 'Samagonas · supakavimas',
            level = 1,
            coords = vector3(2377.54, 4938.41, 43.02),
            heading = 45.0,
            radius = 1.6,
            products = { 'alcohol_pack' },
        },
    },
}

--- Vape skysčio laboratorija — uostas (L1)
Config.VapeLab = {
    blip = {
        enabled = true,
        coords = vector3(-805.8605, -3242.8604, 14.0821),
        sprite = 52,
        color = 26,
        scale = 0.78,
        label = 'Vape laboratorija',
    },
    stations = {
        {
            id = 'vape_lab_process',
            label = 'Vape · paruošimas',
            level = 1,
            coords = vector3(-805.8605, -3242.8604, 14.0821),
            heading = 90.0,
            radius = 1.6,
            products = { 'vape_process' },
        },
        {
            id = 'vape_lab_pack',
            label = 'Vape · supakavimas',
            level = 1,
            coords = vector3(-815.1697, -3237.5278, 14.1465),
            heading = 90.0,
            radius = 1.6,
            products = { 'vape_pack' },
        },
    },
}

--- Grybų perdirbimas — šalia rinkimo lauko (Mount Chiliad)
Config.MushroomLab = {
    blip = {
        enabled = true,
        coords = vector3(2806.6318, 5978.7598, 350.8817),
        sprite = 469,
        color = 7,
        scale = 0.78,
        label = 'Grybų perdirbimas',
    },
    stations = {
        {
            id = 'mushroom_lab_process',
            label = 'Grybai · džiovinimas',
            level = 2,
            coords = vector3(2806.6318, 5978.7598, 350.8817),
            heading = 120.0,
            radius = 1.6,
            products = { 'mushroom_process' },
        },
        {
            id = 'mushroom_lab_pack',
            label = 'Grybai · supakavimas',
            level = 2,
            coords = vector3(2815.4390, 5976.7300, 350.6935),
            heading = 120.0,
            radius = 1.6,
            products = { 'mushroom_pack' },
        },
    },
}

--- Kokaino virimas — Cayo Perico (L3)
Config.CocaineLab = {
    requireIsland = true,
    blip = {
        enabled = true,
        coords = vector3(4987.12, -5128.44, 2.52),
        sprite = 501,
        color = 0,
        scale = 0.78,
        label = 'Kokaino laboratorija (Cayo)',
        requireIsland = true,
    },
    stations = {
        {
            id = 'cocaine_lab_process',
            label = 'Kokainas · virimas',
            level = 3,
            coords = vector3(4987.12, -5128.44, 2.52),
            heading = 57.0,
            radius = 1.6,
            products = { 'cocaine_process' },
        },
        {
            id = 'cocaine_lab_pack',
            label = 'Kokainas · supakavimas',
            level = 3,
            coords = vector3(4989.80, -5130.20, 2.52),
            heading = 57.0,
            radius = 1.6,
            products = { 'cocaine_pack' },
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

--- LS airport test NPC — greitas pirkimas (1 paspaudimas → inventoriuje)
Config.LsTestQuickBuy = {
    { item = 'weed_seed', amount = 15 },
    { item = 'trimming_scissors', amount = 1 },
    { item = 'pill_press', amount = 1 },
    { item = 'scale', amount = 1 },
    { item = 'gloves', amount = 5 },
    { item = 'empty_bag', amount = 25 },
    { item = 'empty_bottle', amount = 15 },
    { item = 'empty_cart', amount = 10 },
    { item = 'filter', amount = 15 },
    { item = 'lab_kit', amount = 2 },
    { item = 'burner', amount = 2 },
    { item = 'bagging_table', amount = 1 },
    { item = 'chemical_mix', amount = 15 },
    { item = 'hemp_trim', amount = 25 },
    { item = 'weed_leaf', amount = 15 },
    { item = 'poppy_flower', amount = 20 },
    { item = 'meth_ingredient', amount = 20 },
    { item = 'pill_powder', amount = 20 },
    { item = 'mushroom_raw', amount = 20 },
    { item = 'cartel_raw', amount = 20 },
    { item = 'amp_precursor', amount = 20 },
    { item = 'alcohol_base', amount = 15 },
    { item = 'vape_liquid_base', amount = 15 },
}

--- Test meniu — duoda itemus / atidaro UI
Config.TestKits = {
    level1 = {
        hemp_trim = 25, alcohol_base = 10, vape_liquid_base = 10,
        empty_cart = 10, empty_bottle = 10, filter = 10, empty_bag = 20,
        gloves = 5,
    },
    level2 = {
        weed_leaf = 30, poppy_flower = 20, meth_ingredient = 15, pill_powder = 15,
        mushroom_raw = 15, chemical_mix = 15, empty_bag = 35, scale = 5,
        lab_kit = 3, gloves = 5, trimming_scissors = 2, pill_press = 1,
    },
    level3 = {
        cartel_raw = 25, chemical_mix = 20, meth_ingredient = 10, pill_powder = 15,
        amp_precursor = 20,
        lab_kit = 5, empty_bag = 35, scale = 5, burner = 3,
        trimming_scissors = 2, pill_press = 1, gloves = 5,
    },
}

--- Galutiniai supakuoti produktai (Config.Products su stage = 'pack')
Config.PackagedDrugOutputs = {}
for _, prod in pairs(Config.Products) do
    if prod.stage == 'pack' and prod.output then
        Config.PackagedDrugOutputs[tostring(prod.output):lower()] = true
    end
end

function Config.IsPackagedDrugItem(itemName)
    return Config.PackagedDrugOutputs[tostring(itemName or ''):lower()] == true
end

--- Schedule mini-žaidimai — žr. shared/minigame_registry.lua (unikalūs per narkotiko liniją).

--[[
  ═══════════════════════════════════════════════════════════════════
  VISŲ LOKACIJŲ REGISTRAS (koordinatės + aprašymas)
  Blipai kuriami client/main.lua → setupStationBlips()
  Koordinates galima perkelti vėliau — keisk atitinkamą Config.* bloką.
  ═══════════════════════════════════════════════════════════════════
]]
Config.WorldSiteIndex = {
    -- Parduotuvės
    { id = 'supply_grove',       category = 'shop',    label = 'Nelegalūs reikmenys',           coords = '124.15, -1930.62, 21.38',   desc = 'L1 ingredientai, maišeliai, filtrai, pirštinės' },
    { id = 'weed_supply',        category = 'shop',    label = 'Kanapių auginimo reikmenys',    coords = '2221.86, 5614.80, 54.90',   desc = 'Sėklos, vazonai, laistytuvai, žirklės' },
    -- Rinkimas
    { id = 'mushroom_field',     category = 'harvest', label = 'Grybų rinkimas',                coords = '2145.94, 6418.35, 153.07',  desc = 'Laukiniai grybai — Mount Chiliad' },
    { id = 'coca_field',         category = 'harvest', label = 'Kokainmedžio lapai (Cayo)',     coords = '4715.03, -4529.36, 26.82',  desc = 'Reikia Cayo Perico salos' },
    -- L1 laboratorijos
    { id = 'thc_lab',            category = 'lab',     label = 'THC distiliacija',              coords = '1391.13, 3603.61, 38.94',   desc = 'THC process + pack stotelės' },
    { id = 'alcohol_lab',        category = 'lab',     label = 'Samagono distiliatorius',       coords = '2434.18, 4968.52, 46.82',   desc = 'Alkoholio distiliacija ir supakavimas' },
    { id = 'vape_lab',           category = 'lab',     label = 'Vape laboratorija',             coords = '1175.52, -3113.84, 6.03',   desc = 'Vape skysčio paruošimas ir supakavimas' },
    -- L2 laboratorijos
    { id = 'weed_dry',           category = 'lab',     label = 'Žolės džiovinimas',             coords = '1144.82, -1659.86, 36.61',   desc = 'Weed process — Davis' },
    { id = 'weed_pack_cayo',     category = 'lab',     label = 'Žolės supakavimas (Cayo)',      coords = '5195.83, -5134.91, 3.35',    desc = 'Weed pack — Cayo Perico' },
    { id = 'heroin_lab',         category = 'lab',     label = 'Heroino laboratorija',          coords = '1953.00, 5180.00, 47.98',   desc = 'Heroin process + pack' },
    { id = 'meth_lab',           category = 'lab',     label = 'Metamfetamino laboratorija',    coords = '2709.10, 5235.05, 49.36',   desc = 'Kristalizacija + supakavimas' },
    { id = 'pills_lab',          category = 'lab',     label = 'Tablečių gamyba',               coords = '348.50, -2062.00, 21.24',   desc = 'Pills process + pack — Davis' },
    { id = 'mushroom_lab',       category = 'lab',     label = 'Grybų perdirbimas',             coords = '2138.52, 6405.18, 153.07',  desc = 'Džiovinimas + supakavimas' },
    -- L3
    { id = 'cocaine_lab',        category = 'lab',     label = 'Kokaino laboratorija (Cayo)',   coords = '4987.12, -5128.44, 2.52',   desc = 'Virimas + supakavimas — Cayo' },
    { id = 'amp_lab',            category = 'lab',     label = 'Amfetamino laboratorija',       coords = '1903.48, 4922.55, 48.86',   desc = 'Journey autobusas + quiz sintezė' },
    { id = 'amp_pack',           category = 'lab',     label = 'Amfetamino supakavimas',      coords = '1908.20, 4926.80, 48.86',   desc = 'Amp pack stotelė' },
    { id = 'weapon_bench',       category = 'weapon',  label = 'Ginklų dirbtuvė L1',            coords = '-1142.73, 4941.63, 222.30', desc = 'Ginklų crafting — Chiliad' },
    -- Supirkėjai
    { id = 'buyer_alcohol',      category = 'buyer',   label = 'Alkoholio supirkėjas',          coords = '186.47, -1273.15, 29.20',    desc = 'Perka illegal_alcohol' },
    { id = 'buyer_thc',          category = 'buyer',   label = 'THC supirkėjas',                coords = '-1164.44, -1567.76, 4.45',   desc = 'Perka thc_cart' },
    { id = 'buyer_vape',         category = 'buyer',   label = 'Vape supirkėjas',               coords = '-1724.61, 234.15, 58.47',    desc = 'Perka vape_liquid' },
    { id = 'buyer_weed',         category = 'buyer',   label = 'Žolės supirkėjas',              coords = '-3.45, -1820.93, 29.54',     desc = 'Perka weed_bag' },
    { id = 'buyer_cocaine',      category = 'buyer',   label = 'Kokaino supirkėjas',            coords = '5587.65, -5220.64, 14.62',   desc = 'Perka cartel_pack — Cayo' },
    { id = 'buyer_heroin',       category = 'buyer',   label = 'Heroino supirkėjas',            coords = '357.24, -2055.82, 22.09',    desc = 'Perka heroin_bag' },
    { id = 'buyer_meth',         category = 'buyer',   label = 'Metamfetamino supirkėjas',      coords = '1981.52, 5177.18, 47.98',   desc = 'Perka meth_bag' },
    { id = 'buyer_pills',        category = 'buyer',   label = 'Tablečių supirkėjas',           coords = '-661.18, -857.82, 24.48',    desc = 'Perka pills_pack' },
    { id = 'buyer_mushroom',     category = 'buyer',   label = 'Grybų supirkėjas',              coords = '-103.52, 6346.18, 31.48',    desc = 'Perka mushroom_pack' },
    { id = 'buyer_amp',          category = 'buyer',   label = 'Amfetamino supirkėjas',         coords = '1905.02, 4918.04, 48.86',    desc = 'Perka amphetamine_bag' },
    -- Test zona (LS airport)
    { id = 'dev_hub',            category = 'test',    label = 'Test: narkotikai ir ginklai',   coords = '-886.92, -3208.01, 13.94',  desc = 'Dev eilė — tik kai EnableDrugTestNPC' },
    { id = 'lsd_planned',        category = 'planned', label = 'LSD planuojama',                coords = 'nil',                         desc = 'Įrašyk coords į Config.PlannedSites.lsd_tablet' },
}
