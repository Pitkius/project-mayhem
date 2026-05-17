--- Turf užėmimo misijos ir cooldown (shared)
Config.TurfCapture = {
    claimThreshold = 100,
    playerCooldownSec = 90,
    turfCooldownSec = 300,
    maxProgressPerMinute = 45,
    drugSaleTurfProgress = 0, --- pardavimai savo turfe nedidina capture (tik rep/heat)
}

Config.TaskReputation = Config.TaskReputation or {
    drug = 8,
    smuggle = 10,
    theft = 7,
    extortion = 9,
    racing = 6,
    hacking = 12,
}

--- Misijos tipai: gangTypes = nil reiškia visiems
Config.MissionTypes = {
    smuggle = {
        label = 'Kontrabandos pristatymas',
        progress = 10,
        durationMs = 8000,
        gangs = { street = true, cartel = true, mafia = true },
        pickupOffset = vector3(45.0, 35.0, 0.0),
        dropInTurf = true,
    },
    theft = {
        label = 'Vogtos mašinos pristatymas',
        progress = 7,
        durationMs = 6000,
        gangs = { street = true, biker = true, racing = true },
        requireVehicle = true,
        dropInTurf = true,
    },
    extortion = {
        label = 'Reketas verslui',
        progress = 9,
        durationMs = 7000,
        gangs = { street = true, mafia = true, cartel = true },
        npcInTurf = true,
    },
    racing = {
        label = 'Gatvės lenktynės',
        progress = 6,
        durationMs = 5000,
        gangs = { racing = true, street = true, biker = true },
        checkpointCount = 3,
    },
    hacking = {
        label = 'Hackerio pagalba',
        progress = 12,
        gangs = nil,
        requiresHackTier = 'atm',
        hackerOnly = false,
    },
}

Config.HackGangRep = {
    atm = 3,
    fleeca = 8,
    store = 2,
}

Config.HackFailHeat = 5
