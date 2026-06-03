Config = {}

--- Burna juda kalbant (ne per raciją)
Config.FacialAnim = {
    dict = 'mp_facial',
    anim = 'mic_chatter',
}

--- Nenaudoti gestų kai kalbi per raciją (tą valdo pma-voice)
Config.SkipWhenRadioActive = true

--- Gestai transporte / kritimo metu
Config.DisableGesturesInVehicle = true

--- Viršutinė kūno dalis — galima vaikščioti (49)
Config.GestureFlag = 49

--- Tikimybės (0.0–1.0) — sąmoningai žemos, kad neperdaug
Config.GestureChanceOnStart = 0.22
Config.GestureChanceWhileTalking = 0.08

--- Mažiausias laikas tarp gestų (ms)
Config.GestureCooldownMs = 5500

--- Kaip dažnai tikrinti, ar paleisti gestą kalbant (ms)
Config.GesturePollMs = 900

--- Vyriški gestai (dict turi egzistuoti žaidime)
Config.GesturesMale = {
    { dict = 'gestures@m@standing@casual', anim = 'gesture_shrug_soft', duration = 2400 },
    { dict = 'gestures@m@standing@casual', anim = 'gesture_shrug_hard', duration = 2200 },
    { dict = 'gestures@m@standing@casual', anim = 'gesture_pleased', duration = 2600 },
    { dict = 'gestures@m@standing@casual', anim = 'gesture_easy_now', duration = 2500 },
    { dict = 'gestures@m@standing@casual', anim = 'gesture_point', duration = 2200 },
    { dict = 'gestures@m@standing@casual', anim = 'gesture_me', duration = 2300 },
    { dict = 'random@arrests', anim = 'generic_radio_chatter', duration = 3200 },
}

--- Moteriški gestai
Config.GesturesFemale = {
    { dict = 'gestures@f@standing@casual', anim = 'gesture_shrug_soft', duration = 2400 },
    { dict = 'gestures@f@standing@casual', anim = 'gesture_shrug_hard', duration = 2200 },
    { dict = 'gestures@f@standing@casual', anim = 'gesture_pleased', duration = 2600 },
    { dict = 'gestures@f@standing@casual', anim = 'gesture_easy_now', duration = 2500 },
    { dict = 'gestures@f@standing@casual', anim = 'gesture_point', duration = 2200 },
    { dict = 'gestures@f@standing@casual', anim = 'gesture_me', duration = 2300 },
}
