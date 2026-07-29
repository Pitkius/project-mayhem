Config = {}

--- Klubo centras (Gabz Vanilla Unicorn / v_strip3 interjeras)
Config.Club = {
    center = vector3(115.01, -1293.19, 28.27),
    spawnRadius = 45.0,
}

Config.Blip = {
    enabled = true,
    coords = vector3(135.409, -1308.931, 28.991),
    sprite = 121,
    color = 48,
    scale = 0.75,
    label = 'Vanilla Unicorn',
}

Config.Prices = {
    lapDance = 120,
    throwCash = 40,
    tipDancer = 25, -- tipas tiesiai šokėjai ant stulpo
}

--- Watch chair sit: scenario Z offset (GTA seat scenarios sit below marker)
Config.WatchSitZOffset = -0.52

--- Scenarijai ant baro / salės kėdžių (kaip GTA — žiūrėti į sceną)
Config.WatchChairs = {
    vector4(123.36, -1292.15, 28.27, 210.0),
    vector4(125.82, -1293.55, 28.27, 210.0),
    vector4(128.77, -1294.90, 28.27, 210.0),
    vector4(130.98, -1296.10, 28.27, 210.0),
    vector4(119.62, -1288.62, 28.27, 120.0),
    vector4(121.86, -1286.94, 28.27, 120.0),
    vector4(109.35, -1291.58, 28.27, 30.0),
    vector4(107.10, -1293.22, 28.27, 30.0),
    vector4(105.02, -1294.72, 28.27, 30.0),
    vector4(112.45, -1302.14, 28.27, 300.0),
    vector4(114.72, -1303.78, 28.27, 300.0),
}

--- VIP / privataus šokio vietos (vanilla unicorn interjeras — tinka ir Gabz VU)
Config.LapSeats = {
    {
        id = 1,
        label = 'VIP sofa 1',
        target = vector3(118.75, -1301.97, 28.42),
        sit = vector4(119.06, -1302.66, 28.27, 40.0),
        camHeading = -10.0,
        exit = vector3(118.75, -1301.99, 28.42),
        exitWait = 5000,
        stripperSpawn = vector4(117.10, -1301.25, 28.05, 303.19),
        stripperPath1 = vector3(118.71, -1301.93, 28.42),
        stripperPath2 = vector3(118.0, -1300.3, 28.17),
        stripperDance = vector3(118.74, -1301.91, 29.27),
        stripperEnd = vector3(117.1, -1301.25, 28.05),
        approachWait = 4900,
    },
    {
        id = 2,
        label = 'VIP sofa 2',
        target = vector3(116.59, -1303.01, 28.42),
        sit = vector4(116.90, -1303.75, 28.27, 40.0),
        camHeading = -10.0,
        exit = vector3(116.59, -1303.01, 28.42),
        exitWait = 6200,
        stripperSpawn = vector4(114.98, -1302.43, 28.05, 303.19),
        stripperPath1 = vector3(116.67, -1303.35, 29.27),
        stripperPath2 = vector3(115.85, -1302.02, 29.02),
        stripperDance = vector3(116.25, -1302.85, 29.27),
        stripperEnd = vector3(114.98, -1302.43, 28.05),
        approachWait = 6000,
    },
    {
        id = 3,
        label = 'VIP sofa 3',
        target = vector3(114.64, -1304.54, 29.27),
        sit = vector4(114.86, -1305.0, 28.27, 40.0),
        camHeading = -10.0,
        exit = vector3(114.64, -1304.54, 29.27),
        exitWait = 6800,
        stripperSpawn = vector4(112.89, -1303.69, 28.05, 303.19),
        stripperPath1 = vector3(114.64, -1304.54, 29.27),
        stripperPath2 = vector3(113.56, -1302.94, 29.02),
        stripperDance = vector3(114.33, -1304.23, 29.27),
        stripperEnd = vector3(112.89, -1303.69, 28.05),
        approachWait = 7000,
    },
    {
        id = 4,
        label = 'VIP sofa 4',
        target = vector3(112.66, -1305.52, 29.27),
        sit = vector4(113.08, -1306.17, 28.27, 40.0),
        camHeading = -10.0,
        exit = vector3(112.66, -1305.52, 29.27),
        exitWait = 7500,
        stripperSpawn = vector4(111.32, -1304.58, 28.05, 303.19),
        stripperPath1 = vector3(112.66, -1305.52, 29.27),
        stripperPath2 = vector3(111.82, -1304.17, 29.02),
        stripperDance = vector3(112.42, -1305.11, 29.27),
        stripperEnd = vector3(111.32, -1304.58, 28.05),
        approachWait = 8000,
    },
    {
        id = 5,
        label = 'VIP sofa 5',
        target = vector3(111.18, -1302.62, 29.27),
        sit = vector4(110.57, -1301.82, 28.27, 216.6),
        camHeading = -10.0,
        exit = vector3(111.18, -1302.62, 29.27),
        exitWait = 7500,
        stripperSpawn = vector4(110.89, -1303.84, 28.05, 303.19),
        stripperPath1 = vector3(111.18, -1302.62, 29.27),
        stripperPath2 = vector3(111.46, -1303.61, 29.02),
        stripperDance = vector3(111.17, -1302.81, 29.27),
        stripperEnd = vector3(110.89, -1303.84, 28.05),
        approachWait = 8000,
    },
    {
        id = 6,
        label = 'VIP sofa 6',
        target = vector3(112.64, -1301.27, 29.27),
        sit = vector4(112.34, -1300.76, 28.27, 216.6),
        camHeading = -10.0,
        exit = vector3(112.64, -1301.27, 29.27),
        exitWait = 6800,
        stripperSpawn = vector4(112.42, -1303.04, 28.05, 303.19),
        stripperPath1 = vector3(112.64, -1301.27, 29.27),
        stripperPath2 = vector3(113.35, -1302.36, 29.02),
        stripperDance = vector3(112.91, -1301.62, 29.27),
        stripperEnd = vector3(112.42, -1303.04, 28.05),
        approachWait = 7000,
    },
    {
        id = 7,
        label = 'VIP sofa 7',
        target = vector3(114.73, -1300.41, 29.27),
        sit = vector4(114.27, -1299.66, 28.27, 216.6),
        camHeading = -10.0,
        exit = vector3(114.73, -1300.41, 29.27),
        exitWait = 6000,
        stripperSpawn = vector4(114.29, -1301.91, 28.05, 303.19),
        stripperPath1 = vector3(114.73, -1300.41, 29.27),
        stripperPath2 = vector3(115.08, -1301.39, 29.02),
        stripperDance = vector3(114.88, -1300.64, 29.27),
        stripperEnd = vector3(114.29, -1301.91, 28.05),
        approachWait = 7000,
    },
}

