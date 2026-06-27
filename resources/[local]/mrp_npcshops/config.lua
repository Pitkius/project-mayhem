Config = Config or {}

--- Shop NPC: spawn tik kai žaidėjas arti; kiti lieka išjungti (mažesnis load).
Config.NpcProximity = {
    enabled = true,
    spawnDistance = 72.0,
    despawnDistance = 92.0,
    checkIntervalMs = 1800,
}

--- Kirpyklos — vanilla qb-clothing zonos + kasininkės pozicija
--- chair = kliento kėdės vieta (Z turi sutapti su interjeru; barber.lua ieško artimiausio chair prop)
Config.BarberPeds = {
    { model = 's_f_m_fembarber', coords = vector4(-814.22, -183.70, 37.57, 116.91), chair = vector4(-815.05, -184.50, 37.57, 296.0) },
    { model = 's_f_m_fembarber', coords = vector4(-1282.61, -1116.82, 6.99, 89.25),  chair = vector4(-1282.75, -1116.45, 6.99, 180.0) },
    { model = 's_f_m_fembarber', coords = vector4(136.78, -1708.40, 28.29, 140.11), chair = vector4(136.35, -1708.55, 28.29, 230.0) },
    { model = 's_f_m_fembarber', coords = vector4(1212.80, -472.90, 65.20, 72.94),  chair = vector4(1211.15, -474.25, 65.20, 165.0) },
    { model = 's_f_m_fembarber', coords = vector4(1931.50, 3729.70, 31.84, 212.61), chair = vector4(1933.85, 3730.45, 31.84, 295.0) },
    { model = 's_f_m_fembarber', coords = vector4(-277.7234, 6230.6265, 31.6955, 49.3482), chair = vector4(-276.67, 6230.14, 31.6955, 225.0) },
}

--- Rūbų parduotuvės — prie kasos (qb-clothing vanilla zonos)
Config.ClothingPeds = {
    { model = 's_f_y_shop_mid', coords = vector4(-1127.1760, -1439.4318, 5.2283, 306.7758) },
    { model = 's_f_y_shop_mid', coords = vector4(73.9787, -1392.0791, 29.3761, 270.4405) },
    { model = 's_f_y_shop_mid', coords = vector4(-712.22, -155.35, 37.42, 122.0) },
    { model = 's_f_y_shop_mid', coords = vector4(-162.66, -303.40, 38.73, 251.0) },
    { model = 's_f_y_shop_mid', coords = vector4(5.2023, 6510.7515, 31.8779, 38.4227) },
}

--- 24/7 + LTD — vanilla qb-shops kasininkų koordinatės
Config.FoodPeds = {
    { model = 'mp_m_shopkeep_01', coords = vector4(24.47, -1346.62, 29.50, 271.66) },
    { model = 'mp_m_shopkeep_01', coords = vector4(-3039.54, 584.38, 7.91, 17.27) },
    { model = 'mp_m_shopkeep_01', coords = vector4(-3242.97, 1000.01, 12.83, 357.57) },
    { model = 'mp_m_shopkeep_01', coords = vector4(1728.07, 6415.63, 35.04, 242.95) },
    { model = 'mp_m_shopkeep_01', coords = vector4(1959.82, 3740.48, 32.34, 301.57) },
    { model = 'mp_m_shopkeep_01', coords = vector4(549.13, 2670.85, 42.16, 99.39) },
    { model = 'mp_m_shopkeep_01', coords = vector4(2677.47, 3279.76, 55.24, 335.08) },
    { model = 'mp_m_shopkeep_01', coords = vector4(2556.66, 380.84, 108.62, 356.67) },
    { model = 'mp_m_shopkeep_01', coords = vector4(372.66, 326.98, 103.57, 253.73) },
    { model = 'mp_m_shopkeep_01', coords = vector4(1164.71, -322.94, 69.21, 101.72) },
    { model = 'mp_m_shopkeep_01', coords = vector4(-47.02, -1758.23, 29.42, 45.05) },
    { model = 'mp_m_shopkeep_01', coords = vector4(-706.06, -913.97, 19.22, 88.04) },
    { model = 'mp_m_shopkeep_01', coords = vector4(377.1436, -1786.7267, 29.5227, 318.4302) },
}

