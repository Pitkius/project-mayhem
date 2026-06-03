Config = {}

--- Dažnio įvedimo ribos
Config.MinFrequency = 1
Config.MaxFrequency = 999

--- Užkoduoti diapazonai (server-side)
Config.RestrictedRanges = {
    { min = 1, max = 10, jobs = { 'police' }, label = 'PD', lockLabel = 'Užkoduotas PD' },
    { min = 11, max = 15, jobs = { 'ambulance' }, label = 'EMS', lockLabel = 'Užkoduotas EMS' },
    { min = 16, max = 20, jobs = { 'mechanic', 'mechanic2', 'mechanic3' }, label = 'MECH', lockLabel = 'Užkoduotas MECH' },
}

--- 21+ vieši
Config.PublicMinFrequency = 21

--- Rodomi kanalo pavadinimai (nebūtina — jei nėra, generuojama iš diapazono)
Config.ChannelNames = {
    [1] = 'PD Pagrindinis',
    [2] = 'PD Operacijos',
    [3] = 'PD Taktinis',
    [11] = 'EMS Pagrindinis',
    [12] = 'EMS Greitoji',
    [16] = 'MECH Pagrindinis',
    [21] = 'Visuomeninis',
    [88] = 'Asmeninis',
}

--- Numatyti garsai (NUI / frontend)
Config.DefaultSounds = {
    beepStart = true,
    beepEnd = true,
    channelChange = true,
    connect = true,
    disconnect = true,
}

--- Overlay pozicija (dešinė virš minimap)
Config.Overlay = {
    x = 0.88,
    y = 0.72,
}

--- Prisijungusių sąrašas ant ekrano (GTA tekstas)
Config.MemberList = {
    x = 0.86,
    y = 0.38,
    maxLines = 8,
}

--- Racijos kalbėjimo animacija (judėjimas leidžiamas: flag 49)
Config.RadioAnim = {
    dict = 'random@arrests',
    anim = 'generic_radio_chatter',
    flag = 49,
}

--- Dažnio keitimo / prisijungimo garsai (frontend)
Config.SoundIds = {
    connect = 'NAV_UP_DOWN',
    disconnect = 'NAV_LEFT_RIGHT',
    channel = 'SELECT',
    beepOn = 'HUD_FRONTEND_DEFAULT_SOUNDSET',
}
