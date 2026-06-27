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

--- Nuomos punktai (spawn = kur atsiranda dviratis).
--- Koordinatės nustatytos šalia garažų, ne ant jų (qb-target / marker nesikerta).
Config.Locations = {
    {
        id = 'airport',
        label = 'Oro uostas (LSIA)',
        coords = vector4(-998.20, -2682.40, 13.98, 330.0),
        spawn = vector4(-994.80, -2685.60, 13.98, 330.0),
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
        label = 'Vespucci',
        coords = vector4(-1151.20, -732.50, 19.88, 311.0),
        spawn = vector4(-1148.50, -735.00, 19.88, 311.0),
    },
    {
        id = 'delperro',
        label = 'Del Perro krantas',
        coords = vector4(-1520.30, -428.50, 35.45, 230.0),
        spawn = vector4(-1517.60, -430.90, 35.45, 230.0),
    },
    {
        id = 'vinewood',
        label = 'Vinewood',
        coords = vector4(604.50, 82.50, 92.13, 248.0),
        spawn = vector4(607.00, 80.00, 92.13, 248.0),
    },
    {
        id = 'mirrorpark',
        label = 'Mirror Park',
        coords = vector4(1028.50, -755.20, 57.99, 45.0),
        spawn = vector4(1031.00, -757.50, 57.99, 45.0),
    },
    {
        id = 'casino',
        label = 'Kazino',
        coords = vector4(918.50, 11.20, 78.76, 147.0),
        spawn = vector4(921.00, 8.50, 78.76, 147.0),
    },
    {
        id = 'sandy',
        label = 'Sandy Shores',
        coords = vector4(1746.50, 3716.00, 34.14, 110.0),
        spawn = vector4(1749.00, 3713.50, 34.14, 110.0),
    },
    {
        id = 'grapeseed',
        label = 'Grapeseed',
        coords = vector4(1727.00, 4926.50, 42.08, 326.0),
        spawn = vector4(1729.50, 4924.00, 42.08, 326.0),
    },
    {
        id = 'paleto',
        label = 'Paleto Bay',
        coords = vector4(119.50, 6624.00, 31.89, 45.0),
        spawn = vector4(122.00, 6621.50, 31.89, 45.0),
    },
    {
        id = 'chumash',
        label = 'Chumash',
        coords = vector4(-3151.00, 1136.50, 20.86, 159.0),
        spawn = vector4(-3148.50, 1134.00, 20.86, 159.0),
    },
    {
        id = 'route68',
        label = 'Route 68',
        coords = vector4(-2562.00, 2341.50, 33.06, 182.0),
        spawn = vector4(-2559.50, 2339.00, 33.06, 182.0),
    },
    {
        id = 'davis',
        label = 'Davis',
        coords = vector4(358.00, -2048.00, 21.70, 140.0),
        spawn = vector4(360.50, -2050.50, 21.70, 140.0),
    },
}
