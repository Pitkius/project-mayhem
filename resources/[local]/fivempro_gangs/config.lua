Config = {}

Config.TabletItem = 'gang_tablet'

Config.GangTypes = {
    street = 'Street Gang',
    biker = 'Biker Club',
    cartel = 'Cartel',
    mafia = 'Mafia',
    racing = 'Racing Crew',
}

Config.ColorPalette = {
    '#22C55E', '#EF4444', '#3B82F6', '#F59E0B', '#A855F7', '#EC4899',
    '#14B8A6', '#F97316', '#84CC16', '#06B6D4', '#EAB308', '#6366F1',
    '#DC2626', '#15803D', '#7C3AED', '#DB2777'
}

Config.Ranks = {
    [0] = 'Runner',
    [1] = 'Member',
    [2] = 'Shot Caller',
    [3] = 'Underboss',
    [4] = 'Boss',
}

Config.Turfs = {
    grove = { label = 'Grove Street', center = vector3(106.4, -1949.2, 20.8), radius = 180.0 },
    davis = { label = 'Davis', center = vector3(-45.2, -1736.9, 29.4), radius = 190.0 },
    rancho = { label = 'Rancho', center = vector3(338.1, -2042.5, 21.1), radius = 175.0 },
    chamberlain = { label = 'Chamberlain Hills', center = vector3(-184.2, -1618.2, 33.3), radius = 170.0 },
    strawberry = { label = 'Strawberry', center = vector3(270.4, -1505.5, 29.3), radius = 160.0 },
    missionrow = { label = 'Mission Row', center = vector3(456.3, -986.4, 30.7), radius = 155.0 },
    textile = { label = 'Textile City', center = vector3(417.8, -808.4, 29.5), radius = 150.0 },
    downtown = { label = 'Downtown', center = vector3(227.1, -875.2, 30.5), radius = 180.0 },
    vinewood = { label = 'Vinewood', center = vector3(331.8, 219.4, 104.8), radius = 220.0 },
    mirrorpark = { label = 'Mirror Park', center = vector3(1133.2, -499.6, 64.1), radius = 170.0 },
    little_seoul = { label = 'Little Seoul', center = vector3(-715.3, -879.8, 23.6), radius = 170.0 },
    delperro = { label = 'Del Perro', center = vector3(-1466.5, -563.2, 33.8), radius = 180.0 },
    la_puerta = { label = 'La Puerta', center = vector3(-1088.3, -1264.7, 5.9), radius = 190.0 },
    cypress = { label = 'Cypress Flats', center = vector3(986.4, -2524.1, 28.3), radius = 210.0 },
    elburro = { label = 'El Burro Heights', center = vector3(1548.9, -2135.2, 77.4), radius = 220.0 },
    sandy = { label = 'Sandy Shores', center = vector3(1726.3, 3723.0, 34.2), radius = 260.0 },
    grapeseed = { label = 'Grapeseed', center = vector3(2444.5, 4968.0, 46.8), radius = 240.0 },
    paleto = { label = 'Paleto Bay', center = vector3(-136.4, 6357.4, 31.5), radius = 280.0 },
}

Config.TurfClaimThreshold = 100

--- Turf įtaka (atskira nuo misijų progresijos)
Config.TurfInfluence = {
    claimThreshold = 100,
    graffiti = 6,
    drugSaleInfluence = 2,
    presencePerMinute = 1,
}

--- Graffiti turf įtakai
Config.Graffiti = {
    item = 'spray_can',
    cleanerItem = 'graffiti_cleaner',
    cooldownSec = 120,
    influenceGain = 6,
    policeAlertChance = 18,
    durationMs = 4500,
}

Config.DrugSellItems = {
    { item = 'weed_skunk', label = 'Skunk', base = 110 },
    { item = 'weed_og-kush', label = 'OG Kush', base = 130 },
    { item = 'meth', label = 'Meth', base = 210 },
    { item = 'cokebaggy', label = 'Coke Baggy', base = 190 },
}

Config.DrugSell = {
    maxDistanceToPed = 3.0,
    policeAlertBase = 12,
    policeAlertHeatFactor = 0.35,
    reputationPriceFactor = 0.006,
    maxHeat = 100,
}

Config.AdminPermissions = { 'admin', 'god' }

--- Turf tablet: Leaflet + satellite image (html/asset). Game units ≈ meters; Y increases north.
Config.TabletMap = {
    gameMin = { x = -4000.0, y = -4000.0 },
    gameMax = { x = 4500.0, y = 6625.0 },
    imageWidth = 1024,
    imageHeight = 1280,
    imageFile = 'asset/gtav_satellite.jpg',
}

Config.TabletVendor = {
    model = 'g_m_y_lost_01',
    coords = vector4(-267.24, -959.34, 31.22, 205.0),
    label = 'Gaujų ryšininkas',
    blip = {
        enabled = true,
        sprite = 521,
        color = 1,
        scale = 0.8,
        shortRange = true,
        label = 'Gang Tablet NPC',
    },
    tabletPrice = 5000,
}
