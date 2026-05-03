Config = {}

Config.JobName = 'ambulance'
Config.TargetDistance = 3.2

--- Pagrindinė vieta (bez MLO – lauke) – persidėta kartu su garažo tašku
Config.Base = vector4(-458.6, -327.15, 34.50, 91.30)

Config.Blip = {
    sprite = 61,
    colour = 2,
    scale = 0.85,
    label = 'Greitoji pagalba',
}

Config.Stash = {
    coords = vector3(-462.9, -326.4, 34.50),
    stashId = 'fivempro_ems_ls',
    label = 'EMS sandėlis',
    maxweight = 4000000,
    slots = 80,
}

Config.Management = {
    coords = vector3(-454.85, -323.35, 34.50),
    heading = 91.30,
}

Config.Locker = {
    coords = vector3(-457.45, -321.05, 34.50),
    heading = 91.30,
}

--- Garažas + salonas (qb-target) – koordinatės pagal žaidėjo nuotrauką
Config.GarageHub = {
    coords = vector3(-460.42, -324.28, 34.50),
    heading = 91.30,
}

--- „Priėmimo“ vietos – išskaidyta plačiau nuo bazės
Config.RepairBays = {
    { coords = vector3(-464.2, -329.1, 34.50), length = 5.8, width = 7.5, heading = 91.30 },
    { coords = vector3(-467.5, -325.4, 34.50), length = 5.8, width = 7.5, heading = 91.30 },
    { coords = vector3(-451.8, -328.0, 34.50), length = 5.8, width = 7.5, heading = 91.30 },
}

Config.Permissions = {
    boss_menu = 4,
}

--- Medicininė / tarnybinė apranga (keisk pagal odę)
Config.DutyOutfits = {
    {
        label = 'Medicininiai marškiniai 1',
        minGrade = 0,
        male = { [4] = 23, [6] = 22, [8] = 15, [11] = 250, [9] = 0 },
        female = { [4] = 23, [6] = 22, [8] = 15, [11] = 258, [9] = 0 },
    },
    {
        label = 'Greitosios pagalbos liemenė',
        minGrade = 1,
        male = { [4] = 23, [6] = 22, [8] = 15, [11] = 250, [9] = 2 },
        female = { [4] = 23, [6] = 22, [8] = 15, [11] = 258, [9] = 2 },
    },
}
