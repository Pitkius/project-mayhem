Config = {}

Config.Services = {
    police = {
        jobs = { 'ltpd', 'police' },
        label = 'Policija',
        color = 38,
        panicSound = true,
    },
    ems = {
        jobs = { 'ambulance' },
        label = 'Medikai',
        color = 1,
        panicSound = false,
    },
    mechanic = {
        jobs = { 'mechanic' },
        label = 'Mechanikai',
        color = 47,
        panicSound = false,
    },
}

Config.CallTypes = {
    robbery = 'Apiplėšimas',
    theft = 'Vagystė',
    shooting = 'Šaudymas',
    fight = 'Muštynės',
    traffic = 'Eismo įvykis',
    civilian_help = 'Civilio pagalbos prašymas',
    custom = 'Kitas',
}

Config.CallStatus = {
    pending = 'Laukia',
    accepted = 'Priimtas',
    enroute = 'Vykstu',
    rejected = 'Atmestas',
    done = 'Baigta',
}

Config.MaxActiveCalls = 120
Config.BlipRefreshMs = 1500
--- Civiliniai/teisėti iškvietimai iš telefono / skriptų: anti-spam (ms vienam žaidėjui)
Config.CreateCallCooldownMs = 4000

