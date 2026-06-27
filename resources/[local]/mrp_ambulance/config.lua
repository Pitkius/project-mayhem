Config = {}

Config.JobName = 'ambulance'
Config.TargetDistance = 3.2

Config.Blip = {
    sprite = 61,
    colour = 2,
    scale = 0.85,
    label = 'Greitoji pagalba',
}

Config.Permissions = {
    boss_menu = 4,
}

--- Medicininė / tarnybinė apranga – žr. config_duty_outfits.lua (addon kolekcijos mrp_gmp_uniforms)

--- EMS postai (Gabz Pillbox + Sandy + Paleto MLO zonos)
Config.Stations = {
    {
        id = 'ems_ls',
        label = 'Pillbox – Greitoji pagalba',
        coords = vector3(309.52, -595.29, 43.28),
        heading = 71.0,
        blip = true,
        stash = {
            coords = vector3(306.36, -601.55, 43.28),
            stashId = 'mrp_ems_ls',
            label = 'EMS sandėlis (Pillbox)',
            maxweight = 4000000,
            slots = 80,
        },
        locker = {
            coords = vector3(298.62, -598.41, 43.28),
            heading = 250.0,
        },
        garageHub = {
            coords = vector3(339.32, -584.32, 28.80),
            heading = 70.0,
            spawn = vector4(331.58, -543.68, 28.74, 340.0),
        },
        emsGarageId = 'ems_ls',
        management = {
            coords = vector3(312.15, -593.45, 43.28),
            heading = 71.0,
        },
    },
    {
        id = 'ems_sandy',
        label = 'Sandy Shores – EMS',
        coords = vector3(1839.6, 3672.9, 34.28),
        heading = 30.0,
        blip = true,
        stash = {
            coords = vector3(1837.2, 3674.5, 34.28),
            stashId = 'mrp_ems_sandy',
            label = 'EMS sandėlis (Sandy)',
            maxweight = 3000000,
            slots = 60,
        },
        locker = {
            coords = vector3(1841.0, 3671.0, 34.28),
            heading = 210.0,
        },
        garageHub = {
            coords = vector3(1843.5, 3663.8, 33.85),
            heading = 210.0,
            spawn = vector4(1843.5, 3663.8, 33.85, 210.0),
        },
        emsGarageId = 'ems_sandy',
        management = {
            coords = vector3(1840.0, 3676.0, 34.28),
            heading = 30.0,
        },
    },
    {
        id = 'ems_paleto',
        label = 'Paleto Bay – EMS',
        coords = vector3(-247.76, 6331.39, 32.43),
        heading = 135.0,
        blip = true,
        stash = {
            coords = vector3(-249.5, 6333.0, 32.43),
            stashId = 'mrp_ems_paleto',
            label = 'EMS sandėlis (Paleto)',
            maxweight = 3000000,
            slots = 60,
        },
        locker = {
            coords = vector3(-246.0, 6329.5, 32.43),
            heading = 315.0,
        },
        garageHub = {
            coords = vector3(-254.0, 6347.0, 32.50),
            heading = 135.0,
            spawn = vector4(-254.0, 6347.0, 32.50, 135.0),
        },
        emsGarageId = 'ems_paleto',
        management = {
            coords = vector3(-245.0, 6334.0, 32.43),
            heading = 135.0,
        },
    },
}

--- Seni alias (atgalinis suderinamumas)
Config.Base = vector4(309.52, -595.29, 43.28, 71.0)
Config.Stash = Config.Stations[1].stash
Config.Locker = Config.Stations[1].locker
Config.GarageHub = Config.Stations[1].garageHub
Config.Management = Config.Stations[1].management

Config.RepairBays = {
    { coords = vector3(316.2, -584.5, 43.28), length = 5.8, width = 7.5, heading = 160.0 },
    { coords = vector3(312.5, -583.0, 43.28), length = 5.8, width = 7.5, heading = 160.0 },
    { coords = vector3(308.8, -581.5, 43.28), length = 5.8, width = 7.5, heading = 160.0 },
}
