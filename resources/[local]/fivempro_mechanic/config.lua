Config = {}

Config.JobName = 'fivempro_mechanic'
Config.TargetDistance = 2.8

--- Pagrindinė bazės vieta (centras / blip)
Config.Base = vector4(-338.82, -136.68, 39.01, 244.49)

Config.Blip = {
    sprite = 446,
    colour = 47,
    scale = 0.85,
    label = 'Mechanikų dirbtuvės',
}

Config.Stash = {
    coords = vector3(-337.45, -135.05, 39.01),
    stashId = 'fivempro_mechanic_ls',
    label = 'Mechanikų sandėlis',
    maxweight = 4000000,
    slots = 80,
}

Config.Management = {
    coords = vector3(-336.75, -139.05, 39.01),
    heading = 244.49,
}

Config.Locker = {
    coords = vector3(-334.95, -137.55, 39.01),
    heading = 244.49,
}

--- Vienas taškas: garažas + tarnybinio transporto pirkimas (fivempro_garages / fivempro_dealership)
Config.GarageHub = {
    coords = vector3(-339.05, -136.85, 39.02),
    heading = 244.49,
}

--- Žaidėjas atveda mašiną į zoną ir paleidžia „greitą“ apžiūrą (iki pilnos integracijos su remonto skriptu)
Config.RepairBays = {
    { coords = vector3(-335.85, -139.55, 39.02), length = 5.2, width = 6.8, heading = 244.49 },
    { coords = vector3(-332.55, -141.95, 39.02), length = 5.2, width = 6.8, heading = 244.49 },
    { coords = vector3(-329.35, -144.35, 39.02), length = 5.2, width = 6.8, heading = 244.49 },
}

Config.Permissions = {
    boss_menu = 4,
}

--- Tarnybinė apranga (komponentai mp freemode – keisk pagal odę)
Config.DutyOutfits = {
    {
        label = 'Darbinė kombinezonas 1',
        minGrade = 0,
        male = { [4] = 39, [6] = 25, [8] = 59, [11] = 56, [9] = 0 },
        female = { [4] = 39, [6] = 25, [8] = 36, [11] = 49, [9] = 0 },
    },
    {
        label = 'Darbinė kombinezonas 2 + pirštinės',
        minGrade = 1,
        male = { [4] = 39, [6] = 24, [8] = 59, [11] = 57, [9] = 0 },
        female = { [4] = 39, [6] = 24, [8] = 36, [11] = 50, [9] = 0 },
    },
}
