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
    --- default = įdiegiama su paskyra ir rodoma pagrindiniame ekrane
    --- default = false → tik per App Store
    AppStoreApps = {
        { id = 'calls', label = 'Skambučiai', icon = 'calls', default = true },
        { id = 'messages', label = 'Žinutės', icon = 'messages', default = true },
        { id = 'contacts', label = 'Kontaktai', icon = 'contacts', default = true },
        { id = 'settings', label = 'Nustatymai', icon = 'settings', default = true },
        { id = 'camera', label = 'Kamera', icon = 'camera', default = true },
        { id = 'notes', label = 'Užrašai', icon = 'notes', default = true },
        { id = 'emergency', label = '112', icon = 'emergency', default = true },
        { id = 'appstore', label = 'App Store', icon = 'appstore', default = true },
        { id = 'ads', label = 'Skelbimai', icon = 'ads', default = false, description = 'Skelbimų lenta ir pardavimai' },
        { id = 'insta', label = 'LifeGram', icon = 'insta', default = false, description = 'Socialinis tinklas su nuotraukomis' },
        { id = 'bank', label = 'Bankas', icon = 'bank', default = false, description = 'Sąskaitos ir balansas' },
        { id = 'shop', label = 'Marketplace', icon = 'shop', default = false, description = 'Parduotuvės ir prekės mieste' },
        { id = 'weather', label = 'Orai', icon = 'weather', default = false, description = 'Orų prognozė Los Santos' },
        { id = 'radio', label = 'Radijas', icon = 'radio', default = false, description = 'Miesto radijo stotys' },
    }
}

--- Skubūs skambučiai (telefonas → dispatch visiems tam tikro job žaidėjams tarnyboje)
Config.Emergency = {
    policeJobs = { 'police' },
    ambulanceJob = 'ambulance',
    mechanicJob = 'mechanic',
    taxiJob = 'taxi',
    blipDurationMs = 120000,
    blipSprite = 161,
    blipScale = 1.0,
    --- Minimalus laikas tarp skambučių į tą pačią tarnybą (sek.)
    callCooldownSec = 45,
    --- G mygtukas – medikų iškvietimas mirus (kaip visiems žaidėjams)
    medicRequestCooldownSec = 90,
    medicRequestKey = 'G',
    --- Miręs policijos darbuotojas iškviečiant medikus automatiškai siunčia PANIC (fivempro_dispatch)
    policePanicOnMedicRequest = true,
}

--- Po mirties: po N sek. galima laikyti G ir atsikelti ARTIMIAUSIOJE ligoninėje (iš sąrašo)
Config.HospitalWake = {
    waitAfterDeathSec = 900,
    holdGMs = 2800,
    --- Kelios ligoninės – serveris pasirenka artimiausią pagal žaidėjo poziciją skambinant G
    locations = {
        vector4(309.52, -595.29, 43.28, 71.0), -- Pillbox EMS (fivempro_ambulance)
        vector4(298.65, -584.47, 43.26, 70.0), -- Pillbox
        vector4(1839.6, 3672.9, 34.28, 210.0), -- Sandy Shores
        vector4(-247.76, 6331.39, 32.43, 45.0), -- Paleto
    },
}
