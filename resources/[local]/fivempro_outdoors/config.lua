Config = {}

--- Gabz Park Ranger — licencijos, supirkimas, gamtosaugininkų darbas
Config.RangerStation = {
    coords = vector4(379.04, 797.66, 190.49, 180.17),
    licenseNpc = vector4(379.04, 797.66, 190.49, 180.17),
    buyerNpc = vector4(376.20, 795.10, 190.49, 90.0),
    butcherCoords = vector4(381.40, 792.30, 190.49, 180.0),
    pedModel = `s_m_y_ranger_01`,
}

--- Žvejybos / medžioklės reikmenų parduotuvė (Paleto krantas)
Config.NatureShopLocation = {
    coords = vector4(-1593.11, 5197.29, 4.36, 27.18),
    pedModel = `s_m_m_fisherman_01`,
    blip = { sprite = 68, colour = 38, scale = 0.85, label = 'Žvejybos ir medžioklės reikmenys' },
}

Config.Blips = {
    ranger = { sprite = 141, colour = 25, scale = 0.85, label = 'Gamtos apsauga' },
    fishing = { sprite = 68, colour = 38, scale = 0.75, label = 'Žvejyba' },
    hunting = { sprite = 442, colour = 46, scale = 0.75, label = 'Medžioklė' },
}

--- Licencijų testai ($)
Config.LicenseTestPrice = 250
Config.LicensePassScore = 3

Config.FishingTestQuestions = {
    { q = 'Kiek žuvų galima laikyti be licencijos?', answers = { '0 — reikia licencijos', '10', 'Neribotai' }, correct = 1 },
    { q = 'Ką daryti su per maža žuvimi?', answers = { 'Paleisti atgal', 'Parduoti', 'Palikti krante' }, correct = 1 },
    { q = 'Ar galima žvejoti valstyiniuose vandenyse be leidimo?', answers = { 'Taip', 'Ne — reikia licencijos', 'Tik naktį' }, correct = 2 },
    { q = 'Kas draudžiama žvejojant?', answers = { 'Dinamitas / nuodai', 'Meškere', 'Masalas' }, correct = 1 },
}

Config.HuntingTestQuestions = {
    { q = 'Kur leidžiama medžioti?', answers = { 'Miesto centre', 'Laukų zonose su licencija', 'Bet kur' }, correct = 2 },
    { q = 'Medžioklinis šratinis šautuvas žaidėjams…', answers = { 'Nužudo', 'Tik parblokš (kaip tazeris)', 'Nieko nedaro' }, correct = 2 },
    { q = 'Skerdimui reikia…', answers = { 'Peilio / medžioklinio peilio', 'Kirtiklio', 'Gręžtuvo' }, correct = 1 },
    { q = 'Ar galima medžioti be licencijos?', answers = { 'Taip', 'Ne', 'Tik su automobiliu' }, correct = 2 },
}

--- qb-inventory parduotuvės (reikia licencijos atidarymui)
Config.FishingShop = {
    name = 'fivempro-fishing-supply',
    label = 'Žvejybos reikmenys',
    license = 'fishing_license',
    items = {
        { name = 'fishingrod', amount = 500, price = 120 },
        { name = 'fishbait', amount = 500, price = 15 },
    },
}

Config.HuntingShop = {
    name = 'fivempro-hunting-supply',
    label = 'Medžioklės reikmenys',
    license = 'hunting_license',
    --- Eilė: šautuvas → peilis → kulkos (shop-stacked UI, viena po kito)
    items = {
        { name = 'weapon_musket', amount = 50, price = 2800 },
        { name = 'hunting_knife', amount = 500, price = 350 },
        { name = 'hunting_ammo', amount = 500, price = 45 },
    },
}

--- Supirkimo kainos
Config.SellPrices = {
    fish_raw = 18,
    fish_clean = 35,
    deer_meat_raw = 22,
    deer_meat_clean = 42,
    deer_pelt = 55,
    boar_meat_raw = 20,
    boar_meat_clean = 38,
    boar_pelt = 48,
    rabbit_meat_raw = 14,
    rabbit_meat_clean = 28,
    rabbit_fur = 22,
}

Config.ButcherMap = {
    fish_raw = 'fish_clean',
    deer_meat_raw = 'deer_meat_clean',
    boar_meat_raw = 'boar_meat_clean',
    rabbit_meat_raw = 'rabbit_meat_clean',
}

--- Žvejybos zonos (prie vandens)
Config.FishingZones = {
    { coords = vector3(-1593.0, 5197.0, 4.36), radius = 90.0, label = 'Paleto krantas' },
    { coords = vector3(1304.5, 4225.2, 33.9), radius = 85.0, label = 'Alamo Sea' },
    { coords = vector3(-1849.0, -1250.0, 8.6), radius = 70.0, label = 'Paleto įlanka' },
    { coords = vector3(713.0, 4092.0, 30.7), radius = 60.0, label = 'Sandy Shores ežeras' },
    { coords = vector3(-3426.0, 967.0, 8.3), radius = 55.0, label = 'Chumash krantas' },
}

--- Medžioklės zonos (laukai už miesto)
Config.HuntingZones = {
    { coords = vector3(2560.0, 4680.0, 34.0), radius = 220.0, label = 'Grapeseed laukai' },
    { coords = vector3(-598.0, 5065.0, 130.0), radius = 200.0, label = 'Paleto miškas' },
    { coords = vector3(1450.0, 6350.0, 23.0), radius = 180.0, label = 'Chiliad pašlaitės' },
    { coords = vector3(2450.0, 1545.0, 38.0), radius = 160.0, label = 'Grand Senora' },
}

Config.AnimalSpawn = {
    maxPerZone = 8,
    respawnSec = 90,
    models = {
        { model = `a_c_deer`, meat = 'deer_meat_raw', extra = 'deer_pelt', weight = 35 },
        { model = `a_c_boar`, meat = 'boar_meat_raw', extra = 'boar_pelt', weight = 30 },
        { model = `a_c_coyote`, meat = 'rabbit_meat_raw', extra = 'rabbit_fur', weight = 15 },
        { model = `a_c_rabbit_01`, meat = 'rabbit_meat_raw', extra = 'rabbit_fur', weight = 20 },
    },
}

Config.FishingLoot = {
    { item = 'fish_raw', weight = 70 },
    { item = 'fish_raw', weight = 25 },
    { item = 'fish_raw', weight = 5 },
}

Config.FishCooldown = 12
Config.HuntGutCooldown = 8
