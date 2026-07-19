--[[
  ═══════════════════════════════════════════════════════════════════
  mrp_drugs — Schedule-1 / tk_drugs stiliaus įrangos sistema
  ═══════════════════════════════════════════════════════════════════

  Srautas:
    1) Žaidėjas naudoja itemą inventoriuje (lab_kit, burner, …)
    2) Ghost placement — [E] padėti, scroll sukti, backspace atšaukti
    3) Prop spawn + qb-target „Naudoti įrangą“
    4) qb-menu → receptai → Schedule minigame → server finishCraft

  Failai:
    · config_equipment.lua   — šis failas (tipai, propai, fixedLocations)
    · client/equipment.lua   — placement, target, minigame flow
    · server/equipment.lua   — DB fivempro_drugs_equipment, sync
    · server/main.lua        — startCraftAtEquipment, ingredient skip

  Svarbu:
    · Recepte įrankis (lab_kit, burner…) NEBŪNA sunaudojamas, jei stovi prie
      atitinkamo prop arba kitas įrankis yra labAssistRadius zonoje.
    · packOnly = true — pakavimo stalai; recepte itemo nereikia, tik produktų sąrašas.
    · fixedLocations — prop spawn be itemo (labuose, kaip tk_drugs EquipmentLocations).

  Prop modeliai: vanilla GTA / Biker DLC (bkr_*).
]]
Config.DrugEquipment = Config.DrugEquipment or {}

--- Visos sistemos jungiklis
Config.DrugEquipment.enabled = true
--- Ghost preview atstumas nuo žaidėjo (m)
Config.DrugEquipment.placeForwardM = 1.35
Config.DrugEquipment.placeGhostAlpha = 170
--- Surinkimo interakcijos atstumas
Config.DrugEquipment.pickupDist = 2.8
--- qb-target / gamybos interakcijos atstumas
Config.DrugEquipment.interactDist = 2.5
--- Limitai pastatytai portable įrangai (fixedLocations neįskaitoma)
Config.DrugEquipment.maxPerPlayer = 3
Config.DrugEquipment.maxGlobal = 120
Config.DrugEquipment.minPlaceDist = 2.0
--- Keli įrankiai vienoje lab zonoje (pvz. lab_kit + burner) — atstumas metrais
Config.DrugEquipment.labAssistRadius = 5.0

--- Cayo Perico ribos portable žolės pakavimo stalui.
--- center = salos centras; radius = 1800 m spindulys, toks pats kaip mrp_cayoperico MapRadius.
--- Pakeitus radius į mažesnį skaičių, stalo padėjimo zona saloje sumažės.
Config.DrugEquipment.cayoPlacement = {
    center = vector3(4840.57, -5174.42, 2.0),
    radius = 1800.0,
}

--- itemName (qb-core) → pasaulio prop + meniu produktai
--- products: portable tipui (dažniausiai tuščia — tik pagalbinis įrankis receptuose)
--- fixedLocations.products: konkretūs receptai tik toje lokacijoje (vienas narkotikas = viena vieta)
Config.DrugEquipment.types = {
    lab_kit = {
        label = 'Laboratorijos stalas',
        prop = 'bkr_prop_meth_table01a',
        icon = 'flask',
        products = {},
    },
    burner = {
        label = 'Degiklis / kaitinilis',
        prop = 'prop_cooker_03',
        icon = 'flame',
        products = {},
    },
    pill_press = {
        label = 'Tablečių presas',
        prop = 'prop_tool_bench02',
        icon = 'pill',
        products = {},
    },
    scale = {
        label = 'Elektroninės svarstyklės',
        prop = 'bkr_prop_coke_scale_01',
        icon = 'scale',
        products = {},
    },
    bagging_table = {
        label = 'Žolės pakavimo stalas',
        prop = 'bkr_prop_weed_table_01a',
        icon = 'bag',
        packOnly = true,
        -- Portable stalas paleidžia tik naują fiksuotos kameros pakavimą po vieną maišelį.
        products = { 'weed_pack' },
        -- Tik stalo savininkas matys ir galės paleisti pakavimo veiksmą.
        ownerOnly = true,
        -- Vienas žaidėjas vienu metu gali turėti tik vieną padėtą tokio tipo stalą.
        maxPerPlayer = 1,
        -- Stalą leidžiama padėti tik Config.DrugEquipment.cayoPlacement ribose.
        cayoOnly = true,
        -- 600000 ms = 10 min. nenaudojamas stalas po šio laiko subyra.
        idleTimeoutMs = 600000,
        -- Holograma piešiama tik esant ne toliau nei 20 m nuo stalo.
        hologramDistance = 20.0,
        -- 1.25 m = hologramos aukštis virš stalo objekto koordinatės.
        hologramHeight = 1.25,
    },
    thc_still = {
        label = 'THC distiliatorius',
        prop = 'bkr_prop_weed_table_01a',
        icon = 'flask',
        packOnly = true,
        products = { 'thc_process' },
    },
    alcohol_still = {
        label = 'Samagono distiliatorius',
        prop = 'prop_cooker_03',
        icon = 'flame',
        packOnly = true,
        products = { 'alcohol_process' },
    },
    vape_still = {
        label = 'Vape paruošimo stalas',
        prop = 'bkr_prop_weed_table_01a',
        icon = 'flask',
        packOnly = true,
        products = { 'vape_process' },
    },
}

