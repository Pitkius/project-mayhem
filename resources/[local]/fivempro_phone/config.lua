Config = {}

Config.KeybindCommand = 'fivempro_phone_toggle'
Config.KeybindDefault = 'F1'

--- Inventoriaus itemo pavadinimas (qb-core `items.lua`) – naudojant itemą atidaromas telefonas
Config.PhoneItem = 'phone'
--- Jei true, F1 veikia tik jei inventoriuje yra `Config.PhoneItem` (telefoną vis tiek galima atidaryti per itemą)
Config.RequirePhoneItemForKeybind = true

Config.Phone = {
    numberMin = 100000,
    numberMax = 999999,
    maxContacts = 120,
    maxMessageLength = 320,
    maxAdLength = 260,
    maxPostCaptionLength = 260,
    maxImageUrlLength = 500,
}

--- Skubūs skambučiai (telefonas → dispatch visiems tam tikro job žaidėjams tarnyboje)
Config.Emergency = {
    policeJobs = { 'ltpd', 'police' },
    ambulanceJob = 'ambulance',
    taxiJob = 'taxi',
    blipDurationMs = 120000,
    blipSprite = 161,
    blipScale = 1.0,
    --- Minimalus laikas tarp skambučių į tą pačią tarnybą (sek.)
    callCooldownSec = 45,
    --- M mygtukas – medikų iškvietimas (sek.)
    medicRequestCooldownSec = 90,
}

--- Po mirties: po N sek. galima laikyti G ir atsikelti ARTIMIAUSIOJE ligoninėje (iš sąrašo)
Config.HospitalWake = {
    waitAfterDeathSec = 900,
    holdGMs = 2800,
    --- Kelios ligoninės – serveris pasirenka artimiausią pagal žaidėjo poziciją skambinant G
    locations = {
        vector4(-458.6, -327.15, 34.50, 91.30), -- fivempro_ambulance LS zona
        vector4(298.65, -584.47, 43.26, 70.0), -- Pillbox
        vector4(1839.6, 3672.9, 34.28, 210.0), -- Sandy Shores
        vector4(-247.76, 6331.39, 32.43, 45.0), -- Paleto
    },
}
