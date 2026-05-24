Config = Config or {}

--- Kirpyklos (tikslūs koordinačiai)
Config.BarberPeds = {
    { model = 's_f_m_fembarber', coords = vector4(-814.22, -183.70, 36.57, 116.91), chair = vector4(-815.10, -184.85, 36.57, 296.0) },
    { model = 's_f_m_fembarber', coords = vector4(-1283.99, -1117.31, 6.99, 89.25),  chair = vector4(-1282.80, -1116.50, 6.99, 180.0) },
    { model = 's_f_m_fembarber', coords = vector4(134.91, -1708.13, 28.29, 140.11), chair = vector4(136.20, -1708.40, 28.29, 230.0) },
    { model = 's_f_m_fembarber', coords = vector4(1211.04, -472.82, 65.20, 72.94),  chair = vector4(1211.00, -474.20, 65.20, 165.0) },
    { model = 's_f_m_fembarber', coords = vector4(1932.83, 3729.73, 31.84, 212.61), chair = vector4(1933.90, 3730.50, 31.84, 295.0) },
    { model = 's_f_m_fembarber', coords = vector4(-278.10, 6228.54, 30.70, 49.32),  chair = vector4(-277.00, 6228.10, 30.70, 225.0) },
}

--- Rūbų parduotuvės
Config.ClothingPeds = {
    { model = 's_f_y_shop_mid', coords = vector4(72.25, -1399.10, 28.38, 266.35) },
    { model = 's_f_y_shop_mid', coords = vector4(-708.71, -152.13, 36.41, 122.44) },
    { model = 's_f_y_shop_mid', coords = vector4(-165.15, -302.49, 38.73, 251.24) },
    { model = 's_f_y_shop_mid', coords = vector4(6.04, 6511.46, 30.88, 42.85) },
}

--- 24/7 parduotuvės
Config.FoodPeds = {
    { model = 'mp_m_shopkeep_01', coords = vector4(24.47, -1346.62, 28.50, 271.66) },
    { model = 'mp_m_shopkeep_01', coords = vector4(-3039.54, 584.38, 6.91, 17.27) },
    { model = 'mp_m_shopkeep_01', coords = vector4(-3242.97, 1000.01, 11.83, 357.57) },
    { model = 'mp_m_shopkeep_01', coords = vector4(1728.07, 6415.63, 34.04, 242.95) },
    { model = 'mp_m_shopkeep_01', coords = vector4(1959.82, 3740.48, 31.34, 301.57) },
    { model = 'mp_m_shopkeep_01', coords = vector4(549.13, 2670.85, 41.16, 99.39) },
    { model = 'mp_m_shopkeep_01', coords = vector4(1165.28, -323.87, 68.20, 100.15) },
    { model = 'mp_m_shopkeep_01', coords = vector4(373.87, 325.89, 102.56, 257.43) },
}

--- Tatuiruotės (kūno modifikacijos per qb-clothing)
Config.TattooPeds = {
    { model = 'u_m_y_tattoo_01', coords = vector4(-1153.67, -1425.68, 3.95, 130.0) },
    { model = 'u_m_y_tattoo_01', coords = vector4(1864.65, 3747.48, 32.03, 30.0) },
    { model = 'u_m_y_tattoo_01', coords = vector4(-293.71, 6200.04, 30.49, 230.0) },
    { model = 'u_m_y_tattoo_01', coords = vector4(-3170.07, 1075.05, 19.83, 250.0) },
}

--- Vaistinė (Pillbox ir papildomai Paleto)
Config.PharmacyPeds = {
    { model = 's_m_m_doctor_01', coords = vector4(307.18, -595.35, 42.28, 68.42) },
    { model = 's_m_m_doctor_01', coords = vector4(-172.88, 6381.02, 30.48, 230.0) },
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
        { name = 'armor_light', amount = 50, price = 350, slot = 5 },
        { name = 'armor_standard', amount = 50, price = 750, slot = 6 },
        { name = 'armor', amount = 30, price = 1200, slot = 7 },
    }
}