--- Fiksuota įranga labuose — nemokamas spawn, negali surinkti (fixed = true)
--- Kiekviena eilutė = viena gamybos vieta, vienas narkotiko tipas
Config.DrugEquipment.fixedLocations = {
    -- L1 · THC (Sandy Shores)
    { itemType = 'thc_still', coords = vector4(1391.13, 3603.61, 38.94, 200.0), label = 'THC distiliatorius' },
    { itemType = 'bagging_table', coords = vector4(1393.85, 3601.20, 38.94, 200.0), label = 'THC pakavimo stalas', products = { 'thc_pack' } },
    -- L1 · Samagonas (Paleto)
    { itemType = 'alcohol_still', coords = vector4(2381.75, 4953.01, 42.93, 45.0), label = 'Samagono distiliatorius' },
    { itemType = 'bagging_table', coords = vector4(2377.54, 4938.41, 43.02, 45.0), label = 'Samagono pakavimo stalas', products = { 'alcohol_pack' } },
    -- L1 · Vape (uostas)
    { itemType = 'vape_still', coords = vector4(-805.86, -3242.86, 14.08, 90.0), label = 'Vape paruošimo stalas' },
    { itemType = 'bagging_table', coords = vector4(-815.17, -3237.53, 14.15, 90.0), label = 'Vape pakavimo stalas', products = { 'vape_pack' } },
    -- L2 · Metas (Grapeseed)
    { itemType = 'lab_kit', coords = vector4(2712.45, 5238.18, 49.36, 286.5), label = 'Meto lab stalas', products = { 'meth_process' } },
    { itemType = 'burner', coords = vector4(2710.80, 5237.00, 49.36, 286.5), label = 'Meto degiklis' },
    { itemType = 'scale', coords = vector4(2709.10, 5235.05, 49.36, 286.5), label = 'Meto svarstyklės', products = { 'meth_pack' } },
    -- L2 · Tabletės (Davis — atskirai nuo heroino)
    { itemType = 'lab_kit', coords = vector4(345.00, -2064.50, 21.24, 140.0), label = 'Tablečių lab stalas' },
    { itemType = 'pill_press', coords = vector4(348.50, -2062.00, 21.24, 140.0), label = 'Tablečių presas', products = { 'pills_process' } },
    { itemType = 'bagging_table', coords = vector4(351.20, -2058.40, 21.24, 140.0), label = 'Tablečių pakavimo stalas', products = { 'pills_pack' } },
    -- L3 · Kokainas (Cayo Perico)
    { itemType = 'lab_kit', coords = vector4(4987.12, -5128.44, 2.52, 57.0), label = 'Kokaino lab stalas', products = { 'cocaine_process' } },
    { itemType = 'burner', coords = vector4(4989.20, -5126.80, 2.52, 57.0), label = 'Kokaino degiklis' },
    { itemType = 'bagging_table', coords = vector4(4989.80, -5130.20, 2.52, 57.0), label = 'Kokaino pakavimo stalas', products = { 'cocaine_pack' } },
    -- L3 · Amfetaminas (Grapeseed dykuma)
    { itemType = 'lab_kit', coords = vector4(1903.48, 4922.55, 48.86, 225.0), label = 'Amfetamino lab stalas', products = { 'amp_process' } },
    { itemType = 'scale', coords = vector4(1908.20, 4926.80, 48.86, 225.0), label = 'Amfetamino svarstyklės', products = { 'amp_pack' } },
}
