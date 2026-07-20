Config = {}

--- Nuotraukų fiksavimas (kamera + galerija)

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
    maxAdTitleLength = 48,
    maxPostCaptionLength = 260,
    maxImageUrlLength = 500,
    --- Telefono kamera / galerija
    enablePhotos = true,
    maxPhotosPerUser = 80,
    maxPhotoDataLength = 1500000,
    maxNotesLength = 8000,
    maxNotes = 50,
    maxNoteTitleLength = 64,
    --- Užrašai, kurių `updated_at` senesnis nei tiek dienų, laikomi „senais“ (valymui)
    notesOldDays = 30,
    --- App Store siuntimo trukmė (ms) — programėlės neįsidiegia iškart
    appDownloadMs = { min = 7000, max = 14000 },
    --- CarPlay: max nuorodos ilgis
    maxCarPlayUrlLength = 2048,
    --- Automatiniai tarnybų kontaktai (įrašomi kiekvienam žaidėjui, abėcėlės tvarka)
    DefaultContacts = {
        { key = 'police', name = 'Policija', number = '112', service = 'police', icon = 'service-police' },
        { key = 'ems', name = 'Greitoji pagalba', number = '113', service = 'ems', icon = 'service-ems' },
        { key = 'mechanic', name = 'Mechanikas', number = '111', service = 'mechanic', icon = 'service-mechanic' },
        { key = 'taxi', name = 'Taksi', number = '1818', service = 'taxi', icon = 'service-taxi' },
    },
    --- Skelbimų kategorijos (lengvai pridėti naujas)
    AdCategories = {
        { id = 'all', label = 'Visi' },
        { id = 'vehicle', label = 'Transportas' },
        { id = 'property', label = 'Nekilnojamas turtas' },
        { id = 'job', label = 'Darbai' },
        { id = 'service', label = 'Paslaugos' },
        { id = 'electronics', label = 'Elektronika' },
        { id = 'clothes', label = 'Drabužiai' },
        { id = 'other', label = 'Įvairūs' },
    },
    --- default = įdiegiama su paskyra ir rodoma pagrindiniame ekrane
    --- default = false → tik per App Store (reikia atsisiųsti)
    --- Apps su requiresAccount: LifeGram / Skelbimai — atskira app paskyra (ne auto)
    AppStoreApps = {
        { id = 'calls', label = 'Skambučiai', icon = 'calls', default = true },
        { id = 'messages', label = 'Žinutės', icon = 'messages', default = true },
        { id = 'contacts', label = 'Kontaktai', icon = 'contacts', default = true },
        { id = 'settings', label = 'Nustatymai', icon = 'settings', default = true },
        { id = 'appstore', label = 'Programėlės', icon = 'appstore', default = true },
        { id = 'camera', label = 'Kamera', icon = 'camera', default = false, description = 'Fotografuok ir saugok nuotraukas telefone' },
        { id = 'gallery', label = 'Galerija', icon = 'gallery', default = false, description = 'Tavo nuotraukų albumas' },
        { id = 'notes', label = 'Užrašai', icon = 'notes', default = false, description = 'Asmeniniai užrašai' },
        { id = 'bank', label = 'BANKAS', icon = 'bank', default = false, description = 'Mobilus bankas — pervedimai, balansas, istorija' },
        { id = 'ads', label = 'Skelbimai', icon = 'ads', default = false, description = 'Skelbimų portalas — reikalinga atskira paskyra', requiresAccount = true },
        { id = 'insta', label = 'LifeGram', icon = 'insta', default = false, description = 'Socialinis tinklas — susikurk savo LifeGram paskyrą', requiresAccount = true },
        { id = 'carplay', label = 'CarPlay', icon = 'carplay', default = false, description = 'Muzika automobilyje (Spotify / YouTube)' },
        { id = 'weather', label = 'Orai', icon = 'weather', default = false, description = 'Orų prognozė: Los Santos, Sandy Shores, Paleto Bay' },
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
    --- Miręs policijos darbuotojas iškviečiant medikus automatiškai siunčia PANIC (mrp_dispatch)
    policePanicOnMedicRequest = true,
}

--- BANKAS telefono programėlė
Config.Bank = {
    name = 'BANKNET',
    transferCooldownSec = 5,
    minTransferAmount = 1,
    maxTransferAmount = 500000,
    maxDepositWithdraw = 500000,
    maxPurposeLength = 80,
    recentTransactionLimit = 20,
    historyLimit = 50,
}

--- Mirties ekrano vaizdas (mrp_phone/client/death.lua)
Config.DeathScreen = {
    title = 'MIRĘS',
    postFx = 'DeathFailMPIn',
    timecycle = 'damage',
    timecycleStrength = 0.72,
    --- Neon purple + kraujo raudona
    accent = { r = 191, g = 95, b = 255 },
    blood = { r = 175, g = 18, b = 38 },
}

--- Po mirties: po N sek. galima laikyti G ir atsikelti ARTIMIAUSIOJE ligoninėje (iš sąrašo)
Config.HospitalWake = {
    waitAfterDeathSec = 900,
    holdGMs = 2800,
    --- Kelios ligoninės – serveris pasirenka artimiausią pagal žaidėjo poziciją skambinant G
    locations = {
        vector4(309.52, -595.29, 43.28, 71.0), -- Pillbox EMS (mrp_ambulance)
        vector4(298.65, -584.47, 43.26, 70.0), -- Pillbox
        vector4(1839.6, 3672.9, 34.28, 210.0), -- Sandy Shores
        vector4(-247.76, 6331.39, 32.43, 45.0), -- Paleto
    },
}
