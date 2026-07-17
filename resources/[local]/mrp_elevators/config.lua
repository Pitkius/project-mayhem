Config = {}

--[[
  Liftai: prie panelio — tik qb-target → meniu su aukštais.
  floors[].coords = kur teleportuoja (vector4 x,y,z,heading)
  panels[]        = qb-target zonos (jei nėra — naudojami floor coords)
  jobs            = elevator arba floor lygyje: nil = visi; {'police'} = tik tie job'ai
  requireDuty     = true → reikia onduty

  PD koordinatės pagal NTeam MRPD aukštų Z (mrp_ltpd).
  Jei teleportas ne į kabiną — /coords prie lifto ir pataisyk XY (Z jau teisingas).
]]

Config.InteractDistance = 2.2
Config.FadeMs = 350
--- qb-target box dydis, jei panel neturi length/width
Config.DefaultPanelLength = 1.35
Config.DefaultPanelWidth = 1.35
Config.PanelMinZ = 1.15
Config.PanelMaxZ = 1.45

Config.Elevators = {
    --- ─── NTeam MRPD (Mission Row) ─────────────────────────────────
    {
        id = 'mrpd_main',
        label = 'PD liftas',
        jobs = { 'police' },
        requireDuty = false,
        floors = {
            {
                label = 'Rūsys / garažas',
                desc = 'Celės, konfiskatas, garažas',
                coords = vector4(461.80, -984.50, 22.85, 270.0),
            },
            {
                label = 'Pagrindinis aukštas',
                desc = 'Lobby / pamaina / rūbinės',
                coords = vector4(461.80, -984.50, 30.69, 270.0),
            },
            {
                label = '2 aukštas',
                desc = 'Kabinetai / vadovybė',
                coords = vector4(461.80, -984.50, 34.25, 270.0),
            },
            {
                label = '3 aukštas (ARAS)',
                desc = 'ARAS / forensics',
                coords = vector4(461.80, -984.50, 38.25, 270.0),
            },
            {
                label = 'Stogas',
                desc = 'Helipadas / maistas',
                coords = vector4(461.80, -984.50, 42.25, 270.0),
            },
        },
        --- Paneliai prie kiekvieno aukšto (tas pats XY, skirtingas Z)
        panels = {
            { coords = vector3(461.80, -984.50, 22.85), heading = 270.0, length = 1.2, width = 1.2 },
            { coords = vector3(461.80, -984.50, 30.69), heading = 270.0, length = 1.2, width = 1.2 },
            { coords = vector3(461.80, -984.50, 34.25), heading = 270.0, length = 1.2, width = 1.2 },
            { coords = vector3(461.80, -984.50, 38.25), heading = 270.0, length = 1.2, width = 1.2 },
            { coords = vector3(461.80, -984.50, 42.25), heading = 270.0, length = 1.2, width = 1.2 },
        },
    },

    --- ─── Gabz Pillbox — west ──────────────────────────────────────
    {
        id = 'pillbox_lift_west',
        label = 'EMS liftas (vakarų)',
        floors = {
            {
                label = 'Pagrindinis aukštas',
                desc = 'EMS / registratūra',
                coords = vector4(330.43, -601.16, 43.28, 70.91),
            },
            {
                label = 'Apatinis aukštas',
                desc = 'Priėmimo holas',
                coords = vector4(345.62, -582.54, 28.80, 262.86),
            },
        },
        panels = {
            { coords = vector3(330.04, -602.70, 43.28), heading = 247.68, length = 0.55, width = 0.55 },
            { coords = vector3(346.10, -581.00, 28.80), heading = 69.47, length = 0.55, width = 0.55 },
        },
    },

    --- ─── Gabz Pillbox — main (stogas / garažas tik EMS+PD) ─────────
    {
        id = 'pillbox_lift_main',
        label = 'EMS liftas',
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
