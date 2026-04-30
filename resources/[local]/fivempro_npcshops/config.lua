Config = Config or {}

Config.BarberPeds = {
    { model = 's_f_m_fembarber', coords = vector4(-815.66, -182.46, 36.57, 133.16) },
    { model = 's_f_m_fembarber', coords = vector4(134.72, -1708.76, 28.29, 140.21) },
    { model = 's_f_m_fembarber', coords = vector4(-1282.32, -1117.14, 5.99, 89.34) },
    { model = 's_f_m_fembarber', coords = vector4(1931.31, 3728.95, 31.84, 206.36) },
}

Config.ClothingPeds = {
    { model = 's_f_y_shop_mid', coords = vector4(1694.41, 4822.95, 41.06, 98.27) },
    { model = 's_f_y_shop_mid', coords = vector4(-709.94, -151.36, 36.42, 118.59) },
    { model = 's_f_y_shop_mid', coords = vector4(74.92, -1392.57, 28.38, 267.53) },
    { model = 's_f_y_shop_mid', coords = vector4(-1193.58, -767.08, 16.32, 215.22) },
}

Config.FoodPeds = {
    { model = 'mp_m_shopkeep_01', coords = vector4(24.24, -1346.63, 28.5, 267.0) },
    { model = 'mp_m_shopkeep_01', coords = vector4(-47.32, -1758.68, 28.42, 49.26) },
    { model = 'mp_m_shopkeep_01', coords = vector4(372.86, 327.13, 102.57, 255.87) },
    { model = 'mp_m_shopkeep_01', coords = vector4(-706.04, -914.44, 18.22, 85.28) },
}

Config.FoodShop = {
    name = 'fivempro-food',
    label = 'Maisto Parduotuve',
    items = {
        { name = 'sandwich', amount = 500, price = 15, slot = 1 },
        { name = 'water_bottle', amount = 500, price = 10, slot = 2 },
    }
}
