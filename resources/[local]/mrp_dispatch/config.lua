Config = {}

Config.Services = {
    police = {
        jobs = { 'police' },
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
        jobs = { 'mechanic', 'mechanic2', 'mechanic3', 'beeker', 'bennys' },
        label = 'Mechanikai',
        color = 47,
        panicSound = false,
    },
}

Config.CallTypes = {
    robbery = 'Apiplėšimas',
    atm = 'Bankomatas',
    theft = 'Vagystė',
    vehicle_alarm = 'Transporto signalizacija',
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
    arrived = 'Atvykta',
    rejected = 'Atmestas',
    done = 'Baigta',
}

Config.MaxActiveCalls = 120
--- Server push interval for live unit/call blips (was 300ms — Phase 7 raised for less overlap with NUI).
Config.BlipRefreshMs = 1500
--- Civiliniai/teisėti iškvietimai iš telefono / skriptų: anti-spam (ms vienam žaidėjui)
Config.CreateCallCooldownMs = 4000

--- PANIC mygtukas (policija, duty). Keisti galima FiveM Settings → Key Bindings → FiveM
Config.PanicCommand = 'panic'
Config.PanicKey = 'F9'
Config.PanicKeyLabel = 'PANIC (policija)'
Config.PanicCooldownMs = 12000
--- Miręs pareigūnas iškviečiant medikus (M) taip pat siunčia PANIC
Config.PanicOnDeadMedicRequest = true

