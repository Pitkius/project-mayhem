--- Gabz Pillbox liftai (koordinatės pagal standartinį Gabz + prime-elevator setup)
Config.PillboxElevators = {
    {
        id = 'pillbox_lift_west',
        label = 'Liftas',
        floors = {
            {
                label = 'Pagrindinis aukštas',
                desc = 'EMS / registratūra',
                coords = vector4(330.43, -601.16, 43.28, 70.91),
            },
            {
                label = 'Pirmas aukštas',
                desc = 'Priėmimo holas',
                coords = vector4(345.62, -582.54, 28.80, 262.86),
            },
        },
        panels = {
            { coords = vector3(330.04, -602.70, 43.28), heading = 247.68, length = 0.55, width = 0.55 },
            { coords = vector3(346.10, -581.00, 28.80), heading = 69.47, length = 0.55, width = 0.55 },
        },
    },
    {
        id = 'pillbox_lift_main',
        label = 'Liftas',
        floors = {
            {
                label = 'Heli aikštelė',
                desc = 'Stogas',
                coords = vector4(338.51, -583.81, 74.16, 250.07),
                jobs = { 'ambulance', 'police' },
            },
            {
                label = 'Pagrindinis aukštas',
                desc = 'EMS / registratūra',
                coords = vector4(327.02, -603.85, 43.28, 337.25),
            },
            {
                label = 'Garažas',
                desc = 'Transporto garažas',
                coords = vector4(340.18, -584.68, 28.80, 104.87),
                jobs = { 'ambulance', 'police' },
            },
        },
        panels = {
            { coords = vector3(325.65, -603.39, 43.28), heading = 160.6, length = 0.55, width = 0.55 },
            { coords = vector3(339.70, -586.20, 28.80), heading = 246.66, length = 0.55, width = 0.55 },
            { coords = vector3(338.42, -583.71, 74.16), heading = 70.21, length = 2.8, width = 0.55 },
        },
    },
}
