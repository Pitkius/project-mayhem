Config = Config or {}

Config.InteractKeyLabel = 'E'

--- Diamond Casino (stream MLO — įėjimas pėsčiomis pro duris, be teleportų)
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
    interiorSpawn = vector4(1089.1294, 207.2294, -48.9997, 320.0139), --- tik eject / fallback
    loadVanillaIpl = true,
    --- Stream MLO: resources/[mlo]/[mlo_pack_3]/diamond-casino-{exterior,interior}
    useStreamMlo = true,
    --- false = jokių script teleportų; eik pro MLO duris
    walkIn = false,
}

--- Senieji teleportų taškai išjungti (MLO). Palikta tuščia / atsarginė konfigūracija.
Config.CasinoEntrances = {}
Config.CasinoExits = {}


--- Kazino kasa — žetonų keitimas 1:1, limitas matomas tik čia
Config.Cashier = {
    coords = vector4(1117.25, 220.05, -49.44, 90.0),
    pedModel = 'u_f_m_casinoshop_01',
    pedScenario = 'WORLD_HUMAN_STAND_IMPATIENT',
    targetDistance = 2.5,
}

--- Statymai ir laimėjimai žetonais (1 žetonas = $1 keičiant pas kasininkę)
Config.Limits = {
    maxBet = 50000,
    maxSingleWin = 50000,
    maxDailyWin = 50000,
    minBet = 50,
}

--- Savaitinis / jackpot automobilis ant podiumo
Config.JackpotCar = {
  weeklyDays = 7,
  garage = 'casino',
  podium = vector4(1100.47, 220.25, -49.95, 0.0),
  pool = {
      { model = 'pariah', label = 'Ocelot Pariah' },
      { model = 'italigto', label = 'Grotti Itali GTO' },
      { model = 'emerus', label = 'Progen Emerus' },
      { model = 'krieger', label = 'Benefactor Krieger' },
      { model = 't20', label = 'Progen T20' },
      { model = 'zentorno', label = 'Pegassi Zentorno' },
      { model = 'toros', label = 'Pegassi Toros' },
      { model = 'comet6', label = 'Pfister Comet S2' },
      { model = 'jester4', label = 'Dinka Jester RR' },
      { model = 'cypher', label = 'Übermacht Cypher' },
      { model = 'elegy2', label = 'Annis Elegy RH8' },
      { model = 'seven70', label = 'Dewbauchee Seven-70' },
      { model = 'schlagen', label = 'Benefactor Schlagen GT' },
      { model = 'neon', label = 'Pfister Neon' },
      { model = 'cyclone', label = 'Coil Cyclone' },
  },
}

--- Laimės ratas (20 segmentų × 18°)
Config.Wheel = {
    model = `vw_prop_vw_luckywheel_02a`,
    coords = vector3(1111.052, 229.849, -50.38),
    heading = 0.0,
    movePos = vector3(1109.55, 228.75, -49.64),
    moveHeading = 0.0,
    cooldownHours = 24,
    --- slot 1–20 = rato segmentas (sukimui)
    prizes = {
        { slot = 1,  label = 'Nieko', type = 'none', amount = 0, weight = 16 },
        { slot = 2,  label = 'Jackpot automobilis', type = 'vehicle', amount = 1, weight = 1 },
        { slot = 3,  label = '1,000 žetonų', type = 'chips', amount = 1000, weight = 14 },
        { slot = 4,  label = 'Nieko', type = 'none', amount = 0, weight = 14 },
        { slot = 5,  label = '2,500 žetonų', type = 'chips', amount = 2500, weight = 12 },
        { slot = 6,  label = '500 žetonų', type = 'chips', amount = 500, weight = 16 },
        { slot = 7,  label = 'Nieko', type = 'none', amount = 0, weight = 14 },
        { slot = 8,  label = '5,000 žetonų', type = 'chips', amount = 5000, weight = 8 },
        { slot = 9,  label = '1,500 žetonų', type = 'chips', amount = 1500, weight = 10 },
        { slot = 10, label = 'Nieko', type = 'none', amount = 0, weight = 14 },
        { slot = 11, label = '10,000 žetonų', type = 'chips', amount = 10000, weight = 5 },
        { slot = 12, label = '750 žetonų', type = 'chips', amount = 750, weight = 12 },
        { slot = 13, label = 'Nieko', type = 'none', amount = 0, weight = 14 },
        { slot = 14, label = '15,000 žetonų', type = 'chips', amount = 15000, weight = 4 },
        { slot = 15, label = '2,000 žetonų', type = 'chips', amount = 2000, weight = 10 },
        { slot = 16, label = 'Nieko', type = 'none', amount = 0, weight = 14 },
        { slot = 17, label = '20,000 žetonų', type = 'chips', amount = 20000, weight = 3 },
        { slot = 18, label = '3,000 žetonų', type = 'chips', amount = 3000, weight = 8 },
        { slot = 19, label = 'Nieko', type = 'none', amount = 0, weight = 14 },
        { slot = 20, label = '25,000 žetonų', type = 'chips', amount = 25000, weight = 2 },
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

Config.Dice = {
    command = 'dice',
    maxDice = 3,
    maxSides = 20,
    defaultSides = 6,
    animMs = 1800,
    displayMs = 4500,
    syncRadius = 35.0,
}
