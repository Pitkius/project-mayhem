Config = {}

Config.TabletItem = 'gang_tablet'

Config.GangTypes = {
    street = 'Street Gang',
    biker = 'Biker Club',
    cartel = 'Cartel',
    mafia = 'Mafia',
    racing = 'Racing Crew',
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
    cypress = { label = 'Cypress Flats', center = vector3(986.4, -2524.1, 28.3), radius = 210.0 },
    la_puerta = { label = 'La Puerta', center = vector3(-1088.3, -1264.7, 5.9), radius = 190.0 },
}

Config.TurfClaimThreshold = 100
Config.TaskReputation = {
    drug = 8,
    smuggle = 10,
    theft = 7,
    extortion = 9,
    racing = 6,
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
