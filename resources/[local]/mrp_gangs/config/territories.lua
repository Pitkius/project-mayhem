Config = Config or {}

Config.TerritoryRules = {
    ownershipLockSec = 72 * 60 * 60,
    defenderPreparationSec = 24 * 60 * 60,
    baseStability = 50,
    captureStability = 65,
    maxOwnedBase = 4,
    maxOwnedByType = { gang = 4, pvp = 2, racket = 3 },
    racketIncomeIntervalMin = 60,
    drugBaseMultiplier = 1.0,
    pvpDrugMultiplier = 1.18,
}

Config.DrugTerritoryItems = {
    weed = { weed_skunk = true, weed_og_kush = true, weed_bag = true, thc_cart = true },
    cocaine = { cokebaggy = true, cartel_pack = true },
    meth = { meth = true, meth_bag = true, amphetamine_bag = true },
    pills = { pills_pack = true },
    heroin = { heroin_bag = true },
    mushrooms = { mushroom_pack = true },
}

Config.Territories = {
    grove_street = {
        label = 'Grove Street',
        type = 'gang',
        drugProduct = 'weed',
        allowsDrugSales = true,
        bonuses = { reputation = 1.08, missionCooldown = 0.95 },
        vertices = {
            { x = 45.0, y = -1948.0 }, { x = 151.0, y = -1997.0 }, { x = 256.0, y = -1918.0 },
            { x = 285.0, y = -1788.0 }, { x = 178.0, y = -1724.0 }, { x = 63.0, y = -1771.0 },
        },
    },
    davis = {
        label = 'Davis',
        type = 'gang',
        drugProduct = 'pills',
        allowsDrugSales = true,
        bonuses = { reputation = 1.06, npcDemand = 1.10 },
        vertices = {
            { x = -304.0, y = -1888.0 }, { x = -93.0, y = -1941.0 }, { x = 65.0, y = -1844.0 },
            { x = 49.0, y = -1647.0 }, { x = -185.0, y = -1575.0 }, { x = -354.0, y = -1690.0 },
        },
    },
    rancho = {
        label = 'Rancho',
        type = 'gang',
        drugProduct = 'meth',
        allowsDrugSales = true,
        bonuses = { reputation = 1.07, crafting = 1.05 },
        vertices = {
            { x = 327.0, y = -2168.0 }, { x = 579.0, y = -2112.0 }, { x = 692.0, y = -1903.0 },
            { x = 603.0, y = -1715.0 }, { x = 399.0, y = -1732.0 }, { x = 284.0, y = -1936.0 },
        },
    },
    chamberlain_hills = {
        label = 'Chamberlain Hills',
        type = 'gang',
        drugProduct = 'weed',
        allowsDrugSales = true,
        bonuses = { reputation = 1.08, graffiti = 1.15 },
        vertices = {
            { x = -371.0, y = -1684.0 }, { x = -184.0, y = -1574.0 }, { x = -108.0, y = -1398.0 },
            { x = -180.0, y = -1274.0 }, { x = -391.0, y = -1337.0 }, { x = -447.0, y = -1515.0 },
        },
    },
    strawberry = {
        label = 'Strawberry',
        type = 'gang',
        drugProduct = 'cocaine',
        allowsDrugSales = true,
        bonuses = { reputation = 1.05, npcDemand = 1.08 },
        vertices = {
            { x = -106.0, y = -1660.0 }, { x = 176.0, y = -1732.0 }, { x = 357.0, y = -1538.0 },
            { x = 294.0, y = -1324.0 }, { x = 49.0, y = -1289.0 }, { x = -143.0, y = -1438.0 },
        },
    },
    mirror_park = {
        label = 'Mirror Park',
        type = 'gang',
        drugProduct = 'pills',
        allowsDrugSales = true,
        bonuses = { reputation = 1.05, policeHeat = 0.92 },
        vertices = {
            { x = 857.0, y = -708.0 }, { x = 1107.0, y = -663.0 }, { x = 1263.0, y = -505.0 },
            { x = 1192.0, y = -300.0 }, { x = 930.0, y = -283.0 }, { x = 813.0, y = -480.0 },
        },
    },
    sandy_shores = {
        label = 'Sandy Shores',
        type = 'gang',
        drugProduct = 'meth',
        allowsDrugSales = true,
        bonuses = { reputation = 1.07, crafting = 1.08 },
        vertices = {
            { x = 1579.0, y = 3451.0 }, { x = 1857.0, y = 3318.0 }, { x = 2119.0, y = 3487.0 },
            { x = 2175.0, y = 3809.0 }, { x = 1930.0, y = 3986.0 }, { x = 1645.0, y = 3838.0 },
        },
    },
    grapeseed = {
        label = 'Grapeseed',
        type = 'gang',
        drugProduct = 'mushrooms',
        allowsDrugSales = true,
        bonuses = { reputation = 1.06, supply = 1.10 },
        vertices = {
            { x = 2234.0, y = 4473.0 }, { x = 2505.0, y = 4381.0 }, { x = 2781.0, y = 4550.0 },
            { x = 2796.0, y = 4845.0 }, { x = 2512.0, y = 5014.0 }, { x = 2268.0, y = 4823.0 },
        },
    },

    cypress_docks = {
        label = 'Cypress Docks',
        type = 'pvp',
        drugProduct = 'cocaine',
        allowsDrugSales = true,
        bonuses = { drugPrice = 1.18, supplyDropWeight = 1.25 },
        vertices = {
            { x = 694.0, y = -2461.0 }, { x = 1025.0, y = -2528.0 }, { x = 1218.0, y = -2301.0 },
            { x = 1138.0, y = -1991.0 }, { x = 827.0, y = -1938.0 }, { x = 626.0, y = -2159.0 },
        },
    },
    la_mesa_yards = {
        label = 'La Mesa Yards',
        type = 'pvp',
        drugProduct = 'meth',
        allowsDrugSales = true,
        bonuses = { drugPrice = 1.18, crafting = 1.10 },
        vertices = {
            { x = 679.0, y = -1544.0 }, { x = 938.0, y = -1598.0 }, { x = 1139.0, y = -1391.0 },
            { x = 1045.0, y = -1094.0 }, { x = 777.0, y = -1055.0 }, { x = 628.0, y = -1281.0 },
        },
    },
    vespucci_canals = {
        label = 'Vespucci Canals',
        type = 'pvp',
        drugProduct = 'pills',
        allowsDrugSales = true,
        bonuses = { drugPrice = 1.18, policeHeat = 0.90 },
        vertices = {
            { x = -1298.0, y = -1276.0 }, { x = -1084.0, y = -1360.0 }, { x = -932.0, y = -1138.0 },
            { x = -1004.0, y = -913.0 }, { x = -1226.0, y = -883.0 }, { x = -1384.0, y = -1061.0 },
        },
    },
    sandy_airfield = {
        label = 'Sandy Airfield',
        type = 'pvp',
        drugProduct = 'cocaine',
        allowsDrugSales = true,
        bonuses = { drugPrice = 1.18, supplyDropWeight = 1.30 },
        vertices = {
            { x = 1488.0, y = 3005.0 }, { x = 1863.0, y = 2951.0 }, { x = 2131.0, y = 3178.0 },
            { x = 2049.0, y = 3400.0 }, { x = 1677.0, y = 3442.0 }, { x = 1433.0, y = 3273.0 },
        },
    },

    little_seoul_racket = {
        label = 'Little Seoul verslai',
        type = 'racket',
        allowsDrugSales = false,
        bonuses = { hourlyIncome = 850, laundering = 1.10 },
        vertices = {
            { x = -962.0, y = -1090.0 }, { x = -701.0, y = -1125.0 }, { x = -517.0, y = -881.0 },
            { x = -588.0, y = -677.0 }, { x = -858.0, y = -640.0 }, { x = -1042.0, y = -847.0 },
        },
    },
    downtown_racket = {
        label = 'Downtown verslai',
        type = 'racket',
        allowsDrugSales = false,
        bonuses = { hourlyIncome = 1000, laundering = 1.08 },
        vertices = {
            { x = -318.0, y = -828.0 }, { x = -58.0, y = -894.0 }, { x = 213.0, y = -692.0 },
            { x = 155.0, y = -424.0 }, { x = -111.0, y = -344.0 }, { x = -372.0, y = -558.0 },
        },
    },
    vinewood_racket = {
        label = 'Vinewood klubai',
        type = 'racket',
        allowsDrugSales = false,
        bonuses = { hourlyIncome = 1250, missionPayout = 1.05 },
        vertices = {
            { x = 168.0, y = -92.0 }, { x = 445.0, y = -143.0 }, { x = 643.0, y = 95.0 },
            { x = 557.0, y = 316.0 }, { x = 287.0, y = 374.0 }, { x = 113.0, y = 151.0 },
        },
    },
    del_perro_racket = {
        label = 'Del Perro pakrantė',
        type = 'racket',
        allowsDrugSales = false,
        bonuses = { hourlyIncome = 950, smuggling = 1.08 },
        vertices = {
            { x = -1671.0, y = -923.0 }, { x = -1394.0, y = -1008.0 }, { x = -1192.0, y = -762.0 },
            { x = -1269.0, y = -504.0 }, { x = -1535.0, y = -463.0 }, { x = -1734.0, y = -671.0 },
        },
    },
    textile_racket = {
        label = 'Textile City prekyba',
        type = 'racket',
        allowsDrugSales = false,
        bonuses = { hourlyIncome = 750, crafting = 1.06 },
        vertices = {
            { x = 285.0, y = -1047.0 }, { x = 548.0, y = -1032.0 }, { x = 741.0, y = -821.0 },
            { x = 664.0, y = -592.0 }, { x = 412.0, y = -558.0 }, { x = 242.0, y = -776.0 },
        },
    },
    paleto_racket = {
        label = 'Paleto logistika',
        type = 'racket',
        allowsDrugSales = false,
        bonuses = { hourlyIncome = 700, supply = 1.12 },
        vertices = {
            { x = -307.0, y = 6085.0 }, { x = 42.0, y = 6014.0 }, { x = 281.0, y = 6236.0 },
            { x = 152.0, y = 6488.0 }, { x = -186.0, y = 6535.0 }, { x = -417.0, y = 6320.0 },
        },
    },
}
