Config = {}

Config.Blip = {
    sprite = 348,
    colour = 2,
    scale = 0.75,
    label = 'Dviračių nuoma',
}

Config.PedModel = 'u_m_m_bikehire_01'
Config.PedScenario = 'WORLD_HUMAN_STAND_MOBILE'
Config.TargetDistance = 2.5

--- Nuomos kaina (grąžinus dviratį — dalis grąžinama)
Config.RefundPercent = 40

Config.Bikes = {
    { model = 'bmx', label = 'BMX', price = 35 },
    { model = 'cruiser', label = 'Cruiser', price = 25 },
    { model = 'fixter', label = 'Fixter', price = 30 },
    { model = 'scorcher', label = 'Scorcher (kalnų)', price = 45 },
    { model = 'tribike', label = 'Tri-Cycles', price = 55 },
    { model = 'tribike2', label = 'Tri-Cycles (enduro)', price = 55 },
}

--- Nuomos punktai (spawn = kur atsiranda dviratis)
Config.Locations = {
    {
        id = 'airport',
        label = 'Oro uostas (LSIA)',
        coords = vector4(-1012.40, -2690.80, 13.98, 150.0),
        spawn = vector4(-1008.20, -2694.50, 13.98, 150.0),
    },
    {
        id = 'legion',
        label = 'Legion aikštė',
        coords = vector4(-247.30, -992.50, 29.29, 70.0),
        spawn = vector4(-244.80, -994.90, 29.29, 70.0),
    },
    {
        id = 'pillbox',
        label = 'Pillbox',
        coords = vector4(294.50, -584.20, 43.28, 70.0),
        spawn = vector4(297.20, -586.80, 43.28, 70.0),
    },
    {
        id = 'vespucci',
        label = 'Vespucci krantas',
        coords = vector4(-1183.60, -1511.40, 4.38, 125.0),
        spawn = vector4(-1180.50, -1513.80, 4.38, 125.0),
    },
    {
        id = 'delperro',
        label = 'Del Perro',
        coords = vector4(-1520.30, -428.50, 35.45, 230.0),
        spawn = vector4(-1517.60, -430.90, 35.45, 230.0),
    },
    {
        id = 'vinewood',
        label = 'Vinewood',
        coords = vector4(596.80, 90.50, 92.13, 250.0),
        spawn = vector4(599.50, 88.20, 92.13, 250.0),
    },
    {
        id = 'mirrorpark',
        label = 'Mirror Park',
        coords = vector4(1036.80, -763.50, 57.99, 225.0),
        spawn = vector4(1039.50, -765.80, 57.99, 225.0),
    },
    {
        id = 'casino',
        label = 'Kazino',
        coords = vector4(895.50, -1.20, 78.76, 150.0),
        spawn = vector4(898.20, -3.50, 78.76, 150.0),
    },
    {
        id = 'sandy',
        label = 'Sandy Shores',
        coords = vector4(1737.50, 3710.80, 34.14, 20.0),
        spawn = vector4(1740.20, 3708.50, 34.14, 20.0),
    },
    {
        id = 'grapeseed',
        label = 'Grapeseed',
        coords = vector4(1718.90, 4933.50, 42.08, 145.0),
        spawn = vector4(1721.60, 4931.20, 42.08, 145.0),
    },
    {
        id = 'paleto',
        label = 'Paleto Bay',
        coords = vector4(110.50, 6617.80, 31.89, 225.0),
        spawn = vector4(113.20, 6615.50, 31.89, 225.0),
    },
    {
        id = 'chumash',
        label = 'Chumash',
        coords = vector4(-3142.80, 1129.20, 20.86, 340.0),
        spawn = vector4(-3140.10, 1126.90, 20.86, 340.0),
    },
    {
        id = 'route68',
        label = 'Route 68',
        coords = vector4(-2553.50, 2335.20, 33.06, 95.0),
        spawn = vector4(-2551.00, 2332.90, 33.06, 95.0),
    },
    {
        id = 'davis',
        label = 'Davis',
        coords = vector4(367.50, -2037.80, 21.70, 320.0),
        spawn = vector4(370.20, -2040.10, 21.70, 320.0),
    },
    {
        id = 'paletobay_pier',
        label = 'Paleto krantas',
        coords = vector4(-1592.50, 5196.80, 4.36, 30.0),
        spawn = vector4(-1589.80, 5194.50, 4.36, 30.0),
    },
}
