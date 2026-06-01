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

--- Turf langeliai: config_turf_cells.lua (tik LS miesto rajonai)

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
    policeAlertBase = 14,
    reputationPriceFactor = 0.006,
}

Config.AdminPermissions = { 'admin', 'god' }

--- Turf tablet: Leaflet + satellite (koord. = gtav_satellite.jpg kampai)
Config.TabletMap = {
    gameMin = { x = -4000.0, y = -4000.0 },
    gameMax = { x = 4500.0, y = 6625.0 },
    offsetX = 0.0,
    offsetY = 0.0,
    imageWidth = 1024,
    imageHeight = 1280,
    imageFile = 'asset/gtav_satellite.jpg',
}

--- Žemėlapio projekcija (Leaflet) — turi sutapti su gtav_satellite.jpg
Config.MapGrid = nil

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
