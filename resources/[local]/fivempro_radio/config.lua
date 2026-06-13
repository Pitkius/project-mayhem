Config = {}

--- Dažnio ribos (MHz, 2 skaitmenys po kablelio)
Config.MinFrequency = 1.0
Config.MaxFrequency = 999.99
Config.FrequencyStep = 0.01

--- Užkoduoti diapazonai iki 21 MHz (server-side)
--- Pvz. 1.11, 9.81 — policija; 12.50 — medikai; 19.81 — mechanikai
Config.RestrictedRanges = {
    { min = 1.0, max = 10.99, jobs = { 'police' }, label = 'Policija', lockLabel = 'Užkoduotas · Policija' },
    { min = 11.0, max = 15.99, jobs = { 'ambulance' }, label = 'Medikai', lockLabel = 'Užkoduotas · Medikai' },
    { min = 16.0, max = 20.99, jobs = { 'mechanic', 'mechanic2', 'mechanic3' }, label = 'Mechanikai', lockLabel = 'Užkoduotas · Mechanikai' },
}

--- 21.00 MHz ir aukščiau — vieši
Config.PublicMinFrequency = 21.0

--- Numatyti garsai (NUI / frontend)
Config.DefaultSounds = {
    beepStart = false,
    beepEnd = false,
    channelChange = true,
    connect = true,
    disconnect = true,
}

--- HUD dešinėje: Racija, Prisijungę: N, - vardai
Config.MemberList = {
    x = 0.90,
    y = 0.08,
    maxLines = 10,
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

function Config.GetFactionForFreq(freq)
    freq = RadioFreq.normalize(freq)
    if not freq then return nil end
    for _, r in ipairs(Config.RestrictedRanges or {}) do
        if freq >= r.min and freq <= r.max then
            return r.label
        end
    end
    if freq >= (Config.PublicMinFrequency or 21.0) then
        return 'Viešas'
    end
    return nil
end
