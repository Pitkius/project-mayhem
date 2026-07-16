Config = Config or {}

--- Legion Square — „miesto centras“ kainų skaičiavimui
Config.CityCenter = vector3(215.76, -809.82, 30.73)
Config.MaxDistFromCenter = 5500.0
Config.BasePrice = 200000
Config.CenterPriceMultiplier = 2.35
Config.PriceRoundStep = 5000
Config.RoutingBucketBase = 12000

Config.MaxOwnedPerPlayer = 2
Config.PaymentAccount = 'bank'
Config.Furnished = false

--- Numatyta (jei interjeras neturi savo stashCapacity)
Config.Stash = {
    maxweight = 200000,
    slots = 32,
}

--- Dynasty 8 MLO (mlo_pack_3) — agentūra
Config.Agency = {
    label = 'Dynasty 8',
    pedModel = 'a_m_m_business_01',
    coords = vector4(-706.18, 267.92, 83.15, 295.0),
    scenario = 'WORLD_HUMAN_CLIPBOARD',
    blip = { sprite = 374, color = 2, scale = 0.85 },
    targetDistance = 2.2,
}

Config.Districts = {
    paleto = { label = 'Paleto Bay', mult = 0.82 },
    sandy = { label = 'Sandy Shores', mult = 0.88 },
    grapeseed = { label = 'Grapeseed', mult = 0.86 },
    davis = { label = 'Davis', mult = 0.95 },
    rancho = { label = 'Rancho', mult = 0.98 },
    strawberry = { label = 'Strawberry', mult = 1.02 },
    mirror_park = { label = 'Mirror Park', mult = 1.15 },
    vespucci = { label = 'Vespucci', mult = 1.22 },
    del_perro = { label = 'Del Perro', mult = 1.28 },
    vinewood = { label = 'Vinewood', mult = 1.38 },
    rockford = { label = 'Rockford Hills', mult = 1.45 },
    downtown = { label = 'Downtown / Legion', mult = 1.55 },
}

--- Neįrengti interjerai — kuo brangesnis pasirinkimas, tuo geresnis vidus (erdvė, sandėlis, patogumai)
Config.Interiors = {
    economy = {
        label = 'Ekonominis',
        qualityLabel = 'Prastas',
        tier = 1,
        description = 'Mažas butas, senas remontas. Mažas sandėliukas, be drabužinės.',
        priceMult = 1.0,
        hasWardrobe = false,
        stashCapacity = { maxweight = 100000, slots = 20 },
        enter = vector4(266.17, -1007.52, -101.01, 0.0),
        exitOffset = vector3(1.42, -2.35, 0.0),
        stash = vector3(265.89, -999.42, -99.01),
    },
    standard = {
        label = 'Standartinis',
        qualityLabel = 'Vidutinis',
        tier = 2,
        description = 'Normalus butas. Vidutinis sandėlis ir drabužinė.',
        priceMult = 1.18,
        hasWardrobe = true,
        stashCapacity = { maxweight = 200000, slots = 32 },
        enter = vector4(346.55, -1012.83, -99.20, 0.0),
        exitOffset = vector3(1.35, -2.42, 0.0),
        stash = vector3(351.29, -998.84, -99.20),
        wardrobe = vector3(350.62, -993.71, -99.20),
    },
    premium = {
        label = 'Premium',
        qualityLabel = 'Geras',
        tier = 3,
        description = 'Erdvesni apartamentai, didesnis sandėlis, atskira drabužinė.',
        priceMult = 1.42,
        hasWardrobe = true,
        stashCapacity = { maxweight = 320000, slots = 48 },
        enter = vector4(-786.87, 315.76, 217.64, 0.0),
        exitOffset = vector3(-0.8, -2.1, 0.0),
        stash = vector3(-796.11, 327.75, 217.04),
        wardrobe = vector3(-797.74, 328.29, 220.44),
    },
    luxury = {
        label = 'Prabangus loftas',
        qualityLabel = 'Prabangus',
        tier = 4,
        description = 'Didžiausias interjeras, didžiausias sandėlis, pilna drabužinė.',
        priceMult = 1.75,
        hasWardrobe = true,
        stashCapacity = { maxweight = 480000, slots = 64 },
        enter = vector4(-174.28, 497.65, 137.67, 190.0),
        exitOffset = vector3(0.0, -2.0, 0.0),
        stash = vector3(-169.88, 491.82, 130.04),
        wardrobe = vector3(-167.47, 487.90, 133.84),
    },
    --- DLC „A Safehouse in the Hills“ (build 3717+, bob74_ipl Mansion1/2)
    mansion_richman = {
        label = 'Richman Villa',
        qualityLabel = 'Mansion DLC',
        tier = 5,
        description = 'GTA Online Richman Villa — pilnas mansion interjeras su garažu ir rūsiu.',
        priceMult = 4.2,
        hasWardrobe = true,
        stashCapacity = { maxweight = 750000, slots = 80 },
        enter = vector4(-1630.43, 470.85, 128.02, 185.0),
        exitOffset = vector3(0.0, -2.5, 0.0),
        stash = vector3(-1649.63, 480.97, 117.36),
        wardrobe = vector3(-1660.50, 485.20, 128.22),
    },
    mansion_vinewood = {
        label = 'Vinewood Residence',
        qualityLabel = 'Mansion DLC',
        tier = 5,
        description = 'GTA Online Vinewood Residence — rytinis Vinewood Hills mansion.',
        priceMult = 4.0,
        hasWardrobe = true,
        stashCapacity = { maxweight = 750000, slots = 80 },
        enter = vector4(543.85, 712.75, 201.02, 180.0),
        exitOffset = vector3(0.0, -2.5, 0.0),
        stash = vector3(547.50, 734.14, 190.50),
        wardrobe = vector3(535.20, 745.80, 201.36),
    },
}

