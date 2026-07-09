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

--- itemName (qb-core) → pasaulio prop + meniu produktai
--- products: receptai, kuriuose reikia šio itemo; arba packOnly sąrašas
Config.DrugEquipment.types = {
    lab_kit = {
        label = 'Laboratorijos stalas',
        prop = 'bkr_prop_meth_table01a',
        icon = 'flask',
        products = { 'meth_process', 'cocaine_process', 'pills_process', 'amp_process' },
    },
    burner = {
        label = 'Degiklis / kaitinilis',
        prop = 'prop_cooker_03',
        icon = 'flame',
        products = { 'meth_process', 'cocaine_process' },
    },
    pill_press = {
        label = 'Tablečių presas',
        prop = 'prop_tool_bench02',
        icon = 'pill',
        products = { 'pills_process' },
    },
    scale = {
        label = 'Elektroninės svarstyklės',
        prop = 'bkr_prop_coke_scale_01',
        icon = 'scale',
        products = { 'meth_pack', 'heroin_pack', 'amp_pack' },
    },
    bagging_table = {
        label = 'Pakavimo stalas',
        prop = 'bkr_prop_weed_table_01a',
        icon = 'bag',
        packOnly = true, --- pack etapai be įrankio recepte
        products = {
            'weed_pack', 'mushroom_pack', 'cocaine_pack', 'pills_pack',
            'thc_pack', 'vape_pack', 'alcohol_pack',
        },
    },
}

--- Fiksuota įranga labuose — nemokamas spawn, negali surinkti (fixed = true)
Config.DrugEquipment.fixedLocations = {
    { itemType = 'lab_kit', coords = vector4(1391.13, 3603.61, 38.94, 200.0), label = 'THC lab stalas' },
    { itemType = 'lab_kit', coords = vector4(1175.52, -3113.84, 6.03, 90.0), label = 'Vape lab stalas' },
    { itemType = 'lab_kit', coords = vector4(1005.72, -3200.12, -38.99, 0.0), label = 'Meto lab stalas' },
    { itemType = 'burner', coords = vector4(1007.2, -3198.5, -38.99, 180.0), label = 'Meto degiklis' },
    { itemType = 'pill_press', coords = vector4(353.6, -2055.2, 21.24, 140.0), label = 'Tablečių presas' },
    { itemType = 'scale', coords = vector4(1009.1, -3199.8, -38.99, 270.0), label = 'Meto svarstyklės' },
    { itemType = 'bagging_table', coords = vector4(5196.4, -5133.2, 3.35, 180.0), label = 'Žolės pakavimo stalas' },
    { itemType = 'bagging_table', coords = vector4(1177.0, -3115.5, 6.03, 0.0), label = 'Vape pakavimo stalas' },
}
