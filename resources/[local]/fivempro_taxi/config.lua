Config = {}

Config.JobName = 'taxi'
Config.TargetDistance = 3.0

Config.Base = vector4(902.12, -172.41, 74.08, 56.0)

Config.Blip = {
    sprite = 198,
    colour = 5,
    scale = 0.85,
    label = 'Downtown Cab',
}

Config.Stash = {
    coords = vector3(900.58, -170.88, 74.08),
    heading = 56.0,
    stashId = 'fivempro_taxi_ls',
    label = 'Taksi sandėlis',
    maxweight = 1500000,
    slots = 50,
}

Config.Management = {
    coords = vector3(895.96, -179.25, 74.70),
    heading = 146.0,
}

Config.Locker = {
    coords = vector3(899.42, -179.58, 74.70),
    heading = 146.0,
}

Config.GarageHub = {
    coords = vector3(902.12, -172.41, 74.08),
    heading = 56.0,
}

Config.Permissions = {
    boss_menu = 2,
}

Config.MaxGrade = 2

Config.DutyOutfits = {
    {
        label = 'Taksi uniforma (naujokas)',
        minGrade = 0,
        male = { [4] = { 10, 0 }, [6] = { 10, 0 }, [8] = { 15, 0 }, [11] = { 13, 0 }, [3] = { 1, 0 } },
        female = { [4] = { 37, 0 }, [6] = { 6, 0 }, [8] = { 2, 0 }, [11] = { 27, 0 }, [3] = { 14, 0 } },
    },
    {
        label = 'Taksi uniforma (patyręs)',
        minGrade = 1,
        male = { [4] = { 28, 0 }, [6] = { 10, 0 }, [8] = { 15, 0 }, [11] = { 55, 0 }, [3] = { 1, 0 } },
        female = { [4] = { 37, 0 }, [6] = { 6, 0 }, [8] = { 6, 0 }, [11] = { 48, 0 }, [3] = { 14, 0 } },
    },
    {
        label = 'Taksi uniforma (bosas)',
        minGrade = 2,
        male = { [4] = { 10, 0 }, [6] = { 10, 0 }, [8] = { 31, 0 }, [11] = { 10, 0 }, [3] = { 1, 0 } },
        female = { [4] = { 37, 0 }, [6] = { 6, 0 }, [8] = { 8, 0 }, [11] = { 7, 0 }, [3] = { 14, 0 } },
    },
}

Config.AllowedTaxiModels = {
    taxi = true,
    cabby = true,
}

Config.Taximeter = {
    baseFare = 8,
    perKm = 65,
    perMinuteWait = 18,
    waitSpeedThresholdKmh = 8.0,
    maxFarePerTrip = 2500,
    minTripSecondsToCharge = 35,
    minTripDistanceKmToCharge = 0.15,
    autoBillStep = 40,
    maxDistancePerTickM = 120.0,
}
