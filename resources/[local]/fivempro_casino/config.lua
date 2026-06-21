Config = Config or {}

--- Diamond Casino (GTA Online interjeras / MLO)
Config.Casino = {
    center = vector3(1110.0, 220.0, -49.0),
    radius = 90.0,
    blip = {
        coords = vector3(924.78, 46.85, 81.11),
        sprite = 679,
        color = 46,
        scale = 0.9,
        label = 'Diamond Casino',
    },
    exit = vector4(1085.98, 214.52, -49.20, 180.0),
    loadVanillaIpl = true,
}

--- Visi limitai — max statymas ir max laimėjimas vienam žaidimui, dienos pergalės limitas (be rato)
Config.Limits = {
    maxBet = 50000,
    maxSingleWin = 50000,
    maxDailyWin = 50000,
    minBet = 50,
}

--- Laimėjimai iš rato dienos limitui NESKAIČIUOJAMI
Config.Wheel = {
    coords = vector3(1111.05, 229.85, -49.64),
    heading = 0.0,
    cooldownHours = 24,
    spinDurationMs = 6500,
    prizes = {
        { label = 'Nieko', type = 'none', amount = 0, weight = 22 },
        { label = '$1,000', type = 'cash', amount = 1000, weight = 24 },
        { label = '$2,500', type = 'cash', amount = 2500, weight = 18 },
        { label = '$5,000', type = 'cash', amount = 5000, weight = 14 },
        { label = '$10,000', type = 'cash', amount = 10000, weight = 10 },
        { label = '$15,000', type = 'cash', amount = 15000, weight = 6 },
        { label = '$25,000', type = 'cash', amount = 25000, weight = 4 },
        { label = '50 žetonų', type = 'chips', amount = 50, weight = 2 },
    },
}

Config.BlackjackTables = {
    { id = 'bj_1', coords = vector3(1149.38, 269.19, -52.84), heading = 135.0 },
    { id = 'bj_2', coords = vector3(1151.84, 266.74, -52.84), heading = 45.0 },
    { id = 'bj_3', coords = vector3(1129.46, 261.63, -52.84), heading = 315.0 },
    { id = 'bj_4', coords = vector3(1144.12, 247.38, -52.04), heading = 225.0 },
}

Config.RouletteTables = {
    { id = 'rl_1', coords = vector3(1144.83, 268.21, -52.84), heading = 135.0 },
    { id = 'rl_2', coords = vector3(1149.01, 262.55, -52.84), heading = 45.0 },
    { id = 'rl_3', coords = vector3(1133.74, 262.59, -52.84), heading = 315.0 },
}

Config.SlotMachines = {
    { id = 'sl_1', coords = vector3(1101.25, 232.43, -50.44) },
    { id = 'sl_2', coords = vector3(1104.55, 229.45, -50.44) },
    { id = 'sl_3', coords = vector3(1108.10, 233.90, -50.44) },
    { id = 'sl_4', coords = vector3(1112.42, 237.90, -50.44) },
    { id = 'sl_5', coords = vector3(1116.85, 228.70, -50.44) },
    { id = 'sl_6', coords = vector3(1120.35, 232.15, -50.44) },
}

--- Ruletės išmokos (europietiška — vienas 0)
Config.RoulettePayouts = {
    number = 36,
    red = 2,
    black = 2,
    odd = 2,
    even = 2,
    low = 2,
    high = 2,
}

Config.SlotSymbols = { '7', 'BAR', 'CH', 'DI', 'BE', 'GR' }
Config.SlotPayouts = {
    ['7-7-7'] = 25,
    ['BAR-BAR-BAR'] = 15,
    ['CH-CH-CH'] = 10,
    ['DI-DI-DI'] = 8,
    ['BE-BE-BE'] = 6,
    ['GR-GR-GR'] = 4,
    pair = 2,
}

--- /dice — kauliukų metimas bet kur
Config.Dice = {
    command = 'dice',
    maxDice = 3,
    maxSides = 20,
    defaultSides = 6,
    animMs = 1800,
    displayMs = 4500,
    syncRadius = 35.0,
}