--- Tatuiruotės
Config.TattooPeds = {
    { model = 'u_m_y_tattoo_01', coords = vector4(-1153.67, -1425.68, 4.95, 130.0) },
    { model = 'u_m_y_tattoo_01', coords = vector4(1864.65, 3747.48, 33.03, 30.0) },
    { model = 'u_m_y_tattoo_01', coords = vector4(-293.71, 6200.04, 31.49, 230.0) },
    { model = 'u_m_y_tattoo_01', coords = vector4(-3170.07, 1075.05, 20.83, 250.0) },
}

--- Vaistinė
Config.PharmacyPeds = {
    { model = 's_m_m_doctor_01', coords = vector4(307.18, -595.35, 43.28, 68.42) },
    { model = 's_m_m_doctor_01', coords = vector4(-172.88, 6381.02, 31.48, 230.0) },
}

Config.FoodShop = {
    name = 'fivempro-food',
    label = '24/7 Parduotuvė',
    items = {
        { name = 'burger',       amount = 500, price = 18, slot = 1 },
        { name = 'chips',        amount = 500, price = 5,  slot = 2 },
        { name = 'twerks_candy', amount = 500, price = 6,  slot = 3 },
        { name = 'water_bottle', amount = 500, price = 10, slot = 4 },
        { name = 'kurkakola',    amount = 500, price = 8,  slot = 5 },
        { name = 'coffee',       amount = 500, price = 9,  slot = 6 },
    }
}

Config.PharmacyShop = {
    name = 'fivempro-pharmacy',
    label = 'Vaistinė',
    items = {
        { name = 'bandage',    amount = 200, price = 25, slot = 1 },
        { name = 'painkillers', amount = 200, price = 18, slot = 2 },
        { name = 'firstaid',   amount = 100, price = 85, slot = 3 },
        { name = 'ifaks',      amount = 100, price = 120, slot = 4 },
    }
}

--- Ūkio turgelis — senovinio tipo parduotuvė (be NPC, tik markeris + blip)
Config.JunkShopBlip = {
    sprite = 566,
    color = 17,
    scale = 0.82,
    label = 'Ūkio turgelis',
}

Config.JunkShopMarker = {
    drawDistance = 32.0,
    useRadius = 2.4,
    type = 27,
    scale = { x = 1.15, y = 1.15, z = 0.32 },
    color = { 184, 134, 72, 135 },
    zOffset = 0.02,
}

--- Vietos markeriams / blipams (NPC nenaudojami)
Config.JunkShopLocations = {
    vector4(2747.2649, 3472.9866, 55.6701, 246.1098),
    vector4(46.7457, -1749.7040, 29.6324, 46.4768),
    vector4(-10.8677, 6499.2393, 31.5051, 39.2733),
}

Config.JunkShopPeds = {}

Config.JunkShop = {
    name = 'fivempro-junk-shop',
    label = 'Ūkio turgelis',
    items = {
        { name = 'mining_pickaxe', amount = 80, price = 185, slot = 1 },
        { name = 'tow_chain', amount = 120, price = 390, slot = 2 },
        { name = 'screwdriverset', amount = 120, price = 295, slot = 3 },
        { name = 'repairkit', amount = 80, price = 820, slot = 4 },
        { name = 'tirerepairkit', amount = 150, price = 115, slot = 5 },
        { name = 'jerry_can', amount = 60, price = 88, slot = 6 },
        { name = 'lighter', amount = 300, price = 6, slot = 7 },
        { name = 'binoculars', amount = 80, price = 265, slot = 8 },
        { name = 'lockpick', amount = 120, price = 58, slot = 9 },
        { name = 'gloves', amount = 250, price = 14, slot = 10 },
        { name = 'trimming_scissors', amount = 80, price = 68, slot = 11 },
        { name = 'scale', amount = 60, price = 120, slot = 12 },
        { name = 'empty_bag', amount = 300, price = 6, slot = 13 },
        { name = 'empty_bottle', amount = 500, price = 4, slot = 14 },
    },
}
