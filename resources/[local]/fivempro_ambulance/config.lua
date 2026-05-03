Config = {}

Config.JobName = 'fivempro_ambulance'
Config.TargetDistance = 2.8

--- Pagrindinė vieta (bez MLO – lauke)
Config.Base = vector4(-447.51, -340.87, 34.50, 259.81)

Config.Blip = {
    sprite = 61,
    colour = 2,
    scale = 0.85,
    label = 'Greitoji pagalba',
}

Config.Stash = {
    coords = vector3(-449.2, -342.4, 34.50),
    stashId = 'fivempro_ems_ls',
    label = 'EMS sandėlis',
    maxweight = 4000000,
    slots = 80,
}

Config.Management = {
    coords = vector3(-445.2, -339.1, 34.50),
    heading = 259.81,
}

Config.Locker = {
    coords = vector3(-448.0, -338.2, 34.50),
    heading = 259.81,
}

Config.GarageHub = {
    coords = vector3(-448.1, -341.05, 34.52),
    heading = 259.81,
}

--- „Priėmimo“ vietos – lauke prie įėjimo (greitos pagalbos zonos RP)
Config.RepairBays = {
    { coords = vector3(-451.2, -342.8, 34.50), length = 4.5, width = 6.0, heading = 259.81 },
    { coords = vector3(-453.5, -344.8, 34.50), length = 4.5, width = 6.0, heading = 259.81 },
    { coords = vector3(-455.8, -346.8, 34.50), length = 4.5, width = 6.0, heading = 259.81 },
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
