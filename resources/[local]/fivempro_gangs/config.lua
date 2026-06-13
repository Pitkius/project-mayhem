Config = {}

Config.TabletItem = 'gang_tablet'

Config.GangTypes = {
    street = 'Street Gang',
    biker = 'Biker Club',
    cartel = 'Cartel',
    mafia = 'Mafia',
    racing = 'Racing Crew',
}

--- Gaujų spalvos: hex + lietuviškas pavadinimas (planšetėje rodoma žodžiais)
Config.GangColors = {
    { hex = '#A855F7', label = 'Violetinė' },
    { hex = '#7C3AED', label = 'Purpurinė' },
    { hex = '#EF4444', label = 'Raudona' },
    { hex = '#DC2626', label = 'Tamsiai raudona' },
    { hex = '#22C55E', label = 'Žalia' },
    { hex = '#15803D', label = 'Tamsiai žalia' },
    { hex = '#84CC16', label = 'Šviesiai žalia' },
    { hex = '#3B82F6', label = 'Mėlyna' },
    { hex = '#6366F1', label = 'Indigo' },
    { hex = '#06B6D4', label = 'Žydra' },
    { hex = '#14B8A6', label = 'Turkio' },
    { hex = '#F59E0B', label = 'Oranžinė' },
    { hex = '#F97316', label = 'Rusva' },
    { hex = '#EAB308', label = 'Geltona' },
    { hex = '#EC4899', label = 'Rožinė' },
    { hex = '#DB2777', label = 'Fuksija' },
    { hex = '#0A0A0A', label = 'Juoda' },
    { hex = '#64748B', label = 'Pilka' },
}

Config.ColorPalette = {}
for _, entry in ipairs(Config.GangColors) do
    Config.ColorPalette[#Config.ColorPalette + 1] = entry.hex
end

function Config.GetColorLabel(hex)
    local key = tostring(hex or ''):upper():gsub('%s+', '')
    for _, entry in ipairs(Config.GangColors) do
        if tostring(entry.hex or ''):upper() == key then
            return entry.label or entry.hex
        end
    end
    return 'Spalva'
end

function Config.FormatColorPair(primaryHex, secondaryHex)
    local p = Config.GetColorLabel(primaryHex)
    local s = Config.GetColorLabel(secondaryHex)
    if p == s then return p end
    return ('%s / %s'):format(p, s)
end

Config.Ranks = {
    [0] = 'Runner',
    [1] = 'Member',
    [2] = 'Shot Caller',
    [3] = 'Underboss',
    [4] = 'Boss',
}

--- Turf zonos: config_turf_cells.lua (~40 RP rajonų, ne tinklelis)

Config.TurfClaimThreshold = 100

--- Turf įtaka (atskira nuo misijų progresijos)
Config.TurfInfluence = {
    claimThreshold = 100,
    graffiti = 6,
    drugSaleInfluence = 2,
    presencePerMinute = 1,
    mission = 6,
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
    { item = 'thc_cart', label = 'THC kronštainis', base = 95 },
    { item = 'illegal_alcohol', label = 'Nelegalus alkoholis', base = 75 },
    { item = 'vape_liquid', label = 'Vape skystis', base = 65 },
    { item = 'weed_bag', label = 'Žolės maišelis', base = 140 },
    { item = 'heroin_bag', label = 'Heroino maišelis', base = 220 },
    { item = 'meth_bag', label = 'Metamfetamino maišelis', base = 260 },
    { item = 'pills_pack', label = 'Tablečių pakuotė', base = 180 },
    { item = 'mushroom_pack', label = 'Grybų pakuotė', base = 150 },
    { item = 'cocaine_bag', label = 'Kokaino maišelis', base = 420 },
    { item = 'amphetamine_bag', label = 'Amfetamino maišelis', base = 380 },
    { item = 'cartel_pack', label = 'Kartelio mišinys', base = 520 },
}

Config.DrugSell = {
    maxDistanceToPed = 3.0,
    policeAlertBase = 14,
    reputationPriceFactor = 0.006,
}

Config.AdminPermissions = { 'admin', 'god' }
--- txAdmin / cfg group.admin (add_ace group.admin command allow) — ne QBCore /addpermission
Config.AdminAceFallbacks = { 'command', 'group.admin' }

--- Turf tablet: Leaflet + HD satelitas (pilna GTA sala, tas pats kaip MDT)
Config.TabletMap = {
    gameMin = { x = -4000.0, y = -4000.0 },
    gameMax = { x = 4500.0, y = 6625.0 },
    coordMin = { x = -4000.0, y = -4000.0 },
    coordMax = { x = 4500.0, y = 6625.0 },
    viewMin = { x = -4000.0, y = -4000.0 },
    viewMax = { x = 4500.0, y = 6625.0 },
    offsetX = 0.0,
    offsetY = 0.0,
    scaleX = 1.0,
    scaleY = 1.0,
    flipY = true,
    imageWidth = 2048,
    imageHeight = 2560,
    imageFile = 'asset/gtav_satellite_2048.png',
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
