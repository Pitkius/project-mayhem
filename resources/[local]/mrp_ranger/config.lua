Config = {}

Config.JobName = 'ranger'

Config.Permissions = {
    cuff = 0,
    fine = 0,
    stash = 0,
    garage = 0,
    locker = 0,
    boss_menu = 3,
}

Config.Station = {
    id = 'ranger_main',
    garageId = 'ranger_main',
    coords = vector3(386.72, 798.67, 190.49),
    bossCoords = vector3(386.72, 798.67, 190.49),
    managementRadius = 4.0,
}

Config.FinePresets = {
    { code = 'NO_FISH', label = 'Žvejyba be licencijos', defaultAmount = 250 },
    { code = 'NO_HUNT', label = 'Medžioklė be licencijos', defaultAmount = 400 },
    { code = 'POACH', label = 'Brakonieriavimas', defaultAmount = 600 },
    { code = 'FIRE', label = 'Ugnies kindimas gamtoje', defaultAmount = 350 },
    { code = 'LITTER', label = 'Šiukšlių palikimas', defaultAmount = 120 },
    { code = 'OFFROAD', label = 'Transportas draudžiamoje zonoje', defaultAmount = 180 },
}

Config.MaxFineAmount = 25000

Config.DutyOutfits = {
    male = {
        ['mask'] = { item = 0, texture = 0 },
        ['torso2'] = { item = 153, texture = 3 },
        ['t-shirt'] = { item = 15, texture = 0 },
        ['pants'] = { item = 97, texture = 3 },
        ['shoes'] = { item = 51, texture = 0 },
        ['arms'] = { item = 0, texture = 0 },
        ['hat'] = { item = 104, texture = 3 },
    },
    female = {
        ['mask'] = { item = 0, texture = 0 },
        ['torso2'] = { item = 154, texture = 3 },
        ['t-shirt'] = { item = 15, texture = 0 },
        ['pants'] = { item = 100, texture = 3 },
        ['shoes'] = { item = 52, texture = 0 },
        ['arms'] = { item = 0, texture = 0 },
        ['hat'] = { item = 103, texture = 3 },
    },
}