--- Scenos stulpai (pole dance NPC)
Config.Poles = {
    { coords = vector3(108.83, -1289.04, 28.25), heading = 30.0 },
    { coords = vector3(104.77, -1294.44, 28.26), heading = 210.0 },
    { coords = vector3(102.24, -1289.97, 28.26), heading = 120.0 },
}

--- Šokėjų modeliai (vanilla stripper peds)
Config.Strippers = {
    {
        name = 'Crystal',
        model = `s_f_y_stripper_01`,
        components = {
            { 0, 0, 0 },
            { 1, 0, 0 },
            { 2, 0, 0 },
            { 3, 0, 0 },
            { 4, 0, 0 },
            { 6, 0, 0 },
            { 8, 0, 0 },
            { 11, 0, 0 },
        },
    },
    {
        name = 'Nikki',
        model = `s_f_y_stripper_02`,
        components = {
            { 0, 0, 0 },
            { 2, 1, 0 },
            { 3, 0, 0 },
            { 4, 0, 0 },
            { 8, 0, 0 },
            { 11, 1, 0 },
        },
    },
    {
        name = 'Destiny',
        model = `mp_f_stripperlite`,
        components = {
            { 0, 0, 0 },
            { 2, 2, 0 },
            { 3, 0, 0 },
            { 4, 1, 0 },
            { 8, 0, 0 },
            { 11, 0, 0 },
        },
    },
}

--- Vanilla GTA pole routines (visi 3)
Config.PoleAnims = {
    { dict = 'mini@strip_club@pole_dance@pole_dance1', clip = 'pole_dance1' },
    { dict = 'mini@strip_club@pole_dance@pole_dance2', clip = 'pole_dance2' },
    { dict = 'mini@strip_club@pole_dance@pole_dance3', clip = 'pole_dance3' },
}

Config.PoleAnimRotateMs = 45000

--- Pinigų propas tipui / metimui (kaip GTA)
Config.CashProp = 'prop_anim_cash_note'
Config.CashPileProp = 'prop_cash_pile_01'

--- Pritilti prie baro (mesti pinigus į sceną)
Config.LeanSpots = {
    { coords = vector3(114.31, -1289.97, 28.26), heading = 29.0 },
    { coords = vector3(114.75, -1285.88, 28.26), heading = 116.2 },
    { coords = vector3(110.98, -1284.24, 28.26), heading = 210.0 },
}

Config.WatchScenario = 'PROP_HUMAN_SEAT_STRIP_WATCH'
--- VIP sėdėjimas naudoja tą patį vanilla strip-watch scenario
Config.VipSitScenario = 'PROP_HUMAN_SEAT_STRIP_WATCH'
