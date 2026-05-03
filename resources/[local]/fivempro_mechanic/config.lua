Config = {}

Config.JobName = 'mechanic'
Config.TargetDistance = 3.2

--- Blipas ir tarnybos taškas – prie garažo (6 nuotrauka)
Config.Base = vector4(-350.41, -117.01, 38.95, 246.37)

Config.Blip = {
    sprite = 446,
    colour = 47,
    scale = 0.85,
    label = 'Mechanikų dirbtuvės',
}

--- Sandėlis / įrankiai (5 nuotrauka)
Config.Stash = {
    coords = vector3(-319.45, -132.02, 38.98),
    heading = 260.38,
    stashId = 'fivempro_mechanic_ls',
    label = 'Mechanikų sandėlis',
    maxweight = 4000000,
    slots = 80,
}

--- Vadovybės meniu (4 nuotrauka)
Config.Management = {
    coords = vector3(-323.52, -129.54, 39.01),
    heading = 335.34,
}

--- Persirengimas / rūbinė (1 nuotrauka)
Config.Locker = {
    coords = vector3(-345.48, -122.90, 39.01),
    heading = 66.30,
}

--- Garažas + tarnybinio transporto pirkimas (6 nuotrauka)
Config.GarageHub = {
    coords = vector3(-350.41, -117.01, 38.95),
    heading = 246.37,
}

--- Remonto vietos (2 ir 3 nuotraukos)
Config.RepairBays = {
    { coords = vector3(-340.89, -128.34, 39.01), length = 5.2, width = 6.8, heading = 161.82 },
    { coords = vector3(-330.82, -131.43, 39.01), length = 5.2, width = 6.8, heading = 156.15 },
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