--- Unikalūs objektai (vienas savininkas visam serveriui)
Config.Properties = {
    -- Pigiausi rajonai (~200–350k + interjeras)
    {
        id = 'paleto_trailer',
        label = 'Paleto — namelis',
        type = 'house',
        district = 'paleto',
        door = vector4(-447.42, 6261.15, 30.05, 42.0),
        allowedInteriors = { 'economy', 'standard' },
    },
    {
        id = 'sandy_trailer',
        label = 'Sandy — dykumos namelis',
        type = 'house',
        district = 'sandy',
        door = vector4(1898.82, 3781.87, 32.88, 210.0),
        allowedInteriors = { 'economy', 'standard' },
    },
    {
        id = 'grapeseed_farm',
        label = 'Grapeseed — sodyba',
        type = 'house',
        district = 'grapeseed',
        door = vector4(1662.04, 4776.11, 42.01, 100.0),
        allowedInteriors = { 'economy', 'standard' },
    },
    {
        id = 'davis_apt',
        label = 'Davis — butas',
        type = 'apartment',
        district = 'davis',
        door = vector4(329.42, -1845.80, 27.75, 230.0),
        allowedInteriors = { 'economy', 'standard', 'premium' },
    },
    {
        id = 'rancho_apt',
        label = 'Rancho — butas',
        type = 'apartment',
        district = 'rancho',
        door = vector4(412.47, -1856.38, 27.32, 315.0),
        allowedInteriors = { 'economy', 'standard', 'premium' },
    },
    {
        id = 'strawberry_apt',
        label = 'Strawberry — butas',
        type = 'apartment',
        district = 'strawberry',
        door = vector4(269.73, -640.75, 42.02, 249.0),
        allowedInteriors = { 'economy', 'standard', 'premium' },
    },
    -- Viduriniai
    {
        id = 'mirror_park_apt',
        label = 'Mirror Park — butas',
        type = 'apartment',
        district = 'mirror_park',
        door = vector4(1031.24, -464.13, 63.86, 40.0),
        allowedInteriors = { 'standard', 'premium' },
    },
    {
        id = 'vespucci_apt',
        label = 'Vespucci — butas',
        type = 'apartment',
        district = 'vespucci',
        door = vector4(-667.02, -1105.24, 14.63, 242.0),
        allowedInteriors = { 'standard', 'premium', 'luxury' },
    },
    {
        id = 'del_perro_apt',
        label = 'Del Perro — apartamentai',
        type = 'apartment',
        district = 'del_perro',
        door = vector4(-1288.52, -430.51, 35.15, 125.0),
        allowedInteriors = { 'standard', 'premium', 'luxury' },
    },
    -- Brangūs — arčiau centro
    {
        id = 'vinewood_apt',
        label = 'Vinewood — apartamentai',
        type = 'apartment',
        district = 'vinewood',
        door = vector4(-619.29, 37.69, 43.59, 181.0),
        allowedInteriors = { 'premium', 'luxury' },
    },
    {
        id = 'rockford_apt',
        label = 'Rockford Hills — apartamentai',
        type = 'apartment',
        district = 'rockford',
        door = vector4(-771.06, 312.74, 85.70, 175.0),
        allowedInteriors = { 'premium', 'luxury' },
    },
    {
        id = 'downtown_apt',
        label = 'Integrity Way — penthouse zona',
        type = 'apartment',
        district = 'downtown',
        door = vector4(291.52, -1078.67, 29.41, 271.0),
        allowedInteriors = { 'premium', 'luxury' },
    },
    {
        id = 'legion_loft',
        label = 'Legion — loftas',
        type = 'apartment',
        district = 'downtown',
        door = vector4(-47.52, -585.86, 37.95, 70.0),
        allowedInteriors = { 'luxury' },
    },
    --- DLC mansions (reikia bob74_ipl + build 3717+)
    {
        id = 'richman_villa',
        label = 'Richman Villa — mansion',
        type = 'mansion',
        district = 'vinewood',
        door = vector4(-1630.43, 470.85, 128.02, 185.0),
        allowedInteriors = { 'mansion_richman' },
    },
    {
        id = 'vinewood_residence',
        label = 'Vinewood Residence — mansion',
        type = 'mansion',
        district = 'vinewood',
        door = vector4(543.85, 712.75, 201.02, 180.0),
        allowedInteriors = { 'mansion_vinewood' },
    },
}
