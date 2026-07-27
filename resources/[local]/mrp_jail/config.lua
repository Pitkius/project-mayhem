Config = {}

Config.PoliceJob = 'police'

--- GTA V aircraft carrier deck (qb-core shared location aircraft_carrier_int)
Config.Carrier = {
    spawn = vector4(3081.0042, -4693.6875, 15.2623, 76.8169),
    center = vector3(3081.0, -4693.7, 15.3),
    maxDistance = 95.0,
}

--- Release at Mission Row PD
Config.Release = vector4(428.23, -981.03, 30.71, 90.0)

Config.MaxMinutes = 10080 -- 7 days
Config.MinMinutes = 1

--- Optional public-work spots on the carrier (each completes ~60s → -1 minute)
Config.WorkDurationMs = 60000
Config.WorkSpots = {
    vector3(3092.4, -4707.2, 15.26),
    vector3(3068.8, -4680.5, 15.26),
    vector3(3105.1, -4688.9, 15.26),
    vector3(3070.2, -4715.6, 15.26),
}
Config.WorkInteractDistance = 2.2
Config.WorkMarker = {
    type = 2,
    scale = vector3(0.35, 0.35, 0.35),
    color = { r = 80, g = 180, b = 255, a = 180 },
}

--- Anti-escape check interval (ms)
Config.EscapeCheckMs = 2500

--- Starter food given after inventory strip
Config.StarterFood = {
    { name = 'burger', amount = 3 },
    { name = 'water_bottle', amount = 3 },
}

--- Jail canteen (qb-inventory shop) — cash/bank, not inventory money
Config.CanteenShop = {
    name = 'mrp_jail_canteen',
    label = 'Kalėjimo valgykla',
    items = {
        { name = 'burger', price = 15, amount = 50 },
        { name = 'water_bottle', price = 8, amount = 50 },
        { name = 'kurkakola', price = 12, amount = 50 },
        { name = 'coffee', price = 10, amount = 50 },
        { name = 'twerks_candy', price = 6, amount = 50 },
    },
}

Config.Canteen = {
    coords = vector4(3095.85, -4702.15, 15.26, 200.0),
    pedModel = 's_m_m_dockwork_01',
    interactDistance = 2.5,
}

Config.Defaults = {
    adminReason = 'Administracinė bausmė',
    policeReason = 'Policijos sulaikymas',
    noReason = 'Nepateikta priežastis',
}

Config.Notify = {
    jailed = 'Tu pasiųstas į viešuosius darbus lėktuvnešyje. Liko: %s min. Priežastis: %s',
    jailedOfficer = 'Žaidėjas #%s įkalintas %s min. (%s)',
    unjailed = 'Bausmė baigta. Inventorius atkurtas.',
    unjailedOfficer = 'Žaidėjas #%s paleistas iš kalėjimo.',
    stripped = 'Inventorius laikinai paimtas. Gausi maisto kalėjimo laikotarpiui.',
    restored = 'Tavo daiktai grąžinti.',
    workDone = 'Darbas atliktas (−1 min). Liko: %s min.',
    escaped = 'Negali palikti lėktuvnešio kol bausmė nesibaigė.',
    notJailed = 'Žaidėjas nėra kalėjime.',
    alreadyJailed = 'Žaidėjas jau kalėjime.',
    invalidTarget = 'Žaidėjas nerastas.',
    invalidMinutes = 'Neteisingas minučių skaičius.',
    noPermission = 'Neturi teisės.',
    canteenDenied = 'Valgykla prieinama tik kaliniams.',
}
